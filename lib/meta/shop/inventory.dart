import '../economy/wallet.dart';
import '../json.dart';
import 'shop_item.dart';

enum PurchaseOutcome { success, alreadyOwned, insufficientFunds, unknownItem }

/// Éléments possédés et équipés.
final class Inventory {
  const Inventory({this.owned = const {}, this.equipped = const {}});

  /// Éléments payants achetés (les gratuits sont possédés d'office).
  final Set<String> owned;

  /// Élément équipé par catégorie ; absent = valeur par défaut.
  final Map<ShopCategory, String?> equipped;

  bool owns(String id) {
    final item = ShopCatalog.byId(id);
    return item != null && (item.isFree || owned.contains(id));
  }

  String? equippedIn(ShopCategory category) =>
      equipped.containsKey(category)
          ? equipped[category]
          : ShopCatalog.defaults[category];

  bool isEquipped(String id) {
    final item = ShopCatalog.byId(id);
    return item != null && equippedIn(item.category) == id;
  }

  /// Achat définitif : débite le porte-monnaie et ajoute l'élément.
  (Inventory, Wallet, PurchaseOutcome) purchase(String id, Wallet wallet) {
    final item = ShopCatalog.byId(id);
    if (item == null) return (this, wallet, PurchaseOutcome.unknownItem);
    if (owns(id)) return (this, wallet, PurchaseOutcome.alreadyOwned);
    if (!wallet.canAfford(item.price)) {
      return (this, wallet, PurchaseOutcome.insufficientFunds);
    }
    return (
      Inventory(owned: {...owned, id}, equipped: equipped),
      wallet.debit(item.price),
      PurchaseOutcome.success,
    );
  }

  /// Équipe un élément possédé. Équiper un thème remet le tapis et le dos
  /// de cartes « selon le thème » pour profiter de l'ambiance complète.
  Inventory equip(String id) {
    final item = ShopCatalog.byId(id);
    if (item == null || !owns(id)) return this;
    final next = {...equipped, item.category: id};
    if (item.category == ShopCategory.theme) {
      next[ShopCategory.table] = null;
      next[ShopCategory.cardBack] = null;
    }
    return Inventory(owned: owned, equipped: next);
  }

  /// Revient à l'élément fourni par le thème (tapis, dos).
  Inventory followTheme(ShopCategory category) {
    if (!category.followsTheme) return this;
    return Inventory(owned: owned, equipped: {...equipped, category: null});
  }

  /// Ajoute un élément offert (récompense de succès).
  Inventory grant(String id) =>
      ShopCatalog.byId(id) == null || owns(id)
          ? this
          : Inventory(owned: {...owned, id}, equipped: equipped);

  Json toJson() => {
    'owned': owned.toList()..sort(),
    'equipped': {for (final e in equipped.entries) e.key.name: e.value},
  };

  static Inventory fromJson(Json j) {
    final equipped = <ShopCategory, String?>{};
    readMap(j, 'equipped').forEach((key, value) {
      final cat = ShopCategory.values.where((c) => c.name == key).firstOrNull;
      if (cat == null) return;
      if (value == null) {
        if (cat.followsTheme) equipped[cat] = null;
      } else if (value is String && ShopCatalog.byId(value) != null) {
        equipped[cat] = value;
      }
    });
    final owned = {
      for (final v in readList(j, 'owned'))
        if (v is String && ShopCatalog.byId(v) != null) v,
    };
    final inv = Inventory(owned: owned, equipped: equipped);
    // Sécurité : on ne garde équipé que ce qui est possédé.
    final safe = {
      for (final e in equipped.entries)
        if (e.value == null || inv.owns(e.value!)) e.key: e.value,
    };
    return Inventory(owned: owned, equipped: safe);
  }
}
