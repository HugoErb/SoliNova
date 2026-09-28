// Assemble les sorties de generate_deals.dart :
//
//   dart run tool/build_deal_tables.dart <dossier des sorties>
//
// Lit `<mode>.*.txt`, écrit `assets/deals/<mode>.txt` (solutions) et
// `lib/engine/solver/winnable_seeds.g.dart` (graines).
import 'dart:io';

import 'package:solinova/engine/model/game_mode.dart';

void main(List<String> args) {
  final input = Directory(args.single);
  Directory('assets/deals').createSync(recursive: true);
  final code = StringBuffer()
    ..writeln(
      '// Fichier généré par tool/build_deal_tables.dart : ne pas modifier.',
    )
    ..writeln("import '../model/game_mode.dart';")
    ..writeln()
    ..writeln('const Map<GameMode, List<int>> winnableSeeds = {');
  for (final mode in GameMode.values) {
    final files =
        input
            .listSync()
            .whereType<File>()
            .where((f) => f.uri.pathSegments.last.startsWith('${mode.name}.'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final lines = <int, String>{};
    for (final f in files) {
      for (final line in f.readAsLinesSync()) {
        final cut = line.indexOf(' ');
        if (cut <= 0) continue;
        lines[int.parse(line.substring(0, cut))] = line;
      }
    }
    if (lines.isEmpty) continue;
    File('assets/deals/${mode.name}.txt')
        .writeAsStringSync('${lines.values.join('\n')}\n');
    code.writeln('  GameMode.${mode.name}: [');
    for (final seed in lines.keys) {
      code.writeln('    $seed,');
    }
    code.writeln('  ],');
    stdout.writeln('${mode.name} : ${lines.length} donnes');
  }
  code.writeln('};');
  File('lib/engine/solver/winnable_seeds.g.dart').writeAsStringSync('$code');
}
