import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/app/app.dart';
import 'package:solinova/app/game_controller.dart';
import 'package:solinova/app/providers.dart';
import 'package:solinova/app/solution_book.dart';
import 'package:solinova/data/storage.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/card.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/model/rank.dart';
import 'package:solinova/engine/model/suit.dart';
import 'package:solinova/engine/rules/rules_registry.dart';
import 'package:solinova/engine/session/game_session.dart';
import 'package:solinova/engine/solver/winnable_deals.dart';
import 'package:solinova/meta/economy/wallet.dart';
import 'package:solinova/meta/profile/profile.dart';
import 'package:solinova/ui/game/game_screen.dart';
import 'package:solinova/ui/screens/progress_screen.dart';
import 'package:solinova/ui/screens/rules_screen.dart';
import 'package:solinova/ui/screens/scoring_screen.dart';
import 'package:solinova/ui/screens/settings_screen.dart';
import 'package:solinova/ui/screens/shop_screen.dart';

/// Tailles d'écran de téléphones en portrait (dp).
const phones = <String, Size>{
  '320x568': Size(320, 568),
  '360x640': Size(360, 640),
  '393x851': Size(393, 851),
  '412x915': Size(412, 915),
};

Future<ProviderContainer> pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(MemoryStore()),
      initialProfileProvider.overrideWithValue(
        const Profile(wallet: Wallet(balance: 5000)),
      ),
      // Lecture synchrone : les solutions sont prêtes dès la distribution.
      solutionBookProvider.overrideWithValue(
        SolutionBook(load: (key) async => File(key).readAsStringSync()),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SoliNovaApp()),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return container;
}

