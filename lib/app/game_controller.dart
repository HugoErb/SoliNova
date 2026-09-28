import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../engine/model/game_mode.dart';
import '../engine/model/move.dart';
import '../engine/model/pile.dart';
import '../engine/rng/seeded_random.dart';
import '../engine/rules/move_advisor.dart';
import '../engine/scoring/score_calculator.dart';
import '../engine/session/game_session.dart';
import '../meta/daily/daily_challenge.dart';
import '../meta/profile/game_completion.dart';
import '../ui/feedback/feedback_service.dart';
import 'providers.dart';

/// Indice affiché : cartes à déplacer et pile cible.
@immutable
final class HintInfo {
  const HintInfo({
    required this.cardIds,
    this.target,
    required this.serial,
    required this.advice,
  });

  final Set<int> cardIds;
  final PileRef? target;
  final int serial;
  final MoveAdvice advice;
}

/// État observé par l'écran de jeu.
@immutable
final class GameViewState {
  const GameViewState({
    this.session,
    this.hint,
    this.invalidCards = const {},
    this.invalidSerial = 0,
    this.dealSerial = 0,
    this.paused = false,
    this.autoPlaying = false,
    this.report,
  });

  final GameSession? session;
  final HintInfo? hint;

  /// Cartes à secouer après un mouvement refusé.
  final Set<int> invalidCards;
  final int invalidSerial;

  /// Incrémenté à chaque nouvelle distribution (animation de donne).
  final int dealSerial;
  final bool paused;
  final bool autoPlaying;

  /// Bilan de la dernière victoire (écran de victoire).
  final GameReport? report;

  bool get canAutoComplete {
    final s = session;
    return s != null &&
        !autoPlaying &&
        !s.isWon &&
        s.rules.canAutoComplete(s.state);
  }

  GameViewState copyWith({
    GameSession? session,
    bool clearSession = false,
    HintInfo? hint,
    bool clearHint = false,
    Set<int>? invalidCards,
    int? invalidSerial,
    int? dealSerial,
    bool? paused,
    bool? autoPlaying,
    GameReport? report,
    bool clearReport = false,
  }) => GameViewState(
    session: clearSession ? null : (session ?? this.session),
    hint: clearHint ? null : (hint ?? this.hint),
    invalidCards: invalidCards ?? this.invalidCards,
    invalidSerial: invalidSerial ?? this.invalidSerial,
    dealSerial: dealSerial ?? this.dealSerial,
    paused: paused ?? this.paused,
    autoPlaying: autoPlaying ?? this.autoPlaying,
    report: clearReport ? null : (report ?? this.report),
  );
}

final gameProvider = NotifierProvider<GameController, GameViewState>(
  GameController.new,
);

/// Orchestration d'une partie : coups, automatismes, chronomètre,
/// sauvegarde et fin de partie. La logique de jeu reste dans le moteur.
class GameController extends Notifier<GameViewState> {
  late GameRepository _repo;
  late DebouncedSaver<GameSession> _saver;

  /// Temps affiché, mis à jour chaque seconde sans reconstruire le plateau.
  final ValueNotifier<int> elapsed = ValueNotifier(0);

  final _messages = StreamController<String>.broadcast();

  /// Messages courts à afficher (ex. « Aucun mouvement utile »).
  Stream<String> get messages => _messages.stream;

  final Stopwatch _watch = Stopwatch();
  int _base = 0;
  Timer? _ticker;
  bool _screenActive = false;
  bool _foreground = true;
  int _hintSerial = 0;
  int _autoToken = 0;

