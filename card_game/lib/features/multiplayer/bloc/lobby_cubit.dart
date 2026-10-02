import 'dart:async';

import 'package:card_game/features/multiplayer/bloc/lobby_state.dart';
import 'package:card_game/features/multiplayer/data/online_prefs.dart';
import 'package:card_game/features/multiplayer/data/online_session.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/protocol/protocol.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the online lobby: connection status, quick match, private rooms.
/// All truth lives on the server — this cubit only mirrors what
/// `OnlineSession` reports and forwards the player's button presses.
class LobbyCubit extends Cubit<LobbyState> {
  LobbyCubit({required OnlineSession session, required OnlinePrefs prefs})
      : _session = session,
        _prefs = prefs,
        super(
          LobbyState(
            connection: session.status,
            played: prefs.played,
            wins: prefs.wins,
            serverUrl: prefs.serverUrl,
          ),
        ) {
    _eventsSub = _session.events.listen(_onEvent);
    _statusSub = _session.statusStream.listen(_onStatus);
  }

  final OnlineSession _session;
  final OnlinePrefs _prefs;
  late final StreamSubscription<OnlineEvent> _eventsSub;
  late final StreamSubscription<ConnectionStatus> _statusSub;

  /// Opens the connection. If the server says we are already in a match
  /// (we dropped mid-game and came back), `MatchStarted` follows and the
  /// page jumps straight back to the table.
  Future<void> init() async {
    await _session.goOnline();
    _syncFromSession();
  }

  void _syncFromSession() {
    if (isClosed) return;
    if (_session.matchId != null) {
      emit(state.copyWith(phase: LobbyPhase.inMatch, matchNonce: state.matchNonce + 1, clearRoom: true));
    } else if (_session.room != null) {
      emit(state.copyWith(phase: LobbyPhase.inRoom, room: _session.room));
    }
  }

  void _onStatus(ConnectionStatus status) {
    if (isClosed) return;
    emit(state.copyWith(connection: status));
  }

  void _onEvent(OnlineEvent event) {
    if (isClosed) return;
    switch (event) {
      case RoomChanged(room: final room):
        if (room == null) {
          if (state.phase == LobbyPhase.inRoom) emit(state.copyWith(phase: LobbyPhase.idle, clearRoom: true));
        } else {
          emit(state.copyWith(phase: LobbyPhase.inRoom, room: room));
        }
      case QueueChanged(active: final active, waiting: final waiting, elapsed: final elapsed, fillInSeconds: final fill):
        if (active) {
          emit(
            state.copyWith(
              phase: LobbyPhase.searching,
              queueWaiting: waiting,
              queueElapsed: elapsed,
              fillInSeconds: fill,
            ),
          );
        } else if (state.phase == LobbyPhase.searching) {
          emit(state.copyWith(phase: LobbyPhase.idle));
        }
      case MatchStarted():
        emit(state.copyWith(phase: LobbyPhase.inMatch, matchNonce: state.matchNonce + 1, clearRoom: true));
      case ServerError():
        // ignore: unnecessary_cast
        _say(_friendly(event as ServerError));
      case SnapshotReceived():
      case MatchEnded():
      case EmoteReceived():
        break;
    }
  }

  String _friendly(ServerError e) {
    switch (e.code) {
      case ErrorCode.roomNotFound:
        return "That room code doesn't exist.";
      case ErrorCode.roomFull:
        return 'That room is full.';
      case ErrorCode.protocol:
        return 'This app version is too old for the server. Please update.';
      case ErrorCode.replaced:
        return 'You signed in on another device.';
      case ErrorCode.rateLimited:
        return 'Slow down a little.';
      default:
        return e.message;
    }
  }

  void _say(String text) => emit(state.copyWith(message: text, messageNonce: state.messageNonce + 1));

  bool _requireOnline() {
    if (_session.isOnline) return true;
    _say('Not connected to the server yet.');
    return false;
  }

  // ---- Actions ---------------------------------------------------------------------

  void quickMatch() {
    if (!_requireOnline()) return;
    _session.quickMatch();
  }

  void cancelSearch() {
    _session.cancelQueue();
    emit(state.copyWith(phase: LobbyPhase.idle));
  }

  void createRoom() {
    if (!_requireOnline()) return;
    _session.createRoom();
  }

  void joinRoom(String code) {
    if (!_requireOnline()) return;
    final String trimmed = code.trim();
    if (trimmed.length != kRoomCodeLength) {
      _say('Room codes are $kRoomCodeLength characters.');
      return;
    }
    _session.joinRoom(trimmed);
  }

  void leaveRoom() {
    _session.leaveRoom();
    emit(state.copyWith(phase: LobbyPhase.idle, clearRoom: true));
  }

  void startRoomMatch() {
    if (!_requireOnline()) return;
    _session.startMatch();
  }

  Future<void> retryConnection() => _session.retryNow();

  Future<void> setServerUrl(String url) async {
    await _prefs.setServerUrl(url);
    emit(state.copyWith(serverUrl: _prefs.serverUrl));
    // Reconnect to the new address.
    await _session.goOffline();
    await _session.goOnline();
  }

  /// The table was closed; refresh the tally and return to an idle lobby.
  void matchLeft() {
    if (isClosed) return;
    emit(state.copyWith(phase: LobbyPhase.idle, played: _prefs.played, wins: _prefs.wins, clearRoom: true));
  }

  @override
  Future<void> close() async {
    await _eventsSub.cancel();
    await _statusSub.cancel();
    // Leaving the lobby with nothing in progress frees the socket; an
    // active match keeps it (the table still needs it).
    if (!_session.hasActiveMatch) {
      if (state.phase == LobbyPhase.searching) _session.cancelQueue();
      if (state.phase == LobbyPhase.inRoom) _session.leaveRoom();
      await _session.goOffline();
    }
    return super.close();
  }
}
