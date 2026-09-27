import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../engine/model/card.dart' as model;
import '../../engine/model/rank.dart';
import '../../engine/model/suit.dart';
import '../../meta/shop/inventory.dart';
import '../../meta/shop/shop_item.dart';
import '../cards/card_painter.dart';
import '../cards/suit_paths.dart';
import '../theme/look.dart';
import '../theme/nova_theme.dart';
import '../widgets/common.dart';

/// Onglet Boutique (dans la navigation principale).
class ShopTab extends StatelessWidget {
  const ShopTab({super.key});

  @override
  Widget build(BuildContext context) => const _ShopBody(inTab: true);
}

/// Boutique en page autonome (ex. accès direct aux thèmes).
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, this.category});

  /// Catégorie ouverte d'emblée (ex. thèmes depuis l'accueil).
  final ShopCategory? category;

  static Route<void> route({bool themesOnly = false, ShopCategory? category}) =>
      MaterialPageRoute<void>(
        builder: (_) => ShopScreen(
          category: themesOnly ? ShopCategory.theme : category,
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: TableBackground()),
        SafeArea(
          child: _ShopBody(
            inTab: false,
            initial: category,
          ),
        ),
      ],
    ),
  );
}

class _ShopBody extends ConsumerStatefulWidget {
  const _ShopBody({required this.inTab, this.initial});

  final bool inTab;
  final ShopCategory? initial;

  @override
  ConsumerState<_ShopBody> createState() => _ShopBodyState();
}

