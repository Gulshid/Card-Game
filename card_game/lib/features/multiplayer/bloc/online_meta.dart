import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:equatable/equatable.dart';

/// Online-only facts the felt table has no field for (who is connected,
/// who a bot is covering, countdowns, emotes). Kept beside — not inside —
/// `GameUiState` so the Phase 05–09 table widgets stay untouched.
///
/// Everything here is in the *local table frame* (local player = South).
class OnlineMeta extends Equatable {
  const OnlineMeta({
    this.connection = ConnectionStatus.connected,
    this.seats = const {},
    this.botControlled = const {},
    this.turnDeadlineMs = 0,
    this.nextRoundDeadlineMs = 0,
    this.endedReason,
    this.emoteSeat,
    this.emoteId,
    this.emoteNonce = 0,
  });

  final ConnectionStatus connection;
  final Map<Seat, RoomSeatInfo> seats;

  /// Seats a bot is currently playing (real bots + covered humans).
  final Set<Seat> botControlled;

  /// Server epoch-ms; compare against `OnlineSession.serverNowMs`.
  final int turnDeadlineMs;
  final int nextRoundDeadlineMs;

  /// Set when the server tells us the match is gone (`abandoned`,
  /// `replaced`, or `finished`).
  final String? endedReason;

  final Seat? emoteSeat;
  final String? emoteId;
  final int emoteNonce;

  /// Human opponents/partner who are currently offline.
  List<RoomSeatInfo> get disconnectedHumans =>
      [for (final RoomSeatInfo s in seats.values) if (!s.isBot && !s.isYou && !s.connected) s];

  OnlineMeta copyWith({
    ConnectionStatus? connection,
    Map<Seat, RoomSeatInfo>? seats,
    Set<Seat>? botControlled,
    int? turnDeadlineMs,
    int? nextRoundDeadlineMs,
    String? endedReason,
    Seat? emoteSeat,
    String? emoteId,
    int? emoteNonce,
  }) {
    return OnlineMeta(
      connection: connection ?? this.connection,
      seats: seats ?? this.seats,
      botControlled: botControlled ?? this.botControlled,
      turnDeadlineMs: turnDeadlineMs ?? this.turnDeadlineMs,
      nextRoundDeadlineMs: nextRoundDeadlineMs ?? this.nextRoundDeadlineMs,
      endedReason: endedReason ?? this.endedReason,
      emoteSeat: emoteSeat ?? this.emoteSeat,
      emoteId: emoteId ?? this.emoteId,
      emoteNonce: emoteNonce ?? this.emoteNonce,
    );
  }

  @override
  List<Object?> get props => [
        connection,
        seats,
        botControlled,
        turnDeadlineMs,
        nextRoundDeadlineMs,
        endedReason,
        emoteSeat,
        emoteId,
        emoteNonce,
      ];
}
