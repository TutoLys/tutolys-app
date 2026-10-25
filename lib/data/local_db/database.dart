import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'memory_connection.dart';

part 'database.g.dart';

/// Durable local state (plan §5.8).
///
/// The outbox is the important one, and it is not a cache: an event is only
/// "logged" once it is on disk here. Buffering in memory and flushing on a
/// timer loses the last minute of play every time the app is killed — and the
/// end of a session is exactly where the interesting signal is.
@DataClassName('OutboxEvent')
class EventOutboxTable extends Table {
  @override
  String get tableName => 'event_outbox';

  /// Client-generated, and the idempotency key the server dedupes on. Primary
  /// key here too, so an in-app retry cannot enqueue the same event twice.
  TextColumn get eventId => text().named('event_id')();

  /// Which kid played this. The flusher uploads each event with *that kid's*
  /// device token, so without this column an event queued by one child on a
  /// shared tablet could be uploaded as another — silently corrupting the
  /// per-kid mastery data the whole product exists to produce (ADR 0014).
  ///
  /// Not part of the primary key: `event_id` is a UUID and the server's own
  /// idempotency key, so it is already globally unique on its own.
  TextColumn get kidId => text().named('kid_id')();

  /// The full event as JSON. Stored opaquely on purpose: the outbox must not
  /// need to understand the schema it carries, so a schema bump needs no
  /// migration here.
  TextColumn get payload => text()();

  /// Ordering. Events upload oldest-first so a tutor report reconstructs the
  /// attempt sequence correctly.
  DateTimeColumn get queuedAt => dateTime().named('queued_at')();

  /// How many upload attempts have been made. Drives the backoff.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Earliest time this event may be retried. Null means "now".
  DateTimeColumn get nextRetryAt =>
      dateTime().named('next_retry_at').nullable()();

  /// Set once the server has acknowledged it. Rows are kept briefly rather
  /// than deleted immediately, so a crash mid-acknowledgement cannot lose the
  /// record of what was already delivered.
  DateTimeColumn get deliveredAt =>
      dateTime().named('delivered_at').nullable()();

  /// Last failure, for diagnostics. Never shown to a kid.
  TextColumn get lastError => text().named('last_error').nullable()();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// Cached exercise content, so a kid can play with no network.
@DataClassName('CachedExercise')
class ExerciseCacheTable extends Table {
  @override
  String get tableName => 'exercise_cache';

  TextColumn get exerciseId => text().named('exercise_id')();
  IntColumn get version => integer()();

  /// The served envelope, verbatim.
  TextColumn get payload => text()();

  /// The server's checksum. Compared against the manifest to decide whether
  /// this row is stale, so one changed exercise does not invalidate the rest.
  TextColumn get contentHash => text().named('content_hash')();

  TextColumn get engineKey => text().named('engine_key')();
  TextColumn get skillNodeId => text().named('skill_node_id')();
  TextColumn get subject => text()();
  IntColumn get grade => integer()();
  IntColumn get rank => integer()();

  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {exerciseId};
}

/// Cached exercise audio — the "read the question aloud" button plays
/// straight from this, never the network, so it works offline the same
/// way the exercise content itself already does.
///
/// A separate table from [ExerciseCacheTable], not a column on it: one
/// exercise can have several questions, each with its own audio, and a
/// blob column on the exercise row would mean re-downloading every
/// question's audio whenever any one of them changed.
@DataClassName('CachedAudio')
class AudioCacheTable extends Table {
  @override
  String get tableName => 'audio_cache';

  TextColumn get exerciseId => text().named('exercise_id')();

  /// Matches a `prompt.audio_ref` value — `"audio"` for a single-question
  /// exercise, `"q0_audio"`/`"q1_audio"`/... for a multi-question one.
  TextColumn get ref => text()();

  BlobColumn get bytes => blob()();

  /// The server's checksum, verified again on every read via
  /// [ContentSync.verifyCache]'s same reasoning for exercise content:
  /// a flipped bit in SQLite must surface as "play it safe and
  /// re-download", not a corrupted clip played to a kid.
  TextColumn get sha256 => text()();

  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {exerciseId, ref};
}

/// Downloaded picture assets, **content-addressed**: one row per sha256,
/// so lessons that use the same picture keep a single copy (ADR 0027).
///
/// Which picture an `image_ref` means is the exercise's own business: its
/// cached envelope's `assets[]` maps the ref to a sha256, and this table
/// holds the bytes for that hash. Shared across kids, like the exercise
/// cache it serves. A row no cached exercise points at any more is removed
/// after the next sync, and every removal is counted (`app_state`).
class AssetCacheTable extends Table {
  @override
  String get tableName => 'asset_cache';

