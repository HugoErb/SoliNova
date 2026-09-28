// Génère des donnes gagnables : graines dont le solveur a trouvé une
// solution, vérifiée en la rejouant.
//
//   dart run tool/generate_deals.dart <mode> <nombre> <budget> [tranche] [tranches]
//
// Écrit une ligne « graine solution » par donne sur la sortie standard.
// Les graines candidates suivent une suite fixe : relancer la même commande
// redonne les mêmes donnes.
import 'dart:io';

import 'package:solinova/engine/model/game_mode.dart';
import 'package:solinova/engine/rng/seeded_random.dart';
import 'package:solinova/engine/rules/rules_registry.dart';
import 'package:solinova/engine/solver/solution_codec.dart';
import 'package:solinova/engine/solver/solver.dart';

void main(List<String> args) {
  final mode = GameMode.values.byName(args[0]);
  final count = int.parse(args[1]);
  final budget = int.parse(args[2]);
  final shard = args.length > 3 ? int.parse(args[3]) : 0;
  final shards = args.length > 4 ? int.parse(args[4]) : 1;
  final rules = RulesRegistry.of(mode);
  final rng = SeededRandom(SeededRandom.hashString('solinova-${mode.name}'));
  var found = 0;
  var tried = 0;
  for (var i = 0; found < count; i++) {
    final seed = rng.nextInt(0x7FFFFFFF) + 1;
    if (i % shards != shard) continue;
    tried++;
    final result = Solver.solve(rules, rules.deal(seed), maxNodes: budget);
    if (!result.solved) continue;
    var state = rules.deal(seed);
    for (final move in result.moves!) {
      if (!rules.isLegal(state, move)) {
        throw StateError('Solution invalide pour $mode / $seed');
      }
      state = rules.apply(state, move);
    }
    if (!rules.isWon(state)) throw StateError('Solution incomplète : $seed');
    stdout.writeln('$seed ${SolutionCodec.encode(result.moves!)}');
    found++;
    stderr.writeln('$mode [$shard] $found/$count (essais : $tried)');
  }
}
