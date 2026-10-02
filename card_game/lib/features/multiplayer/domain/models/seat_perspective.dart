import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';

/// Re-frames a match so the local player always sits South.
///
/// The server speaks in absolute seats (anyone can be North, East, ...),
/// but the whole table UI built in Phases 05–08 assumes "you are South,
/// partner is North, team 0 is Us". Rather than rewrite that UI, the
/// online client rotates every incoming [GameState] into the local
/// player's frame. Rotation by an *odd* number of seats swaps which
/// partnership has even/odd seat indexes, so team indexes (scores, bags,
/// winner) are swapped too — the local team is always team 0 ("Us").
class SeatPerspective {
  const SeatPerspective(this.mySeat);

  /// The local player's seat in the server's absolute frame.
  final Seat mySeat;

  /// Where the local player appears in the rotated frame.
  static const Seat viewSeat = Seat.south;

  bool get swapsTeams => mySeat.index.isOdd;

  /// Absolute seat -> seat as drawn on the local table.
  Seat toView(Seat actual) => Seat.values[(actual.index - mySeat.index + viewSeat.index + 4) % 4];

  /// Local-table seat -> absolute seat.
  Seat fromView(Seat view) => Seat.values[(view.index - viewSeat.index + mySeat.index + 4) % 4];

  int teamToView(int actualTeam) => swapsTeams ? 1 - actualTeam : actualTeam;

  Map<int, int> teamMapToView(Map<int, int> m) => {
        for (final MapEntry<int, int> e in m.entries) teamToView(e.key): e.value,
      };

  List<TrickCard> _trick(List<TrickCard> t) => [
        for (final TrickCard tc in t) TrickCard(seat: toView(tc.seat), card: tc.card),
      ];

  GameState rotate(GameState s) {
    return GameState(
      phase: s.phase,
      dealer: toView(s.dealer),
      turn: toView(s.turn),
      leader: toView(s.leader),
      hands: {for (final e in s.hands.entries) toView(e.key): e.value},
      bids: {for (final e in s.bids.entries) toView(e.key): e.value},
      currentTrick: _trick(s.currentTrick),
      completedTricks: [for (final t in s.completedTricks) _trick(t)],
      tricksWonBySeat: {for (final e in s.tricksWonBySeat.entries) toView(e.key): e.value},
      spadesBroken: s.spadesBroken,
      teamScores: teamMapToView(s.teamScores),
      teamBags: teamMapToView(s.teamBags),
      roundNumber: s.roundNumber,
      winningTeam: s.winningTeam == null ? null : teamToView(s.winningTeam!),
    );
  }
}
