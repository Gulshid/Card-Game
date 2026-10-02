/// Minimal async key/value contract the persistence layer is built on.
///
/// Repositories (profile, saved match) depend on this interface, never on
/// Hive directly. That gives two things: the production app uses
/// [HiveLocalStore], and every repository test runs against
/// [InMemoryLocalStore] with no plugin, no disk and no setup.
///
/// Values are plain `String`s (repositories store JSON), which keeps the
/// on-disk format inspectable and independent of any database's own
/// serialization — swapping Hive for Drift later only means writing one
/// new implementation of these three methods.
abstract interface class LocalStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Map-backed [LocalStore] used by tests (and usable as a no-op store in
/// previews). Nothing is persisted beyond the object's lifetime.
class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  /// Read-only view, handy for asserting exactly what was written.
  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
