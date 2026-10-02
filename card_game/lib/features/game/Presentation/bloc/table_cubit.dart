import 'package:card_game/features/game/Presentation/bloc/game_ui_state.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the felt table needs from whatever is running the match.
///
/// Before Phase 10 the table was wired straight to `GameCubit` (three
/// bots). Online play needs the exact same screen driven by a different
/// brain, so the table now depends only on this contract:
///  * `GameCubit` implements it for offline matches vs bots;
///  * `OnlineGameCubit` implements it for server-driven matches.
abstract class TableCubit extends Cubit<GameUiState> {
  TableCubit(super.initialState);

  /// Called once after creation; starts music and any turn loop.
  Future<void> start();

  /// The local player bids [tricks] (0 = Nil).
  Future<void> submitBid(int tricks);

  /// The local player plays [card].
  Future<void> playCard(PlayingCard card);

  /// The local player is done with the round summary.
  Future<void> nextRound();

  /// "Play again" on the match-result sheet.
  Future<void> restart();
}
