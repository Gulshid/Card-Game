import 'dart:async';
import 'dart:math';

import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/ai/ai_factory.dart';
import 'package:card_game/features/game/domain/ai/ai_strategy.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/data/snapshot_codec.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';

import 'session.dart';

/// Every delay the server applies. Production values by default; tests
/// use [MatchTimings.instant] so whole matches finish in milliseconds.
class MatchTimings {
  const MatchTimings({
    this.botThink = const Duration(milliseconds: 700),
    this.trickPause = const Duration(milliseconds: 1400),
    this.turnLimit = const Duration(seconds: kTurnTimeLimitSeconds),
    this.afkLimit = const Duration(seconds: 10),
    this.roundBreak = const Duration(seconds: kRoundBreakSeconds),
    this.disconnectGrace = const Duration(seconds: kDisconnectGraceSeconds),
    this.abandonAfter = const Duration(minutes: 2),
    this.finishedLinger = const Duration(seconds: 90),
  });

  static const MatchTimings standard = MatchTimings();

  static const MatchTimings instant = MatchTimings(
    botThink: Duration.zero,
    trickPause: Duration.zero,
    turnLimit: Duration(seconds: 5),
    afkLimit: Duration(seconds: 2),
    roundBreak: Duration.zero,
    disconnectGrace: Duration(milliseconds: 50),
    abandonAfter: Duration(seconds: 5),
    finishedLinger: Duration(seconds: 5),
  );

  final Duration botThink;
  final Duration trickPause;
  final Duration turnLimit;
  final Duration afkLimit;
  final Duration roundBreak;
  final Duration disconnectGrace;
  final Duration abandonAfter;
  final Duration finishedLinger;
}

/// One chair at a running match: a human, or a bot.
class MatchSeat {
  MatchSeat.human({required this.seat, required PlayerSession this.player})
      : name = player.name,
        avatarId = player.avatarId,
        isBot = false;

  MatchSeat.bot({required this.seat, required this.name, this.avatarId = 0})
      : player = null,
        isBot = true;

  final Seat seat;
  final PlayerSession? player;
  final String name;
  final int avatarId;
  final bool isBot;

  /// A human who chose to leave: their seat is bot-played for good.
  bool left = false;
  DateTime? disconnectedAt;
  int idleStrikes = 0;
  bool readyNext = false;

  bool get isHuman => !isBot;
  bool get connected => isHuman && !left && (player?.isConnected ?? false);
}

/// The server's authoritative copy of one match.
///
/// The client never tells the server what the state is — only what it
/// wants to *do*. Every move passes through `SpadesRulesEngine.isValidMove`
/// against this object's own [game] before it is applied, with the seat
/// taken from the authenticated connection rather than from the message.
/// Hidden hands never leave this class: each client receives a snapshot
/// redacted for its own seat (see `SnapshotCodec.redactFor`).
class MatchSession {
  MatchSession({
    required this.id,
    required List<MatchSeat> seats,
    required this.onFinished,
    this.timings = MatchTimings.standard,
    this.botDifficulty = AiDifficulty.medium,
    Random? random,
    DateTime Function()? clock,
  })  : assert(seats.length == 4, 'a Spades match always has four seats'),
        _seats = {for (final MatchSeat s in seats) s.seat: s},
        _random = random ?? Random(),
        _clock = clock ?? DateTime.now {
    _strategy = createAiStrategy(botDifficulty, random: _random);
    game = SpadesRulesEngine.newMatch(
      dealer: Seat.values[_random.nextInt(4)],
      seed: _random.nextInt(0x7fffffff),
    );
    roundStartScores = game.teamScores;
    roundStartBags = game.teamBags;
  }

  final String id;
  final MatchTimings timings;
  final AiDifficulty botDifficulty;
  final void Function(MatchSession session, String reason) onFinished;

  final Map<Seat, MatchSeat> _seats;
  final Random _random;
  final DateTime Function() _clock;
  late final AiStrategy _strategy;

  late GameState game;
  late Map<int, int> roundStartScores;
  late Map<int, int> roundStartBags;
  int version = 1;

  Timer? _timer;
  Timer? _abandonTimer;
  DateTime _pacingUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _turnDeadlineMs = 0;
  int _nextRoundDeadlineMs = 0;
  bool _finished = false;

  bool get isFinished => _finished;
  Iterable<MatchSeat> get seats => _seats.values;
  Iterable<PlayerSession> get humanPlayers => [
        for (final MatchSeat s in _seats.values)
          if (s.player != null) s.player!,
      ];

  // ---- Lifecycle ------------------------------------------------------------

  void start() {
    _afterChange();
  }

  /// Seat occupied by [player], or `null` if they are not in this match.
  MatchSeat? seatOf(PlayerSession player) {
    for (final MatchSeat s in _seats.values) {
      if (s.player?.id == player.id) return s;
    }
    return null;
  }

