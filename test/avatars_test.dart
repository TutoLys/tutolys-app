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
  _FakeProfileApi? profileApi,
}) {
  return ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      sessionControllerProvider.overrideWith(_FixedSession.new),
      progressApiProvider.overrideWithValue(_FakeProgressApi(level)),
      profileApiProvider.overrideWithValue(profileApi ?? _FakeProfileApi()),
      questBoardProvider.overrideWith((ref) async => _board(earned)),
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
    test('every starter is free from day one, nothing else', () {
      final earned = earnedAvatars(level: null, has: (_) => false);
      expect(earned, {
        for (final a in avatarCatalog)
          if (a.unlock is AvatarFree) a.key,
      });
      expect(earned, hasLength(6));
    });

    test('a level unlocks every avatar at or below it', () {
      final earned = earnedAvatars(level: 3, has: (_) => false);
      expect(earned, containsAll(['tuque', 'astronaut']));
      expect(earned, isNot(contains('captain')));
    });

    test('an achievement unlocks its own avatar', () {
      final earned = earnedAvatars(
        level: 1,
        has: (a) => a == Achievement.streak7,
      );
      expect(earned, contains('hero'));
      expect(earned, isNot(contains('camper')));
    });

    test('catalog keys are unique and backend-safe', () {
      final keys = [for (final a in avatarCatalog) a.key];
      expect(keys.toSet(), hasLength(keys.length));
      for (final k in keys) {
        expect(RegExp(r'^[a-z0-9][a-z0-9_]{0,63}$').hasMatch(k), isTrue, reason: k);
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

    test('an unknown key draws the default', () {
      expect(avatarFor('from_a_newer_app').key, defaultAvatarKey);
      expect(avatarFor('').key, defaultAvatarKey);
    });
  });

  group('AvatarStore', () {
    test('unlocks are monotonic and kid-scoped', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final a = AvatarStore(db, kidId: 'k1');
      final b = AvatarStore(db, kidId: 'k2');

      await a.recordUnlocked(['tuque']);
      // A later read with a lower level records nothing new and loses nothing.
      expect(await a.recordUnlocked(['kid_wavy']), {'tuque', 'kid_wavy'});
      expect(await b.unlocked(), isEmpty);
    });
  });

  group('AvatarController', () {
    test('starts on the default, adopting the backend\'s key if it has one',
        () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final c = _container(db: db, profileApi: _FakeProfileApi(remote: 'kid_curly'));
      addTearDown(c.dispose);

      expect((await _settle(c)).selected, 'kid_curly');
    });

    test('selecting an unlocked avatar wears it and pushes it up', () async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      final api = _FakeProfileApi();
      final c = _container(db: db, level: 2, profileApi: api);
      addTearDown(c.dispose);
      await _settle(c);

      await c.read(avatarControllerProvider.notifier).select('tuque');

      expect(c.read(selectedAvatarKeyProvider), 'tuque');
      expect(api.saved, ['tuque']);
      expect(await AvatarStore(db, kidId: 'k1').selected(), 'tuque');
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

    test('an avatar from before the sex was set stays on, but is not offered',
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
    });

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

    testWidgets('a locked avatar says what unlocks it and ignores taps',
        (tester) async {
      final c = await pumpPicker(tester, level: 1);

      expect(find.text(Strings.fr.avatarAtLevel(20)), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('avatar-fox_hood')));
      await tester.tap(find.byKey(const ValueKey('avatar-fox_hood')));
      await tester.pumpAndSettle();

      expect(c.read(selectedAvatarKeyProvider), defaultAvatarKey);
    });

    testWidgets('an unlocked one shows its name, and a tap wears it',
        (tester) async {
      final c = await pumpPicker(
        tester,
        level: 1,
        earned: {Achievement.streak3},
      );

      expect(find.text(Strings.fr.avatarName('camper')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('avatar-kid_braids')));
      await tester.pumpAndSettle();

      expect(c.read(selectedAvatarKeyProvider), 'kid_braids');
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
