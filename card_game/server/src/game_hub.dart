import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';

import 'authenticator.dart';
import 'match_session.dart';
import 'session.dart';

const List<String> _kBotNames = ['Ava', 'Ben', 'Cleo', 'Dax'];
const int _kAvatarCount = 8;
const int _kMaxNameLength = 16;
const int _kMaxMessageBytes = 4096;

/// A private lobby: up to four humans, started by the host.
class Room {
  Room(this.code, {required this.isPrivate});

  final String code;
  final bool isPrivate;
  final Map<Seat, PlayerSession> players = {};
  String? hostId;

  Seat? get freeSeat {
    for (final Seat s in Seat.values) {
      if (!players.containsKey(s)) return s;
    }
    return null;
  }

  Seat? seatOf(PlayerSession p) {
    for (final MapEntry<Seat, PlayerSession> e in players.entries) {
      if (e.value.id == p.id) return e.key;
    }
    return null;
  }
}

class _Ticket {
  _Ticket(this.player, this.since);
  final PlayerSession player;
  final DateTime since;
}

/// The whole multiplayer server minus the sockets: identity, rooms,
/// matchmaking, and the table of running [MatchSession]s.
///
/// Drive it with [attach] + [onRaw] (production wires these to a
/// WebSocket; tests call them directly with a fake connection).
class GameHub {
  GameHub({
    Authenticator authenticator = const GuestAuthenticator(),
    this.timings = MatchTimings.standard,
    this.botDifficulty = AiDifficulty.medium,
    this.quickMatchFill = const Duration(seconds: kQuickMatchBotFillSeconds),
    this.roomDisconnectGrace = const Duration(seconds: 15),
    this.rateCapacity = 30,
    this.rateRefillPerSecond = 15,
    Random? random,
    DateTime Function()? clock,
    void Function(String line)? log,
  })  : _authenticator = authenticator,
        _random = random ?? Random.secure(),
        _clock = clock ?? DateTime.now,
        _log = log ?? ((_) {});

  final MatchTimings timings;
  final AiDifficulty botDifficulty;
  final Duration quickMatchFill;
  final Duration roomDisconnectGrace;

  /// Per-connection message budget: burst size and sustained msgs/second.
  final int rateCapacity;
  final double rateRefillPerSecond;
  final Authenticator _authenticator;
  final Random _random;
  final DateTime Function() _clock;
  final void Function(String) _log;

  final Map<String, PlayerSession> _byToken = {};
  final Map<String, PlayerSession> _byUid = {};
  final Map<String, Room> _rooms = {};
  final Map<String, MatchSession> _matches = {};
  final List<_Ticket> _queue = [];
  final Set<ClientConnection> _connections = {};
  final List<Map<String, Object?>> reports = [];

  Timer? _ticker;
  int _nextConnId = 0;
  int _nextMatchId = 0;

  // ---- Introspection (health endpoint / tests) -------------------------------------

  int get connectionCount => _connections.length;
  int get roomCount => _rooms.length;
  int get matchCount => _matches.length;
  int get queueLength => _queue.length;
  MatchSession? matchById(String id) => _matches[id];
  Room? roomByCode(String code) => _rooms[code];

  // ---- Lifecycle -------------------------------------------------------------------

