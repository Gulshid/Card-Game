import 'package:card_game/core/audio/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SfxCue / MusicTrack', () {
    test('every cue has a non-empty asset path under assets/audio/sfx/', () {
      for (final cue in SfxCue.values) {
        expect(cue.assetPath, startsWith('audio/sfx/'));
        expect(cue.assetPath, endsWith('.wav'));
      }
    });

    test('every track has a non-empty asset path under assets/audio/music/', () {
      for (final track in MusicTrack.values) {
        expect(track.assetPath, startsWith('audio/music/'));
      }
    });

    test('no two cues share the same asset path', () {
      final paths = SfxCue.values.map((c) => c.assetPath).toSet();
      expect(paths.length, SfxCue.values.length);
    });
  });

  group('AudioService.applySettings', () {
    test('isMusicOn / isSfxOn reflect the last applied settings', () async {
      final service = AudioService();
      await service.applySettings(musicOn: false, sfxOn: true, musicVolume: 0.5, sfxVolume: 0.5);
      expect(service.isMusicOn, isFalse);
      expect(service.isSfxOn, isTrue);

      await service.applySettings(musicOn: true, sfxOn: false, musicVolume: 0.5, sfxVolume: 0.5);
      expect(service.isMusicOn, isTrue);
      expect(service.isSfxOn, isFalse);

      await service.dispose();
    });
  });

  group('AudioService playback never throws, even without a real audio backend', () {
    // This sandbox (and any plain `flutter test` run without platform
    // channel mocks) has no real audio output — every play/music call
    // is wrapped in try/catch specifically so a missing platform
    // implementation or asset never crashes the game over a sound
    // effect. These tests assert that contract, not that sound is
    // actually audible (which `flutter test` cannot check anyway).
    test('play() on every cue completes without throwing', () async {
      final service = AudioService();
      for (final cue in SfxCue.values) {
        await expectLater(service.play(cue), completes);
      }
      await service.dispose();
    });

    test('play() is a safe no-op once SFX are muted', () async {
      final service = AudioService();
      await service.applySettings(musicOn: true, sfxOn: false, musicVolume: 0.7, sfxVolume: 0.9);
      await expectLater(service.play(SfxCue.cardPlace), completes);
      await service.dispose();
    });

    test('playMusic / stopMusic complete without throwing', () async {
      final service = AudioService();
      await expectLater(service.playMusic(MusicTrack.tableAmbience), completes);
      await expectLater(service.stopMusic(), completes);
      await service.dispose();
    });

    test('playMusic called twice with the same track is a cheap no-op the second time', () async {
      final service = AudioService();
      await service.playMusic(MusicTrack.tableAmbience);
      // Should return immediately without attempting to restart playback.
      await expectLater(service.playMusic(MusicTrack.tableAmbience), completes);
      await service.dispose();
    });
  });
}
