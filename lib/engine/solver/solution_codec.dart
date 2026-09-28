import '../model/move.dart';
import '../model/pile.dart';

/// Encodage compact d'une suite de coups (donnes gagnables pré-calculées).
///
/// Pioche : `+`, recyclage : `~`. Déplacement : trois caractères (source,
/// destination, nombre de cartes).
abstract final class SolutionCodec {
  static const _draw = '+';
  static const _recycle = '~';

  static String encode(List<Move> moves) {
    final buf = StringBuffer();
    for (final m in moves) {
      switch (m) {
        case DrawMove():
          buf.write(_draw);
        case RecycleMove():
          buf.write(_recycle);
        case TransferMove(:final from, :final to, :final count):
          buf
            ..write(_pile(from))
            ..write(_pile(to))
            ..writeCharCode(96 + count);
      }
    }
    return buf.toString();
  }

  static List<Move> decode(String text) {
    final moves = <Move>[];
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == _draw) {
        moves.add(const DrawMove());
        i++;
      } else if (c == _recycle) {
        moves.add(const RecycleMove());
        i++;
      } else {
        moves.add(
          TransferMove(
            from: _ref(text[i]),
            to: _ref(text[i + 1]),
            count: text.codeUnitAt(i + 2) - 96,
          ),
        );
        i += 3;
      }
    }
    return moves;
  }

  // Colonnes : a–j, fondations : A–H, cellules : w–z, défausse : W.
  static String _pile(PileRef p) => switch (p.kind) {
    PileKind.tableau => String.fromCharCode(97 + p.index),
    PileKind.foundation => String.fromCharCode(65 + p.index),
    PileKind.freeCell => String.fromCharCode(119 + p.index),
    PileKind.waste => 'W',
    PileKind.stock => 'S',
  };

  static PileRef _ref(String c) {
    final code = c.codeUnitAt(0);
    if (c == 'W') return PileRef.waste;
    if (c == 'S') return PileRef.stock;
    if (code >= 119) return PileRef.freeCell(code - 119);
    if (code >= 97) return PileRef.tableau(code - 97);
    return PileRef.foundation(code - 65);
  }
}
