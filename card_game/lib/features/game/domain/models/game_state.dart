import 'package:equatable/equatable.dart';

import 'game_phase.dart';
import 'playing_card.dart';
import 'seat.dart';
import 'trick_card.dart';

/// The entire state of a Spades match at any point in time. Wholly
/// immutable and serializable-by-construction (every field is a
/// primitive, enum, or Dart collection) — this is what will let
/// Phase 09 persist an in-progress match and Phase 10 sync it over
/// the network with nothing more than `toJson`/`fromJson` wrappers.
///
/// `GameState` never mutates itself. Every transition lives in
/// `SpadesRulesEngine` as a pure `GameState -> GameState` function;
/// this class only holds data and cheap derived getters.
class GameState extends Equatable {
  const GameState({
    required this.phase,
    required this.dealer,
    required this.turn,
    required this.leader,
    required this.hands,
    required this.bids,
    required this.currentTrick,
    required this.completedTricks,
    required this.tricksWonBySeat,
    required this.spadesBroken,
    required this.teamScores,
    required this.teamBags,
    required this.roundNumber,
    this.winningTeam,
  });

  /// The round/match's current finite state.
  final GamePhase phase;

  /// Deals rotate clockwise from this seat each round.
  final Seat dealer;

  /// Whose turn it is to bid (phase == bidding) or play (phase == playing).
  final Seat turn;

  /// Who leads the current (or, between tricks, the next) trick.
  final Seat leader;

  /// Each seat's remaining, unplayed cards.
  final Map<Seat, List<PlayingCard>> hands;

  /// Each seat's bid for this round. `null` until that seat has bid.
  final Map<Seat, int?> bids;

  /// Cards played to the trick currently in progress, in play order.
  final List<TrickCard> currentTrick;

  /// Every finished trick this round, oldest first — kept for
  /// animation/replay in Phase 05, not required by the engine itself.
  final List<List<TrickCard>> completedTricks;

  /// Individual trick count per seat this round (not per team) —
  /// needed at scoring time to check whether a Nil bidder specifically
  /// took zero tricks, independent of their partner's tricks.
  final Map<Seat, int> tricksWonBySeat;

  /// Once true, spades may be led on any subsequent trick this round.
  final bool spadesBroken;

  /// Cumulative match score per team index (0 = N/S, 1 = E/W).
  final Map<int, int> teamScores;

  /// Cumulative unpenalized overtrick ("bag") count per team.
  final Map<int, int> teamBags;

  final int roundNumber;

  /// Set only once `phase == GamePhase.matchOver`.
  final int? winningTeam;

  // ---- Derived, read-only convenience getters ------------------------

  bool get isBiddingComplete => bids.values.every((bid) => bid != null);

  int tricksWonByTeam(int team) {
    return Seat.values.where((s) => s.team == team).fold(0, (sum, s) => sum + (tricksWonBySeat[s] ?? 0));
  }

  GameState copyWith({
    GamePhase? phase,
    Seat? dealer,
    Seat? turn,
    Seat? leader,
    Map<Seat, List<PlayingCard>>? hands,
    Map<Seat, int?>? bids,
    List<TrickCard>? currentTrick,
    List<List<TrickCard>>? completedTricks,
    Map<Seat, int>? tricksWonBySeat,
    bool? spadesBroken,
    Map<int, int>? teamScores,
    Map<int, int>? teamBags,
    int? roundNumber,
    int? winningTeam,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      dealer: dealer ?? this.dealer,
      turn: turn ?? this.turn,
      leader: leader ?? this.leader,
      hands: hands ?? this.hands,
      bids: bids ?? this.bids,
      currentTrick: currentTrick ?? this.currentTrick,
      completedTricks: completedTricks ?? this.completedTricks,
      tricksWonBySeat: tricksWonBySeat ?? this.tricksWonBySeat,
      spadesBroken: spadesBroken ?? this.spadesBroken,
      teamScores: teamScores ?? this.teamScores,
      teamBags: teamBags ?? this.teamBags,
      roundNumber: roundNumber ?? this.roundNumber,
      winningTeam: winningTeam ?? this.winningTeam,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        dealer,
        turn,
        leader,
        hands,
        bids,
        currentTrick,
        completedTricks,
        tricksWonBySeat,
        spadesBroken,
        teamScores,
        teamBags,
        roundNumber,
        winningTeam,
      ];
}
