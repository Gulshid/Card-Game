import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Typed view of what the server told us. `OnlineSession` parses raw
/// JSON once; cubits only ever see these.
sealed class OnlineEvent {
  const OnlineEvent();
}

class RoomChanged extends OnlineEvent {
  const RoomChanged(this.room);

  /// `null` when we are no longer in a room.
  final RoomInfo? room;
}

class QueueChanged extends OnlineEvent {
  const QueueChanged({required this.active, required this.waiting, required this.elapsed, required this.fillInSeconds});

  final bool active;
  final int waiting;
  final int elapsed;
  final int fillInSeconds;
}

class MatchStarted extends OnlineEvent {
  const MatchStarted(this.matchId);
  final String matchId;
}

class SnapshotReceived extends OnlineEvent {
  const SnapshotReceived(this.snapshot);
  final MatchSnapshot snapshot;
}

class MatchEnded extends OnlineEvent {
  const MatchEnded(this.reason);

  /// `finished`, `abandoned`, or `replaced` (signed in elsewhere).
  final String reason;
}

class EmoteReceived extends OnlineEvent {
  const EmoteReceived({required this.seat, required this.id});

  /// Absolute-frame seat of the sender.
  final Seat seat;
  final String id;
}

class ServerError extends OnlineEvent {
  const ServerError({required this.code, required this.message});
  final String code;
  final String message;
}
