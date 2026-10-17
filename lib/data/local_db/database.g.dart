// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EventOutboxTableTable extends EventOutboxTable
    with TableInfo<$EventOutboxTableTable, OutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventOutboxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    payload,
    queuedAt,
    attempts,
    nextRetryAt,
    deliveredAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  OutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvent(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}delivered_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $EventOutboxTableTable createAlias(String alias) {
    return $EventOutboxTableTable(attachedDatabase, alias);
  }
}

class OutboxEvent extends DataClass implements Insertable<OutboxEvent> {
  /// Client-generated, and the idempotency key the server dedupes on. Primary
  /// key here too, so an in-app retry cannot enqueue the same event twice.
  final String eventId;

  /// The full event as JSON. Stored opaquely on purpose: the outbox must not
  /// need to understand the schema it carries, so a schema bump needs no
  /// migration here.
  final String payload;

  /// Ordering. Events upload oldest-first so a tutor report reconstructs the
  /// attempt sequence correctly.
  final DateTime queuedAt;

  /// How many upload attempts have been made. Drives the backoff.
  final int attempts;

  /// Earliest time this event may be retried. Null means "now".
  final DateTime? nextRetryAt;

  /// Set once the server has acknowledged it. Rows are kept briefly rather
  /// than deleted immediately, so a crash mid-acknowledgement cannot lose the
  /// record of what was already delivered.
  final DateTime? deliveredAt;

