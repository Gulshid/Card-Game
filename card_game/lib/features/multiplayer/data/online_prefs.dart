import 'package:shared_preferences/shared_preferences.dart';

/// Server address used when the app is built without `--dart-define`.
/// `10.0.2.2` is how the Android emulator reaches the host machine; use
/// `--dart-define=SPADES_SERVER_URL=ws://<LAN-IP>:8080/ws` for a real phone,
/// or `wss://your.domain/ws` in production.
const String kDefaultServerUrl = String.fromEnvironment('SPADES_SERVER_URL', defaultValue: 'ws://10.0.2.2:8080/ws');

/// Small on-device state for online play: the guest token that lets the
/// server recognise us after a reconnect or app restart, the server
/// address, and a running online win/loss tally.
///
/// Synchronous getters (SharedPreferences is already loaded at startup)
/// keep the session code simple; setters are async.
abstract interface class OnlinePrefs {
  String? get token;
  Future<void> setToken(String token);

  String get serverUrl;

  /// Pass `null` (or an empty string) to go back to the default.
  Future<void> setServerUrl(String? url);

  int get played;
  int get wins;
  Future<void> recordResult({required bool won});
}

class PrefsOnlinePrefs implements OnlinePrefs {
  PrefsOnlinePrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _kToken = 'online.token';
  static const String _kUrl = 'online.serverUrl';
  static const String _kPlayed = 'online.played';
  static const String _kWins = 'online.wins';

  @override
  String? get token => _prefs.getString(_kToken);

  @override
  Future<void> setToken(String token) => _prefs.setString(_kToken, token);

  @override
  String get serverUrl => _prefs.getString(_kUrl) ?? kDefaultServerUrl;

  @override
  Future<void> setServerUrl(String? url) async {
    final String? trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _prefs.remove(_kUrl);
    } else {
      await _prefs.setString(_kUrl, trimmed);
    }
  }

  @override
  int get played => _prefs.getInt(_kPlayed) ?? 0;

  @override
  int get wins => _prefs.getInt(_kWins) ?? 0;

  @override
  Future<void> recordResult({required bool won}) async {
    await _prefs.setInt(_kPlayed, played + 1);
    if (won) await _prefs.setInt(_kWins, wins + 1);
  }
}

/// Test double.
class MemoryOnlinePrefs implements OnlinePrefs {
  MemoryOnlinePrefs({this.token, String? serverUrl}) : _url = serverUrl;

  @override
  String? token;
  String? _url;
  @override
  int played = 0;
  @override
  int wins = 0;

  @override
  Future<void> setToken(String token) async => this.token = token;

  @override
  String get serverUrl => _url ?? kDefaultServerUrl;

  @override
  Future<void> setServerUrl(String? url) async => _url = (url == null || url.trim().isEmpty) ? null : url.trim();

  @override
  Future<void> recordResult({required bool won}) async {
    played++;
    if (won) wins++;
  }
}
