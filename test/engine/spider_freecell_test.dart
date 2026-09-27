import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/rules/freecell_rules.dart';
import 'package:solinova/engine/rules/spider_rules.dart';
import 'package:solinova/engine/scoring/live_points.dart';

import 'test_helpers.dart';

void main() {
  const sp1 = SpiderRules(GameMode.spider1);
  const sp4 = SpiderRules(GameMode.spider4);
  const fc = FreeCellRules(GameMode.freecell);

  group('Spider', () {
    test('toute carte de valeur supérieure accepte, quelle que soit la couleur', () {
      final st = board(
        GameMode.spider4,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [c(8, h)],
          [c(7, s)],
        ],
      );
      expect(
        sp4.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(1), to: PileRef.tableau(0)),
        ),
        isTrue,
      );
    });

    test('seule une suite de même couleur se déplace en bloc', () {
      final st = board(
        GameMode.spider4,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [c(9, cl)],
          [c(8, h), c(7, s)],
          [c(8, s), c(7, s)],
        ],
      );
      expect(sp4.canPickUp(st, const PileRef.tableau(1), 2), isFalse);
      expect(sp4.canPickUp(st, const PileRef.tableau(2), 2), isTrue);
    });

    test('n\'importe quelle carte sur une colonne vide', () {
      final st = board(
        GameMode.spider1,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [],
          [c(5, s)],
        ],
      );
      expect(
        sp1.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(1), to: PileRef.tableau(0)),
        ),
        isTrue,
      );
    });

    test('distribution interdite si une colonne est vide', () {
      var st = sp1.deal(3);
      expect(sp1.isLegal(st, const DrawMove()), isTrue);
      final dealt = sp1.apply(st, const DrawMove());
      expect(dealt.stock.length, 40);
      for (var i = 0; i < 10; i++) {
        expect(dealt.tableau[i].length, st.tableau[i].length + 1);
        expect(dealt.tableau[i].top!.faceUp, isTrue);
      }
      st = st.withPiles([Pile(const PileRef.tableau(0))]);
      expect(sp1.isLegal(st, const DrawMove()), isFalse);
    });

    test('suite complète Roi → As retirée automatiquement', () {
      final suite = [for (var r = 13; r >= 2; r--) c(r, s)];
      final st = board(
        GameMode.spider1,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [c(4, h, up: false), ...suite],
          [c(1, s)],
        ],
      );
      final next = sp1.apply(
        st,
        const TransferMove(from: PileRef.tableau(1), to: PileRef.tableau(0)),
      );
      expect(next.foundations[0].length, 13);
      expect(next.tableau[0].length, 1);
      expect(next.tableau[0].top!.faceUp, isTrue);
      // La colonne source devient vide : seule la colonne 0 révèle une carte.
      expect(next.points, LivePoints.spiderSuite + LivePoints.reveal);
    });

    test('victoire après 8 suites', () {
      final st = board(
        GameMode.spider1,
        tableauCount: 10,
        foundationCount: 8,
        foundations: [for (var i = 0; i < 8; i++) run(s, 13)],
      );
      expect(sp1.isWon(st), isTrue);
    });

    test('pas de mouvement vers une fondation à la main', () {
      final st = board(
        GameMode.spider1,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [c(1, s)],
        ],
      );
      expect(
        sp1.isLegal(
          st,
          const TransferMove(
            from: PileRef.tableau(0),
            to: PileRef.foundation(0),
          ),
        ),
        isFalse,
      );
    });

    test('toucher : préfère une carte de même couleur', () {
      final st = board(
        GameMode.spider4,
        tableauCount: 10,
        foundationCount: 8,
        tableau: [
          [c(6, h)],
          [c(6, s)],
          [c(5, s)],
        ],
      );
      final m = sp4.bestMoveFor(st, const PileRef.tableau(2), 1)!;
      expect((m as TransferMove).to, const PileRef.tableau(1));
    });
  });

  group('FreeCell', () {
    test('capacité de déplacement (cellules + colonnes vides)', () {
      final st = board(
        GameMode.freecell,
        tableauCount: 8,
        cellCount: 4,
        tableau: [
          [c(9, s)],
          [c(8, h), c(7, s), c(6, h)],
          [c(1, d)],
          [c(1, cl)],
          [c(2, d)],
          [c(2, cl)],
          [c(3, d)],
          [c(3, cl)],
        ],
        cells: [
          [c(13, s)],
          [c(13, h)],
          [c(13, d)],
        ],
      );
      // 1 cellule libre, 0 colonne vide => 2 cartes max.
      expect(fc.maxMovable(st, toEmptyColumn: false), 2);
      expect(
        fc.isLegal(
          st,
          const TransferMove(
            from: PileRef.tableau(1),
            to: PileRef.tableau(0),
            count: 3,
          ),
        ),
        isFalse,
      );
    });

    test('suite de 3 possible avec 2 cellules libres', () {
      final st = board(
        GameMode.freecell,
        tableauCount: 8,
        cellCount: 4,
        tableau: [
          [c(9, s)],
          [c(8, h), c(7, s), c(6, h)],
          [c(1, d)],
          [c(1, cl)],
          [c(2, d)],
          [c(2, cl)],
          [c(3, d)],
          [c(3, cl)],
        ],
        cells: [
          [c(13, s)],
          [c(13, h)],
        ],
      );
      expect(
        fc.isLegal(
          st,
          const TransferMove(
            from: PileRef.tableau(1),
            to: PileRef.tableau(0),
            count: 3,
          ),
        ),
        isTrue,
      );
    });

    test('cellule libre : une seule carte, cellule vide seulement', () {
      final st = board(
        GameMode.freecell,
        tableauCount: 8,
        cellCount: 4,
        tableau: [
          [c(5, s)],
        ],
        cells: [
          [c(9, h)],
        ],
      );
      expect(
        fc.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(0), to: PileRef.freeCell(0)),
        ),
        isFalse,
      );
      expect(
        fc.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(0), to: PileRef.freeCell(1)),
        ),
        isTrue,
      );
    });

    test('pas de retour depuis une fondation', () {
      final st = board(
        GameMode.freecell,
        tableauCount: 8,
        cellCount: 4,
        tableau: [
          [c(3, s)],
        ],
        foundations: [run(h, 2)],
      );
      expect(
        fc.isLegal(
          st,
          const TransferMove(
            from: PileRef.foundation(0),
            to: PileRef.tableau(0),
          ),
        ),
        isFalse,
      );
    });

    test('fin automatique quand les colonnes sont triées', () {
      final st = board(
        GameMode.freecell,
        tableauCount: 8,
        cellCount: 4,
        tableau: [
          [c(13, s), c(12, h)],
        ],
        foundations: [run(s, 12), run(h, 11), run(d, 13), run(cl, 13)],
        cells: [[], [c(13, h)]],
      );
      expect(fc.canAutoComplete(st), isTrue);
      var cur = st;
      var guard = 0;
      while (!fc.isWon(cur) && guard++ < 10) {
        cur = fc.apply(cur, fc.nextAutoCompleteMove(cur)!);
      }
      expect(fc.isWon(cur), isTrue);
    });
  });

  test('Spider : colonne vide bloquant la donne, indice pour la remplir', () {
    final st = board(
      GameMode.spider2,
      tableauCount: 10,
      foundationCount: 8,
      tableau: [
        [c(12, s), c(11, s)],
        [c(2, s), c(1, s)],
        [c(8, s), c(7, s), c(6, s)],
        [c(4, s)],
        [],
        [c(7, h), c(6, h), c(5, h), c(4, h)],
        [c(13, h), c(12, h), c(11, h)],
        [c(1, h)],
        [],
        [],
      ],
      stock: [for (var i = 0; i < 10; i++) c(9, d, up: false)],
    );
    expect(sp1.isLegal(st, const DrawMove()), isFalse);
    final hints = sp1.hintMoves(st);
    expect(hints, isNotEmpty);
    final first = hints.first as TransferMove;
    expect(st.pile(first.to).isEmpty, isTrue);
    expect(first.count, 1);
  });
}
