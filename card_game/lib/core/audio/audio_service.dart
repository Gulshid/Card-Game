import 'package:audioplayers/audioplayers.dart';

/// Every distinct game moment that has a sound. Kept as an enum (rather
/// than passing raw asset strings around the app) so a typo in an asset
/// path is a compile error, not a silent no-op at runtime.
enum SfxCue {
  cardDeal('audio/sfx/card_deal.wav'),
  cardPlace('audio/sfx/card_place.wav'),
  invalidMove('audio/sfx/invalid_move.wav'),
  bidConfirm('audio/sfx/bid_confirm.wav'),
  trickWin('audio/sfx/trick_win.wav'),
  roundWin('audio/sfx/round_win.wav'),
  roundLose('audio/sfx/round_lose.wav'),
  matchWin('audio/sfx/match_win.wav'),
  matchLose('audio/sfx/match_lose.wav'),
  buttonTap('audio/sfx/button_tap.wav');

  const SfxCue(this.assetPath);

  final String assetPath;
}

/// Background music tracks. Only one plays at a time.
enum MusicTrack {
  tableAmbience('audio/music/table_ambience.wav');

  const MusicTrack(this.assetPath);

  final String assetPath;
}

/// Thin wrapper around `audioplayers` so the rest of the app never talks
/// to the plugin directly.
///
/// Two independent players: [_music] loops a background track at low
/// volume; [_sfx] fires one-shot cues and — because `audioplayers` lets
/// the same player be told to play a new source before the last one
/// finishes — two SFX in quick succession (e.g. a bot playing two cards
/// back to back) correctly overlap rather than cutting each other off.
///
/// The Phase 08 audio assets under `assets/audio/` are placeholder
/// tones I synthesized (sine/triangle/square waves), not produced or
/// licensed audio — see `PHASE_07_08_NOTES.md` for what to swap in.
class AudioService {
  AudioService()
      : _music = AudioPlayer(playerId: 'music'),
        _sfx = AudioPlayer(playerId: 'sfx');

  final AudioPlayer _music;
  final AudioPlayer _sfx;

  bool _musicOn = true;
  bool _sfxOn = true;
  double _musicVolume = 0.7;
  double _sfxVolume = 0.9;
  MusicTrack? _currentTrack;

  /// Called from the app-level `BlocListener<SettingsCubit, ...>` any
  /// time the player changes a setting, so a slider drag is audible
  /// immediately.
  Future<void> applySettings({
    required bool musicOn,
    required bool sfxOn,
    required double musicVolume,
    required double sfxVolume,
  }) async {
    final bool musicJustEnabled = musicOn && !_musicOn;
    _musicOn = musicOn;
    _sfxOn = sfxOn;
    _musicVolume = musicVolume;
    _sfxVolume = sfxVolume;

    await _music.setVolume(musicOn ? musicVolume : 0);
    await _sfx.setVolume(sfxVolume);

    if (!musicOn) {
      await _music.pause();
    } else if (musicJustEnabled && _currentTrack != null) {
      await _music.resume();
    }
  }

  bool get isMusicOn => _musicOn;
  bool get isSfxOn => _sfxOn;

  /// Plays [cue] once. Silently does nothing if SFX are muted — call
  /// sites never need to check [isSfxOn] themselves.
  Future<void> play(SfxCue cue) async {
    if (!_sfxOn) return;
    try {
      await _sfx.play(AssetSource(cue.assetPath), volume: _sfxVolume);
    } catch (_) {
      // A missing/corrupt asset should never crash a card game over a
      // sound effect — this is deliberately swallowed rather than
      // rethrown. (Real crash reporting hooks in during Phase 12.)
    }
  }

  /// Starts [track] looping. Safe to call again with the same track
  /// (no-op restart avoided) or a different one (crossfades are a
  /// Phase 09+ nicety; this does a plain stop-then-start for now).
  Future<void> playMusic(MusicTrack track) async {
    if (_currentTrack == track) return;
    _currentTrack = track;
    if (!_musicOn) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource(track.assetPath), volume: _musicVolume);
    } catch (_) {
      // Same reasoning as `play`: never let a missing music asset crash the app.
    }
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    await _music.stop();
  }

  Future<void> dispose() async {
    await _music.dispose();
    await _sfx.dispose();
  }
}
