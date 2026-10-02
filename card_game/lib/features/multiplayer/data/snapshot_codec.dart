import 'package:card_game/features/game/data/game_state_codec.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';

/// JSON <-> [MatchSnapshot], plus the redaction that keeps hidden hands
/// off the wire. Used by both the server (encode) and the client (decode).
abstract class SnapshotCodec {
  /// Stand-in for a card the viewer must not see. Only ever counted.
  static const PlayingCard hiddenCard = PlayingCard(suit: Suit.clubs, rank: Rank.two);

  /// [state] as [viewer] may see it: own hand intact, every other hand
  /// reduced to a same-length list of [hiddenCard].
  static GameState redactFor(GameState state, Seat viewer) {
    return state.copyWith(
      hands: {
        for (final MapEntry<Seat, List<PlayingCard>> e in state.hands.entries)
          e.key: e.key == viewer ? e.value : List<PlayingCard>.filled(e.value.length, hiddenCard),
      },
    );
  }

  static Map<String, Object?> encode({
    required String matchId,
    required int version,
    required Seat viewer,
    required GameState game,
    required List<RoomSeatInfo> seats,
    required Map<int, int> roundStartScores,
    required Map<int, int> roundStartBags,
    required int turnDeadlineMs,
    required int nextRoundDeadlineMs,
    required Set<Seat> botControlled,
  }) {
    return {
      'type': S2C.snapshot,
      'matchId': matchId,
      'version': version,
      'mySeat': viewer.name,
      'game': GameStateCodec.encode(redactFor(game, viewer)),
      'seats': [for (final RoomSeatInfo s in seats) s.toJson()],
      'roundStartScores': GameStateCodec.encodeIntMap(roundStartScores),
      'roundStartBags': GameStateCodec.encodeIntMap(roundStartBags),
      'turnDeadlineMs': turnDeadlineMs,
      'nextRoundDeadlineMs': nextRoundDeadlineMs,
      'botControlled': [for (final Seat s in botControlled) s.name],
    };
  }

  /// Throws [FormatException] on anything malformed.
  static MatchSnapshot decode(Map<String, Object?> json) {
    try {
      final List<Object?> rawSeats = (json['seats']! as List).cast<Object?>();
      final List<Object?> rawBots = ((json['botControlled'] as List?) ?? const []).cast<Object?>();
      return MatchSnapshot(
        matchId: json['matchId']! as String,
        version: (json['version']! as num).toInt(),
        mySeat: Seat.values.byName(json['mySeat']! as String),
        game: GameStateCodec.decode((json['game']! as Map).cast<String, Object?>()),
        seats: [
          for (final Object? s in rawSeats) RoomSeatInfo.fromJson((s! as Map).cast<String, Object?>()),
        ],
        roundStartScores: GameStateCodec.decodeIntMap(json['roundStartScores']),
        roundStartBags: GameStateCodec.decodeIntMap(json['roundStartBags']),
        turnDeadlineMs: ((json['turnDeadlineMs'] as num?) ?? 0).toInt(),
        nextRoundDeadlineMs: ((json['nextRoundDeadlineMs'] as num?) ?? 0).toInt(),
        botControlled: {for (final Object? s in rawBots) Seat.values.byName(s! as String)},
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Corrupt snapshot: $e');
    }
  }

  // ---- Moves (client -> server) -------------------------------------------

  static Map<String, Object?> encodeBid(int tricks) => {'kind': 'bid', 'tricks': tricks};

  static Map<String, Object?> encodePlay(PlayingCard card) => {'kind': 'play', 'card': '${card.suit.name}.${card.rank.name}'};

  /// Parses the `move` payload into a card, or throws [FormatException].
  static PlayingCard parseCard(Object? raw) {
    if (raw is! String) throw const FormatException('card must be a string');
    final List<String> parts = raw.split('.');
    if (parts.length != 2) throw FormatException('Bad card: $raw');
    final Suit? suit = Suit.values.asNameMap()[parts[0]];
    final Rank? rank = Rank.values.asNameMap()[parts[1]];
    if (suit == null || rank == null) throw FormatException('Bad card: $raw');
    return PlayingCard(suit: suit, rank: rank);
  }
}
