import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/data/online_prefs.dart';
import 'package:card_game/features/multiplayer/data/online_socket.dart';
import 'package:card_game/features/multiplayer/data/snapshot_codec.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';

/// Who we introduce ourselves as on every (re)connect.
typedef PlayerIntro = ({String name, int avatarId});

/// The app's single connection to the game server.
///
/// Owns the socket lifecycle — connect, `hello`/`welcome`, heartbeat,
/// automatic reconnect with backoff — and turns raw JSON frames into typed
/// [OnlineEvent]s. It also caches the latest [room] and [snapshot] so a
/// screen that opens *after* an event (e.g. the table, pushed right as the
/// first snapshot lands) can still read the current truth.
///
/// Reconnecting is deliberately dumb: it just opens a new socket and says
/// `hello` with the saved token. The server recognises the token, puts us
/// back in our seat and replays a fresh snapshot — so the client has no
/// "resume" code path to get wrong.
class OnlineSession {
  OnlineSession({
    required OnlineSocketConnector connector,
    required OnlinePrefs prefs,
    required PlayerIntro Function() intro,
    this.pingEvery = const Duration(seconds: 15),
    this.staleAfter = const Duration(seconds: 40),
    this.connectTimeout = const Duration(seconds: 8),
    this.maxBackoff = const Duration(seconds: 10),
    DateTime Function()? clock,
    Random? random,
  })  : _connector = connector,
        _prefs = prefs,
        _intro = intro,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final Duration pingEvery;
  final Duration staleAfter;
  final Duration connectTimeout;
  final Duration maxBackoff;

  final OnlineSocketConnector _connector;
  final OnlinePrefs _prefs;
  final PlayerIntro Function() _intro;
  final DateTime Function() _clock;
  final Random _random;

  final StreamController<OnlineEvent> _events = StreamController<OnlineEvent>.broadcast();
  final StreamController<ConnectionStatus> _statusController = StreamController<ConnectionStatus>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _wantOnline = false;
  int _attempt = 0;
  int _epoch = 0; // bumps every time a socket is opened/closed; stale callbacks check it
  bool _everWelcomed = false;

  OnlineSocket? _socket;
  StreamSubscription<String>? _sub;
  Timer? _retryTimer;
  Timer? _pingTimer;
  DateTime _lastRx = DateTime.fromMillisecondsSinceEpoch(0);

  String? playerId;
  RoomInfo? room;
  MatchSnapshot? snapshot;
  String? matchId;

  /// `serverTime - localTime` at the last `welcome`; add to local `now` to
  /// compare against the server's absolute deadlines.
  int clockOffsetMs = 0;

  Stream<OnlineEvent> get events => _events.stream;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _status;
  bool get isOnline => _status == ConnectionStatus.connected;
  bool get hasActiveMatch => matchId != null;
  int get serverNowMs => _clock().millisecondsSinceEpoch + clockOffsetMs;

  // ---- Connection lifecycle -----------------------------------------------------

  /// Starts (and keeps alive) the connection. Safe to call repeatedly.
  Future<void> goOnline() async {
    if (_wantOnline) return;
    _wantOnline = true;
    _attempt = 0;
    await _open();
  }

