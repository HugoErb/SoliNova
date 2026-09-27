import '../model/game_mode.dart';
import 'freecell_rules.dart';
import 'game_rules.dart';
import 'klondike_rules.dart';
import 'spider_rules.dart';

/// Associe chaque mode à ses règles.
abstract final class RulesRegistry {
  static final Map<GameMode, GameRules> _rules = {
    for (final mode in GameMode.values) mode: _create(mode),
  };

  static GameRules _create(GameMode mode) => switch (mode.family) {
    GameFamily.klondike => KlondikeRules(mode),
    GameFamily.spider => SpiderRules(mode),
    GameFamily.freecell => FreeCellRules(mode),
  };

  static GameRules of(GameMode mode) => _rules[mode]!;
}
