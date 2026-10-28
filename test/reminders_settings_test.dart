import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/pairing_api.dart' show Classroom;
import 'package:tutolys_app/core/routing/page_tab.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/data/local_db/streak_local.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/reminders/reminder_coordinator.dart';
import 'package:tutolys_app/features/reminders/reminder_policy.dart';
import 'package:tutolys_app/features/reminders/reminder_scheduler.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';
import 'package:tutolys_app/features/settings/settings_screen.dart';

const _lea = PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1);
const _noah = PairedKid(id: 'noah', displayName: 'Noah', gradeLevel: 3);

class _Store extends SessionStore {
  String? pin = '123456';

  @override
  Future<bool> hasGuardianPin() async => pin != null;

  @override
  Future<int?> guardianPinDigits() async => pin?.length;

  @override
  Future<bool> verifyGuardianPin(String p) async => p == pin;
}

class _Sink extends ReminderSink {
  _Sink({this.allowed = true});
  final bool allowed;
  List<PlannedReminder>? last;
  int asked = 0;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async => last = plan;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allowed;
  }
}

class _Session extends SessionController {
  _Session(this.value);
  final SessionState value;

  @override
  SessionState build() => value;
}

SessionState _paired({List<PairedKid> kids = const [_lea], Classroom? classroom}) =>
    SessionState(
      status: SessionStatus.paired,
      kid: kids.first,
      kids: kids,
      accessToken: 't',
      classroom: classroom,
    );

