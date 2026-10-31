import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/paired_router.dart' show PlayRequest;

import '../play/play_screen.dart';
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
/// What a reviewer reads on a row: the skill's name and, once
/// downloaded, the lesson's prompt.
final qaLessonTitlesProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final db = ref.watch(localDatabaseProvider);
      final titles = <String, String>{};
      for (final n in await db.select(db.skillNodeTable).get()) {
        titles['node:${n.id}'] = n.labelFr;
      }
      for (final e in await db.select(db.exerciseCacheTable).get()) {
        final text = _promptOf(e.payload);
        if (text != null) titles['ex:${e.exerciseId}'] = text;
      }
      return titles;
    });

/// The lesson's first prompt: its own, or its first question's.
String? _promptOf(String payload) {
  try {
    final envelope = jsonDecode(payload) as Map<String, Object?>;
    Object? prompt = envelope['prompt'];
    if (prompt == null) {
      if (envelope['questions'] case [final Map first, ...]) {
        prompt = first['prompt'];
      }
    }
    final text = prompt is Map ? prompt['text'] : null;
    return text is String && text.trim().isNotEmpty ? text : null;
  } on Object {
    return null;
  }
}

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
  const QaLessonPicker({this.router, super.key});

  /// The paired shell's router, from the page that opened the picker. A
  /// game then plays at `#/play` like any other, so Back asks before
  /// leaving and returns to that page (AM20). Null: pushed here instead.
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.s;
    final lessons = ref.watch(qaLessonsProvider);
    final titles = ref.watch(qaLessonTitlesProvider).value ?? const {};
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
                title: Text(
                  titles['ex:${r.exerciseId}'] ??
                      titles['node:${r.skillNodeId}'] ??
                      r.skillNodeId,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${r.engineKey} · rank ${r.rank} · ${r.locale}'
                  '${titles.containsKey('ex:${r.exerciseId}') ? '' : ' · not downloaded'}',
                ),
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
    if (router case final router?) {
      // The picker sits on the root navigator above the router: close it,
      // play through the router, then open it again for the next lesson.
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      await router.push(
        '/play',
        extra: PlayRequest(node: leaf, envelope: envelope, practice: true),
      );
      final back = router.routerDelegate.navigatorKey.currentContext;
      if (back != null && back.mounted) {
        await Navigator.of(back, rootNavigator: true).push<void>(
          MaterialPageRoute(builder: (_) => QaLessonPicker(router: router)),
        );
      }
      return;
    }
    // No router in reach (the log opened outside the paired shell): pushed
    // on the picker's own navigator.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PlayScreen(node: leaf, envelope: envelope!, practice: true),
      ),
    );
  }
}
