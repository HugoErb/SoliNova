import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'progress_screen.dart';
import 'rules_screen.dart';
import 'scoring_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

Route<void> rulesRoute() => RulesScreen.route(null);
Route<void> settingsRoute() => SettingsScreen.route();

/// Onglet « Plus » : accès secondaires.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = [
      (
        Icons.bar_chart_rounded,
        'Statistiques',
        'Globales et par mode',
        StatisticsScreen.route,
      ),
      (
        Icons.palette_rounded,
        'Thèmes',
        'Changer l\'ambiance du jeu',
        () => ShopScreen.route(themesOnly: true),
      ),
      (
        Icons.menu_book_rounded,
        'Règles du jeu',
        'Klondike, Spider, FreeCell',
        rulesRoute,
      ),
      (
        Icons.calculate_rounded,
        'Comment le score est calculé',
        'Score, XP et points',
        ScoringScreen.route,
      ),
      (
        Icons.tune_rounded,
        'Paramètres',
        'Son, animations, affichage',
        settingsRoute,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text(
            'Plus',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final (icon, title, subtitle, route) in entries)
                ListTile(
                  leading: Icon(icon, color: scheme.primary),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(subtitle),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.of(context).push(route()),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Column(
            children: [
              NovaStar(size: 28, color: scheme.primary),
              const SizedBox(height: 8),
              const Text(
                'SoliNova',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              Text(
                'Version 1.0. Fonctionne entièrement hors ligne,\nsans compte ni publicité.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
