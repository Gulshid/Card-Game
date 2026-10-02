import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/game/domain/repositories/saved_match_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tells Home whether there is a suspended match to offer "Resume" for.
/// State is the [SavedMatch] itself, or `null` when there is none.
class ResumeMatchCubit extends Cubit<SavedMatch?> {
  ResumeMatchCubit({required SavedMatchRepository repository})
      : _repository = repository,
        super(null);

  final SavedMatchRepository _repository;

  /// Re-reads the save. Call at startup and whenever the table screen
  /// closes (the match may have been finished, abandoned or progressed).
  Future<void> refresh() async {
    final SavedMatch? saved = await _repository.load();
    if (!isClosed) emit(saved);
  }

  /// Player chose to throw the suspended match away.
  Future<void> abandon() async {
    await _repository.clear();
    if (!isClosed) emit(null);
  }
}
