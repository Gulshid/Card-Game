/// Pluggable identity check, run during `hello`.
///
/// The default [GuestAuthenticator] lets anyone in as an anonymous guest
/// (identity = a server-issued token the client keeps). To upgrade to real
/// accounts, implement [verify] against Firebase Auth / Supabase / your own
/// JWT issuer and return the verified user id: the hub will then key the
/// player's session on that id instead of the guest token.
abstract interface class Authenticator {
  /// Returns a stable, verified user id for [idToken], or `null` to treat
  /// the caller as a guest. Throw [AuthException] to reject the connection.
  Future<String?> verify(String? idToken);
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Anonymous guests only.
class GuestAuthenticator implements Authenticator {
  const GuestAuthenticator();

  @override
  Future<String?> verify(String? idToken) async => null;
}
