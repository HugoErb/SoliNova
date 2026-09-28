import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../../meta/daily/daily_challenge.dart';
import '../widgets/common.dart';
import 'new_game_sheet.dart';

const _weekdays = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _dayLabel(DateTime d, DateTime today) {
  final diff = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Hier';
  final label = '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  return label[0].toUpperCase() + label.substring(1);
}

/// Mode affiché dans l'onglet Défis (choisi aussi depuis l'accueil).
final challengeModeProvider =
    NotifierProvider<ChallengeModeController, GameMode?>(
      ChallengeModeController.new,
    );

class ChallengeModeController extends Notifier<GameMode?> {
  /// Null : premier mode dont un défi reste à réussir.
  @override
  GameMode? build() => null;

  void select(GameMode mode) => state = mode;
}

/// Défis quotidiens : trois défis par mode et par jour, générés localement.
class ChallengesTab extends ConsumerWidget {
  const ChallengesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final log = ref.watch(profileProvider.select((p) => p.dailies));
    final scheme = Theme.of(context).colorScheme;
    final date = DailyChallengeGenerator.dateKey(now);
    int doneIn(GameMode m) => log.succeededOn(date, m);
    final mode =
        ref.watch(challengeModeProvider) ??
        GameMode.values.firstWhere(
          (m) => doneIn(m) < 3,
          orElse: () => GameMode.values.first,
        );
    final today = DailyChallengeGenerator.forDayAndMode(now, mode);
    final total = GameMode.values.length * ChallengeDifficulty.values.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Défis du jour',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${log.succeededOn(date)} / $total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Trois défis par mode, les mêmes donnes toute la journée. '
            'Tentatives illimitées, récompense versée à la première réussite.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in GameMode.values)
              ChoiceChip(
                label: Text('${m.fullName}  ${doneIn(m)}/3'),
                avatar: doneIn(m) == 3
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : null,
                selected: m == mode,
                onSelected: (_) =>
                    ref.read(challengeModeProvider.notifier).select(m),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(mode),
            children: [
              for (final c in today) ...[
                _ChallengeCard(challenge: c, progress: log.of(c.id)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SectionTitle('Historique récent'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 1; i <= 7; i++)
                _HistoryRow(
                  day: now.subtract(Duration(days: i)),
                  today: now,
                  log: log,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge, required this.progress});

  final DailyChallenge challenge;
  final ChallengeProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = challenge;
    final status = progress.status;
    final (statusText, statusColor) = switch (status) {
      ChallengeStatus.succeeded => ('Réussi', scheme.primary),
      ChallengeStatus.inProgress => (
        '${progress.attempts} tentative${progress.attempts > 1 ? 's' : ''}',
        scheme.onSurface,
      ),
      ChallengeStatus.notStarted => ('À faire', scheme.onSurfaceVariant),
    };
    final dots = switch (c.difficulty) {
      ChallengeDifficulty.easy => 1,
      ChallengeDifficulty.medium => 2,
      ChallengeDifficulty.hard => 3,
    };

    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.circle,
                    size: 9,
                    color: i < dots
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                c.difficulty.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            c.mode.fullName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            c.objective.describe(),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: scheme.primary),
              Text(
                ' ${c.rewardXp} XP',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 14),
              NovaStar(size: 13, color: scheme.primary),
              Text(
                ' ${c.rewardPoints} points',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (progress.bestTimeMs != null)
                Text(
                  'Meilleur temps ${formatDuration(progress.bestTimeMs!)}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          status == ChallengeStatus.succeeded
              ? SecondaryButton(
                  label: 'Rejouer',
                  icon: Icons.replay_rounded,
                  onPressed: () => _play(context, ref),
                )
              : PrimaryButton(
                  label: status == ChallengeStatus.inProgress
                      ? 'Réessayer'
                      : 'Jouer',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => _play(context, ref),
                ),
        ],
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) => startGame(
    context,
    ref,
    () => ref.read(gameProvider.notifier).startChallenge(challenge),
  );
}

/// Une journée passée : défis réussis par mode (trois pastilles par mode).
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.day,
    required this.today,
    required this.log,
  });

  final DateTime day;
  final DateTime today;
  final DailyChallengeLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = DailyChallengeGenerator.dateKey(day);
    final total = GameMode.values.length * ChallengeDifficulty.values.length;
    final succeeded = log.succeededOn(date);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dayLabel(day, today),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Semantics(
            label: '$succeeded défis réussis sur $total',
            excludeSemantics: true,
            child: Row(
              children: [
                for (final m in GameMode.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _ModeDots(done: log.succeededOn(date, m)),
                  ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '$succeeded/$total',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: succeeded > 0
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
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

/// Trois petits points empilés : défis réussis d'un mode.
class _ModeDots extends StatelessWidget {
  const _ModeDots({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 2; i >= 0; i--)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }
}
