import 'dart:async';

import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/features/game/Presentation/bloc/game_ui_state.dart';
import 'package:card_game/features/game/Presentation/bloc/table_cubit.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/player.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:card_game/features/multiplayer/bloc/online_meta.dart';
import 'package:card_game/features/multiplayer/data/online_prefs.dart';
import 'package:card_game/features/multiplayer/data/online_session.dart';
import 'package:card_game/features/multiplayer/domain/models/match_snapshot.dart';
import 'package:card_game/features/multiplayer/domain/models/online_events.dart';
import 'package:card_game/features/multiplayer/domain/models/room_info.dart';
import 'package:card_game/features/multiplayer/domain/models/seat_perspective.dart';
import 'package:flutter/foundation.dart';

/// Runs the felt table for a server-driven match.
///
/// The server is the only authority. This cubit never applies a move
/// locally: it checks legality (so illegal taps get an instant, friendly
/// hint instead of a round trip), sends the *intent*, and then renders
/// whatever snapshot the server sends back. The snapshot is rotated so the
/// local player always sits South (see `SeatPerspective`), which lets the
/// existing table UI be reused as-is.
class OnlineGameCubit extends TableCubit {
  OnlineGameCubit({
    required OnlineSession session,
    required MatchSnapshot initial,
    required OnlinePrefs prefs,
    required HapticsService haptics,
    required AudioService audio,
    this.trickPause = const Duration(milliseconds: 1200),
  })  : _session = session,
        _prefs = prefs,
        _haptics = haptics,
        _audio = audio,
        _snap = initial,
        _persp = SeatPerspective(initial.mySeat),
        meta = ValueNotifier<OnlineMeta>(_metaFor(initial, session.status)),
        super(_stateFor(initial)) {
    _events = _session.events.listen(_onEvent);
    _status = _session.statusStream.listen(_onStatus);
  }

  final OnlineSession _session;
  final OnlinePrefs _prefs;
  final HapticsService _haptics;
  final AudioService _audio;

  /// How long a finished trick stays on the table. Zero in tests.
  final Duration trickPause;

  /// Online-only extras (connection, who is covered by a bot, emotes...).
  final ValueNotifier<OnlineMeta> meta;

  MatchSnapshot _snap;
  SeatPerspective _persp;
  late final StreamSubscription<OnlineEvent> _events;
  late final StreamSubscription<ConnectionStatus> _status;

  Timer? _pauseTimer;
  Timer? _awaitTimer;
  bool _awaitingServer = false;
  bool _readySent = false;
  bool _left = false;
  int _emoteNonce = 0;

  MatchSnapshot get snapshot => _snap;

  /// Where the local player sits on the server's table (absolute seat).
  Seat get mySeat => _snap.mySeat;

  // ---- State construction --------------------------------------------------------------

  static bool _othersTurn(GameState g) =>
      (g.phase == GamePhase.bidding || g.phase == GamePhase.playing) && g.turn != kHumanSeat;

  static Map<Seat, Player> _playersFor(MatchSnapshot s, SeatPerspective persp) => {
        for (final RoomSeatInfo info in s.seats)
          persp.toView(info.seat): Player(
            seat: persp.toView(info.seat),
            name: info.isYou ? 'You' : info.name,
            isBot: info.isBot,
          ),
      };

  static GameUiState _stateFor(MatchSnapshot s) {
    final SeatPerspective persp = SeatPerspective(s.mySeat);
    final GameState game = persp.rotate(s.game);
    return GameUiState(
      game: game,
      difficulty: AiDifficulty.medium, // unused online; the field is required
      players: _playersFor(s, persp),
      roundStartScores: persp.teamMapToView(s.roundStartScores),
      roundStartBags: persp.teamMapToView(s.roundStartBags),
      displayTrick: game.currentTrick,
      isBotThinking: _othersTurn(game),
    );
  }

