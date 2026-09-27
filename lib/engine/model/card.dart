import 'rank.dart';
import 'suit.dart';

/// Carte immuable. [id] est unique dans une partie (0..51 ou 0..103) et
/// permet à l'interface de suivre la carte d'une pile à l'autre.
final class Card {
  const Card({
    required this.id,
    required this.suit,
    required this.rank,
    this.faceUp = false,
  });

  final int id;
  final Suit suit;
  final Rank rank;
  final bool faceUp;

  bool get isRed => suit.isRed;

  Card flipped(bool up) =>
      up == faceUp ? this : Card(id: id, suit: suit, rank: rank, faceUp: up);

  /// Encodage compact pour la persistance.
  int encode() =>
      ((id * 4 + suit.index) * 16 + rank.value) * 2 + (faceUp ? 1 : 0);

  static Card decode(int code) {
    final up = code % 2 == 1;
    var rest = code ~/ 2;
    final rank = Rank.fromValue(rest % 16);
    rest ~/= 16;
    final suit = Suit.values[rest % 4];
    return Card(id: rest ~/ 4, suit: suit, rank: rank, faceUp: up);
  }

  String get label => '${rank.label} de ${suit.label}';

  @override
  bool operator ==(Object other) =>
      other is Card &&
      other.id == id &&
      other.suit == suit &&
      other.rank == rank &&
      other.faceUp == faceUp;

  @override
  int get hashCode => Object.hash(id, suit, rank, faceUp);

  @override
  String toString() => '${rank.short}${suit.symbol}${faceUp ? '' : '*'}';
}
