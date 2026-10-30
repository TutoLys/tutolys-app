import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode;

import 'database.dart';

/// The subjects of a French-language school, in document order: what the
/// backend serves while no adult has said which language the school
/// teaches in, and what the app shows before its first answer (backend work
/// order N3, ADR 0101).
const frenchProgramme = ['MATH', 'FR', 'SCI', 'SOC', 'CCQ', 'ESL'];

/// Which subjects this kid studies, from their `school_language` on the
/// backend (ADR 0101). The app never decides this itself: a
/// French-language school teaches FR + ESL, an English-language one EN +
/// FLS, never both pairs.
class Programme {
  const Programme({
    this.subjects = frenchProgramme,
    this.schoolLanguageRequired = false,
  });

  /// Backend codes, in the order to show them.
  final List<String> subjects;

  /// No adult has said which language the school teaches in yet. Not a
  /// refusal: the French set is served meanwhile. Only an adult is asked.
  final bool schoolLanguageRequired;

  /// Read from a tree or manifest body; null from a backend older than the
  /// field, so the app keeps what it had.
  static Programme? fromJson(Map<String, Object?> body) {
    final subjects = body['subjects'];
    if (subjects is! List || subjects.isEmpty) return null;
    return Programme(
      subjects: List.unmodifiable(subjects.cast<String>()),
      schoolLanguageRequired: body['school_language_required'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'subjects': subjects,
    'school_language_required': schoolLanguageRequired,
  };

  @override
  bool operator ==(Object other) =>
      other is Programme &&
      other.schoolLanguageRequired == schoolLanguageRequired &&
      other.subjects.length == subjects.length &&
      [
        for (var i = 0; i < subjects.length; i++)
          other.subjects[i] == subjects[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hash(schoolLanguageRequired, subjects.join(','));
}

/// The last programme the backend gave each kid, kept so the village
/// opens right with no network. Per kid, in `app_state` (ADR 0014):
/// siblings may go to schools of different languages.
class ProgrammeStore {
  ProgrammeStore(this.db, {required this.kidId});

  final LocalDatabase db;
  final String kidId;

  static const _key = 'programme';

  Future<Programme?> read() async {
    final row =
        await (db.select(db.appStateTable)
              ..where((t) => t.kidId.equals(kidId))
              ..where((t) => t.key.equals(_key)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return Programme.fromJson(
        (jsonDecode(row.value) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> write(Programme programme) => db
      .into(db.appStateTable)
      .insert(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: _key,
          value: jsonEncode(programme.toJson()),
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
}
