import 'dart:async';
import 'dart:convert';

import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/data/snapshot_codec.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../server/src/game_hub.dart';
import '../../../../server/src/match_session.dart';
import '../../../../server/src/session.dart';


/// A fake socket plus helpers, so tests talk to the hub exactly like a
/// real client would — JSON in, JSON out — with no network.
class FakeClient {
  FakeClient(this.hub) {
    conn = hub.attach(onSend: (s) => inbox.add((jsonDecode(s) as Map).cast<String, Object?>()), onClose: (c, r) async => closed = true);
  }

  final GameHub hub;
  late final ClientConnection conn;
  final List<Map<String, Object?>> inbox = [];
  bool closed = false;
  String? token;
  MatchSnapshot? lastSnapshot;

  Future<void> send(Map<String, Object?> m) => hub.onRaw(conn, jsonEncode(m));

  Future<void> hello({String name = 'Tester', String? tok}) async {
    await send({'type': C2S.hello, 'protocol': kProtocolVersion, 'name': name, 'avatarId': 1, 'token': tok});
    final Map<String, Object?>? w = last(S2C.welcome);
    token = w?['token'] as String?;
  }

  Map<String, Object?>? last(String type) {
    for (final Map<String, Object?> m in inbox.reversed) {
      if (m['type'] == type) return m;
    }
    return null;
  }

  List<Map<String, Object?>> all(String type) => [for (final m in inbox) if (m['type'] == type) m];

  MatchSnapshot? get snapshot {
    final Map<String, Object?>? m = last(S2C.snapshot);
    return m == null ? null : SnapshotCodec.decode(m);
  }

  /// Plays the first legal move whenever it is this client's turn.
  int _sentVersion = -1;

  void autoPlay() {
    final MatchSnapshot? s = snapshot;
    if (s == null || s.game.turn != s.mySeat || s.version == _sentVersion) return;
    _sentVersion = s.version;
    final Move? move = firstLegal(s);
    if (move == null) return;
    unawaited(send({
      'type': C2S.move,
      ...switch (move) {
        BidMove(tricksBid: final t) => SnapshotCodec.encodeBid(t),
        PlayCardMove(card: final c) => SnapshotCodec.encodePlay(c),
      },
    }));
  }

  static Move? firstLegal(MatchSnapshot s) {
    final g = s.game;
    if (g.phase == GamePhase.bidding) return BidMove(seat: s.mySeat, tricksBid: 3);
    if (g.phase != GamePhase.playing) return null;
    for (final PlayingCard c in g.hands[s.mySeat]!) {
      final m = PlayCardMove(seat: s.mySeat, card: c);
      if (SpadesRulesEngine.isValidMove(g, m)) return m;
    }
    return null;
  }
}

