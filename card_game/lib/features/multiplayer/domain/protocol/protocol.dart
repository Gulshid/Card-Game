/// Wire protocol shared by the Flutter client and the Dart game server.
///
/// Pure Dart, no Flutter imports: the same file is compiled into the app
/// and into `server/spades_server.dart`, so the two sides can never drift
/// apart on a message name or an error code.
///
/// Every message is a JSON object `{"type": "...", ...payload}`.
const int kProtocolVersion = 1;

/// Client -> server message types.
abstract class C2S {
  static const String hello = 'hello';
  static const String ping = 'ping';
  static const String quickMatch = 'quick_match';
  static const String cancelQueue = 'cancel_queue';
  static const String createRoom = 'create_room';
  static const String joinRoom = 'join_room';
  static const String leaveRoom = 'leave_room';
  static const String startMatch = 'start_match';
  static const String move = 'move';
  static const String readyNext = 'ready_next';
  static const String leaveMatch = 'leave_match';
  static const String emote = 'emote';
  static const String report = 'report';
}

/// Server -> client message types.
abstract class S2C {
  static const String welcome = 'welcome';
  static const String pong = 'pong';
  static const String error = 'error';
  static const String queueStatus = 'queue_status';
  static const String roomUpdate = 'room_update';
  static const String roomClosed = 'room_closed';
  static const String matchStarted = 'match_started';
  static const String snapshot = 'snapshot';
  static const String emote = 'emote';
  static const String matchEnded = 'match_ended';
}

/// Machine-readable error codes (the `code` field of an `error` message).
abstract class ErrorCode {
  static const String badRequest = 'bad_request';
  static const String protocol = 'protocol_mismatch';
  static const String notInRoom = 'not_in_room';
  static const String roomNotFound = 'room_not_found';
  static const String roomFull = 'room_full';
  static const String alreadyInRoom = 'already_in_room';
  static const String notHost = 'not_host';
  static const String notInMatch = 'not_in_match';
  static const String illegalMove = 'illegal_move';
  static const String notYourTurn = 'not_your_turn';
  static const String rateLimited = 'rate_limited';
  static const String replaced = 'replaced_by_new_connection';
  static const String authFailed = 'auth_failed';
}

/// The only emotes the server will relay (a whitelist, so a modified
/// client can't use the emote channel as free-text chat).
const List<String> kEmoteIds = ['gg', 'nice', 'oops', 'thanks', 'hurry', 'wow'];

/// Room-code alphabet: no 0/O/1/I/L so codes survive being read aloud.
const String kRoomCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int kRoomCodeLength = 4;

/// Server tuning shared with the client so countdowns line up.
const int kTurnTimeLimitSeconds = 45;
const int kRoundBreakSeconds = 10;
const int kQuickMatchBotFillSeconds = 10;
const int kDisconnectGraceSeconds = 30;
