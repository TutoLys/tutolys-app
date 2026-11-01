import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/sync/curriculum_sync.dart';

/// A curriculum server that can be taken offline, so every branch of the
/// sync's switch can be driven without a real network.
class FakeCurriculumServer extends CurriculumApi {
  FakeCurriculumServer() : super(dio: Dio());

  /// subject -> the leaves the server would serve for it.
  final Map<String, List<CurriculumLeaf>> leavesBySubject = {};

  bool offline = false;
  bool unauthorized = false;
  String? failWith;

  int fetchCalls = 0;

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    fetchCalls++;
    if (offline) return const CurriculumTreeOffline();
    if (unauthorized) return const CurriculumTreeUnauthorized();
    if (failWith != null) return CurriculumTreeFailed(failWith!);

    return CurriculumTreeFetched(leavesBySubject[subject] ?? const []);
  }
}

void main() {
  late LocalDatabase db;
  late FakeCurriculumServer server;
  late CurriculumSync sync;

  CurriculumLeaf leaf(
    String id, {
    String label = 'Lire et écrire tout nombre naturel',
  }) {
    return CurriculumLeaf(
      id: id,
      labelFr: label,
      labelEn: '',
      stableKey: 'mathematique/$id',
    );
  }

  setUp(() {
    db = LocalDatabase.memory();
    server = FakeCurriculumServer();
    sync = CurriculumSync(db: db, api: server, accessToken: () => 'token');
  });

  tearDown(() => db.close());

  test('downloads and caches every leaf', () async {
    server.leavesBySubject['MATH'] = [leaf('a'), leaf('b'), leaf('c')];

    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.isOk, isTrue);
    expect(report.count, 3);
    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached.map((c) => c.id).toSet(), {'a', 'b', 'c'});
  });

  test('an empty tree is not an error', () async {
    final report = await sync.sync(subject: 'MATH', grade: 1);
    expect(report.isOk, isTrue);
    expect(report.count, 0);
  });

  test('a leaf withdrawn from the server is dropped from the cache', () async {
    server.leavesBySubject['MATH'] = [leaf('a'), leaf('b')];
    await sync.sync(subject: 'MATH', grade: 1);

    server.leavesBySubject['MATH'] = [leaf('a')];
    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.count, 1);
    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached.map((c) => c.id).toSet(), {'a'});
  });

  test('an edited label updates in place rather than duplicating', () async {
    server.leavesBySubject['MATH'] = [leaf('a', label: 'Original')];
    await sync.sync(subject: 'MATH', grade: 1);

    server.leavesBySubject['MATH'] = [leaf('a', label: 'Edited')];
    await sync.sync(subject: 'MATH', grade: 1);

    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached.length, 1);
    expect(cached.single.labelFr, 'Edited');
  });

  test('cached reads are scoped to subject and grade', () async {
    server.leavesBySubject['MATH'] = [leaf('a')];
    await sync.sync(subject: 'MATH', grade: 1);
    // A different grade slice should not see grade 1's rows.
    final otherGrade = await sync.cachedLeaves(subject: 'MATH', grade: 2);
    final otherSubject = await sync.cachedLeaves(subject: 'FR', grade: 1);
    expect(otherGrade, isEmpty);
    expect(otherSubject, isEmpty);
  });

  test('mid-sync offline leaves the existing cache untouched', () async {
    server.leavesBySubject['MATH'] = [leaf('a'), leaf('b')];
    await sync.sync(subject: 'MATH', grade: 1);

    server.offline = true;
    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.offline, isTrue);
    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached.map((c) => c.id).toSet(), {
      'a',
      'b',
    }, reason: 'offline must not clear the cache');
  });

  test(
    'an unauthorized credential is reported, not treated as empty content',
    () async {
      server.leavesBySubject['MATH'] = [leaf('a')];
      await sync.sync(subject: 'MATH', grade: 1);

      server.unauthorized = true;
      final report = await sync.sync(subject: 'MATH', grade: 1);

      expect(report.unauthorized, isTrue);
      final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
      expect(
        cached,
        isNotEmpty,
        reason: 'an auth failure must not clear the cache',
      );
    },
  );

  test('a server failure is reported, not treated as empty content', () async {
    server.leavesBySubject['MATH'] = [leaf('a')];
    await sync.sync(subject: 'MATH', grade: 1);

    server.failWith = 'server exploded';
    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.error, 'server exploded');
    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached, isNotEmpty);
  });

  test('syncing with no access token does not call the server', () async {
    sync = CurriculumSync(db: db, api: server, accessToken: () => null);

    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.unauthorized, isTrue);
    expect(server.fetchCalls, 0);
  });

  test('document order, strand and area come through to the cache', () async {
    final parsed = CurriculumLeaf.fromJson({
      'id': 'l1',
      'label_fr': 'Lire',
      'label_en': '',
      'stable_key': 'francais-langue/lire/b:A/o:1',
      'doc_order': 412,
      'short_label_fr': 'Lire des mots',
      'short_label_en': '  ',
      'strand': {
        'key': 'francais-langue/lire',
        'label_fr': 'Compétence Lire des textes variés — Section Stratégies',
        'label_en': '',
        'ordinal': 7,
      },
      'area': {
        'label_fr': 'Lire des textes variés',
        'label_en': '',
        'ordinal': 1,
      },
    });
    server.leavesBySubject['FR'] = [parsed];
    await sync.sync(subject: 'FR', grade: 1);

    final row = (await sync.cachedLeaves(subject: 'FR', grade: 1)).single;
    expect(row.docOrder, 412);
    expect(row.strandKey, 'francais-langue/lire');
    expect(row.strandLabelFr, startsWith('Compétence Lire'));
    expect(row.areaLabelFr, 'Lire des textes variés');
    // AM9: the kid's short label is cached; a blank one is no label.
    expect(row.shortLabelFr, 'Lire des mots');
    expect(row.shortLabelEn, isNull);
    expect(row.areaLabelEn, '');
    expect(row.areaOrdinal, 1);
  });

  test('an older backend without them still parses, as nulls', () {
    final old = CurriculumLeaf.fromJson({
      'id': 'l1',
      'label_fr': 'Lire',
      'label_en': '',
      'stable_key': 'francais-langue/lire/b:A/o:1',
    });
    expect(old.docOrder, isNull);
    expect(old.areaLabelFr, isNull);
    expect(old.shortLabelFr, isNull);
  });
}
