import 'package:card_game/core/storage/local_store.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Production [LocalStore] backed by a single Hive box of strings.
///
/// One box is enough: the app stores a handful of small JSON documents
/// (profile, stats, history, achievements, the in-progress match).
/// Hive's writes are queued per box, so a `delete` issued after a `write`
/// can never overtake it — the saved-match repository relies on that.
class HiveLocalStore implements LocalStore {
  HiveLocalStore._(this._box);

  final Box<String> _box;

  static const String defaultBoxName = 'spades_royale_store';

  /// Initializes Hive and opens the box. If the file on disk is corrupt
  /// (rare: e.g. the process was killed mid-write on a failing disk) the
  /// box is wiped and recreated rather than letting the app crash on
  /// every launch — losing stats is far better than a bricked app.
  static Future<HiveLocalStore> open({String boxName = defaultBoxName}) async {
    await Hive.initFlutter();
    Box<String> box;
    try {
      box = await Hive.openBox<String>(boxName);
    } catch (_) {
      await Hive.deleteBoxFromDisk(boxName);
      box = await Hive.openBox<String>(boxName);
    }
    return HiveLocalStore._(box);
  }

  @override
  Future<String?> read(String key) async => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}
