import 'dart:convert';

import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/data/snapshot_codec.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _encode(GameState g, Seat viewer) => SnapshotCodec.encode(
      matchId: 'm1',
      version: 3,
      viewer: viewer,
      game: g,
      seats: [
        for (final Seat s in Seat.values)
          RoomSeatInfo(
            seat: s,
            name: 'P${s.index}',
            avatarId: 0,
            isBot: s != viewer,
            connected: true,
            isYou: s == viewer,
            isHost: false,
          ),
      ],
      roundStartScores: g.teamScores,
      roundStartBags: g.teamBags,
      turnDeadlineMs: 123,
      nextRoundDeadlineMs: 0,
      botControlled: {Seat.east},
    );

void main() {
  final GameState game = SpadesRulesEngine.newMatch(seed: 42);

  test('redaction hides every other hand but keeps its size', () {
    final GameState red = SnapshotCodec.redactFor(game, Seat.south);
    expect(red.hands[Seat.south], game.hands[Seat.south]);
    for (final Seat s in [Seat.north, Seat.east, Seat.west]) {
      expect(red.hands[s]!.length, 13);
      expect(red.hands[s]!.every((c) => c == SnapshotCodec.hiddenCard), isTrue);
    }
  });

  test('encoded JSON never contains an opponent card', () {
    final String json = jsonEncode(_encode(game, Seat.south));
    // Every card string an opponent really holds (except ones that also
    // happen to be in the viewer's own hand — impossible, one deck) must be absent.
    for (final Seat s in [Seat.north, Seat.east, Seat.west]) {
      for (final PlayingCard c in game.hands[s]!) {
        if (c == SnapshotCodec.hiddenCard) continue; // the placeholder itself
        expect(json.contains('"${c.suit.name}.${c.rank.name}"'), isFalse, reason: '$c leaked from $s');
      }
    }
  });

  test('round-trips through JSON', () {
    final MatchSnapshot snap = SnapshotCodec.decode(
      (jsonDecode(jsonEncode(_encode(game, Seat.west))) as Map).cast<String, Object?>(),
    );
    expect(snap.matchId, 'm1');
    expect(snap.version, 3);
    expect(snap.mySeat, Seat.west);
    expect(snap.turnDeadlineMs, 123);
    expect(snap.botControlled, {Seat.east});
    expect(snap.game.hands[Seat.west], game.hands[Seat.west]);
    expect(snap.game.phase, game.phase);
    expect(snap.seats.where((s) => s.isYou).single.seat, Seat.west);
  });

  test('malformed snapshots throw FormatException', () {
    expect(() => SnapshotCodec.decode({'type': 'snapshot'}), throwsFormatException);
    expect(() => SnapshotCodec.parseCard('nope'), throwsFormatException);
    expect(() => SnapshotCodec.parseCard('spades.eleventy'), throwsFormatException);
  });
}