  @override
  GameViewState build() {
    _repo = GameRepository(ref.read(storeProvider));
    _saver = DebouncedSaver<GameSession>(_repo.save);
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_messages.close());
    });
    final session = ref.read(initialSessionProvider);
    final restored = session != null && !session.isWon ? session : null;
    _base = restored?.elapsedMs ?? 0;
    elapsed.value = _base;
    return GameViewState(session: restored);
  }

  FeedbackService get _fx => ref.read(feedbackProvider);

  bool get hasResumableGame => state.session != null && state.report == null;

  // ---------------------------------------------------------------------------
  // Chronomètre : ne tourne que pendant une partie commencée, visible,
  // au premier plan et non en pause.

  int get _elapsedNow => _base + _watch.elapsedMilliseconds;

  void _updateClock() {
    final s = state.session;
    final shouldRun =
        s != null &&
        s.started &&
        !s.isWon &&
        !state.paused &&
        _screenActive &&
        _foreground;
    if (shouldRun && !_watch.isRunning) {
      _watch.start();
      _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
        elapsed.value = _elapsedNow;
      });
    } else if (!shouldRun && _watch.isRunning) {
      _watch.stop();
      _base += _watch.elapsedMilliseconds;
      _watch.reset();
      _ticker?.cancel();
      _ticker = null;
      elapsed.value = _base;
      _persist();
    }
  }

  void setScreenActive(bool active) {
    _screenActive = active;
    _updateClock();
  }

  /// Passage en arrière-plan / retour : on fige le temps et on sauvegarde.
  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    _updateClock();
    if (!foreground) await _saver.flush();
  }

  void _resetClock(int ms) {
    _watch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    _base = ms;
    elapsed.value = ms;
  }

  void _persist() {
    final s = state.session;
    if (s == null || s.isWon) return;
    _saver.schedule(s.withElapsed(_elapsedNow));
  }

  // ---------------------------------------------------------------------------
  // Cycle de vie des parties.

  /// Vrai si lancer une nouvelle partie abandonnerait une partie commencée.
  bool get wouldAbandon {
    final s = state.session;
    return s != null && s.started && !s.isWon;
  }

  void newGame(GameMode mode, {int? seed, String? challengeId}) {
    _abandonIfStarted();
    _startSession(
      GameSession.start(
        mode,
        seed ?? SeededRandom.randomSeed(),
        challengeId: challengeId,
      ),
    );
  }

  void startChallenge(DailyChallenge c) =>
      newGame(c.mode, seed: c.seed, challengeId: c.id);

  /// Même donne depuis le début (la tentative en cours compte comme défaite
  /// si elle était commencée).
  void restart() {
    final s = state.session;
    if (s == null) return;
    _abandonIfStarted();
    _startSession(s.restart());
  }

  /// Rejoue la donne de la partie qui vient d'être gagnée.
  void replayLast() {
    final report = state.report;
    if (report == null) return;
    _startSession(
      GameSession.start(
        report.result.mode,
        report.result.seed,
        challengeId: report.result.challengeId,
      ),
    );
  }

  /// Abandon explicite : défaite si la partie était commencée.
  void abandon() {
    _abandonIfStarted();
    _autoToken++;
    _resetClock(0);
    unawaited(_saver.cancelThen(_repo.clear));
    state = GameViewState(dealSerial: state.dealSerial);
  }

  void _abandonIfStarted() {
    final s = state.session;
    if (s == null || !s.started || s.isWon) return;
    final result = GameCompletion.resultOf(
      s.withElapsed(_elapsedNow),
      ref.read(profileProvider),
      won: false,
      now: DateTime.now(),
    );
    ref.read(profileProvider.notifier).recordGame(result);
  }

  void _startSession(GameSession session) {
    _autoToken++;
    _resetClock(session.elapsedMs);
    state = GameViewState(session: session, dealSerial: state.dealSerial + 1);
    _saver.schedule(session);
    _updateClock();
  }

  void dismissReport() => state = state.copyWith(clearReport: true);

  void setPaused(bool paused) {
    if (state.session == null) return;
    state = state.copyWith(paused: paused);
    _updateClock();
  }

  // ---------------------------------------------------------------------------
  // Coups.

  /// Tente un coup du joueur ; renvoie faux s'il est refusé.
  bool play(
    Move move, {
    Set<int> rejectCards = const {},
    bool assisted = false,
  }) {
    final s = state.session;
    if (s == null || state.paused || state.autoPlaying) return false;
    final next = assisted ? s.playAssisted(move) : s.play(move);
    if (next == null) {
      reject(rejectCards);
      return false;
    }
    _emitFor(s, move);
    if (assisted) _autoToken++;
    state = state.copyWith(session: next, clearHint: true);
    _updateClock();
    _persist();
    if (assisted) {
      // Une pression joue exactement un coup, même si l'automatisme des
      // fondations est activé. Le coût est déjà présent en cas de victoire.
      if (next.isWon) _finishWin();
    } else {
      _afterMove();
    }
    return true;
  }

  void reject(Set<int> cards) {
    state = state.copyWith(
      invalidCards: cards,
      invalidSerial: state.invalidSerial + 1,
    );
    _fx.emit(FeedbackEvent.invalid);
  }

  void _emitFor(GameSession before, Move move) {
    if (move is TransferMove && move.to.kind == PileKind.foundation) {
      _fx.emit(FeedbackEvent.foundation);
    } else if (move is DrawMove || move is RecycleMove) {
      _fx.emit(FeedbackEvent.flip);
    } else {
      _fx.emit(FeedbackEvent.move);
    }
  }

  void _afterMove() {
    final s = state.session!;
    if (s.isWon) {
      _finishWin();
      return;
    }
    if (ref.read(settingsProvider).autoMove) unawaited(_runSafeAutoMoves());
  }

  Duration get _autoDelay {
    final look = ref.read(lookProvider);
    final base = look.scaled(look.motion.move);
    return Duration(milliseconds: 60 + base.inMilliseconds ~/ 2);
  }

  Future<void> _runSafeAutoMoves() async {
    final token = ++_autoToken;
    while (true) {
      await Future<void>.delayed(_autoDelay);
      if (token != _autoToken) return;
      final s = state.session;
      if (s == null || s.isWon || state.paused) return;
      final move = s.rules.nextSafeAutoMove(s.state);
      if (move == null) return;
      final next = s.playAuto(move);
      if (next == null) return;
      _fx.emit(FeedbackEvent.foundation);
      state = state.copyWith(session: next, clearHint: true);
      _persist();
      if (next.isWon) {
        _finishWin();
        return;
      }
    }
  }

  /// Termine automatiquement une partie déjà gagnée d'avance.
  Future<void> autoComplete() async {
    if (!state.canAutoComplete) return;
    final token = ++_autoToken;
    state = state.copyWith(autoPlaying: true, clearHint: true);
    while (true) {
      final s = state.session;
      if (s == null || token != _autoToken) break;
      final move = s.rules.nextAutoCompleteMove(s.state);
      if (move == null) break;
      final next = s.turns.isEmpty ? s.play(move) : s.playAuto(move);
      if (next == null) break;
      _fx.emit(FeedbackEvent.foundation);
      state = state.copyWith(session: next);
      if (next.isWon) {
        state = state.copyWith(autoPlaying: false);
        _finishWin();
        return;
      }
      await Future<void>.delayed(
        Duration(milliseconds: 40 + _autoDelay.inMilliseconds ~/ 3),
      );
    }
    state = state.copyWith(autoPlaying: false);
    _persist();
  }

  void undo() {
    final s = state.session;
    if (s == null || state.paused || state.autoPlaying) return;
    final prev = s.undo();
    if (prev == null) return;
    _autoToken++;
    _fx.emit(FeedbackEvent.move);
    state = state.copyWith(session: prev, clearHint: true);
    _persist();
  }

  MoveAdvice? _advice(GameSession session) =>
      MoveAdvisor.best(session.rules, session.state, history: session.history);

  /// Explique le meilleur coup estimé sans le jouer.
  void hint() {
    final s = state.session;
    if (s == null || state.paused || state.autoPlaying || s.isWon) return;
    final advice = _advice(s);
    if (advice == null) {
      clearHint();
      _messages.add(
        'Aucun mouvement utile. Essaie Annuler ou une nouvelle partie.',
      );
      return;
    }
    final move = advice.move;
    // Laisse le temps de lire l'indice avant tout nouveau déplacement.
    _autoToken++;
    final Set<int> cards;
    PileRef? target;
    switch (move) {
      case TransferMove(:final from, :final to, :final count):
        final pile = s.state.pile(from);
        cards = {for (final c in pile.takeTop(count)) c.id};
        target = to;
      case DrawMove():
        final top = s.state.stock.top;
        cards = top == null ? const {} : {top.id};
        target = null;
      case RecycleMove():
        cards = const {};
        target = PileRef.stock;
    }
    state = state.copyWith(
      session: s.withHintUsed(),
      hint: HintInfo(
        cardIds: cards,
        target: target,
        serial: ++_hintSerial,
        advice: advice,
      ),
    );
    _persist();
  }

  /// Même suggestion que l'indice, jouée sans message ni surbrillance.
  void playBestMove() {
    final s = state.session;
    if (s == null || state.paused || state.autoPlaying || s.isWon) return;
    final advice = _advice(s);
    clearHint();
    if (advice == null) return;
    play(advice.move, assisted: true);
  }

  void clearHint() {
    if (state.hint != null) state = state.copyWith(clearHint: true);
  }

  /// Toucher (simple ou double) sur la carte [index] de [pile].
  void tap(PileRef pile, int? index, {required bool doubleTap}) {
    final s = state.session;
    if (s == null || state.paused || state.autoPlaying || s.isWon) return;
    final gs = s.state;
    if (pile.kind == PileKind.stock) {
      if (gs.stock.isNotEmpty) {
        if (!play(const DrawMove()) && s.mode.family == GameFamily.spider) {
          _messages.add('Remplis les colonnes vides avant de distribuer.');
        }
      } else if (s.rules.isLegal(gs, const RecycleMove())) {
        play(const RecycleMove());
      }
      return;
    }
    if (index == null) return;
    final p = gs.pile(pile);
    final count = p.length - index;
    final settings = ref.read(settingsProvider);
    if (!doubleTap && !settings.tapToMove) return;
    final ids = {for (final c in p.takeTop(count)) c.id};
    final move = s.rules.bestMoveFor(
      gs,
      pile,
      count,
      foundationOnly: doubleTap && !settings.tapToMove,
    );
    if (move == null) {
      reject(ids);
      return;
    }
    play(move, rejectCards: ids);
  }

  /// Dépôt d'un glisser-déposer. Renvoie vrai si le coup est joué.
  bool drop(PileRef from, int count, PileRef? to) {
    final s = state.session;
    if (s == null) return false;
    final ids = {for (final c in s.state.pile(from).takeTop(count)) c.id};
    if (to == null || to == from) return false;
    final move = TransferMove(from: from, to: to, count: count);
    if (!s.rules.isLegal(s.state, move)) {
      reject(ids);
      return false;
    }
    return play(move, rejectCards: ids);
  }

  // ---------------------------------------------------------------------------
  // Fin de partie.

  void _finishWin() {
    final s = state.session!;
    final ms = _elapsedNow;
    _resetClock(ms);
    _autoToken++;
    unawaited(_saver.cancelThen(_repo.clear));
    final result = GameCompletion.resultOf(
      s.withElapsed(ms),
      ref.read(profileProvider),
      won: true,
      now: DateTime.now(),
    );
    final report = ref.read(profileProvider.notifier).recordGame(result);
    _fx.emit(FeedbackEvent.win);
    state = state.copyWith(
      session: s.withElapsed(ms),
      report: report,
      clearHint: true,
      autoPlaying: false,
    );
  }

  /// Score affiché en direct (points de jeu moins pénalités).
  int get liveScore {
    final s = state.session;
    if (s == null) return 0;
    return ScoreCalculator.live(
      gamePoints: s.state.points,
      hints: s.hintsUsed,
      assistedMoves: s.assistedMovesUsed,
      undos: s.undoCount,
    );
  }
}
