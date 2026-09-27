import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/model/move.dart';
import 'package:solinova/engine/model/pile.dart';
import 'package:solinova/engine/rules/klondike_rules.dart';
import 'package:solinova/engine/scoring/live_points.dart';

import 'test_helpers.dart';

void main() {
  const k1 = KlondikeRules(GameMode.klondike1);
  const k3 = KlondikeRules(GameMode.klondike3);

  group('Klondike — tableau', () {
    test('couleur alternée et valeur décroissante', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(8, s)],
          [c(7, h)],
          [c(7, cl)],
        ],
      );
      const ok = TransferMove(from: PileRef.tableau(1), to: PileRef.tableau(0));
      const sameColor = TransferMove(
        from: PileRef.tableau(2),
        to: PileRef.tableau(0),
      );
      expect(k1.isLegal(st, ok), isTrue);
      expect(k1.isLegal(st, sameColor), isFalse);
    });

    test('seul un Roi va sur une colonne vide', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [],
          [c(13, h)],
          [c(12, s)],
        ],
      );
      expect(
        k1.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(1), to: PileRef.tableau(0)),
        ),
        isTrue,
      );
      expect(
        k1.isLegal(
          st,
          const TransferMove(from: PileRef.tableau(2), to: PileRef.tableau(0)),
        ),
        isFalse,
      );
    });

    test('déplacement d\'une suite et retournement automatique', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(9, cl)],
          [c(2, s, up: false), c(8, h), c(7, s)],
        ],
      );
      const m = TransferMove(
        from: PileRef.tableau(1),
        to: PileRef.tableau(0),
        count: 2,
      );
      expect(k1.isLegal(st, m), isTrue);
      final next = k1.apply(st, m);
      expect(next.tableau[0].length, 3);
      expect(next.tableau[1].top!.faceUp, isTrue);
      expect(next.points, LivePoints.reveal);
    });

    test('impossible de saisir une carte cachée', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(9, cl)],
          [c(8, h, up: false), c(7, s)],
        ],
      );
      expect(k1.canPickUp(st, const PileRef.tableau(1), 2), isFalse);
    });
  });

  group('Klondike — fondations', () {
    test('As sur fondation vide, puis même couleur croissante', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(1, h)],
          [c(2, h)],
          [c(2, s)],
        ],
      );
      const ace = TransferMove(
        from: PileRef.tableau(0),
        to: PileRef.foundation(0),
      );
      final next = k1.apply(st, ace);
      expect(next.points, LivePoints.toFoundation);
      expect(
        k1.isLegal(
          next,
          const TransferMove(
            from: PileRef.tableau(1),
            to: PileRef.foundation(0),
          ),
        ),
        isTrue,
      );
      expect(
        k1.isLegal(
          next,
          const TransferMove(
            from: PileRef.tableau(2),
            to: PileRef.foundation(0),
          ),
        ),
        isFalse,
      );
    });

    test('pas de suite de plusieurs cartes vers une fondation', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(2, s), c(1, h)],
        ],
        foundations: [run(s, 1)],
      );
      expect(
        k1.isLegal(
          st,
          const TransferMove(
            from: PileRef.tableau(0),
            to: PileRef.foundation(0),
            count: 2,
          ),
        ),
        isFalse,
      );
    });

    test('reprise d\'une fondation vers le tableau : pénalité', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(4, s)],
        ],
        foundations: [run(h, 3)],
      );
      const m = TransferMove(
        from: PileRef.foundation(0),
        to: PileRef.tableau(0),
      );
      expect(k1.isLegal(st, m), isTrue);
      expect(k1.apply(st, m).points, LivePoints.foundationToTableau);
    });
  });

  group('Klondike — pioche', () {
    test('tirage 1 et 3 cartes', () {
      final stock = [c(1, s, up: false), c(2, s, up: false), c(3, s, up: false), c(4, s, up: false)];
      final st1 = board(GameMode.klondike1, stock: stock);
      final a = k1.apply(st1, const DrawMove());
      expect(a.waste.length, 1);
      expect(a.waste.top!.rank.value, 4);
      expect(a.waste.top!.faceUp, isTrue);

      final st3 = board(GameMode.klondike3, stock: stock);
      final b = k3.apply(st3, const DrawMove());
      expect(b.waste.length, 3);
      expect([for (final x in b.waste.cards) x.rank.value], [4, 3, 2]);
      final b2 = k3.apply(b, const DrawMove());
      expect(b2.waste.length, 4);
      expect(b2.stock.isEmpty, isTrue);
    });

    test('recyclage : ordre restauré, faces cachées, pénalité en tirage 1', () {
      final st = board(
        GameMode.klondike1,
        waste: [c(1, s), c(2, s), c(3, s)],
      );
      expect(k1.isLegal(st, const DrawMove()), isFalse);
      expect(k1.isLegal(st, const RecycleMove()), isTrue);
      final next = k1.apply(st, const RecycleMove());
      expect(next.waste.isEmpty, isTrue);
      expect(next.stock.length, 3);
      expect(next.stock.cards.every((x) => !x.faceUp), isTrue);
      expect(next.stock.top!.rank.value, 1);
      expect(next.points, LivePoints.recycleDraw1);
      expect(next.recycleCount, 1);

      final st3 = board(GameMode.klondike3, waste: [c(1, s)]);
      expect(k3.apply(st3, const RecycleMove()).points, 0);
    });

    test('recyclage interdit tant que la pioche n\'est pas vide', () {
      final st = board(
        GameMode.klondike1,
        stock: [c(5, s, up: false)],
        waste: [c(1, s)],
      );
      expect(k1.isLegal(st, const RecycleMove()), isFalse);
    });
  });

  group('Klondike — victoire et automatismes', () {
    test('victoire quand les 52 cartes sont en fondation', () {
      final st = board(
        GameMode.klondike1,
        foundations: [run(s, 13), run(h, 13), run(d, 13), run(cl, 13)],
      );
      expect(k1.isWon(st), isTrue);
      expect(k1.isWon(k1.deal(1)), isFalse);
    });

    test('terminaison automatique quand tout est visible', () {
      var st = board(
        GameMode.klondike1,
        tableau: [
          [c(13, s), c(12, h)],
          [c(13, h), c(12, s)],
        ],
        foundations: [run(s, 11), run(h, 11), run(d, 13), run(cl, 13)],
      );
      expect(k1.canAutoComplete(st), isTrue);
      var guard = 0;
      while (!k1.isWon(st) && guard++ < 10) {
        st = k1.apply(st, k1.nextAutoCompleteMove(st)!);
      }
      expect(k1.isWon(st), isTrue);
    });

    test('coup sûr : un 2 part en fondation, un 5 attend', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(2, h)],
        ],
        foundations: [run(h, 1)],
      );
      expect(k1.nextSafeAutoMove(st), isNotNull);

      final st2 = board(
        GameMode.klondike1,
        tableau: [
          [c(5, h)],
        ],
        foundations: [run(h, 4), run(s, 2), run(cl, 2)],
      );
      expect(k1.nextSafeAutoMove(st2), isNull);
    });

    test('toucher : priorité à la fondation', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(3, h)],
          [c(4, s)],
        ],
        foundations: [run(h, 2)],
      );
      final m = k1.bestMoveFor(st, const PileRef.tableau(0), 1);
      expect(m, const TransferMove(from: PileRef.tableau(0), to: PileRef.foundation(0)));
    });
  });

  group('Klondike — indices', () {
    test('propose un mouvement valide, sans le jouer', () {
      final st = k1.deal(12345);
      final hints = k1.hintMoves(st);
      for (final m in hints) {
        expect(k1.isLegal(st, m), isTrue);
      }
    });

    test('aucun indice quand rien n\'est pertinent', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(13, s)],
          [c(5, h)],
        ],
      );
      expect(k1.hintMoves(st), isEmpty);
    });

    test('préfère un retournement à un simple déplacement', () {
      final st = board(
        GameMode.klondike1,
        tableau: [
          [c(9, s)],
          [c(1, d, up: false), c(8, h)],
          [c(9, cl), c(8, d)],
        ],
      );
      final hint = k1.hintMoves(st).first as TransferMove;
      expect(hint.from, const PileRef.tableau(1));
    });
    test('tirage 3 : ne propose pas de piocher une carte inaccessible', () {
      // Ordre de sortie : 10♦, 4♠, 9♦. Seules la 3e carte et la dernière
      // arrivent sur le dessus : le 4♠ n'est jamais jouable.
      final st = board(
        GameMode.klondike3,
        tableau: [
          [c(13, s)],
          [c(5, h)],
        ],
        stock: [c(9, d, up: false), c(4, s, up: false), c(10, d, up: false)],
      );
      expect(k3.hintMoves(st), isNot(contains(const DrawMove())));
      expect(k1.hintMoves(st), contains(const DrawMove()));
    });
  });
}
