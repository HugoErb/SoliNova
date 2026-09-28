import '../model/game_mode.dart';
import '../model/game_state.dart';
import '../model/move.dart';
import '../rules/game_rules.dart';
import '../rules/rules_registry.dart';

/// Un tour = le coup du joueur suivi des coups automatiques qu'il a
/// déclenchés. « Annuler » revient toujours au début d'un tour complet.
final class Turn {
  const Turn(this.moves);

  final List<Move> moves;

  Turn append(Move move) => Turn([...moves, move]);

  List<Object> toJson() => [for (final m in moves) m.toJson()];

  static Turn fromJson(List<Object?> json) => Turn([
    for (final m in json) Move.fromJson((m! as Map).cast<String, Object?>()),
  ]);
}

/// Session de jeu immuable : état courant, historique et compteurs.
///
/// Une partie est considérée comme **commencée** dès le premier coup valide
/// du joueur ([moveCount] > 0). Une partie jamais commencée n'est jamais
/// comptée dans les statistiques.
final class GameSession {
  GameSession._({
    required this.mode,
    required this.seed,
    required this.state,
    required List<GameState> history,
    required List<Turn> turns,
    required this.moveCount,
    required this.hintsUsed,
    required this.assistedMovesUsed,
    required this.undoCount,
    required this.elapsedMs,
    required this.challengeId,
  }) : history = List.unmodifiable(history),
       turns = List.unmodifiable(turns);

  /// Nouvelle partie distribuée à partir de [seed].
  factory GameSession.start(GameMode mode, int seed, {String? challengeId}) {
    final rules = RulesRegistry.of(mode);
    return GameSession._(
      mode: mode,
      seed: seed,
      state: rules.deal(seed),
      history: const [],
      turns: const [],
      moveCount: 0,
      hintsUsed: 0,
      assistedMovesUsed: 0,
      undoCount: 0,
      elapsedMs: 0,
      challengeId: challengeId,
    );
  }

  final GameMode mode;
  final int seed;
  final GameState state;

  /// États avant chaque tour, pour Annuler.
  final List<GameState> history;
  final List<Turn> turns;

  /// Coups joués par le joueur (les coups automatiques ne comptent pas,
  /// Annuler ne décrémente pas ce compteur).
  final int moveCount;
  final int hintsUsed;
  final int assistedMovesUsed;
  final int undoCount;
  final int elapsedMs;

  /// Identifiant du défi quotidien joué, ou null pour une partie normale.
  final String? challengeId;

  GameRules get rules => RulesRegistry.of(mode);

  bool get started => moveCount > 0;
  bool get isWon => rules.isWon(state);
  bool get canUndo => history.isNotEmpty && !isWon;

  GameSession _copy({
    GameState? state,
    List<GameState>? history,
    List<Turn>? turns,
    int? moveCount,
    int? hintsUsed,
    int? assistedMovesUsed,
    int? undoCount,
    int? elapsedMs,
  }) => GameSession._(
    mode: mode,
    seed: seed,
    state: state ?? this.state,
    history: history ?? this.history,
    turns: turns ?? this.turns,
    moveCount: moveCount ?? this.moveCount,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    assistedMovesUsed: assistedMovesUsed ?? this.assistedMovesUsed,
    undoCount: undoCount ?? this.undoCount,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    challengeId: challengeId,
  );

  /// Joue un coup du joueur. Renvoie null si le coup est illégal.
  GameSession? play(Move move) {
    if (isWon || !rules.isLegal(state, move)) return null;
    return _copy(
      state: rules.apply(state, move),
      history: [...history, state],
      turns: [
        ...turns,
        Turn([move]),
      ],
      moveCount: moveCount + 1,
    );
  }

  /// Joue un coup automatique rattaché au dernier tour (non compté).
  GameSession? playAuto(Move move) {
    if (isWon || turns.isEmpty || !rules.isLegal(state, move)) return null;
    return _copy(
      state: rules.apply(state, move),
      turns: [...turns.sublist(0, turns.length - 1), turns.last.append(move)],
    );
  }

  /// Revient au début du dernier tour.
  GameSession? undo() {
    if (!canUndo) return null;
    return _copy(
      state: history.last,
      history: history.sublist(0, history.length - 1),
      turns: turns.sublist(0, turns.length - 1),
      undoCount: undoCount + 1,
    );
  }

  GameSession withHintUsed() => _copy(hintsUsed: hintsUsed + 1);

  /// Le coût reste comptabilisé après Annuler, comme celui d'un indice.
  GameSession? playAssisted(Move move) =>
      play(move)?._copy(assistedMovesUsed: assistedMovesUsed + 1);

  GameSession withElapsed(int ms) => _copy(elapsedMs: ms);

  /// Même donne, remise à zéro (« Recommencer »).
  GameSession restart() =>
      GameSession.start(mode, seed, challengeId: challengeId);

  // ---------------------------------------------------------------------------
  // Persistance : on sauvegarde la graine et les tours, puis on rejoue.
  // L'état courant est aussi sauvegardé en secours si le rejeu échoue.

  static const schemaVersion = 1;

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'mode': mode.name,
    'seed': seed,
    'turns': [for (final t in turns) t.toJson()],
    'moves': moveCount,
    'hints': hintsUsed,
    'assistedMoves': assistedMovesUsed,
    'undos': undoCount,
    'elapsed': elapsedMs,
    'challenge': challengeId,
    'state': state.toJson(),
  };

  static GameSession fromJson(Map<String, Object?> json) {
    final mode = GameMode.values.byName(json['mode']! as String);
    final seed = json['seed']! as int;
    final rules = RulesRegistry.of(mode);
    final turns = [
      for (final t in (json['turns']! as List))
        Turn.fromJson((t! as List).cast<Object?>()),
    ];
    final saved = GameState.fromJson(
      (json['state']! as Map).cast<String, Object?>(),
    );

    var state = rules.deal(seed);
    final history = <GameState>[];
    var replayOk = true;
    for (final turn in turns) {
      history.add(state);
      for (final move in turn.moves) {
        if (!rules.isLegal(state, move)) {
          replayOk = false;
          break;
        }
        state = rules.apply(state, move);
      }
      if (!replayOk) break;
    }
    if (replayOk && _sameLayout(state, saved)) {
      state = saved;
    } else {
      // Rejeu impossible : on garde l'état sauvegardé, sans historique.
      state = saved;
      history.clear();
      turns.clear();
    }
    return GameSession._(
      mode: mode,
      seed: seed,
      state: state,
      history: history,
      turns: turns,
      moveCount: json['moves']! as int,
      hintsUsed: json['hints']! as int,
      assistedMovesUsed: json['assistedMoves'] as int? ?? 0,
      undoCount: json['undos']! as int,
      elapsedMs: json['elapsed']! as int,
      challengeId: json['challenge'] as String?,
    );
  }

  static bool _sameLayout(GameState a, GameState b) {
    final pa = a.allPiles.toList();
    final pb = b.allPiles.toList();
    if (pa.length != pb.length) return false;
    for (var i = 0; i < pa.length; i++) {
      final ca = pa[i].cards;
      final cb = pb[i].cards;
      if (ca.length != cb.length) return false;
      for (var j = 0; j < ca.length; j++) {
        if (ca[j] != cb[j]) return false;
      }
    }
    return a.points == b.points;
  }
}