  /// Drops the connection and forgets any cached room/match.
  Future<void> goOffline() async {
    _wantOnline = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    await _teardownSocket(closeSocket: true);
    room = null;
    snapshot = null;
    matchId = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  /// Retry right now (the "Reconnect" button) instead of waiting out a backoff.
  Future<void> retryNow() async {
    if (!_wantOnline || _status == ConnectionStatus.connected) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempt = 0;
    await _open();
  }

  Future<void> _open() async {
    if (!_wantOnline || _socket != null) return;
    final int epoch = ++_epoch;
    _setStatus(_everWelcomed ? ConnectionStatus.reconnecting : ConnectionStatus.connecting);
    try {
      final Uri uri = Uri.parse(_prefs.serverUrl);
      final OnlineSocket socket = await _connector(uri).timeout(connectTimeout);
      if (!_wantOnline || epoch != _epoch) {
        await socket.close();
        return;
      }
      _socket = socket;
      _lastRx = _clock();
      _sub = socket.incoming.listen(
        (String frame) => _onFrame(epoch, frame),
        onDone: () => _onDropped(epoch),
        onError: (Object _) => _onDropped(epoch),
        cancelOnError: true,
      );
      final PlayerIntro me = _intro();
      socket.send(
        jsonEncode({
          'type': C2S.hello,
          'protocol': kProtocolVersion,
          'token': _prefs.token,
          'name': me.name,
          'avatarId': me.avatarId,
        }),
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(pingEvery, (_) => _heartbeat(epoch));
    } on Object {
      if (epoch == _epoch) _onDropped(epoch);
    }
  }

  void _heartbeat(int epoch) {
    if (epoch != _epoch) return;
    if (_clock().difference(_lastRx) > staleAfter) {
      // Half-open socket: nothing heard for too long. Force a reconnect.
      _onDropped(epoch);
      return;
    }
    _socket?.send(jsonEncode({'type': C2S.ping, 't': _clock().millisecondsSinceEpoch}));
  }

  Future<void> _teardownSocket({required bool closeSocket}) async {
    _epoch++;
    _pingTimer?.cancel();
    _pingTimer = null;
    final StreamSubscription<String>? sub = _sub;
    final OnlineSocket? socket = _socket;
    _sub = null;
    _socket = null;
    await sub?.cancel();
    if (closeSocket) {
      try {
        await socket?.close();
      } on Object {
        // Already closed.
      }
    }
  }

  void _onDropped(int epoch) {
    if (epoch != _epoch) return; // a stale socket's late callback
    unawaited(_teardownSocket(closeSocket: true));
    if (!_wantOnline) return;
    _setStatus(_everWelcomed ? ConnectionStatus.reconnecting : ConnectionStatus.connecting);
    _attempt++;
    final int seconds = min(maxBackoff.inSeconds, 1 << min(_attempt, 5));
    final Duration delay = Duration(milliseconds: seconds * 1000 + _random.nextInt(400));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_open());
    });
  }

  void _setStatus(ConnectionStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  // ---- Inbound ------------------------------------------------------------------------

  void _onFrame(int epoch, String frame) {
    if (epoch != _epoch) return;
    _lastRx = _clock();

    final Map<String, Object?> msg;
    try {
      final Object? decoded = jsonDecode(frame);
      if (decoded is! Map) return;
      msg = decoded.cast<String, Object?>();
    } on Object {
      return;
    }

    try {
      _dispatch(msg);
    } on FormatException {
      // A malformed server frame must never crash the app; drop it. The
      // next snapshot supersedes whatever this one carried.
    }
  }

  void _dispatch(Map<String, Object?> msg) {
    switch (msg['type']) {
      case S2C.welcome:
        playerId = msg['playerId'] as String?;
        final Object? token = msg['token'];
        if (token is String) unawaited(_prefs.setToken(token));
        final Object? serverTime = msg['serverTimeMs'];
        if (serverTime is num) clockOffsetMs = serverTime.toInt() - _clock().millisecondsSinceEpoch;
        _everWelcomed = true;
        _attempt = 0;
        _setStatus(ConnectionStatus.connected);
      case S2C.roomUpdate:
        room = RoomInfo.fromJson(msg);
        _emit(RoomChanged(room));
      case S2C.roomClosed:
        room = null;
        _emit(const RoomChanged(null));
      case S2C.queueStatus:
        _emit(
          QueueChanged(
            active: (msg['active'] as bool?) ?? false,
            waiting: ((msg['waiting'] as num?) ?? 0).toInt(),
            elapsed: ((msg['elapsed'] as num?) ?? 0).toInt(),
            fillInSeconds: ((msg['fillInSeconds'] as num?) ?? 0).toInt(),
          ),
        );
      case S2C.matchStarted:
        final String startedId = msg['matchId']! as String;
        if (matchId != startedId) snapshot = null; // a different match: old snapshot is stale
        matchId = startedId;
        room = null;
        _emit(MatchStarted(startedId));
      case S2C.snapshot:
        final MatchSnapshot s = SnapshotCodec.decode(msg);
        final MatchSnapshot? held = snapshot;
        if (held != null && held.matchId == s.matchId && s.version < held.version) return; // out of order
        snapshot = s;
        matchId = s.matchId;
        _emit(SnapshotReceived(s));
      case S2C.matchEnded:
        final String endReason = (msg['reason'] as String?) ?? 'finished';
        matchId = null;
        _emit(MatchEnded(endReason));
      case S2C.emote:
        final Seat? emoteSeat = Seat.values.asNameMap()[msg['seat']];
        final Object? emoteId = msg['id'];
        if (emoteSeat != null && emoteId is String) _emit(EmoteReceived(seat: emoteSeat, id: emoteId));
      case S2C.error:
        final String errCode = (msg['code'] as String?) ?? ErrorCode.badRequest;
        final String errMessage = (msg['message'] as String?) ?? 'Something went wrong.';
        if (errCode == ErrorCode.replaced || errCode == ErrorCode.protocol || errCode == ErrorCode.authFailed) {
          // Retrying cannot fix these; stop and tell the UI.
          _wantOnline = false;
          _retryTimer?.cancel();
          unawaited(_teardownSocket(closeSocket: true));
          _setStatus(ConnectionStatus.disconnected);
          if (errCode == ErrorCode.replaced) _emit(const MatchEnded(ErrorCode.replaced));
        }
        _emit(ServerError(code: errCode, message: errMessage));
      case S2C.pong:
        break;
    }
  }

  void _emit(OnlineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  // ---- Outbound commands ----------------------------------------------------------------------

  bool _send(String type, [Map<String, Object?> payload = const {}]) {
    final OnlineSocket? socket = _socket;
    if (socket == null || _status != ConnectionStatus.connected) return false;
    socket.send(jsonEncode({'type': type, ...payload}));
    return true;
  }

  bool quickMatch() => _send(C2S.quickMatch);
  bool cancelQueue() => _send(C2S.cancelQueue);
  bool createRoom() => _send(C2S.createRoom);
  bool joinRoom(String code) => _send(C2S.joinRoom, {'code': code.trim().toUpperCase()});
  bool startMatch() => _send(C2S.startMatch);

  bool leaveRoom() {
    room = null;
    return _send(C2S.leaveRoom);
  }

  bool sendBid(int tricks) => _send(C2S.move, SnapshotCodec.encodeBid(tricks));
  bool sendCard(PlayingCard card) => _send(C2S.move, SnapshotCodec.encodePlay(card));
  bool readyNext() => _send(C2S.readyNext);
  bool sendEmote(String id) => _send(C2S.emote, {'id': id});
  bool report(Seat seat, {String reason = ''}) => _send(C2S.report, {'seat': seat.name, 'reason': reason});

  /// Quit the running match for good (a bot takes the seat). Forgets the
  /// cached match so a fresh lobby doesn't think a match is still live.
  bool leaveMatch() {
    final bool sent = _send(C2S.leaveMatch);
    matchId = null;
    snapshot = null;
    return sent;
  }

  Future<void> dispose() async {
    await goOffline();
    await _events.close();
    await _statusController.close();
  }
}
