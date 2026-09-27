import '../rng/seeded_random.dart';
import 'card.dart';
import 'rank.dart';
import 'suit.dart';

/// Construction et mélange de paquets.
abstract final class Deck {
  /// Paquet standard de 52 cartes, face cachée.
  static List<Card> standard() => build(Suit.values, copies: 1);

  /// Construit [copies] séries de 13 cartes pour chaque couleur de [suits].
  static List<Card> build(List<Suit> suits, {required int copies}) {
    final cards = <Card>[];
    var id = 0;
    for (var c = 0; c < copies; c++) {
      for (final suit in suits) {
        for (final rank in Rank.values) {
          cards.add(Card(id: id++, suit: suit, rank: rank));
        }
      }
    }
    return cards;
  }

  /// Mélange de Fisher-Yates déterministe.
  static List<Card> shuffled(List<Card> cards, int seed) {
    final rng = SeededRandom(seed);
    final list = [...cards];
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }
}
