import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/rng/seeded_random.dart';
import 'package:solinova/engine/rules/rules_registry.dart';
import 'package:solinova/engine/scoring/score_calculator.dart';
import 'package:solinova/engine/session/game_session.dart';

void main() {
  group('GameSession', () {
    test('une partie ne commence qu\'au premier coup valide', () {
      final s = GameSession.start(GameMode.klondike1, 1);
      expect(s.started, isFalse);
      final played = s.play(const DrawMove())!;
      expect(played.started, isTrue);
      expect(played.moveCount, 1);
    });

    test('coup illégal refusé sans modifier la session', () {
      final s = GameSession.start(GameMode.klondike1, 1);
      expect(s.play(const RecycleMove()), isNull);
    });

    test('annuler revient à l\'état précédent, y compris les points', () {
      var s = GameSession.start(GameMode.klondike1, 8);
      final before = s.state.toJson();
      s = s.play(const DrawMove())!;
      s = s.undo()!;
      expect(s.state.toJson(), before);
      expect(s.undoCount, 1);
      expect(s.moveCount, 1, reason: 'Annuler ne décrémente pas les coups');
      expect(s.undo(), isNull);
    });

    test('les coups automatiques sont annulés avec le coup du joueur', () {
      var s = GameSession.start(GameMode.klondike1, 8);
      final before = s.state.toJson();
      s = s.play(const DrawMove())!;
      s = s.playAuto(const DrawMove())!;
      expect(s.moveCount, 1);
      expect(s.turns.single.moves.length, 2);
      s = s.undo()!;
      expect(s.state.toJson(), before);
    });

    test('sauvegarde et restauration exactes, historique compris', () {
      for (final mode in GameMode.values) {
        var s = GameSession.start(mode, 777);
        final rules = RulesRegistry.of(mode);
        final rng = SeededRandom(3);
        for (var i = 0; i < 40; i++) {
          final moves = rules.legalMoves(s.state);
          if (moves.isEmpty) break;
          s = s.play(moves[rng.nextInt(moves.length)])!;
        }
        s = s.withHintUsed().withElapsed(65432);
        final restored = GameSession.fromJson(s.toJson());
        expect(restored.state.toJson(), s.state.toJson());
        expect(restored.history.length, s.history.length);
        expect(restored.moveCount, s.moveCount);
        expect(restored.hintsUsed, 1);
        expect(restored.elapsedMs, 65432);
        if (s.canUndo) {
          expect(restored.undo()!.state.toJson(), s.undo()!.state.toJson());
        }
      }
    });

    test('recommencer redonne exactement la même distribution', () {
      var s = GameSession.start(GameMode.spider2, 55);
      final initial = s.state.toJson();
      s = s.play(RulesRegistry.of(GameMode.spider2).legalMoves(s.state).first)!;
      expect(s.restart().state.toJson(), initial);
    });
  });

  group('Parties aléatoires : invariants du moteur', () {
    for (final mode in GameMode.values) {
      test('${mode.fullName} : aucune carte perdue ni dupliquée', () {
        final rules = RulesRegistry.of(mode);
        for (var seed = 1; seed <= 30; seed++) {
          var state = rules.deal(seed);
          final rng = SeededRandom(seed * 31);
          for (var step = 0; step < 300; step++) {
            final moves = rules.legalMoves(state);
            if (moves.isEmpty) break;
            final move = moves[rng.nextInt(moves.length)];
            state = rules.apply(state, move);
            final ids = state.allPiles.expand((p) => p.cards).map((c) => c.id);
            expect(ids.length, rules.cardCount);
            expect(ids.toSet().length, rules.cardCount);
            // Les cartes du tableau hors piles cachées restent cohérentes.
            for (final col in state.tableau) {
              if (col.isNotEmpty && mode.family != GameFamily.freecell) {
                expect(col.top!.faceUp, isTrue);
              }
            }
            for (final hint in rules.hintMoves(state)) {
              expect(rules.isLegal(state, hint), isTrue);
            }
          }
        }
      });
    }
  });

  group('ScoreCalculator', () {
    test('exemple Klondike tirage 1 documenté', () {
      final score = ScoreCalculator.compute(
        mode: GameMode.klondike1,
        won: true,
        gamePoints: 700,
        elapsedMs: 180000,
        moves: 110,
        hints: 1,
        undos: 2,
        previousStreak: 2,
      );
      expect(score.victoryBonus, 500);
      expect(score.difficultyBonus, 0);
      expect(score.speedBonus, 240); // (300 - 180) x 2
      expect(score.movesBonus, 100); // (130 - 110) x 5
      expect(score.streakBonus, 100); // 2 x 50
      expect(score.hintPenalty, 25);
      expect(score.undoPenalty, 10);
      expect(score.total, 700 + 500 + 240 + 100 + 100 - 25 - 10);
    });

    test('bonus plafonnés et jamais négatifs', () {
      final fast = ScoreCalculator.compute(
        mode: GameMode.klondike1,
        won: true,
        gamePoints: 0,
        elapsedMs: 0,
        moves: 1,
        hints: 0,
        undos: 0,
        previousStreak: 50,
      );
      expect(fast.speedBonus, ScoreCalculator.speedMax);
      expect(fast.movesBonus, ScoreCalculator.movesMax);
      expect(fast.streakBonus, ScoreCalculator.streakMax);

      final slow = ScoreCalculator.compute(
        mode: GameMode.klondike1,
        won: true,
        gamePoints: 0,
        elapsedMs: 99999000,
        moves: 9999,
        hints: 100,
        undos: 100,
        previousStreak: 0,
      );
      expect(slow.speedBonus, 0);
      expect(slow.movesBonus, 0);
      expect(slow.total, 0);
    });

    test('défaite : aucun bonus', () {
      final lost = ScoreCalculator.compute(
        mode: GameMode.spider4,
        won: false,
        gamePoints: 300,
        elapsedMs: 1000,
        moves: 10,
        hints: 0,
        undos: 0,
        previousStreak: 5,
      );
      expect(lost.total, 300);
    });

    test('Spider 4 couleurs rapporte plus que 1 couleur à performance égale', () {
      ScoreBreakdown s(GameMode m) => ScoreCalculator.compute(
        mode: m,
        won: true,
        gamePoints: 900,
        elapsedMs: 600000,
        moves: 200,
        hints: 0,
        undos: 0,
        previousStreak: 0,
      );
      expect(s(GameMode.spider4).total, greaterThan(s(GameMode.spider1).total));
    });
  });
}
