import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solinova/engine/model/suit.dart';
import 'package:solinova/meta/shop/shop_item.dart';
import 'package:solinova/ui/cards/card_painter.dart';
import 'package:solinova/ui/cards/seasonal_motifs.dart';
import 'package:solinova/ui/theme/look.dart';
import 'package:solinova/ui/theme/nova_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('chaque article visuel de la boutique a un rendu', () {
    for (final item in ShopCatalog.items) {
      switch (item.category) {
        case ShopCategory.theme:
          expect(ThemeCatalog.byId(item.id).id, item.id, reason: item.id);
        case ShopCategory.table:
          expect(ThemeCatalog.tables, contains(item.id));
        case ShopCategory.cardBack:
          expect(ThemeCatalog.backs, contains(item.id));
        case ShopCategory.cardFace:
          expect(FaceStyle.fromShopId(item.id).shopId, item.id);
        case ShopCategory.animation ||
            ShopCategory.victory ||
            ShopCategory.effect:
          break;
      }
    }
  });

  test('chaque style de face est vendu en boutique', () {
    for (final f in FaceStyle.values) {
      expect(ShopCatalog.byId(f.shopId), isNotNull, reason: f.shopId);
    }
  });

  test('nouveaux styles de face : encre lisible sur le fond', () {
    const own = [
      FaceStyle.solid,
      FaceStyle.solidFour,
      FaceStyle.colored,
      FaceStyle.neon,
      FaceStyle.retro,
    ];
    for (final theme in ThemeCatalog.all) {
      for (final style in own) {
        for (final suit in Suit.values) {
          final c = faceColors(suit, theme.face, style);
          expect(
            contrast(c.ink, c.paper),
            greaterThanOrEqualTo(4.5),
            reason: '${style.name} ${suit.name}',
          );
        }
      }
    }
  });

  test('thèmes saisonniers : faces classiques lisibles', () {
    const seasonal = [
      'theme.spring',
      'theme.summer',
      'theme.autumn',
      'theme.winter',
      'theme.christmas',
      'theme.halloween',
      'theme.valentine',
      'theme.easter',
    ];
    for (final id in seasonal) {
      final face = ThemeCatalog.byId(id).face;
      for (final suit in Suit.values) {
        final c = faceColors(suit, face, FaceStyle.classic);
        expect(contrast(c.ink, c.paper), greaterThanOrEqualTo(4.5), reason: id);
      }
    }
  });

  test('les motifs tiennent dans leur carré', () {
    for (final m in Motif.values) {
      final b = MotifPaths.inRect(m, const Rect.fromLTWH(0, 0, 100, 100))
          .getBounds();
      expect(b.isEmpty, isFalse, reason: m.name);
      expect(
        const Rect.fromLTWH(-1, -1, 102, 102).contains(b.topLeft) &&
            const Rect.fromLTWH(-1, -1, 102, 102).contains(b.bottomRight),
        isTrue,
        reason: '${m.name} $b',
      );
    }
  });
}