  void dispose() {
    _finished = true;
    _timer?.cancel();
    _abandonTimer?.cancel();
  }

  void _finish(String reason) {
    if (_finished) return;
    dispose();
    for (final MatchSeat s in _seats.values) {
      if (s.isHuman && !s.left) {
        s.player?.send({'type': S2C.matchEnded, 'matchId': id, 'reason': reason});
      }
    }
    onFinished(this, reason);
  }

  // ---- Inbound events -----------------------------------------------------------

  /// A human submits a move. Returns an [ErrorCode] on rejection, `null` on
  /// success. The *seat* always comes from the connection, never the payload.
  String? handleMove(PlayerSession player, Map<String, Object?> payload) {
    if (_finished) return ErrorCode.notInMatch;
    final MatchSeat? ms = seatOf(player);
    if (ms == null || ms.left) return ErrorCode.notInMatch;
    if (game.phase != GamePhase.bidding && game.phase != GamePhase.playing) return ErrorCode.illegalMove;
    if (game.turn != ms.seat) return ErrorCode.notYourTurn;

    final Move? move = _parseMove(ms.seat, payload);
    if (move == null) return ErrorCode.badRequest;
    if (!SpadesRulesEngine.isValidMove(game, move)) return ErrorCode.illegalMove;

    ms.idleStrikes = 0;
    _applyMove(move);
    return null;
  }

  /// A human is ready to skip the remaining round-break countdown.
  void handleReadyNext(PlayerSession player) {
    final MatchSeat? ms = seatOf(player);
    if (_finished || ms == null || ms.left || game.phase != GamePhase.roundEnd) return;
    ms.readyNext = true;
    _afterChange();
  }

  void handleEmote(PlayerSession player, String emoteId) {
    final MatchSeat? ms = seatOf(player);
    if (_finished || ms == null || ms.left || !kEmoteIds.contains(emoteId)) return;
    final DateTime now = _clock();
    if (now.difference(player.lastEmote) < const Duration(seconds: 1)) return;
    player.lastEmote = now;
    for (final MatchSeat other in _seats.values) {
      if (other.isHuman && !other.left) {
        other.player?.send({'type': S2C.emote, 'seat': ms.seat.name, 'id': emoteId});
      }
    }
  }

  void onPlayerDisconnected(PlayerSession player) {
    final MatchSeat? ms = seatOf(player);
    if (_finished || ms == null || ms.left) return;
    ms.disconnectedAt = _clock();
    if (!_seats.values.any((s) => s.connected)) {
      _abandonTimer?.cancel();
      _abandonTimer = Timer(timings.abandonAfter, () => _finish('abandoned'));
    }
    _afterChange();
  }

  void onPlayerReconnected(PlayerSession player) {
    final MatchSeat? ms = seatOf(player);
    if (_finished || ms == null || ms.left) return;
    ms.disconnectedAt = null;
    ms.idleStrikes = 0;
    _abandonTimer?.cancel();
    player.send({'type': S2C.matchStarted, 'matchId': id});
    _afterChange();
  }

  /// A human quits for good. Their seat is bot-played from now on; if no
  /// human remains the match is discarded.
  void onPlayerLeft(PlayerSession player) {
    final MatchSeat? ms = seatOf(player);
    if (_finished || ms == null || ms.left) return;
    ms.left = true;
    if (!_seats.values.any((s) => s.isHuman && !s.left)) {
      _finish(game.phase == GamePhase.matchOver ? 'finished' : 'abandoned');
      return;
    }
    _afterChange();
  }

  // ---- Move application -------------------------------------------------------

