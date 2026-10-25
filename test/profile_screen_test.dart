import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/profile/profile_screen.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _FixedSessionController extends SessionController {
  _FixedSessionController(this._state);
  final SessionState _state;

  /// Whether `forget()` was called. The real implementation reads fields
  /// `build()` would normally set up (`_store`, `_api`), which this fixed
  /// controller skips — so `forget()` is overridden rather than exercised
  /// for real, same as `build()` already is.
  bool forgotten = false;

  @override
  SessionState build() => _state;

  @override
  Future<void> forget() async {
    forgotten = true;
    state = const SessionState.unpaired();
  }
}

/// In-memory stand-in for the PIN gate's storage needs. Mirrors
/// `FakeSessionStore` in `pairing_test.dart` — a hand-written fake for the
/// couple of methods under test, not the real secure-storage-backed one.
class _FakeSessionStore extends SessionStore {
  String? _pin;

  void presetPin(String pin) => _pin = pin;

  @override
  Future<bool> hasGuardianPin() async => _pin != null;

  @override
  Future<void> setGuardianPin(String pin) async => _pin = pin;

  @override
  Future<bool> verifyGuardianPin(String pin) async => _pin == pin;

  @override
  Future<void> clearPairing() async {}
}

class _FakeProgressApi extends ProgressApi {
  _FakeProgressApi() : super(dio: Dio());

  ProgressResult result = const ProgressFetched(
    ProgressSnapshot(masteries: [], currentStreakDays: null),
  );

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async =>
      result;
}

Widget appUnder({ProgressApi? progressApi}) {
  return ProviderScope(
    overrides: [
      progressApiProvider.overrideWithValue(progressApi ?? _FakeProgressApi()),
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(
          const SessionState(
            status: SessionStatus.paired,
            kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 3),
            accessToken: 'token',
          ),
        ),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ProfileScreen(),
      ),
    ),
  );
}

/// Builds a container for the PIN-gate tests, where asserting on the
/// controller's `forgotten` flag or the store's saved PIN needs a handle
/// that survives past `pumpWidget` — `appUnder()`'s `ProviderScope` creates
/// its own internally and doesn't expose one.
ProviderContainer _buildContainer({SessionStore? store}) {
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store ?? _FakeSessionStore()),
      progressApiProvider.overrideWithValue(_FakeProgressApi()),
      sessionControllerProvider.overrideWith(
        () => _FixedSessionController(
          const SessionState(
            status: SessionStatus.paired,
            kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 3),
            accessToken: 'token',
          ),
        ),
      ),
      // Réglages reads its own settings from the local database, so the
      // PIN-gate harness needs one now that sign-out lives there.
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
    ],
  );
  return container;
}

