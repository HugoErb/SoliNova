import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../meta/profile/game_completion.dart';
import '../feedback/feedback_service.dart';
import '../widgets/common.dart';

/// Bilan de victoire : score, temps, coups, XP, points, records, succès,
/// série et défi.
class VictorySheet extends ConsumerStatefulWidget {
  const VictorySheet({super.key, required this.report});

  final GameReport report;

  @override
  ConsumerState<VictorySheet> createState() => _VictorySheetState();
}

class _VictorySheetState extends ConsumerState<VictorySheet>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    final look = ref.read(lookProvider);
    final wait = look.animationsEnabled ? 900 : 0;
    _delay = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      unawaited(_enter.forward());
      unawaited(
        _count.forward().then((_) {
          if (!mounted) return;
          final fx = ref.read(feedbackProvider);
          if (widget.report.levelsGained > 0) fx.emit(FeedbackEvent.levelUp);
          if (widget.report.unlocked.isNotEmpty) {
            fx.emit(FeedbackEvent.achievement);
          }
        }),
      );
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _enter.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final result = r.result;
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(gameProvider.notifier);
    final curve = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => IgnorePointer(
        ignoring: _enter.value < 0.5,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35 * curve.value),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionalTranslation(
              translation: Offset(0, 1 - curve.value),
              child: child,
            ),
          ),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NovaStar(size: 26, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Text(
                      'Victoire',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      result.mode.fullName,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _count,
                  builder: (context, _) {
                    final v = Curves.easeOutCubic.transform(_count.value);
                    return Text(
                      formatNumber((result.score.total * v).round()),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1,
                      ),
                    );
                  },
                ),
                Text(
                  'points de score',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                if (r.records.any) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (r.records.bestScore) const _Badge('Meilleur score'),
                      if (r.records.bestTime) const _Badge('Meilleur temps'),
                      if (r.records.fewestMoves) const _Badge('Moins de coups'),
                      if (r.records.longestStreak) const _Badge('Plus longue série'),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    _Stat('Temps', formatDuration(result.elapsedMs)),
                    _Stat('Coups', '${result.moves}'),
                    _Stat('Série', '${r.streak}'),
                  ],
                ),
                const SizedBox(height: 16),
                _RewardsPanel(report: r, progress: _count),
                if (r.challenge != null) ...[
                  const SizedBox(height: 12),
                  Panel(
                    color: scheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        Icon(
                          r.challengeProgress?.succeeded == true
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: r.challengeProgress?.succeeded == true
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Défi ${r.challenge!.difficulty.label.toLowerCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                r.challengeCompletedNow
                                    ? 'Réussi : +${r.challenge!.rewardXp} XP et +${r.challenge!.rewardPoints} points'
                                    : r.challengeProgress?.succeeded == true
                                    ? 'Déjà réussi aujourd\'hui'
                                    : 'Objectif non atteint : ${r.challenge!.objective.describe().toLowerCase()}',
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final a in r.unlocked) ...[
                  const SizedBox(height: 10),
                  _AchievementRow(title: a.title, subtitle: a.description, tier: a.tier.label),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Nouvelle partie',
                  icon: Icons.add_rounded,
                  onPressed: () => controller.newGame(result.mode),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Rejouer',
                        icon: Icons.replay_rounded,
                        onPressed: controller.replayLast,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Accueil',
                        icon: Icons.home_rounded,
                        onPressed: () {
                          controller.abandon();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        'Nouveau record : ${text.toLowerCase()}',
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    );
  }
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({required this.report, required this.progress});

  final GameReport report;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final before = report.levelBefore;
    final after = report.levelAfter;
    return Panel(
      color: scheme.surfaceContainerHighest,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(progress.value);
          final leveled = after.level > before.level;
          // Barre : part de l'ancienne progression puis se remplit.
          final bar = leveled
              ? (t < 0.5 ? before.progress + (1 - before.progress) * t * 2 : after.progress * (t - 0.5) * 2)
              : before.progress + (after.progress - before.progress) * t;
          final shownLevel = leveled && t >= 0.5 ? after.level : before.level;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Niveau $shownLevel',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  if (leveled && t >= 0.5) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Niveau supérieur',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '+${formatNumber((report.totalXp * t).round())} XP',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: bar),
              const SizedBox(height: 12),
              Row(
                children: [
                  NovaStar(size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '+${formatNumber((report.totalPoints * t).round())} points',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (report.levelUpPoints > 0)
                    Text(
                      'dont ${report.levelUpPoints} de niveau',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.title, required this.subtitle, required this.tier});

  final String title;
  final String subtitle;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      color: scheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: scheme.primary, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Succès débloqué : $title', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(tier, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
