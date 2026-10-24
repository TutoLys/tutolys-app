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
import 'package:tutolys_app/features/profile/profile_screen.dart';
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
        home: const ProfileScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the kid name and grade', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text('Yelhan'), findsOneWidget);
    expect(find.text(Strings.fr.profileGrade(3)), findsOneWidget);
  });

  testWidgets(
    'a freshly-paired kid with no progress yet shows no summary card',
    (tester) async {
      await tester.pumpWidget(appUnder());
      await tester.pumpAndSettle();

      expect(find.text(Strings.fr.profileSkillsMastered(0)), findsNothing);
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

    expect(find.text(Strings.fr.profileSignOut), findsOneWidget);
  });

  testWidgets('shows the real freeze balance from the backend', (tester) async {
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

    expect(find.text(Strings.fr.profileFreezesAvailable(2)), findsOneWidget);
  });

  testWidgets('no freeze line when the balance is unknown', (tester) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: 5),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.profileFreezesAvailable(0)), findsNothing);
  });

  group('PIN gate', () {
    testWidgets('with no PIN set yet, sign-out prompts to create one first', (
      tester,
    ) async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.fr.profileSignOut));
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

        await tester.tap(find.text(Strings.fr.profileSignOut));
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

      await tester.tap(find.text(Strings.fr.profileSignOut));
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

        await tester.tap(find.text(Strings.fr.profileSignOut));
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

      await tester.tap(find.text(Strings.fr.profileSignOut));
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
