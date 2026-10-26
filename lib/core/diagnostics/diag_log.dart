import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One thing that went wrong, kept on the device only (ADR 0038).
@immutable
class DiagEntry {
  const DiagEntry({
    required this.at,
    required this.kind,
    required this.type,
    required this.message,
    this.frames = const [],
  });

  final DateTime at;

  /// Where it was caught: `flutter`, `platform`, `zone`, or `caught:<site>`.
  final String kind;

  /// The error's runtime type.
  final String type;

  /// Already scrubbed.
  final String message;

  /// The top of the stack, at most [DiagLog.maxFrames] lines.
  final List<String> frames;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind,
    'type': type,
    'message': message,
    'frames': frames,
  };

  static DiagEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return DiagEntry(
      at: at,
      kind: '${raw['kind']}',
      type: '${raw['type']}',
      message: '${raw['message']}',
      frames: [for (final f in (raw['frames'] as List?) ?? const []) '$f'],
    );
  }

  @override
  String toString() =>
      '${at.toIso8601String()} [$kind] $type: $message'
      '${frames.isEmpty ? '' : '\n  ${frames.join('\n  ')}'}';
}

/// The last [capacity] errors of this run, in memory, scrubbed.
///
/// Nothing here leaves the device. It exists so a hang or a crash can be
/// read on the device itself, in the stuck screen's "Détails" and in
/// À propos (ADR 0038), instead of vanishing into a console nobody has open.
class DiagLog extends ChangeNotifier {
  DiagLog({this.capacity = 200, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// The app's one log. Tests make their own.
  static final DiagLog instance = DiagLog();

  static const maxFrames = 5;

  final int capacity;
  final DateTime Function() _now;
  final _entries = ListQueue<DiagEntry>();

  /// What the previous run ended on, when it was saved (see [restore]).
  List<DiagEntry> previousRun = const [];

  /// Called after each new entry, so a store can keep the latest copy.
  void Function(List<DiagEntry> entries)? onChanged;

  List<DiagEntry> get entries => List.unmodifiable(_entries);

  /// Records [error], scrubbed, and prints it to the console.
  void record(String kind, Object error, [StackTrace? stack]) {
    final entry = DiagEntry(
      at: _now(),
      kind: kind,
      type: error.runtimeType.toString(),
      message: scrub('$error'),
      frames: topFrames(stack),
    );
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    debugPrint('[diag] $entry');
    onChanged?.call(entries);
    notifyListeners();
  }

  /// Loads the previous run's entries from what [onChanged] saved.
  void restore(String? saved) {
    if (saved == null || saved.isEmpty) return;
    try {
      previousRun = [
        for (final raw in jsonDecode(saved) as List) ?DiagEntry.fromJson(raw),
      ];
    } on Object {
      previousRun = const [];
    }
  }

  static String encode(List<DiagEntry> entries) =>
      jsonEncode([for (final e in entries) e.toJson()]);

  static List<String> topFrames(StackTrace? stack) {
    if (stack == null) return const [];
    return [
      for (final line in stack.toString().split('\n'))
        if (line.trim().isNotEmpty) scrub(line.trim()),
    ].take(maxFrames).toList();
  }

  static final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*',
  );
  static final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  static final _bearer = RegExp(r'(Bearer\s+)\S+', caseSensitive: false);
  // The backend's pairing alphabet (no 0/O/1/I/L), six or more symbols,
  // with at least one digit so ordinary capitalised words survive.
  static final _pairingCode = RegExp(
    r'\b(?=[23456789ABCDEFGHJKMNPQRSTUVWXYZ]*[2-9])[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6,8}\b',
  );

  /// Removes anything that looks like a token, an email or a pairing code.
  static String scrub(String text) => text
      .replaceAll(_jwt, '<jwt>')
      .replaceAllMapped(_bearer, (m) => '${m[1]}<token>')
      .replaceAll(_email, '<email>')
      .replaceAll(_pairingCode, '<code>');

  /// Installs the global hooks: Flutter framework errors, uncaught
  /// platform errors. [runZonedGuarded] in `main` covers the rest.
  void installHooks() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record('flutter', details.exception, details.stack);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error, stack);
      return true;
    };
  }

  /// For `runZonedGuarded`.
  void onZoneError(Object error, StackTrace stack) =>
      record('zone', error, stack);
}

/// Records a caught error that the caller then handles as before.
void recordCaught(String site, Object error, [StackTrace? stack]) =>
    DiagLog.instance.record('caught:$site', error, stack);

/// Keeps the latest copy of the log on disk, at most every [every], via
/// [write]. Best-effort: a write that fails is dropped, never retried in a
/// loop, because the database may be the thing that's stuck.
class DiagPersister {
  DiagPersister({required this.write, this.every = const Duration(seconds: 2)});

  final Future<void> Function(String json) write;
  final Duration every;
  Timer? _timer;
  List<DiagEntry>? _pending;

  void schedule(List<DiagEntry> entries) {
    _pending = entries;
    _timer ??= Timer(every, () async {
      _timer = null;
      final batch = _pending;
      _pending = null;
      if (batch == null) return;
      try {
        await write(DiagLog.encode(batch)).timeout(const Duration(seconds: 5));
      } on Object {
        // Nowhere to report it but the log itself, which would loop.
      }
    });
  }
}
