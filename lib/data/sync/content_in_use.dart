/// Exercises a game has on screen right now (ADR 0093).
///
/// The offline window never evicts one of these: a lesson must not lose its
/// audio or pictures under a child who is playing it. The play screen
/// registers its exercise for the life of the game. A count rather than a
/// set, so two screens on the same exercise (a replay pushed over a
/// celebration) don't release it early.
class ContentInUse {
  final _counts = <String, int>{};

  void hold(String exerciseId) =>
      _counts[exerciseId] = (_counts[exerciseId] ?? 0) + 1;

  void release(String exerciseId) {
    final n = (_counts[exerciseId] ?? 0) - 1;
    if (n <= 0) {
      _counts.remove(exerciseId);
    } else {
      _counts[exerciseId] = n;
    }
  }

  Set<String> get ids => _counts.keys.toSet();
}
