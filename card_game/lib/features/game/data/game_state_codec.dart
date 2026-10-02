import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';

/// JSON <-> [GameState] conversion, kept in the data layer so the pure
/// engine models stay free of serialization concerns.
///
/// The encoded form contains only `String`/`int`/`bool`/`null`/`List`/
/// `Map<String, …>`, so it survives `jsonEncode`/`jsonDecode` unchanged.
/// A schema [schemaVersion] is embedded: if the format ever changes, old
/// saves are rejected with a [FormatException] (and discarded by the
/// repository) instead of being half-parsed into a corrupt match.
///
/// `decode` throws [FormatException] for *any* malformed input — callers
/// need exactly one `catch` to be safe.
abstract class GameStateCodec {
  static const int schemaVersion = 1;

  // ---- GameState ------------------------------------------------------

  static Map<String, Object?> encode(GameState s) {
    return {
      'v': schemaVersion,
      'phase': s.phase.name,
      'dealer': s.dealer.name,
      'turn': s.turn.name,
      'leader': s.leader.name,
      'hands': {
        for (final MapEntry<Seat, List<PlayingCard>> e in s.hands.entries)
          e.key.name: [for (final PlayingCard c in e.value) _encodeCard(c)],
      },
      'bids': {
        for (final MapEntry<Seat, int?> e in s.bids.entries) e.key.name: e.value,
      },
      'currentTrick': _encodeTrick(s.currentTrick),
      'completedTricks': [for (final List<TrickCard> t in s.completedTricks) _encodeTrick(t)],
      'tricksWonBySeat': {
        for (final MapEntry<Seat, int> e in s.tricksWonBySeat.entries) e.key.name: e.value,
      },
      'spadesBroken': s.spadesBroken,
      'teamScores': encodeIntMap(s.teamScores),
      'teamBags': encodeIntMap(s.teamBags),
      'roundNumber': s.roundNumber,
      'winningTeam': s.winningTeam,
    };
  }

  static GameState decode(Map<String, Object?> json) {
    try {
      if (json['v'] != schemaVersion) {
        throw FormatException('Unsupported game-state version: ${json['v']}');
      }

      final Map<Seat, List<PlayingCard>> hands = _seatMap(
        json['hands'],
        (Object? v) => [for (final Object? c in _list(v)) _parseCard(c)],
      );
      final Map<Seat, int?> bids = _seatMap<int?>(
        json['bids'],
        (Object? v) => v == null ? null : (v as num).toInt(),
      );
      if (hands.length != Seat.values.length || bids.length != Seat.values.length) {
        throw const FormatException('Game state is missing a seat');
      }

      return GameState(
        phase: GamePhase.values.byName(json['phase']! as String),
        dealer: Seat.values.byName(json['dealer']! as String),
        turn: Seat.values.byName(json['turn']! as String),
        leader: Seat.values.byName(json['leader']! as String),
        hands: hands,
        bids: bids,
        currentTrick: _parseTrick(json['currentTrick']),
        completedTricks: [for (final Object? t in _list(json['completedTricks'])) _parseTrick(t)],
        tricksWonBySeat: _seatMap<int>(json['tricksWonBySeat'], (Object? v) => (v! as num).toInt()),
        spadesBroken: json['spadesBroken']! as bool,
        teamScores: decodeIntMap(json['teamScores']),
        teamBags: decodeIntMap(json['teamBags']),
        roundNumber: (json['roundNumber']! as num).toInt(),
        winningTeam: (json['winningTeam'] as num?)?.toInt(),
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Corrupt game state: $e');
    }
  }

  // ---- Shared helpers (also used by SavedMatchCodec) -------------------

  static Map<String, int> encodeIntMap(Map<int, int> map) => {
        for (final MapEntry<int, int> e in map.entries) '${e.key}': e.value,
      };

  static Map<int, int> decodeIntMap(Object? raw) => {
        for (final MapEntry<String, Object?> e in _map(raw).entries) int.parse(e.key): (e.value! as num).toInt(),
      };

  // ---- Internals ----------------------------------------------------------

  static String _encodeCard(PlayingCard c) => '${c.suit.name}.${c.rank.name}';

  static PlayingCard _parseCard(Object? raw) {
    final List<String> parts = (raw! as String).split('.');
    if (parts.length != 2) throw FormatException('Bad card: $raw');
    return PlayingCard(suit: Suit.values.byName(parts[0]), rank: Rank.values.byName(parts[1]));
  }

  static List<Map<String, String>> _encodeTrick(List<TrickCard> trick) => [
        for (final TrickCard tc in trick) {'seat': tc.seat.name, 'card': _encodeCard(tc.card)},
      ];

  static List<TrickCard> _parseTrick(Object? raw) => [
        for (final Object? item in _list(raw))
          TrickCard(
            seat: Seat.values.byName(_map(item)['seat']! as String),
            card: _parseCard(_map(item)['card']),
          ),
      ];

  static Map<String, Object?> _map(Object? v) {
    if (v is Map) return v.cast<String, Object?>();
    throw FormatException('Expected a JSON object, got ${v.runtimeType}');
  }

  static List<Object?> _list(Object? v) {
    if (v is List) return v.cast<Object?>();
    throw FormatException('Expected a JSON array, got ${v.runtimeType}');
  }

  static Map<Seat, T> _seatMap<T>(Object? raw, T Function(Object?) parse) => {
        for (final MapEntry<String, Object?> e in _map(raw).entries) Seat.values.byName(e.key): parse(e.value),
      };
}

/// JSON <-> [SavedMatch]; wraps [GameStateCodec] with the extra fields.
abstract class SavedMatchCodec {
  static const int schemaVersion = 1;

  static Map<String, Object?> encode(SavedMatch m) {
    return {
      'v': schemaVersion,
      'game': GameStateCodec.encode(m.game),
      'difficulty': m.difficulty.name,
      'roundStartScores': GameStateCodec.encodeIntMap(m.roundStartScores),
      'roundStartBags': GameStateCodec.encodeIntMap(m.roundStartBags),
      'nilsMade': m.nilsMade,
      'savedAt': m.savedAt.toIso8601String(),
    };
  }

  static SavedMatch decode(Map<String, Object?> json) {
    try {
      if (json['v'] != schemaVersion) {
        throw FormatException('Unsupported saved-match version: ${json['v']}');
      }
      return SavedMatch(
        game: GameStateCodec.decode((json['game']! as Map).cast<String, Object?>()),
        difficulty: AiDifficulty.values.byName(json['difficulty']! as String),
        roundStartScores: GameStateCodec.decodeIntMap(json['roundStartScores']),
        roundStartBags: GameStateCodec.decodeIntMap(json['roundStartBags']),
        nilsMade: (json['nilsMade'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.parse(json['savedAt']! as String),
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Corrupt saved match: $e');
    }
  }
}
