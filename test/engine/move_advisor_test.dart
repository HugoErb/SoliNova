import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/game_state.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/rules/move_advisor.dart';
import 'package:solinova/engine/rules/rules_registry.dart';

import 'test_helpers.dart';

void main() {
  for (final mode in GameMode.values) {
    test('${mode.fullName} : conseils valides sur des parties successives', () {
      final rules = RulesRegistry.of(mode);
      for (var seed = 1; seed <= 5; seed++) {
        var state = rules.deal(seed);
        final ids = state.allPiles
            .expand((p) => p.cards)
            .map((c) => c.id)
            .toSet();
        final history = <GameState>[];
        for (var turn = 0; turn < 150 && !rules.isWon(state); turn++) {
          final before = state.toJson();
          final advice = MoveAdvisor.best(rules, state, history: history);
          expect(
            state.toJson(),
            before,
            reason: 'le conseil ne joue pas le coup',
          );
          if (advice == null) break;
          expect(rules.isLegal(state, advice.move), isTrue);
          expect(advice.instruction, isNotEmpty);
          expect(advice.reason, isNotEmpty);
          final next = rules.apply(state, advice.move);
          expect(next.points - state.points, advice.points);
          final nextIds = next.allPiles
              .expand((p) => p.cards)
              .map((c) => c.id)
              .toList();
          expect(nextIds.length, ids.length);
          expect(nextIds.toSet(), ids);
          history.add(state);
          state = next;
        }
      }
    });
  }

  test('privilégie une carte cachée à un gain immédiat supérieur', () {
    final state = board(
      GameMode.klondike1,
      tableau: [
        [c(9, cl, up: false), c(7, h)],
        [c(8, s)],
        [c(13, d), c(1, s)],
      ],
    );
    final rules = RulesRegistry.of(state.mode);
    final advice = MoveAdvisor.best(rules, state)!;
    expect(
      advice.move,
      const TransferMove(from: PileRef.tableau(0), to: PileRef.tableau(1)),
    );
    expect(advice.points, 5);
    expect(advice.reason, contains('révèle une carte cachée'));
    expect(advice.instruction, contains('Sept de cœur'));
  });

  test('à progression égale, préfère le coup qui rapporte des points', () {
    final state = board(
      GameMode.klondike1,
      tableau: [
        [c(13, s), c(6, h)],
        [c(7, s)],
        [c(9, cl)],
      ],
      waste: [c(8, d)],
    );
    final advice = MoveAdvisor.best(RulesRegistry.of(state.mode), state)!;
    expect(
      advice.move,
      const TransferMove(from: PileRef.waste, to: PileRef.tableau(2)),
    );
    expect(advice.points, 5);
  });

  test('Spider : termine une suite avant un simple regroupement', () {
    final state = board(
      GameMode.spider2,
      tableauCount: 10,
      foundationCount: 8,
      tableau: [
        [c(9, h, up: false), c(5, s)],
        [c(6, s)],
        [for (var rank = 13; rank >= 2; rank--) c(rank, s)],
        [c(4, h), c(1, s)],
      ],
    );
    final advice = MoveAdvisor.best(RulesRegistry.of(state.mode), state)!;
    expect(
      advice.move,
      const TransferMove(from: PileRef.tableau(3), to: PileRef.tableau(2)),
    );
    expect(advice.points, 100);
    expect(advice.reason, contains('complète 1 suite'));
  });

  test('FreeCell : fondation sûre et libération de cellule', () {
    final state = board(
      GameMode.freecell,
      tableauCount: 8,
      cellCount: 4,
      tableau: [
        [c(13, h), c(5, s)],
      ],
      foundations: [run(s, 4)],
      cells: [
        [c(1, h)],
      ],
    );
    final advice = MoveAdvisor.best(RulesRegistry.of(state.mode), state)!;
    expect(
      advice.move,
      const TransferMove(from: PileRef.freeCell(0), to: PileRef.foundation(1)),
    );
    expect(advice.reason, contains('libère une cellule'));
    expect(advice.points, 10);
  });

  test('explique aussi la pioche et le coût réel du recyclage', () {
    final rules = RulesRegistry.of(GameMode.klondike1);
    final draw = MoveAdvisor.best(
      rules,
      board(GameMode.klondike1, stock: [c(1, h, up: false)]),
    )!;
    expect(draw.move, const DrawMove());
    expect(draw.instruction, 'Pioche une carte.');
    final recycle = MoveAdvisor.best(
      rules,
      board(GameMode.klondike1, waste: [c(1, h), c(8, s)]),
    )!;
    expect(recycle.move, const RecycleMove());
    expect(recycle.points, -20);
  });

  test('évite de revenir à un plateau déjà parcouru', () {
    final rules = RulesRegistry.of(GameMode.klondike1);
    final state = board(
      GameMode.klondike1,
      tableau: [
        [c(3, s)],
      ],
      foundations: [run(s, 2)],
    );
    final advice = MoveAdvisor.best(rules, state)!;
    final previous = rules.apply(state, advice.move);
    expect(MoveAdvisor.best(rules, state, history: [previous]), isNull);
  });
}
