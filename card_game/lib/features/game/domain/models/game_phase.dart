/// The finite states a round/match can be in. The rules engine only
/// allows moves that match the current phase (e.g. a `PlayCardMove`
/// is illegal while `phase == bidding`), which is what makes cheating
/// via a malformed move structurally impossible rather than something
/// that has to be checked ad hoc.
enum GamePhase {
  /// Waiting for all four seats to submit a bid for the round.
  bidding,

  /// Bidding is complete; seats are playing tricks in turn.
  playing,

  /// All 13 tricks have been played and this round's score has been
  /// computed. Waiting for the caller to start the next round.
  roundEnd,

  /// A team has reached the match's winning score. The match is over;
  /// no further moves are accepted.
  matchOver,
}
