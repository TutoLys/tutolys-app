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

  @override
  Set<Column> get primaryKey => {id};
}

/// Local overrides for per-engine settings (plan §5.5: app-side, never server).
@DataClassName('EngineSettingRow')
class EngineSettingsTable extends Table {
  @override
  String get tableName => 'engine_settings';

  TextColumn get engineKey => text().named('engine_key')();
  TextColumn get settingKey => text().named('setting_key')();

  /// JSON-encoded, so one column holds bool, number or string without a
  /// per-type column or a migration when a new setting type appears.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {engineKey, settingKey};
}

/// Small key/value store for session and sync bookkeeping.
@DataClassName('AppStateRow')
class AppStateTable extends Table {
  @override
  String get tableName => 'app_state';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {key};
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

  /// ISO `yyyy-MM-dd`, local date — not a `DateTimeColumn`, so "the same
  /// calendar day" never depends on a stored time-of-day or timezone.
  TextColumn get date => text()();

  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(
  tables: [
    EventOutboxTable,
    ExerciseCacheTable,
    SkillNodeTable,
    EngineSettingsTable,
    AppStateTable,
    PlayedDateTable,
    AudioCacheTable,
  ],
)
// Timestamp storage is configured in build.yaml
// (store_date_time_values_as_text) — see the rationale there.
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  /// In-memory instance for tests.
  LocalDatabase.memory() : super(memoryExecutor());

  @override
  int get schemaVersion => 3;

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
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playedDateTable);
      }
      if (from < 3) {
        await m.createTable(audioCacheTable);
      }
    },
  );
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
LocalDatabase openLocalDatabase() {
  return LocalDatabase(
    driftDatabase(
      name: 'tutolys',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );
}
