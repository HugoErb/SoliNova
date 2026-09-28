import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
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

/// Défis quotidiens : trois défis par jour, générés localement.
class ChallengesTab extends ConsumerWidget {
  const ChallengesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DailyChallengeGenerator.forDay(now);
    final log = ref.watch(profileProvider.select((p) => p.dailies));
    final scheme = Theme.of(context).colorScheme;
    final done = today.where((c) => log.of(c.id).succeeded).length;

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
                '$done / 3',
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
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            'Les mêmes donnes toute la journée. Tentatives illimitées, '
            'récompense versée à la première réussite.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        for (final c in today) ...[
          _ChallengeCard(challenge: c, progress: log.of(c.id)),
          const SizedBox(height: 12),
        ],
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
    final challenges = DailyChallengeGenerator.forDay(day);
    final succeeded = challenges.where((c) => log.of(c.id).succeeded).length;
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
            label: '$succeeded défis réussis sur 3',
            excludeSemantics: true,
            child: Row(
              children: [
                for (final c in challenges)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      switch (log.of(c.id).status) {
                        ChallengeStatus.succeeded => Icons.check_circle_rounded,
                        ChallengeStatus.inProgress => Icons.cancel_rounded,
                        ChallengeStatus.notStarted =>
                          Icons.radio_button_unchecked_rounded,
                      },
                      size: 20,
                      color: log.of(c.id).succeeded
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
