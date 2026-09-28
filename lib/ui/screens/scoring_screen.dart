import 'package:flutter/material.dart';

import '../../engine/model/game_mode.dart';
import '../../engine/scoring/live_points.dart';
import '../../engine/scoring/score_calculator.dart';
import '../../meta/daily/daily_challenge.dart';
import '../../meta/economy/wallet.dart';
import '../../meta/progression/player_progress.dart';
import '../widgets/common.dart';

/// Page « Comment le score est calculé ». Toutes les valeurs sont lues dans
/// les modules de calcul : la page reste toujours exacte.
class ScoringScreen extends StatelessWidget {
  const ScoringScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const ScoringScreen());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = TextStyle(
      fontSize: 15.5,
      height: 1.5,
      color: scheme.onSurface,
    );
    const sc = ScoreCalculator.victoryBonus;

    Widget para(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(text, style: body),
    );

    Widget rows(List<(String, String)> items) => Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final (a, b) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      a,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: Text(
                      b,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    String signed(int v) => v > 0 ? '+$v' : '$v';

    // Exemple 1 : Klondike tirage 1.
    final ex1 = ScoreCalculator.compute(
      mode: GameMode.klondike1,
      won: true,
      gamePoints: 700,
      elapsedMs: 180000,
      moves: 110,
      hints: 1,
      undos: 2,
      previousStreak: 2,
    );
    // Exemple 2 : Spider 4 couleurs.
    final ex2 = ScoreCalculator.compute(
      mode: GameMode.spider4,
      won: true,
      gamePoints: 1150,
      elapsedMs: 1200000,
      moves: 300,
      hints: 0,
      undos: 4,
      previousStreak: 0,
    );

    List<(String, String)> breakdown(ScoreBreakdown s) => [
      ('Points de jeu', formatNumber(s.gamePoints)),
      ('Bonus de victoire', '+${s.victoryBonus}'),
      ('Bonus de difficulté', '+${s.difficultyBonus}'),
      ('Bonus de rapidité', '+${s.speedBonus}'),
      ('Bonus de coups', '+${s.movesBonus}'),
      ('Bonus de série', '+${s.streakBonus}'),
      ('Pénalité indices', '-${s.hintPenalty}'),
      ('Pénalité coups assistés', '-${s.assistedMovePenalty}'),
      ('Pénalité annulations', '-${s.undoPenalty}'),
      ('Score final', formatNumber(s.total)),
    ];

    final xp1 =
        XpRules.winBase[GameMode.klondike1]! + ex1.total ~/ XpRules.scorePerXp;
    final pts1 = PointsRules.winBase + ex1.total ~/ PointsRules.scorePerPoint;

    return NovaPage(
      title: 'Comment le score est calculé',
      children: [
        para(
          'SoliNova sépare trois compteurs qui ne se mélangent jamais : le score '
          'mesure la qualité d\'une partie, l\'XP fait monter ton niveau, et les '
          'points servent à acheter des éléments en boutique.',
        ),
        const SectionTitle('Score de départ et points de jeu'),
        para(
          'Chaque partie commence à 0. Pendant la partie, certaines actions '
          'rapportent ou coûtent des points de jeu :',
        ),
        rows([
          (
            'Carte posée en fondation (Klondike, FreeCell)',
            signed(LivePoints.toFoundation),
          ),
          (
            'Carte de la défausse vers le tableau (Klondike)',
            signed(LivePoints.wasteToTableau),
          ),
          (
            'Carte cachée retournée (Klondike, Spider)',
            signed(LivePoints.reveal),
          ),
          (
            'Carte reprise d\'une fondation (Klondike)',
            signed(LivePoints.foundationToTableau),
          ),
          (
            'Pioche remise en place, tirage 1 (Klondike)',
            signed(LivePoints.recycleDraw1),
          ),
          ('Suite complète Roi → As (Spider)', signed(LivePoints.spiderSuite)),
        ]),
        const SizedBox(height: 8),
        para(
          'Annuler un coup retire aussi les points qu\'il avait rapportés : '
          'impossible de gagner des points en jouant et annulant en boucle.',
        ),
        const SectionTitle('Bonus en cas de victoire'),
        rows([
          ('Bonus de victoire', '+$sc'),
          (
            'Bonus de rapidité',
            '${ScoreCalculator.speedPerSecond} par seconde sous le temps de référence, max ${ScoreCalculator.speedMax}',
          ),
          (
            'Bonus de coups',
            '${ScoreCalculator.movesPerMove} par coup sous la référence, max ${ScoreCalculator.movesMax}',
          ),
          (
            'Bonus de série',
            '${ScoreCalculator.streakPerWin} par victoire consécutive précédente dans le mode, max ${ScoreCalculator.streakMax}',
          ),
        ]),
        const SectionTitle('Pénalités'),
        rows([
          ('Chaque indice utilisé', '-${ScoreCalculator.hintCost}'),
          ('Chaque coup assisté', '-${ScoreCalculator.assistedMoveCost}'),
          ('Chaque annulation', '-${ScoreCalculator.undoCost}'),
        ]),
        const SizedBox(height: 8),
        para(
          'Le score ne descend jamais sous 0. Une défaite ne reçoit aucun bonus.',
        ),
        const SectionTitle('Différences entre les modes'),
        rows([
          for (final m in GameMode.values)
            (
              m.fullName,
              'difficulté +${ScoreCalculator.modes[m]!.difficultyBonus}\n'
                  '${ScoreCalculator.modes[m]!.referenceSeconds ~/ 60} min, '
                  '${ScoreCalculator.modes[m]!.referenceMoves} coups',
            ),
        ]),
        const SizedBox(height: 8),
        para(
          'Les modes les plus difficiles rapportent un bonus fixe plus élevé et ont '
          'des références de temps et de coups plus larges.',
        ),
        const SectionTitle('Exemple : Klondike tirage 1'),
        para(
          'Victoire en 3 min et 110 coups, 700 points de jeu, 1 indice, '
          '2 annulations, après 2 victoires d\'affilée.',
        ),
        rows(breakdown(ex1)),
        const SectionTitle('Exemple : Spider 4 couleurs'),
        para(
          'Victoire en 20 min et 300 coups, 1 150 points de jeu, aucun indice, '
          '4 annulations, première victoire de la série.',
        ),
        rows(breakdown(ex2)),
        const SectionTitle('XP'),
        para(
          'Une victoire rapporte l\'XP de base du mode plus 1 XP par tranche de '
          '${XpRules.scorePerXp} points de score. Une défaite rapporte '
          '${XpRules.lossXp} XP seulement si la partie a duré au moins '
          '${XpRules.lossMinSeconds} secondes et ${XpRules.lossMinMoves} coups.',
        ),
        rows([
          for (final m in GameMode.values)
            (m.fullName, '${XpRules.winBase[m]} XP'),
        ]),
        const SizedBox(height: 8),
        para(
          'Passer du niveau n au suivant demande 100 + 50 × (n − 1) XP. '
          'Dans l\'exemple Klondike : ${XpRules.winBase[GameMode.klondike1]} + '
          '${ex1.total} ÷ ${XpRules.scorePerXp} = $xp1 XP.',
        ),
        const SectionTitle('Points'),
        para(
          'Une victoire rapporte ${PointsRules.winBase} points plus 1 point par '
          'tranche de ${PointsRules.scorePerPoint} points de score. Chaque niveau '
          'atteint offre ${PointsRules.perLevelUp} points. Les défis et les succès '
          'rapportent aussi des points. Une défaite ne rapporte aucun point.',
        ),
        para(
          'Dans l\'exemple Klondike : ${PointsRules.winBase} + ${ex1.total} ÷ '
          '${PointsRules.scorePerPoint} = $pts1 points.',
        ),
        const SectionTitle('Défis quotidiens'),
        rows([
          for (final d in ChallengeDifficulty.values)
            (d.label, '${d.rewardXp} XP et ${d.rewardPoints} points'),
        ]),
        const SizedBox(height: 8),
        para(
          'La récompense d\'un défi est versée une seule fois, à la première réussite.',
        ),
      ],
    );
  }
}