  static OnlineMeta _metaFor(MatchSnapshot s, ConnectionStatus connection, {OnlineMeta? previous}) {
    final SeatPerspective persp = SeatPerspective(s.mySeat);
    return (previous ?? const OnlineMeta()).copyWith(
      connection: connection,
      seats: {
        for (final RoomSeatInfo info in s.seats)
          persp.toView(info.seat): RoomSeatInfo(
            seat: persp.toView(info.seat),
            name: info.name,
            avatarId: info.avatarId,
            isBot: info.isBot,
            connected: info.connected,
            isYou: info.isYou,
            isHost: info.isHost,
          ),
      },
      botControlled: {for (final Seat seat in s.botControlled) persp.toView(seat)},
      turnDeadlineMs: s.turnDeadlineMs,
      nextRoundDeadlineMs: s.nextRoundDeadlineMs,
    );
  }

  // ---- TableCubit ----------------------------------------------------------------------------

  @override
  Future<void> start() async {
    unawaited(_audio.playMusic(MusicTrack.tableAmbience));
    unawaited(_audio.play(SfxCue.cardDeal));
  }

  @override
  Future<void> submitBid(int tricks) async {
    final GameUiState s = state;
    if (_awaitingServer || !s.canHumanAct || s.game.phase != GamePhase.bidding) return;
    if (!SpadesRulesEngine.isValidMove(s.game, BidMove(seat: kHumanSeat, tricksBid: tricks))) return;

    if (!_session.sendBid(tricks)) {
      _hint('Reconnecting… try again in a moment.');
      return;
    }
    _haptics.selection();
    unawaited(_audio.play(SfxCue.bidConfirm));
    _markAwaiting();
  }

  @override
  Future<void> playCard(PlayingCard card) async {
    final GameUiState s = state;
    if (_awaitingServer || !s.canHumanAct || s.game.phase != GamePhase.playing) return;

    if (!SpadesRulesEngine.isValidMove(s.game, PlayCardMove(seat: kHumanSeat, card: card))) {
      _haptics.notification();
      unawaited(_audio.play(SfxCue.invalidMove));
      _hint(_explainIllegalPlay(s.game, card));
      return;
    }
    if (!_session.sendCard(card)) {
      _hint('Reconnecting… try again in a moment.');
      return;
    }
    _haptics.light();
    unawaited(_audio.play(SfxCue.cardPlace));
    _markAwaiting();
  }

  @override
  Future<void> nextRound() async {
    if (state.game.phase != GamePhase.roundEnd || state.isBusy || _readySent) return;
    _readySent = true;
    _session.readyNext();
  }

  /// "Play again" online means: leave this table and go back to the lobby
  /// (the page pops after calling this).
  @override
  Future<void> restart() async => leave();

  /// Quits the match for good; a bot takes the seat.
  void leave() {
    if (_left) return;
    _left = true;
    _session.leaveMatch();
  }

  void sendEmote(String id) => _session.sendEmote(id);

  void reportSeat(Seat viewSeat, {String reason = ''}) => _session.report(_persp.fromView(viewSeat), reason: reason);

  // ---- Inbound -----------------------------------------------------------------------------------

  void _onStatus(ConnectionStatus status) {
    if (isClosed) return;
    meta.value = meta.value.copyWith(connection: status);
  }

  void _onEvent(OnlineEvent event) {
    if (isClosed) return;
    switch (event) {
      case SnapshotReceived(snapshot: final s):
        if (s.matchId == _snap.matchId) _applySnapshot(s);
      case MatchEnded(reason: final reason):
        meta.value = meta.value.copyWith(endedReason: reason);
      case EmoteReceived(seat: final seat, id: final id):
        meta.value = meta.value.copyWith(emoteSeat: _persp.toView(seat), emoteId: id, emoteNonce: ++_emoteNonce);
      case ServerError(code: final code, message: final message):
        _awaitingServer = false;
        _awaitTimer?.cancel();
        if (code == 'illegal_move' || code == 'not_your_turn') {
          _hint('That move was not accepted.');
        } else if (code != 'rate_limited') {
          _hint(message);
        }
      case RoomChanged():
      case QueueChanged():
      case MatchStarted():
        break;
    }
  }

