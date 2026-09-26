import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.musicOn = true,
    this.sfxOn = true,
    this.hapticsOn = true,
    this.musicVolume = 0.7,
    this.sfxVolume = 0.9,
  });

  final bool musicOn;
  final bool sfxOn;
  final bool hapticsOn;
  final double musicVolume;
  final double sfxVolume;

  SettingsState copyWith({
    bool? musicOn,
    bool? sfxOn,
    bool? hapticsOn,
    double? musicVolume,
    double? sfxVolume,
  }) {
    return SettingsState(
      musicOn: musicOn ?? this.musicOn,
      sfxOn: sfxOn ?? this.sfxOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
    );
  }

  @override
  List<Object?> get props => [musicOn, sfxOn, hapticsOn, musicVolume, sfxVolume];
}
