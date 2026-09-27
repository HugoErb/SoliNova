import 'card.dart';

/// Type de pile sur le plateau.
enum PileKind { stock, waste, foundation, tableau, freeCell }

/// Référence stable vers une pile du plateau.
final class PileRef {
  const PileRef(this.kind, [this.index = 0]);

  static const stock = PileRef(PileKind.stock);
  static const waste = PileRef(PileKind.waste);

  const PileRef.foundation(int index) : this(PileKind.foundation, index);
  const PileRef.tableau(int index) : this(PileKind.tableau, index);
  const PileRef.freeCell(int index) : this(PileKind.freeCell, index);

  final PileKind kind;
  final int index;

  String encode() => '${kind.name}:$index';

  static PileRef decode(String value) {
    final parts = value.split(':');
    return PileRef(PileKind.values.byName(parts[0]), int.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      other is PileRef && other.kind == kind && other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);

  @override
  String toString() => encode();
}

/// Pile immuable de cartes. Le dernier élément de [cards] est le dessus.
///
/// Les fondations, colonnes du tableau, cellules libres, pioche et défausse
/// sont toutes des [Pile] distinguées par [PileRef.kind].
final class Pile {
  Pile(this.ref, [List<Card> cards = const []])
    : cards = List.unmodifiable(cards);

  final PileRef ref;
  final List<Card> cards;

  bool get isEmpty => cards.isEmpty;
  bool get isNotEmpty => cards.isNotEmpty;
  int get length => cards.length;
  Card? get top => cards.isEmpty ? null : cards.last;

  /// Index de la première carte visible, ou [length] si aucune.
  int get firstFaceUpIndex {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].faceUp) return i;
    }
    return cards.length;
  }

  Pile withCards(List<Card> newCards) => Pile(ref, newCards);

  Pile push(Iterable<Card> added) => Pile(ref, [...cards, ...added]);

  /// Retire les [count] cartes du dessus.
  Pile removeTop(int count) =>
      Pile(ref, cards.sublist(0, cards.length - count));

  List<Card> takeTop(int count) => cards.sublist(cards.length - count);

  /// Retourne la carte du dessus face visible si nécessaire.
  Pile revealTop() {
    final t = top;
    if (t == null || t.faceUp) return this;
    return Pile(ref, [...cards.sublist(0, cards.length - 1), t.flipped(true)]);
  }
}
