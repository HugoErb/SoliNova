import 'card.dart';
import 'game_mode.dart';
import 'pile.dart';

/// État immuable du plateau à un instant donné.
final class GameState {
  GameState({
    required this.mode,
    required this.stock,
    required this.waste,
    required List<Pile> foundations,
    required List<Pile> tableau,
    List<Pile> freeCells = const [],
    this.points = 0,
    this.recycleCount = 0,
  }) : foundations = List.unmodifiable(foundations),
       tableau = List.unmodifiable(tableau),
       freeCells = List.unmodifiable(freeCells);

  final GameMode mode;
  final Pile stock;
  final Pile waste;
  final List<Pile> foundations;
  final List<Pile> tableau;
  final List<Pile> freeCells;

  /// Points de jeu cumulés pendant la partie (voir le module de score).
  final int points;
  final int recycleCount;

  Pile pile(PileRef ref) => switch (ref.kind) {
    PileKind.stock => stock,
    PileKind.waste => waste,
    PileKind.foundation => foundations[ref.index],
    PileKind.tableau => tableau[ref.index],
    PileKind.freeCell => freeCells[ref.index],
  };

  Iterable<Pile> get allPiles sync* {
    yield stock;
    yield waste;
    yield* foundations;
    yield* tableau;
    yield* freeCells;
  }

  int get totalCards => allPiles.fold(0, (sum, p) => sum + p.length);

  int get foundationCardCount =>
      foundations.fold(0, (sum, p) => sum + p.length);

  /// Remplace une ou plusieurs piles.
  GameState withPiles(Iterable<Pile> piles, {int? points, int? recycleCount}) {
    var stock = this.stock;
    var waste = this.waste;
    final foundations = [...this.foundations];
    final tableau = [...this.tableau];
    final freeCells = [...this.freeCells];
    for (final p in piles) {
      switch (p.ref.kind) {
        case PileKind.stock:
          stock = p;
        case PileKind.waste:
          waste = p;
        case PileKind.foundation:
          foundations[p.ref.index] = p;
        case PileKind.tableau:
          tableau[p.ref.index] = p;
        case PileKind.freeCell:
          freeCells[p.ref.index] = p;
      }
    }
    return GameState(
      mode: mode,
      stock: stock,
      waste: waste,
      foundations: foundations,
      tableau: tableau,
      freeCells: freeCells,
      points: points ?? this.points,
      recycleCount: recycleCount ?? this.recycleCount,
    );
  }

  GameState copyWith({int? points, int? recycleCount}) =>
      withPiles(const [], points: points, recycleCount: recycleCount);

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'points': points,
    'recycles': recycleCount,
    'piles': {
      for (final p in allPiles)
        p.ref.encode(): [for (final c in p.cards) c.encode()],
    },
  };

  static GameState fromJson(Map<String, Object?> json) {
    final mode = GameMode.values.byName(json['mode']! as String);
    final raw = (json['piles']! as Map).cast<String, Object?>();
    final piles = <PileRef, Pile>{};
    raw.forEach((key, value) {
      final ref = PileRef.decode(key);
      final cards = [
        for (final code in (value! as List).cast<int>()) Card.decode(code),
      ];
      piles[ref] = Pile(ref, cards);
    });
    List<Pile> list(PileKind kind) {
      final refs = piles.keys.where((r) => r.kind == kind).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      return [for (final r in refs) piles[r]!];
    }

    return GameState(
      mode: mode,
      stock: piles[PileRef.stock] ?? Pile(PileRef.stock),
      waste: piles[PileRef.waste] ?? Pile(PileRef.waste),
      foundations: list(PileKind.foundation),
      tableau: list(PileKind.tableau),
      freeCells: list(PileKind.freeCell),
      points: json['points']! as int,
      recycleCount: json['recycles']! as int,
    );
  }
}
