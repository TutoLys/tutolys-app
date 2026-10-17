import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/content_api.dart';
import '../local_db/database.dart';
import 'content_hash.dart';

/// What a sync did, so the UI and the logs can say something specific.
class SyncReport {
  const SyncReport({
    required this.upToDate,
    required this.downloaded,
    required this.removed,
    required this.rejected,
    required this.unavailable,
    this.offline = false,
    this.unauthorized = false,
    this.error,
  });

  const SyncReport.offline()
      : upToDate = 0,
        downloaded = 0,
        removed = 0,
        rejected = const [],
        unavailable = const [],
        offline = true,
        unauthorized = false,
        error = null;

  const SyncReport.unauthorized()
      : upToDate = 0,
        downloaded = 0,
        removed = 0,
        rejected = const [],
        unavailable = const [],
        offline = false,
        unauthorized = true,
        error = null;

  const SyncReport.failed(String this.error)
      : upToDate = 0,
        downloaded = 0,
        removed = 0,
        rejected = const [],
        unavailable = const [],
        offline = false,
        unauthorized = false;

  /// Already cached with a matching checksum — not downloaded again.
  final int upToDate;

  final int downloaded;

  /// Dropped from the cache because the server no longer lists them.
  final int removed;

  /// Arrived with a checksum that did not match the manifest. Refused.
  final List<String> rejected;

  /// Listed in the manifest but not served when asked for.
  final List<String> unavailable;

  final bool offline;
  final bool unauthorized;
  final String? error;

  bool get isOk => !offline && !unauthorized && error == null;
  bool get changedAnything => downloaded > 0 || removed > 0;
}

