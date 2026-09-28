import 'package:flutter/material.dart';

import '../../engine/model/game_mode.dart';
import '../../engine/scoring/score_calculator.dart';
import '../widgets/common.dart';

/// Section de règles.
typedef _Rule = (String title, String body);

const Map<GameFamily, List<_Rule>> _rules = {
  GameFamily.klondike: [
    (
      'Objectif',
      'Ranger les 52 cartes sur les 4 fondations, une par couleur, de l\'As au Roi.',
    ),
    (
      'Mise en place',
      '7 colonnes de 1 à 7 cartes : seule la dernière carte de chaque colonne '
          'est visible. Les 24 cartes restantes forment la pioche.',
    ),
    (
      'Déplacements autorisés',
      'Une carte se pose sur une carte de valeur immédiatement supérieure et de '
          'couleur opposée (rouge sur noir, noir sur rouge). Une suite correctement '
          'ordonnée se déplace en bloc. Une carte d\'une fondation peut revenir '
          'dans le tableau.',
    ),
    (
      'Colonnes',
      'Quand une carte cachée se retrouve en bas d\'une colonne, elle se retourne '
          'automatiquement. Seul un Roi (ou une suite commençant par un Roi) peut '
          'occuper une colonne vide.',
    ),
    (
      'Fondations',
      'Chaque fondation commence par un As puis reçoit les cartes de même couleur '
          'dans l\'ordre croissant : 2, 3… jusqu\'au Roi.',
    ),
    (
      'Pioche',
      'Touche la pioche pour retourner 1 carte (tirage 1) ou 3 cartes (tirage 3) '
          'sur la défausse. Seule la carte du dessus de la défausse est jouable. '
          'Quand la pioche est vide, touche son emplacement pour remettre la '
          'défausse en pioche : les passages sont illimités.',
    ),
    (
      'Victoire',
      'La partie est gagnée quand les 52 cartes sont sur les fondations.',
    ),
    (
      'Particularités',
      'Le tirage 3 cartes est plus difficile : certaines cartes restent '
          'inaccessibles tant que celles du dessus n\'ont pas été jouées. Quand '
          'toutes les cartes sont visibles et la pioche vide, le bouton Terminer '
          'range automatiquement le reste.',
    ),
  ],
  GameFamily.spider: [
    (
      'Objectif',
      'Former 8 suites complètes du Roi à l\'As dans une même couleur. Chaque suite '
          'complète quitte automatiquement le tableau.',
    ),
    (
      'Mise en place',
      '104 cartes (deux jeux). 10 colonnes : les 4 premières reçoivent 6 cartes, '
          'les 6 autres 5 cartes ; seule la dernière est visible. Les 50 cartes '
          'restantes forment la pioche.',
    ),
    (
      'Déplacements autorisés',
      'Une carte se pose sur n\'importe quelle carte de valeur immédiatement '
          'supérieure, quelle que soit sa couleur. En revanche, seules les suites '
          'décroissantes d\'une même couleur se déplacent en bloc.',
    ),
    (
      'Colonnes',
      'Les cartes cachées se retournent automatiquement. N\'importe quelle carte '
          'ou suite peut occuper une colonne vide.',
    ),
    (
      'Fondations',
      'On n\'y pose rien à la main : une suite Roi → As complète de même couleur '
          'y part d\'elle-même.',
    ),
    (
      'Pioche',
      'Touche la pioche pour distribuer une carte visible sur chacune des 10 '
          'colonnes (5 distributions possibles). Impossible tant qu\'une colonne '
          'est vide.',
    ),
    ('Victoire', 'La partie est gagnée quand les 8 suites sont complètes.'),
    (
      'Particularités',
      '1 couleur : uniquement des piques, idéal pour débuter. 2 couleurs : piques '
          'et cœurs. 4 couleurs : les quatre couleurs, nettement plus exigeant.',
    ),
  ],
  GameFamily.freecell: [
    (
      'Objectif',
      'Ranger les 52 cartes sur les 4 fondations, de l\'As au Roi par couleur.',
    ),
    (
      'Mise en place',
      'Toutes les cartes sont distribuées face visible sur 8 colonnes (4 de 7 '
          'cartes, 4 de 6 cartes). 4 cellules libres et 4 fondations sont vides.',
    ),
    (
      'Déplacements autorisés',
      'Une carte se pose sur une carte de valeur immédiatement supérieure et de '
          'couleur opposée. Une cellule libre accueille une seule carte, quelle '
          'qu\'elle soit.',
    ),
    (
      'Colonnes',
      'N\'importe quelle carte peut occuper une colonne vide. On peut déplacer une '
          'suite en bloc si les cellules et colonnes libres le permettent : '
          '(cellules libres + 1) × 2 puissance (colonnes vides).',
    ),
    (
      'Fondations',
      'Même principe qu\'au Klondike. Une carte posée en fondation n\'en ressort pas.',
    ),
    (
      'Pioche',
      'Il n\'y a pas de pioche : toutes les cartes sont en jeu dès le début.',
    ),
    (
      'Victoire',
      'La partie est gagnée quand les 52 cartes sont sur les fondations.',
    ),
    (
      'Particularités',
      'Presque toutes les donnes peuvent être gagnées : c\'est un jeu de '
          'réflexion pure. Les cellules libres sont précieuses, garde-en toujours une.',
    ),
  ],
};

const _common = [
  (
    'Commandes',
    'Glisse une carte (ou une suite) pour la déplacer. Un toucher joue le meilleur '
        'coup disponible, en priorité vers une fondation. Un double toucher envoie '
        'une carte vers sa fondation. Annuler revient au coup précédent. Indice '
        'explique le prochain coup d\'une suite gagnante calculée pour ta '
        'position. Chaque donne distribuée est gagnable. La baguette joue ce '
        'même coup automatiquement, '
        'sans explication. Indice : ${ScoreCalculator.hintCost} points de score ; '
        'coup assisté : ${ScoreCalculator.assistedMoveCost} points. '
        'Ces deux aides sont illimitées, même à zéro point. '
        'Elles empêchent de valider les objectifs et succès « sans indice ». '
        'Si tu t\'écartes du chemin et que la position est perdue, l\'aide '
        'te le dit : annule quelques coups.',
  ),
  (
    'Partie commencée',
    'Une partie compte dans les statistiques dès le premier coup joué. Si tu '
        'l\'abandonnes ou en lances une autre, elle compte comme une défaite.',
  ),
];

/// Règles détaillées de chaque mode.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key, this.initial});

  final GameMode? initial;

  static Route<void> route(GameMode? mode) =>
      MaterialPageRoute<void>(builder: (_) => RulesScreen(initial: mode));

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  late GameFamily _family = widget.initial?.family ?? GameFamily.klondike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const names = {
      GameFamily.klondike: 'Klondike',
      GameFamily.spider: 'Spider',
      GameFamily.freecell: 'FreeCell',
    };
    return NovaPage(
      title: 'Règles du jeu',
      children: [
        SegmentedButton<GameFamily>(
          segments: [
            for (final f in GameFamily.values)
              ButtonSegment(value: f, label: Text(names[f]!)),
          ],
          selected: {_family},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _family = s.first),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey(_family),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, body) in [
                ..._rules[_family]!,
                ..._common,
              ]) ...[
                SectionTitle(title),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