  void _applySnapshot(MatchSnapshot s) {
    if (s.version < _snap.version) return;
    final GameUiState prev = state;
    _snap = s;
    _persp = SeatPerspective(s.mySeat);
    _awaitingServer = false;
    _awaitTimer?.cancel();

    final GameState game = _persp.rotate(s.game);
    final GameState before = prev.game;
    final bool newRound = game.roundNumber != before.roundNumber;
    final bool trickDone = !newRound && game.completedTricks.length > before.completedTricks.length;
    final bool pausing = _pauseTimer?.isActive ?? false;

    GameUiState next = prev.copyWith(
      game: game,
      players: _playersFor(s, _persp),
      roundStartScores: _persp.teamMapToView(s.roundStartScores),
      roundStartBags: _persp.teamMapToView(s.roundStartBags),
      isBotThinking: _othersTurn(game),
    );

    if (newRound) {
      _pauseTimer?.cancel();
      _pauseTimer = null;
      _readySent = false;
      unawaited(_audio.play(SfxCue.cardDeal));
      next = next.copyWith(displayTrick: const [], clearDisplayWinner: true, isResolvingTrick: false);
    } else if (trickDone) {
      _pauseTimer?.cancel();
      _pauseTimer = Timer(trickPause, _endPause);
      unawaited(_audio.play(SfxCue.trickWin));
      next = next.copyWith(
        displayTrick: game.completedTricks.last,
        displayWinner: game.leader,
        isResolvingTrick: true,
        isBotThinking: false,
      );
    } else if (pausing) {
      next = next.copyWith(isBotThinking: false); // keep the finished trick on screen
    } else {
      if (game.currentTrick.length > before.currentTrick.length && game.currentTrick.last.seat != kHumanSeat) {
        unawaited(_audio.play(SfxCue.cardPlace));
      }
      next = next.copyWith(displayTrick: game.currentTrick, clearDisplayWinner: true);
    }

    emit(next);
    meta.value = _metaFor(s, _session.status, previous: meta.value);
  }

  void _endPause() {
    _pauseTimer = null;
    if (isClosed) return;
    final GameState g = state.game;
    emit(
      state.copyWith(
        displayTrick: g.currentTrick,
        clearDisplayWinner: true,
        isResolvingTrick: false,
        isBotThinking: _othersTurn(g),
      ),
    );
    _playRoundOrMatchCue(g);
    if (g.phase == GamePhase.matchOver) unawaited(_prefs.recordResult(won: g.winningTeam == 0));
  }

  void _playRoundOrMatchCue(GameState after) {
    if (after.phase == GamePhase.matchOver) {
      _haptics.notification();
      unawaited(_audio.play(after.winningTeam == 0 ? SfxCue.matchWin : SfxCue.matchLose));
      return;
    }
    if (after.phase == GamePhase.roundEnd) {
      final int mine = (after.teamScores[0] ?? 0) - (state.roundStartScores[0] ?? 0);
      final int theirs = (after.teamScores[1] ?? 0) - (state.roundStartScores[1] ?? 0);
      _haptics.medium();
      unawaited(_audio.play(mine >= theirs ? SfxCue.roundWin : SfxCue.roundLose));
    }
  }

  // ---- Helpers --------------------------------------------------------------------------------------

  /// Blocks double-taps until the server answers (or 3 s pass, in case a
  /// frame was lost — the next snapshot or error would clear it anyway).
  void _markAwaiting() {
    _awaitingServer = true;
    _awaitTimer?.cancel();
    _awaitTimer = Timer(const Duration(seconds: 3), () => _awaitingServer = false);
  }

  void _hint(String text) {
    if (isClosed) return;
    emit(state.copyWith(hint: text, hintNonce: state.hintNonce + 1));
  }

  String _explainIllegalPlay(GameState game, PlayingCard card) {
    final List<PlayingCard> hand = game.hands[kHumanSeat] ?? const [];
    if (!hand.contains(card)) return 'That card is not in your hand.';
    if (game.currentTrick.isEmpty) {
      if (card.suit == Suit.spades && !game.spadesBroken) {
        return 'Spades are not broken yet — lead another suit.';
      }
      return 'You cannot play that card now.';
    }
    final Suit led = game.currentTrick.first.card.suit;
    return 'You must follow suit (${led.symbol}).';
  }

  @override
  Future<void> close() async {
    _pauseTimer?.cancel();
    _awaitTimer?.cancel();
    await _events.cancel();
    await _status.cancel();
    leave();
    await _audio.stopMusic();
    meta.dispose();
    return super.close();
  }
}