  TextColumn get sha256 => text()();

  /// `image/webp`, `image/png`, … — from the asset's `media_type`, or
  /// inferred from its URL for content published before that field.
  TextColumn get mediaType => text().named('media_type')();

  BlobColumn get bytes => blob()();

  IntColumn get sizeBytes => integer().named('size_bytes')();

  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {sha256};
}

/// Cached curriculum leaves for the path screen (A7).
///
/// Flat, not a tree — no parent/child columns, matching the backend
/// endpoint's own flat response. A7's path UI is a plain list, not a
/// traversal; a richer tree cache is a later extension, not built ahead of
/// a screen that would use it.
@DataClassName('CachedSkillNode')
class SkillNodeTable extends Table {
  @override
  String get tableName => 'skill_node_cache';

  TextColumn get id => text()();
  TextColumn get labelFr => text().named('label_fr')();
  TextColumn get labelEn => text().named('label_en')();
  TextColumn get stableKey => text().named('stable_key')();
  TextColumn get subject => text()();
  IntColumn get grade => integer()();

  /// Document order, strand and learning area as the curriculum endpoint
  /// sends them (schema v7, backend ADR 0044). Null on rows cached before
  /// that, until the next sync refills them.
  IntColumn get docOrder => integer().named('doc_order').nullable()();
  TextColumn get strandKey => text().named('strand_key').nullable()();
  TextColumn get strandLabelFr => text().named('strand_label_fr').nullable()();
  TextColumn get strandLabelEn => text().named('strand_label_en').nullable()();
  TextColumn get areaLabelFr => text().named('area_label_fr').nullable()();
  TextColumn get areaLabelEn => text().named('area_label_en').nullable()();
  IntColumn get areaOrdinal => integer().named('area_ordinal').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local overrides for per-engine settings (plan §5.5: app-side, never server).
@DataClassName('EngineSettingRow')
class EngineSettingsTable extends Table {
  @override
  String get tableName => 'engine_settings';

  /// One kid wants hints on and the next does not, so a setting belongs to a
  /// kid rather than to the device (ADR 0014).
  TextColumn get kidId => text().named('kid_id')();

  TextColumn get engineKey => text().named('engine_key')();
  TextColumn get settingKey => text().named('setting_key')();

  /// JSON-encoded, so one column holds bool, number or string without a
  /// per-type column or a migration when a new setting type appears.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {kidId, engineKey, settingKey};
}

/// Small key/value store for session and sync bookkeeping.
@DataClassName('AppStateRow')
class AppStateTable extends Table {
  @override
  String get tableName => 'app_state';

  /// Which kid owns this key, or [deviceScope] for device-level bookkeeping.
  ///
  /// This table holds both kinds: `home_stats.*` is a per-kid daily counter,
  /// while `outbox_capacity.*` counts evictions for the device's whole
  /// outbox. A sentinel rather than a nullable column on purpose — SQLite
  /// permits NULL in any primary-key column that is not `INTEGER PRIMARY
  /// KEY`, and NULLs compare distinct, so a nullable owner here would
  /// silently allow unlimited duplicate device-level rows (ADR 0014).
  TextColumn get kidId => text().named('kid_id')();

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {kidId, key};
}

/// One row per local calendar date with at least one completed exercise —
/// plan §5.8's own streak rule ("a day counts if at least one completed
/// exercise has event_ts on that local date"), kept independently of
/// `EventOutboxTable` so the streak survives that table's own 6-hour
/// delivered-row pruning. Unlike the outbox this is permanent and tiny (one
/// row per day ever played, not per event), so it is never pruned.
@DataClassName('PlayedDateRow')
class PlayedDateTable extends Table {
  @override
  String get tableName => 'played_date';

  /// Whose streak this is (ADR 0014). Two siblings on one tablet keep
  /// separate streaks; without this, either child playing would extend both.
  TextColumn get kidId => text().named('kid_id')();

  /// ISO `yyyy-MM-dd`, local date — not a `DateTimeColumn`, so "the same
  /// calendar day" never depends on a stored time-of-day or timezone.
  TextColumn get date => text()();

