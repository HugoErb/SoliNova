import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../game/game_screen.dart';

/// Choix du mode de jeu pour une nouvelle partie.
Future<void> showNewGameSheet(
  BuildContext context,
  WidgetRef ref, {
  bool stayOnGame = false,
}) async {
  final mode = await showModalBottomSheet<GameMode>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ModePicker(),
  );
  if (mode == null || !context.mounted) return;
  await startGame(context, ref, () {
    ref.read(gameProvider.notifier).newGame(mode);
  }, stayOnGame: stayOnGame);
}

/// Lance une partie après confirmation d'abandon si nécessaire, puis ouvre
/// l'écran de jeu.
Future<void> startGame(
  BuildContext context,
  WidgetRef ref,
  VoidCallback start, {
  bool stayOnGame = false,
}) async {
  final controller = ref.read(gameProvider.notifier);
  if (controller.wouldAbandon && ref.read(settingsProvider).confirmAbandon) {
    final ok = await confirmAbandon(context);
    if (!ok || !context.mounted) return;
  }
  start();
  if (!stayOnGame) await Navigator.of(context).push(GameScreen.route());
}

class _ModePicker extends ConsumerWidget {
  const _ModePicker();

  static const _descriptions = {
    GameMode.klondike1: 'Le grand classique, une carte à la fois.',
    GameMode.klondike3: 'Trois cartes par pioche : plus de réflexion.',
    GameMode.spider1: 'Idéal pour découvrir Spider.',
    GameMode.spider2: 'Pique et cœur : un vrai défi.',
    GameMode.spider4: 'Les quatre couleurs : pour les experts.',
    GameMode.freecell: 'Tout est visible : pure stratégie.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(profileProvider.select((p) => p.stats));
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  'Modes de jeu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              for (final family in GameFamily.values) ...[
                for (final mode in GameMode.values.where(
                  (m) => m.family == family,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(context, mode),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _FamilyGlyph(family: family),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _descriptions[mode]!,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: '${stats.of(mode).wins} victoires',
                                excludeSemantics: true,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.emoji_events_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${stats.of(mode).wins}',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyGlyph extends StatelessWidget {
  const _FamilyGlyph({required this.family});

  final GameFamily family;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = switch (family) {
      GameFamily.klondike => 'K',
      GameFamily.spider => 'S',
      GameFamily.freecell => 'F',
    };
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}
