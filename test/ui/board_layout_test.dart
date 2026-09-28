import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/card.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/game_state.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/model/rank.dart';
import 'package:solinova/engine/model/suit.dart';
import 'package:solinova/engine/rng/seeded_random.dart';
import 'package:solinova/engine/rules/rules_registry.dart';
import 'package:solinova/ui/board/board_layout.dart';
import 'package:solinova/ui/cards/card_painter.dart';
import 'package:solinova/ui/theme/look.dart';

/// Zones de plateau (dp) pour des téléphones courants, en portrait, une fois
/// retirés la barre d'état, le bandeau d'infos et la barre d'actions.
const boards = <String, Size>{
  'petit 320x568': Size(320, 440),
  '360x640': Size(360, 510),
  '360x800': Size(360, 660),
  '393x851 (Pixel)': Size(393, 715),
  '412x915': Size(412, 780),
  '480x1000 grand': Size(480, 860),
};

double strip(double w) => indexStripHeight(w, FaceStyle.large);

void expectInside(BoardGeometry g, String label) {
  for (final p in g.placements.values) {
    final r = p.rect;
    expect(r.left, greaterThanOrEqualTo(-0.01), reason: '$label gauche');
    expect(
      r.right,
      lessThanOrEqualTo(g.size.width + 0.01),
      reason: '$label droite',
    );
    expect(r.top, greaterThanOrEqualTo(-0.01), reason: '$label haut');
    expect(
      r.bottom,
      lessThanOrEqualTo(g.size.height + 0.01),
      reason: '$label bas',
    );
  }
}

GameState longColumn(GameMode mode, {required int down, required int up}) {
  final base = RulesRegistry.of(mode).deal(1);
  var id = 5000;
  final cards = [
    for (var i = 0; i < down; i++)
      Card(id: id++, suit: Suit.spades, rank: Rank.king),
    for (var i = 0; i < up; i++)
      Card(
        id: id++,
        suit: i.isEven ? Suit.hearts : Suit.spades,
        rank: Rank.fromValue(13 - i % 13),
        faceUp: true,
      ),
  ];
  return base.withPiles([Pile(const PileRef.tableau(0), cards)]);
}

void main() {
  for (final entry in boards.entries) {
    for (final mode in GameMode.values) {
      test('${entry.key} — ${mode.fullName} : tout tient à l\'écran', () {
        final rules = RulesRegistry.of(mode);
        final rng = SeededRandom(9);
        var state = rules.deal(4);
        for (var step = 0; step < 200; step++) {
          final g = BoardGeometry.compute(
            state: state,
            size: entry.value,
            indexStrip: strip,
          );
          expectInside(g, '${mode.name} étape $step');
          final moves = rules.legalMoves(state);
          if (moves.isEmpty) break;
          state = rules.apply(state, moves[rng.nextInt(moves.length)]);
        }
      });
    }

    test('${entry.key} : colonnes extrêmes restent lisibles', () {
      final cases = {
        GameMode.klondike1: (6, 13),
        GameMode.freecell: (0, 19),
        GameMode.spider4: (5, 20),
      };
      cases.forEach((mode, dims) {
        final state = longColumn(mode, down: dims.$1, up: dims.$2);
        final g = BoardGeometry.compute(
          state: state,
          size: entry.value,
          indexStrip: strip,
        );
        expectInside(g, mode.name);
        final col = state.tableau[0];
        final a = g.placements[col.cards[col.length - 2].id]!.rect;
        final b = g.placements[col.cards[col.length - 1].id]!.rect;
        expect(
          b.top - a.top,
          greaterThanOrEqualTo(g.minFaceUpOffset - 0.01),
          reason: '${mode.name} : index de la carte recouverte visible',
        );
      });
    });

    test('${entry.key} : cartes assez grandes pour être manipulées', () {
      for (final mode in GameMode.values) {
        final g = BoardGeometry.compute(
          state: RulesRegistry.of(mode).deal(1),
          size: entry.value,
          indexStrip: strip,
        );
        expect(g.cardSize.width, greaterThanOrEqualTo(28), reason: mode.name);
        // Largeur totale utilisée : jamais plus que l'écran.
        final maxRight = g.slots.values
            .map((r) => r.right)
            .reduce((a, b) => a > b ? a : b);
        expect(maxRight, lessThanOrEqualTo(entry.value.width));
      }
    });
  }

  test('hitTest renvoie la carte du dessus', () {
    final state = RulesRegistry.of(GameMode.klondike1).deal(3);
    final g = BoardGeometry.compute(
      state: state,
      size: const Size(360, 600),
      indexStrip: strip,
    );
    final col = state.tableau[6];
    final topCard = g.placements[col.top!.id]!;
    expect(g.hitTest(topCard.rect.center)!.card.id, col.top!.id);
  });
}
