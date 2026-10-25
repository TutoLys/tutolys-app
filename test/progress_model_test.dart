import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/progress/progress_model.dart';

CachedSkillNode leaf(String id, String strand, int o) => CachedSkillNode(
  id: id,
  labelFr: id,
  labelEn: '',
  stableKey: 'mathematique/$strand/b:A/o:$o',
  subject: 'MATH',
  grade: 1,
);

SkillMasteryDto m(String id, double pct, {bool mastered = false}) =>
    SkillMasteryDto(skillNodeId: id, masteryPct: pct, isMastered: mastered);

List<AreaProgress> build(
  List<CachedSkillNode> leaves,
  List<SkillMasteryDto> masteries,
) => buildAreaProgress(
  subject: 'MATH',
  leaves: leaves,
  masteries: masteries,
  english: false,
);

void main() {
  test('rows share the Carte\'s learning-area titles and order', () {
    final rows = build([
      leaf('g', 'geometrie', 1),
      leaf('n', 'sens-et-ecriture-des-nombres', 1),
    ], const []);
    expect(rows.map((r) => r.title), ['Arithmétique', 'Géométrie']);
  });

  test('the bar is mean mastery over every leaf, unplayed ones as zero', () {
    final rows = build(
      [leaf('a', 'mesure', 1), leaf('b', 'mesure', 2)],
      [m('a', 60)],
    );
    expect(rows.single.fraction, closeTo(0.3, 1e-9));
  });

  test('mastered only when every leaf is — not at a high percentage', () {
    final nearly = build(
      [leaf('a', 'mesure', 1), leaf('b', 'mesure', 2)],
      [m('a', 95, mastered: true), m('b', 70)],
    );
    expect(nearly.single.status, AreaStatus.learning);

    final done = build(
      [leaf('a', 'mesure', 1), leaf('b', 'mesure', 2)],
      [m('a', 90, mastered: true), m('b', 85, mastered: true)],
    );
    expect(done.single.status, AreaStatus.mastered);
  });

  test('nothing played is not started, at zero', () {
    final rows = build([leaf('a', 'mesure', 1)], const []);
    expect(rows.single.status, AreaStatus.notStarted);
    expect(rows.single.fraction, 0);
  });

  test('mastery for a skill outside this subject changes nothing', () {
    final rows = build([leaf('a', 'mesure', 1)], [m('elsewhere', 100)]);
    expect(rows.single.status, AreaStatus.notStarted);
  });

  group('a finished lesson counts at once (ADR 0032)', () {
    test('local lessons move the bar and the status before the server', () {
      final rows = buildAreaProgress(
        subject: 'MATH',
        leaves: [leaf('a', 'mesure', 1), leaf('b', 'mesure', 2)],
        masteries: const [],
        english: false,
        local: const {'a': 0.5},
      );
      expect(rows.single.fraction, closeTo(0.25, 1e-9));
      expect(rows.single.status, AreaStatus.learning);
    });

    test('per leaf, the further of server and local wins', () {
      final rows = buildAreaProgress(
        subject: 'MATH',
        leaves: [leaf('a', 'mesure', 1), leaf('b', 'mesure', 2)],
        masteries: [m('a', 80), m('b', 10)],
        english: false,
        local: const {'a': 0.5, 'b': 1.0},
      );
      expect(rows.single.fraction, closeTo((0.8 + 1.0) / 2, 1e-9));
    });

    test('gold stays the server\'s: all lessons done is not mastered', () {
      final rows = buildAreaProgress(
        subject: 'MATH',
        leaves: [leaf('a', 'mesure', 1)],
        masteries: const [],
        english: false,
        local: const {'a': 1.0},
      );
      expect(rows.single.fraction, 1.0);
      expect(rows.single.status, AreaStatus.learning);
    });
  });
}