/// Keeps the local exercise cache in step with the server.
///
/// Three properties make it safe to run on a kid's tablet over mobile data:
///
/// 1. **Diff by checksum.** Only exercises whose `content_hash` changed are
///    downloaded. The predecessor seeded its ETag from a global aggregate, so
///    one leaf edit anywhere re-downloaded the whole tree for every child.
/// 2. **Verify before accepting.** Every envelope is re-hashed and compared
///    with the manifest. The old backend had no integrity guarantee on content
///    at all; a truncated or tampered download would simply have been played.
/// 3. **Atomic swap.** The cache is updated in one transaction, so a sync that
///    dies halfway leaves the previous content intact and playable rather than
///    a half-written mixture.
class ContentSync {
  ContentSync({
    required this.db,
    required this.api,
    required this.accessToken,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final LocalDatabase db;
  final ContentApi api;

  /// Read per call: a sync may start long after the token it would have
  /// captured expired.
  final String? Function() accessToken;

  final DateTime Function() _now;

  Future<SyncReport> sync({String? subject}) async {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      return const SyncReport.unauthorized();
    }

    final manifestResult =
        await api.fetchManifest(accessToken: token, subject: subject);

    return switch (manifestResult) {
      ManifestFetched(:final manifest) => _applyManifest(manifest, token),
      // Offline is not an error: cached content stays playable, which is the
      // entire point of caching it.
      ManifestOffline() => Future.value(const SyncReport.offline()),
      ManifestUnauthorized() => Future.value(const SyncReport.unauthorized()),
      ManifestFailed(:final detail) => Future.value(SyncReport.failed(detail)),
    };
  }

  Future<SyncReport> _applyManifest(
    ContentManifest manifest,
    String token,
  ) async {
    final cached = {
      for (final row in await db.select(db.exerciseCacheTable).get())
        row.exerciseId: row.contentHash,
    };

    final wanted = {for (final e in manifest.entries) e.exerciseId: e};

    // Stale or missing — the only things worth bytes.
    final toFetch = manifest.entries
        .where((e) => cached[e.exerciseId] != e.contentHash)
        .map((e) => e.exerciseId)
        .toList();

    // Cached but no longer offered: retired, or outside this kid's grade now.
    final toRemove =
        cached.keys.where((id) => !wanted.containsKey(id)).toList();

    final upToDate = manifest.entries.length - toFetch.length;

    final verified = <Map<String, Object?>>[];
    final rejected = <String>[];
    final unavailable = <String>[];

    for (var i = 0; i < toFetch.length; i += ContentApi.fetchChunkSize) {
      final chunk = toFetch.sublist(
        i,
        (i + ContentApi.fetchChunkSize).clamp(0, toFetch.length),
      );

      final result = await api.fetchExercises(ids: chunk, accessToken: token);

      switch (result) {
        case ExercisesFetched(:final envelopes, unavailable: final missing):
          unavailable.addAll(missing);
          for (final envelope in envelopes) {
            final id = envelope['exercise_id'] as String?;
            if (id == null) continue;

            final expected = wanted[id]?.contentHash;
            final actual = contentSha256(envelope);

            if (expected == null || actual != expected) {
              // Truncated, tampered with, or the manifest moved under us.
              // Refusing is the only safe answer: a kid must never be shown
              // content we cannot vouch for.
              rejected.add(id);
              continue;
            }
            verified.add(envelope);
          }
        case ExercisesOffline():
          // Mid-sync network loss. Whatever verified so far is still good, so
          // commit it rather than throwing the work away — the next sync picks
          // up the rest.
          await _commit(verified, const []);
          return SyncReport(
            upToDate: upToDate,
            downloaded: verified.length,
            removed: 0,
            rejected: rejected,
            unavailable: unavailable,
            offline: true,
          );
        case ExercisesFailed(:final detail):
          await _commit(verified, const []);
          return SyncReport(
            upToDate: upToDate,
            downloaded: verified.length,
            removed: 0,
            rejected: rejected,
            unavailable: unavailable,
            error: detail,
          );
      }
    }

    await _commit(verified, toRemove);

    return SyncReport(
      upToDate: upToDate,
      downloaded: verified.length,
      removed: toRemove.length,
      rejected: rejected,
      unavailable: unavailable,
    );
  }

  /// Write verified content and drop withdrawn content in one transaction.
  ///
  /// Atomicity is what makes a failed sync harmless: either the cache moves
  /// forward as a whole or it does not move at all. A half-applied swap could
  /// leave an exercise whose content and checksum disagree, which the next
  /// sync would then re-download forever.
  Future<void> _commit(
    List<Map<String, Object?>> verified,
    List<String> removeIds,
  ) async {
    if (verified.isEmpty && removeIds.isEmpty) return;

    await db.transaction(() async {
      for (final envelope in verified) {
        await db.into(db.exerciseCacheTable).insertOnConflictUpdate(
              ExerciseCacheTableCompanion.insert(
                exerciseId: envelope['exercise_id'] as String,
                version: envelope['version'] as int,
                payload: jsonEncode(envelope),
                contentHash: contentSha256(envelope),
                engineKey: envelope['engine_key'] as String,
                skillNodeId: envelope['skill_node_id'] as String,
                subject: envelope['subject'] as String,
                grade: envelope['grade'] as int,
                rank: envelope['rank'] as int,
                cachedAt: _now(),
              ),
            );
      }

      if (removeIds.isNotEmpty) {
        await (db.delete(db.exerciseCacheTable)
              ..where((t) => t.exerciseId.isIn(removeIds)))
            .go();
      }
    });
  }

  // --- offline reads ----------------------------------------------------

  /// Cached exercises for a subject, in play order.
  ///
  /// This is the read the play screen uses, and it never touches the network —
  /// which is what makes an airplane-mode session possible.
  Future<List<Map<String, Object?>>> cachedExercises({
    String? subject,
    int? grade,
  }) async {
    final query = db.select(db.exerciseCacheTable)
      ..orderBy([
        (t) => OrderingTerm.asc(t.subject),
        (t) => OrderingTerm.asc(t.rank),
      ]);

    if (subject != null) query.where((t) => t.subject.equals(subject));
    if (grade != null) query.where((t) => t.grade.equals(grade));

    final rows = await query.get();
    return rows
        .map((row) => jsonDecode(row.payload) as Map<String, Object?>)
        .toList(growable: false);
  }

  /// One cached exercise, or null if it was never downloaded.
  Future<Map<String, Object?>?> cachedExercise(String exerciseId) async {
    final row = await (db.select(db.exerciseCacheTable)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.payload) as Map<String, Object?>;
  }

  Future<int> cachedCount() async {
    final count = db.exerciseCacheTable.exerciseId.count();
    final query = db.selectOnly(db.exerciseCacheTable)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Re-verify everything on disk against its stored checksum.
  ///
  /// Guards against disk corruption rather than a bad download: a flipped bit
  /// in SQLite would otherwise surface as a broken exercise in front of a kid.
  Future<List<String>> verifyCache() async {
    final corrupt = <String>[];
    for (final row in await db.select(db.exerciseCacheTable).get()) {
      final envelope = jsonDecode(row.payload) as Map<String, Object?>;
      if (contentSha256(envelope) != row.contentHash) {
        corrupt.add(row.exerciseId);
      }
    }
    return corrupt;
  }
}
