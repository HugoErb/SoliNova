import 'dart:math' as math;

import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../cards/seasonal_motifs.dart';
import '../cards/suit_paths.dart';
import '../theme/nova_theme.dart';

/// Durée au format « 3:05 » ou « 1:02:05 ».
String formatDuration(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Durée longue lisible : « 3 h 12 min ».
String formatLongDuration(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 1) return '${ms ~/ 1000} s';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Nombre avec espace fine insécable entre les milliers (usage français).
String formatNumber(int n) {
  final neg = n < 0;
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

String formatPercent(double v) => '${(v * 100).round()} %';

/// Tapis de jeu : dégradé radial et motif discret, animé pour Aurore.
class TableBackground extends ConsumerStatefulWidget {
  const TableBackground({super.key});

  @override
  ConsumerState<TableBackground> createState() => _TableBackgroundState();
}

class _TableBackgroundState extends ConsumerState<TableBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = ref.watch(lookProvider);
    final animated = look.theme.animatedTable && look.animationsEnabled;
    if (animated && !_c.isAnimating) {
      _c.repeat();
    } else if (!animated && _c.isAnimating) {
      _c.stop();
    }
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: AnimatedBuilder(
          key: ValueKey(look.table),
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _TablePainter(
              look.table,
              animated ? _c.value : null,
              look.theme.accent,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.style, this.phase, this.accent);

  final TableStyle style;
  final double? phase;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var center = const Alignment(0, -0.35);
    if (phase != null) {
      final a = phase! * math.pi * 2;
      center = Alignment(math.sin(a) * 0.5, -0.3 + math.cos(a) * 0.3);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: center,
          radius: 1.25,
          colors: [style.center, style.edge],
        ).createShader(rect),
    );
    if (phase != null) {
      final a = phase! * math.pi * 2;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(math.cos(a) * 0.7, 0.6 + math.sin(a) * 0.2),
            radius: 0.9,
            colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }
    final ink = Paint()
      ..color = (style.center.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white)
          .withValues(alpha: style.patternOpacity);
    switch (style.pattern) {
      case TablePattern.none:
        break;
      case TablePattern.grain:
        final rnd = math.Random(3);
        final count = (size.width * size.height / 90).round();
        canvas.drawPoints(
          PointMode.points,
          [
            for (var i = 0; i < count; i++)
              Offset(
                rnd.nextDouble() * size.width,
                rnd.nextDouble() * size.height,
              ),
          ],
          ink
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round,
        );
      case TablePattern.dots:
        const step = 22.0;
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1.1, ink);
          }
        }
      case TablePattern.lines:
        ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (var y = 0.0; y < size.height; y += 7) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y + 3), ink);
        }
      case TablePattern.vignette:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              radius: 1.1,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: style.patternOpacity),
              ],
            ).createShader(rect),
        );
    }
    final motif = style.motif;
    if (motif != null) _paintMotifs(canvas, size, motif);
  }

  /// Symboles semés en quinconce avec un léger décalage pseudo-aléatoire
  /// (fixe, pour que le tapis ne change pas d'un affichage à l'autre).
  void _paintMotifs(Canvas canvas, Size size, Motif motif) {
    final paint = Paint()
      ..color = (style.center.computeLuminance() > 0.5
              ? Colors.black
              : Colors.white)
          .withValues(alpha: style.motifOpacity);
    final rnd = math.Random(7);
    const step = 96.0;
    const side = 26.0;
    var row = 0;
    for (var y = step * 0.4; y < size.height + step; y += step * 0.75, row++) {
      for (var x = row.isEven ? step * 0.3 : step * 0.8;
          x < size.width + step;
          x += step) {
        final center = Offset(
          x + (rnd.nextDouble() - 0.5) * step * 0.3,
          y + (rnd.nextDouble() - 0.5) * step * 0.3,
        );
        final s = side * (0.8 + rnd.nextDouble() * 0.4);
        canvas.drawPath(
          MotifPaths.inRect(
            motif,
            Rect.fromCenter(center: center, width: s, height: s),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) =>
      old.style != style || old.phase != phase || old.accent != accent;
}

/// Logo SoliNova : étoile Nova à quatre branches.
class NovaStar extends StatelessWidget {
  const NovaStar({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(c),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      SuitPaths.star(c, size.width / 2, waist: 0.2),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// Surface translucide posée sur le tapis.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Bouton principal plein.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(64, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Bouton secondaire discret.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surfaceContainerHighest,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// En-tête de page simple avec retour.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Retour',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Page standard : tapis + en-tête + contenu défilant verticalement.
class NovaPage extends StatelessWidget {
  const NovaPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: TableBackground()),
          SafeArea(
            child: Column(
              children: [
                PageHeader(title: title, trailing: trailing),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre de section dans une page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

/// Barre de progression arrondie.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 8, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.onSurface.withValues(alpha: 0.1)),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color ?? scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille de points (monnaie de la boutique).
class PointsChip extends ConsumerWidget {
  const PointsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(profileProvider.select((p) => p.wallet.balance));
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${formatNumber(balance)} points',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NovaStar(size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: Text(
                formatNumber(balance),
                key: ValueKey(balance),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
