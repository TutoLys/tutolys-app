import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../data/local_db/database.dart';
import '../../data/local_db/node_progress_local.dart';
import '../../data/local_db/session_store.dart';
import 'carte_model.dart';
import 'node_lessons.dart';
import '../../data/sync/window_plan.dart';
import 'path_controller.dart' show pickLessons;

/// Leaves kept per subject from the frontier forward, the frontier
/// included (ADR 0093). The interview's 20–30 leaves, about 15–18 MB.
const offlineWindowLeaves = 25;

/// Finished leaves kept just behind the frontier, for an offline replay.
const offlineWindowBehind = 3;

/// The leaves one kid needs on the device: the frontier, the next
/// [size] − 1 playable leaves, and [behind] before it, in Carte order.
///
/// [order] is every leaf in the order the Carte draws them; [playable] the
/// ones with a published lesson (only those hold anything to download, so
/// only those count). [done] is completed or mastered: the frontier is the
/// first playable leaf not in it, exactly the Carte's `active` node, and
/// the last playable leaf once everything is done. [review] (prior-grade
/// leaves the review channel would serve) is always included.
Set<String> computeOfflineWindow({
  required List<String> order,
  required Set<String> playable,
  Set<String> done = const {},
  Set<String> review = const {},
  int size = offlineWindowLeaves,
  int behind = offlineWindowBehind,
}) {
  final path = [
    for (final id in order)
      if (playable.contains(id)) id,
  ];
  if (path.isEmpty) return {...review};
  var frontier = path.indexWhere((id) => !done.contains(id));
  if (frontier < 0) frontier = path.length - 1;
  final start = math.max(0, frontier - behind);
  final end = math.min(path.length, frontier + size);
  return {...path.sublist(start, end), ...review};
}

/// Plans the window for a manifest, for every kid paired to the device.
///
/// Each kid's window comes from the manifest, the curriculum cache and that
/// kid's own completion record (`node_progress.*`), all already on the
/// device: a sibling's window needs neither their token nor the network.
/// The playing kid's also counts server mastery when it's known, and is
/// stored so a sibling's sync keeps it; a sibling's stored window wins over
/// a local guess.
class OfflineWindowPlanner {
  OfflineWindowPlanner({
    required this.db,
    required this.kids,
    required this.activeKidId,
    this.mastered,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final LocalDatabase db;
  final Future<List<PairedKid>> Function() kids;
  final String? Function() activeKidId;

  /// Leaves the server says the playing kid has mastered.
  final Set<String> Function()? mastered;

  final DateTime Function() _now;

  static String storedKey(String subject, int grade) =>
      'offline_window.$subject.$grade';

  /// Null when the curriculum for a subject isn't cached yet: with no order
  /// there is no frontier, and guessing would evict the wrong lessons. The
  /// sync then keeps everything, as it did before the window.
  Future<WindowPlan?> plan({
    required int grade,
    required String locale,
    required List<ManifestEntryLite> entries,
  }) async {
    final bySubject = <String, List<ManifestEntryLite>>{};
    for (final e in entries) {
      bySubject.putIfAbsent(e.subject, () => []).add(e);
    }
    final active = activeKidId();
    final paired = [
      for (final k in await _kidsOrNone())
        if (k.gradeLevel == grade) k.id,
    ];
    if (active != null && !paired.contains(active)) paired.add(active);

    final fetch = <String>{};
    final keep = <String>{};
    for (final MapEntry(key: subject, value: subjectEntries)
        in bySubject.entries) {
      final leaves = await (db.select(
        db.skillNodeTable,
      )..where((t) => t.subject.equals(subject) & t.grade.equals(grade))).get();
      if (leaves.isEmpty) return null;
      final order = [
        for (final group in groupLeavesByArea(
          subject: subject,
          leaves: leaves,
          english: false,
        ))
          for (final leaf in group.leaves) leaf.id,
      ];
      final lessons = pickLessons([
        for (final e in subjectEntries) e.stub,
      ], locale: locale);
      final playable = lessons.keys.toSet();

      for (final kid in paired) {
        final isActive = kid == active;
        final stored = isActive ? null : await _stored(kid, subject, grade);
        final window =
            stored ??
            computeOfflineWindow(
              order: order,
              playable: playable,
              done: {
                ...await _completed(kid, lessons),
                if (isActive) ...?mastered?.call(),
              },
            );
        if (isActive) {
          fetch.addAll(window);
          await _store(kid, subject, grade, window);
        }
        keep.addAll(window);
      }
    }
    // No playing kid at this grade (a sync for a sibling's manifest):
    // download what is kept.
    if (fetch.isEmpty) fetch.addAll(keep);
    return WindowPlan(fetch: fetch, keep: keep..addAll(fetch));
  }

  /// The secure store can fail (a locked keyring, a test with no
  /// plugin); the playing kid's window is still planned.
  Future<List<PairedKid>> _kidsOrNone() async {
    try {
      return await kids();
    } on Object {
      return const [];
    }
  }

  Future<Set<String>> _completed(
    String kidId,
    Map<String, List<Map<String, Object?>>> lessons,
  ) async {
    const prefix = 'node_progress.';
    final rows = await (db.select(
      db.appStateTable,
    )..where((t) => t.kidId.equals(kidId) & t.key.like('$prefix%'))).get();
    final done = <String>{};
    for (final row in rows) {
      final id = row.key.substring(prefix.length);
      final node = lessons[id];
      final progress = NodeProgress.fromJson(id, row.value);
      if (node == null || progress == null) continue;
      if (nodeLessons(node, progress).complete) done.add(id);
    }
    return done;
  }

  Future<Set<String>?> _stored(String kidId, String subject, int grade) async {
    final row =
        await (db.select(db.appStateTable)..where(
              (t) =>
                  t.kidId.equals(kidId) &
                  t.key.equals(storedKey(subject, grade)),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return (jsonDecode(row.value) as List).whereType<String>().toSet();
    } on Object {
      return null;
    }
  }

  Future<void> _store(
    String kidId,
    String subject,
    int grade,
    Set<String> window,
  ) => db
      .into(db.appStateTable)
      .insertOnConflictUpdate(
        AppStateTableCompanion.insert(
          kidId: kidId,
          key: storedKey(subject, grade),
          value: jsonEncode(window.toList()..sort()),
          updatedAt: _now(),
        ),
      );
}
