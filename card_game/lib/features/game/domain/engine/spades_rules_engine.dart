import '../models/deck.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/playing_card.dart';
import '../models/seat.dart';
import '../models/suit.dart';
import '../models/trick_card.dart';
import 'scoring.dart';

/// The winning score. A round only ends a match at the point its
/// score is applied (never mid-round), matching the GDD (§7).
const int kMatchWinningScore = 500;

/// Pure functions that move a [GameState] forward. Every method here
/// is `GameState -> GameState` (or a boolean check) with no side
/// effects and no dependency on Flutter — this file can be unit
/// tested, run in an isolate, or executed on a game server unchanged.
///
/// The two halves of "don't trust the UI": [isValidMove] must be
/// called before [applyMove] by every caller, including a future
/// multiplayer server (Phase 10) re-validating a client's claimed
/// move independently.
abstract class SpadesRulesEngine {
  // ---- Starting a match / round --------------------------------------

  /// Builds the very first `GameState` of a match: shuffles, deals,
  /// and opens bidding. Pass `seed` for a reproducible deal in tests.
  static GameState newMatch({Seat dealer = Seat.north, int? seed}) {
    return _dealRound(
      dealer: dealer,
      roundNumber: 1,
      teamScores: {0: 0, 1: 0},
      teamBags: {0: 0, 1: 0},
      seed: seed,
    );
  }

  /// Deals the next round after the current one reached `roundEnd`.
  /// Dealer rotates clockwise; scores/bags carry over from `state`.
  static GameState startNextRound(GameState state, {int? seed}) {
    if (state.phase != GamePhase.roundEnd) {
      throw StateError('startNextRound called outside GamePhase.roundEnd (was ${state.phase})');
    }
    return _dealRound(
      dealer: state.dealer.next,
      roundNumber: state.roundNumber + 1,
      teamScores: state.teamScores,
      teamBags: state.teamBags,
      seed: seed,
    );
  }

  static GameState _dealRound({
    required Seat dealer,
    required int roundNumber,
    required Map<int, int> teamScores,
    required Map<int, int> teamBags,
    int? seed,
  }) {
    final List<List<PlayingCard>> dealt = Deck.standard52().shuffled(seed: seed).dealEqually(4);
    final Map<Seat, List<PlayingCard>> hands = {
      for (final seat in Seat.values) seat: dealt[seat.index],
    };
    final Seat firstToBid = dealer.next;

    return GameState(
      phase: GamePhase.bidding,
      dealer: dealer,
      turn: firstToBid,
      leader: firstToBid,
      hands: hands,
      bids: {for (final seat in Seat.values) seat: null},
      currentTrick: const [],
      completedTricks: const [],
      tricksWonBySeat: {for (final seat in Seat.values) seat: 0},
      spadesBroken: false,
      teamScores: teamScores,
      teamBags: teamBags,
      roundNumber: roundNumber,
    );
  }

  // ---- Move validation -------------------------------------------------

  /// The single legality check every move must pass. UI code, bots
  /// (Phase 06), and a multiplayer server (Phase 10) all call this
  /// before ever calling [applyMove] — never the reverse.
  static bool isValidMove(GameState state, Move move) {
    if (move.seat != state.turn) return false;

    return switch (move) {
      BidMove(tricksBid: final bid) => state.phase == GamePhase.bidding && bid >= 0 && bid <= 13,
      PlayCardMove(card: final card) => _isValidPlay(state, move.seat, card),
    };
  }

  static bool _isValidPlay(GameState state, Seat seat, PlayingCard card) {
    if (state.phase != GamePhase.playing) return false;

    final List<PlayingCard> hand = state.hands[seat] ?? const [];
    if (!hand.contains(card)) return false;

    final bool isLeadingTrick = state.currentTrick.isEmpty;

    if (isLeadingTrick) {
      final bool onlyHoldsSpades = hand.every((c) => c.suit == Suit.spades);
      if (card.suit == Suit.spades && !state.spadesBroken && !onlyHoldsSpades) {
        return false; // may not break spades on lead unless forced to
      }
      return true;
    }

    final Suit ledSuit = state.currentTrick.first.card.suit;
    final bool hasLedSuit = hand.any((c) => c.suit == ledSuit);
    if (hasLedSuit && card.suit != ledSuit) {
      return false; // must follow suit if able
    }
    return true;
  }

  // ---- Move application -------------------------------------------------

  /// Applies an already-validated move. Callers must check
  /// [isValidMove] first — this method trusts its input and will
  /// throw a [StateError] rather than silently accept an illegal move,
  /// so a bug upstream fails loudly instead of corrupting game state.
  static GameState applyMove(GameState state, Move move) {
    if (!isValidMove(state, move)) {
      throw StateError('Illegal move $move for state phase ${state.phase}');
    }
    return switch (move) {
      BidMove() => _applyBid(state, move),
      PlayCardMove() => _applyPlayCard(state, move),
    };
  }