  Move? _parseMove(Seat seat, Map<String, Object?> payload) {
    final Object? kind = payload['kind'];
    if (kind == 'bid') {
      final Object? tricks = payload['tricks'];
      if (tricks is! int) return null;
      return BidMove(seat: seat, tricksBid: tricks);
    }
    if (kind == 'play') {
      try {
        return PlayCardMove(seat: seat, card: SnapshotCodec.parseCard(payload['card']));
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  void _applyMove(Move move) {
    final GameState before = game;
    game = SpadesRulesEngine.applyMove(before, move); // throws if illegal
    version++;
    if (game.completedTricks.length > before.completedTricks.length) {
      // Clients hold a finished trick on screen for a moment; don't let a
      // bot's reply cut that short.
      _pacingUntil = _clock().add(timings.trickPause);
    }
    _afterChange();
  }

  void _dealNextRound() {
    if (_finished || game.phase != GamePhase.roundEnd) return;
    game = SpadesRulesEngine.startNextRound(game, seed: _random.nextInt(0x7fffffff));
    roundStartScores = game.teamScores;
    roundStartBags = game.teamBags;
    version++;
    for (final MatchSeat s in _seats.values) {
      s.readyNext = false;
    }
    _afterChange();
  }

  void _afterChange() {
    if (_finished) return;
    _reschedule();
    _broadcast();
  }

  // ---- Scheduling ---------------------------------------------------------------

  Duration _pacingRemaining() {
    final Duration d = _pacingUntil.difference(_clock());
    return d.isNegative ? Duration.zero : d;
  }

  int _msFromNow(Duration d) => _clock().add(d).millisecondsSinceEpoch;

  bool _isBotControlled(MatchSeat ms) {
    if (ms.isBot || ms.left) return true;
    final DateTime? since = ms.disconnectedAt;
    if (since == null) return false;
    return _clock().difference(since) >= timings.disconnectGrace;
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    _turnDeadlineMs = 0;
    _nextRoundDeadlineMs = 0;

    switch (game.phase) {
      case GamePhase.matchOver:
        _timer = Timer(timings.finishedLinger, () => _finish('finished'));
        return;
      case GamePhase.roundEnd:
        final bool allReady = _seats.values.where((s) => s.connected).every((s) => s.readyNext);
        final Duration delay = (allReady ? Duration.zero : timings.roundBreak) + _pacingRemaining();
        _nextRoundDeadlineMs = _msFromNow(delay);
        _timer = Timer(delay, _dealNextRound);
        return;
      case GamePhase.bidding:
      case GamePhase.playing:
        break;
    }

    final MatchSeat ms = _seats[game.turn]!;
    if (_isBotControlled(ms)) {
      _timer = Timer(timings.botThink + _pacingRemaining(), () => _playForSeat(ms));
      return;
    }

    final DateTime? since = ms.disconnectedAt;
    if (since != null) {
      // Disconnected, still inside the grace window: hold the table for them.
      final Duration remaining = timings.disconnectGrace - _clock().difference(since);
      final Duration wait = remaining.isNegative ? Duration.zero : remaining;
      _turnDeadlineMs = _msFromNow(wait);
      _timer = Timer(wait, () => _playForSeat(ms));
      return;
    }

    final Duration limit = ms.idleStrikes >= 2 ? timings.afkLimit : timings.turnLimit;
    _turnDeadlineMs = _msFromNow(limit);
    _timer = Timer(limit, () {
      ms.idleStrikes++;
      _playForSeat(ms);
    });
  }

  /// Plays a move on behalf of [ms] (a bot, a disconnected human, or a human
  /// whose clock ran out). Always legal: the bot's choice is re-validated and
  /// falls back to the first legal move if a strategy ever misbehaves.
  void _playForSeat(MatchSeat ms) {
    if (_finished) return;
    if (game.turn != ms.seat) return;
    if (game.phase != GamePhase.bidding && game.phase != GamePhase.playing) return;
    _applyMove(_chooseBotMove(ms.seat));
  }

  Move _chooseBotMove(Seat seat) {
    try {
      final Move move = _strategy.chooseMove(game);
      if (move.seat == seat && SpadesRulesEngine.isValidMove(game, move)) return move;
    } on Object {
      // Fall through to the guaranteed-legal fallback below.
    }
    if (game.phase == GamePhase.bidding) return BidMove(seat: seat, tricksBid: 3);
    for (final PlayingCard card in game.hands[seat] ?? const <PlayingCard>[]) {
      final PlayCardMove candidate = PlayCardMove(seat: seat, card: card);
      if (SpadesRulesEngine.isValidMove(game, candidate)) return candidate;
    }
    throw StateError('No legal move for $seat in phase ${game.phase}');
  }

  // ---- Outbound ------------------------------------------------------------------

  Set<Seat> _botControlledSeats() => {
        for (final MatchSeat s in _seats.values)
          if (_isBotControlled(s) || (s.isHuman && s.disconnectedAt != null)) s.seat,
      };

  List<RoomSeatInfo> seatInfos(Seat viewer) => [
        for (final Seat seat in Seat.values)
          RoomSeatInfo(
            seat: seat,
            name: _seats[seat]!.name,
            avatarId: _seats[seat]!.avatarId,
            isBot: _seats[seat]!.isBot,
            connected: _seats[seat]!.isBot || _seats[seat]!.connected,
            isYou: seat == viewer,
            isHost: false,
          ),
      ];

  Map<String, Object?> snapshotFor(Seat viewer) => SnapshotCodec.encode(
        matchId: id,
        version: version,
        viewer: viewer,
        game: game,
        seats: seatInfos(viewer),
        roundStartScores: roundStartScores,
        roundStartBags: roundStartBags,
        turnDeadlineMs: _turnDeadlineMs,
        nextRoundDeadlineMs: _nextRoundDeadlineMs,
        botControlled: _botControlledSeats(),
      );

  void _broadcast() {
    for (final MatchSeat s in _seats.values) {
      if (s.isHuman && !s.left) s.player?.send(snapshotFor(s.seat));
    }
  }

  /// Re-sends the current snapshot to one player (used on explicit resync).
  void resync(PlayerSession player) {
    final MatchSeat? ms = seatOf(player);
    if (ms == null || ms.left) return;
    player.send(snapshotFor(ms.seat));
  }
}