  void start() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    for (final MatchSession m in _matches.values.toList()) {
      m.dispose();
    }
    _matches.clear();
    for (final ClientConnection c in _connections.toList()) {
      await c.close(1001, 'server shutting down');
    }
  }

  /// One housekeeping pass: matchmaking, stale sockets, idle sessions.
  /// Public so tests can step time deterministically.
  void tick() {
    _tickQueue();
    final DateTime now = _clock();
    for (final ClientConnection c in _connections.toList()) {
      if (now.difference(c.lastSeen) > const Duration(seconds: 60)) {
        unawaited(c.close(4408, 'heartbeat timeout'));
      }
    }
    final List<PlayerSession> stale = _byToken.values
        .where(
          (p) =>
              !p.isConnected && p.matchId == null && p.roomCode == null && now.difference(p.lastActive) > const Duration(hours: 1),
        )
        .toList();
    for (final PlayerSession p in stale) {
      _byToken.remove(p.token);
      _byUid.removeWhere((_, v) => v.id == p.id);
    }
  }

  // ---- Connection plumbing -----------------------------------------------------------

  /// Registers a new socket. The client must say `hello` within 10 s.
  ClientConnection attach({
    required void Function(String) onSend,
    required Future<void> Function(int code, String reason) onClose,
  }) {
    final ClientConnection conn = ClientConnection(
      id: ++_nextConnId,
      onSend: onSend,
      onClose: onClose,
      clock: _clock,
      rateLimiter: RateLimiter(capacity: rateCapacity, refillPerSecond: rateRefillPerSecond, clock: _clock),
    );
    _connections.add(conn);
    Timer(const Duration(seconds: 10), () {
      if (conn.player == null && conn.isOpen) unawaited(conn.close(4401, 'hello timeout'));
    });
    return conn;
  }

  void onClosed(ClientConnection conn) {
    conn.markClosed();
    _connections.remove(conn);
    final PlayerSession? p = conn.player;
    if (p == null || p.connection != conn) return;
    p.connection = null;
    _removeFromQueue(p);

    final MatchSession? match = p.matchId == null ? null : _matches[p.matchId];
    if (match != null) {
      match.onPlayerDisconnected(p);
      return;
    }
    if (p.roomCode != null) {
      p.roomLeaveTimer?.cancel();
      p.roomLeaveTimer = Timer(roomDisconnectGrace, () {
        if (!p.isConnected) _leaveRoom(p);
      });
    }
  }

  /// Entry point for every inbound frame.
  Future<void> onRaw(ClientConnection conn, Object? raw) async {
    if (raw is! String) {
      _error(conn, ErrorCode.badRequest, 'Text frames only.');
      return;
    }
    if (raw.length > _kMaxMessageBytes) {
      await conn.close(4413, 'message too large');
      return;
    }
    if (!conn.limiter.tryConsume()) {
      _error(conn, ErrorCode.rateLimited, 'Slow down.');
      if (conn.limiter.violations > 60) await conn.close(4429, 'rate limited');
      return;
    }
    conn.lastSeen = _clock();

    final Map<String, Object?> msg;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('not an object');
      msg = decoded.cast<String, Object?>();
    } on Object {
      _error(conn, ErrorCode.badRequest, 'Malformed JSON.');
      return;
    }

    final Object? type = msg['type'];
    if (type == C2S.ping) {
      conn.send({'type': S2C.pong, 't': msg['t']});
      return;
    }
    if (type == C2S.hello) {
      await _onHello(conn, msg);
      return;
    }

    final PlayerSession? player = conn.player;
    if (player == null) {
      _error(conn, ErrorCode.authFailed, 'Send hello first.');
      return;
    }
    player.lastActive = _clock();

    switch (type) {
      case C2S.quickMatch:
        _quickMatch(player);
      case C2S.cancelQueue:
        _removeFromQueue(player);
        player.send({'type': S2C.queueStatus, 'waiting': 0, 'elapsed': 0, 'active': false});
      case C2S.createRoom:
        _createRoom(player);
      case C2S.joinRoom:
        _joinRoom(player, msg['code']);
      case C2S.leaveRoom:
        _leaveRoom(player);
      case C2S.startMatch:
        _startRoomMatch(player);
      case C2S.move:
        _onMove(player, msg);
      case C2S.readyNext:
        _matchOf(player)?.handleReadyNext(player);
      case C2S.leaveMatch:
        _leaveMatch(player);
      case C2S.emote:
        final Object? emoteId = msg['id'];
        if (emoteId is String) _matchOf(player)?.handleEmote(player, emoteId);
      case C2S.report:
        _onReport(player, msg);
      default:
        _error(conn, ErrorCode.badRequest, 'Unknown message type.');
    }
  }

  // ---- Hello / identity ----------------------------------------------------------------

  Future<void> _onHello(ClientConnection conn, Map<String, Object?> msg) async {
    if (msg['protocol'] != kProtocolVersion) {
      _error(conn, ErrorCode.protocol, 'Please update the app (server speaks protocol $kProtocolVersion).');
      await conn.close(4426, 'protocol mismatch');
      return;
    }

    String? uid;
    try {
      uid = await _authenticator.verify(msg['idToken'] as String?);
    } on AuthException catch (e) {
      _error(conn, ErrorCode.authFailed, e.message);
      await conn.close(4403, 'auth failed');
      return;
    }
    if (!conn.isOpen) return;

    final String name = sanitizeName(msg['name']);
    final int avatar = _clampAvatar(msg['avatarId']);
    final Object? token = msg['token'];

    PlayerSession? p;
    if (uid != null) {
      p = _byUid[uid];
    } else if (token is String) {
      p = _byToken[token];
    }

    if (p == null) {
      p = PlayerSession(id: _newId(), token: _newToken(), name: name, avatarId: avatar, now: _clock());
      _byToken[p.token] = p;
      if (uid != null) _byUid[uid] = p;
      _log('new player ${p.id} ($name)');
    } else {
      p.name = name;
      p.avatarId = avatar;
    }

    // One live socket per player: a newer connection replaces the older one.
    final ClientConnection? old = p.connection;
    if (old != null && old != conn) {
      old.player = null;
      old.send({'type': S2C.error, 'code': ErrorCode.replaced, 'message': 'Signed in from another device.'});
      unawaited(old.close(4409, 'replaced'));
    }
    p.connection = conn;
    conn.player = p;
    p.roomLeaveTimer?.cancel();
    p.lastActive = _clock();

    conn.send({
      'type': S2C.welcome,
      'protocol': kProtocolVersion,
      'playerId': p.id,
      'token': p.token,
      'name': p.name,
      'avatarId': p.avatarId,
      'serverTimeMs': _clock().millisecondsSinceEpoch,
    });

    final MatchSession? match = p.matchId == null ? null : _matches[p.matchId];
    if (match != null && !match.isFinished) {
      match.onPlayerReconnected(p); // sends match_started + a fresh snapshot
      return;
    }
    p.matchId = null;
    final Room? room = p.roomCode == null ? null : _rooms[p.roomCode];
    if (room != null) {
      _sendRoom(room);
    } else {
      p.roomCode = null;
    }
  }

  /// Trims, strips control characters, collapses whitespace, caps length.
  static String sanitizeName(Object? raw) {
    if (raw is! String) return 'Player';
    final String cleaned = raw.replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Player';
    return cleaned.length > _kMaxNameLength ? cleaned.substring(0, _kMaxNameLength) : cleaned;
  }

  static int _clampAvatar(Object? raw) => raw is num ? raw.toInt().clamp(0, _kAvatarCount - 1) : 0;

  String _newId() => 'p_${_randomHex(6)}';
  String _newToken() => _randomHex(24);

  String _randomHex(int bytes) {
    final Random secure = Random.secure();
    return List.generate(bytes, (_) => secure.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  // ---- Rooms -------------------------------------------------------------------------------

  bool _busy(PlayerSession p) => p.roomCode != null || p.matchId != null || p.inQueue;

  void _createRoom(PlayerSession p) {
    if (_busy(p)) {
      _error(p.connection, ErrorCode.alreadyInRoom, 'Leave your current room or match first.');
      return;
    }
    final Room room = Room(_newRoomCode(), isPrivate: true)..hostId = p.id;
    room.players[Seat.north] = p;
    p.roomCode = room.code;
    _rooms[room.code] = room;
    _sendRoom(room);
  }

  String _newRoomCode() {
    while (true) {
      final String code = String.fromCharCodes(
        List.generate(kRoomCodeLength, (_) => kRoomCodeAlphabet.codeUnitAt(_random.nextInt(kRoomCodeAlphabet.length))),
      );
      if (!_rooms.containsKey(code)) return code;
    }
  }

  void _joinRoom(PlayerSession p, Object? rawCode) {
    if (_busy(p)) {
      _error(p.connection, ErrorCode.alreadyInRoom, 'Leave your current room or match first.');
      return;
    }
    if (rawCode is! String) {
      _error(p.connection, ErrorCode.badRequest, 'Missing room code.');
      return;
    }
    final Room? room = _rooms[rawCode.trim().toUpperCase()];
    if (room == null) {
      _error(p.connection, ErrorCode.roomNotFound, 'No room with that code.');
      return;
    }
    final Seat? seat = room.freeSeat;
    if (seat == null) {
      _error(p.connection, ErrorCode.roomFull, 'That room is full.');
      return;
    }
    room.players[seat] = p;
    p.roomCode = room.code;
    _sendRoom(room);
  }

  void _leaveRoom(PlayerSession p) {
    final Room? room = p.roomCode == null ? null : _rooms[p.roomCode];
    p.roomCode = null;
    p.roomLeaveTimer?.cancel();
    if (room == null) return;

    final Seat? seat = room.seatOf(p);
    if (seat != null) room.players.remove(seat);
    p.send({'type': S2C.roomClosed});

    if (room.players.isEmpty) {
      _rooms.remove(room.code);
      return;
    }
    if (room.hostId == p.id) room.hostId = room.players.values.first.id;
    _sendRoom(room);
  }

  void _sendRoom(Room room) {
    for (final PlayerSession viewer in room.players.values) {
      viewer.send(_roomJson(room, viewer));
    }
  }

  Map<String, Object?> _roomJson(Room room, PlayerSession viewer) {
    return {
      'type': S2C.roomUpdate,
      'code': room.code,
      'private': room.isPrivate,
      'seats': [
        for (final Seat seat in Seat.values)
          if (room.players[seat] case final PlayerSession occupant)
            RoomSeatInfo(
              seat: seat,
              name: occupant.name,
              avatarId: occupant.avatarId,
              isBot: false,
              connected: occupant.isConnected,
              isYou: occupant.id == viewer.id,
              isHost: occupant.id == room.hostId,
            ).toJson()
          else
            RoomSeatInfo.empty(seat).toJson(),
      ],
    };
  }

  void _startRoomMatch(PlayerSession p) {
    final Room? room = p.roomCode == null ? null : _rooms[p.roomCode];
    if (room == null) {
      _error(p.connection, ErrorCode.notInRoom, 'You are not in a room.');
      return;
    }
    if (room.hostId != p.id) {
      _error(p.connection, ErrorCode.notHost, 'Only the host can start the match.');
      return;
    }
    _rooms.remove(room.code);
    for (final PlayerSession human in room.players.values) {
      human.roomCode = null;
    }
    _launchMatch(Map<Seat, PlayerSession>.of(room.players));
  }

  // ---- Matchmaking ----------------------------------------------------------------------------

  void _quickMatch(PlayerSession p) {
    if (_busy(p)) {
      _error(p.connection, ErrorCode.alreadyInRoom, 'Leave your current room or match first.');
      return;
    }
    p.inQueue = true;
    _queue.add(_Ticket(p, _clock()));
    _tickQueue();
  }

  void _removeFromQueue(PlayerSession p) {
    p.inQueue = false;
    _queue.removeWhere((t) => t.player.id == p.id);
  }

  void _tickQueue() {
    _queue.removeWhere((t) {
      final bool gone = !t.player.isConnected;
      if (gone) t.player.inQueue = false;
      return gone;
    });

    while (_queue.length >= 4) {
      final List<_Ticket> group = _queue.sublist(0, 4);
      _queue.removeRange(0, 4);
      _launchQuickGroup(group);
    }

    final DateTime now = _clock();
    if (_queue.isNotEmpty && now.difference(_queue.first.since) >= quickMatchFill) {
      final List<_Ticket> group = List.of(_queue);
      _queue.clear();
      _launchQuickGroup(group);
    }

    for (final _Ticket t in _queue) {
      t.player.send({
        'type': S2C.queueStatus,
        'active': true,
        'waiting': _queue.length,
        'elapsed': now.difference(t.since).inSeconds,
        'fillInSeconds': max(0, quickMatchFill.inSeconds - now.difference(t.since).inSeconds),
      });
    }
  }

  void _launchQuickGroup(List<_Ticket> group) {
    final List<Seat> order = List.of(Seat.values)..shuffle(_random);
    final Map<Seat, PlayerSession> humans = {};
    for (int i = 0; i < group.length; i++) {
      group[i].player.inQueue = false;
      humans[order[i]] = group[i].player;
    }
    _launchMatch(humans);
  }

  void _launchMatch(Map<Seat, PlayerSession> humans) {
    final String id = 'm_${++_nextMatchId}_${_randomHex(3)}';
    final List<MatchSeat> seats = [
      for (final Seat seat in Seat.values)
        if (humans[seat] case final PlayerSession human)
          MatchSeat.human(seat: seat, player: human)
        else
          MatchSeat.bot(seat: seat, name: _kBotNames[seat.index], avatarId: seat.index),
    ];

    final MatchSession session = MatchSession(
      id: id,
      seats: seats,
      timings: timings,
      botDifficulty: botDifficulty,
      random: _random,
      clock: _clock,
      onFinished: _onMatchFinished,
    );
    _matches[id] = session;
    for (final PlayerSession p in humans.values) {
      p.matchId = id;
      p.send({'type': S2C.matchStarted, 'matchId': id});
    }
    _log('match $id started with ${humans.length} human(s)');
    session.start();
  }

  void _onMatchFinished(MatchSession session, String reason) {
    _matches.remove(session.id);
    for (final PlayerSession p in session.humanPlayers) {
      if (p.matchId == session.id) p.matchId = null;
    }
    _log('match ${session.id} finished ($reason)');
  }

  // ---- In-match ------------------------------------------------------------------------------------

  MatchSession? _matchOf(PlayerSession p) => p.matchId == null ? null : _matches[p.matchId];

  void _onMove(PlayerSession p, Map<String, Object?> msg) {
    final MatchSession? match = _matchOf(p);
    if (match == null) {
      _error(p.connection, ErrorCode.notInMatch, 'You are not in a match.');
      return;
    }
    final String? error = match.handleMove(p, msg);
    if (error != null) {
      _error(p.connection, error, 'Move rejected.');
      // Re-send authoritative state so a desynced client heals immediately.
      match.resync(p);
    }
  }

  void _leaveMatch(PlayerSession p) {
    final MatchSession? match = _matchOf(p);
    p.matchId = null;
    match?.onPlayerLeft(p);
  }

  void _onReport(PlayerSession p, Map<String, Object?> msg) {
    final MatchSession? match = _matchOf(p);
    final Object? seatName = msg['seat'];
    if (match == null || seatName is! String) return;
    final Seat? target = Seat.values.asNameMap()[seatName];
    if (target == null) return;
    final MatchSeat? ms = match.seats.where((s) => s.seat == target).firstOrNull;
    final PlayerSession? offender = ms?.player;
    if (offender == null || offender.id == p.id) return;
    offender.reportsAgainst++;
    final Object? reason = msg['reason'];
    reports.add({
      'at': _clock().toIso8601String(),
      'reporter': p.id,
      'offender': offender.id,
      'match': match.id,
      'reason': reason is String ? reason.substring(0, min(reason.length, 200)) : '',
    });
    _log('report: ${p.id} -> ${offender.id}');
  }

  // ---- Errors -----------------------------------------------------------------------------------------

  void _error(ClientConnection? conn, String code, String message) {
    conn?.send({'type': S2C.error, 'code': code, 'message': message});
  }
}
