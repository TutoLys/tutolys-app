import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/page_tab.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/sync/content_freshness.dart';
import 'package:tutolys_app/features/home/subject_progress.dart';
import 'package:tutolys_app/features/home/village_scene.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/path/programme.dart';
import 'package:tutolys_app/features/path/subject_language.dart';
import 'package:tutolys_app/features/path/subject_pills.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';

const _frenchSet = ['MATH', 'FR', 'SCI', 'SOC', 'CCQ', 'ESL'];
const _englishSet = ['MATH', 'EN', 'SCI', 'SOC', 'CCQ', 'FLS'];

class _Session extends SessionController {
  _Session([this.kid = 'lea']);
  final String kid;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.paired,
    accessToken: 'token',
    kid: PairedKid(id: kid, displayName: 'x', gradeLevel: 1),
  );
}

class _Kid extends Notifier<String?> {
  @override
  String? build() => 'lea';
  void set(String id) => state = id;
}

/// A backend serving one programme, beside an empty tree.
class _Curriculum extends CurriculumApi {
  _Curriculum(this.programme) : super(dio: Dio());
  Programme? programme;
  final asked = <String>[];

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) async {
    asked.add(subject);
    return CurriculumTreeFetched(const [], programme: programme);
  }
}

class _NoContent extends ContentApi {
  _NoContent() : super(dio: Dio());

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async => const ManifestFetched(
    ContentManifest(grade: 1, manifestHash: 'm', entries: []),
  );
}

