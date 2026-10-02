import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/player.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';
import 'package:equatable/equatable.dart';

/// The human always sits South; North is their partner.
const Seat kHumanSeat = Seat.south;

const Map<Seat, Player> kDefaultPlayers = {
  Seat.north: Player(seat: Seat.north, name: 'Ava', isBot: true),
  Seat.east: Player(seat: Seat.east, name: 'Ben', isBot: true),
  Seat.south: Player(seat: Seat.south, name: 'You'),
  Seat.west: Player(seat: Seat.west, name: 'Cleo', isBot: true),
};

/// Team 0 is North/South (the human's side); team 1 is East/West.
const List<String> kTeamNames = ['Us', 'Them'];

/// Everything the table screen renders: the engine's [GameState] plus the
/// presentation-only pieces the engine deliberately doesn't know about
/// (bot "thinking", the pause that lets you see a finished trick, hints).
class GameUiState extends Equatable {
  const GameUiState({
    required this.game,
    required this.difficulty,
    required this.roundStartScores,
    required this.roundStartBags,
    this.players = kDefaultPlayers,
    this.displayTrick = const [],
    this.displayWinner,
    this.isBotThinking = false,
    this.isResolvingTrick = false,
    this.hint,
    this.hintNonce = 0,
    this.newlyUnlocked = const [],
  });

  factory GameUiState.initial({required AiDifficulty difficulty, required GameState game}) {
    return GameUiState(
      game: game,
      difficulty: difficulty,
      roundStartScores: game.teamScores,
      roundStartBags: game.teamBags,
    );
  }

  final GameState game;
  final AiDifficulty difficulty;
  final Map<Seat, Player> players;

  /// Team scores/bags when the current round began, so the summary can
  /// show this round's points as a delta.
  final Map<int, int> roundStartScores;
  final Map<int, int> roundStartBags;

  /// Cards shown in the middle of the table. Normally the engine's
  /// current trick, but held on the finished trick for a moment after the
  /// 4th card so the player can see who won it.
  final List<TrickCard> displayTrick;
  final Seat? displayWinner;

  final bool isBotThinking;
  final bool isResolvingTrick;

  /// Transient message (e.g. an illegal-play explanation). [hintNonce]
  /// increments on every new hint so the same text can show twice.
  final String? hint;
  final int hintNonce;

  /// Achievements earned by the match that just ended (Phase 09); shown on
  /// the match-result sheet. Empty at all other times.
  final List<Achievement> newlyUnlocked;

  bool get isBusy => isBotThinking || isResolvingTrick;

  bool get isHumanTurn =>
      game.turn == kHumanSeat && (game.phase == GamePhase.bidding || game.phase == GamePhase.playing);

  bool get canHumanAct => isHumanTurn && !isBusy;

  bool get showRoundSummary => game.phase == GamePhase.roundEnd && !isResolvingTrick;

  bool get showMatchResult => game.phase == GamePhase.matchOver && !isResolvingTrick;

  /// Points a team scored in the current (or just finished) round.
  int roundPointsFor(int team) => (game.teamScores[team] ?? 0) - (roundStartScores[team] ?? 0);

  GameUiState copyWith({
    GameState? game,
    AiDifficulty? difficulty,
    Map<int, int>? roundStartScores,
    Map<int, int>? roundStartBags,
    List<TrickCard>? displayTrick,
    Seat? displayWinner,
    bool clearDisplayWinner = false,
    bool? isBotThinking,
    bool? isResolvingTrick,
    String? hint,
    int? hintNonce,
    List<Achievement>? newlyUnlocked,
  }) {
    return GameUiState(
      game: game ?? this.game,
      difficulty: difficulty ?? this.difficulty,
      players: players,
      roundStartScores: roundStartScores ?? this.roundStartScores,
      roundStartBags: roundStartBags ?? this.roundStartBags,
      displayTrick: displayTrick ?? this.displayTrick,
      displayWinner: clearDisplayWinner ? null : (displayWinner ?? this.displayWinner),
      isBotThinking: isBotThinking ?? this.isBotThinking,
      isResolvingTrick: isResolvingTrick ?? this.isResolvingTrick,
      hint: hint ?? this.hint,
      hintNonce: hintNonce ?? this.hintNonce,
      newlyUnlocked: newlyUnlocked ?? this.newlyUnlocked,
    );
  }

  @override
  List<Object?> get props => [
        game,
        difficulty,
        players,
        roundStartScores,
        roundStartBags,
        displayTrick,
        displayWinner,
        isBotThinking,
        isResolvingTrick,
        hint,
        hintNonce,
        newlyUnlocked,
      ];
}
