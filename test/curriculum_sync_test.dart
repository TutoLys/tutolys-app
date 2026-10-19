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

  CurriculumLeaf leaf(String id, {String label = 'Lire et écrire tout nombre naturel'}) {
    return CurriculumLeaf(id: id, labelFr: label, labelEn: '', stableKey: 'mathematique/$id');
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
    expect(cached.map((c) => c.id).toSet(), {'a', 'b'}, reason: 'offline must not clear the cache');
  });

  test('an unauthorized credential is reported, not treated as empty content', () async {
    server.leavesBySubject['MATH'] = [leaf('a')];
    await sync.sync(subject: 'MATH', grade: 1);

    server.unauthorized = true;
    final report = await sync.sync(subject: 'MATH', grade: 1);

    expect(report.unauthorized, isTrue);
    final cached = await sync.cachedLeaves(subject: 'MATH', grade: 1);
    expect(cached, isNotEmpty, reason: 'an auth failure must not clear the cache');
  });

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
}