class _ShopBodyState extends ConsumerState<_ShopBody> {
  late ShopCategory _category = widget.initial ?? ShopCategory.theme;

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(profileProvider.select((p) => p.inventory));
    final scheme = Theme.of(context).colorScheme;
    final items = ShopCatalog.ofCategory(_category);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 340 ? 1 : 2;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(widget.inTab ? 20 : 8, 12, 16, 4),
            child: Row(
              children: [
                if (!widget.inTab)
                  IconButton(
                    tooltip: 'Retour',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Text(
                    _category == ShopCategory.theme && !widget.inTab
                        ? 'Thèmes'
                        : 'Boutique',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
                const PointsChip(),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Uniquement des éléments cosmétiques, achetés avec les points '
              'gagnés en jouant. Aucun paiement réel.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ShopCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Text(
              _category.description,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        if (_category.followsTheme)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Panel(
                onTap: () =>
                    ref.read(profileProvider.notifier).followTheme(_category),
                child: Row(
                  children: [
                    Icon(
                      inventory.equippedIn(_category) == null
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Selon le thème',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 1.6 : 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ItemTile(item: items[i], inventory: inventory),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.inventory});

  final ShopItem item;
  final Inventory inventory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final owned = inventory.owns(item.id);
    final equipped = inventory.isEquipped(item.id);
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => showItemSheet(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ItemPreview(item: item)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (equipped) ...[
                      Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text('Équipé', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                    ] else if (owned)
                      Text(
                        item.isFree ? 'Gratuit' : 'Débloqué',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                      )
                    else ...[
                      Icon(Icons.lock_rounded, size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      NovaStar(size: 12, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        formatNumber(item.price),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fiche d'un élément : aperçu, description, achat, équipement.
Future<void> showItemSheet(BuildContext context, ShopItem item) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemSheet(item: item),
    );

class _ItemSheet extends ConsumerWidget {
  const _ItemSheet({required this.item});

  final ShopItem item;

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final wallet = ref.read(profileProvider).wallet;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Acheter « ${item.name} » ?'),
        content: Text(
          'Coût : ${formatNumber(item.price)} points. Il te restera '
          '${formatNumber(wallet.balance - item.price)} points. '
          'L\'achat est définitif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final (outcome, unlocked) = ref.read(profileProvider.notifier).purchase(item.id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = switch (outcome) {
      PurchaseOutcome.success => '« ${item.name} » débloqué.',
      PurchaseOutcome.alreadyOwned => 'Tu possèdes déjà cet élément.',
      PurchaseOutcome.insufficientFunds => 'Pas assez de points.',
      PurchaseOutcome.unknownItem => 'Élément introuvable.',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
    for (final a in unlocked) {
      messenger.showSnackBar(
        SnackBar(content: Text('Succès débloqué : ${a.title}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final inventory = profile.inventory;
    final owned = inventory.owns(item.id);
    final equipped = inventory.isEquipped(item.id);
    final canAfford = profile.wallet.canAfford(item.price);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: math.min(240, MediaQuery.sizeOf(context).height * 0.3),
                child: ItemPreview(item: item, large: true),
              ),
            ),
            const SizedBox(height: 16),
            Text(item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(item.category.label, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(item.description, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15)),
            const SizedBox(height: 20),
            if (equipped)
              const SecondaryButton(label: 'Équipé', icon: Icons.check_rounded, onPressed: null)
            else if (owned)
              PrimaryButton(
                label: item.category == ShopCategory.theme ? 'Activer' : 'Équiper',
                icon: Icons.check_rounded,
                onPressed: () {
                  ref.read(profileProvider.notifier).equip(item.id);
                  Navigator.pop(context);
                },
              )
            else ...[
              PrimaryButton(
                label: 'Acheter pour ${formatNumber(item.price)} points',
                icon: Icons.lock_open_rounded,
                onPressed: canAfford ? () => unawaited(_buy(context, ref)) : null,
              ),
              if (!canAfford) ...[
                const SizedBox(height: 8),
                Text(
                  'Il te manque ${formatNumber(item.price - profile.wallet.balance)} points. '
                  'Gagne des parties et réussis des défis pour en obtenir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Aperçu visuel d'un élément de boutique.
class ItemPreview extends ConsumerWidget {
  const ItemPreview({super.key, required this.item, this.large = false});

  final ShopItem item;
  final bool large;

  static const _queen = model.Card(id: -1, suit: Suit.hearts, rank: Rank.queen, faceUp: true);
  static const _ten = model.Card(id: -2, suit: Suit.spades, rank: Rank.ten, faceUp: true);
  static const _ace = model.Card(id: -3, suit: Suit.diamonds, rank: Rank.ace, faceUp: true);
  static const _seven = model.Card(id: -4, suit: Suit.clubs, rank: Rank.seven, faceUp: true);
  static const _back = model.Card(id: -5, suit: Suit.spades, rank: Rank.ace);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(lookProvider);
    final look = switch (item.category) {
      ShopCategory.theme => current.copyWith(
        theme: ThemeCatalog.byId(item.id),
        table: ThemeCatalog.byId(item.id).table,
        back: ThemeCatalog.byId(item.id).back,
      ),
      ShopCategory.table => current.copyWith(table: ThemeCatalog.tables[item.id]),
      ShopCategory.cardBack => current.copyWith(back: ThemeCatalog.backs[item.id]),
      ShopCategory.cardFace => current.copyWith(
        faceStyle: FaceStyle.fromShopId(item.id),
      ),
      ShopCategory.animation => current.copyWith(
        motion: switch (item.id) {
          'anim.snappy' => MotionStyle.snappy,
          'anim.bouncy' => MotionStyle.bouncy,
          'anim.float' => MotionStyle.floaty,
          _ => MotionStyle.smooth,
        },
      ),
      ShopCategory.effect => current.copyWith(
        effect: switch (item.id) {
          'fx.glow' => EffectStyle.glow,
          'fx.sparkle' => EffectStyle.sparkle,
          _ => EffectStyle.none,
        },
      ),
      ShopCategory.victory => current,
    };

    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final cardW = math.min(c.maxWidth * 0.3, h * 0.62 / 1.42);
        Widget card(model.Card m, {double angle = 0, bool glow = false}) =>
            Transform.rotate(
              angle: angle,
              child: Container(
                width: cardW,
                height: cardW * 1.42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardW * 0.1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3)),
                    if (glow)
                      BoxShadow(color: look.theme.accent.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 1),
                  ],
                ),
                child: CustomPaint(painter: CardPainter(card: m, look: look)),
              ),
            );

        final Widget content = switch (item.category) {
          ShopCategory.theme || ShopCategory.table => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              card(_back, angle: -0.08),
              SizedBox(width: cardW * 0.15),
              card(_queen, angle: 0.06),
            ],
          ),
          ShopCategory.cardFace => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              card(_ten, angle: -0.06),
              SizedBox(width: cardW * 0.08),
              card(large ? _queen : _ace),
              if (large) ...[SizedBox(width: cardW * 0.08), card(_seven, angle: 0.06)],
            ],
          ),
          ShopCategory.cardBack => Center(child: card(_back)),
          ShopCategory.animation => _MotionDemo(look: look, child: card(_queen)),
          ShopCategory.effect => Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                card(_ace, glow: look.effect == EffectStyle.glow),
                if (look.effect == EffectStyle.sparkle)
                  IgnorePointer(child: SparkleBurst(color: look.theme.highlight, size: cardW * 1.6, loop: true)),
              ],
            ),
          ),
          ShopCategory.victory => Center(
            child: Icon(
              switch (item.id) {
                'win.confetti' => Icons.celebration_rounded,
                'win.stars' => Icons.auto_awesome_rounded,
                'win.fireworks' => Icons.flare_rounded,
                _ => Icons.style_rounded,
              },
              size: h * 0.4,
              color: look.theme.accent,
            ),
          ),
        };
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MiniTable(look.table)),
            content,
          ],
        );
      },
    );
  }
}

class _MiniTable extends CustomPainter {
  _MiniTable(this.style);
  final TableStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [style.center, style.edge],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MiniTable old) => old.style != style;
}

/// Démonstration en boucle d'un style de mouvement.
class _MotionDemo extends StatefulWidget {
  const _MotionDemo({required this.look, required this.child});

  final Look look;
  final Widget child;

  @override
  State<_MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<_MotionDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.look.motion.move * 1,
  );
  Timer? _loop;
  bool _right = false;

  @override
  void initState() {
    super.initState();
    _loop = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      _right = !_right;
      unawaited(_c.forward(from: 0));
    });
  }

  @override
  void dispose() {
    _loop?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.look.motion;
    return LayoutBuilder(
      builder: (context, c) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = m.curve.transform(_c.value);
          final span = c.maxWidth * 0.22;
          final from = _right ? -span : span;
          final x = from + (-from - from) * t;
          final lift = math.sin(_c.value * math.pi) * m.lift;
          return Transform.translate(
            offset: Offset(x, -lift * 10),
            child: Transform.scale(scale: 1 + lift * 0.06, child: child),
          );
        },
        child: Center(child: widget.child),
      ),
    );
  }
}

/// Gerbe d'étincelles (effet « Étincelles »).
class SparkleBurst extends StatefulWidget {
  const SparkleBurst({super.key, required this.color, required this.size, this.loop = false});

  final Color color;
  final double size;
  final bool loop;

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.loop) {
      unawaited(_c.repeat());
    } else {
      unawaited(_c.forward());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      size: Size.square(widget.size),
      painter: _SparklePainter(_c.value, widget.color),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fade = 1 - t;
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2 + 0.3;
      final r = size.width * (0.18 + 0.32 * Curves.easeOutCubic.transform(t));
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawPath(
        SuitPaths.star(p, size.width * 0.035 * (0.5 + fade)),
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.t != t;
}
