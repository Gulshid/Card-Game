import 'package:card_game/features/home/bloc/resume_match_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    Future<void>.delayed(const Duration(seconds: 3)), // minimum splash time
  ]);
  if (mounted) context.goNamed(AppRoute.home);
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
