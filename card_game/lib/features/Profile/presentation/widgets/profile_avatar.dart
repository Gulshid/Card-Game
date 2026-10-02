import 'package:card_game/features/profile/domain/models/player_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The selectable avatars. Length must stay equal to
/// [PlayerProfile.avatarCount] (asserted below).
const List<(IconData, Color)> kAvatars = [
  (Icons.person, Color(0xFF2451B5)),
  (Icons.face, Color(0xFF1E8E5A)),
  (Icons.pets, Color(0xFFB4532A)),
  (Icons.sports_esports, Color(0xFF6B3FA0)),
  (Icons.rocket_launch, Color(0xFFD85A30)),
  (Icons.local_fire_department, Color(0xFFC0392B)),
  (Icons.diamond, Color(0xFF148F9F)),
  (Icons.psychology, Color(0xFF3B4656)),
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.avatarId, this.radius = 28, super.key})
      : assert(PlayerProfile.avatarCount == 8, 'Update kAvatars to match PlayerProfile.avatarCount');

  final int avatarId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = kAvatars[avatarId.clamp(0, kAvatars.length - 1)];
    return CircleAvatar(
      radius: radius.r,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: radius.r * 1.1),
    );
  }
}