  /// Last failure, for diagnostics. Never shown to a kid.
  final String? lastError;
  const OutboxEvent({
    required this.eventId,
    required this.payload,
    required this.queuedAt,
    required this.attempts,
    this.nextRetryAt,
    this.deliveredAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['payload'] = Variable<String>(payload);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  EventOutboxTableCompanion toCompanion(bool nullToAbsent) {
    return EventOutboxTableCompanion(
      eventId: Value(eventId),
      payload: Value(payload),
      queuedAt: Value(queuedAt),
      attempts: Value(attempts),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      payload: serializer.fromJson<String>(json['payload']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'payload': serializer.toJson<String>(payload),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxEvent copyWith({
    String? eventId,
    String? payload,
    DateTime? queuedAt,
    int? attempts,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> deliveredAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => OutboxEvent(
    eventId: eventId ?? this.eventId,
    payload: payload ?? this.payload,
    queuedAt: queuedAt ?? this.queuedAt,
    attempts: attempts ?? this.attempts,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxEvent copyWithCompanion(EventOutboxTableCompanion data) {
    return OutboxEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      payload: data.payload.present ? data.payload.value : this.payload,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvent(')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    payload,
    queuedAt,
    attempts,
    nextRetryAt,
    deliveredAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvent &&
          other.eventId == this.eventId &&
          other.payload == this.payload &&
          other.queuedAt == this.queuedAt &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.deliveredAt == this.deliveredAt &&
          other.lastError == this.lastError);
}

class EventOutboxTableCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<String> eventId;
  final Value<String> payload;
  final Value<DateTime> queuedAt;
  final Value<int> attempts;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> deliveredAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const EventOutboxTableCompanion({
    this.eventId = const Value.absent(),
    this.payload = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventOutboxTableCompanion.insert({
    required String eventId,
    required String payload,
    required DateTime queuedAt,
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       payload = Value(payload),
       queuedAt = Value(queuedAt);
  static Insertable<OutboxEvent> custom({
    Expression<String>? eventId,
    Expression<String>? payload,
    Expression<DateTime>? queuedAt,
    Expression<int>? attempts,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? deliveredAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (payload != null) 'payload': payload,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventOutboxTableCompanion copyWith({
    Value<String>? eventId,
    Value<String>? payload,
    Value<DateTime>? queuedAt,
    Value<int>? attempts,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime?>? deliveredAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return EventOutboxTableCompanion(
      eventId: eventId ?? this.eventId,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventOutboxTableCompanion(')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseCacheTableTable extends ExerciseCacheTable
    with TableInfo<$ExerciseCacheTableTable, CachedExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineKeyMeta = const VerificationMeta(
    'engineKey',
  );
  @override
  late final GeneratedColumn<String> engineKey = GeneratedColumn<String>(
    'engine_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillNodeIdMeta = const VerificationMeta(
    'skillNodeId',
  );
  @override
  late final GeneratedColumn<String> skillNodeId = GeneratedColumn<String>(
    'skill_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
    'grade',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<int> rank = GeneratedColumn<int>(
    'rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    exerciseId,
    version,
    payload,
    contentHash,
    engineKey,
    skillNodeId,
    subject,
    grade,
    rank,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('engine_key')) {
      context.handle(
        _engineKeyMeta,
        engineKey.isAcceptableOrUnknown(data['engine_key']!, _engineKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_engineKeyMeta);
    }
    if (data.containsKey('skill_node_id')) {
      context.handle(
        _skillNodeIdMeta,
        skillNodeId.isAcceptableOrUnknown(
          data['skill_node_id']!,
          _skillNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_skillNodeIdMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
        _gradeMeta,
        grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta),
      );
    } else if (isInserting) {
      context.missing(_gradeMeta);
    }
    if (data.containsKey('rank')) {
      context.handle(
        _rankMeta,
        rank.isAcceptableOrUnknown(data['rank']!, _rankMeta),
      );
    } else if (isInserting) {
      context.missing(_rankMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseId};
  @override
  CachedExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedExercise(
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      engineKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_key'],
      )!,
      skillNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_node_id'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade'],
      )!,
      rank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rank'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $ExerciseCacheTableTable createAlias(String alias) {
    return $ExerciseCacheTableTable(attachedDatabase, alias);
  }
}

class CachedExercise extends DataClass implements Insertable<CachedExercise> {
  final String exerciseId;
  final int version;

  /// The served envelope, verbatim.
  final String payload;

  /// The server's checksum. Compared against the manifest to decide whether
  /// this row is stale, so one changed exercise does not invalidate the rest.
  final String contentHash;
  final String engineKey;
  final String skillNodeId;
  final String subject;
  final int grade;
  final int rank;
  final DateTime cachedAt;
  const CachedExercise({
    required this.exerciseId,
    required this.version,
    required this.payload,
    required this.contentHash,
    required this.engineKey,
    required this.skillNodeId,
    required this.subject,
    required this.grade,
    required this.rank,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_id'] = Variable<String>(exerciseId);
    map['version'] = Variable<int>(version);
    map['payload'] = Variable<String>(payload);
    map['content_hash'] = Variable<String>(contentHash);
    map['engine_key'] = Variable<String>(engineKey);
    map['skill_node_id'] = Variable<String>(skillNodeId);
    map['subject'] = Variable<String>(subject);
    map['grade'] = Variable<int>(grade);
    map['rank'] = Variable<int>(rank);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ExerciseCacheTableCompanion toCompanion(bool nullToAbsent) {
    return ExerciseCacheTableCompanion(
      exerciseId: Value(exerciseId),
      version: Value(version),
      payload: Value(payload),
      contentHash: Value(contentHash),
      engineKey: Value(engineKey),
      skillNodeId: Value(skillNodeId),
      subject: Value(subject),
      grade: Value(grade),
      rank: Value(rank),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedExercise(
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      version: serializer.fromJson<int>(json['version']),
      payload: serializer.fromJson<String>(json['payload']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      engineKey: serializer.fromJson<String>(json['engineKey']),
      skillNodeId: serializer.fromJson<String>(json['skillNodeId']),
      subject: serializer.fromJson<String>(json['subject']),
      grade: serializer.fromJson<int>(json['grade']),
      rank: serializer.fromJson<int>(json['rank']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseId': serializer.toJson<String>(exerciseId),
      'version': serializer.toJson<int>(version),
      'payload': serializer.toJson<String>(payload),
      'contentHash': serializer.toJson<String>(contentHash),
      'engineKey': serializer.toJson<String>(engineKey),
      'skillNodeId': serializer.toJson<String>(skillNodeId),
      'subject': serializer.toJson<String>(subject),
      'grade': serializer.toJson<int>(grade),
      'rank': serializer.toJson<int>(rank),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedExercise copyWith({
    String? exerciseId,
    int? version,
    String? payload,
    String? contentHash,
    String? engineKey,
    String? skillNodeId,
    String? subject,
    int? grade,
    int? rank,
    DateTime? cachedAt,
  }) => CachedExercise(
    exerciseId: exerciseId ?? this.exerciseId,
    version: version ?? this.version,
    payload: payload ?? this.payload,
    contentHash: contentHash ?? this.contentHash,
    engineKey: engineKey ?? this.engineKey,
    skillNodeId: skillNodeId ?? this.skillNodeId,
    subject: subject ?? this.subject,
    grade: grade ?? this.grade,
    rank: rank ?? this.rank,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedExercise copyWithCompanion(ExerciseCacheTableCompanion data) {
    return CachedExercise(
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      version: data.version.present ? data.version.value : this.version,
      payload: data.payload.present ? data.payload.value : this.payload,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      engineKey: data.engineKey.present ? data.engineKey.value : this.engineKey,
      skillNodeId: data.skillNodeId.present
          ? data.skillNodeId.value
          : this.skillNodeId,
      subject: data.subject.present ? data.subject.value : this.subject,
      grade: data.grade.present ? data.grade.value : this.grade,
      rank: data.rank.present ? data.rank.value : this.rank,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedExercise(')
          ..write('exerciseId: $exerciseId, ')
          ..write('version: $version, ')
          ..write('payload: $payload, ')
          ..write('contentHash: $contentHash, ')
          ..write('engineKey: $engineKey, ')
          ..write('skillNodeId: $skillNodeId, ')
          ..write('subject: $subject, ')
          ..write('grade: $grade, ')
          ..write('rank: $rank, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    exerciseId,
    version,
    payload,
    contentHash,
    engineKey,
    skillNodeId,
    subject,
    grade,
    rank,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedExercise &&
          other.exerciseId == this.exerciseId &&
          other.version == this.version &&
          other.payload == this.payload &&
          other.contentHash == this.contentHash &&
          other.engineKey == this.engineKey &&
          other.skillNodeId == this.skillNodeId &&
          other.subject == this.subject &&
          other.grade == this.grade &&
          other.rank == this.rank &&
          other.cachedAt == this.cachedAt);
}

class ExerciseCacheTableCompanion extends UpdateCompanion<CachedExercise> {
  final Value<String> exerciseId;
  final Value<int> version;
  final Value<String> payload;
  final Value<String> contentHash;
  final Value<String> engineKey;
  final Value<String> skillNodeId;
  final Value<String> subject;
  final Value<int> grade;
  final Value<int> rank;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ExerciseCacheTableCompanion({
    this.exerciseId = const Value.absent(),
    this.version = const Value.absent(),
    this.payload = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.engineKey = const Value.absent(),
    this.skillNodeId = const Value.absent(),
    this.subject = const Value.absent(),
    this.grade = const Value.absent(),
    this.rank = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseCacheTableCompanion.insert({
    required String exerciseId,
    required int version,
    required String payload,
    required String contentHash,
    required String engineKey,
    required String skillNodeId,
    required String subject,
    required int grade,
    required int rank,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       version = Value(version),
       payload = Value(payload),
       contentHash = Value(contentHash),
       engineKey = Value(engineKey),
       skillNodeId = Value(skillNodeId),
       subject = Value(subject),
       grade = Value(grade),
       rank = Value(rank),
       cachedAt = Value(cachedAt);
  static Insertable<CachedExercise> custom({
    Expression<String>? exerciseId,
    Expression<int>? version,
    Expression<String>? payload,
    Expression<String>? contentHash,
    Expression<String>? engineKey,
    Expression<String>? skillNodeId,
    Expression<String>? subject,
    Expression<int>? grade,
    Expression<int>? rank,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (version != null) 'version': version,
      if (payload != null) 'payload': payload,
      if (contentHash != null) 'content_hash': contentHash,
      if (engineKey != null) 'engine_key': engineKey,
      if (skillNodeId != null) 'skill_node_id': skillNodeId,
      if (subject != null) 'subject': subject,
      if (grade != null) 'grade': grade,
      if (rank != null) 'rank': rank,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseCacheTableCompanion copyWith({
    Value<String>? exerciseId,
    Value<int>? version,
    Value<String>? payload,
    Value<String>? contentHash,
    Value<String>? engineKey,
    Value<String>? skillNodeId,
    Value<String>? subject,
    Value<int>? grade,
    Value<int>? rank,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return ExerciseCacheTableCompanion(
      exerciseId: exerciseId ?? this.exerciseId,
      version: version ?? this.version,
      payload: payload ?? this.payload,
      contentHash: contentHash ?? this.contentHash,
      engineKey: engineKey ?? this.engineKey,
      skillNodeId: skillNodeId ?? this.skillNodeId,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      rank: rank ?? this.rank,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (engineKey.present) {
      map['engine_key'] = Variable<String>(engineKey.value);
    }
    if (skillNodeId.present) {
      map['skill_node_id'] = Variable<String>(skillNodeId.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (rank.present) {
      map['rank'] = Variable<int>(rank.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseCacheTableCompanion(')
          ..write('exerciseId: $exerciseId, ')
          ..write('version: $version, ')
          ..write('payload: $payload, ')
          ..write('contentHash: $contentHash, ')
          ..write('engineKey: $engineKey, ')
          ..write('skillNodeId: $skillNodeId, ')
          ..write('subject: $subject, ')
          ..write('grade: $grade, ')
          ..write('rank: $rank, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EngineSettingsTableTable extends EngineSettingsTable
    with TableInfo<$EngineSettingsTableTable, EngineSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EngineSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _engineKeyMeta = const VerificationMeta(
    'engineKey',
  );
  @override
  late final GeneratedColumn<String> engineKey = GeneratedColumn<String>(
    'engine_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  @override
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [engineKey, settingKey, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'engine_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EngineSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('engine_key')) {
      context.handle(
        _engineKeyMeta,
        engineKey.isAcceptableOrUnknown(data['engine_key']!, _engineKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_engineKeyMeta);
    }
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {engineKey, settingKey};
  @override
  EngineSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EngineSettingRow(
      engineKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine_key'],
      )!,
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $EngineSettingsTableTable createAlias(String alias) {
    return $EngineSettingsTableTable(attachedDatabase, alias);
  }
}

class EngineSettingRow extends DataClass
    implements Insertable<EngineSettingRow> {
  final String engineKey;
  final String settingKey;

  /// JSON-encoded, so one column holds bool, number or string without a
  /// per-type column or a migration when a new setting type appears.
  final String value;
  const EngineSettingRow({
    required this.engineKey,
    required this.settingKey,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['engine_key'] = Variable<String>(engineKey);
    map['setting_key'] = Variable<String>(settingKey);
    map['value'] = Variable<String>(value);
    return map;
  }

  EngineSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return EngineSettingsTableCompanion(
      engineKey: Value(engineKey),
      settingKey: Value(settingKey),
      value: Value(value),
    );
  }

  factory EngineSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EngineSettingRow(
      engineKey: serializer.fromJson<String>(json['engineKey']),
      settingKey: serializer.fromJson<String>(json['settingKey']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'engineKey': serializer.toJson<String>(engineKey),
      'settingKey': serializer.toJson<String>(settingKey),
      'value': serializer.toJson<String>(value),
    };
  }

  EngineSettingRow copyWith({
    String? engineKey,
    String? settingKey,
    String? value,
  }) => EngineSettingRow(
    engineKey: engineKey ?? this.engineKey,
    settingKey: settingKey ?? this.settingKey,
    value: value ?? this.value,
  );
  EngineSettingRow copyWithCompanion(EngineSettingsTableCompanion data) {
    return EngineSettingRow(
      engineKey: data.engineKey.present ? data.engineKey.value : this.engineKey,
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EngineSettingRow(')
          ..write('engineKey: $engineKey, ')
          ..write('settingKey: $settingKey, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(engineKey, settingKey, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EngineSettingRow &&
          other.engineKey == this.engineKey &&
          other.settingKey == this.settingKey &&
          other.value == this.value);
}

class EngineSettingsTableCompanion extends UpdateCompanion<EngineSettingRow> {
  final Value<String> engineKey;
  final Value<String> settingKey;
  final Value<String> value;
  final Value<int> rowid;
  const EngineSettingsTableCompanion({
    this.engineKey = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EngineSettingsTableCompanion.insert({
    required String engineKey,
    required String settingKey,
    required String value,
    this.rowid = const Value.absent(),
  }) : engineKey = Value(engineKey),
       settingKey = Value(settingKey),
       value = Value(value);
  static Insertable<EngineSettingRow> custom({
    Expression<String>? engineKey,
    Expression<String>? settingKey,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (engineKey != null) 'engine_key': engineKey,
      if (settingKey != null) 'setting_key': settingKey,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EngineSettingsTableCompanion copyWith({
    Value<String>? engineKey,
    Value<String>? settingKey,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return EngineSettingsTableCompanion(
      engineKey: engineKey ?? this.engineKey,
      settingKey: settingKey ?? this.settingKey,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (engineKey.present) {
      map['engine_key'] = Variable<String>(engineKey.value);
    }
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EngineSettingsTableCompanion(')
          ..write('engineKey: $engineKey, ')
          ..write('settingKey: $settingKey, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppStateTableTable extends AppStateTable
    with TableInfo<$AppStateTableTable, AppStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppStateTableTable createAlias(String alias) {
    return $AppStateTableTable(attachedDatabase, alias);
  }
}

class AppStateRow extends DataClass implements Insertable<AppStateRow> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppStateRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppStateTableCompanion toCompanion(bool nullToAbsent) {
    return AppStateTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppStateRow copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppStateRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppStateRow copyWithCompanion(AppStateTableCompanion data) {
    return AppStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppStateTableCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppStateTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateTableCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppStateTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppStateTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $EventOutboxTableTable eventOutboxTable = $EventOutboxTableTable(
    this,
  );
  late final $ExerciseCacheTableTable exerciseCacheTable =
      $ExerciseCacheTableTable(this);
  late final $EngineSettingsTableTable engineSettingsTable =
      $EngineSettingsTableTable(this);
  late final $AppStateTableTable appStateTable = $AppStateTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventOutboxTable,
    exerciseCacheTable,
    engineSettingsTable,
    appStateTable,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$EventOutboxTableTableCreateCompanionBuilder =
    EventOutboxTableCompanion Function({
      required String eventId,
      required String payload,
      required DateTime queuedAt,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> deliveredAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$EventOutboxTableTableUpdateCompanionBuilder =
    EventOutboxTableCompanion Function({
      Value<String> eventId,
      Value<String> payload,
      Value<DateTime> queuedAt,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<DateTime?> deliveredAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$EventOutboxTableTableFilterComposer
    extends Composer<_$LocalDatabase, $EventOutboxTableTable> {
  $$EventOutboxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventOutboxTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $EventOutboxTableTable> {
  $$EventOutboxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventOutboxTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $EventOutboxTableTable> {
  $$EventOutboxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$EventOutboxTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $EventOutboxTableTable,
          OutboxEvent,
          $$EventOutboxTableTableFilterComposer,
          $$EventOutboxTableTableOrderingComposer,
          $$EventOutboxTableTableAnnotationComposer,
          $$EventOutboxTableTableCreateCompanionBuilder,
          $$EventOutboxTableTableUpdateCompanionBuilder,
          (
            OutboxEvent,
            BaseReferences<
              _$LocalDatabase,
              $EventOutboxTableTable,
              OutboxEvent
            >,
          ),
          OutboxEvent,
          PrefetchHooks Function()
        > {
  $$EventOutboxTableTableTableManager(
    _$LocalDatabase db,
    $EventOutboxTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventOutboxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventOutboxTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventOutboxTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventOutboxTableCompanion(
                eventId: eventId,
                payload: payload,
                queuedAt: queuedAt,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                deliveredAt: deliveredAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String payload,
                required DateTime queuedAt,
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventOutboxTableCompanion.insert(
                eventId: eventId,
                payload: payload,
                queuedAt: queuedAt,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                deliveredAt: deliveredAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventOutboxTableTable, OutboxEvent>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $EventOutboxTableTable,
                    OutboxEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventOutboxTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $EventOutboxTableTable,
      OutboxEvent,
      $$EventOutboxTableTableFilterComposer,
      $$EventOutboxTableTableOrderingComposer,
      $$EventOutboxTableTableAnnotationComposer,
      $$EventOutboxTableTableCreateCompanionBuilder,
      $$EventOutboxTableTableUpdateCompanionBuilder,
      (
        OutboxEvent,
        BaseReferences<_$LocalDatabase, $EventOutboxTableTable, OutboxEvent>,
      ),
      OutboxEvent,
      PrefetchHooks Function()
    >;
typedef $$ExerciseCacheTableTableCreateCompanionBuilder =
    ExerciseCacheTableCompanion Function({
      required String exerciseId,
      required int version,
      required String payload,
      required String contentHash,
      required String engineKey,
      required String skillNodeId,
      required String subject,
      required int grade,
      required int rank,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$ExerciseCacheTableTableUpdateCompanionBuilder =
    ExerciseCacheTableCompanion Function({
      Value<String> exerciseId,
      Value<int> version,
      Value<String> payload,
      Value<String> contentHash,
      Value<String> engineKey,
      Value<String> skillNodeId,
      Value<String> subject,
      Value<int> grade,
      Value<int> rank,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$ExerciseCacheTableTableFilterComposer
    extends Composer<_$LocalDatabase, $ExerciseCacheTableTable> {
  $$ExerciseCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engineKey => $composableBuilder(
    column: $table.engineKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillNodeId => $composableBuilder(
    column: $table.skillNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseCacheTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $ExerciseCacheTableTable> {
  $$ExerciseCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engineKey => $composableBuilder(
    column: $table.engineKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillNodeId => $composableBuilder(
    column: $table.skillNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grade => $composableBuilder(
    column: $table.grade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rank => $composableBuilder(
    column: $table.rank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseCacheTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ExerciseCacheTableTable> {
  $$ExerciseCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engineKey =>
      $composableBuilder(column: $table.engineKey, builder: (column) => column);

  GeneratedColumn<String> get skillNodeId => $composableBuilder(
    column: $table.skillNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<int> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ExerciseCacheTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ExerciseCacheTableTable,
          CachedExercise,
          $$ExerciseCacheTableTableFilterComposer,
          $$ExerciseCacheTableTableOrderingComposer,
          $$ExerciseCacheTableTableAnnotationComposer,
          $$ExerciseCacheTableTableCreateCompanionBuilder,
          $$ExerciseCacheTableTableUpdateCompanionBuilder,
          (
            CachedExercise,
            BaseReferences<
              _$LocalDatabase,
              $ExerciseCacheTableTable,
              CachedExercise
            >,
          ),
          CachedExercise,
          PrefetchHooks Function()
        > {
  $$ExerciseCacheTableTableTableManager(
    _$LocalDatabase db,
    $ExerciseCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> exerciseId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<String> engineKey = const Value.absent(),
                Value<String> skillNodeId = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<int> grade = const Value.absent(),
                Value<int> rank = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseCacheTableCompanion(
                exerciseId: exerciseId,
                version: version,
                payload: payload,
                contentHash: contentHash,
                engineKey: engineKey,
                skillNodeId: skillNodeId,
                subject: subject,
                grade: grade,
                rank: rank,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseId,
                required int version,
                required String payload,
                required String contentHash,
                required String engineKey,
                required String skillNodeId,
                required String subject,
                required int grade,
                required int rank,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExerciseCacheTableCompanion.insert(
                exerciseId: exerciseId,
                version: version,
                payload: payload,
                contentHash: contentHash,
                engineKey: engineKey,
                skillNodeId: skillNodeId,
                subject: subject,
                grade: grade,
                rank: rank,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseCacheTableTable, CachedExercise>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $ExerciseCacheTableTable,
                    CachedExercise
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ExerciseCacheTableTable,
      CachedExercise,
      $$ExerciseCacheTableTableFilterComposer,
      $$ExerciseCacheTableTableOrderingComposer,
      $$ExerciseCacheTableTableAnnotationComposer,
      $$ExerciseCacheTableTableCreateCompanionBuilder,
      $$ExerciseCacheTableTableUpdateCompanionBuilder,
      (
        CachedExercise,
        BaseReferences<
          _$LocalDatabase,
          $ExerciseCacheTableTable,
          CachedExercise
        >,
      ),
      CachedExercise,
      PrefetchHooks Function()
    >;
typedef $$EngineSettingsTableTableCreateCompanionBuilder =
    EngineSettingsTableCompanion Function({
      required String engineKey,
      required String settingKey,
      required String value,
      Value<int> rowid,
    });
typedef $$EngineSettingsTableTableUpdateCompanionBuilder =
    EngineSettingsTableCompanion Function({
      Value<String> engineKey,
      Value<String> settingKey,
      Value<String> value,
      Value<int> rowid,
    });

class $$EngineSettingsTableTableFilterComposer
    extends Composer<_$LocalDatabase, $EngineSettingsTableTable> {
  $$EngineSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get engineKey => $composableBuilder(
    column: $table.engineKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EngineSettingsTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $EngineSettingsTableTable> {
  $$EngineSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get engineKey => $composableBuilder(
    column: $table.engineKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EngineSettingsTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $EngineSettingsTableTable> {
  $$EngineSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get engineKey =>
      $composableBuilder(column: $table.engineKey, builder: (column) => column);

  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$EngineSettingsTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $EngineSettingsTableTable,
          EngineSettingRow,
          $$EngineSettingsTableTableFilterComposer,
          $$EngineSettingsTableTableOrderingComposer,
          $$EngineSettingsTableTableAnnotationComposer,
          $$EngineSettingsTableTableCreateCompanionBuilder,
          $$EngineSettingsTableTableUpdateCompanionBuilder,
          (
            EngineSettingRow,
            BaseReferences<
              _$LocalDatabase,
              $EngineSettingsTableTable,
              EngineSettingRow
            >,
          ),
          EngineSettingRow,
          PrefetchHooks Function()
        > {
  $$EngineSettingsTableTableTableManager(
    _$LocalDatabase db,
    $EngineSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EngineSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EngineSettingsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EngineSettingsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> engineKey = const Value.absent(),
                Value<String> settingKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EngineSettingsTableCompanion(
                engineKey: engineKey,
                settingKey: settingKey,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String engineKey,
                required String settingKey,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => EngineSettingsTableCompanion.insert(
                engineKey: engineKey,
                settingKey: settingKey,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EngineSettingsTableTable, EngineSettingRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $EngineSettingsTableTable,
                    EngineSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EngineSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $EngineSettingsTableTable,
      EngineSettingRow,
      $$EngineSettingsTableTableFilterComposer,
      $$EngineSettingsTableTableOrderingComposer,
      $$EngineSettingsTableTableAnnotationComposer,
      $$EngineSettingsTableTableCreateCompanionBuilder,
      $$EngineSettingsTableTableUpdateCompanionBuilder,
      (
        EngineSettingRow,
        BaseReferences<
          _$LocalDatabase,
          $EngineSettingsTableTable,
          EngineSettingRow
        >,
      ),
      EngineSettingRow,
      PrefetchHooks Function()
    >;
typedef $$AppStateTableTableCreateCompanionBuilder =
    AppStateTableCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppStateTableTableUpdateCompanionBuilder =
    AppStateTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppStateTableTableFilterComposer
    extends Composer<_$LocalDatabase, $AppStateTableTable> {
  $$AppStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppStateTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $AppStateTableTable> {
  $$AppStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppStateTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $AppStateTableTable> {
  $$AppStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppStateTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $AppStateTableTable,
          AppStateRow,
          $$AppStateTableTableFilterComposer,
          $$AppStateTableTableOrderingComposer,
          $$AppStateTableTableAnnotationComposer,
          $$AppStateTableTableCreateCompanionBuilder,
          $$AppStateTableTableUpdateCompanionBuilder,
          (
            AppStateRow,
            BaseReferences<_$LocalDatabase, $AppStateTableTable, AppStateRow>,
          ),
          AppStateRow,
          PrefetchHooks Function()
        > {
  $$AppStateTableTableTableManager(
    _$LocalDatabase db,
    $AppStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppStateTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppStateTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppStateTableTable, AppStateRow>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $AppStateTableTable,
                    AppStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $AppStateTableTable,
      AppStateRow,
      $$AppStateTableTableFilterComposer,
      $$AppStateTableTableOrderingComposer,
      $$AppStateTableTableAnnotationComposer,
      $$AppStateTableTableCreateCompanionBuilder,
      $$AppStateTableTableUpdateCompanionBuilder,
      (
        AppStateRow,
        BaseReferences<_$LocalDatabase, $AppStateTableTable, AppStateRow>,
      ),
      AppStateRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$EventOutboxTableTableTableManager get eventOutboxTable =>
      $$EventOutboxTableTableTableManager(_db, _db.eventOutboxTable);
  $$ExerciseCacheTableTableTableManager get exerciseCacheTable =>
      $$ExerciseCacheTableTableTableManager(_db, _db.exerciseCacheTable);
  $$EngineSettingsTableTableTableManager get engineSettingsTable =>
      $$EngineSettingsTableTableTableManager(_db, _db.engineSettingsTable);
  $$AppStateTableTableTableManager get appStateTable =>
      $$AppStateTableTableTableManager(_db, _db.appStateTable);
}
