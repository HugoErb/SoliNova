import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/deck.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/rng/seeded_random.dart';
import 'package:solinova/engine/rules/rules_registry.dart';

void main() {
  group('SeededRandom', () {
    test('même graine => même suite', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);
      for (var i = 0; i < 100; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
    });

    test('valeurs de référence stables (ne doivent jamais changer)', () {
      final r = SeededRandom(1);
      // Valeurs figées : si ce test casse, les défis quotidiens changent.
      expect([r.nextUint32(), r.nextUint32(), r.nextUint32()], [
        2693262067,
        11749833,
        2265367787,
      ]);
    });

    test('nextInt reste dans les bornes', () {
      final r = SeededRandom(7);
      for (var i = 0; i < 1000; i++) {
        final v = r.nextInt(13);
        expect(v, inInclusiveRange(0, 12));
      }
    });

    test('hashString est stable', () {
      expect(SeededRandom.hashString(''), 0x811C9DC5);
      expect(SeededRandom.hashString('a'), 0xE40C292C);
      expect(
        SeededRandom.hashString('2026-09-27|facile'),
        SeededRandom.hashString('2026-09-27|facile'),
      );
    });
  });

  group('Deck', () {
    test('paquet standard : 52 cartes uniques', () {
      final deck = Deck.standard();
      expect(deck.length, 52);
      expect(deck.map((c) => c.id).toSet().length, 52);
      expect(deck.map((c) => '${c.suit}${c.rank}').toSet().length, 52);
    });

    test('mélange déterministe et permutation', () {
      final a = Deck.shuffled(Deck.standard(), 123);
      final b = Deck.shuffled(Deck.standard(), 123);
      final other = Deck.shuffled(Deck.standard(), 124);
      expect(a.map((c) => c.id), b.map((c) => c.id));
      expect(a.map((c) => c.id), isNot(other.map((c) => c.id)));
      expect(a.map((c) => c.id).toSet().length, 52);
    });
  });

  group('Distribution', () {
    test('Klondike : 1..7 cartes, dernière visible, pioche de 24', () {
      for (final mode in [GameMode.klondike1, GameMode.klondike3]) {
        final s = RulesRegistry.of(mode).deal(99);
        for (var i = 0; i < 7; i++) {
          final col = s.tableau[i];
          expect(col.length, i + 1);
          expect(col.top!.faceUp, isTrue);
          expect(col.cards.where((c) => c.faceUp).length, 1);
        }
        expect(s.stock.length, 24);
        expect(s.stock.cards.every((c) => !c.faceUp), isTrue);
        expect(s.totalCards, 52);
      }
    });

    test('Spider : 54 cartes au tableau, 50 en pioche, couleurs', () {
      final expectedSuits = {
        GameMode.spider1: 1,
        GameMode.spider2: 2,
        GameMode.spider4: 4,
      };
      expectedSuits.forEach((mode, suits) {
        final s = RulesRegistry.of(mode).deal(5);
        expect(s.tableau.length, 10);
        expect(s.tableau.fold(0, (n, p) => n + p.length), 54);
        for (var i = 0; i < 10; i++) {
          expect(s.tableau[i].length, i < 4 ? 6 : 5);
          expect(s.tableau[i].top!.faceUp, isTrue);
        }
        expect(s.stock.length, 50);
        expect(s.foundations.length, 8);
        final all = s.allPiles.expand((p) => p.cards).toList();
        expect(all.length, 104);
        expect(all.map((c) => c.id).toSet().length, 104);
        expect(all.map((c) => c.suit).toSet().length, suits);
      });
    });

    test('FreeCell : 8 colonnes (7,7,7,7,6,6,6,6) toutes visibles', () {
      final s = RulesRegistry.of(GameMode.freecell).deal(11);
      expect([for (final p in s.tableau) p.length], [7, 7, 7, 7, 6, 6, 6, 6]);
      expect(s.tableau.every((p) => p.cards.every((c) => c.faceUp)), isTrue);
      expect(s.freeCells.length, 4);
      expect(s.stock.isEmpty, isTrue);
    });

    test('même graine => même donne pour chaque mode', () {
      for (final mode in GameMode.values) {
        final a = RulesRegistry.of(mode).deal(2024);
        final b = RulesRegistry.of(mode).deal(2024);
        expect(a.toJson(), b.toJson());
      }
    });
  });
}
