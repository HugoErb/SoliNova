import 'package:flutter/services.dart';

import '../engine/model/game_mode.dart';
import '../engine/model/move.dart';
import '../engine/solver/solution_codec.dart';

/// Solutions des donnes gagnables, lues à la demande depuis les assets.
class SolutionBook {
  SolutionBook({Future<String> Function(String key)? load})
    : _loadText = load ?? rootBundle.loadString;

  final Future<String> Function(String key) _loadText;
  final _byMode = <GameMode, Future<Map<int, String>>>{};

  /// Solution de la donne [seed], ou null si elle n'est pas répertoriée.
  Future<List<Move>?> solutionFor(GameMode mode, int seed) async {
    final table = await _byMode.putIfAbsent(mode, () => _load(mode));
    final encoded = table[seed];
    return encoded == null ? null : SolutionCodec.decode(encoded);
  }

  Future<Map<int, String>> _load(GameMode mode) async {
    try {
      final text = await _loadText('assets/deals/${mode.name}.txt');
      final table = <int, String>{};
      for (final line in text.split('\n')) {
        final cut = line.indexOf(' ');
        if (cut <= 0) continue;
        final seed = int.tryParse(line.substring(0, cut));
        if (seed != null) table[seed] = line.substring(cut + 1).trim();
      }
      return table;
    } on Object {
      return const {};
    }
  }
}
