import 'package:card_game/features/game/domain/models/saved_match.dart';

/// Holds at most one suspended single-player match.
abstract interface class SavedMatchRepository {
  /// The suspended match, or `null` if there is none — or if what was on
  /// disk is unreadable (a corrupt/obsolete save is discarded, never
  /// surfaced as an error).
  Future<SavedMatch?> load();

  Future<void> save(SavedMatch match);

  Future<void> clear();
}
