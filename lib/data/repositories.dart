import 'dart:async';
import 'dart:convert';

import '../engine/session/game_session.dart';
import '../meta/profile/profile.dart';
import 'storage.dart';

/// Lecture/écriture JSON robuste : une donnée corrompue est mise de côté et
/// remplacée par la valeur par défaut, sans jamais planter l'application.
abstract base class _JsonRepository<T> {
  _JsonRepository(this.store, this.key);

  final KeyValueStore store;
  final String key;

  T decode(Map<String, Object?> json);
  Map<String, Object?> encode(T value);

  Future<T?> loadOrNull() async {
    final raw = await store.read(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) throw const FormatException('Objet attendu');
      return decode(json.cast<String, Object?>());
    } on Object {
      await store.quarantine(key);
      return null;
    }
  }

  Future<void> save(T value) => store.write(key, jsonEncode(encode(value)));
}

final class ProfileRepository extends _JsonRepository<Profile> {
  ProfileRepository(KeyValueStore store) : super(store, 'profile');

  @override
  Profile decode(Map<String, Object?> json) => Profile.fromJson(json);

  @override
  Map<String, Object?> encode(Profile value) => value.toJson();

  Future<Profile> load() async => await loadOrNull() ?? const Profile();
}

final class GameRepository extends _JsonRepository<GameSession> {
  GameRepository(KeyValueStore store) : super(store, 'game');

  @override
  GameSession decode(Map<String, Object?> json) => GameSession.fromJson(json);

  @override
  Map<String, Object?> encode(GameSession value) => value.toJson();

  Future<void> clear() => store.delete(key);
}

/// Regroupe les écritures rapprochées : une seule écriture disque après
/// [delay], et [flush] force l'écriture immédiate (passage en arrière-plan).
final class DebouncedSaver<T> {
  DebouncedSaver(this._write, {this.delay = const Duration(milliseconds: 400)});

  final Future<void> Function(T value) _write;
  final Duration delay;
  Timer? _timer;
  T? _pending;
  bool _hasPending = false;
  Future<void> _chain = Future.value();

  void schedule(T value) {
    _pending = value;
    _hasPending = true;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Écrit la dernière valeur en attente. Les écritures sont sérialisées.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_hasPending) return _chain;
    final value = _pending as T;
    _hasPending = false;
    _pending = null;
    _chain = _chain.then((_) => _write(value)).catchError((Object _) {});
    return _chain;
  }

  /// Abandonne l'écriture en attente (ex. partie terminée puis effacée).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _hasPending = false;
    _pending = null;
  }

  /// Abandonne l'écriture en attente puis exécute [action] après les
  /// écritures déjà lancées, pour qu'aucune ne la défasse (ex. effacer la
  /// sauvegarde d'une partie terminée).
  Future<void> cancelThen(Future<void> Function() action) {
    cancel();
    _chain = _chain.then((_) => action()).catchError((Object _) {});
    return _chain;
  }
}
