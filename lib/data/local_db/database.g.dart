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
  static const VerificationMeta _kidIdMeta = const VerificationMeta('kidId');
  @override
  late final GeneratedColumn<String> kidId = GeneratedColumn<String>(
    'kid_id',
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
    kidId,
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
    if (data.containsKey('kid_id')) {
      context.handle(
        _kidIdMeta,
        kidId.isAcceptableOrUnknown(data['kid_id']!, _kidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kidIdMeta);
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
      kidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid_id'],
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

  /// Which kid played this. The flusher uploads each event with *that kid's*
  /// device token, so without this column an event queued by one child on a
  /// shared tablet could be uploaded as another — silently corrupting the
  /// per-kid mastery data the whole product exists to produce (ADR 0014).
  ///
  /// Not part of the primary key: `event_id` is a UUID and the server's own
  /// idempotency key, so it is already globally unique on its own.
  final String kidId;

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
    required this.kidId,
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
    map['kid_id'] = Variable<String>(kidId);
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
      kidId: Value(kidId),
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
      kidId: serializer.fromJson<String>(json['kidId']),
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
      'kidId': serializer.toJson<String>(kidId),
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
    String? kidId,
    String? payload,
    DateTime? queuedAt,
    int? attempts,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<DateTime?> deliveredAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => OutboxEvent(
    eventId: eventId ?? this.eventId,
    kidId: kidId ?? this.kidId,
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
      kidId: data.kidId.present ? data.kidId.value : this.kidId,
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
          ..write('kidId: $kidId, ')
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
    kidId,
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
          other.kidId == this.kidId &&
          other.payload == this.payload &&
          other.queuedAt == this.queuedAt &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.deliveredAt == this.deliveredAt &&
          other.lastError == this.lastError);
}

class EventOutboxTableCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<String> eventId;
  final Value<String> kidId;
  final Value<String> payload;
  final Value<DateTime> queuedAt;
  final Value<int> attempts;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime?> deliveredAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const EventOutboxTableCompanion({
    this.eventId = const Value.absent(),
    this.kidId = const Value.absent(),
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
    required String kidId,
    required String payload,
    required DateTime queuedAt,
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       kidId = Value(kidId),
       payload = Value(payload),
       queuedAt = Value(queuedAt);
  static Insertable<OutboxEvent> custom({
    Expression<String>? eventId,
    Expression<String>? kidId,
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
      if (kidId != null) 'kid_id': kidId,
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
    Value<String>? kidId,
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
      kidId: kidId ?? this.kidId,
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
    if (kidId.present) {
      map['kid_id'] = Variable<String>(kidId.value);
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
          ..write('kidId: $kidId, ')
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

class $SkillNodeTableTable extends SkillNodeTable
    with TableInfo<$SkillNodeTableTable, CachedSkillNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillNodeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelFrMeta = const VerificationMeta(
    'labelFr',
  );
  @override
  late final GeneratedColumn<String> labelFr = GeneratedColumn<String>(
    'label_fr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelEnMeta = const VerificationMeta(
    'labelEn',
  );
  @override
  late final GeneratedColumn<String> labelEn = GeneratedColumn<String>(
    'label_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stableKeyMeta = const VerificationMeta(
    'stableKey',
  );
  @override
  late final GeneratedColumn<String> stableKey = GeneratedColumn<String>(
    'stable_key',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    labelFr,
    labelEn,
    stableKey,
    subject,
    grade,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_node_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSkillNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label_fr')) {
      context.handle(
        _labelFrMeta,
        labelFr.isAcceptableOrUnknown(data['label_fr']!, _labelFrMeta),
      );
    } else if (isInserting) {
      context.missing(_labelFrMeta);
    }
    if (data.containsKey('label_en')) {
      context.handle(
        _labelEnMeta,
        labelEn.isAcceptableOrUnknown(data['label_en']!, _labelEnMeta),
      );
    } else if (isInserting) {
      context.missing(_labelEnMeta);
    }
    if (data.containsKey('stable_key')) {
      context.handle(
        _stableKeyMeta,
        stableKey.isAcceptableOrUnknown(data['stable_key']!, _stableKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_stableKeyMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedSkillNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSkillNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      labelFr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_fr'],
      )!,
      labelEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_en'],
      )!,
      stableKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stable_key'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      grade: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grade'],
      )!,
    );
  }

  @override
  $SkillNodeTableTable createAlias(String alias) {
    return $SkillNodeTableTable(attachedDatabase, alias);
  }
}

class CachedSkillNode extends DataClass implements Insertable<CachedSkillNode> {
  final String id;
  final String labelFr;
  final String labelEn;
  final String stableKey;
  final String subject;
  final int grade;
  const CachedSkillNode({
    required this.id,
    required this.labelFr,
    required this.labelEn,
    required this.stableKey,
    required this.subject,
    required this.grade,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label_fr'] = Variable<String>(labelFr);
    map['label_en'] = Variable<String>(labelEn);
    map['stable_key'] = Variable<String>(stableKey);
    map['subject'] = Variable<String>(subject);
    map['grade'] = Variable<int>(grade);
    return map;
  }

  SkillNodeTableCompanion toCompanion(bool nullToAbsent) {
    return SkillNodeTableCompanion(
      id: Value(id),
      labelFr: Value(labelFr),
      labelEn: Value(labelEn),
      stableKey: Value(stableKey),
      subject: Value(subject),
      grade: Value(grade),
    );
  }

  factory CachedSkillNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSkillNode(
      id: serializer.fromJson<String>(json['id']),
      labelFr: serializer.fromJson<String>(json['labelFr']),
      labelEn: serializer.fromJson<String>(json['labelEn']),
      stableKey: serializer.fromJson<String>(json['stableKey']),
      subject: serializer.fromJson<String>(json['subject']),
      grade: serializer.fromJson<int>(json['grade']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'labelFr': serializer.toJson<String>(labelFr),
      'labelEn': serializer.toJson<String>(labelEn),
      'stableKey': serializer.toJson<String>(stableKey),
      'subject': serializer.toJson<String>(subject),
      'grade': serializer.toJson<int>(grade),
    };
  }

  CachedSkillNode copyWith({
    String? id,
    String? labelFr,
    String? labelEn,
    String? stableKey,
    String? subject,
    int? grade,
  }) => CachedSkillNode(
    id: id ?? this.id,
    labelFr: labelFr ?? this.labelFr,
    labelEn: labelEn ?? this.labelEn,
    stableKey: stableKey ?? this.stableKey,
    subject: subject ?? this.subject,
    grade: grade ?? this.grade,
  );
  CachedSkillNode copyWithCompanion(SkillNodeTableCompanion data) {
    return CachedSkillNode(
      id: data.id.present ? data.id.value : this.id,
      labelFr: data.labelFr.present ? data.labelFr.value : this.labelFr,
      labelEn: data.labelEn.present ? data.labelEn.value : this.labelEn,
      stableKey: data.stableKey.present ? data.stableKey.value : this.stableKey,
      subject: data.subject.present ? data.subject.value : this.subject,
      grade: data.grade.present ? data.grade.value : this.grade,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSkillNode(')
          ..write('id: $id, ')
          ..write('labelFr: $labelFr, ')
          ..write('labelEn: $labelEn, ')
          ..write('stableKey: $stableKey, ')
          ..write('subject: $subject, ')
          ..write('grade: $grade')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, labelFr, labelEn, stableKey, subject, grade);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSkillNode &&
          other.id == this.id &&
          other.labelFr == this.labelFr &&
          other.labelEn == this.labelEn &&
          other.stableKey == this.stableKey &&
          other.subject == this.subject &&
          other.grade == this.grade);
}

class SkillNodeTableCompanion extends UpdateCompanion<CachedSkillNode> {
  final Value<String> id;
  final Value<String> labelFr;
  final Value<String> labelEn;
  final Value<String> stableKey;
  final Value<String> subject;
  final Value<int> grade;
  final Value<int> rowid;
  const SkillNodeTableCompanion({
    this.id = const Value.absent(),
    this.labelFr = const Value.absent(),
    this.labelEn = const Value.absent(),
    this.stableKey = const Value.absent(),
    this.subject = const Value.absent(),
    this.grade = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SkillNodeTableCompanion.insert({
    required String id,
    required String labelFr,
    required String labelEn,
    required String stableKey,
    required String subject,
    required int grade,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       labelFr = Value(labelFr),
       labelEn = Value(labelEn),
       stableKey = Value(stableKey),
       subject = Value(subject),
       grade = Value(grade);
  static Insertable<CachedSkillNode> custom({
    Expression<String>? id,
    Expression<String>? labelFr,
    Expression<String>? labelEn,
    Expression<String>? stableKey,
    Expression<String>? subject,
    Expression<int>? grade,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (labelFr != null) 'label_fr': labelFr,
      if (labelEn != null) 'label_en': labelEn,
      if (stableKey != null) 'stable_key': stableKey,
      if (subject != null) 'subject': subject,
      if (grade != null) 'grade': grade,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SkillNodeTableCompanion copyWith({
    Value<String>? id,
    Value<String>? labelFr,
    Value<String>? labelEn,
    Value<String>? stableKey,
    Value<String>? subject,
    Value<int>? grade,
    Value<int>? rowid,
  }) {
    return SkillNodeTableCompanion(
      id: id ?? this.id,
      labelFr: labelFr ?? this.labelFr,
      labelEn: labelEn ?? this.labelEn,
      stableKey: stableKey ?? this.stableKey,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (labelFr.present) {
      map['label_fr'] = Variable<String>(labelFr.value);
    }
    if (labelEn.present) {
      map['label_en'] = Variable<String>(labelEn.value);
    }
    if (stableKey.present) {
      map['stable_key'] = Variable<String>(stableKey.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillNodeTableCompanion(')
          ..write('id: $id, ')
          ..write('labelFr: $labelFr, ')
          ..write('labelEn: $labelEn, ')
          ..write('stableKey: $stableKey, ')
          ..write('subject: $subject, ')
          ..write('grade: $grade, ')
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
  static const VerificationMeta _kidIdMeta = const VerificationMeta('kidId');
  @override
  late final GeneratedColumn<String> kidId = GeneratedColumn<String>(
    'kid_id',
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
  List<GeneratedColumn> get $columns => [kidId, engineKey, settingKey, value];
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
    if (data.containsKey('kid_id')) {
      context.handle(
        _kidIdMeta,
        kidId.isAcceptableOrUnknown(data['kid_id']!, _kidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kidIdMeta);
    }
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
  Set<GeneratedColumn> get $primaryKey => {kidId, engineKey, settingKey};
  @override
  EngineSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EngineSettingRow(
      kidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid_id'],
      )!,
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
  /// One kid wants hints on and the next does not, so a setting belongs to a
  /// kid rather than to the device (ADR 0014).
  final String kidId;
  final String engineKey;
  final String settingKey;

  /// JSON-encoded, so one column holds bool, number or string without a
  /// per-type column or a migration when a new setting type appears.
  final String value;
  const EngineSettingRow({
    required this.kidId,
    required this.engineKey,
    required this.settingKey,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kid_id'] = Variable<String>(kidId);
    map['engine_key'] = Variable<String>(engineKey);
    map['setting_key'] = Variable<String>(settingKey);
    map['value'] = Variable<String>(value);
    return map;
  }

  EngineSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return EngineSettingsTableCompanion(
      kidId: Value(kidId),
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
      kidId: serializer.fromJson<String>(json['kidId']),
      engineKey: serializer.fromJson<String>(json['engineKey']),
      settingKey: serializer.fromJson<String>(json['settingKey']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kidId': serializer.toJson<String>(kidId),
      'engineKey': serializer.toJson<String>(engineKey),
      'settingKey': serializer.toJson<String>(settingKey),
      'value': serializer.toJson<String>(value),
    };
  }

  EngineSettingRow copyWith({
    String? kidId,
    String? engineKey,
    String? settingKey,
    String? value,
  }) => EngineSettingRow(
    kidId: kidId ?? this.kidId,
    engineKey: engineKey ?? this.engineKey,
    settingKey: settingKey ?? this.settingKey,
    value: value ?? this.value,
  );
  EngineSettingRow copyWithCompanion(EngineSettingsTableCompanion data) {
    return EngineSettingRow(
      kidId: data.kidId.present ? data.kidId.value : this.kidId,
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
          ..write('kidId: $kidId, ')
          ..write('engineKey: $engineKey, ')
          ..write('settingKey: $settingKey, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kidId, engineKey, settingKey, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EngineSettingRow &&
          other.kidId == this.kidId &&
          other.engineKey == this.engineKey &&
          other.settingKey == this.settingKey &&
          other.value == this.value);
}

class EngineSettingsTableCompanion extends UpdateCompanion<EngineSettingRow> {
  final Value<String> kidId;
  final Value<String> engineKey;
  final Value<String> settingKey;
  final Value<String> value;
  final Value<int> rowid;
  const EngineSettingsTableCompanion({
    this.kidId = const Value.absent(),
    this.engineKey = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EngineSettingsTableCompanion.insert({
    required String kidId,
    required String engineKey,
    required String settingKey,
    required String value,
    this.rowid = const Value.absent(),
  }) : kidId = Value(kidId),
       engineKey = Value(engineKey),
       settingKey = Value(settingKey),
       value = Value(value);
  static Insertable<EngineSettingRow> custom({
    Expression<String>? kidId,
    Expression<String>? engineKey,
    Expression<String>? settingKey,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kidId != null) 'kid_id': kidId,
      if (engineKey != null) 'engine_key': engineKey,
      if (settingKey != null) 'setting_key': settingKey,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EngineSettingsTableCompanion copyWith({
    Value<String>? kidId,
    Value<String>? engineKey,
    Value<String>? settingKey,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return EngineSettingsTableCompanion(
      kidId: kidId ?? this.kidId,
      engineKey: engineKey ?? this.engineKey,
      settingKey: settingKey ?? this.settingKey,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kidId.present) {
      map['kid_id'] = Variable<String>(kidId.value);
    }
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
          ..write('kidId: $kidId, ')
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
  static const VerificationMeta _kidIdMeta = const VerificationMeta('kidId');
  @override
  late final GeneratedColumn<String> kidId = GeneratedColumn<String>(
    'kid_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  List<GeneratedColumn> get $columns => [kidId, key, value, updatedAt];
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
    if (data.containsKey('kid_id')) {
      context.handle(
        _kidIdMeta,
        kidId.isAcceptableOrUnknown(data['kid_id']!, _kidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kidIdMeta);
    }
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
  Set<GeneratedColumn> get $primaryKey => {kidId, key};
  @override
  AppStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppStateRow(
      kidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid_id'],
      )!,
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
  /// Which kid owns this key, or [deviceScope] for device-level bookkeeping.
  ///
  /// This table holds both kinds: `home_stats.*` is a per-kid daily counter,
  /// while `outbox_capacity.*` counts evictions for the device's whole
  /// outbox. A sentinel rather than a nullable column on purpose — SQLite
  /// permits NULL in any primary-key column that is not `INTEGER PRIMARY
  /// KEY`, and NULLs compare distinct, so a nullable owner here would
  /// silently allow unlimited duplicate device-level rows (ADR 0014).
  final String kidId;
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppStateRow({
    required this.kidId,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kid_id'] = Variable<String>(kidId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppStateTableCompanion toCompanion(bool nullToAbsent) {
    return AppStateTableCompanion(
      kidId: Value(kidId),
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
      kidId: serializer.fromJson<String>(json['kidId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kidId': serializer.toJson<String>(kidId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppStateRow copyWith({
    String? kidId,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => AppStateRow(
    kidId: kidId ?? this.kidId,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppStateRow copyWithCompanion(AppStateTableCompanion data) {
    return AppStateRow(
      kidId: data.kidId.present ? data.kidId.value : this.kidId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppStateRow(')
          ..write('kidId: $kidId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kidId, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppStateRow &&
          other.kidId == this.kidId &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppStateTableCompanion extends UpdateCompanion<AppStateRow> {
  final Value<String> kidId;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppStateTableCompanion({
    this.kidId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppStateTableCompanion.insert({
    required String kidId,
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : kidId = Value(kidId),
       key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppStateRow> custom({
    Expression<String>? kidId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kidId != null) 'kid_id': kidId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppStateTableCompanion copyWith({
    Value<String>? kidId,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppStateTableCompanion(
      kidId: kidId ?? this.kidId,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kidId.present) {
      map['kid_id'] = Variable<String>(kidId.value);
    }
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
          ..write('kidId: $kidId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayedDateTableTable extends PlayedDateTable
    with TableInfo<$PlayedDateTableTable, PlayedDateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayedDateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kidIdMeta = const VerificationMeta('kidId');
  @override
  late final GeneratedColumn<String> kidId = GeneratedColumn<String>(
    'kid_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kidId, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'played_date';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayedDateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kid_id')) {
      context.handle(
        _kidIdMeta,
        kidId.isAcceptableOrUnknown(data['kid_id']!, _kidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kidIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kidId, date};
  @override
  PlayedDateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayedDateRow(
      kidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $PlayedDateTableTable createAlias(String alias) {
    return $PlayedDateTableTable(attachedDatabase, alias);
  }
}

class PlayedDateRow extends DataClass implements Insertable<PlayedDateRow> {
  /// Whose streak this is (ADR 0014). Two siblings on one tablet keep
  /// separate streaks; without this, either child playing would extend both.
  final String kidId;

  /// ISO `yyyy-MM-dd`, local date — not a `DateTimeColumn`, so "the same
  /// calendar day" never depends on a stored time-of-day or timezone.
  final String date;
  const PlayedDateRow({required this.kidId, required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kid_id'] = Variable<String>(kidId);
    map['date'] = Variable<String>(date);
    return map;
  }

  PlayedDateTableCompanion toCompanion(bool nullToAbsent) {
    return PlayedDateTableCompanion(kidId: Value(kidId), date: Value(date));
  }

  factory PlayedDateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayedDateRow(
      kidId: serializer.fromJson<String>(json['kidId']),
      date: serializer.fromJson<String>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kidId': serializer.toJson<String>(kidId),
      'date': serializer.toJson<String>(date),
    };
  }

  PlayedDateRow copyWith({String? kidId, String? date}) =>
      PlayedDateRow(kidId: kidId ?? this.kidId, date: date ?? this.date);
  PlayedDateRow copyWithCompanion(PlayedDateTableCompanion data) {
    return PlayedDateRow(
      kidId: data.kidId.present ? data.kidId.value : this.kidId,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayedDateRow(')
          ..write('kidId: $kidId, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kidId, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayedDateRow &&
          other.kidId == this.kidId &&
          other.date == this.date);
}

class PlayedDateTableCompanion extends UpdateCompanion<PlayedDateRow> {
  final Value<String> kidId;
  final Value<String> date;
  final Value<int> rowid;
  const PlayedDateTableCompanion({
    this.kidId = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayedDateTableCompanion.insert({
    required String kidId,
    required String date,
    this.rowid = const Value.absent(),
  }) : kidId = Value(kidId),
       date = Value(date);
  static Insertable<PlayedDateRow> custom({
    Expression<String>? kidId,
    Expression<String>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kidId != null) 'kid_id': kidId,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayedDateTableCompanion copyWith({
    Value<String>? kidId,
    Value<String>? date,
    Value<int>? rowid,
  }) {
    return PlayedDateTableCompanion(
      kidId: kidId ?? this.kidId,
      date: date ?? this.date,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kidId.present) {
      map['kid_id'] = Variable<String>(kidId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayedDateTableCompanion(')
          ..write('kidId: $kidId, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheTableTable extends AudioCacheTable
    with TableInfo<$AudioCacheTableTable, CachedAudio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    ref,
    bytes,
    sha256,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAudio> instance, {
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
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    } else if (isInserting) {
      context.missing(_refMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
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
  Set<GeneratedColumn> get $primaryKey => {exerciseId, ref};
  @override
  CachedAudio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAudio(
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $AudioCacheTableTable createAlias(String alias) {
    return $AudioCacheTableTable(attachedDatabase, alias);
  }
}

class CachedAudio extends DataClass implements Insertable<CachedAudio> {
  final String exerciseId;

  /// Matches a `prompt.audio_ref` value — `"audio"` for a single-question
  /// exercise, `"q0_audio"`/`"q1_audio"`/... for a multi-question one.
  final String ref;
  final Uint8List bytes;

  /// The server's checksum, verified again on every read via
  /// [ContentSync.verifyCache]'s same reasoning for exercise content:
  /// a flipped bit in SQLite must surface as "play it safe and
  /// re-download", not a corrupted clip played to a kid.
  final String sha256;
  final DateTime cachedAt;
  const CachedAudio({
    required this.exerciseId,
    required this.ref,
    required this.bytes,
    required this.sha256,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_id'] = Variable<String>(exerciseId);
    map['ref'] = Variable<String>(ref);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['sha256'] = Variable<String>(sha256);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  AudioCacheTableCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheTableCompanion(
      exerciseId: Value(exerciseId),
      ref: Value(ref),
      bytes: Value(bytes),
      sha256: Value(sha256),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedAudio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAudio(
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      ref: serializer.fromJson<String>(json['ref']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      sha256: serializer.fromJson<String>(json['sha256']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseId': serializer.toJson<String>(exerciseId),
      'ref': serializer.toJson<String>(ref),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'sha256': serializer.toJson<String>(sha256),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedAudio copyWith({
    String? exerciseId,
    String? ref,
    Uint8List? bytes,
    String? sha256,
    DateTime? cachedAt,
  }) => CachedAudio(
    exerciseId: exerciseId ?? this.exerciseId,
    ref: ref ?? this.ref,
    bytes: bytes ?? this.bytes,
    sha256: sha256 ?? this.sha256,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedAudio copyWithCompanion(AudioCacheTableCompanion data) {
    return CachedAudio(
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      ref: data.ref.present ? data.ref.value : this.ref,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAudio(')
          ..write('exerciseId: $exerciseId, ')
          ..write('ref: $ref, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    exerciseId,
    ref,
    $driftBlobEquality.hash(bytes),
    sha256,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAudio &&
          other.exerciseId == this.exerciseId &&
          other.ref == this.ref &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.sha256 == this.sha256 &&
          other.cachedAt == this.cachedAt);
}

class AudioCacheTableCompanion extends UpdateCompanion<CachedAudio> {
  final Value<String> exerciseId;
  final Value<String> ref;
  final Value<Uint8List> bytes;
  final Value<String> sha256;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const AudioCacheTableCompanion({
    this.exerciseId = const Value.absent(),
    this.ref = const Value.absent(),
    this.bytes = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioCacheTableCompanion.insert({
    required String exerciseId,
    required String ref,
    required Uint8List bytes,
    required String sha256,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       ref = Value(ref),
       bytes = Value(bytes),
       sha256 = Value(sha256),
       cachedAt = Value(cachedAt);
  static Insertable<CachedAudio> custom({
    Expression<String>? exerciseId,
    Expression<String>? ref,
    Expression<Uint8List>? bytes,
    Expression<String>? sha256,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (ref != null) 'ref': ref,
      if (bytes != null) 'bytes': bytes,
      if (sha256 != null) 'sha256': sha256,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioCacheTableCompanion copyWith({
    Value<String>? exerciseId,
    Value<String>? ref,
    Value<Uint8List>? bytes,
    Value<String>? sha256,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return AudioCacheTableCompanion(
      exerciseId: exerciseId ?? this.exerciseId,
      ref: ref ?? this.ref,
      bytes: bytes ?? this.bytes,
      sha256: sha256 ?? this.sha256,
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
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
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
    return (StringBuffer('AudioCacheTableCompanion(')
          ..write('exerciseId: $exerciseId, ')
          ..write('ref: $ref, ')
          ..write('bytes: $bytes, ')
          ..write('sha256: $sha256, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivitySessionTableTable extends ActivitySessionTable
    with TableInfo<$ActivitySessionTableTable, ActivitySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitySessionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _activitySessionIdMeta = const VerificationMeta(
    'activitySessionId',
  );
  @override
  late final GeneratedColumn<String> activitySessionId =
      GeneratedColumn<String>(
        'activity_session_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _kidIdMeta = const VerificationMeta('kidId');
  @override
  late final GeneratedColumn<String> kidId = GeneratedColumn<String>(
    'kid_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _snapshotMeta = const VerificationMeta(
    'snapshot',
  );
  @override
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
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
  List<GeneratedColumn> get $columns => [
    activitySessionId,
    kidId,
    exerciseId,
    snapshot,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_session';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivitySessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('activity_session_id')) {
      context.handle(
        _activitySessionIdMeta,
        activitySessionId.isAcceptableOrUnknown(
          data['activity_session_id']!,
          _activitySessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activitySessionIdMeta);
    }
    if (data.containsKey('kid_id')) {
      context.handle(
        _kidIdMeta,
        kidId.isAcceptableOrUnknown(data['kid_id']!, _kidIdMeta),
      );
    } else if (isInserting) {
      context.missing(_kidIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotMeta);
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
  Set<GeneratedColumn> get $primaryKey => {activitySessionId};
  @override
  ActivitySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivitySessionRow(
      activitySessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_session_id'],
      )!,
      kidId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActivitySessionTableTable createAlias(String alias) {
    return $ActivitySessionTableTable(attachedDatabase, alias);
  }
}

class ActivitySessionRow extends DataClass
    implements Insertable<ActivitySessionRow> {
  final String activitySessionId;

  /// Per kid, like everything else a child produces (ADR 0014).
  final String kidId;
  final String exerciseId;

  /// `SessionSnapshot.toJson()`. One JSON column rather than a column per
  /// field: the snapshot is versioned by its own reader, which rejects what
  /// it can't trust, so its shape can grow without a migration.
  final String snapshot;
  final DateTime updatedAt;
  const ActivitySessionRow({
    required this.activitySessionId,
    required this.kidId,
    required this.exerciseId,
    required this.snapshot,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['activity_session_id'] = Variable<String>(activitySessionId);
    map['kid_id'] = Variable<String>(kidId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['snapshot'] = Variable<String>(snapshot);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActivitySessionTableCompanion toCompanion(bool nullToAbsent) {
    return ActivitySessionTableCompanion(
      activitySessionId: Value(activitySessionId),
      kidId: Value(kidId),
      exerciseId: Value(exerciseId),
      snapshot: Value(snapshot),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActivitySessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivitySessionRow(
      activitySessionId: serializer.fromJson<String>(json['activitySessionId']),
      kidId: serializer.fromJson<String>(json['kidId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'activitySessionId': serializer.toJson<String>(activitySessionId),
      'kidId': serializer.toJson<String>(kidId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'snapshot': serializer.toJson<String>(snapshot),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActivitySessionRow copyWith({
    String? activitySessionId,
    String? kidId,
    String? exerciseId,
    String? snapshot,
    DateTime? updatedAt,
  }) => ActivitySessionRow(
    activitySessionId: activitySessionId ?? this.activitySessionId,
    kidId: kidId ?? this.kidId,
    exerciseId: exerciseId ?? this.exerciseId,
    snapshot: snapshot ?? this.snapshot,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActivitySessionRow copyWithCompanion(ActivitySessionTableCompanion data) {
    return ActivitySessionRow(
      activitySessionId: data.activitySessionId.present
          ? data.activitySessionId.value
          : this.activitySessionId,
      kidId: data.kidId.present ? data.kidId.value : this.kidId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivitySessionRow(')
          ..write('activitySessionId: $activitySessionId, ')
          ..write('kidId: $kidId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('snapshot: $snapshot, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(activitySessionId, kidId, exerciseId, snapshot, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivitySessionRow &&
          other.activitySessionId == this.activitySessionId &&
          other.kidId == this.kidId &&
          other.exerciseId == this.exerciseId &&
          other.snapshot == this.snapshot &&
          other.updatedAt == this.updatedAt);
}

class ActivitySessionTableCompanion
    extends UpdateCompanion<ActivitySessionRow> {
  final Value<String> activitySessionId;
  final Value<String> kidId;
  final Value<String> exerciseId;
  final Value<String> snapshot;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ActivitySessionTableCompanion({
    this.activitySessionId = const Value.absent(),
    this.kidId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitySessionTableCompanion.insert({
    required String activitySessionId,
    required String kidId,
    required String exerciseId,
    required String snapshot,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : activitySessionId = Value(activitySessionId),
       kidId = Value(kidId),
       exerciseId = Value(exerciseId),
       snapshot = Value(snapshot),
       updatedAt = Value(updatedAt);
  static Insertable<ActivitySessionRow> custom({
    Expression<String>? activitySessionId,
    Expression<String>? kidId,
    Expression<String>? exerciseId,
    Expression<String>? snapshot,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (activitySessionId != null) 'activity_session_id': activitySessionId,
      if (kidId != null) 'kid_id': kidId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (snapshot != null) 'snapshot': snapshot,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitySessionTableCompanion copyWith({
    Value<String>? activitySessionId,
    Value<String>? kidId,
    Value<String>? exerciseId,
    Value<String>? snapshot,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActivitySessionTableCompanion(
      activitySessionId: activitySessionId ?? this.activitySessionId,
      kidId: kidId ?? this.kidId,
      exerciseId: exerciseId ?? this.exerciseId,
      snapshot: snapshot ?? this.snapshot,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (activitySessionId.present) {
      map['activity_session_id'] = Variable<String>(activitySessionId.value);
    }
    if (kidId.present) {
      map['kid_id'] = Variable<String>(kidId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
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
    return (StringBuffer('ActivitySessionTableCompanion(')
          ..write('activitySessionId: $activitySessionId, ')
          ..write('kidId: $kidId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('snapshot: $snapshot, ')
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
  late final $SkillNodeTableTable skillNodeTable = $SkillNodeTableTable(this);
  late final $EngineSettingsTableTable engineSettingsTable =
      $EngineSettingsTableTable(this);
  late final $AppStateTableTable appStateTable = $AppStateTableTable(this);
  late final $PlayedDateTableTable playedDateTable = $PlayedDateTableTable(
    this,
  );
  late final $AudioCacheTableTable audioCacheTable = $AudioCacheTableTable(
    this,
  );
  late final $ActivitySessionTableTable activitySessionTable =
      $ActivitySessionTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventOutboxTable,
    exerciseCacheTable,
    skillNodeTable,
    engineSettingsTable,
    appStateTable,
    playedDateTable,
    audioCacheTable,
    activitySessionTable,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$EventOutboxTableTableCreateCompanionBuilder =
    EventOutboxTableCompanion Function({
      required String eventId,
      required String kidId,
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
      Value<String> kidId,
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

  ColumnFilters<String> get kidId => $composableBuilder(
    column: $table.kidId,
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

  ColumnOrderings<String> get kidId => $composableBuilder(
    column: $table.kidId,
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

  GeneratedColumn<String> get kidId =>
      $composableBuilder(column: $table.kidId, builder: (column) => column);

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
                Value<String> kidId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventOutboxTableCompanion(
                eventId: eventId,
                kidId: kidId,
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
                required String kidId,
                required String payload,
                required DateTime queuedAt,
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventOutboxTableCompanion.insert(
                eventId: eventId,
                kidId: kidId,
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
typedef $$SkillNodeTableTableCreateCompanionBuilder =
    SkillNodeTableCompanion Function({
      required String id,
      required String labelFr,
      required String labelEn,
      required String stableKey,
      required String subject,
      required int grade,
      Value<int> rowid,
    });
typedef $$SkillNodeTableTableUpdateCompanionBuilder =
    SkillNodeTableCompanion Function({
      Value<String> id,
      Value<String> labelFr,
      Value<String> labelEn,
      Value<String> stableKey,
      Value<String> subject,
      Value<int> grade,
      Value<int> rowid,
    });

class $$SkillNodeTableTableFilterComposer
    extends Composer<_$LocalDatabase, $SkillNodeTableTable> {
  $$SkillNodeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelFr => $composableBuilder(
    column: $table.labelFr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelEn => $composableBuilder(
    column: $table.labelEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stableKey => $composableBuilder(
    column: $table.stableKey,
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
}

class $$SkillNodeTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $SkillNodeTableTable> {
  $$SkillNodeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelFr => $composableBuilder(
    column: $table.labelFr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelEn => $composableBuilder(
    column: $table.labelEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stableKey => $composableBuilder(
    column: $table.stableKey,
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
}

class $$SkillNodeTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SkillNodeTableTable> {
  $$SkillNodeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get labelFr =>
      $composableBuilder(column: $table.labelFr, builder: (column) => column);

  GeneratedColumn<String> get labelEn =>
      $composableBuilder(column: $table.labelEn, builder: (column) => column);

  GeneratedColumn<String> get stableKey =>
      $composableBuilder(column: $table.stableKey, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);
}

class $$SkillNodeTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $SkillNodeTableTable,
          CachedSkillNode,
          $$SkillNodeTableTableFilterComposer,
          $$SkillNodeTableTableOrderingComposer,
          $$SkillNodeTableTableAnnotationComposer,
          $$SkillNodeTableTableCreateCompanionBuilder,
          $$SkillNodeTableTableUpdateCompanionBuilder,
          (
            CachedSkillNode,
            BaseReferences<
              _$LocalDatabase,
              $SkillNodeTableTable,
              CachedSkillNode
            >,
          ),
          CachedSkillNode,
          PrefetchHooks Function()
        > {
  $$SkillNodeTableTableTableManager(
    _$LocalDatabase db,
    $SkillNodeTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillNodeTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillNodeTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillNodeTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> labelFr = const Value.absent(),
                Value<String> labelEn = const Value.absent(),
                Value<String> stableKey = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<int> grade = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SkillNodeTableCompanion(
                id: id,
                labelFr: labelFr,
                labelEn: labelEn,
                stableKey: stableKey,
                subject: subject,
                grade: grade,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String labelFr,
                required String labelEn,
                required String stableKey,
                required String subject,
                required int grade,
                Value<int> rowid = const Value.absent(),
              }) => SkillNodeTableCompanion.insert(
                id: id,
                labelFr: labelFr,
                labelEn: labelEn,
                stableKey: stableKey,
                subject: subject,
                grade: grade,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SkillNodeTableTable, CachedSkillNode>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $SkillNodeTableTable,
                    CachedSkillNode
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SkillNodeTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $SkillNodeTableTable,
      CachedSkillNode,
      $$SkillNodeTableTableFilterComposer,
      $$SkillNodeTableTableOrderingComposer,
      $$SkillNodeTableTableAnnotationComposer,
      $$SkillNodeTableTableCreateCompanionBuilder,
      $$SkillNodeTableTableUpdateCompanionBuilder,
      (
        CachedSkillNode,
        BaseReferences<_$LocalDatabase, $SkillNodeTableTable, CachedSkillNode>,
      ),
      CachedSkillNode,
      PrefetchHooks Function()
    >;
typedef $$EngineSettingsTableTableCreateCompanionBuilder =
    EngineSettingsTableCompanion Function({
      required String kidId,
      required String engineKey,
      required String settingKey,
      required String value,
      Value<int> rowid,
    });
typedef $$EngineSettingsTableTableUpdateCompanionBuilder =
    EngineSettingsTableCompanion Function({
      Value<String> kidId,
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
  ColumnFilters<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnFilters(column),
  );

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
  ColumnOrderings<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnOrderings(column),
  );

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
  GeneratedColumn<String> get kidId =>
      $composableBuilder(column: $table.kidId, builder: (column) => column);

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
                Value<String> kidId = const Value.absent(),
                Value<String> engineKey = const Value.absent(),
                Value<String> settingKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EngineSettingsTableCompanion(
                kidId: kidId,
                engineKey: engineKey,
                settingKey: settingKey,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kidId,
                required String engineKey,
                required String settingKey,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => EngineSettingsTableCompanion.insert(
                kidId: kidId,
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
      required String kidId,
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppStateTableTableUpdateCompanionBuilder =
    AppStateTableCompanion Function({
      Value<String> kidId,
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
  ColumnFilters<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnFilters(column),
  );

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
  ColumnOrderings<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnOrderings(column),
  );

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
  GeneratedColumn<String> get kidId =>
      $composableBuilder(column: $table.kidId, builder: (column) => column);

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
                Value<String> kidId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppStateTableCompanion(
                kidId: kidId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kidId,
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppStateTableCompanion.insert(
                kidId: kidId,
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
typedef $$PlayedDateTableTableCreateCompanionBuilder =
    PlayedDateTableCompanion Function({
      required String kidId,
      required String date,
      Value<int> rowid,
    });
typedef $$PlayedDateTableTableUpdateCompanionBuilder =
    PlayedDateTableCompanion Function({
      Value<String> kidId,
      Value<String> date,
      Value<int> rowid,
    });

class $$PlayedDateTableTableFilterComposer
    extends Composer<_$LocalDatabase, $PlayedDateTableTable> {
  $$PlayedDateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayedDateTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $PlayedDateTableTable> {
  $$PlayedDateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayedDateTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PlayedDateTableTable> {
  $$PlayedDateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kidId =>
      $composableBuilder(column: $table.kidId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$PlayedDateTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $PlayedDateTableTable,
          PlayedDateRow,
          $$PlayedDateTableTableFilterComposer,
          $$PlayedDateTableTableOrderingComposer,
          $$PlayedDateTableTableAnnotationComposer,
          $$PlayedDateTableTableCreateCompanionBuilder,
          $$PlayedDateTableTableUpdateCompanionBuilder,
          (
            PlayedDateRow,
            BaseReferences<
              _$LocalDatabase,
              $PlayedDateTableTable,
              PlayedDateRow
            >,
          ),
          PlayedDateRow,
          PrefetchHooks Function()
        > {
  $$PlayedDateTableTableTableManager(
    _$LocalDatabase db,
    $PlayedDateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayedDateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayedDateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayedDateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kidId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayedDateTableCompanion(
                kidId: kidId,
                date: date,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kidId,
                required String date,
                Value<int> rowid = const Value.absent(),
              }) => PlayedDateTableCompanion.insert(
                kidId: kidId,
                date: date,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayedDateTableTable, PlayedDateRow>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $PlayedDateTableTable,
                    PlayedDateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayedDateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $PlayedDateTableTable,
      PlayedDateRow,
      $$PlayedDateTableTableFilterComposer,
      $$PlayedDateTableTableOrderingComposer,
      $$PlayedDateTableTableAnnotationComposer,
      $$PlayedDateTableTableCreateCompanionBuilder,
      $$PlayedDateTableTableUpdateCompanionBuilder,
      (
        PlayedDateRow,
        BaseReferences<_$LocalDatabase, $PlayedDateTableTable, PlayedDateRow>,
      ),
      PlayedDateRow,
      PrefetchHooks Function()
    >;
typedef $$AudioCacheTableTableCreateCompanionBuilder =
    AudioCacheTableCompanion Function({
      required String exerciseId,
      required String ref,
      required Uint8List bytes,
      required String sha256,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$AudioCacheTableTableUpdateCompanionBuilder =
    AudioCacheTableCompanion Function({
      Value<String> exerciseId,
      Value<String> ref,
      Value<Uint8List> bytes,
      Value<String> sha256,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$AudioCacheTableTableFilterComposer
    extends Composer<_$LocalDatabase, $AudioCacheTableTable> {
  $$AudioCacheTableTableFilterComposer({
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

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioCacheTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $AudioCacheTableTable> {
  $$AudioCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioCacheTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $AudioCacheTableTable> {
  $$AudioCacheTableTableAnnotationComposer({
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

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$AudioCacheTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $AudioCacheTableTable,
          CachedAudio,
          $$AudioCacheTableTableFilterComposer,
          $$AudioCacheTableTableOrderingComposer,
          $$AudioCacheTableTableAnnotationComposer,
          $$AudioCacheTableTableCreateCompanionBuilder,
          $$AudioCacheTableTableUpdateCompanionBuilder,
          (
            CachedAudio,
            BaseReferences<_$LocalDatabase, $AudioCacheTableTable, CachedAudio>,
          ),
          CachedAudio,
          PrefetchHooks Function()
        > {
  $$AudioCacheTableTableTableManager(
    _$LocalDatabase db,
    $AudioCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> exerciseId = const Value.absent(),
                Value<String> ref = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheTableCompanion(
                exerciseId: exerciseId,
                ref: ref,
                bytes: bytes,
                sha256: sha256,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseId,
                required String ref,
                required Uint8List bytes,
                required String sha256,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheTableCompanion.insert(
                exerciseId: exerciseId,
                ref: ref,
                bytes: bytes,
                sha256: sha256,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioCacheTableTable, CachedAudio>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $AudioCacheTableTable,
                    CachedAudio
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $AudioCacheTableTable,
      CachedAudio,
      $$AudioCacheTableTableFilterComposer,
      $$AudioCacheTableTableOrderingComposer,
      $$AudioCacheTableTableAnnotationComposer,
      $$AudioCacheTableTableCreateCompanionBuilder,
      $$AudioCacheTableTableUpdateCompanionBuilder,
      (
        CachedAudio,
        BaseReferences<_$LocalDatabase, $AudioCacheTableTable, CachedAudio>,
      ),
      CachedAudio,
      PrefetchHooks Function()
    >;
typedef $$ActivitySessionTableTableCreateCompanionBuilder =
    ActivitySessionTableCompanion Function({
      required String activitySessionId,
      required String kidId,
      required String exerciseId,
      required String snapshot,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ActivitySessionTableTableUpdateCompanionBuilder =
    ActivitySessionTableCompanion Function({
      Value<String> activitySessionId,
      Value<String> kidId,
      Value<String> exerciseId,
      Value<String> snapshot,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ActivitySessionTableTableFilterComposer
    extends Composer<_$LocalDatabase, $ActivitySessionTableTable> {
  $$ActivitySessionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get activitySessionId => $composableBuilder(
    column: $table.activitySessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitySessionTableTableOrderingComposer
    extends Composer<_$LocalDatabase, $ActivitySessionTableTable> {
  $$ActivitySessionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get activitySessionId => $composableBuilder(
    column: $table.activitySessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kidId => $composableBuilder(
    column: $table.kidId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshot => $composableBuilder(
    column: $table.snapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitySessionTableTableAnnotationComposer
    extends Composer<_$LocalDatabase, $ActivitySessionTableTable> {
  $$ActivitySessionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get activitySessionId => $composableBuilder(
    column: $table.activitySessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kidId =>
      $composableBuilder(column: $table.kidId, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActivitySessionTableTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $ActivitySessionTableTable,
          ActivitySessionRow,
          $$ActivitySessionTableTableFilterComposer,
          $$ActivitySessionTableTableOrderingComposer,
          $$ActivitySessionTableTableAnnotationComposer,
          $$ActivitySessionTableTableCreateCompanionBuilder,
          $$ActivitySessionTableTableUpdateCompanionBuilder,
          (
            ActivitySessionRow,
            BaseReferences<
              _$LocalDatabase,
              $ActivitySessionTableTable,
              ActivitySessionRow
            >,
          ),
          ActivitySessionRow,
          PrefetchHooks Function()
        > {
  $$ActivitySessionTableTableTableManager(
    _$LocalDatabase db,
    $ActivitySessionTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitySessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitySessionTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ActivitySessionTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> activitySessionId = const Value.absent(),
                Value<String> kidId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitySessionTableCompanion(
                activitySessionId: activitySessionId,
                kidId: kidId,
                exerciseId: exerciseId,
                snapshot: snapshot,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String activitySessionId,
                required String kidId,
                required String exerciseId,
                required String snapshot,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActivitySessionTableCompanion.insert(
                activitySessionId: activitySessionId,
                kidId: kidId,
                exerciseId: exerciseId,
                snapshot: snapshot,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivitySessionTableTable, ActivitySessionRow>(
                    table,
                  ),
                  BaseReferences<
                    _$LocalDatabase,
                    $ActivitySessionTableTable,
                    ActivitySessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitySessionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $ActivitySessionTableTable,
      ActivitySessionRow,
      $$ActivitySessionTableTableFilterComposer,
      $$ActivitySessionTableTableOrderingComposer,
      $$ActivitySessionTableTableAnnotationComposer,
      $$ActivitySessionTableTableCreateCompanionBuilder,
      $$ActivitySessionTableTableUpdateCompanionBuilder,
      (
        ActivitySessionRow,
        BaseReferences<
          _$LocalDatabase,
          $ActivitySessionTableTable,
          ActivitySessionRow
        >,
      ),
      ActivitySessionRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$EventOutboxTableTableTableManager get eventOutboxTable =>
      $$EventOutboxTableTableTableManager(_db, _db.eventOutboxTable);
  $$ExerciseCacheTableTableTableManager get exerciseCacheTable =>
      $$ExerciseCacheTableTableTableManager(_db, _db.exerciseCacheTable);
  $$SkillNodeTableTableTableManager get skillNodeTable =>
      $$SkillNodeTableTableTableManager(_db, _db.skillNodeTable);
  $$EngineSettingsTableTableTableManager get engineSettingsTable =>
      $$EngineSettingsTableTableTableManager(_db, _db.engineSettingsTable);
  $$AppStateTableTableTableManager get appStateTable =>
      $$AppStateTableTableTableManager(_db, _db.appStateTable);
  $$PlayedDateTableTableTableManager get playedDateTable =>
      $$PlayedDateTableTableTableManager(_db, _db.playedDateTable);
  $$AudioCacheTableTableTableManager get audioCacheTable =>
      $$AudioCacheTableTableTableManager(_db, _db.audioCacheTable);
  $$ActivitySessionTableTableTableManager get activitySessionTable =>
      $$ActivitySessionTableTableTableManager(_db, _db.activitySessionTable);
}
