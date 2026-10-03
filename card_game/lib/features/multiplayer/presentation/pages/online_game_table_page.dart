import 'dart:async';

import 'package:card_game/Shared/widgets/loading_indicator.dart';
import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/routes/app_router.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_state.dart';
import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/Profile/presentation/widgets/card_back_scope.dart';
import 'package:card_game/features/game/Presentation/bloc/table_cubit.dart';
import 'package:card_game/features/game/Presentation/pages/game_table_page.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/multiplayer/bloc/online_game_cubit.dart';
import 'package:card_game/features/multiplayer/data/online_prefs.dart';
import 'package:card_game/features/multiplayer/data/online_session.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/presentation/widgets/online_table_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The felt table for a server-driven match. It is the *same*
/// [GameTableView] as the offline table; only the cubit behind it and an
/// overlay (connection, bots covering, emotes) differ.
///
/// The table waits for the first snapshot before it builds, which is what
/// makes both "match just started" and "reconnected mid-match" work with
/// the same code path.
class OnlineGameTablePage extends StatefulWidget {
  const OnlineGameTablePage({super.key});

  @override
  State<OnlineGameTablePage> createState() => _OnlineGameTablePageState();
}

class _OnlineGameTablePageState extends State<OnlineGameTablePage> {
  final OnlineSession _session = sl<OnlineSession>();
  OnlineGameCubit? _cubit;
  StreamSubscription<OnlineEvent>? _sub;

  @override
  void initState() {
    super.initState();
    final MatchSnapshot? snap = _session.snapshot;
    if (snap != null) {
      _createCubit(snap);
    } else {
      _sub = _session.events.listen((OnlineEvent e) {
        if (e is SnapshotReceived && _cubit == null && mounted) {
          setState(() => _createCubit(e.snapshot));
        }
      });
    }
  }

  void _createCubit(MatchSnapshot snap) {
    _cubit = OnlineGameCubit(
      session: _session,
      initial: snap,
      prefs: sl<OnlinePrefs>(),
      haptics: sl<HapticsService>(),
      audio: sl<AudioService>(),
    )..start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cubit?.close(); // also leaves the match if the player hasn't already
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave match?'),
        content: const Text('A bot will take over your seat and you will not be able to rejoin.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return leave ?? false;
  }

  void _exitToLobby() {
    _cubit?.leave();
    if (mounted) context.pop();
  }

  void _exitToHome() {
    _cubit?.leave();
    if (mounted) context.goNamed(AppRoute.home);
  }

  Future<void> _onLeavePressed() async {
    final bool over = _cubit?.state.game.phase == GamePhase.matchOver;
    if (over || await _confirmLeave()) _exitToLobby();
  }

  @override
  Widget build(BuildContext context) {
    final OnlineGameCubit? cubit = _cubit;
    if (cubit == null) {
      return Scaffold(
        backgroundColor: AppColors.feltDeep,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.feltGradient),
          child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoadingIndicator(),
              const SizedBox(height: 16),
              const Text('Joining table…', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextButton(onPressed: _exitToLobby, child: const Text('Cancel')),
            ],
          ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onLeavePressed());
      },
      child: BlocProvider<TableCubit>.value(
        value: cubit,
        child: BlocSelector<ProfileCubit, ProfileState, CardBackStyle>(
          selector: (state) => state.profile.cardBack,
          builder: (context, cardBack) => CardBackScope(
            style: cardBack,
            child: GameTableView(
              resumed: true, // never replay the deal flourish for the first view
              playAgainLabel: 'Back to lobby',
              homeLabel: 'Home',
              onPlayAgain: _exitToLobby,
              onHome: _exitToHome,
              overlay: OnlineTableOverlay(cubit: cubit, session: _session, onLeave: _onLeavePressed),
            ),
          ),
        ),
      ),
    );
  }
}