  @override
  Set<Column> get primaryKey => {kidId, date};
}

/// In-progress activity sessions, so a session survives the app being
/// killed mid-question (architecture doc §5.4, ADR 0019).
///
/// One row per live session. The row is written in the same transaction as
/// the step's outbox events (`DriftActivitySessionStore.commit`) and deleted
/// in the transaction that records the session's end, so a row here always
/// means "unfinished, and everything it did is already in the outbox".
@DataClassName('ActivitySessionRow')
class ActivitySessionTable extends Table {
  @override
  String get tableName => 'activity_session';

  TextColumn get activitySessionId => text().named('activity_session_id')();

  /// Per kid, like everything else a child produces (ADR 0014).
  TextColumn get kidId => text().named('kid_id')();

  TextColumn get exerciseId => text().named('exercise_id')();

  /// `SessionSnapshot.toJson()`. One JSON column rather than a column per
  /// field: the snapshot is versioned by its own reader, which rejects what
  /// it can't trust, so its shape can grow without a migration.
  TextColumn get snapshot => text()();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {activitySessionId};
}

/// The `kid_id` value for rows that belong to the device rather than to any
/// one kid — today only `app_state`'s `outbox_capacity.*` bookkeeping.
///
/// A real value, not NULL, for the reason spelled out on
/// [AppStateTable.kidId]: SQLite would let NULLs pile up as distinct
/// primary keys.
const String deviceScope = '';

@DriftDatabase(
  tables: [
    EventOutboxTable,
    ExerciseCacheTable,
    SkillNodeTable,
    EngineSettingsTable,
    AppStateTable,
    PlayedDateTable,
    AudioCacheTable,
    ActivitySessionTable,
    AssetCacheTable,
  ],
)
// Timestamp storage is configured in build.yaml
// (store_date_time_values_as_text) — see the rationale there.
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e, {this.migrationKidId});

  /// In-memory instance for tests.
  LocalDatabase.memory({this.migrationKidId}) : super(memoryExecutor());

  /// Resolves the owner lazily, when the migration actually needs it.

  /// The kid whose data is already on disk, for the 3 → 4 upgrade.
  ///
  /// Before v4 a device meant exactly one kid, so every existing row is
  /// theirs and the upgrade backfills this id rather than discarding data.
  /// Passed in rather than read here because it lives in `SessionStore`'s
  /// platform secure store: a drift migration that reached for
  /// `flutter_secure_storage` would be untestable and would couple the
  /// schema to the platform (ADR 0014).
  ///
  /// Null means the device was never paired — there is nothing worth
  /// keeping, and the pre-v4 rows are dropped instead of being backfilled
  /// to an owner that does not exist.
  ///
  /// Prefer [migrationKidIdLoader] in the running app: resolving this value
  /// eagerly would mean awaiting the platform secure store *before*
  /// `runApp`, so a slow or stalled read would hold the app on its splash
  /// screen with nothing on screen to explain why. The migration is already
  /// async, so it can just as well await the value itself — and only on the
  /// one boot that actually upgrades.
  final String? migrationKidId;