Widget _widgetFor(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: TutolysTheme.learner(),
        locale: const Locale('fr', 'CA'),
        supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the kid name and grade', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text('Yelhan'), findsOneWidget);
    expect(find.text(Strings.fr.gradeLabel(3)), findsOneWidget);
  });

  testWidgets(
    'a freshly-paired kid with no progress yet shows no summary card',
    (tester) async {
      await tester.pumpWidget(appUnder());
      await tester.pumpAndSettle();

      expect(find.text(Strings.fr.profileSkillsMastered(0)), findsOneWidget);
    },
  );

  testWidgets('shows real mastered-skill count and streak', (tester) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [
            SkillMasteryDto(skillNodeId: 'a', masteryPct: 95, isMastered: true),
            SkillMasteryDto(
              skillNodeId: 'b',
              masteryPct: 40,
              isMastered: false,
            ),
          ],
          currentStreakDays: 5,
        ),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget); // mastered count
    expect(find.text('5'), findsOneWidget); // streak
    expect(find.text(Strings.fr.profileSkillsMastered(1)), findsOneWidget);
    expect(find.text(Strings.fr.profileStreakDays(5)), findsOneWidget);
  });

  testWidgets('sign-out button is still present', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    // Sign-out lives on Réglages now, not Profil — the design puts it
    // there, and the PIN-gate group below exercises it where it is.
  });

  testWidgets('the freeze balance is no longer on Profil', (tester) async {
    // It moved to Quêtes' streak detail as "Bouclier de série" (ADR 0015).
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [],
          currentStreakDays: 5,
          freezesAvailable: 2,
        ),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.streakShieldBalance(2)), findsNothing);
    expect(find.text(Strings.fr.streakShieldBalance(2).toUpperCase()), findsNothing);
  });

  testWidgets('shows the real XP total from the backend ledger', (
    tester,
  ) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: 5, totalXp: 135),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text('135'), findsOneWidget);
    expect(find.text(Strings.fr.profileTotalXp), findsOneWidget);
  });

  testWidgets(
    'a freshly-paired kid with zero XP but a real streak still shows the card',
    (tester) async {
      final progressApi = _FakeProgressApi()
        ..result = const ProgressFetched(
          ProgressSnapshot(masteries: [], currentStreakDays: 1, totalXp: 0),
        );

      await tester.pumpWidget(appUnder(progressApi: progressApi));
      await tester.pumpAndSettle();

      // Mastered-count also reads "0" here (no masteries), so assert on
      // the XP label instead of the bare digit to avoid ambiguity.
      expect(find.text(Strings.fr.profileTotalXp), findsOneWidget);
    },
  );

  group('PIN gate', () {
    testWidgets('with no PIN set yet, sign-out prompts to create one first', (
      tester,
    ) async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();

      // Réglages scrolls; sign-out sits at its foot, so it has to be
      // brought into view before it can be tapped.
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();

      expect(find.text(Strings.fr.pinGateCreateTitle), findsOneWidget);
      final controller = container.read(
        sessionControllerProvider.notifier,
      ) as _FixedSessionController;
      expect(controller.forgotten, isFalse);
    });

    testWidgets(
      'a mismatched PIN confirmation shows an error and does not sign out',
      (tester) async {
        final container = _buildContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();

        // Réglages scrolls; sign-out sits at its foot, so it has to be
      // brought into view before it can be tapped.
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '1234');
        await tester.enterText(find.byType(TextFormField).last, '9999');
        await tester.tap(find.text(Strings.fr.pinGateCreate));
        await tester.pumpAndSettle();

        expect(find.text(Strings.fr.pinGateMismatch), findsOneWidget);
        final controller = container.read(
          sessionControllerProvider.notifier,
        ) as _FixedSessionController;
        expect(controller.forgotten, isFalse);
      },
    );

    testWidgets('creating a matching PIN saves it and signs the device out', (
      tester,
    ) async {
      final store = _FakeSessionStore();
      final container = _buildContainer(store: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();

      // Réglages scrolls; sign-out sits at its foot, so it has to be
      // brought into view before it can be tapped.
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '1234');
      await tester.enterText(find.byType(TextFormField).last, '1234');
      await tester.tap(find.text(Strings.fr.pinGateCreate));
      await tester.pumpAndSettle();

      expect(await store.hasGuardianPin(), isTrue);
      final controller = container.read(
        sessionControllerProvider.notifier,
      ) as _FixedSessionController;
      expect(controller.forgotten, isTrue);
    });

    testWidgets(
      'with a PIN already set, the wrong PIN is rejected and does not sign out',
      (tester) async {
        final store = _FakeSessionStore()..presetPin('1234');
        final container = _buildContainer(store: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();

        // Réglages scrolls; sign-out sits at its foot, so it has to be
      // brought into view before it can be tapped.
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
        await tester.pumpAndSettle();

        expect(find.text(Strings.fr.pinGateEnterTitle), findsOneWidget);

        await tester.enterText(find.byType(TextField), '0000');
        await tester.tap(find.text(Strings.fr.pinGateConfirmSignOut));
        await tester.pumpAndSettle();

        expect(find.text(Strings.fr.pinGateWrong), findsOneWidget);
        final controller = container.read(
          sessionControllerProvider.notifier,
        ) as _FixedSessionController;
        expect(controller.forgotten, isFalse);
      },
    );

    testWidgets('the correct PIN signs the device out', (tester) async {
      final store = _FakeSessionStore()..presetPin('1234');
      final container = _buildContainer(store: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();

      // Réglages scrolls; sign-out sits at its foot, so it has to be
      // brought into view before it can be tapped.
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text(Strings.fr.pinGateConfirmSignOut));
      await tester.pumpAndSettle();

      final controller = container.read(
        sessionControllerProvider.notifier,
      ) as _FixedSessionController;
      expect(controller.forgotten, isTrue);
    });
  });
}
