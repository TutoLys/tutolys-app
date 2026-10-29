import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/content_api.dart';
import '../local_db/database.dart';
import 'asset_kind.dart';
import 'content_in_use.dart';
import 'content_hash.dart';
import 'lesson_key.dart';
import 'window_plan.dart';

/// What a sync did, so the UI and the logs can say something specific.
class SyncReport {
  const SyncReport({
    required this.upToDate,
    required this.downloaded,
    required this.removed,
    required this.rejected,
    required this.unavailable,
    this.evicted = 0,
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
      evicted = 0,
      offline = true,
      unauthorized = false,
      error = null;

  const SyncReport.unauthorized()
    : upToDate = 0,
      downloaded = 0,
      removed = 0,
      rejected = const [],
      unavailable = const [],
      evicted = 0,
      offline = false,
      unauthorized = true,
      error = null;

  const SyncReport.failed(String this.error)
    : upToDate = 0,
      downloaded = 0,
      removed = 0,
      rejected = const [],
      unavailable = const [],
      evicted = 0,
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

  /// Dropped because their leaf left every paired kid's offline window
  /// (ADR 0093). Still published: a later window brings them back.
  final int evicted;

  final bool offline;
  final bool unauthorized;
  final String? error;

  bool get isOk => !offline && !unauthorized && error == null;
  bool get changedAnything => downloaded > 0 || removed > 0 || evicted > 0;
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
///
/// With a [planWindow] it keeps only the offline window (ADR 0093): the
/// playing kid's ~25 leaves per subject are downloaded, every paired kid's
/// are kept, and the rest is evicted once a sync completes.
class ContentSync {
  ContentSync({
    required this.db,
    required this.api,
    required this.accessToken,
    this.planWindow,
    ContentInUse? inUse,
    DateTime Function()? clock,
  }) : inUse = inUse ?? ContentInUse(),
       _now = clock ?? DateTime.now;

  final LocalDatabase db;
  final ContentApi api;

  /// Read per call: a sync may start long after the token it would have
  /// captured expired.
  final String? Function() accessToken;

  /// Null keeps the whole grade, as before the window: tests of the sync
  /// itself, and a device whose curriculum isn't cached yet.
  final Future<WindowPlan?> Function({
    required int grade,
    required String locale,
    required List<ManifestEntryLite> entries,
  })?
  planWindow;

  /// Exercises on screen: never evicted.
  final ContentInUse inUse;

  final DateTime Function() _now;

  /// Syncs in flight, by subject and language: a background prefetch and
  /// the Carte asking for the same subject share one pass.
  final _inflight = <String, Future<SyncReport>>{};

  /// [locale] is the language to ask for; see `subject_language.dart` for
  /// which one a subject wants.
  Future<SyncReport> sync({String? subject, String? locale}) {
    final key = '$subject|$locale';
    return _inflight[key] ??= _sync(subject: subject, locale: locale)
        .whenComplete(() {
          // A block, not an arrow: returning the removed future would make
          // whenComplete wait on itself.
          _inflight.remove(key);
        });
  }

  Future<SyncReport> _sync({String? subject, String? locale}) async {
    final token = accessToken();
    if (token == null || token.isEmpty) {
      return const SyncReport.unauthorized();
    }

    final manifestResult = await api.fetchManifest(
      accessToken: token,
      subject: subject,
      locale: locale,
    );

    return switch (manifestResult) {
      ManifestFetched(:final manifest) => _applyManifest(
        manifest,
        token,
        subject: subject,
        askedLocale: locale ?? manifest.locale,
      ),
      // Offline is not an error: cached content stays playable, which is the
      // entire point of caching it.
      ManifestOffline() => Future.value(const SyncReport.offline()),
      ManifestUnauthorized() => Future.value(const SyncReport.unauthorized()),
      ManifestFailed(:final detail) => Future.value(SyncReport.failed(detail)),
    };
  }

  Future<SyncReport> _applyManifest(
    ContentManifest manifest,
    String token, {
    String? subject,
    required String askedLocale,
  }) async {
    await _storeManifest(manifest, subject: subject, askedLocale: askedLocale);
    final plan = await planWindow?.call(
      grade: manifest.grade,
      locale: askedLocale,
      entries: [for (final e in manifest.entries) _lite(e)],
    );

    // Only this kid's own slice of the cache.
    //
    // The content tables are shared by every kid paired to this device
    // (ADR 0014) because content is identified by `(subject, grade)` and two
    // same-grade siblings read byte-identical rows. That sharing has exactly
    // one sharp edge, and it is here: reading the whole table would make
    // "cached but absent from my manifest" mean "withdrawn" *and* "belongs
    // to my sibling", so a grade-1 sync would delete a grade-3 sibling's
    // content, they would re-download it, and the two would thrash forever
    // — on what may be a metered connection.
    //
    // `manifest.grade` is the server's own answer for whose manifest this
    // is, derived from the device token rather than asked for, so it cannot
    // disagree with the entries it accompanies.
    final cachedQuery = db.select(db.exerciseCacheTable)
      ..where((t) => t.grade.equals(manifest.grade));
    if (subject != null) {
      cachedQuery.where((t) => t.subject.equals(subject));
    }

    final cachedRows = await cachedQuery.get();
    final cached = {
      for (final row in cachedRows) row.exerciseId: row.contentHash,
    };

    final wanted = {for (final e in manifest.entries) e.exerciseId: e};

    // The same lesson can be cached in two languages, each its own
    // exercise (backend ADR 0026). Keyed by lesson (`lessonKey`) → the
    // locales this manifest wants it in.
    final wantedLocales = <String, Set<String>>{};
    for (final e in manifest.entries) {
      wantedLocales
          .putIfAbsent(
            lessonKey(
              skillNodeId: e.skillNodeId,
              engineKey: e.engineKey,
              rank: e.rank,
              lessonGroup: e.lessonGroup,
            ),
            () => {},
          )
          .add(e.locale);
    }

    // Stale or missing, and inside the playing kid's window — the only
    // things worth bytes.
    final toFetch = manifest.entries
        .where((e) => plan == null || plan.fetch.contains(e.skillNodeId))
        .where((e) => cached[e.exerciseId] != e.contentHash)
        .map((e) => e.exerciseId)
        .toList();

    // Cached but no longer offered: retired, or outside this kid's grade now.
    //
    // Except a lesson's version in *another* language. Siblings on one
    // device share this cache and may have chosen different languages, and
    // one kid can switch back: deleting the French version because this
    // manifest asked for English would make the two re-download each other
    // forever. A version goes only when its lesson is wanted in no language
    // at all, or is wanted in its own language under a newer id.
    final toRemove = [
      for (final row in cachedRows)
        if (!wanted.containsKey(row.exerciseId))
          if (wantedLocales[_lessonKeyOfRow(row)] case final locales
              when locales == null || locales.contains(_localeOf(row.payload)))
            row.exerciseId,
    ];

    // Still published, but outside every paired kid's window. Never a
    // lesson someone is in the middle of or looking at.
    final protected = plan == null ? const <String>{} : await _protectedIds();
    final removing = toRemove.toSet();
    final toEvict = plan == null
        ? const <String>[]
        : [
            for (final row in cachedRows)
              if (!removing.contains(row.exerciseId) &&
                  !plan.keep.contains(row.skillNodeId) &&
                  !protected.contains(row.exerciseId))
                row.exerciseId,
          ];

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
      final chunkVerified = <Map<String, Object?>>[];

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
            chunkVerified.add(envelope);
          }
          // Committed as each chunk verifies, so an interrupted prefetch
          // resumes where it stopped: the checksum diff skips what's here.
          // A newer verified version never breaks the old one, so a failed
          // sync still leaves the cache playable.
          await _commit(chunkVerified, const []);
          await _syncAssets(chunkVerified, prune: false);
          verified.addAll(chunkVerified);
        case ExercisesOffline():
          // Mid-sync network loss. Whatever verified so far is committed;
          // nothing is removed — the next sync picks up the rest.
          return SyncReport(
            upToDate: upToDate,
            downloaded: verified.length,
            removed: 0,
            rejected: rejected,
            unavailable: unavailable,
            offline: true,
          );
        case ExercisesFailed(:final detail):
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

    // Only now, after a complete pass, does anything leave.
    await _commit(const [], toRemove, evictIds: toEvict);
    await pruneAudio();
    await pruneImages();

    return SyncReport(
      upToDate: upToDate,
      downloaded: verified.length,
      removed: toRemove.length,
      evicted: toEvict.length,
      rejected: rejected,
      unavailable: unavailable,
    );
  }

  static ManifestEntryLite _lite(ManifestEntry e) => ManifestEntryLite(
    exerciseId: e.exerciseId,
    skillNodeId: e.skillNodeId,
    subject: e.subject,
    rank: e.rank,
    engineKey: e.engineKey,
    locale: e.locale,
    lessonGroup: e.lessonGroup,
  );

  /// Replaces the stored manifest for this `(subject, grade, asked locale)`
  /// in one transaction (ADR 0093).
  Future<void> _storeManifest(
    ContentManifest manifest, {
    String? subject,
    required String askedLocale,
  }) => db.transaction(() async {
    final old = db.delete(db.manifestEntryTable)
      ..where(
        (t) =>
            t.grade.equals(manifest.grade) & t.askedLocale.equals(askedLocale),
      );
    if (subject != null) old.where((t) => t.subject.equals(subject));
    await old.go();
    await db.batch((b) {
      b.insertAllOnConflictUpdate(db.manifestEntryTable, [
        for (final e in manifest.entries)
          ManifestEntryTableCompanion.insert(
            askedLocale: askedLocale,
            exerciseId: e.exerciseId,
            skillNodeId: e.skillNodeId,
            subject: e.subject,
            grade: e.grade,
            rank: e.rank,
            engineKey: e.engineKey,
            contentHash: e.contentHash,
            locale: e.locale,
            lessonGroup: Value(e.lessonGroup),
          ),
      ]);
    });
  });

  /// The stored manifest for a subject at a grade, in the language asked.
  Future<List<ManifestEntryLite>> storedManifest({
    required String subject,
    required int grade,
    required String askedLocale,
  }) async => [
    for (final row
        in await (db.select(db.manifestEntryTable)..where(
              (t) =>
                  t.subject.equals(subject) &
                  t.grade.equals(grade) &
                  t.askedLocale.equals(askedLocale),
            ))
            .get())
      ManifestEntryLite.fromRow(row),
  ];

  /// Exercises with an unfinished game (any kid) or on screen now.
  Future<Set<String>> _protectedIds() async => {
    ...inUse.ids,
    for (final row in await (db.selectOnly(
      db.activitySessionTable,
    )..addColumns([db.activitySessionTable.exerciseId])).get())
      row.read(db.activitySessionTable.exerciseId)!,
  };

  /// Downloads one node's lessons now: a tap on a leaf outside the window
  /// (ADR 0093). Verified like any sync, then committed with its assets.
  Future<NodeDownload> downloadNode({
    required String skillNodeId,
    required int grade,
    required String askedLocale,
  }) async {
    final token = accessToken();
    if (token == null || token.isEmpty) return NodeDownload.offline;
    final rows =
        await (db.select(db.manifestEntryTable)..where(
              (t) =>
                  t.skillNodeId.equals(skillNodeId) &
                  t.grade.equals(grade) &
                  t.askedLocale.equals(askedLocale),
            ))
            .get();
    if (rows.isEmpty) return NodeDownload.failed;
    final expected = {for (final r in rows) r.exerciseId: r.contentHash};
    final result = await api.fetchExercises(
      ids: expected.keys.toList(),
      accessToken: token,
    );
    switch (result) {
      case ExercisesOffline():
        return NodeDownload.offline;
      case ExercisesFailed():
        return NodeDownload.failed;
      case ExercisesFetched(:final envelopes):
        final verified = [
          for (final envelope in envelopes)
            if (expected[envelope['exercise_id']] case final hash?
                when hash == contentSha256(envelope))
              envelope,
        ];
        if (verified.isEmpty) return NodeDownload.failed;
        await _commit(verified, const []);
        await _syncAssets(verified, prune: false);
        return NodeDownload.done;
    }
  }

  static const evictedKey = 'offline_window.evicted_total';
  static const lastEvictedKey = 'offline_window.last_evicted_at';
  static const removedAudioKey = 'audio_cache.removed_total';

  /// Removes audio no cached exercise owns any more, and counts it. Audio
  /// is keyed by exercise, so it goes with the last exercise that held it.
  Future<int> pruneAudio() => db.transaction(() async {
    final owned = db.selectOnly(db.exerciseCacheTable)
      ..addColumns([db.exerciseCacheTable.exerciseId]);
    final removed = await (db.delete(
      db.audioCacheTable,
    )..where((t) => t.exerciseId.isNotInQuery(owned))).go();
    if (removed > 0) {
      await _bump(removedAudioKey, removed, stampKey: null);
    }
    return removed;
  });

  /// Adds [by] to a device-scoped counter, and stamps [stampKey] with now.
  Future<void> _bump(String key, int by, {required String? stampKey}) async {
    final now = _now();
    final total = (await _counter(key)) + by;
    for (final (k, v) in [
      (key, '$total'),
      if (stampKey != null) (stampKey, now.toUtc().toIso8601String()),
    ]) {
      await db
          .into(db.appStateTable)
          .insertOnConflictUpdate(
            AppStateTableCompanion.insert(
              kidId: deviceScope,
              key: k,
              value: v,
              updatedAt: now,
            ),
          );
    }
  }

  Future<String?> _deviceValue(String key) async =>
      (await (db.select(db.appStateTable)
                ..where((t) => t.kidId.equals(deviceScope) & t.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Future<int> _counter(String key) async =>
      int.tryParse(await _deviceValue(key) ?? '') ?? 0;

  /// What the offline window holds and has evicted: for the technical log
  /// and for tests (ADR 0093). Nothing here leaves the device.
  Future<OfflineStats> offlineStats() async {
    final subjects = <String, SubjectCacheSize>{};
    for (final row
        in await db
            .customSelect(
              'SELECT subject, COUNT(DISTINCT skill_node_id) AS leaves, '
              'COUNT(*) AS exercises, SUM(LENGTH(payload)) AS bytes '
              'FROM exercise_cache GROUP BY subject',
              readsFrom: {db.exerciseCacheTable},
            )
            .get()) {
      subjects[row.read<String>('subject')] = SubjectCacheSize(
        leaves: row.read<int>('leaves'),
        exercises: row.read<int>('exercises'),
        contentBytes: row.read<int>('bytes'),
        audioBytes: 0,
      );
    }
    for (final row
        in await db
            .customSelect(
              'SELECT e.subject AS subject, SUM(LENGTH(a.bytes)) AS bytes '
              'FROM audio_cache a JOIN exercise_cache e '
              'ON a.exercise_id = e.exercise_id GROUP BY e.subject',
              readsFrom: {db.audioCacheTable, db.exerciseCacheTable},
            )
            .get()) {
      final subject = row.read<String>('subject');
      final size = subjects[subject];
      if (size == null) continue;
      subjects[subject] = size.withAudio(row.read<int>('bytes'));
    }
    final images = await db
        .customSelect(
          'SELECT COALESCE(SUM(size_bytes), 0) AS bytes FROM asset_cache',
          readsFrom: {db.assetCacheTable},
        )
        .getSingle();
    return OfflineStats(
      bySubject: subjects,
      imageBytes: images.read<int>('bytes'),
      evictedTotal: await _counter(evictedKey),
      lastEvictedAt: DateTime.tryParse(
        await _deviceValue(lastEvictedKey) ?? '',
      ),
      audioRemovedTotal: await _counter(removedAudioKey),
      imagesRemovedTotal: await imagesRemovedTotal(),
    );
  }

  /// Audio, then pictures, for newly verified envelopes; then drop
  /// pictures no cached exercise points at any more.
  Future<void> _syncAssets(
    List<Map<String, Object?>> envelopes, {
    bool prune = true,
  }) async {
    await _syncAudio(envelopes);
    await _syncImages(envelopes);
    if (prune) await pruneImages();
  }

  /// Download and cache every audio asset referenced by newly-verified
  /// envelopes (`assets[]`, `{ref, url, sha256}`).
  ///
  /// Best-effort, on purpose: a missing or failed audio download is never
  /// fatal to a sync the way a bad exercise checksum is — the text prompt
  /// still works, and the next sync simply tries again for whatever's
  /// still missing (nothing here marks an asset "tried and gave up").
  Future<void> _syncAudio(List<Map<String, Object?>> envelopes) async {
    if (envelopes.isEmpty) return;

    final cached = {
      for (final row in await db.select(db.audioCacheTable).get())
        (row.exerciseId, row.ref): row.sha256,
    };

    for (final envelope in envelopes) {
      final exerciseId = envelope['exercise_id'] as String?;
      final assets = envelope['assets'] as List?;
      if (exerciseId == null || assets == null) continue;

      for (final asset in assets.cast<Map<String, Object?>>()) {
        final ref = asset['ref'] as String?;
        final url = asset['url'] as String?;
        final sha256 = asset['sha256'] as String?;
        if (ref == null || url == null || sha256 == null) continue;
        if (assetKindOf(asset) != AssetKind.audio) continue;
        if (cached[(exerciseId, ref)] == sha256) continue; // already have it

        // The same clip under another exercise (a translation that kept
        // its audio, a lesson re-published): copy it, don't download it.
        final local =
            await (db.select(db.audioCacheTable)
                  ..where((t) => t.sha256.equals(sha256))
                  ..limit(1))
                .getSingleOrNull();
        final result = local != null && bytesSha256(local.bytes) == sha256
            ? AudioFetched(local.bytes)
            : await api.fetchAudio(url);
        if (result is! AudioFetched) continue; // offline or a server error

        final actualHash = bytesSha256(result.bytes);
        if (actualHash != sha256) {
          // Truncated or tampered with — the exact same refusal
          // `_applyManifest` already gives a bad exercise checksum.
          continue;
        }

        await db
            .into(db.audioCacheTable)
            .insertOnConflictUpdate(
              AudioCacheTableCompanion.insert(
                exerciseId: exerciseId,
                ref: ref,
                bytes: result.bytes,
                sha256: actualHash,
                cachedAt: _now(),
              ),
            );
      }
    }
  }

  /// Download every picture newly verified envelopes reference, into the
  /// content-addressed `asset_cache` (ADR 0027).
  ///
  /// Same posture as audio: best-effort, verified against the manifest's
  /// sha256, and a picture that fails to arrive is simply tried again next
  /// sync — the engine shows the item's label meanwhile. Keyed by hash, so
  /// a picture two lessons share is downloaded once.
  Future<void> _syncImages(List<Map<String, Object?>> envelopes) async {
    final have = {
      for (final row in await (db.selectOnly(
        db.assetCacheTable,
      )..addColumns([db.assetCacheTable.sha256])).get())
        row.read(db.assetCacheTable.sha256)!,
    };

    for (final envelope in envelopes) {
      final assets = envelope['assets'] as List?;
      if (assets == null) continue;
      for (final asset in assets.cast<Map<String, Object?>>()) {
        final url = asset['url'] as String?;
        final sha256 = asset['sha256'] as String?;
        final mediaType = imageMediaTypeOf(asset);
        if (url == null || sha256 == null || mediaType == null) continue;
        if (have.contains(sha256)) continue;

        final result = await api.fetchAsset(url);
        if (result is! AudioFetched) continue; // offline or a server error
        if (bytesSha256(result.bytes) != sha256) continue; // refuse it

        await db
            .into(db.assetCacheTable)
            .insertOnConflictUpdate(
              AssetCacheTableCompanion.insert(
                sha256: sha256,
                mediaType: mediaType,
                bytes: result.bytes,
                sizeBytes: result.bytes.length,
                cachedAt: _now(),
              ),
            );
        have.add(sha256);
      }
    }
  }

  static const removedImagesKey = 'asset_cache.removed_total';
  static const lastRemovedImagesKey = 'asset_cache.last_removed_at';

  /// Removes every cached picture that no cached exercise references, and
  /// returns how many. Never silent: the running total and the time of the
  /// last removal are kept in device-scoped `app_state`.
  Future<int> pruneImages() async {
    final wanted = <String>{};
    for (final row in await db.select(db.exerciseCacheTable).get()) {
      final assets =
          (jsonDecode(row.payload) as Map<String, Object?>)['assets'] as List?;
      for (final asset in (assets ?? const []).cast<Map<String, Object?>>()) {
        if (imageMediaTypeOf(asset) == null) continue;
        if (asset['sha256'] case final String sha) wanted.add(sha);
      }
    }

    return db.transaction(() async {
      final removed = await (db.delete(
        db.assetCacheTable,
      )..where((t) => t.sha256.isNotIn(wanted))).go();
      if (removed == 0) return 0;

      final now = _now();
      final total = (await imagesRemovedTotal()) + removed;
      for (final (key, value) in [
        (removedImagesKey, '$total'),
        (lastRemovedImagesKey, now.toUtc().toIso8601String()),
      ]) {
        await db
            .into(db.appStateTable)
            .insertOnConflictUpdate(
              AppStateTableCompanion.insert(
                kidId: deviceScope,
                key: key,
                value: value,
                updatedAt: now,
              ),
            );
      }
      return removed;
    });
  }

  /// Pictures ever removed from this device's cache by [pruneImages].
  Future<int> imagesRemovedTotal() async {
    final row =
        await (db.select(db.appStateTable)..where(
              (t) =>
                  t.kidId.equals(deviceScope) & t.key.equals(removedImagesKey),
            ))
            .getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  /// Write verified content and drop withdrawn content in one transaction.
  ///
  /// Atomicity is what makes a failed sync harmless: either the cache moves
  /// forward as a whole or it does not move at all. A half-applied swap could
  /// leave an exercise whose content and checksum disagree, which the next
  /// sync would then re-download forever.
  ///
  /// [evictIds] leave in the same transaction, and are counted and
  /// timestamped there (ADR 0093): never silently.
  Future<void> _commit(
    List<Map<String, Object?>> verified,
    List<String> removeIds, {
    List<String> evictIds = const [],
  }) async {
    if (verified.isEmpty && removeIds.isEmpty && evictIds.isEmpty) return;

    await db.transaction(() async {
      for (final envelope in verified) {
        await db
            .into(db.exerciseCacheTable)
            .insertOnConflictUpdate(
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
        await (db.delete(
          db.exerciseCacheTable,
        )..where((t) => t.exerciseId.isIn(removeIds))).go();
      }
      if (evictIds.isNotEmpty) {
        final evicted = await (db.delete(
          db.exerciseCacheTable,
        )..where((t) => t.exerciseId.isIn(evictIds))).go();
        if (evicted > 0) {
          await _bump(evictedKey, evicted, stampKey: lastEvictedKey);
        }
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

  /// [lessonKey] for a cached row; a payload that won't parse still gets
  /// the fallback key from its columns.
  static String _lessonKeyOfRow(CachedExercise row) {
    String? group;
    try {
      group =
          (jsonDecode(row.payload) as Map<String, Object?>)['lesson_group']
              as String?;
    } on Object {
      group = null;
    }
    return lessonKey(
      skillNodeId: row.skillNodeId,
      engineKey: row.engineKey,
      rank: row.rank,
      lessonGroup: group,
    );
  }

  /// The language a cached envelope is in. Envelopes have always carried
  /// `locale`; anything older or malformed counts as French, the default.
  static String _localeOf(String payload) {
    try {
      return ((jsonDecode(payload) as Map<String, Object?>)['locale']
              as String?) ??
          'fr-CA';
    } on Object {
      return 'fr-CA';
    }
  }

  /// One cached exercise, or null if it was never downloaded.
  Future<Map<String, Object?>?> cachedExercise(String exerciseId) async {
    final row = await (db.select(
      db.exerciseCacheTable,
    )..where((t) => t.exerciseId.equals(exerciseId))).getSingleOrNull();
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

/// What a tap on a not-downloaded leaf got.
enum NodeDownload { done, offline, failed }

/// One subject's share of the offline cache.
class SubjectCacheSize {
  const SubjectCacheSize({
    required this.leaves,
    required this.exercises,
    required this.contentBytes,
    required this.audioBytes,
  });

  final int leaves;
  final int exercises;
  final int contentBytes;
  final int audioBytes;

  int get bytes => contentBytes + audioBytes;

  SubjectCacheSize withAudio(int audio) => SubjectCacheSize(
    leaves: leaves,
    exercises: exercises,
    contentBytes: contentBytes,
    audioBytes: audio,
  );
}

/// [ContentSync.offlineStats]: sizes and the never-silent eviction counts.
class OfflineStats {
  const OfflineStats({
    required this.bySubject,
    required this.imageBytes,
    required this.evictedTotal,
    required this.lastEvictedAt,
    required this.audioRemovedTotal,
    required this.imagesRemovedTotal,
  });

  final Map<String, SubjectCacheSize> bySubject;

  /// Pictures are shared across subjects (content-addressed), so counted
  /// once, not per subject.
  final int imageBytes;
  final int evictedTotal;
  final DateTime? lastEvictedAt;
  final int audioRemovedTotal;
  final int imagesRemovedTotal;

  /// For the technical log: one line per subject, then the counters.
  List<String> describe() => [
    for (final MapEntry(key: subject, value: size) in bySubject.entries)
      'offline $subject: ${size.leaves} leaves, ${size.exercises} lessons, '
          '${_kb(size.bytes)}',
    'offline images: ${_kb(imageBytes)}',
    'offline evicted: $evictedTotal'
        '${lastEvictedAt == null ? '' : ' (last ${lastEvictedAt!.toUtc().toIso8601String()})'}'
        ', audio removed: $audioRemovedTotal, images removed: $imagesRemovedTotal',
  ];

  static String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';
}
