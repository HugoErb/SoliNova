import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../meta/settings/settings.dart';
import '../../meta/shop/shop_item.dart';
import '../feedback/feedback_service.dart';
import '../widgets/common.dart';
import 'shop_screen.dart';

/// Paramètres de SoliNova.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final profile = ref.read(profileProvider.notifier);
    final look = ref.watch(lookProvider);
    final inventory = ref.watch(profileProvider.select((p) => p.inventory));
    final scheme = Theme.of(context).colorScheme;
    void set(Settings Function(Settings) f) => profile.updateSettings(f);
    final hasVariant = look.theme.variantId != null;

    String nameOf(ShopCategory c, {String fallback = 'Selon le thème'}) {
      final id = inventory.equippedIn(c);
      return id == null ? fallback : (ShopCatalog.byId(id)?.name ?? fallback);
    }

    Widget toggle(String title, String? subtitle, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle),
          value: value,
          onChanged: onChanged,
        );

    Widget link(String title, String value, ShopCategory category) => ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value),
      trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
      onTap: () => Navigator.of(context).push(ShopScreen.route(category: category)),
    );

    Widget group(List<Widget> children) => Panel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );

    return NovaPage(
      title: 'Paramètres',
      children: [
        const SectionTitle('Son'),
        group([
          toggle('Effets sonores', 'Sons discrets pendant la partie', s.sound, (v) {
            set((x) => x.copyWith(sound: v));
            if (v) ref.read(feedbackProvider).emit(FeedbackEvent.foundation);
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.volume_down_rounded, color: scheme.onSurfaceVariant),
                Expanded(
                  child: Slider(
                    value: s.soundVolume,
                    divisions: 10,
                    label: '${(s.soundVolume * 100).round()} %',
                    semanticFormatterCallback: (v) => 'Volume ${(v * 100).round()} %',
                    onChanged: s.sound ? (v) => set((x) => x.copyWith(soundVolume: v)) : null,
                    onChangeEnd: (_) => ref.read(feedbackProvider).emit(FeedbackEvent.foundation),
                  ),
                ),
                Icon(Icons.volume_up_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ]),
        const SectionTitle('Jeu'),
        group([
          toggle(
            'Déplacement automatique',
            'Range en fondation les cartes qui ne servent plus',
            s.autoMove,
            (v) => set((x) => x.copyWith(autoMove: v)),
          ),
          toggle(
            'Toucher pour jouer',
            s.tapToMove
                ? 'Un toucher joue le meilleur coup'
                : 'Seul le double toucher agit (vers la fondation)',
            s.tapToMove,
            (v) => set((x) => x.copyWith(tapToMove: v)),
          ),
          toggle(
            'Confirmation avant abandon',
            'Demander avant de perdre une partie commencée',
            s.confirmAbandon,
            (v) => set((x) => x.copyWith(confirmAbandon: v)),
          ),
        ]),
        const SectionTitle('Affichage'),
        group([
          toggle('Afficher le score', null, s.showScore, (v) => set((x) => x.copyWith(showScore: v))),
          toggle('Afficher le chronomètre', null, s.showTimer, (v) => set((x) => x.copyWith(showTimer: v))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Animations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                SegmentedButton<AnimationSpeed>(
                  segments: [
                    for (final a in AnimationSpeed.values)
                      ButtonSegment(value: a, label: Text(a.label)),
                  ],
                  selected: {s.animations},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => set((x) => x.copyWith(animations: v.first)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Mode sombre', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  hasVariant
                      ? 'Ce thème existe en version claire et sombre.'
                      : 'Le thème actuel a une seule version : ce réglage s\'appliquera aux thèmes Minimal clair et Pastel.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                SegmentedButton<DarkModePreference>(
                  segments: [
                    for (final d in DarkModePreference.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {s.darkMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => set((x) => x.copyWith(darkMode: v.first)),
                ),
              ],
            ),
          ),
        ]),
        const SectionTitle('Apparence'),
        group([
          link('Thème', nameOf(ShopCategory.theme, fallback: 'Classique vert'), ShopCategory.theme),
          link('Style des cartes', nameOf(ShopCategory.cardFace, fallback: 'Classique'), ShopCategory.cardFace),
          link('Dos des cartes', nameOf(ShopCategory.cardBack), ShopCategory.cardBack),
          link('Fond de table', nameOf(ShopCategory.table), ShopCategory.table),
        ]),
        const SizedBox(height: 16),
        Text(
          'Toutes tes données restent sur ce téléphone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
