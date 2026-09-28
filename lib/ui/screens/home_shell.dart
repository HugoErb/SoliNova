import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../../meta/daily/daily_challenge.dart';
import '../game/game_screen.dart';
import '../widgets/common.dart';
import 'challenges_screen.dart';
import 'more_screen.dart';
import 'new_game_sheet.dart';
import 'progress_screen.dart';
import 'shop_screen.dart';

/// Coque principale : cinq destinations dans une barre inférieure.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  void goTo(int tab) => setState(() => _tab = tab);

  static const _items = [
    (Icons.style_rounded, Icons.style_outlined, 'Jouer'),
    (Icons.today_rounded, Icons.today_outlined, 'Défis'),
    (Icons.insights_rounded, Icons.insights_outlined, 'Progrès'),
    (Icons.storefront_rounded, Icons.storefront_outlined, 'Boutique'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'Plus'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = <Widget>[
      PlayTab(onOpenTab: goTo),
      const ChallengesTab(),
      const ProgressTab(),
      const ShopTab(),
      const MoreTab(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: TableBackground()),
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.015),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primary.withValues(alpha: 0.18),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: scheme.onSurface,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: _tab,
          onDestinationSelected: goTo,
          destinations: [
            for (final (sel, icon, label) in _items)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(sel),
                label: label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Accueil : reprise, nouvelle partie, défis du jour, accès rapides.
class PlayTab extends ConsumerWidget {
  const PlayTab({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final session = game.session;
    final resumable = session != null && game.report == null;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DailyChallengeGenerator.forDay(now);
    final date = DailyChallengeGenerator.dateKey(now);
    final dailies = ref.watch(profileProvider.select((p) => p.dailies));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Row(children: [_LevelRing(), Spacer(), PointsChip()]),
        const SizedBox(height: 28),
        Row(
          children: [
            NovaStar(size: 40, color: scheme.primary),
            const SizedBox(width: 12),
            Text(
              'SoliNova',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: scheme.onSurface,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (resumable) ...[
          Panel(
            onTap: () => Navigator.of(context).push(GameScreen.route()),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continuer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.challengeId != null ? 'Défi du jour, ' : ''}'
                        '${session.mode.fullName}\n'
                        '${session.moveCount} coups en '
                        '${formatDuration(ref.read(gameProvider.notifier).elapsed.value)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        resumable
            ? SecondaryButton(
                label: 'Nouvelle partie',
                icon: Icons.add_rounded,
                onPressed: () => showNewGameSheet(context, ref),
              )
            : PrimaryButton(
                label: 'Nouvelle partie',
                icon: Icons.add_rounded,
                onPressed: () => showNewGameSheet(context, ref),
              ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Défis du jour',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => onOpenTab(1),
              child: const Text('Tout voir'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final mode in GameMode.values)
                ListTile(
                  onTap: () {
                    ref.read(challengeModeProvider.notifier).select(mode);
                    onOpenTab(1);
                  },
                  title: Text(
                    mode.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${dailies.succeededOn(date, mode)} / 3 réussis',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in today)
                        if (c.mode == mode)
                          _StatusDot(status: dailies.of(c.id).status),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _QuickLinks(onOpenTab: onOpenTab),
      ],
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final links = [
      (
        Icons.bar_chart_rounded,
        'Statistiques',
        () => Navigator.of(context).push(StatisticsScreen.route()),
      ),
      (
        Icons.palette_rounded,
        'Thèmes',
        () => Navigator.of(context).push(ShopScreen.route(themesOnly: true)),
      ),
      (
        Icons.menu_book_rounded,
        'Règles',
        () => Navigator.of(context).push(rulesRoute()),
      ),
      (
        Icons.tune_rounded,
        'Paramètres',
        () => Navigator.of(context).push(settingsRoute()),
      ),
    ];
    return Row(
      children: [
        for (final (icon, label, onTap) in links)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.onSurface),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Pastille d'état d'un défi.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final ChallengeStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      ChallengeStatus.succeeded => Icon(
        Icons.check_circle_rounded,
        color: scheme.primary,
        semanticLabel: 'Réussi',
      ),
      ChallengeStatus.inProgress => Icon(
        Icons.timelapse_rounded,
        color: scheme.onSurface,
        semanticLabel: 'En cours',
      ),
      ChallengeStatus.notStarted => Icon(
        Icons.radio_button_unchecked_rounded,
        color: scheme.onSurfaceVariant,
        semanticLabel: 'À faire',
      ),
    };
  }
}

/// Anneau de niveau.
class _LevelRing extends ConsumerWidget {
  const _LevelRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = ref.watch(profileProvider.select((p) => p.progress));
    final info = xp.levelInfo;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Niveau ${info.level}, ${info.xpIntoLevel} XP sur ${info.xpForNextLevel}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: info.progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                painter: _RingPainter(
                  v,
                  scheme.primary,
                  scheme.onSurface.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    '${info.level}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Niveau',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${info.xpIntoLevel} / ${info.xpForNextLevel} XP',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track);

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
