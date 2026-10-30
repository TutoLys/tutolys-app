import 'package:drift/drift.dart' show Value;

import '../local_db/programme_store.dart' show Programme;
import '../api/curriculum_api.dart';
import '../local_db/database.dart';

/// What a sync did.
class CurriculumSyncReport {
  const CurriculumSyncReport({
    required this.count,
    this.offline = false,
    this.unauthorized = false,
    this.error,
    this.programme,
  });

  /// The kid's subjects, when the backend sent them (ADR 0101).
  final Programme? programme;

  /// Leaves now cached for the synced subject/grade. Unchanged from before
  /// the call on `offline`/`unauthorized`/`error` — the cache is never
  /// touched unless a fetch actually succeeded.
  final int count;

  final bool offline;
  final bool unauthorized;
  final String? error;

  bool get isOk => !offline && !unauthorized && error == null;
}

/// Keeps the local curriculum-leaf cache in step with the server.
///
/// Deliberately simpler than `ContentSync`: no checksum diff, no chunked
/// fetch, no per-item verification. The curriculum tree changes rarely
/// compared to exercise content, and a kid's grade/subject slice is small —
/// replace-on-sync is the right amount of machinery, not
/// `ContentSync`'s wholesale.
class CurriculumSync {
  CurriculumSync({
    required this.db,
    required this.api,
    required this.accessToken,
  });

  final LocalDatabase db;
  final CurriculumApi api;

  /// Read per call: a sync may start long after the token it would have
  /// captured expired.
  final String? Function() accessToken;

  Future<CurriculumSyncReport> sync({
    required String subject,
    required int grade,
  }) async {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      return const CurriculumSyncReport(count: 0, unauthorized: true);
    }

    final result = await api.fetchTree(accessToken: token, subject: subject);

    return switch (result) {
      CurriculumTreeFetched(:final leaves, :final programme) => _replace(
        subject,
        grade,
        leaves,
        programme,
      ),
      // Offline is not an error: whatever is already cached stays playable,
      // which is the entire point of caching it — the existing rows are
      // left untouched, not cleared.
      CurriculumTreeOffline() => const CurriculumSyncReport(
        count: 0,
        offline: true,
      ),
      CurriculumTreeUnauthorized() => const CurriculumSyncReport(
        count: 0,
        unauthorized: true,
      ),
      CurriculumTreeFailed(:final detail) => CurriculumSyncReport(
        count: 0,
        error: detail,
      ),
    };
  }

  /// Delete-then-insert the whole subject/grade slice in one transaction, so
  /// a sync that dies halfway leaves the previous cache intact rather than a
  /// half-written mixture.
  Future<CurriculumSyncReport> _replace(
    String subject,
    int grade,
    List<CurriculumLeaf> leaves,
    Programme? programme,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.skillNodeTable)
            ..where((t) => t.subject.equals(subject))
            ..where((t) => t.grade.equals(grade)))
          .go();
      for (final leaf in leaves) {
        await db
            .into(db.skillNodeTable)
            .insertOnConflictUpdate(
              SkillNodeTableCompanion.insert(
                id: leaf.id,
                labelFr: leaf.labelFr,
                labelEn: leaf.labelEn,
                stableKey: leaf.stableKey,
                subject: subject,
                grade: grade,
                docOrder: Value(leaf.docOrder),
                strandKey: Value(leaf.strandKey),
                strandLabelFr: Value(leaf.strandLabelFr),
                strandLabelEn: Value(leaf.strandLabelEn),
                areaLabelFr: Value(leaf.areaLabelFr),
                areaLabelEn: Value(leaf.areaLabelEn),
                areaOrdinal: Value(leaf.areaOrdinal),
              ),
            );
      }
    });
    return CurriculumSyncReport(count: leaves.length, programme: programme);
  }

  /// The locally cached slice, for the path screen to read — works with no
  /// network, which is the point of caching it.
  Future<List<CachedSkillNode>> cachedLeaves({
    required String subject,
    required int grade,
  }) {
    return (db.select(db.skillNodeTable)
          ..where((t) => t.subject.equals(subject))
          ..where((t) => t.grade.equals(grade)))
        .get();
  }
}
