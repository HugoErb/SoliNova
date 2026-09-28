import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/app/game_controller.dart';
import 'package:solinova/app/providers.dart';
import 'package:solinova/app/solution_book.dart';
import 'package:solinova/data/repositories.dart';
import 'package:solinova/data/storage.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/game_state.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/session/game_session.dart';
import 'package:solinova/engine/solver/winnable_deals.dart';
import 'package:solinova/meta/economy/wallet.dart';
import 'package:solinova/meta/profile/profile.dart';

import '../engine/test_helpers.dart';

ProviderContainer containerFor(GameState state) {
  final session = GameSession.fromJson({
    ...GameSession.start(state.mode, 1).toJson(),
    'state': state.toJson(),
  });
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(MemoryStore()),
      initialProfileProvider.overrideWithValue(
        const Profile(wallet: Wallet(balance: 123)),
      ),
      initialSessionProvider.overrideWithValue(session),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in GameMode.values) {
    test(
      '${mode.fullName} : ne jouer que des coups assistés gagne la partie',
      () async {
        final container = ProviderContainer(
          overrides: [
            storeProvider.overrideWithValue(MemoryStore()),
            solutionBookProvider.overrideWithValue(
              SolutionBook(load: (key) async => File(key).readAsStringSync()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(gameProvider.notifier);
        controller.newGame(mode);
        final seed = container.read(gameProvider).session!.seed;
        expect(WinnableDeals.seedsOf(mode), contains(seed));
        await Future<void>.delayed(Duration.zero);
        final messages = <String>[];
        final subscription = controller.messages.listen(messages.add);
        addTearDown(subscription.cancel);
        for (
          var i = 0;
          i < 2000 && container.read(gameProvider).report == null;
          i++
        ) {
          final before = container.read(gameProvider).session!.moveCount;
          controller.playBestMove();
          expect(
            container.read(gameProvider).session!.moveCount,
            before + 1,
            reason: 'coup assisté immédiat sur le chemin gagnant',
          );
        }
        expect(container.read(gameProvider).report?.result.won, isTrue);
        expect(messages, isEmpty);
        await container.read(profileProvider.notifier).flush();
        await controller.setForeground(false);
      },
    );
  }

  test('après un écart, le solveur retrouve une suite gagnante', () async {
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(MemoryStore())],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameProvider.notifier);
    // Donne répertoriée mais sans solution chargée : tout vient du solveur.
    controller.newGame(
      GameMode.freecell,
      seed: WinnableDeals.seedsOf(GameMode.freecell)[3],
    );
    final session = container.read(gameProvider).session!;
    final rules = session.rules;
    controller.play(rules.legalMoves(session.state).last);
    controller.hint();
    // Recherche longue dans un isolat : on attend la réponse.
    for (var i = 0; i < 600 && container.read(gameProvider).hint == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(container.read(gameProvider).thinking, isNull);
    final hint = container.read(gameProvider).hint!;
    expect(hint.advice.winning, isTrue);
    controller.playBestMove();
    expect(
      container.read(gameProvider).session!.turns.last.moves.single,
      hint.advice.move,
    );
    await controller.setForeground(false);
  });

  testWidgets('un indice reste lisible pendant les automatismes de fondation', (
    tester,
  ) async {
    final container = containerFor(
      board(
        GameMode.klondike1,
        tableau: [
          [c(1, h)],
        ],
        stock: [c(2, h, up: false)],
      ),
    );
    final controller = container.read(gameProvider.notifier);
    controller.play(const DrawMove());
    controller.hint();
    final hint = container.read(gameProvider).hint!;
    final before = container.read(gameProvider).session!.state.toJson();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(gameProvider).hint, same(hint));
    expect(container.read(gameProvider).session!.state.toJson(), before);
    controller.playBestMove();
    await tester.pump(const Duration(seconds: 1));
    expect(
      container.read(gameProvider).session!.turns.last.moves.single,
      hint.advice.move,
    );
    expect(container.read(gameProvider).session!.assistedMovesUsed, 1);
    expect(container.read(gameProvider).hint, isNull);
  });

  test(
    'aides illimitées à zéro, même suggestion, coût conservé et sauvegardé',
    () async {
      final state = board(
        GameMode.klondike1,
        tableau: [
          [c(1, h)],
        ],
      );
      final container = containerFor(state);
      final controller = container.read(gameProvider.notifier);
      final messages = <String>[];
      final subscription = controller.messages.listen(messages.add);
      addTearDown(subscription.cancel);
      for (var i = 1; i <= 5; i++) {
        controller.hint();
        final hint = container.read(gameProvider).hint!;
        expect(
          container.read(gameProvider).session!.state.toJson(),
          state.toJson(),
        );
        expect(controller.liveScore, 0);
        controller.playBestMove();
        final played = container.read(gameProvider).session!;
        expect(played.turns.last.moves.single, hint.advice.move);
        expect(played.hintsUsed, i);
        expect(played.assistedMovesUsed, i);
        expect(container.read(gameProvider).hint, isNull);
        controller.undo();
        expect(
          container.read(gameProvider).session!.state.toJson(),
          state.toJson(),
        );
      }
      await controller.setForeground(false);
      final saved = await GameRepository(container.read(storeProvider))
          .loadOrNull();
      expect(saved!.assistedMovesUsed, 5);
      expect(saved.hintsUsed, 5);
      expect(container.read(profileProvider).wallet.balance, 123);
      expect(messages, isEmpty);
    },
  );

  test('aucun coup disponible : aucun coût ni bandeau automatique', () async {
    final container = containerFor(board(GameMode.klondike1));
    final controller = container.read(gameProvider.notifier);
    final messages = <String>[];
    final subscription = controller.messages.listen(messages.add);
    addTearDown(subscription.cancel);
    controller.playBestMove();
    await Future<void>.delayed(Duration.zero);
    expect(messages, isEmpty);
    expect(container.read(gameProvider).session!.assistedMovesUsed, 0);
    controller.hint();
    expect(container.read(gameProvider).session!.hintsUsed, 0);
    expect(container.read(gameProvider).hint, isNull);
  });

  test('le coup gagnant inclut la pénalité dans le bilan', () async {
    final container = containerFor(
      board(
        GameMode.klondike1,
        tableau: [
          [c(13, h)],
        ],
        foundations: [run(s, 13), run(h, 12), run(d, 13), run(cl, 13)],
      ),
    );
    final controller = container.read(gameProvider.notifier);
    controller.playBestMove();
    final report = container.read(gameProvider).report!;
    expect(report.result.won, isTrue);
    expect(report.result.assistedMoves, 1);
    expect(report.result.score.assistedMovePenalty, 40);
    expect(report.result.hints, 0);
    expect(report.unlocked.map((a) => a.id), isNot(contains('no_hint')));
    await container.read(profileProvider.notifier).flush();
  });

  test('pause : aucune aide facturée ni coup joué', () async {
    final container = containerFor(board(GameMode.klondike1, stock: [c(1, h)]));
    final controller = container.read(gameProvider.notifier);
    controller.setPaused(true);
    controller.hint();
    controller.playBestMove();
    final session = container.read(gameProvider).session!;
    expect(session.moveCount, 0);
    expect(session.hintsUsed, 0);
    expect(session.assistedMovesUsed, 0);
    expect(session.rules.isLegal(session.state, const DrawMove()), isTrue);
    await controller.setForeground(false);
  });
}
