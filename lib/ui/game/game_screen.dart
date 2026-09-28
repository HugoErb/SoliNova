import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/game_controller.dart';
import '../../app/providers.dart';
import '../../engine/model/game_mode.dart';
import '../../engine/scoring/score_calculator.dart';
import '../board/board_view.dart';
import '../screens/new_game_sheet.dart';
import '../screens/rules_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/common.dart';
import 'victory_fx.dart';
import 'victory_sheet.dart';

/// Écran de partie : plateau prioritaire, informations discrètes en haut,
/// actions à portée de pouce en bas.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    settings: const RouteSettings(name: 'game'),
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, a, b) => const GameScreen(),
    transitionsBuilder: (context, a, b, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
      child: ScaleTransition(
        scale: Tween(
          begin: 0.97,
          end: 1.0,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  StreamSubscription<String>? _messages;
  late final GameController _controller = ref.read(gameProvider.notifier);

  @override
  void initState() {
    super.initState();
    _messages = _controller.messages.listen(_showMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.setScreenActive(true);
    });
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    _controller.setScreenActive(false);
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _openMenu() async {
    _controller.clearHint();
    final session = ref.read(gameProvider).session;
    if (session == null) return;
    // Le chronomètre ne tourne pas pendant que le menu est ouvert.
    _controller.setScreenActive(false);
    final choice = await showModalBottomSheet<_MenuChoice>(
      context: context,
      builder: (context) => _GameMenu(mode: session.mode),
    );
    if (!mounted) return;
    _controller.setScreenActive(true);
    if (choice == null) return;
    switch (choice) {
      case _MenuChoice.newGame:
        await _confirmThen(() => _controller.newGame(session.mode));
      case _MenuChoice.changeMode:
        await showNewGameSheet(context, ref, stayOnGame: true);
      case _MenuChoice.restart:
        await _confirmThen(_controller.restart);
      case _MenuChoice.pause:
        _controller.setPaused(true);
      case _MenuChoice.rules:
        _controller.setPaused(true);
        await Navigator.of(context).push(RulesScreen.route(session.mode));
        if (mounted) _controller.setPaused(false);
      case _MenuChoice.settings:
        _controller.setPaused(true);
        await Navigator.of(context).push(SettingsScreen.route());
        if (mounted) _controller.setPaused(false);
      case _MenuChoice.abandon:
        final ok = await _confirmThen(_controller.abandon, force: true);
        if (ok && mounted) Navigator.of(context).pop();
      case _MenuChoice.home:
        Navigator.of(context).pop();
    }
  }

  /// Demande confirmation si une partie commencée serait abandonnée.
  Future<bool> _confirmThen(VoidCallback action, {bool force = false}) async {
    final needs =
        _controller.wouldAbandon &&
        (force || ref.read(settingsProvider).confirmAbandon);
    if (needs) {
      final ok = await confirmAbandon(context);
      if (!ok) return false;
    }
    action();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    final look = ref.watch(lookProvider);
    final session = game.session;
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: TableBackground()),
            SafeArea(
              child: Column(
                children: [
                  _Hud(onMenu: _openMenu),
                  Expanded(
                    child: session == null
                        ? const SizedBox.shrink()
                        : LayoutBuilder(
                            builder: (context, constraints) => Stack(
                              children: [
                                const Positioned.fill(child: BoardView()),
                                if (game.hint case final hint?)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 8,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: constraints.maxHeight * 0.45,
                                      ),
                                      child: _HintBanner(
                                        hint: hint,
                                        onClose: _controller.clearHint,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  _ActionBar(
                    onNewGame: session == null
                        ? null
                        : () => _confirmThen(
                            () => _controller.newGame(session.mode),
                          ),
                  ),
                ],
              ),
            ),
            if (game.paused)
              Positioned.fill(
                child: _PauseOverlay(
                  onResume: () => _controller.setPaused(false),
                ),
              ),
            if (game.report != null) ...[
              Positioned.fill(
                child: VictoryFx(key: ValueKey(game.report), look: look),
              ),
              Positioned.fill(child: VictorySheet(report: game.report!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialogue de confirmation d'abandon.
Future<bool> confirmAbandon(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Abandonner la partie ?'),
      content: const Text(
        'La partie en cours sera comptée comme une défaite et ta série '
        'de victoires repartira de zéro.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Continuer à jouer'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Abandonner'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

enum _MenuChoice {
  pause,
  newGame,
  restart,
  changeMode,
  rules,
  settings,
  abandon,
  home,
}

class _GameMenu extends StatelessWidget {
  const _GameMenu({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    Widget item(
      IconData icon,
      String label,
      _MenuChoice c, {
      bool danger = false,
    }) {
      final scheme = Theme.of(context).colorScheme;
      final color = danger ? scheme.error : scheme.onSurface;
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
        onTap: () => Navigator.pop(context, c),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                mode.fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            item(Icons.pause_rounded, 'Pause', _MenuChoice.pause),
            item(
              Icons.replay_rounded,
              'Recommencer cette donne',
              _MenuChoice.restart,
            ),
            item(Icons.add_rounded, 'Nouvelle partie', _MenuChoice.newGame),
            item(
              Icons.style_rounded,
              'Changer de mode',
              _MenuChoice.changeMode,
            ),
            item(Icons.menu_book_rounded, 'Règles du jeu', _MenuChoice.rules),
            item(Icons.tune_rounded, 'Paramètres', _MenuChoice.settings),
            item(
              Icons.home_rounded,
              'Accueil (la partie est gardée)',
              _MenuChoice.home,
            ),
            item(
              Icons.flag_rounded,
              'Abandonner',
              _MenuChoice.abandon,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'informations : menu, mode, temps, score, coups.
class _Hud extends ConsumerWidget {
  const _Hud({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameProvider.select((g) => g.session));
    final dealSerial = ref.watch(gameProvider.select((g) => g.dealSerial));
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(gameProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    const numStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    Widget stat(String label, Widget value) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
          ),
          Expanded(
            child: session == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (settings.showTimer)
                        stat(
                          'Temps',
                          ValueListenableBuilder<int>(
                            valueListenable: controller.elapsed,
                            builder: (context, ms, _) =>
                                Text(formatDuration(ms), style: numStyle),
                          ),
                        ),
                      if (settings.showScore)
                        stat(
                          'Score',
                          _ScoreCounter(
                            key: ValueKey(dealSerial),
                            score: controller.liveScore,
                            style: numStyle,
                          ),
                        ),
                      stat(
                        'Coups',
                        Text('${session.moveCount}', style: numStyle),
                      ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: 'Pause',
            onPressed: session == null
                ? null
                : () => ref.read(gameProvider.notifier).setPaused(true),
            icon: const Icon(Icons.pause_rounded),
          ),
        ],
      ),
    );
  }
}

/// Score en direct : à chaque variation, le nombre pulse et l'écart
/// (« −20 », « +10 ») s'élève puis s'efface au-dessus du compteur.
class _ScoreCounter extends ConsumerStatefulWidget {
  const _ScoreCounter({super.key, required this.score, required this.style});

  final int score;
  final TextStyle style;

  @override
  ConsumerState<_ScoreCounter> createState() => _ScoreCounterState();
}

class _ScoreCounterState extends ConsumerState<_ScoreCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _delta = 0;

  @override
  void didUpdateWidget(_ScoreCounter old) {
    super.didUpdateWidget(old);
    final delta = widget.score - old.score;
    if (delta == 0 || !ref.read(lookProvider).animationsEnabled) return;
    _delta = delta;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Text(formatNumber(widget.score), style: widget.style);
    return AnimatedBuilder(
      animation: _c,
      child: text,
      builder: (context, child) {
        final t = _c.value;
        if (!_c.isAnimating) return child!;
        final color = _delta < 0 ? scheme.error : scheme.primary;
        // Pulsation courte du nombre, écart qui monte et s'efface.
        final pulse = 1 + 0.18 * math.sin(math.min(t * 3, 1) * math.pi);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: pulse,
              child: Text(
                formatNumber(widget.score),
                style: widget.style.copyWith(
                  color: Color.lerp(
                    color,
                    DefaultTextStyle.of(context).style.color,
                    Curves.easeIn.transform(t),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 14 + 16 * Curves.easeOut.transform(t),
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - Curves.easeIn.transform(t),
                  child: Text(
                    _delta > 0 ? '+$_delta' : '−${-_delta}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Explication de l'indice, posée sur le bas du plateau.
class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.hint, required this.onClose});

  final HintInfo hint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final advice = hint.advice;
    final points = advice.points;
    Widget chip(String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.primary, width: 4)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        advice.instruction,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        advice.reason,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          chip(
                            'Coup ${points >= 0 ? '+' : '−'}${points.abs()} pts',
                            points > 0
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            points > 0
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                          if (advice.winning)
                            chip(
                              'Mène à la victoire',
                              scheme.secondaryContainer,
                              scheme.onSecondaryContainer,
                            ),
                          chip(
                            'Indice −${ScoreCalculator.hintCost} pts',
                            scheme.tertiaryContainer,
                            scheme.onTertiaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: "Fermer l'indice",
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Actions principales en bas de l'écran, avec libellés accessibles.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.onNewGame});

  final VoidCallback? onNewGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final controller = ref.read(gameProvider.notifier);
    final session = game.session;
    final canUndo = session != null && session.canUndo && !game.autoPlaying;
    final canAssist =
        session != null &&
        !session.isWon &&
        !game.paused &&
        !game.autoPlaying &&
        game.thinking == null;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.undo_rounded,
              label: 'Annuler',
              onTap: canUndo ? controller.undo : null,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Indice (${ScoreCalculator.hintCost} points)',
              busy: game.thinking == Assist.hint,
              onTap: canAssist ? controller.hint : null,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.auto_fix_high_rounded,
              label:
                  'Jouer le meilleur coup (${ScoreCalculator.assistedMoveCost} points)',
              busy: game.thinking == Assist.play,
              onTap: canAssist
                  ? () {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..removeCurrentSnackBar();
                      controller.playBestMove();
                    }
                  : null,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: game.canAutoComplete
                  ? _ActionButton(
                      key: const ValueKey('auto'),
                      icon: Icons.auto_awesome_rounded,
                      label: 'Terminer',
                      highlight: scheme.primary,
                      onTap: () => unawaited(controller.autoComplete()),
                    )
                  : _ActionButton(
                      key: const ValueKey('new'),
                      icon: Icons.add_rounded,
                      label: 'Nouvelle partie',
                      onTap: onNewGame,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? highlight;

  /// Recherche en cours : la roue remplace l'icône.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final bg = highlight ?? scheme.surfaceContainerHigh;
    final fg = highlight != null ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled || busy ? 1 : 0.4,
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: busy
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: scheme.primary,
                            ),
                          )
                        : Icon(icon, color: fg, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onResume,
      child: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NovaStar(size: 44, color: scheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'Pause',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le chronomètre est arrêté.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Reprendre',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onResume,
                  expand: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
