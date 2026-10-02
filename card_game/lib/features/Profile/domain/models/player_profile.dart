import 'package:equatable/equatable.dart';

import 'achievements.dart';

/// Who the player is: display name, avatar and the card back they've
/// chosen. Local-only for now; Phase 10 will attach an account id.
class PlayerProfile extends Equatable {
  const PlayerProfile({
    this.name = defaultName,
    this.avatarId = 0,
    this.cardBack = CardBackStyle.classic,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final Object? rawAvatar = json['avatarId'];
    final int avatar = rawAvatar is num ? rawAvatar.toInt() : 0;
    return PlayerProfile(
      name: sanitizeName((json['name'] as String?) ?? '') ?? defaultName,
      avatarId: avatar.clamp(0, avatarCount - 1),
      cardBack: CardBackStyle.values.asNameMap()[json['cardBack']] ?? CardBackStyle.classic,
    );
  }

  static const String defaultName = 'Player';
  static const int maxNameLength = 16;

  /// Must equal the number of entries in the presentation layer's avatar
  /// list (`kAvatars`); ids are clamped into this range on load.
  static const int avatarCount = 8;

  final String name;
  final int avatarId;
  final CardBackStyle cardBack;

  /// Trims, collapses inner whitespace and caps the length. Returns `null`
  /// if nothing usable is left, so callers can simply ignore the edit.
  static String? sanitizeName(String raw) {
    final String collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return null;
    return collapsed.length > maxNameLength ? collapsed.substring(0, maxNameLength) : collapsed;
  }

  PlayerProfile copyWith({String? name, int? avatarId, CardBackStyle? cardBack}) {
    return PlayerProfile(
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      cardBack: cardBack ?? this.cardBack,
    );
  }

  Map<String, Object?> toJson() => {'name': name, 'avatarId': avatarId, 'cardBack': cardBack.name};

  @override
  List<Object?> get props => [name, avatarId, cardBack];
}
