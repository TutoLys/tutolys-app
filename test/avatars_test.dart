import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/profile_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/profile/avatar_picker.dart';
import 'package:tutolys_app/features/profile/avatars.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';

class _FixedSession extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1),
    accessToken: 'token',
  );
}

class _FakeProgressApi extends ProgressApi {
  _FakeProgressApi(this.level) : super(dio: Dio());
  final int? level;

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async =>
      ProgressFetched(
        ProgressSnapshot(
          masteries: const [],
          currentStreakDays: 1,
          level: level,
          // Grade levels (app ADR 0033): 98 skills, level - 1 done.
          skillsCompleted: level == null ? null : level! - 1,
          skillsTotal: level == null ? null : 98,
        ),
      );
}

class _FakeProfileApi extends ProfileApi {
  _FakeProfileApi({this.remote, this.sex = KidSex.unspecified})
    : super(dio: Dio());
  final String? remote;
  KidSex sex;
  final saved = <String>[];

  @override
  Future<RemoteProfile?> fetchProfile({required String accessToken}) async =>
      RemoteProfile(avatarKey: remote ?? '', sex: sex);

  @override
  Future<bool> saveAvatarKey({
    required String accessToken,
    required String avatarKey,
  }) async {
    saved.add(avatarKey);
    return true;
  }
}

class _OfflineProfileApi extends _FakeProfileApi {
  @override
  Future<RemoteProfile?> fetchProfile({required String accessToken}) async =>
      null;
}

QuestBoard _board(Set<Achievement> earned) => QuestBoard(
  quests: const [],
  weekCompleted: 0,
  unlocked: {for (final a in earned) a.name: '2026-10-20'},
  today: DateTime(2026, 10, 25),
);

ProviderContainer _container({
  required LocalDatabase db,
  int? level,
  Set<Achievement> earned = const {},
  Map<String, int> bySubject = const {},
  _FakeProfileApi? profileApi,
}) {
  return ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      sessionControllerProvider.overrideWith(_FixedSession.new),
      progressApiProvider.overrideWithValue(_FakeProgressApi(level)),
      profileApiProvider.overrideWithValue(profileApi ?? _FakeProfileApi()),
      questBoardProvider.overrideWith((ref) async => _board(earned)),
      completedSkillsBySubjectProvider.overrideWith((ref) async => bySubject),
    ],
  );
}

/// Lets ProgressController's microtask load land, then reads the avatar.
Future<AvatarState> _settle(ProviderContainer c) async {
  c.read(progressControllerProvider);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c.read(avatarControllerProvider.future);
}

