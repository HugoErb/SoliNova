import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/rules/rules_registry.dart';
import 'package:solinova/engine/solver/solution_codec.dart';
import 'package:solinova/engine/solver/solver.dart';
import 'package:solinova/engine/solver/winnable_deals.dart';

import 'test_helpers.dart';

Map<int, String> solutionsOf(GameMode mode) => {
  for (final line in File('assets/deals/${mode.name}.txt').readAsLinesSync())
    if (line.contains(' '))
      int.parse(line.substring(0, line.indexOf(' '))): line.substring(
        line.indexOf(' ') + 1,
      ),
};

void main() {
  for (final mode in GameMode.values) {
    test('${mode.fullName} : chaque donne du pool a une solution gagnante', () {
      final rules = RulesRegistry.of(mode);
      final seeds = WinnableDeals.seedsOf(mode);
      final solutions = solutionsOf(mode);
      expect(seeds, isNotEmpty);
      expect(seeds.toSet(), solutions.keys.toSet());
      // Rejoue un échantillon réparti sur tout le pool.
      for (var i = 0; i < seeds.length; i += seeds.length ~/ 12 + 1) {
        var state = rules.deal(seeds[i]);
        for (final move in SolutionCodec.decode(solutions[seeds[i]]!)) {
          expect(rules.isLegal(state, move), isTrue, reason: '${seeds[i]}');
          state = rules.apply(state, move);
        }
        expect(rules.isWon(state), isTrue, reason: '${seeds[i]}');
      }
    });
  }

  test('le codec relit exactement les coups encodés', () {
    const moves = <Move>[
      DrawMove(),
      RecycleMove(),
      TransferMove(from: PileRef.waste, to: PileRef.tableau(6)),
      TransferMove(from: PileRef.tableau(9), to: PileRef.tableau(0), count: 13),
      TransferMove(from: PileRef.freeCell(3), to: PileRef.foundation(7)),
    ];
    expect(SolutionCodec.decode(SolutionCodec.encode(moves)), moves);
  });

  test('défis quotidiens et nouvelles parties tirent des donnes du pool', () {
    for (final mode in GameMode.values) {
      final seeds = WinnableDeals.seedsOf(mode).toSet();
      expect(seeds, contains(WinnableDeals.randomSeed(mode)));
      expect(seeds, contains(WinnableDeals.seedFor(mode, 0xDEADBEEF)));
    }
  });

  test('trouve une suite gagnante en cours de partie', () {
    final rules = RulesRegistry.of(GameMode.freecell);
    final seed = WinnableDeals.seedsOf(GameMode.freecell).first;
    var state = rules.deal(seed);
    final line = SolutionCodec.decode(solutionsOf(GameMode.freecell)[seed]!);
    for (final move in line.take(line.length ~/ 2)) {
      state = rules.apply(state, move);
    }
    final result = Solver.solve(rules, state, maxNodes: 20000);
    expect(result.solved, isTrue);
    for (final move in result.moves!) {
      state = rules.apply(state, move);
    }
    expect(rules.isWon(state), isTrue);
  });

  test('reconnaît une position sans issue', () {
    // Aucun As en jeu : aucune carte ne peut rejoindre les fondations.
    final state = board(
      GameMode.klondike1,
      tableau: [
        [c(12, h, up: false), c(13, s)],
        [c(11, cl, up: false), c(13, d)],
      ],
      foundations: [[], [], [], []],
    );
    final result = Solver.solve(RulesRegistry.of(state.mode), state);
    expect(result.solved, isFalse);
    expect(result.exhausted, isTrue);
  });
}