void main() {
  group('the coordinator', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    test('plans from every paired kid\'s own settings and play', () async {
      final now = DateTime(2026, 10, 28, 9);
      await AppSettingsStore(db, kidId: 'lea').write(
        AppSettings(dailyReminders: true, remindersOnSince: DateTime(2026, 10, 28)),
      );
      await AppSettingsStore(db, kidId: 'noah').write(
        const AppSettings(dailyReminders: true, reminderMinutes: 9 * 60 + 30),
      );
      await StreakLocal(db, kidId: 'noah', clock: () => now).recordPlayedToday();

      final sink = _Sink();
      final c = ReminderCoordinator(db: db, sink: () async => sink, clock: () => now);
      addTearDown(c.dispose);
      await c.reschedule(_paired(kids: const [_lea, _noah]));

      // Noah played today: only his tomorrow, at 09:30. Léa: today and
      // tomorrow at 17:00.
      expect(sink.last!.map((r) => (r.at, r.kidIds.join(','))), [
        (DateTime(2026, 10, 28, 17), 'lea'),
        (DateTime(2026, 10, 29, 9, 30), 'noah'),
        (DateTime(2026, 10, 29, 17), 'lea'),
      ]);
    });

    test('the playing kid\'s in-memory settings win over the disk', () async {
      final now = DateTime(2026, 10, 28, 9);
      final sink = _Sink();
      final c = ReminderCoordinator(db: db, sink: () async => sink, clock: () => now);
      addTearDown(c.dispose);
      await c.reschedule(
        _paired(),
        active: AppSettings(dailyReminders: true, remindersOnSince: now),
      );
      expect(sink.last, hasLength(2));
    });

    test('unpaired or a class tablet: everything is cancelled', () async {
      await AppSettingsStore(db, kidId: 'lea')
          .write(const AppSettings(dailyReminders: true));
      final sink = _Sink();
      final c = ReminderCoordinator(db: db, sink: () async => sink);
      addTearDown(c.dispose);
      await c.reschedule(_paired(classroom: const Classroom(classId: 'c', className: '1re A', organizationName: 'École')));
      expect(sink.last, isEmpty);
      await c.reschedule(const SessionState.unpaired());
      expect(sink.last, isEmpty);
    });
  });

  group('settings', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    test('off by default; the old always-on flag is not a guardian\'s choice',
        () async {
      await db.into(db.appStateTable).insert(
            AppStateTableCompanion.insert(
              kidId: 'lea',
              key: 'settings.daily_reminders',
              value: 'true',
              updatedAt: DateTime(2026, 10, 1),
            ),
          );
      final s = await AppSettingsStore(db, kidId: 'lea').read();
      expect(s.dailyReminders, isFalse);
      expect(s.reminderMinutes, defaultReminderMinutes);
    });

    test('on, the time and the day turned on round-trip', () async {
      final store = AppSettingsStore(db, kidId: 'lea');
      await store.write(AppSettings(
        dailyReminders: true,
        reminderMinutes: 9 * 60 + 30,
        remindersOnSince: DateTime(2026, 10, 28, 15, 4),
      ));
      final s = await store.read();
      expect(s.dailyReminders, isTrue);
      expect(s.reminderMinutes, 9 * 60 + 30);
      expect(s.remindersOnSince, DateTime(2026, 10, 28));
    });
  });

  group('Réglages · Notifications', () {
    Future<(ProviderContainer, _Sink)> pump(
      WidgetTester tester, {
      ReminderSupport support = ReminderSupport.scheduled,
      SessionState? session,
      AppSettings stored = const AppSettings(),
      bool allowed = true,
    }) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      await AppSettingsStore(db, kidId: 'lea').write(stored);
      final sink = _Sink(allowed: allowed);
      final c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          sessionStoreProvider.overrideWithValue(_Store()),
          sessionControllerProvider.overrideWith(() => _Session(session ?? _paired())),
          reminderSupportProvider.overrideWithValue(support),
          reminderSinkProvider.overrideWith((ref) async => sink),
        ],
      );
      addTearDown(c.dispose);
      await c.read(pageTabProvider(TabbedPage.settings).notifier)
          .select(SettingsTab.notifications.name);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(900, 1400), disableAnimations: true),
            child: MaterialApp(
              theme: TutolysTheme.learner(),
              locale: const Locale('fr', 'CA'),
              supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: SettingsScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (c, sink);
    }

    VillageSwitch reminderSwitch(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('settings-reminders')),
        matching: find.byType(VillageSwitch),
      ),
    );

    testWidgets('turning on asks the guardian PIN, then the OS', (tester) async {
      final (c, sink) = await pump(tester);
      expect(reminderSwitch(tester).value, isFalse);
      expect(find.byKey(const ValueKey('settings-reminder-time')), findsNothing);

      reminderSwitch(tester).onChanged!(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-gate-primary')), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();

      expect(sink.asked, 1);
      final s = c.read(settingsControllerProvider);
      expect(s.dailyReminders, isTrue);
      expect(s.remindersOnSince, isNotNull);
      expect(find.byKey(const ValueKey('settings-reminder-time')), findsOneWidget);
    });

    testWidgets('a wrong PIN, or no OS permission, leaves them off', (
      tester,
    ) async {
      final (c, sink) = await pump(tester, allowed: false);
      reminderSwitch(tester).onChanged!(true);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();
      expect(sink.asked, 1);
      expect(c.read(settingsControllerProvider).dailyReminders, isFalse);
      expect(find.text(Strings.fr.settingsRemindersBlocked), findsOneWidget);
      // Let the toast go before the tree is torn down.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    });

    testWidgets('turning off needs no PIN', (tester) async {
      final (c, _) = await pump(
        tester,
        stored: const AppSettings(dailyReminders: true),
      );
      reminderSwitch(tester).onChanged!(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-gate-primary')), findsNothing);
      expect(c.read(settingsControllerProvider).dailyReminders, isFalse);
    });

    testWidgets('the time is chosen behind the PIN, from 08:00 to 19:00', (
      tester,
    ) async {
      final (c, _) = await pump(
        tester,
        stored: const AppSettings(dailyReminders: true),
      );
      expect(find.text(Strings.fr.reminderTimeLabel(17 * 60)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settings-reminder-time')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.byKey(const ValueKey('pin-gate-primary')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reminder-slot-480')), findsOneWidget);
      expect(find.byKey(const ValueKey('reminder-slot-450')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reminder-slot-570')));
      await tester.pumpAndSettle();
      expect(c.read(settingsControllerProvider).reminderMinutes, 570);
    });

    testWidgets('web: off, and says where reminders come from', (tester) async {
      await pump(tester, support: ReminderSupport.none);
      expect(reminderSwitch(tester).onChanged, isNull);
      expect(find.text(Strings.fr.settingsRemindersWebNote), findsOneWidget);
    });

    testWidgets('Linux: only while TutoLys is open, said plainly', (
      tester,
    ) async {
      await pump(tester, support: ReminderSupport.whileRunning);
      expect(reminderSwitch(tester).onChanged, isNotNull);
      expect(find.text(Strings.fr.settingsRemindersWhileRunning), findsOneWidget);
    });

    testWidgets('a class tablet: never', (tester) async {
      await pump(
        tester,
        session: _paired(classroom: const Classroom(classId: 'c', className: '1re A', organizationName: 'École')),
        stored: const AppSettings(dailyReminders: true),
      );
      expect(reminderSwitch(tester).onChanged, isNull);
      expect(reminderSwitch(tester).value, isFalse);
      expect(find.text(Strings.fr.settingsRemindersClassNote), findsOneWidget);
    });

    testWidgets('"Nouvelles quêtes" is left as it was', (tester) async {
      await pump(tester);
      expect(find.text(Strings.fr.settingsQuestNotifications), findsOneWidget);
    });
  });
}
