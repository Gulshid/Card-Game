import 'package:audioplayers/audioplayers.dart';

/// Thin wrapper around `audioplayers` so the rest of the app never
/// talks to the plugin directly. Phase 08 adds real SFX/music assets
/// and calls like `playCardPlace()`, `playTrickWin()`; for now this
/// exposes only what `main.dart`'s settings listener needs.
class AudioService {
  AudioService()
      : _music = AudioPlayer(playerId: 'music'),
        _sfx = AudioPlayer(playerId: 'sfx');

  final AudioPlayer _music;
  final AudioPlayer _sfx;

  bool _musicOn = true;
  bool _sfxOn = true;

  /// Called from the app-level `BlocListener<SettingsCubit, ...>` any
  /// time the player changes a setting, so a slider drag is audible
  /// immediately — same pattern as your old app.
  Future<void> applySettings({
    required bool musicOn,
    required bool sfxOn,
    required double musicVolume,
    required double sfxVolume,
  }) async {
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    await _music.setVolume(musicOn ? musicVolume : 0);
    await _sfx.setVolume(sfxVolume);
    if (!musicOn) {
      await _music.pause();
    }
  }

  bool get isMusicOn => _musicOn;
  bool get isSfxOn => _sfxOn;

  Future<void> dispose() async {
    await _music.dispose();
    await _sfx.dispose();
  }
}
