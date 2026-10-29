import '../local_db/database.dart';

/// What one sync should download, and what the device must keep.
class WindowPlan {
  const WindowPlan({required this.fetch, required this.keep});

  /// The playing kid's window: downloaded by this sync.
  final Set<String> fetch;

  /// The union of every paired kid's window at this grade: never evicted.
  /// Always contains [fetch].
  final Set<String> keep;
}

/// The fields of a manifest entry the window needs, from the API or from
/// the `manifest_entry` table alike.
class ManifestEntryLite {
  const ManifestEntryLite({
    required this.exerciseId,
    required this.skillNodeId,
    required this.subject,
    required this.rank,
    required this.engineKey,
    required this.locale,
    this.lessonGroup,
  });

  factory ManifestEntryLite.fromRow(ManifestEntryRow row) => ManifestEntryLite(
    exerciseId: row.exerciseId,
    skillNodeId: row.skillNodeId,
    subject: row.subject,
    rank: row.rank,
    engineKey: row.engineKey,
    locale: row.locale,
    lessonGroup: row.lessonGroup,
  );

  final String exerciseId;
  final String skillNodeId;
  final String subject;
  final int rank;
  final String engineKey;
  final String locale;
  final String? lessonGroup;

  /// An envelope-shaped stand-in for a lesson that isn't downloaded:
  /// enough for `pickLessons` and `nodeLessons`, and marked so nothing
  /// tries to play it.
  Map<String, Object?> get stub => {
    'exercise_id': exerciseId,
    'skill_node_id': skillNodeId,
    'subject': subject,
    'rank': rank,
    'engine_key': engineKey,
    'locale': locale,
    'lesson_group': ?lessonGroup,
    notDownloadedKey: true,
  };
}

/// Set on a [ManifestEntryLite.stub]: the lesson exists but isn't on the
/// device.
const notDownloadedKey = '_not_downloaded';

bool isNotDownloaded(Map<String, Object?> lesson) =>
    lesson[notDownloadedKey] == true;
