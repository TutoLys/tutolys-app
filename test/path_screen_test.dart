import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/core/routing/paired_router.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/node_progress_local.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_hash.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/path/path_screen.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/features/play/play_screen.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

class FakeCurriculumApi extends CurriculumApi {
  FakeCurriculumApi(this.bySubject) : super(dio: Dio());
  final Map<String, List<CurriculumLeaf>> bySubject;
  final requested = <String>[];

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    requested.add(subject);
    return CurriculumTreeFetched(bySubject[subject] ?? const []);
  }
}

class _FixedProgress extends ProgressController {
  _FixedProgress(this._state);
  final ProgressState _state;

  @override
  ProgressState build() => _state;

  @override
  Future<void> refresh() async {}
}

class FakeContentApi extends ContentApi {
  FakeContentApi(this.content) : super(dio: Dio());
  final Map<String, Map<String, Object?>> content;

  /// The server answers 500 to the manifest, as on Hafid's play-test.
  bool failing = false;

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async {
    if (failing) return const ManifestFailed('500');
    final entries = content.values
        .map(
          (e) => ManifestEntry(
            exerciseId: e['exercise_id'] as String,
            version: e['version'] as int,
            contentHash: contentSha256(e),
            engineKey: e['engine_key'] as String,
            engineMinVersion: e['engine_min_version'] as int,
            skillNodeId: e['skill_node_id'] as String,
            subject: e['subject'] as String,
            grade: e['grade'] as int,
            rank: e['rank'] as int,
          ),
        )
        .toList();
    return ManifestFetched(
      ContentManifest(grade: 1, manifestHash: 'm', entries: entries),
    );
  }

  @override
  Future<ExercisesResult> fetchExercises({
    required List<String> ids,
    required String accessToken,
  }) async {
    return ExercisesFetched(
      envelopes: ids.map((id) => content[id]!).toList(),
      unavailable: const [],
    );
  }
}

Map<String, Object?> exercise({
  required String id,
  required String skillNodeId,
  int rank = 0,
}) {
  return {
    'exercise_id': id,
    'version': 1,
    'engine_key': 'mcq',
    'engine_min_version': 1,
    'skill_node_id': skillNodeId,
    'subject': 'MATH',
    'grade': 1,
    'rank': rank,
    'locale': 'fr-CA',
    'prompt': {
      'text': 'Combien font 2 + 2 ?',
      'audio_ref': null,
      'image_ref': null,
    },
    'config': const {
      'options': [
        {'id': 'a', 'label': '4'},
      ],
      'correct': 'a',
    },
    'assets': const <Object?>[],
  };
}

Widget appUnder({
  required List<CurriculumLeaf> leaves,
  required Map<String, Map<String, Object?>> content,
  Map<String, List<CurriculumLeaf>> otherSubjects = const {},
  List<SkillMasteryDto> masteries = const [],
  FakeCurriculumApi? curriculum,
  LocalDatabase? db,
  ProgressState? progress,
  FakeContentApi? contentApi,
  List<Override> overrides = const [],
}) {
  final router = buildPairedRouter();
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      ...overrides,
      localDatabaseProvider.overrideWithValue(db ?? LocalDatabase.memory()),
      // The inbox has no fake here and fails; recovery would then re-run
      // every reader and skew the sync counts these tests assert.
      recoveryRetriesProvider.overrideWithValue(false),
      curriculumApiProvider.overrideWithValue(
        curriculum ?? FakeCurriculumApi({'MATH': leaves, ...otherSubjects}),
      ),
      progressControllerProvider.overrideWith(
        () => _FixedProgress(
          progress ?? ProgressState(loading: false, masteries: masteries),
        ),
      ),
      contentApiProvider.overrideWithValue(
        contentApi ?? FakeContentApi(content),
      ),
      // The background prefetch of other subjects (ADR 0095) would skew
      // the per-subject sync counts these tests assert.
      offlinePrefetchProvider.overrideWithValue(false),
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(
          const SessionState(
            status: SessionStatus.paired,
            kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1),
            accessToken: 'token',
          ),
        ),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp.router(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
}

const _compter = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);