  /// Async form of [migrationKidId], awaited inside the migration.
  ///
  /// Set by `openLocalDatabase`; tests use [migrationKidId] directly. When
  /// both are set this one wins.
  Future<String?> Function()? migrationKidIdLoader;

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // Foreign keys are off by default in SQLite, which silently turns
      // a constraint into a suggestion.
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (m) async {
      await m.createAll();
      // Pending events, oldest first — the query the flusher runs every
      // time it wakes up.
      await customStatement(
        'CREATE INDEX IF NOT EXISTS event_outbox_pending '
        'ON event_outbox (delivered_at, queued_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS exercise_cache_lookup '
        'ON exercise_cache (grade, subject, rank)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS skill_node_cache_lookup '
        'ON skill_node_cache (subject, grade)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS event_outbox_kid '
        'ON event_outbox (kid_id, delivered_at, queued_at)',
      );
      await _createActivitySessionIndex();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playedDateTable);
      }
      if (from < 3) {
        await m.createTable(audioCacheTable);
      }
      if (from < 4) {
        await _addKidScope(m);
      }
      if (from < 5) {
        await m.createTable(activitySessionTable);
        await _createActivitySessionIndex();
      }
      if (from < 6) {
        await m.createTable(assetCacheTable);
      }
      // Bounded by `to` too: a migration test that stops at an older
      // version must not get these columns.
      if (from < 7 && to >= 7) {
        for (final column in [
          skillNodeTable.docOrder,
          skillNodeTable.strandKey,
          skillNodeTable.strandLabelFr,
          skillNodeTable.strandLabelEn,
          skillNodeTable.areaLabelFr,
          skillNodeTable.areaLabelEn,
          skillNodeTable.areaOrdinal,
        ]) {
          await m.addColumn(skillNodeTable, column);
        }
      }
    },
  );

  /// "This kid's unfinished session for this exercise" — the lookup the
  /// play screen makes before starting anything.
  Future<void> _createActivitySessionIndex() => customStatement(
    'CREATE INDEX IF NOT EXISTS activity_session_lookup '
    'ON activity_session (kid_id, exercise_id)',
  );

  /// The 3 → 4 upgrade: give the per-kid tables an owner (ADR 0014).
  ///
  /// `played_date`, `engine_settings` and `app_state` gain `kid_id` *inside*
  /// their primary key, so SQLite has to rebuild them — `alterTable` does
  /// that. `event_outbox` only gains a plain column.
  Future<void> _addKidScope(Migrator m) async {
    final owner = migrationKidIdLoader != null
        ? await migrationKidIdLoader!()
        : migrationKidId;

    if (owner == null) {
      // Never paired: the rows belong to nobody. Backfilling them to an
      // owner that does not exist would resurrect them under whichever kid
      // pairs next, attributing a stranger's play to them.
      await delete(eventOutboxTable).go();
      await delete(playedDateTable).go();
      await delete(engineSettingsTable).go();
      await delete(appStateTable).go();
    }

    final backfill = Variable<String>(owner ?? deviceScope);

    await m.alterTable(
      TableMigration(
        eventOutboxTable,
        columnTransformer: {eventOutboxTable.kidId: backfill},
        newColumns: [eventOutboxTable.kidId],
      ),
    );
    await m.alterTable(
      TableMigration(
        playedDateTable,
        columnTransformer: {playedDateTable.kidId: backfill},
        newColumns: [playedDateTable.kidId],
      ),
    );
    await m.alterTable(
      TableMigration(
        engineSettingsTable,
        columnTransformer: {engineSettingsTable.kidId: backfill},
        newColumns: [engineSettingsTable.kidId],
      ),
    );

    // `app_state` is the mixed one: its `home_stats.*` keys belong to the
    // kid, its `outbox_capacity.*` keys to the device. Everything lands on
    // the device sentinel first, then the kid's own keys move across — a
    // whitelist, so a key added later defaults to device scope rather than
    // being silently attributed to whoever happened to be paired.
    await m.alterTable(
      TableMigration(
        appStateTable,
        columnTransformer: {appStateTable.kidId: Variable<String>(deviceScope)},
        newColumns: [appStateTable.kidId],
      ),
    );
    if (owner != null) {
      await customStatement(
        "UPDATE app_state SET kid_id = ? WHERE key LIKE 'home_stats.%'",
        [owner],
      );
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS event_outbox_kid '
      'ON event_outbox (kid_id, delivered_at, queued_at)',
    );
  }
}

/// Opens the real on-disk (or browser-persisted) database for the running
/// app — `drift_flutter`'s `driftDatabase` picks the right backend per
/// platform: `NativeDatabase` in the platform's application-support
/// directory on Linux/desktop, `WasmDatabase` (IndexedDB/OPFS, picked by
/// feature-detection) on web. ADR 0002 covers why this needs its own
/// conditional backend at all — `database.dart` previously imported
/// `drift/native.dart` (`dart:ffi`) unconditionally, which doesn't compile
/// for web. `sqlite3.wasm` and `drift_worker.js` in `web/` (pinned to
/// drift 2.35.2, the version in `pubspec.yaml`) are what the web backend
/// actually loads.
///
/// [migrationKidId] resolves the kid already paired on this device, needed
/// only by the 3 → 4 upgrade — see [LocalDatabase.migrationKidId]. It is a
/// callback rather than a value so that boot never waits on the platform
/// secure store: drift opens lazily and runs the migration on the first
/// query, so the read happens there, off the path to `runApp`.
///
/// Resolving to null when a kid *is* paired silently discards their local
/// streak and queued events, so the callback must read `SessionStore`, not
/// guess.
LocalDatabase openLocalDatabase({Future<String?> Function()? migrationKidId}) {
  return LocalDatabase(
    driftDatabase(
      name: 'tutolys',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  )..migrationKidIdLoader = migrationKidId;
}