/// Aucun défilement horizontal nulle part.
void expectNoHorizontalScroll(WidgetTester tester) {
  final horizontal = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );
  expect(horizontal, findsNothing, reason: 'défilement horizontal interdit');
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Manrope-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(loadFonts);

  for (final entry in phones.entries) {
    group(entry.key, () {
      testWidgets('accueil et onglets sans débordement', (tester) async {
        await pumpApp(tester, entry.value);
        expect(find.text('SoliNova'), findsWidgets);
        expectNoHorizontalScroll(tester);
        for (final tab in ['Défis', 'Progrès', 'Boutique', 'Plus', 'Jouer']) {
          await tester.tap(find.text(tab).last);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: tab);
          expectNoHorizontalScroll(tester);
        }
      });

      testWidgets('pages secondaires sans débordement', (tester) async {
        await pumpApp(tester, entry.value);
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        final routes = <Route<void> Function()>[
          StatisticsScreen.route,
          () => RulesScreen.route(GameMode.spider4),
          ScoringScreen.route,
          SettingsScreen.route,
          () => ShopScreen.route(themesOnly: true),
        ];
        for (final r in routes) {
          unawaited(nav.push(r()));
          await settle(tester);
          expect(tester.takeException(), isNull);
          expectNoHorizontalScroll(tester);
          nav.pop();
          await settle(tester);
        }
      });

      for (final mode in GameMode.values) {
        testWidgets('partie ${mode.fullName}', (tester) async {
          final container = await pumpApp(tester, entry.value);
          container
              .read(gameProvider.notifier)
              .newGame(mode, seed: WinnableDeals.seedsOf(mode).first);
          final nav = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          unawaited(nav.push(GameScreen.route()));
          await settle(tester);
          expect(tester.takeException(), isNull);
          expectNoHorizontalScroll(tester);
          expect(find.byTooltip('Annuler'), findsOneWidget);
          expect(find.byTooltip('Indice (20 points)'), findsOneWidget);
          expect(
            find.byTooltip('Jouer le meilleur coup (40 points)'),
            findsOneWidget,
          );
          expect(find.text('Annuler'), findsNothing);
          expect(find.text('Indice'), findsNothing);

          // Un coup puis Annuler, via l'interface.
          final controller = container.read(gameProvider.notifier);
          final session = container.read(gameProvider).session!;
          final move = session.rules.legalMoves(session.state).first;
          expect(controller.play(move), isTrue);
          await settle(tester);
          await tester.tap(find.byTooltip('Annuler'));
          await settle(tester);
          expect(container.read(gameProvider).session!.undoCount, 1);

          await tester.tap(find.byTooltip('Indice (20 points)'));
          await settle(tester);
          expect(tester.takeException(), isNull);
          final hint = container.read(gameProvider).hint!;
          expect(find.text(hint.advice.instruction), findsOneWidget);
          expect(find.text(hint.advice.reason), findsOneWidget);
          final beforeAssistance = container.read(gameProvider).session!;
          final expected = beforeAssistance.rules.apply(
            beforeAssistance.state,
            hint.advice.move,
          );
          await tester.tap(
            find.byTooltip('Jouer le meilleur coup (40 points)'),
          );
          await settle(tester);
          final assisted = container.read(gameProvider);
          expect(assisted.session!.state.toJson(), expected.toJson());
          expect(assisted.session!.assistedMovesUsed, 1);
          expect(assisted.session!.hintsUsed, beforeAssistance.hintsUsed);
          expect(assisted.hint, isNull);
          expect(find.text(hint.advice.instruction), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);

          // Menu de partie.
          await tester.tap(find.byTooltip('Menu'));
          await settle(tester);
          expect(find.text('Recommencer cette donne'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 10));
          await settle(tester);
          // Pause : le chronomètre s'arrête, la sauvegarde est écrite.
          controller.setPaused(true);
          await settle(tester);
          expect(find.text('Reprendre'), findsOneWidget);
        });
      }
    });
  }

  testWidgets('victoire : terminaison automatique et bilan', (tester) async {
    tester.view.physicalSize = const Size(393, 851) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Partie presque gagnée : il ne reste que le Roi de cœur.
    final rules = RulesRegistry.of(GameMode.klondike1);
    final deal = rules.deal(1);
    final all = deal.allPiles.expand((p) => p.cards).toList();
    List<Card> suit(Suit st) => [
      for (final r in Rank.values)
        if (!(st == Suit.hearts && r == Rank.king))
          all.firstWhere((c) => c.suit == st && c.rank == r).flipped(true),
    ];
    final king = all
        .firstWhere((c) => c.suit == Suit.hearts && c.rank == Rank.king)
        .flipped(true);
    final state = deal.withPiles([
      Pile(PileRef.stock),
      for (var i = 0; i < 7; i++)
        Pile(PileRef.tableau(i), i == 0 ? [king] : const []),
      Pile(const PileRef.foundation(0), suit(Suit.spades)),
      Pile(const PileRef.foundation(1), suit(Suit.hearts)),
      Pile(const PileRef.foundation(2), suit(Suit.diamonds)),
      Pile(const PileRef.foundation(3), suit(Suit.clubs)),
    ]);
    final session = GameSession.fromJson({
      ...GameSession.start(GameMode.klondike1, 1).toJson(),
      'state': state.toJson(),
      'elapsed': 95000,
      'moves': 80,
    });
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(MemoryStore()),
        initialSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SoliNovaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await settle(tester);
    expect(find.byTooltip('Terminer'), findsOneWidget);
    await tester.tap(find.byTooltip('Terminer'));
    await settle(tester);
    await settle(tester);
    final game = container.read(gameProvider);
    expect(game.report, isNotNull);
    expect(game.report!.result.won, isTrue);
    expect(find.text('Victoire'), findsOneWidget);
    expect(find.textContaining('Succès débloqué'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(container.read(profileProvider).stats.global.wins, 1);
    expect(container.read(profileProvider).wallet.balance, greaterThan(0));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -2000),
    );
    await settle(tester);
    expect(find.text('Rejouer'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    // Nouvelle partie depuis le bilan.
    await tester.tap(find.text('Nouvelle partie'));
    await settle(tester);
    expect(container.read(gameProvider).report, isNull);
    expect(container.read(gameProvider).session!.started, isFalse);
  });
}
