import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solinova/app/app.dart';
import 'package:solinova/app/game_controller.dart';
import 'package:solinova/app/providers.dart';
import 'package:solinova/data/storage.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/ui/game/game_screen.dart';

/// Mesure des temps d'image pendant une partie Spider 4 couleurs (le
/// plateau le plus chargé) : distribution, glisser-déposer, annulations.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluidité du plateau', (tester) async {
    final container = ProviderContainer(
      overrides: [storeProvider.overrideWithValue(MemoryStore())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SoliNovaApp()),
    );
    await tester.pumpAndSettle();
    final controller = container.read(gameProvider.notifier);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    await binding.traceAction(() async {
      controller.newGame(GameMode.spider4, seed: 12);
      nav.push(GameScreen.route());
      await tester.pumpAndSettle();
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (var i = 0; i < 8; i++) {
        // Glisser lent d'une carte à travers le plateau puis relâcher.
        final col = i % 10;
        final x = size.width * (col + 0.5) / 10;
        final gesture = await tester.startGesture(Offset(x, size.height * 0.32));
        for (var s = 0; s < 30; s++) {
          await gesture.moveBy(const Offset(4, 6));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        // Coup valide via le moteur (animation de déplacement), puis Annuler.
        final s = container.read(gameProvider).session!;
        final moves = s.rules.legalMoves(s.state);
        if (moves.isNotEmpty) controller.play(moves.first);
        await tester.pumpAndSettle();
        controller.undo();
        await tester.pumpAndSettle();
      }
      controller.setPaused(true);
      await tester.pumpAndSettle();
    }, reportKey: 'drag_perf');
  });
}
