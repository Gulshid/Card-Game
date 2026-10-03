import 'package:card_game/Shared/widgets/app_background.dart';
import 'package:card_game/Shared/widgets/spade_mark.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/home/bloc/resume_match_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';

/// Loads what Home needs before showing it: the player's profile/stats
/// (so Home never flashes default values) and whether a suspended match
/// exists (so the "Resume" card is already there on the first frame).
///
/// It does not auto-jump into the suspended match — the player decides
/// from Home. Either read failing is handled inside the repositories
/// (they fall back to defaults), so this screen can never get stuck.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Duration _minSplash = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final ProfileCubit profile = context.read<ProfileCubit>();
    final ResumeMatchCubit resume = context.read<ResumeMatchCubit>();
    await Future.wait([
      profile.ensureLoaded(),
      resume.refresh(),
      Future<void>.delayed(_minSplash), // minimum splash time
    ]);
    if (mounted) context.goNamed(AppRoute.home);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 5),
              // Emblem: scales + fades in.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
                ),
                child: BrandBadge(size: 116.w),
              ),
              SizedBox(height: 28.h),
              // Wordmark: fades in slightly later.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: const Interval(0.35, 1, curve: Curves.easeOut),
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => AppColors.goldGradient.createShader(r),
                      child: Text(
                        'Spades Royale',
                        style: AppTextStyles.display(Colors.white).copyWith(fontSize: 36.sp, letterSpacing: 0.5),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'THE CLASSIC TRICK-TAKING GAME',
                      style: AppTextStyles.overline(
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 4),
              // Progress hairline that fills over the minimum splash time.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _minSplash,
                curve: Curves.easeInOut,
                builder: (context, t, _) => SizedBox(
                  width: 140.w,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: t, minHeight: 3),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
          ),
        ),
      ),
    );
  }
}