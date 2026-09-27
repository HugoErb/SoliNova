import 'dart:math' as math;

/// Générateur pseudo-aléatoire déterministe (Mulberry32).
///
/// On n'utilise pas `dart:math.Random(seed)` car son algorithme n'est pas
/// garanti stable entre versions : une graine doit toujours produire la même
/// donne, notamment pour les défis quotidiens.
final class SeededRandom {
  SeededRandom(int seed) : _state = seed & _mask;

  static const _mask = 0xFFFFFFFF;
  int _state;

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & _mask;
    return (t ^ (t >>> 14)) & _mask;
  }

  /// Entier uniforme dans [0, max).
  int nextInt(int max) {
    assert(max > 0);
    // Rejet pour éviter le biais modulo.
    final limit = (0x100000000 ~/ max) * max;
    while (true) {
      final v = nextUint32();
      if (v < limit) return v % max;
    }
  }

  double nextDouble() => nextUint32() / 0x100000000;

  /// Multiplication 32 bits (équivalent de Math.imul).
  static int _imul(int a, int b) {
    final aHi = (a >>> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >>> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return ((aLo * bLo) + ((((aHi * bLo) + (aLo * bHi)) << 16) & _mask)) &
        _mask;
  }

  /// Graine aléatoire pour une partie normale.
  static int randomSeed() => math.Random.secure().nextInt(0x7FFFFFFF) + 1;

  /// Hachage FNV-1a 32 bits, stable, pour dériver une graine d'un texte.
  static int hashString(String input) {
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = _imul(hash, 0x01000193);
    }
    return hash & _mask;
  }
}
