import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

@DriftDatabase(
  tables: [
    EventOutboxTable,
    ExerciseCacheTable,
    EngineSettingsTable,
    AppStateTable,
  ],
)
// Timestamp storage is configured in build.yaml
// (store_date_time_values_as_text) — see the rationale there.
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.e);

  /// In-memory instance for tests.
  LocalDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

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
        },
      );
}

/// Opens the on-disk database in the platform's application support directory.
Future<LocalDatabase> openLocalDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final file = File(p.join(directory.path, 'tutolys.sqlite'));
  return LocalDatabase(NativeDatabase.createInBackground(file));
}
