import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/Shared/widgets/stat_tile.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/routes/app_router.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/Profile/presentation/widgets/profile_avatar.dart';
import 'package:card_game/features/multiplayer/bloc/lobby_cubit.dart';
import 'package:card_game/features/multiplayer/bloc/lobby_state.dart';
import 'package:card_game/features/multiplayer/data/online_prefs.dart';
import 'package:card_game/features/multiplayer/data/online_session.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Entry to online play: quick match, create a private room, or join one
/// by code. Opens the connection on entry and closes it on exit (unless a
/// match is running, which keeps the socket alive for the table).
class OnlineLobbyPage extends StatelessWidget {
  const OnlineLobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LobbyCubit(session: sl<OnlineSession>(), prefs: sl<OnlinePrefs>())..init(),
      child: const _LobbyView(),
    );
  }
}

class _LobbyView extends StatefulWidget {
  const _LobbyView();

  @override
  State<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<_LobbyView> {
  final TextEditingController _code = TextEditingController();
  bool _openingTable = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _openTable() async {
    if (_openingTable) return;
    _openingTable = true;
    final LobbyCubit lobby = context.read<LobbyCubit>();
    await context.pushNamed(AppRoute.onlineTable);
    _openingTable = false;
    lobby.matchLeft();
  }

  Future<void> _editServer(String current) async {
    final LobbyCubit lobby = context.read<LobbyCubit>();
    final TextEditingController c = TextEditingController(text: current);
    final String? url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(
          controller: c,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'ws://192.168.1.20:8080/ws'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(''), child: const Text('Reset')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (url != null) await lobby.setServerUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LobbyCubit, LobbyState>(
      listenWhen: (a, b) => a.matchNonce != b.matchNonce || a.messageNonce != b.messageNonce,
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message!)));
        }
        if (state.phase == LobbyPhase.inMatch) _openTable();
      },
      builder: (context, state) {
        final LobbyCubit cubit = context.read<LobbyCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Play Online'),
            actions: [
              IconButton(
                tooltip: 'Server address',
                icon: const Icon(Icons.dns_outlined),
                onPressed: () => _editServer(state.serverUrl),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConnectionCard(state: state, onRetry: cubit.retryConnection),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: StatTile(value: '${state.played}', label: 'Online games')),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(child: StatTile(value: '${state.wins}', label: 'Online wins')),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                if (state.phase == LobbyPhase.inRoom && state.room != null)
                  _RoomCard(room: state.room!, onStart: cubit.startRoomMatch, onLeave: cubit.leaveRoom)
                else if (state.phase == LobbyPhase.searching)
                  _SearchingCard(state: state, onCancel: cubit.cancelSearch)
                else ...[
                  PrimaryButton(
                    label: 'Quick match',
                    icon: Icons.bolt_rounded,
                    onPressed: state.isOnline ? cubit.quickMatch : null,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Create private room',
                    icon: Icons.group_add_outlined,
                    onPressed: state.isOnline ? cubit.createRoom : null,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text('Join with a code', style: AppTextStyles.h2(Theme.of(context).colorScheme.onSurface)),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: kRoomCodeLength,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                          decoration: const InputDecoration(hintText: 'ABCD', counterText: ''),
                          onSubmitted: cubit.joinRoom,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: state.isOnline ? () => cubit.joinRoom(_code.text) : null,
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Quick match pairs you with other players; empty seats are filled by bots after '
                    '$kQuickMatchBotFillSeconds seconds. Private rooms let friends play together — the host '
                    'can start with bots in any empty seat.',
                    style: AppTextStyles.caption(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.state, required this.onRetry});

  final LobbyState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = switch (state.connection) {
      ConnectionStatus.connected => (Icons.cloud_done_outlined, AppColors.success, 'Connected'),
      ConnectionStatus.connecting => (Icons.cloud_sync_outlined, AppColors.warning, 'Connecting…'),
      ConnectionStatus.reconnecting => (Icons.cloud_sync_outlined, AppColors.warning, 'Reconnecting…'),
      ConnectionStatus.disconnected => (Icons.cloud_off_outlined, AppColors.danger, 'Offline'),
    };
    return AppSurface(
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: AppTextStyles.bodyStrong(Theme.of(context).colorScheme.onSurface)),
                Text(
                  state.serverUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          if (state.connection != ConnectionStatus.connected) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SearchingCard extends StatelessWidget {
  const _SearchingCard({required this.state, required this.onCancel});

  final LobbyState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return AppSurface(
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: AppSpacing.md),
          Text('Finding players…', style: AppTextStyles.h2(on)),
          SizedBox(height: AppSpacing.xs),
          Text(
            '${state.queueWaiting} in queue · bots join in ${state.fillInSeconds}s',
            style: AppTextStyles.body(on.withValues(alpha: 0.7)),
          ),
          SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onStart, required this.onLeave});

  final RoomInfo room;
  final VoidCallback onStart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final Color on = Theme.of(context).colorScheme.onSurface;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Room code', textAlign: TextAlign.center, style: AppTextStyles.caption(on.withValues(alpha: 0.6))),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Text(
              room.code,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(AppColors.gold).copyWith(letterSpacing: 8),
            ),
          ),
          Text('Tap to copy · share it with friends', textAlign: TextAlign.center, style: AppTextStyles.caption(on.withValues(alpha: 0.5))),
          SizedBox(height: AppSpacing.md),
          for (final RoomSeatInfo s in room.seats)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: s.occupied
                  ? ProfileAvatar(avatarId: s.avatarId, radius: 16)
                  : const CircleAvatar(child: Icon(Icons.chair_alt_outlined)),
              title: Text(
                s.occupied ? '${s.name}${s.isYou ? ' (you)' : ''}' : 'Empty — bot will sit here',
                style: AppTextStyles.body(on.withValues(alpha: s.occupied ? 1 : 0.5)),
              ),
              subtitle: Text(
                '${s.seat.name[0].toUpperCase()}${s.seat.name.substring(1)}'
                '${s.isHost ? ' · host' : ''}${s.occupied && !s.connected ? ' · offline' : ''}',
              ),
            ),
          SizedBox(height: AppSpacing.md),
          if (room.iAmHost)
            PrimaryButton(
              label: room.humanCount < 4 ? 'Start with bots in empty seats' : 'Start match',
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            )
          else
            Text('Waiting for the host to start…', textAlign: TextAlign.center, style: AppTextStyles.body(on.withValues(alpha: 0.7))),
          TextButton(onPressed: onLeave, child: const Text('Leave room')),
        ],
      ),
    );
  }
}