Future<void> until(bool Function() cond, {Duration timeout = const Duration(seconds: 20), String what = 'condition'}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

GameHub makeHub({Duration quickFill = const Duration(seconds: 999), bool strictRate = false}) => GameHub(
      // Tests fire bursts far faster than any human; only the abuse test
      // uses the real limits.
      rateCapacity: strictRate ? 30 : 100000,
      rateRefillPerSecond: strictRate ? 15.0 : 100000.0,
      timings: MatchTimings.instant,
      quickMatchFill: quickFill,
      roomDisconnectGrace: const Duration(milliseconds: 50),
    );

/// Starts a private room with [client] as the only human; returns once the
/// first snapshot has arrived.
Future<void> startSoloMatch(FakeClient client) async {
  await client.send({'type': C2S.createRoom});
  await client.send({'type': C2S.startMatch});
  await until(() => client.last(S2C.snapshot) != null, what: 'first snapshot');
}

void main() {
  group('identity', () {
    test('hello issues a token; the same token returns the same player', () async {
      final GameHub hub = makeHub();
      final FakeClient a = FakeClient(hub);
      await a.hello(name: 'Alice');
      expect(a.token, isNotNull);
      final String id = a.last(S2C.welcome)!['playerId']! as String;

      final FakeClient b = FakeClient(hub);
      await b.hello(name: 'Alice', tok: a.token);
      expect(b.last(S2C.welcome)!['playerId'], id);
      expect(a.closed, isTrue, reason: 'old socket is replaced by the new one');
    });

    test('wrong protocol version is rejected', () async {
      final FakeClient c = FakeClient(makeHub());
      await c.send({'type': C2S.hello, 'protocol': 999, 'name': 'x'});
      expect(c.last(S2C.error)!['code'], ErrorCode.protocol);
      expect(c.closed, isTrue);
    });

    test('commands before hello are refused; garbage does not crash', () async {
      final FakeClient c = FakeClient(makeHub());
      await c.send({'type': C2S.quickMatch});
      expect(c.last(S2C.error)!['code'], ErrorCode.authFailed);
      await c.hub.onRaw(c.conn, 'not json');
      await c.hub.onRaw(c.conn, '[1,2]');
      expect(c.all(S2C.error).length, 3);
    });

    test('names are sanitised', () {
      expect(GameHub.sanitizeName('  Bob\n\t  the   Builder  '), 'Bob the Builder');
      expect(GameHub.sanitizeName(''), 'Player');
      expect(GameHub.sanitizeName(null), 'Player');
      expect(GameHub.sanitizeName('x' * 100).length, 16);
    });
  });

  group('rooms', () {
    test('create, join by code, host-only start', () async {
      final GameHub hub = makeHub();
      final FakeClient host = FakeClient(hub);
      await host.hello(name: 'Host');
      final FakeClient guest = FakeClient(hub);
      await guest.hello(name: 'Guest');

      await host.send({'type': C2S.createRoom});
      final String code = host.last(S2C.roomUpdate)!['code']! as String;
      expect(code.length, kRoomCodeLength);

      await guest.send({'type': C2S.joinRoom, 'code': code.toLowerCase()});
      expect(guest.last(S2C.roomUpdate)!['code'], code);

      await guest.send({'type': C2S.startMatch});
      expect(guest.last(S2C.error)!['code'], ErrorCode.notHost);

      await host.send({'type': C2S.startMatch});
      expect(host.last(S2C.matchStarted), isNotNull);
      expect(guest.last(S2C.matchStarted), isNotNull);
      expect(hub.roomCount, 0);
      expect(hub.matchCount, 1);
    });

    test('unknown code and full room produce errors', () async {
      final GameHub hub = makeHub();
      final FakeClient host = FakeClient(hub);
      await host.hello();
      await host.send({'type': C2S.createRoom});
      final String code = host.last(S2C.roomUpdate)!['code']! as String;

      final FakeClient lost = FakeClient(hub);
      await lost.hello();
      await lost.send({'type': C2S.joinRoom, 'code': 'ZZZZ'});
      expect(lost.last(S2C.error)!['code'], ErrorCode.roomNotFound);

      for (int i = 0; i < 3; i++) {
        final FakeClient f = FakeClient(hub);
        await f.hello(name: 'F$i');
        await f.send({'type': C2S.joinRoom, 'code': code});
      }
      await lost.send({'type': C2S.joinRoom, 'code': code});
      expect(lost.last(S2C.error)!['code'], ErrorCode.roomFull);
    });

    test('leaving hands the host role on; last one out closes the room', () async {
      final GameHub hub = makeHub();
      final FakeClient a = FakeClient(hub);
      final FakeClient b = FakeClient(hub);
      await a.hello(name: 'A');
      await b.hello(name: 'B');
      await a.send({'type': C2S.createRoom});
      final String code = a.last(S2C.roomUpdate)!['code']! as String;
      await b.send({'type': C2S.joinRoom, 'code': code});

      await a.send({'type': C2S.leaveRoom});
      final seats = (b.last(S2C.roomUpdate)!['seats']! as List).cast<Map>();
      expect(seats.where((s) => s['isHost'] == true && s['isYou'] == true), hasLength(1));

      await b.send({'type': C2S.leaveRoom});
      expect(hub.roomCount, 0);
    });
  });

  group('matchmaking', () {
    test('four queued players are grouped with no bots', () async {
      final GameHub hub = makeHub();
      final List<FakeClient> clients = [for (int i = 0; i < 4; i++) FakeClient(hub)];
      for (final (int i, FakeClient c) in clients.indexed) {
        await c.hello(name: 'P$i');
        await c.send({'type': C2S.quickMatch});
      }
      expect(hub.matchCount, 1);
      expect(hub.queueLength, 0);
      for (final FakeClient c in clients) {
        await until(() => c.last(S2C.snapshot) != null, what: 'snapshot');
      }
      final Set<Seat> seats = {for (final c in clients) c.snapshot!.mySeat};
      expect(seats, hasLength(4), reason: 'everyone gets a different seat');
      expect(clients.first.snapshot!.seats.where((s) => s.isBot), isEmpty);
    });

    test('a lone player is filled with bots after the wait', () async {
      final GameHub hub = makeHub(quickFill: Duration.zero);
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await c.send({'type': C2S.quickMatch});
      hub.tick();
      expect(hub.matchCount, 1);
      await until(() => c.last(S2C.snapshot) != null, what: 'snapshot');
      expect(c.snapshot!.seats.where((s) => s.isBot), hasLength(3));
    });

    test('cancelling leaves the queue', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await c.send({'type': C2S.quickMatch});
      expect(hub.queueLength, 1);
      await c.send({'type': C2S.cancelQueue});
      expect(hub.queueLength, 0);
    });
  });

  group('authoritative match', () {
    test('snapshots never contain other seats\' real cards', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);

      final MatchSnapshot s = c.snapshot!;
      final String raw = jsonEncode(c.last(S2C.snapshot));
      final real = hub.matchById(s.matchId)!.game.hands;
      for (final Seat other in Seat.values.where((x) => x != s.mySeat)) {
        expect(s.game.hands[other]!.every((card) => card == SnapshotCodec.hiddenCard), isTrue);
        for (final PlayingCard card in real[other]!) {
          if (card == SnapshotCodec.hiddenCard) continue;
          expect(raw.contains('"${card.suit.name}.${card.rank.name}"'), isFalse);
        }
      }
    });

    test('illegal, out-of-turn and malformed moves are rejected; legal ones accepted', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);

      // Wait for our turn to bid (bots in front of us bid instantly).
      await until(() => c.snapshot != null && c.snapshot!.game.turn == c.snapshot!.mySeat, what: 'my turn');
      final int v0 = c.snapshot!.version;

      await c.send({'type': C2S.move, 'kind': 'bid', 'tricks': 99});
      expect(c.last(S2C.error)!['code'], ErrorCode.illegalMove);
      await c.send({'type': C2S.move, 'kind': 'bid', 'tricks': 'three'});
      expect(c.last(S2C.error)!['code'], ErrorCode.badRequest);
      await c.send({'type': C2S.move, 'kind': 'play', 'card': 'spades.ace'});
      expect(c.last(S2C.error)!['code'], ErrorCode.illegalMove, reason: 'cannot play a card during bidding');

      await c.send({'type': C2S.move, 'kind': 'bid', 'tricks': 4});
      await until(() => c.snapshot!.version > v0, what: 'bid applied');
      expect(c.snapshot!.game.bids[c.snapshot!.mySeat], 4);

      // A move now (not our turn, or bidding over) must not be accepted twice.
      final int errors = c.all(S2C.error).length;
      await c.send({'type': C2S.move, 'kind': 'bid', 'tricks': 4});
      expect(c.all(S2C.error).length, errors + 1);
    });

    test('a claimed seat in the payload is ignored', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);
      await until(() => c.snapshot!.game.turn == c.snapshot!.mySeat, what: 'my turn');
      final Seat me = c.snapshot!.mySeat;
      await c.send({'type': C2S.move, 'kind': 'bid', 'tricks': 2, 'seat': me.next.name});
      await until(() => c.snapshot!.game.bids[me] != null, what: 'bid recorded');
      expect(c.snapshot!.game.bids[me], 2);
    });

    test('a complete match finishes with a winner (one human, three bots)', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);

      final Timer driver = Timer.periodic(const Duration(milliseconds: 2), (_) => c.autoPlay());
      addTearDown(driver.cancel);
      await until(
        () => c.snapshot?.game.phase == GamePhase.matchOver,
        timeout: const Duration(seconds: 90),
        what: 'match to finish',
      );
      final g = c.snapshot!.game;
      expect(g.winningTeam, isNotNull);
      expect(g.teamScores[g.winningTeam!]!, greaterThanOrEqualTo(kMatchWinningScore));
    });

    test('a disconnected player is covered by a bot, then can reconnect', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello(name: 'Dropper');
      await startSoloMatch(c);
      final String token = c.token!;
      final String matchId = c.snapshot!.matchId;
      final Seat seat = c.snapshot!.mySeat;

      hub.onClosed(c.conn);
      final match = hub.matchById(matchId)!;
      // With nobody connected, bots keep the game moving past our seat.
      await until(() => match.version > 8 || match.game.phase == GamePhase.playing, what: 'bots to continue');
      await until(() => match.game.hands[seat]!.length < 13, what: 'bot to play our seat');

      final FakeClient back = FakeClient(hub);
      await back.hello(name: 'Dropper', tok: token);
      expect(back.last(S2C.matchStarted)!['matchId'], matchId);
      await until(() => back.last(S2C.snapshot) != null, what: 'resync snapshot');
      expect(back.snapshot!.mySeat, seat);
    });

    test('leaving the match hands the seat to a bot and ends it when nobody is left', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);
      await c.send({'type': C2S.leaveMatch});
      expect(hub.matchCount, 0);
    });

    test('emotes are whitelisted', () async {
      final GameHub hub = makeHub();
      final FakeClient c = FakeClient(hub);
      await c.hello();
      await startSoloMatch(c);
      await c.send({'type': C2S.emote, 'id': 'free text chat'});
      expect(c.last(S2C.emote), isNull);
      await c.send({'type': C2S.emote, 'id': 'gg'});
      expect(c.last(S2C.emote)!['id'], 'gg');
    });
  });

  group('abuse protection', () {
    test('a flood of messages is rate limited', () async {
      final FakeClient c = FakeClient(makeHub(strictRate: true));
      await c.hello();
      for (int i = 0; i < 200; i++) {
        await c.send({'type': C2S.ping});
      }
      expect(c.all(S2C.error).any((e) => e['code'] == ErrorCode.rateLimited), isTrue);
    });

    test('oversized frames close the socket', () async {
      final FakeClient c = FakeClient(makeHub());
      await c.hello();
      await c.hub.onRaw(c.conn, 'x' * 10000);
      expect(c.closed, isTrue);
    });
  });
}
