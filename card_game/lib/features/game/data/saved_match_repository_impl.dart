import 'dart:convert';

import 'package:card_game/core/storage/local_store.dart';
import 'package:card_game/features/game/data/game_state_codec.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/game/domain/repositories/saved_match_repository.dart';

class SavedMatchRepositoryImpl implements SavedMatchRepository {
  SavedMatchRepositoryImpl({required LocalStore store}) : _store = store;

  final LocalStore _store;

  static const String _key = 'match.inProgress';

  @override
  Future<SavedMatch?> load() async {
    final String? raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Saved match is not a JSON object');
      final SavedMatch match = SavedMatchCodec.decode(decoded.cast<String, Object?>());
      // A finished match is never resumable; treat a stale one as absent.
      if (match.game.phase == GamePhase.matchOver) {
        await clear();
        return null;
      }
      return match;
    } on Object {
      // Corrupt or from an incompatible app version: drop it so the player
      // is never stuck with a "Resume" button that can't resume.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(SavedMatch match) => _store.write(_key, jsonEncode(SavedMatchCodec.encode(match)));

  @override
  Future<void> clear() => _store.delete(_key);
}
