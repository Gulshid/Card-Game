import 'dart:async';
import 'dart:convert';

/// Simple token bucket: [capacity] messages of burst, refilled at
/// [refillPerSecond]. A client that floods the socket gets dropped
/// messages (and, if it keeps going, a closed connection).
class RateLimiter {
  RateLimiter({this.capacity = 30, this.refillPerSecond = 15, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _tokens = capacity.toDouble() {
    _last = _clock();
  }

  final int capacity;
  final double refillPerSecond;
  final DateTime Function() _clock;
  double _tokens;
  late DateTime _last;

  /// Consecutive-ish rejected messages; the hub closes the socket past a limit.
  int violations = 0;

  bool tryConsume() {
    final DateTime now = _clock();
    final double elapsed = now.difference(_last).inMilliseconds / 1000.0;
    _last = now;
    _tokens = (_tokens + elapsed * refillPerSecond).clamp(0, capacity.toDouble());
    if (_tokens >= 1) {
      _tokens -= 1;
      return true;
    }
    violations++;
    return false;
  }
}

/// One live socket. Transport-agnostic (a send callback and a close
/// callback) so the hub can be driven by real WebSockets in production
/// and by an in-memory fake in tests.
class ClientConnection {
  ClientConnection({
    required this.id,
    required void Function(String) onSend,
    required Future<void> Function(int code, String reason) onClose,
    DateTime Function()? clock,
    RateLimiter? rateLimiter,
  })  : _onSend = onSend,
        _onClose = onClose,
        limiter = rateLimiter ?? RateLimiter(clock: clock);

  final int id;
  final void Function(String) _onSend;
  final Future<void> Function(int code, String reason) _onClose;
  final RateLimiter limiter;

  bool _open = true;
  DateTime lastSeen = DateTime.now();

  /// Set once the client has completed `hello`.
  PlayerSession? player;

  bool get isOpen => _open;

  void send(Map<String, Object?> message) {
    if (!_open) return;
    try {
      _onSend(jsonEncode(message));
    } on Object {
      _open = false;
    }
  }

  Future<void> close([int code = 1000, String reason = '']) async {
    if (!_open) return;
    _open = false;
    try {
      await _onClose(code, reason);
    } on Object {
      // Already gone.
    }
  }

  /// Called when the transport itself reports closure.
  void markClosed() => _open = false;
}

/// A guest (or authenticated) player's server-side identity. Outlives any
/// single socket: it is what lets a player reconnect into the same seat.
class PlayerSession {
  PlayerSession({
    required this.id,
    required this.token,
    required this.name,
    required this.avatarId,
    DateTime? now,
  }) : lastActive = now ?? DateTime.now();

  final String id;

  /// Secret that proves a reconnecting client is this player. Never
  /// broadcast to other players.
  final String token;

  String name;
  int avatarId;

  ClientConnection? connection;
  String? roomCode;
  String? matchId;
  bool inQueue = false;
  Timer? roomLeaveTimer;
  DateTime lastActive;
  DateTime lastEmote = DateTime.fromMillisecondsSinceEpoch(0);
  int reportsAgainst = 0;

  bool get isConnected => connection != null && connection!.isOpen;

  void send(Map<String, Object?> message) => connection?.send(message);
}