  static GameState _applyBid(GameState state, BidMove move) {
    final Map<Seat, int?> updatedBids = {...state.bids, move.seat: move.tricksBid};
    final bool biddingComplete = updatedBids.values.every((b) => b != null);

    return state.copyWith(
      bids: updatedBids,
      turn: biddingComplete ? state.leader : move.seat.next,
      phase: biddingComplete ? GamePhase.playing : GamePhase.bidding,
    );
  }

  static GameState _applyPlayCard(GameState state, PlayCardMove move) {
    final List<PlayingCard> updatedHand = List.of(state.hands[move.seat] ?? const [])..remove(move.card);
    final Map<Seat, List<PlayingCard>> updatedHands = {...state.hands, move.seat: updatedHand};
    final List<TrickCard> updatedTrick = [...state.currentTrick, TrickCard(seat: move.seat, card: move.card)];
    final bool spadesBroken = state.spadesBroken || move.card.suit == Suit.spades;

    if (updatedTrick.length < 4) {
      return state.copyWith(
        hands: updatedHands,
        currentTrick: updatedTrick,
        turn: move.seat.next,
        spadesBroken: spadesBroken,
      );
    }

    // Trick complete: resolve the winner, file it into history, and
    // either open the next trick or close out the round.
    final Seat trickWinner = _resolveTrickWinner(updatedTrick);
    final Map<Seat, int> updatedTricksWon = {
      ...state.tricksWonBySeat,
      trickWinner: (state.tricksWonBySeat[trickWinner] ?? 0) + 1,
    };
    final List<List<TrickCard>> updatedCompleted = [...state.completedTricks, updatedTrick];
    final bool roundComplete = updatedHands.values.every((hand) => hand.isEmpty);

    if (!roundComplete) {
      return state.copyWith(
        hands: updatedHands,
        currentTrick: const [],
        completedTricks: updatedCompleted,
        tricksWonBySeat: updatedTricksWon,
        spadesBroken: spadesBroken,
        leader: trickWinner,
        turn: trickWinner,
      );
    }

    return _closeRound(
      state.copyWith(
        hands: updatedHands,
        currentTrick: const [],
        completedTricks: updatedCompleted,
        tricksWonBySeat: updatedTricksWon,
        spadesBroken: spadesBroken,
        leader: trickWinner,
        turn: trickWinner,
      ),
    );
  }

  /// Highest card of the led suit wins, unless a spade was played —
  /// then the highest spade wins regardless of what was led.
  static Seat _resolveTrickWinner(List<TrickCard> trick) {
    final Suit ledSuit = trick.first.card.suit;
    final bool anySpadePlayed = trick.any((tc) => tc.card.suit == Suit.spades);
    final Suit winningSuit = anySpadePlayed ? Suit.spades : ledSuit;

    TrickCard winner = trick.firstWhere((tc) => tc.card.suit == winningSuit);
    for (final tc in trick) {
      if (tc.card.suit == winningSuit && tc.card.rank.value > winner.card.rank.value) {
        winner = tc;
      }
    }
    return winner.seat;
  }

  static GameState _closeRound(GameState state) {
    final TeamRoundScore teamZero = Scoring.scoreTeam(
      team: 0,
      bids: state.bids,
      tricksWonBySeat: state.tricksWonBySeat,
      existingBags: state.teamBags[0] ?? 0,
    );
    final TeamRoundScore teamOne = Scoring.scoreTeam(
      team: 1,
      bids: state.bids,
      tricksWonBySeat: state.tricksWonBySeat,
      existingBags: state.teamBags[1] ?? 0,
    );

    final Map<int, int> updatedScores = {
      0: (state.teamScores[0] ?? 0) + teamZero.scoreDelta,
      1: (state.teamScores[1] ?? 0) + teamOne.scoreDelta,
    };
    final Map<int, int> updatedBags = {
      0: (state.teamBags[0] ?? 0) + teamZero.bagsDelta,
      1: (state.teamBags[1] ?? 0) + teamOne.bagsDelta,
    };

    final bool teamZeroWins = updatedScores[0]! >= kMatchWinningScore;
    final bool teamOneWins = updatedScores[1]! >= kMatchWinningScore;
    // If both cross the threshold in the same round (rare), the
    // strictly higher score wins; an exact tie plays on, since
    // Spades has no defined tiebreak-by-score rule.
    final bool matchOver = teamZeroWins || teamOneWins;
    final int? winningTeam = !matchOver
        ? null
        : (teamZeroWins && teamOneWins)
            ? (updatedScores[0]! == updatedScores[1]! ? null : (updatedScores[0]! > updatedScores[1]! ? 0 : 1))
            : (teamZeroWins ? 0 : 1);

    return state.copyWith(
      phase: winningTeam != null ? GamePhase.matchOver : GamePhase.roundEnd,
      teamScores: updatedScores,
      teamBags: updatedBags,
      winningTeam: winningTeam,
    );
  }
}
