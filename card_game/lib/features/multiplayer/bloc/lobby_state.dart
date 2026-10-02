import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:equatable/equatable.dart';

enum LobbyPhase {
  /// Connected (or connecting) with nothing in progress.
  idle,

  /// In the quick-match queue.
  searching,

  /// Sitting in a private room.
  inRoom,

  /// A match exists; the lobby page is about to open (or has opened) the table.
  inMatch,
}

class LobbyState extends Equatable {
  const LobbyState({
    this.connection = ConnectionStatus.disconnected,
    this.phase = LobbyPhase.idle,
    this.room,
    this.queueWaiting = 0,
    this.queueElapsed = 0,
    this.fillInSeconds = 0,
    this.message,
    this.messageNonce = 0,
    this.matchNonce = 0,
    this.played = 0,
    this.wins = 0,
    this.serverUrl = '',
  });

  final ConnectionStatus connection;
  final LobbyPhase phase;
  final RoomInfo? room;
  final int queueWaiting;
  final int queueElapsed;
  final int fillInSeconds;

  /// Transient error/info text; [messageNonce] bumps so identical text re-shows.
  final String? message;
  final int messageNonce;

  /// Bumps each time a match starts so the page navigates exactly once.
  final int matchNonce;

  final int played;
  final int wins;
  final String serverUrl;

  bool get isOnline => connection == ConnectionStatus.connected;

  LobbyState copyWith({
    ConnectionStatus? connection,
    LobbyPhase? phase,
    RoomInfo? room,
    bool clearRoom = false,
    int? queueWaiting,
    int? queueElapsed,
    int? fillInSeconds,
    String? message,
    int? messageNonce,
    int? matchNonce,
    int? played,
    int? wins,
    String? serverUrl,
  }) {
    return LobbyState(
      connection: connection ?? this.connection,
      phase: phase ?? this.phase,
      room: clearRoom ? null : (room ?? this.room),
      queueWaiting: queueWaiting ?? this.queueWaiting,
      queueElapsed: queueElapsed ?? this.queueElapsed,
      fillInSeconds: fillInSeconds ?? this.fillInSeconds,
      message: message ?? this.message,
      messageNonce: messageNonce ?? this.messageNonce,
      matchNonce: matchNonce ?? this.matchNonce,
      played: played ?? this.played,
      wins: wins ?? this.wins,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  @override
  List<Object?> get props => [
        connection,
        phase,
        room,
        queueWaiting,
        queueElapsed,
        fillInSeconds,
        message,
        messageNonce,
        matchNonce,
        played,
        wins,
        serverUrl,
      ];
}
