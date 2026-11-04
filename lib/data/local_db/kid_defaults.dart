import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// The starting options a guardian's answers set for one child (backend ADR
/// 0220). Only the effects: the device never receives the answers. Null
/// means the guardian didn't answer that question.
///
/// These are defaults, not orders, and they are never copied into a setting:
/// a later edit in the portal must still reach whatever the family hasn't
/// touched (`applyKidDefaults`).
class KidDefaults {
  const KidDefaults({
    this.autoReadPrompts,
    this.sessionMinutes,
    this.firstSubject,
    this.reduceMotion,
    this.music,
    this.soundEffects,
  });

  /// Reads the `defaults` object. Unknown keys are ignored, and a value the
  /// contract doesn't allow counts as unanswered: `reduce_motion` is only
  /// ever true, `music` and `sound_effects` only ever false.
  factory KidDefaults.fromJson(Map<String, Object?> json) {
    final minutes = json['session_minutes'];
    final subject = json['first_subject'];
    final autoRead = json['auto_read_prompts'];
    return KidDefaults(
      autoReadPrompts: autoRead is bool ? autoRead : null,
      sessionMinutes: const {5, 10, 15}.contains(minutes)
          ? minutes as int
          : null,
      firstSubject: subject is String && subject.isNotEmpty ? subject : null,
      reduceMotion: json['reduce_motion'] == true ? true : null,
      music: json['music'] == false ? false : null,
      soundEffects: json['sound_effects'] == false ? false : null,
    );
  }

  static const none = KidDefaults();

  /// True: read each question when it appears, for this child only. The one
  /// exception to "read only on tap" (Hafid's D1, 2026-11-03).
  final bool? autoReadPrompts;

  /// The "Joue N minutes" target, and when a finished lesson offers a pause.
  final int? sessionMinutes;

  /// The subject Village and Carte open on, until the child has played.
  final String? firstSubject;

  final bool? reduceMotion;
  final bool? music;
  final bool? soundEffects;

  Map<String, Object?> toJson() => {
    'auto_read_prompts': ?autoReadPrompts,
    'session_minutes': ?sessionMinutes,
    'first_subject': ?firstSubject,
    'reduce_motion': ?reduceMotion,
    'music': ?music,
    'sound_effects': ?soundEffects,
  };
}

/// The active kid's [KidDefaults] as last served, so they hold offline and
/// from the first frame of the next launch. Per kid (ADR 0014): one child's
/// automatic reading must not reach a sibling on the same tablet.
class KidDefaultsStore {
  const KidDefaultsStore(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _key = 'guardian.defaults';

  Future<String?> _raw() async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId) & t.key.equals(_key)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<KidDefaults> read() async {
    final raw = await _raw();
    if (raw == null) return KidDefaults.none;
    final json = jsonDecode(raw);
    return json is Map<String, Object?>
        ? KidDefaults.fromJson(json)
        : KidDefaults.none;
  }

  /// Replaces what's held, so an answer the guardian removed goes too.
  /// Returns whether anything changed.
  Future<bool> adopt(KidDefaults served, {DateTime? now}) async {
    final next = jsonEncode(served.toJson());
    if (next == (await _raw() ?? jsonEncode(KidDefaults.none.toJson()))) {
      return false;
    }
    await db
        .into(db.appStateTable)
        .insertOnConflictUpdate(
          AppStateTableCompanion.insert(
            kidId: kidId,
            key: _key,
            value: next,
            updatedAt: now ?? DateTime.now(),
          ),
        );
    return true;
  }
}
