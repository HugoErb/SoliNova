import 'pile.dart';

/// Mouvement joué sur le plateau.
sealed class Move {
  const Move();

  Map<String, Object> toJson();

  static Move fromJson(Map<String, Object?> json) {
    return switch (json['t']) {
      'x' => TransferMove(
        from: PileRef.decode(json['f']! as String),
        to: PileRef.decode(json['d']! as String),
        count: json['n']! as int,
      ),
      'draw' => const DrawMove(),
      'recycle' => const RecycleMove(),
      _ => throw FormatException('Mouvement inconnu : $json'),
    };
  }
}

/// Déplace les [count] cartes du dessus de [from] vers [to].
final class TransferMove extends Move {
  const TransferMove({required this.from, required this.to, this.count = 1});

  final PileRef from;
  final PileRef to;
  final int count;

  @override
  Map<String, Object> toJson() => {
    't': 'x',
    'f': from.encode(),
    'd': to.encode(),
    'n': count,
  };

  @override
  bool operator ==(Object other) =>
      other is TransferMove &&
      other.from == from &&
      other.to == to &&
      other.count == count;

  @override
  int get hashCode => Object.hash(from, to, count);

  @override
  String toString() => 'Transfer($from -> $to x$count)';
}

/// Pioche (Klondike) ou distribution d'une rangée (Spider).
final class DrawMove extends Move {
  const DrawMove();

  @override
  Map<String, Object> toJson() => {'t': 'draw'};

  @override
  bool operator ==(Object other) => other is DrawMove;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'Draw';
}

/// Remet la défausse dans la pioche (Klondike).
final class RecycleMove extends Move {
  const RecycleMove();

  @override
  Map<String, Object> toJson() => {'t': 'recycle'};

  @override
  bool operator ==(Object other) => other is RecycleMove;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'Recycle';
}
