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
import 'package:tutolys_app/features/profile/pin_gate.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/profile/avatar_picker.dart';
import 'package:tutolys_app/features/profile/profile_screen.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';
import 'package:tutolys_app/features/quests/quest_board.dart';

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
  Future<int?> guardianPinDigits() async => _pin?.length;

  @override
  Future<void> setGuardianPin(String pin) async => _pin = pin;

  @override
  Future<bool> verifyGuardianPin(String pin) async => _pin == pin;

  @override
  Future<DateTime?> guardianPinLockedUntil() async => null;

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

Widget appUnder({
  ProgressApi? progressApi,
  QuestBoard? board,
  VoidCallback? onSwitchProfile,
  VoidCallback? onOpenProgress,
  double sidebar = 0,
}) {
  return ProviderScope(
    overrides: [
      // The streak reads this device's own play days (ADR 0032).
      localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
      if (board != null) questBoardProvider.overrideWith((ref) async => board),
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
    // The window's real size, so wide layouts and the dialog breakpoint
    // apply; a bare MediaQueryData would report a 0×0 window.
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQueryData.fromView(View.of(context))
            .copyWith(disableAnimations: true),
        child: MaterialApp(
          theme: TutolysTheme.learner(),
          locale: const Locale('fr', 'CA'),
          supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            // The shell's sidebar or rail, when [sidebar] is set.
            body: Row(
              children: [
                SizedBox(width: sidebar),
                Expanded(
                  child: ProfileScreen(
                    onSwitchProfile: onSwitchProfile,
                    onOpenProgress: onOpenProgress,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens one of Profil's pill tabs (app ADR 0051): only the chosen tab's
/// card is built.
Future<void> _openTab(WidgetTester tester, String tab) async {
  final pill = find.byKey(ValueKey('profile-tab-$tab'));
  await tester.ensureVisible(pill);
  await tester.tap(pill);
  await tester.pumpAndSettle();
}

/// Builds a container for the PIN-gate tests, where asserting on the
/// controller's `forgotten` flag or the store's saved PIN needs a handle
/// that survives past `pumpWidget` — `appUnder()`'s `ProviderScope` creates
/// its own internally and doesn't expose one.
ProviderContainer _buildContainer({SessionStore? store}) {
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(store ?? _FakeSessionStore()),
      // The adult check before a first PIN (A5) asks 7 × 8.
      adultCheckFactsProvider.overrideWithValue(() => (7, 8)),
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

/// Past the PIN, the removal confirmation (ADR 0037) reads its summary
/// from drift, which needs real time; nothing is unsent here, so the one
/// way on is "Effacer maintenant".
Future<void> _confirmErase(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.tap(find.text(Strings.fr.removeKidEraseNow));
  await tester.pumpAndSettle();
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
  // Hafid, 2026-10-29: the column sits in the middle of the page area (the
  // window less the sidebar), not right of it, at every width.
  for (final width in [1024.0, 1950.0]) {
    testWidgets('Profil at $width: centred in the page area', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const sidebar = VillageMetrics.sidebarWidth;
      await tester.pumpWidget(appUnder(sidebar: sidebar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final column = tester.getRect(
        find
            .descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Column),
            )
            .first,
      );
      expect(column.center.dx, closeTo((sidebar + width) / 2, 0.5));
      expect(
        column.width,
        width - sidebar >= PageWidth.wideFrom
            ? PageWidth.columnWide
            : PageWidth.column,
      );
    });
  }

  testWidgets('the badge grid shows the eight, earned ones unlocked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        board: QuestBoard(
          quests: const [],
          weekCompleted: 0,
          unlocked: const {'streak3': '2026-10-20', 'streak7': '2026-10-24'},
          today: DateTime(2026, 10, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'badges');

    expect(find.byKey(const ValueKey('badge-streak3-earned')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-level10-locked')), findsOneWidget);
    expect(find.text(Strings.fr.achExplorer), findsOneWidget);
    // A 7-day streak earned the title, so it shows under the name.
    expect(find.text(Strings.fr.flameKeeperTitle), findsOneWidget);
  });

  for (final width in [1024.0, 1440.0]) {
    testWidgets('the badge card hugs its badges at ${width.round()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appUnder());
      await tester.pumpAndSettle();
      await _openTab(tester, 'badges');

      final card = find
          .ancestor(
            of: find.byKey(const ValueKey('profile-badges')),
            matching: find.byType(Material),
          )
          .first;
      // Two rows of a 54px badge and a two-line label (the pill names the
      // card, so no title): a grid with square-ish cells made this ~470px.
      expect(tester.getSize(card).height, lessThan(240));
      expect(tester.getSize(card).height, greaterThan(150));
    });
  }

  for (final width in [1440.0, 1920.0]) {
    testWidgets(
      'at ${width.round()}px the avatar dialog lines up with the Profil column',
      (tester) async {
        tester.view.physicalSize = Size(width, 1040);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(appUnder(sidebar: 224));
        await tester.pumpAndSettle();

        final column = tester.getRect(
          find
              .ancestor(
                of: find.byKey(const ValueKey('profile-avatar-edit')),
                // The outermost: the page column itself.
                matching: find.byType(Column),
              )
              .last,
        );
        await tester.tap(find.byKey(const ValueKey('profile-avatar-edit')));
        await tester.pumpAndSettle();

        final dialog = tester.getRect(find.byType(AvatarPicker));
        expect(column.center.dx, greaterThan(width / 2 + 100));
        expect(dialog.center.dx, closeTo(column.center.dx, 2));
        expect(dialog.left, closeTo(column.left, 2));
        expect(dialog.right, closeTo(column.right, 2));
        // The barrier still covers the whole window, sidebar included.
        expect(tester.getRect(find.byType(ModalBarrier).last).width, width);
      },
    );
  }

  testWidgets('recent activity lists the latest badges with their day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        board: QuestBoard(
          quests: const [],
          weekCompleted: 0,
          unlocked: const {'streak3': '2026-10-20', 'streak7': '2026-10-24'},
          today: DateTime(2026, 10, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'recent');

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('recent-activity-streak7')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('recent-activity-streak3')),
    );
    expect(first.dy, lessThan(second.dy));
    expect(find.text(Strings.fr.profileRecentDay(0)), findsOneWidget);
    expect(find.text(Strings.fr.profileRecentDay(4)), findsOneWidget);
    expect(find.text(Strings.fr.profileRecentEmpty), findsNothing);
  });

  testWidgets('recent activity says how to earn a first badge', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appUnder(
        board: QuestBoard(
          quests: const [],
          weekCompleted: 0,
          unlocked: const {},
          today: DateTime(2026, 10, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openTab(tester, 'recent');
    expect(find.text(Strings.fr.profileRecentEmpty), findsOneWidget);
  });

  testWidgets('three tabs under the hero, Par matière first, one at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.profileNoSubjects), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-badges')), findsNothing);
    // The hero stays above every tab.
    expect(find.text('Yelhan'), findsOneWidget);

    await _openTab(tester, 'badges');
    expect(find.byKey(const ValueKey('profile-badges')), findsOneWidget);
    expect(find.text(Strings.fr.profileNoSubjects), findsNothing);
    expect(find.text('Yelhan'), findsOneWidget);
  });

  testWidgets('Profil fits a phone on every tab', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();
    for (final tab in ['subjects', 'badges', 'recent']) {
      await _openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('the three stats sit on one row at 375 px (AM13)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [],
          currentStreakDays: 12,
          totalXp: 135,
          level: 2,
          skillsCompleted: 1,
          skillsTotal: 98,
        ),
      );
    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.progressLevel(2)), findsOneWidget);
    final cards = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byKey(ValueKey('profile-stat-$i'))),
    ];
    // One row: same top, left to right, all inside the screen.
    expect(cards[1].top, cards[0].top);
    expect(cards[2].top, cards[0].top);
    expect(cards[0].right, lessThan(cards[1].left));
    expect(cards[1].right, lessThan(cards[2].left));
    expect(cards[2].right, lessThanOrEqualTo(375));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no title until it is earned', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-title')), findsNothing);
  });

  testWidgets('shows the kid name and grade', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.text('Yelhan'), findsOneWidget);
    expect(find.text(Strings.fr.gradeLabel(3)), findsOneWidget);
  });

  testWidgets('the hero shows the design\'s three stats: streak and badges', (
    tester,
  ) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(masteries: [], currentStreakDays: 5),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text(Strings.fr.profileStreakLabel), findsOneWidget);
    expect(find.text(Strings.fr.profileBadgesEarned), findsOneWidget);
    // Mastered skills live on Progrès; Profil no longer repeats them.
    expect(find.text(Strings.fr.profileSkillsMastered(0)), findsNothing);
  });

  testWidgets('with a level, the first stat is the level over the XP total', (
    tester,
  ) async {
    final progressApi = _FakeProgressApi()
      ..result = const ProgressFetched(
        ProgressSnapshot(
          masteries: [],
          currentStreakDays: 1,
          totalXp: 135,
          level: 2,
          skillsCompleted: 1,
          skillsTotal: 98,
        ),
      );

    await tester.pumpWidget(appUnder(progressApi: progressApi));
    await tester.pumpAndSettle();

    expect(find.text(Strings.fr.progressLevel(2)), findsOneWidget);
    expect(find.text('135 ${Strings.fr.profileTotalXp}'), findsOneWidget);
  });

  testWidgets('the league chip names the league, never the percentile, and '
      'opens Progrès', (tester) async {
    var opened = 0;
    final progressApi = _FakeProgressApi()
      ..result = ProgressFetched(
        ProgressSnapshot.fromJson(const {
          'masteries': [],
          'league': {
            'division': 'gold',
            'week_start': '2026-11-02',
            'week_end': '2026-11-09T00:00:00-05:00',
            'xp_this_week': 62,
            'xp_last_week': 40,
            'promote_at_xp': 160,
            'xp_to_promote': 98,
            'keep_at_xp': 45,
            'last_week': null,
          },
          'effort_percentile': {
            'percentile': 78,
            'grade': 3,
            'week_start': '2026-11-02',
          },
        }),
      );
    await tester.pumpWidget(
      appUnder(progressApi: progressApi, onOpenProgress: () => opened++),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ligue Or'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile-league')));
    expect(opened, 1);
  });

  testWidgets('no league chip before a backend serves one', (tester) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-league')), findsNothing);
  });

  testWidgets('the hero shows the kid\'s avatar, never the mascot', (
    tester,
  ) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-avatar')), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/asset-mascot-welcome.webp')),
      findsNothing,
    );
  });

  testWidgets('"Changer de profil" opens Qui joue ?, only when wired', (
    tester,
  ) async {
    await tester.pumpWidget(appUnder());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-switch')), findsNothing);

    var opened = 0;
    await tester.pumpWidget(appUnder(onSwitchProfile: () => opened++));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.fr.switchProfile));
    expect(opened, 1);
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
    expect(
      find.text(Strings.fr.streakShieldBalance(2).toUpperCase()),
      findsNothing,
    );
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
    Future<void> openSignOut(WidgetTester tester) async {
      // Sign-out lives in Réglages' Zone parent tab (app ADR 0051), and
      // the page scrolls, so it has to be brought into view.
      final parents = find.byKey(const ValueKey('settings-tab-parents'));
      await tester.ensureVisible(parents);
      await tester.pumpAndSettle();
      await tester.tap(parents);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.fr.settingsSignOut));
      await tester.pumpAndSettle();
      // No PIN yet: the adult check comes first (A5).
      if (find.byKey(const ValueKey('adult-check')).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), '56');
        await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
        await tester.pumpAndSettle();
      }
    }

    Future<void> tapPrimary(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();
    }

    bool forgotten(ProviderContainer container) =>
        (container.read(sessionControllerProvider.notifier)
                as _FixedSessionController)
            .forgotten;

    testWidgets('with no PIN set yet, sign-out prompts to create one first', (
      tester,
    ) async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();
      await openSignOut(tester);

      expect(find.text(Strings.fr.pinGateCreateTitle), findsOneWidget);
      expect(find.text(Strings.fr.pinGatePinLabel(6)), findsOneWidget);
      expect(find.text('0/6'), findsNWidgets(2));
      expect(forgotten(container), isFalse);
    });

    testWidgets('the PIN fields are hidden, numeric and take 6 digits only', (
      tester,
    ) async {
      final container = _buildContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();
      await openSignOut(tester);

      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.obscureText, isTrue);
      expect(field.keyboardType, TextInputType.number);
      expect(field.maxLength, 6);

      await tester.enterText(find.byType(TextField).first, '12a3-4567890');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '123456',
      );
    });

    testWidgets('a 4-digit PIN is refused when creating one', (tester) async {
      final store = _FakeSessionStore();
      final container = _buildContainer(store: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();
      await openSignOut(tester);

      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.enterText(find.byType(TextField).last, '1234');
      await tapPrimary(tester);

      expect(find.text(Strings.fr.pinGateTooShort(6)), findsOneWidget);
      expect(await store.hasGuardianPin(), isFalse);
      expect(forgotten(container), isFalse);
    });

    testWidgets(
      'a mismatched PIN confirmation shows an error and does not sign out',
      (tester) async {
        final container = _buildContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();
        await openSignOut(tester);

        await tester.enterText(find.byType(TextField).first, '123456');
        await tester.enterText(find.byType(TextField).last, '999999');
        await tapPrimary(tester);

        expect(find.text(Strings.fr.pinGateMismatch), findsOneWidget);
        expect(forgotten(container), isFalse);
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
      await openSignOut(tester);

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tapPrimary(tester);
      await _confirmErase(tester);

      expect(await store.verifyGuardianPin('123456'), isTrue);
      expect(forgotten(container), isTrue);
    });

    testWidgets(
      'with a PIN already set, the wrong PIN is rejected and does not sign out',
      (tester) async {
        final store = _FakeSessionStore()..presetPin('123456');
        final container = _buildContainer(store: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();
        await openSignOut(tester);

        expect(find.text(Strings.fr.pinGateEnterTitle), findsOneWidget);

        await tester.enterText(find.byType(TextField), '000000');
        await tapPrimary(tester);

        expect(find.text(Strings.fr.pinGateWrong), findsOneWidget);
        expect(forgotten(container), isFalse);
      },
    );

    testWidgets('the correct PIN signs the device out', (tester) async {
      final store = _FakeSessionStore()..presetPin('123456');
      final container = _buildContainer(store: store);
      addTearDown(container.dispose);
      await tester.pumpWidget(_widgetFor(container));
      await tester.pumpAndSettle();
      await openSignOut(tester);

      expect(find.text(Strings.fr.pinGatePinLabel(6)), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tapPrimary(tester);
      await _confirmErase(tester);

      expect(forgotten(container), isTrue);
    });

    group('a 4-digit PIN from before the change', () {
      testWidgets('opens once, then a new 6-digit PIN is required first', (
        tester,
      ) async {
        final store = _FakeSessionStore()..presetPin('1234');
        final container = _buildContainer(store: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();
        await openSignOut(tester);

        // Asked for the old PIN at its old length.
        expect(find.text(Strings.fr.pinGatePinLabel(4)), findsOneWidget);
        await tester.enterText(find.byType(TextField), '1234');
        await tapPrimary(tester);

        expect(find.text(Strings.fr.pinGateUpgradeTitle), findsOneWidget);
        expect(forgotten(container), isFalse);

        await tester.enterText(find.byType(TextField).first, '246813');
        await tester.enterText(find.byType(TextField).last, '246813');
        await tapPrimary(tester);
        await _confirmErase(tester);

        expect(await store.guardianPinDigits(), 6);
        expect(await store.verifyGuardianPin('246813'), isTrue);
        expect(forgotten(container), isTrue);
      });

      testWidgets('backing out of the new PIN keeps the old one working', (
        tester,
      ) async {
        final store = _FakeSessionStore()..presetPin('1234');
        final container = _buildContainer(store: store);
        addTearDown(container.dispose);
        await tester.pumpWidget(_widgetFor(container));
        await tester.pumpAndSettle();
        await openSignOut(tester);

        await tester.enterText(find.byType(TextField), '1234');
        await tapPrimary(tester);
        await tester.tap(find.text(Strings.fr.cancel));
        await tester.pumpAndSettle();

        expect(forgotten(container), isFalse);
        expect(await store.verifyGuardianPin('1234'), isTrue);

        // And the next try asks for the old PIN again, not a lock-out.
        await openSignOut(tester);
        expect(find.text(Strings.fr.pinGateEnterTitle), findsOneWidget);
        expect(find.text(Strings.fr.pinGatePinLabel(4)), findsOneWidget);
      });
    });
  });
}
