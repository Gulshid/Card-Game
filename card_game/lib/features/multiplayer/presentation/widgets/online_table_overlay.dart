import 'dart:async';

import 'package:card_game/Shared/widgets/glass_icon_button.dart';
import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/game/Presentation/bloc/table_cubit.dart';
import 'package:card_game/features/multiplayer/bloc/online_game_cubit.dart';
import 'package:card_game/features/multiplayer/bloc/online_meta.dart';
import 'package:card_game/features/multiplayer/data/online_session.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Display text for the whitelisted emote ids (the wire only carries ids).
const Map<String, String> kEmoteLabels = {
  'gg': 'GG!',
  'nice': 'Nice play!',
  'oops': 'Oops…',
  'thanks': 'Thanks!',
  'hurry': 'Hurry up ⏱',
  'wow': 'Wow!',
};

/// Everything online-specific drawn on top of the felt: connection
/// problems, "a bot is covering for X", your turn clock, emotes, and the
/// full-screen notice when the match disappears from under you.
///
/// Rendered via `GameTableView.overlay`, so the table itself needs no
/// knowledge of networking.
class OnlineTableOverlay extends StatelessWidget {
  const OnlineTableOverlay({
    required this.cubit,
    required this.session,
    required this.onLeave,
    super.key,
  });

  final OnlineGameCubit cubit;
  final OnlineSession session;

  /// Called by the leave button and the "match ended" notice.
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ValueListenableBuilder<OnlineMeta>(
        valueListenable: cubit.meta,
        builder: (context, meta, _) {
          final bool matchIsOver = cubit.state.game.phase.name == 'matchOver';
          final bool lost = meta.endedReason != null && meta.endedReason != 'finished';

          return Stack(
            children: [
              Positioned(
                top: 80.h,
                left: 8.w,
                right: 8.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GlassIconButton(
                          tooltip: 'Leave match',
                          icon: Icons.logout_rounded,
                          size: 38,
                          forceDark: true,
                          color: Colors.white70,
                          onPressed: onLeave,
                        ),
                        const Spacer(),
                        if (!matchIsOver) _TurnClock(meta: meta, session: session),
                        _EmoteButton(onSelected: cubit.sendEmote),
                      ],
                    ),
                    if (meta.connection != ConnectionStatus.connected)
                      const _Pill(icon: Icons.wifi_off, text: 'Connection lost — reconnecting…', color: AppColors.danger),
                    for (final RoomSeatInfo s in meta.disconnectedHumans)
                      _Pill(
                        icon: Icons.smart_toy_outlined,
                        text: '${s.name} disconnected — a bot plays if they stay away',
                        color: AppColors.warning,
                      ),
                    if (meta.emoteId != null && meta.emoteSeat != null)
                      _EmoteToast(
                        key: ValueKey(meta.emoteNonce),
                        who: meta.seats[meta.emoteSeat]?.name ?? meta.emoteSeat!.name,
                        text: kEmoteLabels[meta.emoteId] ?? meta.emoteId!,
                      ),
                  ],
                ),
              ),
              if (lost) Positioned.fill(child: _EndedNotice(reason: meta.endedReason!, onExit: onLeave)),
            ],
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.85)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Flexible(child: Text(text, style: AppTextStyles.caption(Colors.white))),
        ],
      ),
    );
  }
}

class _EmoteToast extends StatelessWidget {
  const _EmoteToast({required this.who, required this.text, super.key});

  final String who;
  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2800),
      curve: const Interval(0.7, 1),
      builder: (context, t, child) => Opacity(opacity: 1 - t, child: child),
      child: _Pill(icon: Icons.chat_bubble_outline, text: '$who: $text', color: AppColors.gold),
    );
  }
}

class _EmoteButton extends StatelessWidget {
  const _EmoteButton({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Send an emote',
        padding: EdgeInsets.zero,
        icon: Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 19.sp),
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final String id in kEmoteIds) PopupMenuItem<String>(value: id, child: Text(kEmoteLabels[id] ?? id)),
        ],
      ),
    );
  }
}

/// Seconds left on the local player's clock (only while it is their turn).
class _TurnClock extends StatefulWidget {
  const _TurnClock({required this.meta, required this.session});

  final OnlineMeta meta;
  final OnlineSession session;

  @override
  State<_TurnClock> createState() => _TurnClockState();
}

class _TurnClockState extends State<_TurnClock> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool myTurn = context.select((TableCubit c) => c.state.isHumanTurn);
    final int deadline = widget.meta.turnDeadlineMs;
    if (!myTurn || deadline == 0) return const SizedBox.shrink();

    final int left = ((deadline - widget.session.serverNowMs) / 1000).ceil().clamp(0, 999);
    final bool urgent = left <= 10;
    final Color tone = urgent ? AppColors.danger : Colors.white70;
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: urgent ? AppColors.danger.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16.sp, color: tone),
          SizedBox(width: 4.w),
          Text('${left}s', style: AppTextStyles.numeric(tone, size: 14)),
        ],
      ),
    );
  }
}

class _EndedNotice extends StatelessWidget {
  const _EndedNotice({required this.reason, required this.onExit});

  final String reason;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final String text = reason == ErrorCode.replaced
        ? 'You signed in on another device, so this table was closed here.'
        : 'This match is no longer available.';
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A50), Color(0xFF0E1830)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 40.sp),
            SizedBox(height: AppSpacing.sm),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.body(Colors.white)),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Back to lobby', icon: Icons.arrow_back_rounded, onPressed: onExit),
          ],
        ),
      ),
    );
  }
}
