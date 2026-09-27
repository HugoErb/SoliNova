/// Valeur d'une carte, de l'As (1) au Roi (13).
enum Rank {
  ace(1, 'A', 'As'),
  two(2, '2', 'Deux'),
  three(3, '3', 'Trois'),
  four(4, '4', 'Quatre'),
  five(5, '5', 'Cinq'),
  six(6, '6', 'Six'),
  seven(7, '7', 'Sept'),
  eight(8, '8', 'Huit'),
  nine(9, '9', 'Neuf'),
  ten(10, '10', 'Dix'),
  jack(11, 'V', 'Valet'),
  queen(12, 'D', 'Dame'),
  king(13, 'R', 'Roi');

  const Rank(this.value, this.short, this.label);

  final int value;
  final String short;
  final String label;

  static Rank fromValue(int value) => Rank.values[value - 1];

  bool get isAce => this == Rank.ace;
  bool get isKing => this == Rank.king;
}
