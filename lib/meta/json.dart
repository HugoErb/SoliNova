/// Petits utilitaires de lecture JSON tolérants : une donnée manquante ou
/// corrompue retombe sur une valeur par défaut au lieu de planter.
typedef Json = Map<String, Object?>;

int readInt(Json json, String key, [int fallback = 0]) {
  final v = json[key];
  return v is int ? v : (v is num ? v.toInt() : fallback);
}

int? readIntOrNull(Json json, String key) {
  final v = json[key];
  return v is int ? v : (v is num ? v.toInt() : null);
}

bool readBool(Json json, String key, bool fallback) {
  final v = json[key];
  return v is bool ? v : fallback;
}

String? readString(Json json, String key) {
  final v = json[key];
  return v is String ? v : null;
}

Json readMap(Json json, String key) {
  final v = json[key];
  return v is Map ? v.cast<String, Object?>() : <String, Object?>{};
}

List<Object?> readList(Json json, String key) {
  final v = json[key];
  return v is List ? v.cast<Object?>() : const [];
}

T readEnum<T extends Enum>(Json json, String key, List<T> values, T fallback) {
  final name = json[key];
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
