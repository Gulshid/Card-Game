import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:equatable/equatable.dart';

/// What the server sends a client after every state change: that
/// client's *redacted* view of the match.
///
/// Other seats' hands are never on the wire. [game] carries opponents'
/// hands as same-length lists of a placeholder card purely so the table
/// widgets can count them — they must never be read as real cards.
class MatchSnapshot extends Equatable {
  const MatchSnapshot({
    required this.matchId,
    required this.version,
    required this.mySeat,
    required this.game,
    required this.seats,
    required this.roundStartScores,
    required this.roundStartBags,
    required this.turnDeadlineMs,
    required this.nextRoundDeadlineMs,
    required this.botControlled,
  });

  final String matchId;

  /// Increments on every applied move / round start. Clients ignore any
  /// snapshot whose version is not newer than the one they hold.
  final int version;

  /// The seat this client occupies, in the server's (absolute) frame.
  final Seat mySeat;

  /// Absolute-frame state with opponents' hands replaced by placeholders.
  final GameState game;

  final List<RoomSeatInfo> seats;
  final Map<int, int> roundStartScores;
  final Map<int, int> roundStartBags;

  /// Epoch-ms deadline for the current turn (0 when nobody is on the clock).
  final int turnDeadlineMs;

  /// Epoch-ms when the server auto-deals the next round (0 if not waiting).
  final int nextRoundDeadlineMs;

  /// Seats a bot is currently playing (real bots, plus humans who timed out
  /// or are disconnected and being covered).
  final Set<Seat> botControlled;

  @override
  List<Object?> get props => [
        matchId,
        version,
        mySeat,
        game,
        seats,
        roundStartScores,
        roundStartBags,
        turnDeadlineMs,
        nextRoundDeadlineMs,
        botControlled,
      ];
}
