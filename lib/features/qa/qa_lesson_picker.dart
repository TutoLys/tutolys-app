import 'package:design_system/design_system.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/paired_router.dart';
import '../../data/local_db/database.dart';
import '../../data/sync/content_sync.dart' show NodeDownload;
import '../pairing/pairing_controller.dart';
import '../path/path_controller.dart';
import '../path/subject_pills.dart' show subjectLabel;
import '../../core/i18n/strings.dart';

/// The build asked for QA tools: `--dart-define=QA_TOOLS=true`.
const _qaDefine = bool.fromEnvironment('QA_TOOLS');

/// Whether a build with these flags has the QA lesson picker (ADR 0100).
/// A release build never does, whatever its defines.
@visibleForTesting
bool qaToolsFor({required bool release, required bool define}) =>
    !release && define;

/// The QA lesson picker exists in this build: profile or debug, built with
/// `QA_TOOLS=true`. A `const`, so a release build compiles the picker out.
const qaToolsEnabled = !kReleaseMode && _qaDefine;

/// Every published lesson at the kid's grade, from the stored manifests,
/// downloaded or not.
final qaLessonsProvider = FutureProvider.autoDispose<List<ManifestEntryRow>>((
  ref,
) async {
  final db = ref.watch(localDatabaseProvider);
  final grade = ref.watch(sessionControllerProvider).kid?.gradeLevel ?? 1;
  final rows =
      await (db.select(db.manifestEntryTable)
            ..where((t) => t.grade.equals(grade))
            ..orderBy([
              (t) => OrderingTerm.asc(t.subject),
              (t) => OrderingTerm.asc(t.engineKey),
              (t) => OrderingTerm.asc(t.skillNodeId),
              (t) => OrderingTerm.asc(t.rank),
            ]))
          .get();
  final seen = <String>{};
  return [
    for (final r in rows)
      if (seen.add(r.exerciseId)) r,
  ];
});

/// Reviewers play any lesson here, not only the Carte's frontier (QA).
///
/// Plays as **practice** (`PlayRequest.practice`): nothing reaches
/// telemetry, the Carte, XP, quests or the streak, so the paired kid's
/// real data stays clean. A lesson outside the offline window downloads
/// first.
class QaLessonPicker extends ConsumerWidget {
  const QaLessonPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final lessons = ref.watch(qaLessonsProvider);
    return Scaffold(
      key: const ValueKey('qa-lesson-picker'),
      appBar: AppBar(title: const Text('QA · lessons')),
      body: switch (lessons) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Text(
            'No manifest stored yet: open each subject on the Carte once.',
          ),
        ),
        AsyncData(:final value) => ListView(
          children: [
            for (final (i, r) in value.indexed) ...[
              if (i == 0 || value[i - 1].subject != r.subject)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    subjectLabel(t, r.subject),
                    style: const TextStyle(
                      fontFamily: VillageType.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ListTile(
                key: ValueKey('qa-lesson-${r.exerciseId}'),
                dense: true,
                title: Text('${r.engineKey} · rank ${r.rank} · ${r.locale}'),
                subtitle: Text(r.skillNodeId),
                onTap: () => _play(context, ref, r),
              ),
            ],
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    ManifestEntryRow r,
  ) async {
    final sync = ref.read(contentSyncProvider);
    var envelope = await sync.cachedExercise(r.exerciseId);
    if (envelope == null) {
      final got = await sync.downloadNode(
        skillNodeId: r.skillNodeId,
        grade: r.grade,
        askedLocale: r.askedLocale,
      );
      if (got == NodeDownload.done) {
        envelope = await sync.cachedExercise(r.exerciseId);
      }
    }
    if (!context.mounted) return;
    if (envelope == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not available offline.')));
      return;
    }
    final db = ref.read(localDatabaseProvider);
    final leaf =
        await (db.select(
          db.skillNodeTable,
        )..where((t) => t.id.equals(r.skillNodeId))).getSingleOrNull() ??
        CachedSkillNode(
          id: r.skillNodeId,
          labelFr: r.skillNodeId,
          labelEn: r.skillNodeId,
          stableKey: 'qa/${r.skillNodeId}',
          subject: r.subject,
          grade: r.grade,
        );
    if (!context.mounted) return;
    await GoRouter.of(context).push(
      '/play',
      extra: PlayRequest(node: leaf, envelope: envelope, practice: true),
    );
  }
}