Future<void> openCarte(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  // The shell starts on Village; the design names this destination Carte.
  await tester.tap(find.text('Carte'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the first playable node is active and plays when tapped', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );

    // Titled by its learning area, not a generic heading.
    expect(find.text('Arithmétique'), findsOneWidget);
    // Never played: the card says so rather than showing "0 %".
    expect(find.text('À DÉCOUVRIR'), findsOneWidget);

    // The design plays on the orb itself.
    await tester.tap(find.byKey(const ValueKey('path-orb-leaf-1')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('the active card\'s Continuer plays the same node', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('a phone pins Continuer above the tab bar, off the path (AM9)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openCarte(
      tester,
      appUnder(
        leaves: const [
          _compter,
          CurriculumLeaf(
            id: 'leaf-2',
            labelFr: "par ordre croissant ou décroissant à partir d'un nombre",
            labelEn: '',
            stableKey: 'mathematique/arithmetique/b:A/o:2',
            shortLabelFr: 'Ranger les nombres',
          ),
        ],
        content: {
          'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1'),
          'ex-2': exercise(id: 'ex-2', skillNodeId: 'leaf-2'),
        },
      ),
    );

    final bar = find.byKey(const ValueKey('carte-continue-bar'));
    expect(bar, findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget, reason: 'only the bar');
    // Below the scrolling path, never over a node.
    final path = tester.getRect(find.byKey(const ValueKey('carte-path')));
    expect(tester.getRect(bar).top, greaterThanOrEqualTo(path.bottom));
    // Content's short label under the orb, not the trimmed statement.
    expect(find.text('Ranger les nombres'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('a trimmed caption is read once, by its full name (AM9)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const full =
        "par ordre croissant ou décroissant à partir d'un nombre donné";
    await openCarte(
      tester,
      appUnder(
        leaves: const [
          CurriculumLeaf(
            id: 'leaf-1',
            labelFr: full,
            labelEn: '',
            stableKey: 'mathematique/arithmetique/b:A/o:1',
          ),
        ],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
      ),
    );

    // The orb says the whole statement, never « …. ».
    expect(
      find.bySemanticsLabel(RegExp('^${RegExp.escape(full)}')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'…\.')), findsNothing);
    // The visible caption is drawn, but not read a second time.
    expect(find.text('par ordre croissant…'), findsWidgets);
    expect(find.bySemanticsLabel('par ordre croissant…'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the active card shows the real mastery from /me/progress', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')},
        masteries: const [
          SkillMasteryDto(
            skillNodeId: 'leaf-1',
            masteryPct: 60,
            isMastered: false,
          ),
        ],
      ),
    );

    expect(find.text('EN COURS · 60 % MAÎTRISÉ'), findsOneWidget);
  });

  testWidgets('a subject pill switches the map to that subject', (
    tester,
  ) async {
    final curriculum = FakeCurriculumApi({
      'MATH': const [_compter],
      'FR': const [
        CurriculumLeaf(
          id: 'fr-1',
          labelFr: 'Lire des syllabes',
          labelEn: '',
          stableKey: 'francais-langue/lire/b:A/o:1',
        ),
      ],
    });
    await openCarte(
      tester,
      appUnder(leaves: const [], content: const {}, curriculum: curriculum),
    );
    expect(find.text('Compter'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('subject-pill-FR')));
    await tester.pumpAndSettle();

    expect(curriculum.requested.last, 'FR');
    expect(find.text('Lire des syllabes'), findsOneWidget);
    expect(find.text('Compter'), findsNothing);
  });

  testWidgets('a locked node (no synced exercise) has no way to play', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(leaves: const [_compter], content: const {}),
    );

    // Nothing playable means no active node, so no Continuer card either.
    expect(find.text('Continuer'), findsNothing);

    // A locked orb has no handler at all, so tapping it cannot play.
    await tester.tap(
      find.byKey(const ValueKey('path-orb-leaf-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlayScreen), findsNothing);
    expect(find.byType(PathScreen), findsOneWidget);
  });

  testWidgets('a subject with no skills at this grade says so', (tester) async {
    await openCarte(tester, appUnder(leaves: const [], content: const {}));

    expect(find.byType(PlayScreen), findsNothing);
    expect(
      find.text("Il n'y a rien dans cette matière pour la 1re année."),
      findsOneWidget,
    );
    // The pills stay, so a kid can still go to a subject that has content.
    expect(find.byKey(const ValueKey('subject-pill-FR')), findsOneWidget);
  });

  testWidgets('skills with no lessons yet: "en préparation", map locked', (
    tester,
  ) async {
    await openCarte(
      tester,
      appUnder(leaves: const [_compter], content: const {}),
    );

    expect(
      find.byKey(const ValueKey('carte-gap-noLessonsYet')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Les activités de cette matière sont en préparation. Reviens bientôt !',
      ),
      findsOneWidget,
    );
    // The skill still shows, so the kid sees what's coming.
    expect(find.byKey(ValueKey('path-orb-${_compter.id}')), findsOneWidget);
  });

  group('nothing past the frontier opens (Hafid, asked twice)', () {
    CurriculumLeaf mesure(String id, int o) => CurriculumLeaf(
      id: id,
      labelFr: 'Notion $id',
      labelEn: '',
      stableKey: 'mathematique/mesure/b:A/o:$o',
    );
    final leaves = [mesure('a', 1), mesure('b', 2), mesure('c', 3)];
    // a has two lessons, one finished: "1/2", so a is the frontier.
    // b is mastered on the server, c finished on an older build (a record
    // with no exercise ids). Neither may open while a isn't done.
    final content = {
      'a-0': exercise(id: 'a-0', skillNodeId: 'a'),
      'a-1': exercise(id: 'a-1', skillNodeId: 'a', rank: 1),
      'b-0': exercise(id: 'b-0', skillNodeId: 'b'),
      'c-0': exercise(id: 'c-0', skillNodeId: 'c'),
    };
    const masteries = [
      SkillMasteryDto(skillNodeId: 'b', masteryPct: 95, isMastered: true),
    ];

    Future<LocalDatabase> seeded() async {
      final db = LocalDatabase.memory();
      final local = NodeProgressLocal(db, kidId: 'k1');
      await local.recordCompleted('a', perfect: true, exerciseId: 'a-0');
      await local.recordCompleted('c', perfect: true);
      return db;
    }

    testWidgets('no orb, card or tap beyond the frontier plays', (
      tester,
    ) async {
      final db = await tester.runAsync(seeded);
      await openCarte(
        tester,
        appUnder(
          leaves: leaves,
          content: content,
          masteries: masteries,
          db: db,
        ),
      );

      // The two-lesson node isn't done until both are.
      expect(find.byKey(const ValueKey('lesson-count-a')), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      for (final id in ['b', 'c']) {
        final orb = find.byKey(ValueKey('path-orb-$id'));
        expect(orb, findsOneWidget);
        await tester.ensureVisible(orb);
        await tester.tap(orb, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(PlayScreen), findsNothing, reason: 'orb $id');
        await tester.tap(find.text('Notion $id'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(PlayScreen), findsNothing, reason: 'label $id');
      }

      // One Continuer card, and it plays the frontier's unfinished lesson.
      expect(find.text('Continuer'), findsOneWidget);
      await tester.ensureVisible(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
      expect(play.node.id, 'a');
      expect(play.envelope['exercise_id'], 'a-1');
    });

    // A2 (UX review): the Village's gold Continuer now starts an activity,
    // but only ever the frontier's, never one past it.
    testWidgets('the Village plays the frontier, never past it', (
      tester,
    ) async {
      final db = await tester.runAsync(seeded);
      await tester.pumpWidget(
        appUnder(
          leaves: leaves,
          content: content,
          masteries: masteries,
          db: db,
        ),
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const ValueKey('recommend-continue'));
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      final play = tester.widget<PlayScreen>(find.byType(PlayScreen));
      expect(play.node.id, 'a');
      expect(play.envelope['exercise_id'], 'a-1');
    });
  });

  group('the Carte opens on where the kid is', () {
    // Twelve nodes in one strand, the first nine done: the frontier sits
    // far below the first screen.
    final leaves = [
      for (var i = 1; i <= 12; i++)
        CurriculumLeaf(
          id: 'n$i',
          labelFr: 'Notion $i',
          labelEn: '',
          stableKey: 'mathematique/mesure/b:A/o:$i',
        ),
    ];
    final content = {
      for (var i = 1; i <= 12; i++)
        'e$i': exercise(id: 'e$i', skillNodeId: 'n$i'),
    };

    Future<LocalDatabase> seeded() async {
      final db = LocalDatabase.memory();
      final local = NodeProgressLocal(db, kidId: 'k1');
      for (var i = 1; i <= 9; i++) {
        await local.recordCompleted('n$i', perfect: true, exerciseId: 'e$i');
      }
      return db;
    }

    void expectCentred(WidgetTester tester, String id) {
      final orb = find.byKey(ValueKey('path-orb-$id'));
      final view = tester.getRect(find.byKey(const ValueKey('carte-path')));
      final y = tester.getCenter(orb).dy;
      expect(view.contains(tester.getCenter(orb)), isTrue, reason: id);
      expect(
        (y - view.center.dy).abs(),
        lessThan(view.height / 4),
        reason: '$id roughly centred',
      );
    }

    testWidgets('on opening, after a subject switch, and back from a game', (
      tester,
    ) async {
      final db = await tester.runAsync(seeded);
      final curriculum = FakeCurriculumApi({
        'MATH': leaves,
        'FR': const [
          CurriculumLeaf(
            id: 'fr-1',
            labelFr: 'Lire',
            labelEn: '',
            stableKey: 'francais-langue/lire/b:A/o:1',
          ),
        ],
      });
      await openCarte(
        tester,
        appUnder(
          leaves: leaves,
          content: content,
          curriculum: curriculum,
          db: db,
        ),
      );
      expectCentred(tester, 'n10');

      // Away and back: still the frontier, not the top. The pills are
      // pinned, so no scrolling up first.
      Future<void> pill(String code) async {
        await tester.tap(find.byKey(ValueKey('subject-pill-$code')));
        await tester.pumpAndSettle();
      }

      await pill('FR');
      await pill('MATH');
      expectCentred(tester, 'n10');

      // Play the frontier and come back: the map shows it.
      await tester.tap(find.byKey(const ValueKey('path-orb-n10')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget);
      // Finished elsewhere: the record moves the frontier to n11.
      await tester.runAsync(
        () => NodeProgressLocal(
          db!,
          kidId: 'k1',
        ).recordCompleted('n10', perfect: true, exerciseId: 'e10'),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayScreen)),
      );
      container.invalidate(nodeProgressProvider);
      Navigator.of(tester.element(find.byType(PlayScreen))).pop();
      await tester.pumpAndSettle();
      expectCentred(tester, 'n11');
    });
  });

  group(
    'the pills and strand title stay pinned (Hafid: "like a freeze row")',
    () {
      // Two areas of eight nodes: the path is far taller than the screen.
      final leaves = [
        for (var i = 1; i <= 8; i++)
          CurriculumLeaf(
            id: 'n$i',
            labelFr: 'Nombre $i',
            labelEn: '',
            stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:$i',
          ),
        for (var i = 1; i <= 8; i++)
          CurriculumLeaf(
            id: 'g$i',
            labelFr: 'Forme $i',
            labelEn: '',
            stableKey: 'mathematique/geometrie/b:A/o:$i',
          ),
      ];
      final content = {
        for (final l in leaves)
          'e-${l.id}': exercise(id: 'e-${l.id}', skillNodeId: l.id),
      };

      bool hittable(WidgetTester tester, Finder f) {
        final target = tester.renderObject(f);
        final hit = tester.hitTestOnBinding(tester.getCenter(f));
        return hit.path.any((e) => e.target == target);
      }

      String strandTitle(WidgetTester tester) => tester
          .widget<Text>(find.byKey(const ValueKey('carte-strand-title')))
          .data!;

      for (final (name, size) in [
        ('desktop', const Size(1280, 800)),
        ('mobile', const Size(400, 800)),
      ]) {
        testWidgets('after scrolling the path, on $name', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final curriculum = FakeCurriculumApi({
            'MATH': leaves,
            'FR': const [
              CurriculumLeaf(
                id: 'fr-1',
                labelFr: 'Lire',
                labelEn: '',
                stableKey: 'francais-langue/lire/b:A/o:1',
              ),
            ],
          });
          await openCarte(
            tester,
            appUnder(leaves: leaves, content: content, curriculum: curriculum),
          );
          final pill = find.byKey(const ValueKey('subject-pill-FR'));
          final header = tester.getRect(
            find.byKey(const ValueKey('carte-header')),
          );
          expect(strandTitle(tester), 'Arithmétique');

          // Down into the second area.
          await tester.dragUntilVisible(
            find.byKey(const ValueKey('path-orb-g6')),
            find.byKey(const ValueKey('carte-path')),
            const Offset(0, -200),
          );
          await tester.pumpAndSettle();

          expect(
            tester.getRect(find.byKey(const ValueKey('carte-header'))),
            header,
            reason: 'the header did not move',
          );
          expect(
            hittable(tester, pill),
            isTrue,
            reason: 'pills still tappable',
          );
          expect(strandTitle(tester), 'Géométrie', reason: 'title follows');
          // Nothing of the path draws over the header.
          final path = tester.getRect(find.byKey(const ValueKey('carte-path')));
          expect(path.top, greaterThanOrEqualTo(header.bottom));

          await tester.tap(pill);
          await tester.pumpAndSettle();
          expect(curriculum.requested.last, 'FR');
          expect(find.text('Lire'), findsOneWidget);
        });
      }
    },
  );

  group('a failed sync says so (Hafid: published lessons read "soon")', () {
    testWidgets('cached lessons after a failed sync carry a note and a retry', (
      tester,
    ) async {
      final api = FakeContentApi({
        'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1'),
      });
      await openCarte(
        tester,
        appUnder(leaves: const [_compter], content: const {}, contentApi: api),
      );
      expect(find.byKey(const ValueKey('carte-stale')), findsNothing);

      // The server goes down; a refresh keeps the cache and says how old.
      api.failing = true;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PathScreen)),
      );
      await tester.runAsync(
        () => container.read(pathControllerProvider.notifier).refresh(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('carte-stale')), findsOneWidget);
      expect(
        find.textContaining('Activités à jour au'),
        findsOneWidget,
        reason: 'the last good sync, not "never"',
      );
      expect(find.byKey(const ValueKey('path-orb-leaf-1')), findsOneWidget);

      // Back up: Réessayer syncs and the note goes.
      api.failing = false;
      await tester.tap(find.text('Réessayer'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('carte-stale')), findsNothing);
    });

    testWidgets('showing the Carte again re-syncs once the last is old', (
      tester,
    ) async {
      final curriculum = FakeCurriculumApi({
        'MATH': const [_compter],
      });
      await openCarte(
        tester,
        appUnder(leaves: const [], content: const {}, curriculum: curriculum),
      );
      final before = curriculum.requested.length;
      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(PathScreen)),
      ).read(pathControllerProvider.notifier);

      await tester.runAsync(notifier.refreshIfStale);
      expect(curriculum.requested.length, before, reason: 'just synced');
      await tester.runAsync(
        () => notifier.refreshIfStale(maxAge: Duration.zero),
      );
      expect(curriculum.requested.length, before + 1);
    });

    testWidgets('tapping the subject already shown re-syncs it only when '
        'stale', (tester) async {
      final curriculum = FakeCurriculumApi({
        'MATH': const [_compter],
      });
      await openCarte(
        tester,
        appUnder(leaves: const [], content: const {}, curriculum: curriculum),
      );
      final before = curriculum.requested.length;
      await tester.tap(find.byKey(const ValueKey('subject-pill-MATH')));
      await tester.pumpAndSettle();
      expect(curriculum.requested.length, before, reason: 'just synced');
    });

    testWidgets('never synced and failing says lessons may be missing', (
      tester,
    ) async {
      final api = FakeContentApi(const {})..failing = true;
      await openCarte(
        tester,
        appUnder(leaves: const [_compter], content: const {}, contentApi: api),
      );
      expect(
        find.textContaining('Des activités peuvent manquer'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the header shows XP beside the level (Hafid: "Why is the XP '
      'not showing?")', (tester) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_compter],
        content: const {},
        progress: const ProgressState(loading: false, level: 3, totalXp: 120),
      ),
    );
    expect(find.text('Niv. 3'), findsOneWidget);
    expect(find.text('120 XP'), findsOneWidget);
  });
}
