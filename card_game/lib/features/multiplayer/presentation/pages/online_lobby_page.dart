import 'package:card_game/Shared/widgets/app_background.dart';
import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/fade_slide_in.dart';
import 'package:card_game/Shared/widgets/loading_indicator.dart';
import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/Shared/widgets/secondary_button.dart';
import 'package:card_game/Shared/widgets/section_header.dart';
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
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
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
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(child: _ConnectionCard(state: state, onRetry: cubit.retryConnection)),
                    SizedBox(height: AppSpacing.md),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 70),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.public_rounded,
                              value: '${state.played}',
                              label: 'Online games',
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: StatTile(
                              icon: Icons.emoji_events_outlined,
                              value: '${state.wins}',
                              label: 'Online wins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    if (state.phase == LobbyPhase.inRoom && state.room != null)
                      _RoomCard(room: state.room!, onStart: cubit.startRoomMatch, onLeave: cubit.leaveRoom)
                    else if (state.phase == LobbyPhase.searching)
                      _SearchingCard(state: state, onCancel: cubit.cancelSearch)
                    else ...[
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PrimaryButton(
                              label: 'Quick match',
                              icon: Icons.bolt_rounded,
                              onPressed: state.isOnline ? cubit.quickMatch : null,
                            ),
                            SizedBox(height: AppSpacing.sm + 2),
                            SecondaryButton(
                              label: 'Create private room',
                              icon: Icons.group_add_outlined,
                              onPressed: state.isOnline ? cubit.createRoom : null,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg + 4.h),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 210),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader('Join with a code'),
                            SizedBox(height: AppSpacing.sm + 2),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _code,
                                    textAlign: TextAlign.center,
                                    textCapitalization: TextCapitalization.characters,
                                    maxLength: kRoomCodeLength,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                                    style: AppTextStyles.title(primary).copyWith(letterSpacing: 10),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16.sp, color: muted),
                                SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Quick match pairs you with other players; empty seats are filled by bots after '
                                    '$kQuickMatchBotFillSeconds seconds. Private rooms let friends play together — the host '
                                    'can start with bots in any empty seat.',
                                    style: AppTextStyles.caption(muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final (IconData icon, Color color, String text) = switch (state.connection) {
      ConnectionStatus.connected => (Icons.cloud_done_outlined, AppColors.success, 'Connected'),
      ConnectionStatus.connecting => (Icons.cloud_sync_outlined, AppColors.warning, 'Connecting…'),
      ConnectionStatus.reconnecting => (Icons.cloud_sync_outlined, AppColors.warning, 'Reconnecting…'),
      ConnectionStatus.disconnected => (Icons.cloud_off_outlined, AppColors.danger, 'Offline'),
    };

    return AppSurface(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 21.sp),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(text, style: AppTextStyles.bodyStrong(primary)),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  state.serverUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(muted),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppSurface(
      highlight: true,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          SizedBox(height: AppSpacing.sm),
          const AppLoadingIndicator(size: 44),
          SizedBox(height: AppSpacing.lg),
          Text('Finding players…', style: AppTextStyles.title(primary)),
          SizedBox(height: AppSpacing.xs + 2),
          Text(
            '${state.queueWaiting} in queue · bots join in ${state.fillInSeconds}s',
            style: AppTextStyles.body(muted),
          ),
          SizedBox(height: AppSpacing.lg),
          SecondaryButton(label: 'Cancel', onPressed: onCancel),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppSurface(
      highlight: true,
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ROOM CODE', textAlign: TextAlign.center, style: AppTextStyles.overline(muted)),
          SizedBox(height: AppSpacing.sm + 2),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              children: [
                for (final String ch in room.code.split(''))
                  Container(
                    width: 52.w,
                    height: 64.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [const Color(0xFF22345F), const Color(0xFF111C38)]
                            : [Colors.white, const Color(0xFFEFF1F8)],
                      ),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.3),
                      boxShadow: AppShadows.goldGlow(0.14),
                    ),
                    child: Text(ch, style: AppTextStyles.display(AppColors.goldText(context))),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm + 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copy_rounded, size: 13.sp, color: muted),
              SizedBox(width: 6.w),
              Text('Tap to copy · share it with friends', style: AppTextStyles.caption(muted)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          const Divider(),
          SizedBox(height: AppSpacing.sm),
          for (final RoomSeatInfo s in room.seats) _SeatRow(seat: s, primary: primary, muted: muted),
          SizedBox(height: AppSpacing.md),
          if (room.iAmHost)
            PrimaryButton(
              label: room.humanCount < 4 ? 'Start (bots fill empty seats)' : 'Start match',
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLoadingIndicator(size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Text('Waiting for the host to start…', style: AppTextStyles.body(muted)),
                ],
              ),
            ),
          SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onLeave,
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Leave room'),
          ),
        ],
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({required this.seat, required this.primary, required this.muted});

  final RoomSeatInfo seat;
  final Color primary;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final String seatName = '${seat.seat.name[0].toUpperCase()}${seat.seat.name.substring(1)}';

    Widget chip(String text, Color color) => Container(
          margin: EdgeInsets.only(left: 6.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(text, style: AppTextStyles.overline(color).copyWith(fontSize: 8.5.sp)),
        );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          seat.occupied
              ? ProfileAvatar(avatarId: seat.avatarId, radius: 18)
              : CircleAvatar(
                  radius: 18.r,
                  backgroundColor: muted.withValues(alpha: 0.12),
                  child: Icon(Icons.chair_alt_outlined, size: 17.sp, color: muted),
                ),
          SizedBox(width: AppSpacing.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seat.occupied ? '${seat.name}${seat.isYou ? ' (you)' : ''}' : 'Empty — bot will sit here',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong(seat.occupied ? primary : muted),
                ),
                Text(seatName, style: AppTextStyles.caption(muted)),
              ],
            ),
          ),
          if (seat.isHost) chip('HOST', AppColors.gold),
          if (seat.occupied && !seat.connected) chip('OFFLINE', AppColors.danger),
        ],
      ),
    );
  }
}
