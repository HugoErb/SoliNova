import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../../meta/achievements/achievements.dart';
import '../widgets/common.dart';

/// Progression : niveau, badges, succès et objectifs.
class ProgressTab extends ConsumerWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final info = profile.progress.levelInfo;
    final scheme = Theme.of(context).colorScheme;
    final ctx = AchievementContext(
      stats: profile.stats,
      progress: profile.progress,
      dailies: profile.dailies,
      inventory: profile.inventory,
    );
    final unlocked = profile.achievements;
    final all = AchievementCatalog.all;
    final pending = all.where((a) => !unlocked.containsKey(a.id)).toList()
      ..sort((a, b) {
        final pa = a.progressOf(ctx) / a.target;
        final pb = b.progressOf(ctx) / b.target;
        return pb.compareTo(pa);
      });
    final done = all.where((a) => unlocked.containsKey(a.id)).toList();

    int count(BadgeTier t) => done.where((a) => a.tier == t).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text(
            'Progrès',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Niveau ${info.level}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                  ),
                  const Spacer(),
                  Text(
                    '${formatNumber(profile.progress.totalXp)} XP au total',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProgressBar(value: info.progress, height: 10),
              const SizedBox(height: 8),
              Text(
                'Encore ${info.xpForNextLevel - info.xpIntoLevel} XP pour le niveau ${info.level + 1}.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final t in BadgeTier.values) ...[
              Expanded(
                child: Panel(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      _TierMedal(tier: t, size: 30),
                      const SizedBox(height: 6),
                      Text(
                        '${count(t)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      Text(t.label, style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              if (t != BadgeTier.gold) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: 'Statistiques détaillées',
          icon: Icons.bar_chart_rounded,
          onPressed: () => Navigator.of(context).push(StatisticsScreen.route()),
        ),
        SectionTitle('Objectifs en cours (${pending.length})'),
        for (final a in pending) _AchievementTile(achievement: a, ctx: ctx),
        SectionTitle('Succès débloqués (${done.length} / ${all.length})'),
        if (done.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Gagne ta première partie pour débloquer un succès.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final a in done)
          _AchievementTile(achievement: a, ctx: ctx, unlockedAt: unlocked[a.id]),
      ],
    );
  }
}

class _TierMedal extends StatelessWidget {
  const _TierMedal({required this.tier, this.size = 26, this.dim = false});

  final BadgeTier tier;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      BadgeTier.bronze => const Color(0xFFD08A57),
      BadgeTier.silver => const Color(0xFFC9D1DB),
      BadgeTier.gold => const Color(0xFFE8C063),
    };
    return Icon(
      Icons.workspace_premium_rounded,
      size: size,
      color: dim ? color.withValues(alpha: 0.35) : color,
      semanticLabel: 'Badge ${tier.label}',
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.ctx,
    this.unlockedAt,
  });

  final Achievement achievement;
  final AchievementContext ctx;
  final DateTime? unlockedAt;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final scheme = Theme.of(context).colorScheme;
    final unlocked = unlockedAt != null;
    final value = unlocked ? a.target : a.progressOf(ctx);
    final rewards = [
      if (a.rewardXp > 0) '${a.rewardXp} XP',
      if (a.rewardPoints > 0) '${a.rewardPoints} points',
      if (a.rewardItem != null) 'un objet cosmétique',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TierMedal(tier: a.tier, dim: !unlocked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(a.description, style: TextStyle(color: scheme.onSurfaceVariant)),
                  if (!unlocked && a.target > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: ProgressBar(value: value / a.target, height: 6)),
                        const SizedBox(width: 10),
                        Text(
                          '$value / ${a.target}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (rewards.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      unlocked ? 'Obtenu : ${rewards.join(', ')}' : 'Récompense : ${rewards.join(', ')}',
                      style: TextStyle(color: scheme.primary, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
            if (unlocked) Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Statistiques globales et par mode.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => const StatisticsScreen(),
  );

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  GameMode? _mode;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final stats = profile.stats;
    final s = _mode == null ? stats.global : stats.of(_mode!);
    final scheme = Theme.of(context).colorScheme;
    String orDash(int? v, String Function(int) f) => v == null ? '—' : f(v);

    final main = <(String, String)>[
      ('Parties :', '${s.games}'),
      ('Gagnées :', '${s.wins}'),
      ('Taux de victoire :', s.games == 0 ? '—' : formatPercent(s.winRate)),
      ('Meilleur score :', orDash(s.bestScore, formatNumber)),
      ('Score moyen :', orDash(s.averageScore, formatNumber)),
      ('Temps le plus court :', orDash(s.bestTimeMs, formatDuration)),
      ('Temps moyen :', orDash(s.averageTimeMs, formatDuration)),
      ('Moins de coups :', orDash(s.fewestMoves, (v) => '$v')),
      ('Coups moyens :', orDash(s.averageMoves, (v) => '$v')),
      ('Série actuelle :', '${s.currentStreak}'),
      ('Plus longue série :', '${s.longestStreak}'),
    ];
    final extra = <(String, String)>[
      ('Temps total joué :', formatLongDuration(s.timePlayedMs)),
      ('Total de coups :', formatNumber(s.totalMoves)),
      ('Indices utilisés :', '${s.hintsUsed}'),
      ('Annulations :', '${s.undosUsed}'),
      if (_mode == null) ...[
        ('Défis terminés :', '${stats.challengesFinished}'),
        ('Défis réussis :', '${stats.challengesSucceeded}'),
        ('Points gagnés :', formatNumber(stats.pointsEarned)),
        ('XP totale :', formatNumber(profile.progress.totalXp)),
        ('Niveau actuel :', '${profile.progress.level}'),
      ],
    ];

    Widget table(List<(String, String)> rows) => Panel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return NovaPage(
      title: 'Statistiques',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tous les modes'),
              selected: _mode == null,
              onSelected: (_) => setState(() => _mode = null),
            ),
            for (final m in GameMode.values)
              ChoiceChip(
                label: Text(m.fullName),
                selected: _mode == m,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(_mode),
            children: [
              table(main),
              const SizedBox(height: 12),
              table(extra),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Score, temps et coups sont calculés sur les parties gagnées. '
          'Une partie compte dès le premier coup joué ; abandonnée, elle '
          'compte comme une défaite.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
      ],
    );
  }
}
