/// Catégories de la boutique. Tout est cosmétique.
enum ShopCategory {
  theme('Thèmes', 'Ambiance complète : palette, tapis, dos de cartes'),
  table('Fonds de table', 'Remplace le tapis du thème'),
  cardFace('Styles de cartes', 'Apparence des faces'),
  cardBack('Dos de cartes', 'Motif au dos des cartes'),
  animation('Animations', 'Style de déplacement des cartes'),
  victory('Victoire', 'Animation de fin de partie'),
  effect('Effets visuels', 'Effets pendant la partie');

  const ShopCategory(this.label, this.description);

  final String label;
  final String description;

  /// Catégories pouvant rester « selon le thème » (aucun élément équipé).
  bool get followsTheme =>
      this == ShopCategory.table || this == ShopCategory.cardBack;
}

/// Élément de boutique. L'aperçu visuel est fourni par l'interface à partir
/// de [id] ; ce modèle reste indépendant de Flutter.
final class ShopItem {
  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    this.price = 0,
  });

  final String id;
  final ShopCategory category;
  final String name;
  final String description;

  /// Prix en points ; 0 = gratuit, possédé d'office.
  final int price;

  bool get isFree => price == 0;
}

/// Catalogue complet de la boutique.
abstract final class ShopCatalog {
  static const items = <ShopItem>[
    // Thèmes complets.
    ShopItem(
      id: 'theme.emerald',
      category: ShopCategory.theme,
      name: 'Classique vert',
      description: 'Un vert émeraude profond, sobre et reposant.',
    ),
    ShopItem(
      id: 'theme.midnight',
      category: ShopCategory.theme,
      name: 'Bleu nuit',
      description: 'Des bleus profonds et des reflets froids.',
    ),
    ShopItem(
      id: 'theme.minimal',
      category: ShopCategory.theme,
      name: 'Minimal clair',
      description: 'Lumineux, épuré, sans distraction.',
    ),
    ShopItem(
      id: 'theme.oled',
      category: ShopCategory.theme,
      name: 'Noir OLED',
      description: 'Noir absolu, contrastes nets, idéal la nuit.',
      price: 400,
    ),
    ShopItem(
      id: 'theme.modern',
      category: ShopCategory.theme,
      name: 'Moderne',
      description: 'Graphite et accents corail, lignes nettes.',
      price: 700,
    ),
    ShopItem(
      id: 'theme.pastel',
      category: ShopCategory.theme,
      name: 'Pastel',
      description: 'Lavande, pêche et menthe, tout en douceur.',
      price: 700,
    ),
    ShopItem(
      id: 'theme.wood',
      category: ShopCategory.theme,
      name: 'Bois',
      description: 'Noyer chaleureux et cartes ivoire.',
      price: 900,
    ),
    ShopItem(
      id: 'theme.aurora',
      category: ShopCategory.theme,
      name: 'Aurore',
      description: 'Dégradé boréal animé, violet et turquoise.',
      price: 1500,
    ),

    // Thèmes des saisons.
    ShopItem(
      id: 'theme.spring',
      category: ShopCategory.theme,
      name: 'Printemps',
      description: 'Vert tendre et fleurs de cerisier.',
      price: 800,
    ),
    ShopItem(
      id: 'theme.summer',
      category: ShopCategory.theme,
      name: 'Été',
      description: 'Bleu lagon et soleil éclatant.',
      price: 800,
    ),
    ShopItem(
      id: 'theme.autumn',
      category: ShopCategory.theme,
      name: 'Automne',
      description: 'Tons roux et feuilles d\'érable.',
      price: 800,
    ),
    ShopItem(
      id: 'theme.winter',
      category: ShopCategory.theme,
      name: 'Hiver',
      description: 'Bleu glacier et flocons de neige.',
      price: 800,
    ),

    // Thèmes des fêtes.
    ShopItem(
      id: 'theme.christmas',
      category: ShopCategory.theme,
      name: 'Noël',
      description: 'Vert sapin, rouge et or, sous la neige.',
      price: 1000,
    ),
    ShopItem(
      id: 'theme.halloween',
      category: ShopCategory.theme,
      name: 'Halloween',
      description: 'Nuit violette et citrouilles.',
      price: 1000,
    ),
    ShopItem(
      id: 'theme.valentine',
      category: ShopCategory.theme,
      name: 'Saint-Valentin',
      description: 'Bordeaux et rose, semé de cœurs.',
      price: 1000,
    ),
    ShopItem(
      id: 'theme.easter',
      category: ShopCategory.theme,
      name: 'Pâques',
      description: 'Pastels printaniers et œufs décorés.',
      price: 1000,
    ),

    // Fonds de table.
    ShopItem(
      id: 'table.graphite',
      category: ShopCategory.table,
      name: 'Graphite',
      description: 'Gris anthracite mat.',
      price: 200,
    ),
    ShopItem(
      id: 'table.sand',
      category: ShopCategory.table,
      name: 'Sable',
      description: 'Beige chaud et grain léger.',
      price: 250,
    ),
    ShopItem(
      id: 'table.slate',
      category: ShopCategory.table,
      name: 'Ardoise',
      description: 'Bleu-gris minéral.',
      price: 250,
    ),
    ShopItem(
      id: 'table.velvet',
      category: ShopCategory.table,
      name: 'Velours',
      description: 'Bordeaux feutré, vignettage doux.',
      price: 300,
    ),
    ShopItem(
      id: 'table.ocean',
      category: ShopCategory.table,
      name: 'Océan',
      description: 'Dégradé bleu lagon.',
      price: 300,
    ),

    // Styles de cartes. Les styles d'accessibilité sont gratuits.
    ShopItem(
      id: 'face.classic',
      category: ShopCategory.cardFace,
      name: 'Classique',
      description: 'Index lisibles et grand symbole central.',
    ),
    ShopItem(
      id: 'face.large',
      category: ShopCategory.cardFace,
      name: 'Grand index',
      description: 'Valeurs très grandes pour une lecture facile.',
    ),
    ShopItem(
      id: 'face.fourColor',
      category: ShopCategory.cardFace,
      name: 'Quatre couleurs',
      description: 'Pique noir, cœur rouge, carreau bleu, trèfle vert.',
    ),
    ShopItem(
      id: 'face.minimal',
      category: ShopCategory.cardFace,
      name: 'Épuré',
      description: 'Typographie fine, aucun ornement.',
      price: 200,
    ),
    ShopItem(
      id: 'face.elegant',
      category: ShopCategory.cardFace,
      name: 'Élégant',
      description: 'Filet doré et index raffinés.',
      price: 350,
    ),
    ShopItem(
      id: 'face.solid',
      category: ShopCategory.cardFace,
      name: 'Plein',
      description: 'Fond rouge ou anthracite, écriture blanche.',
      price: 400,
    ),
    ShopItem(
      id: 'face.solidFour',
      category: ShopCategory.cardFace,
      name: 'Plein 4 couleurs',
      description: 'Un fond de couleur par enseigne, écriture blanche.',
      price: 500,
    ),
    ShopItem(
      id: 'face.colored',
      category: ShopCategory.cardFace,
      name: 'Coloré',
      description: 'Fonds pastel et encre assortie à chaque enseigne.',
      price: 400,
    ),
    ShopItem(
      id: 'face.neon',
      category: ShopCategory.cardFace,
      name: 'Néon',
      description: 'Fond noir et couleurs lumineuses.',
      price: 600,
    ),
    ShopItem(
      id: 'face.retro',
      category: ShopCategory.cardFace,
      name: 'Rétro',
      description: 'Papier crème, double filet et encres anciennes.',
      price: 350,
    ),

    // Dos de cartes.
    ShopItem(
      id: 'back.nova',
      category: ShopCategory.cardBack,
      name: 'Nova',
      description: 'L\'étoile SoliNova.',
    ),
    ShopItem(
      id: 'back.lines',
      category: ShopCategory.cardBack,
      name: 'Rayures',
      description: 'Fines diagonales.',
      price: 150,
    ),
    ShopItem(
      id: 'back.dots',
      category: ShopCategory.cardBack,
      name: 'Pois',
      description: 'Trame de points réguliers.',
      price: 150,
    ),
    ShopItem(
      id: 'back.waves',
      category: ShopCategory.cardBack,
      name: 'Vagues',
      description: 'Ondulations concentriques.',
      price: 250,
    ),
    ShopItem(
      id: 'back.geo',
      category: ShopCategory.cardBack,
      name: 'Losanges',
      description: 'Motif géométrique en losanges.',
      price: 300,
    ),
    ShopItem(
      id: 'back.gold',
      category: ShopCategory.cardBack,
      name: 'Or',
      description: 'Noir profond et filets dorés.',
      price: 600,
    ),

    // Dos saisonniers.
    ShopItem(
      id: 'back.blossom',
      category: ShopCategory.cardBack,
      name: 'Cerisier',
      description: 'Fleurs de cerisier sur fond rose.',
      price: 300,
    ),
    ShopItem(
      id: 'back.sun',
      category: ShopCategory.cardBack,
      name: 'Soleil',
      description: 'Soleils dorés sur bleu lagon.',
      price: 300,
    ),
    ShopItem(
      id: 'back.leaf',
      category: ShopCategory.cardBack,
      name: 'Érable',
      description: 'Feuilles d\'automne orangées.',
      price: 300,
    ),
    ShopItem(
      id: 'back.snowflake',
      category: ShopCategory.cardBack,
      name: 'Flocons',
      description: 'Flocons blancs sur bleu d\'hiver.',
      price: 300,
    ),
    ShopItem(
      id: 'back.tree',
      category: ShopCategory.cardBack,
      name: 'Sapin',
      description: 'Sapins dorés sur rouge de Noël.',
      price: 300,
    ),
    ShopItem(
      id: 'back.pumpkin',
      category: ShopCategory.cardBack,
      name: 'Citrouille',
      description: 'Citrouilles orange dans la nuit.',
      price: 300,
    ),
    ShopItem(
      id: 'back.heart',
      category: ShopCategory.cardBack,
      name: 'Cœurs',
      description: 'Cœurs tendres sur fond rose.',
      price: 300,
    ),
    ShopItem(
      id: 'back.egg',
      category: ShopCategory.cardBack,
      name: 'Œufs',
      description: 'Œufs décorés sur bleu pastel.',
      price: 300,
    ),

    // Animations de déplacement.
    ShopItem(
      id: 'anim.smooth',
      category: ShopCategory.animation,
      name: 'Fluide',
      description: 'Glissement doux et naturel.',
    ),
    ShopItem(
      id: 'anim.snappy',
      category: ShopCategory.animation,
      name: 'Vif',
      description: 'Déplacements rapides et nets.',
      price: 150,
    ),
    ShopItem(
      id: 'anim.bouncy',
      category: ShopCategory.animation,
      name: 'Rebond',
      description: 'Arrivée avec un léger rebond.',
      price: 250,
    ),
    ShopItem(
      id: 'anim.float',
      category: ShopCategory.animation,
      name: 'Aérien',
      description: 'Les cartes s\'élèvent pendant le trajet.',
      price: 250,
    ),

    // Animations de victoire.
    ShopItem(
      id: 'win.cascade',
      category: ShopCategory.victory,
      name: 'Cascade',
      description: 'Les cartes s\'envolent des fondations.',
    ),
    ShopItem(
      id: 'win.confetti',
      category: ShopCategory.victory,
      name: 'Confettis',
      description: 'Pluie de confettis aux couleurs du thème.',
      price: 300,
    ),
    ShopItem(
      id: 'win.stars',
      category: ShopCategory.victory,
      name: 'Étoiles',
      description: 'Des étoiles filantes traversent l\'écran.',
      price: 400,
    ),
    ShopItem(
      id: 'win.fireworks',
      category: ShopCategory.victory,
      name: 'Feux d\'artifice',
      description: 'Gerbes lumineuses pour célébrer.',
      price: 500,
    ),

    // Effets visuels.
    ShopItem(
      id: 'fx.none',
      category: ShopCategory.effect,
      name: 'Aucun',
      description: 'Sobriété totale.',
    ),
    ShopItem(
      id: 'fx.glow',
      category: ShopCategory.effect,
      name: 'Halo',
      description: 'Halo lumineux autour des cartes saisies.',
      price: 200,
    ),
    ShopItem(
      id: 'fx.sparkle',
      category: ShopCategory.effect,
      name: 'Étincelles',
      description: 'Éclat discret à chaque carte en fondation.',
      price: 300,
    ),
  ];

  static final Map<String, ShopItem> _byId = {for (final i in items) i.id: i};

  static ShopItem? byId(String id) => _byId[id];

  static List<ShopItem> ofCategory(ShopCategory c) =>
      items.where((i) => i.category == c).toList();

  /// Élément équipé par défaut pour chaque catégorie.
  static const Map<ShopCategory, String?> defaults = {
    ShopCategory.theme: 'theme.emerald',
    ShopCategory.table: null,
    ShopCategory.cardFace: 'face.classic',
    ShopCategory.cardBack: null,
    ShopCategory.animation: 'anim.smooth',
    ShopCategory.victory: 'win.cascade',
    ShopCategory.effect: 'fx.none',
  };
}