void main() {
  group('earnedAvatars', () {
    test('the free ones are free from day one, nothing else', () {
      final earned = earnedAvatars(level: null, has: (_) => false);
      expect(earned, {
        for (final a in avatarCatalog)
          if (a.unlock is AvatarFree) a.key,
      });
      // Six starters, plus the camper and the explorer as girl and boy.
      expect(earned, hasLength(10));
      expect(earned, containsAll(['camper_girl', 'explorer_boy']));
    });

    test('a level unlocks every avatar at or below it', () {
      final earned = earnedAvatars(level: 3, has: (_) => false);
      expect(earned, contains('tuque_girl'));
      expect(earned, isNot(contains('captain_girl')));
    });

    test('an achievement unlocks both keys of its character', () {
      final earned = earnedAvatars(
        level: 1,
        has: (a) => a == Achievement.streak7,
      );
      expect(earned, containsAll(['hero_girl', 'hero_boy']));
      expect(earned, isNot(contains('artist_girl')));
    });

    test('a subject unlocks its characters, tier by tier', () {
      Set<String> at(int sci) => earnedAvatars(
        level: 1,
        has: (_) => false,
        completedIn: (s) => s == 'SCI' ? sci : 0,
      );
      expect(at(4), isNot(contains('scientist_girl')));
      expect(at(5), containsAll(['scientist_girl', 'scientist_boy']));
      expect(at(5), isNot(contains('chemist_girl')));
      expect(at(15), containsAll(['chemist_girl', 'chemist_boy']));
      // Science says nothing about the other subjects.
      expect(at(15), isNot(contains('knight_girl')));
    });

    test('every subject has an avatar, and rare ones are never earned', () {
      final subjects = {
        for (final a in avatarCatalog)
          if (a.unlock case AvatarForSubject(:final subject)) subject,
      };
      expect(subjects, {'MATH', 'FR', 'EN', 'SCI', 'SOC', 'CCQ'});
      final all = earnedAvatars(
        level: 99,
        has: (_) => true,
        completedIn: (_) => 1000,
      );
      for (final a in avatarCatalog.where((a) => a.unlock is AvatarRare)) {
        expect(all, isNot(contains(a.key)), reason: a.key);
      }
    });

    test('the two keys of a character share one unlock and differ in sex', () {
      final groups = <String, List<AvatarDef>>{};
      for (final a in avatarCatalog.where((a) => a.group != null)) {
        groups.putIfAbsent(a.group!, () => []).add(a);
      }
      for (final MapEntry(key: group, value: defs) in groups.entries) {
        expect(defs.map((a) => a.unlock).toSet(), hasLength(1), reason: group);
        expect(
          defs.map((a) => a.sex).toSet(),
          hasLength(defs.length),
          reason: group,
        );
      }
    });

    test('every avatar has a name in both languages', () {
      for (final a in avatarCatalog.where((a) => a.unlock is! AvatarFree)) {
        expect(Strings.fr.avatarName(a.key), isNot('Avatar'), reason: a.key);
        expect(Strings.en.avatarName(a.key), isNot('Avatar'), reason: a.key);
      }
    });

    test('catalog keys are unique and backend-safe', () {
      final keys = [for (final a in avatarCatalog) a.key];
      expect(keys.toSet(), hasLength(keys.length));
      for (final k in keys) {
        expect(
          RegExp(r'^[a-z0-9][a-z0-9_]{0,63}$').hasMatch(k),
          isTrue,
          reason: k,
        );
      }
    });

    test('every bundled avatar file exists, as a small webp', () {
      for (final a in avatarCatalog) {
        if (a.asset == null) continue;
        final f = File('assets/images/${a.asset}');
        expect(f.existsSync(), isTrue, reason: a.asset);
        expect(a.asset, endsWith('.webp'), reason: a.asset);
        // Every avatar ships in every build, web included.
        expect(f.lengthSync(), lessThan(120 * 1024), reason: a.asset);
      }
    });

    test('every starter has a sex; the defaults follow it', () {
      for (final a in avatarCatalog.where((a) => a.unlock is AvatarFree)) {
        expect(a.sex, isNotNull, reason: a.key);
      }
      expect(avatarFor(defaultAvatarFor(KidSex.girl)).sex, KidSex.girl);
      expect(avatarFor(defaultAvatarFor(KidSex.boy)).sex, KidSex.boy);
      expect(defaultAvatarFor(KidSex.unspecified), defaultAvatarKey);
    });

    test('a kid is offered their own sex, and everyone is offered all', () {
      final girl = avatarCatalog.where((a) => offeredTo(a, KidSex.girl));
      final boy = avatarCatalog.where((a) => offeredTo(a, KidSex.boy));
      expect(girl.map((a) => a.key), containsAll(['kid_wavy', 'kid_glasses']));
      expect(girl.map((a) => a.key), isNot(contains('kid_curly')));
      expect(boy.map((a) => a.key), contains('kid_curly'));
      expect(boy.map((a) => a.key), isNot(contains('kid_wavy')));
      expect(
        avatarCatalog.where((a) => offeredTo(a, KidSex.unspecified)),
        hasLength(avatarCatalog.length),
      );
    });

    test('the backend\'s sex value parses, unknown is unspecified', () {
      expect(KidSex.parse('girl'), KidSex.girl);
      expect(KidSex.parse('boy'), KidSex.boy);
      expect(KidSex.parse(''), KidSex.unspecified);
      expect(KidSex.parse(null), KidSex.unspecified);
    });

    test('the hash is FNV-1a, so every platform rolls the same', () {
      expect(stableHash(''), 0x811c9dc5);
      expect(stableHash('a'), 0xe40c292c);
      expect(stableHash('foobar'), 0xbf9cf968);
    });

    test('an unknown key draws the default', () {
      expect(avatarFor('from_a_newer_app').key, defaultAvatarKey);
      expect(avatarFor('').key, defaultAvatarKey);
    });
  });

  group('rareDropFor', () {
    String? roll(
      String lesson, {
      String kid = 'k1',
      KidSex sex = KidSex.girl,
      Set<String> unlocked = const {},
    }) =>
        rareDropFor(kidId: kid, lessonId: lesson, sex: sex, unlocked: unlocked);
    final lessons = [for (var i = 0; i < 4000; i++) 'lesson-$i'];

    test('is deterministic per kid and lesson', () {
      for (final l in lessons.take(200)) {
        expect(roll(l), roll(l));
      }
      final hits = lessons.where((l) => roll(l) != null).toList();
      final siblingHits = lessons.where((l) => roll(l, kid: 'k2') != null);
      expect(hits.toSet(), isNot(siblingHits.toSet()));
    });

    test('drops on about one perfect lesson in 20', () {
      final share =
          lessons.where((l) => roll(l) != null).length / lessons.length;
      expect(share, inInclusiveRange(0.035, 0.065));
    });

    test('drops only characters for the kid\'s sex, never a duplicate', () {
      for (final l in lessons) {
        final girl = roll(l);
        if (girl != null) expect(girl, isNot('pirate'));
        final boy = roll(l, sex: KidSex.boy);
        if (boy != null) expect(boy, isNot('mermaid'));
      }
      final owned = {
        for (final a in avatarCatalog)
          if (a.unlock is AvatarRare && a.sex != KidSex.boy) a.key,
      };
      expect(lessons.map((l) => roll(l, unlocked: owned)).nonNulls, isEmpty);
    });
  });

  group('historical figures', () {
    final lessons = [for (var i = 0; i < 4000; i++) 'lesson-$i'];
    String? roll(String lesson, String? subject, {KidSex sex = KidSex.girl}) =>
        rareDropFor(
          kidId: 'k1',
          lessonId: lesson,
          sex: sex,
          unlocked: const {},
          subject: subject,
        );

    test('drop only from a CCQ lesson', () {
      bool historical(String? c) => c != null && c.startsWith('hist_');
      expect(lessons.map((l) => roll(l, 'MATH')).where(historical), isEmpty);
      expect(lessons.map((l) => roll(l, null)).where(historical), isEmpty);
      final ccq = lessons.map((l) => roll(l, 'CCQ')).where(historical).toSet();
      expect(ccq, {'hist_therese_casgrain', 'hist_rene_levesque'});
    });

    test('are offered to every kid, and say who they were', () {
      final hist = avatarCatalog.where((a) => a.isHistorical).toList();
      expect(hist.map((a) => a.key), [
        'hist_therese_casgrain',
        'hist_rene_levesque',
      ]);
      for (final a in hist) {
        expect(a.unlock, isA<AvatarRare>());
        expect((a.unlock as AvatarRare).subject, 'CCQ');
        for (final sex in KidSex.values) {
          expect(offeredTo(a, sex), isTrue, reason: '${a.key} $sex');
        }
        expect(Strings.fr.avatarCaption(a.key), isNotNull, reason: a.key);
        expect(Strings.en.avatarCaption(a.key), isNotNull, reason: a.key);
      }
      expect(Strings.fr.avatarCaption('wizard_girl'), isNull);
    });
  });

  group('AvatarStore', () {
    test('unlocks are monotonic and kid-scoped', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final a = AvatarStore(db, kidId: 'k1');
      final b = AvatarStore(db, kidId: 'k2');

      await a.recordUnlocked(['tuque_girl']);
      // A later read with a lower level records nothing new and loses nothing.
      expect(await a.recordUnlocked(['kid_wavy']), {'tuque_girl', 'kid_wavy'});
      expect(await b.unlocked(), isEmpty);
    });
  });

  group('AvatarController', () {
    test(
      'starts on the default, adopting the backend\'s key if it has one',
      () async {
        final db = LocalDatabase.memory();
        addTearDown(db.close);
        final c = _container(
          db: db,
          profileApi: _FakeProfileApi(remote: 'kid_curly'),
        );
        addTearDown(c.dispose);

        expect((await _settle(c)).selected, 'kid_curly');
      },
    );

    test('selecting an unlocked avatar wears it and pushes it up', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final api = _FakeProfileApi();
      final c = _container(db: db, level: 2, profileApi: api);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(avatarControllerProvider.notifier).select('tuque_girl');

      expect(c.read(selectedAvatarKeyProvider), 'tuque_girl');
      expect(api.saved, ['tuque_girl']);
      expect(await AvatarStore(db, kidId: 'k1').selected(), 'tuque_girl');
    });

    test('a subject\'s completed skills unlock its avatar', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(db: db, bySubject: {'CCQ': 5});
      addTearDown(c.dispose);

      final state = await _settle(c);
      expect(state.isUnlocked('knight_girl'), isTrue);
      expect(state.isUnlocked('fleur_knight_girl'), isFalse);
    });

    test('a key the catalog no longer has is worn as the default', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      // `tuque` was a key before the art came; no release ever shipped it.
      await AvatarStore(db, kidId: 'k1').select('tuque');
      final c = _container(
        db: db,
        profileApi: _FakeProfileApi(remote: 'tuque', sex: KidSex.boy),
      );
      addTearDown(c.dispose);

      expect((await _settle(c)).selected, 'kid_curly');
    });

    test('a rare drop unlocks its character once per lesson', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(
        db: db,
        profileApi: _FakeProfileApi(sex: KidSex.boy),
      );
      addTearDown(c.dispose);
      await _settle(c);
      final lucky = [for (var i = 0; i < 1000; i++) 'lesson-$i'].firstWhere(
        (l) =>
            rareDropFor(
              kidId: 'k1',
              lessonId: l,
              sex: KidSex.boy,
              unlocked: const {},
            ) !=
            null,
      );
      final notifier = c.read(avatarControllerProvider.notifier);

      final key = await notifier.rollRareDrop(lucky);
      expect(key, isNotNull);
      expect(avatarFor(key).sex, isNot(KidSex.girl));
      final unlocked = await AvatarStore(db, kidId: 'k1').unlocked();
      expect(unlocked, containsAll(keysOf(avatarFor(key).character)));

      // Replaying the same perfect lesson never drops again.
      expect(await notifier.rollRareDrop(lucky), isNull);
      expect(
        (await c.read(avatarControllerProvider.future)).isUnlocked(key!),
        isTrue,
      );
    });

    test('a boy with no choice yet wears a boy avatar, not Léa', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(
        db: db,
        profileApi: _FakeProfileApi(sex: KidSex.boy),
      );
      addTearDown(c.dispose);

      final state = await _settle(c);
      expect(state.selected, 'kid_curly');
      expect(state.offered.map((a) => a.key), isNot(contains('kid_wavy')));
      expect(await AvatarStore(db, kidId: 'k1').sex(), KidSex.boy);
    });

    test(
      'an avatar from before the sex was set stays on, but is not offered',
      () async {
        final db = LocalDatabase.memory();
        addTearDown(db.close);
        await AvatarStore(db, kidId: 'k1').select('kid_wavy');
        final api = _FakeProfileApi(sex: KidSex.boy);
        final c = _container(db: db, profileApi: api);
        addTearDown(c.dispose);

        final state = await _settle(c);
        expect(state.selected, 'kid_wavy');
        expect(state.offered.map((a) => a.key), isNot(contains('kid_wavy')));

        // Nor can it be picked again by key.
        await c.read(avatarControllerProvider.notifier).select('kid_glasses');
        expect(c.read(selectedAvatarKeyProvider), 'kid_wavy');
        expect(api.saved, isEmpty);
      },
    );

    test('the cached sex holds offline', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      await AvatarStore(db, kidId: 'k1').setSex(KidSex.boy);
      final c = _container(db: db, profileApi: _OfflineProfileApi());
      addTearDown(c.dispose);

      expect((await _settle(c)).selected, 'kid_curly');
    });

    test('a locked avatar is refused', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final api = _FakeProfileApi();
      final c = _container(db: db, level: 1, profileApi: api);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(avatarControllerProvider.notifier).select('fox_hood');

      expect(c.read(selectedAvatarKeyProvider), defaultAvatarKey);
      expect(api.saved, isEmpty);
    });
  });

  group('AvatarPicker', () {
    Future<ProviderContainer> pumpPicker(
      WidgetTester tester, {
      int? level,
      Set<Achievement> earned = const {},
      KidSex sex = KidSex.unspecified,
    }) async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(
        db: db,
        level: level,
        earned: earned,
        profileApi: _FakeProfileApi(sex: sex),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: TutolysTheme.learner(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: AvatarPicker()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('a locked avatar says what unlocks it and ignores taps', (
      tester,
    ) async {
      final c = await pumpPicker(tester, level: 1);

      expect(find.text(Strings.fr.avatarAtLevel(20)), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('avatar-fox_hood')));
      await tester.tap(find.byKey(const ValueKey('avatar-fox_hood')));
      await tester.pumpAndSettle();

      expect(c.read(selectedAvatarKeyProvider), defaultAvatarKey);
    });

    testWidgets('an unlocked one shows its name, and a tap wears it', (
      tester,
    ) async {
      final c = await pumpPicker(
        tester,
        level: 1,
        earned: {Achievement.streak7},
      );

      expect(find.text(Strings.fr.avatarName('hero_girl')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('avatar-kid_braids')));
      await tester.pumpAndSettle();

      expect(c.read(selectedAvatarKeyProvider), 'kid_braids');
    });

    testWidgets('a subject avatar says what unlocks it; a rare one is a ?', (
      tester,
    ) async {
      await pumpPicker(tester, level: 1, sex: KidSex.girl);

      expect(find.text(Strings.fr.avatarForSubject('SCI', 5)), findsOneWidget);
      // Four rare characters for a girl and the two historical figures,
      // none named before it's found.
      expect(find.text('?'), findsNWidgets(6));
      expect(find.text(Strings.fr.avatarHistoricalHint), findsNWidgets(2));
      expect(find.text(Strings.fr.avatarRareHint), findsNWidgets(4));
      expect(find.text(Strings.fr.avatarName('wizard_girl')), findsNothing);
    });

    Future<void> openFrom(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(db: db, level: 1);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: TutolysTheme.village(),
            locale: const Locale('fr', 'CA'),
            supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAvatarPicker(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('on desktop it is a centred dialog with a bounded height', (
      tester,
    ) async {
      const screen = Size(1920, 1040);
      await openFrom(tester, screen);

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      final box = tester.getRect(find.byType(AvatarPicker));
      expect(box.width, lessThanOrEqualTo(640));
      expect(box.height, lessThanOrEqualTo(screen.height * 0.85 + 0.5));
      expect(box.center.dx, closeTo(screen.width / 2, 1));
      expect(box.center.dy, closeTo(screen.height / 2, 1));

      // The avatars scroll inside it; the title and close button stay.
      final title = find.text(Strings.fr.avatarPickerTitle);
      final before = tester.getTopLeft(title);
      await tester.drag(
        find.byKey(const ValueKey('avatar-picker-scroll')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title), before);
      expect(tester.getRect(find.byType(AvatarPicker)), box);
    });

    testWidgets('on a phone it is a bottom sheet with a drag handle', (
      tester,
    ) async {
      const screen = Size(400, 800);
      await openFrom(tester, screen);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isTrue,
      );
      final box = tester.getRect(find.byType(AvatarPicker));
      expect(box.height, lessThanOrEqualTo(screen.height * 0.85 + 0.5));
    });

    testWidgets('a boy is shown only boy starters', (tester) async {
      await pumpPicker(tester, level: 1, sex: KidSex.boy);

      expect(find.byKey(const ValueKey('avatar-kid_curly')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-kid_freckles')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-kid_wavy')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-kid_braids')), findsNothing);
    });
  });
}
