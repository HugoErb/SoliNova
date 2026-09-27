import 'dart:io';

/// Stockage clé → texte. Abstrait pour pouvoir tester sans disque et, plus
/// tard, brancher un export/import.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Met de côté une donnée illisible pour ne jamais l'écraser en silence.
  Future<void> quarantine(String key);
}

/// Fichiers JSON dans le dossier privé de l'application.
///
/// Écriture atomique : on écrit un fichier temporaire puis on le renomme,
/// pour qu'une coupure ne laisse jamais un fichier à moitié écrit.
final class FileStore implements KeyValueStore {
  FileStore(this.directory);

  final Directory directory;

  File _file(String key) => File('${directory.path}/$key.json');

  @override
  Future<String?> read(String key) async {
    final file = _file(key);
    if (!await file.exists()) {
      // Reprise après une écriture interrompue avant le renommage.
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) return tmp.readAsString();
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    await directory.create(recursive: true);
    final file = _file(key);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> quarantine(String key) async {
    final file = _file(key);
    if (await file.exists()) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.corrupt-$stamp');
    }
  }
}

/// Stockage en mémoire (tests).
final class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  final Map<String, String> quarantined = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> quarantine(String key) async {
    final v = data.remove(key);
    if (v != null) quarantined[key] = v;
  }
}