Widget _app(Widget child, {Locale locale = const Locale('fr', 'CA')}) =>
    MediaQuery(
      data: const MediaQueryData(size: Size(900, 900), disableAnimations: true),
      child: MaterialApp(
        theme: TutolysTheme.village(),
        locale: locale,
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

/// The two second-language programmes (ADR 0101, backend work order
/// `APP_WORKORDER_SECOND_LANGUAGES.md`).
void main() {
  group('the programme from the backend', () {
    test('read beside the tree; absent from an older backend', () {
      final p = Programme.fromJson({
        'nodes': const [],
        'subjects': _englishSet,
        'school_language_required': false,
      });
      expect(p!.subjects, _englishSet);
      expect(p.schoolLanguageRequired, isFalse);
      expect(Programme.fromJson({'nodes': const []}), isNull);
      expect(
        Programme.fromJson({
          'subjects': _frenchSet,
          'school_language_required': true,
        })!.schoolLanguageRequired,
        isTrue,
      );
    });

    test('before any answer, the French set: the backend\'s own fallback', () {
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
          activeKidIdProvider.overrideWithValue('lea'),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(programmeSubjectsProvider), _frenchSet);
      expect(c.read(programmeProvider).schoolLanguageRequired, isFalse);
    });

    test('kept per kid, so siblings at schools of different languages each '
        'open on their own, offline', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final kid = NotifierProvider<_Kid, String?>(_Kid.new);
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWith((ref) => ref.watch(kid)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(programmeProvider, (_, _) {});
      await c
          .read(programmeProvider.notifier)
          .adopt('lea', const Programme(subjects: _englishSet));
      expect(c.read(programmeSubjectsProvider), _englishSet);

      // Noah's answer lands while Léa plays: stored for him, not shown.
      await c
          .read(programmeProvider.notifier)
          .adopt('noah', const Programme(subjects: _frenchSet));
      expect(c.read(programmeSubjectsProvider), _englishSet);

      c.read(kid.notifier).set('noah');
      await pumpEventQueue();
      expect(c.read(programmeSubjectsProvider), _frenchSet);
      c.read(kid.notifier).set('lea');
      await pumpEventQueue();
      expect(c.read(programmeSubjectsProvider), _englishSet);
    });
  });

  group('the Carte follows it', () {
    late ProviderContainer c;
    late _Curriculum curriculum;

    ProviderContainer build(Programme programme) {
      curriculum = _Curriculum(programme);
      return ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
          curriculumApiProvider.overrideWithValue(curriculum),
          contentApiProvider.overrideWithValue(_NoContent()),
          offlinePrefetchProvider.overrideWithValue(true),
          sessionControllerProvider.overrideWith(_Session.new),
        ],
      );
    }

    tearDown(() async {
      await pumpEventQueue(times: 200);
      c.dispose();
    });

    test('the background sync asks for this kid\'s subjects only: never '
        'the other programme\'s', () async {
      c = build(const Programme(subjects: _englishSet));
      await c.read(pathControllerProvider.notifier).refresh();
      await pumpEventQueue(times: 300);
      expect(curriculum.asked.toSet(), _englishSet.toSet());
      expect(curriculum.asked, isNot(contains('FR')));
      expect(curriculum.asked, isNot(contains('ESL')));
    });

    test('a subject that left the programme moves the Carte to one that '
        'is in it', () async {
      c = build(const Programme(subjects: _englishSet));
      final path = c.read(pathControllerProvider.notifier);
      await path.selectSubject('FR');
      await pumpEventQueue(times: 50);
      expect(c.read(pathControllerProvider).subject, 'MATH');
    });

    test('a synced subject with no lesson is known to be empty; one never '
        'synced is not', () async {
      c = build(const Programme(subjects: _frenchSet));
      final db = c.read(localDatabaseProvider);
      c.listen(subjectsWithoutLessonsProvider, (_, _) {});
      expect(await c.read(subjectsWithoutLessonsProvider.future), isEmpty);
      await ContentFreshness(db).markSynced('ESL', 1);
      c.invalidate(subjectsWithoutLessonsProvider);
      expect(await c.read(subjectsWithoutLessonsProvider.future), {'ESL'});
    });
  });

  group('lesson language (ADR 0023)', () {
    test('ESL is English and FLS French, whatever the app is set to', () {
      for (final app in const [Locale('fr', 'CA'), Locale('en', 'CA')]) {
        expect(contentLocaleFor('ESL', app), 'en-CA');
        expect(contentLocaleFor('FLS', app), 'fr-CA');
      }
      // Non-language subjects still follow the app.
      expect(contentLocaleFor('MATH', const Locale('en', 'CA')), 'en-CA');
    });
  });

  group('drawn', () {
    Future<void> pills(WidgetTester tester, List<String> subjects) async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('lea'),
        ],
      );
      addTearDown(c.dispose);
      await c
          .read(programmeProvider.notifier)
          .adopt('lea', Programme(subjects: subjects));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(
            SubjectPills(selected: 'MATH', compact: false, onSelect: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pills: an English-school kid gets English and French, and '
        'CCQ, from the list, never Français + Anglais', (tester) async {
      await pills(tester, _englishSet);
      for (final code in _englishSet) {
        expect(
          find.byKey(ValueKey('subject-pill-$code')),
          findsOneWidget,
          reason: code,
        );
      }
      expect(find.byKey(const ValueKey('subject-pill-FR')), findsNothing);
      expect(find.byKey(const ValueKey('subject-pill-ESL')), findsNothing);
    });

    testWidgets('pills: a code the app has never heard of still gets one', (
      tester,
    ) async {
      await pills(tester, [..._frenchSet, 'NEW']);
      expect(find.byKey(const ValueKey('subject-pill-NEW')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Village: a second language with no lessons says « Bientôt », '
        'in colour and still tappable, never 0 %', (tester) async {
      String? tapped;
      final buildings = [
        for (final b in villageBuildings(Strings.fr))
          b.withProgress(null, hasLessons: b.subject != 'ESL'),
      ];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 1000,
            height: 580,
            child: VillageScene(
              buildings: buildings,
              signTitle: 'x',
              signSubtitle: 'y',
              onTapBuilding: (b) => tapped = b.subject,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scene-soon-ESL')), findsOneWidget);
      expect(find.byKey(const ValueKey('scene-new-ESL')), findsNothing);
      expect(find.byKey(const ValueKey('scene-new-MATH')), findsOneWidget);
      final esl = find.byKey(const ValueKey('village-building-ESL'));
      expect(esl.hitTestable(), findsOneWidget);
      await tester.tap(esl);
      expect(tapped, 'ESL');
    });

    Future<void> parentZone(WidgetTester tester, {required bool ask}) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          activeKidIdProvider.overrideWithValue('lea'),
          sessionControllerProvider.overrideWith(_Session.new),
        ],
      );
      addTearDown(c.dispose);
      await c
          .read(programmeProvider.notifier)
          .adopt(
            'lea',
            Programme(subjects: _frenchSet, schoolLanguageRequired: ask),
          );
      await c
          .read(pageTabProvider(TabbedPage.settings).notifier)
          .select(SettingsTab.parents.name);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: _app(const SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an unset school language is asked in Zone parent, of an '
        'adult', (tester) async {
      await parentZone(tester, ask: true);
      expect(
        find.byKey(const ValueKey('parent-zone-school-language')),
        findsOneWidget,
      );
      expect(
        find.text(Strings.fr.settingsSchoolLanguageNeeded),
        findsOneWidget,
      );
    });

    testWidgets('and not once it is set', (tester) async {
      await parentZone(tester, ask: false);
      expect(
        find.byKey(const ValueKey('parent-zone-school-language')),
        findsNothing,
      );
    });

    test('a kid knows the second language by its language\'s name', () {
      expect(subjectLabel(Strings.fr, 'ESL'), 'Anglais');
      expect(subjectLabel(Strings.en, 'ESL'), 'English');
      expect(subjectLabel(Strings.fr, 'FLS'), 'Français');
      expect(subjectLabel(Strings.en, 'FLS'), 'French');
    });
  });
}
