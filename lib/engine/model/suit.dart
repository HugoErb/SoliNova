/// Couleur (enseigne) d'une carte.
enum Suit {
  spades('Pique', '♠', isRed: false),
  hearts('Cœur', '♥', isRed: true),
  diamonds('Carreau', '♦', isRed: true),
  clubs('Trèfle', '♣', isRed: false);

  const Suit(this.label, this.symbol, {required this.isRed});

  final String label;
  final String symbol;
  final bool isRed;

  bool isOppositeColorOf(Suit other) => isRed != other.isRed;
}
