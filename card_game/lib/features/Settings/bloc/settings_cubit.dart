import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

/// Owns audio/haptics preferences for the whole app. `main.dart`
/// listens to this cubit and forwards changes into `AudioService` /
/// `HapticsService` live — this cubit only owns the *values*, never
/// touches the services directly, keeping it trivially testable.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required SharedPreferences prefs})
      : _prefs = prefs,
        super(
          SettingsState(
            musicOn: prefs.getBool(_kMusicOn) ?? true,
            sfxOn: prefs.getBool(_kSfxOn) ?? true,
            hapticsOn: prefs.getBool(_kHapticsOn) ?? true,
            musicVolume: prefs.getDouble(_kMusicVolume) ?? 0.7,
            sfxVolume: prefs.getDouble(_kSfxVolume) ?? 0.9,
          ),
        );

  final SharedPreferences _prefs;

  static const String _kMusicOn = 'settings.musicOn';
  static const String _kSfxOn = 'settings.sfxOn';
  static const String _kHapticsOn = 'settings.hapticsOn';
  static const String _kMusicVolume = 'settings.musicVolume';
  static const String _kSfxVolume = 'settings.sfxVolume';

  Future<void> setMusicOn({required bool value}) async {
    emit(state.copyWith(musicOn: value));
    await _prefs.setBool(_kMusicOn, value);
  }

  Future<void> setSfxOn({required bool value}) async {
    emit(state.copyWith(sfxOn: value));
    await _prefs.setBool(_kSfxOn, value);
  }

  Future<void> setHapticsOn({required bool value}) async {
    emit(state.copyWith(hapticsOn: value));
    await _prefs.setBool(_kHapticsOn, value);
  }

  Future<void> setMusicVolume(double value) async {
    emit(state.copyWith(musicVolume: value));
    await _prefs.setDouble(_kMusicVolume, value);
  }

  Future<void> setSfxVolume(double value) async {
    emit(state.copyWith(sfxVolume: value));
    await _prefs.setDouble(_kSfxVolume, value);
  }
}
