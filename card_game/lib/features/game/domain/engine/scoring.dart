import 'package:equatable/equatable.dart';

import '../models/seat.dart';

/// Result of scoring one completed round for one team. Kept separate
/// from the score *application* (which lives in the engine) so this
/// stays a pure, independently testable calculation with no knowledge
/// of `GameState` at all.
class TeamRoundScore extends Equatable {
  const TeamRoundScore({
    required this.team,
    required this.madeBid,
    required this.scoreDelta,
    required this.bagsDelta,
    required this.bagPenaltyApplied,
  });

  final int team;
  final bool madeBid;
  final int scoreDelta;
  final int bagsDelta;
  final bool bagPenaltyApplied;

  @override
  List<Object?> get props => [team, madeBid, scoreDelta, bagsDelta, bagPenaltyApplied];
}

/// Pure Spades scoring, per the rules fixed in the GDD (§7):
/// - Team makes bid: `10 * bid`, plus 1 point per bag (overtrick).
/// - Team fails bid: `-10 * bid`, tricks won are worthless.
/// - Nil made: `+100` to that seat's team. Nil failed: `-100`.
///   The nil bidder's own tricks still count toward the team's total
///   for the bid-vs-tricks comparison — only the personal nil
///   bonus/penalty is separate.
/// - 10 accumulated bags: `-100` penalty, counter resets to the
///   remainder (not hard-zeroed, so a team that goes 12 bags over
///   still carries 2 into the next cycle rather than losing them).
abstract class Scoring {
  static const int _pointsPerBid = 10;
  static const int _nilBonus = 100;
  static const int _bagPenaltyThreshold = 10;
  static const int _bagPenalty = 100;

  static TeamRoundScore scoreTeam({
    required int team,
    required Map<Seat, int?> bids,
    required Map<Seat, int> tricksWonBySeat,
    required int existingBags,
  }) {
    final List<Seat> teamSeats = Seat.values.where((s) => s.team == team).toList();
    assert(teamSeats.length == 2, 'A Spades team always has exactly two seats');

    int bidTarget = 0;
    int nilBonusTotal = 0;
    for (final seat in teamSeats) {
      final int? bid = bids[seat];
      assert(bid != null, 'scoreTeam called before $seat submitted a bid');
      final int bidValue = bid ?? 0;
      final int tricksWon = tricksWonBySeat[seat] ?? 0;
      if (bidValue == 0) {
        // Nil: contributes nothing to the team's trick target; scored
        // as its own bonus/penalty based purely on that seat's tricks.
        nilBonusTotal += tricksWon == 0 ? _nilBonus : -_nilBonus;
      } else {
        bidTarget += bidValue;
      }
    }

    final int teamTricks = teamSeats.fold(0, (sum, s) => sum + (tricksWonBySeat[s] ?? 0));
    final bool madeBid = teamTricks >= bidTarget;
    final int base = madeBid ? _pointsPerBid * bidTarget : -_pointsPerBid * bidTarget;
    final int bags = madeBid ? teamTricks - bidTarget : 0;

    final int totalBags = existingBags + bags;
    final int penaltyUnits = totalBags ~/ _bagPenaltyThreshold;
    final bool penaltyApplies = penaltyUnits > 0;
    final int bagPenaltyPoints = -_bagPenalty * penaltyUnits;
    final int newBagCount = totalBags % _bagPenaltyThreshold;

    return TeamRoundScore(
      team: team,
      madeBid: madeBid,
      scoreDelta: base + nilBonusTotal + bagPenaltyPoints,
      // Delta the caller adds to `existingBags` to reach the correct
      // post-round count — not just this round's raw overtricks,
      // since a threshold crossing resets the counter.
      bagsDelta: newBagCount - existingBags,
      bagPenaltyApplied: penaltyApplies,
    );
  }
}
