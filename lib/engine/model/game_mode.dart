/// Famille de règles. Permet d'ajouter Pyramid, TriPeaks, Yukon… plus tard.
enum GameFamily { klondike, spider, freecell }

/// Mode de jeu jouable. Chaque mode a ses règles, sa distribution, son score
/// et ses statistiques propres.
enum GameMode {
  klondike1(GameFamily.klondike, 'Klondike', 'Tirage 1 carte', drawCount: 1),
  klondike3(GameFamily.klondike, 'Klondike', 'Tirage 3 cartes', drawCount: 3),
  spider1(GameFamily.spider, 'Spider', '1 couleur', suitCount: 1),
  spider2(GameFamily.spider, 'Spider', '2 couleurs', suitCount: 2),
  spider4(GameFamily.spider, 'Spider', '4 couleurs', suitCount: 4),
  freecell(GameFamily.freecell, 'FreeCell', '4 cellules libres');

  const GameMode(
    this.family,
    this.title,
    this.subtitle, {
    this.drawCount = 1,
    this.suitCount = 4,
  });

  final GameFamily family;
  final String title;
  final String subtitle;
  final int drawCount;
  final int suitCount;

  String get fullName => '$title — $subtitle';

  static GameMode? tryParse(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
