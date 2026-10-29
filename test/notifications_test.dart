import 'package:design_system/design_system.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/routing/village_header.dart';
import 'package:tutolys_app/data/api/notifications_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/assignments/assignments_controller.dart';
import 'package:tutolys_app/features/notifications/notifications_panel.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';

final _now = DateTime.now();

NotificationDto n(
  String id,
  String type, {
  bool read = false,
  Duration ago = Duration.zero,
}) => NotificationDto(
  id: id,
  type: type,
  message: 'Message du serveur',
  createdAt: _now.subtract(ago),
  isRead: read,
);

class _FakeApi extends NotificationsApi {
  _FakeApi(this.inbox) : super(dio: Dio());
  NotificationInbox inbox;
  int markCalls = 0;

  @override
  Future<NotificationsResult> fetch({required String accessToken}) async =>
      NotificationsFetched(inbox);

  @override
  Future<bool> markAllRead({required String accessToken}) async {
    markCalls++;
    return true;
  }
}

class _Session extends SessionController {
  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.paired, accessToken: 'token');
}

ProviderContainer _container(_FakeApi api) => ProviderContainer(
  overrides: [
    // The bell merges in the local inbox (ADR 0097).
    localDatabaseProvider.overrideWithValue(LocalDatabase.memory()),
    notificationsApiProvider.overrideWithValue(api),
    notificationsPollingProvider.overrideWithValue(false),
    assignmentsPollingProvider.overrideWithValue(false),
    sessionControllerProvider.overrideWith(_Session.new),
  ],
);

Widget app(ProviderContainer c, Widget child) => UncontrolledProviderScope(
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
    home: Scaffold(body: child),
  ),
);

void main() {
  test('parses the inbox the backend serves', () {
    final inbox = NotificationInbox.fromJson({
      'unread_count': 1,
      'notifications': [
        {
          'id': 'a',
          'type': 'daily_quest_completed',
          'message': 'Bravo !',
          'created_at': '2026-10-25T08:00:00Z',
          'read_at': null,
          'is_read': false,
        },
      ],
    });
    expect(inbox.unreadCount, 1);
    expect(inbox.items.single.type, 'daily_quest_completed');
    expect(inbox.items.single.isRead, isFalse);
  });

  test(
    'loads, then marking read clears the badge at once and tells the server',
    () async {
      final api = _FakeApi(
        NotificationInbox(
          unreadCount: 2,
          items: [
            n('a', 'daily_quest_completed'),
            n('b', 'streak_freeze_spent'),
          ],
        ),
      );
      final c = _container(api);
      addTearDown(c.dispose);
      c.listen(notificationsControllerProvider, (_, _) {});
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.read(notificationsControllerProvider).unreadCount, 2);

      await c.read(notificationsControllerProvider.notifier).markAllRead();
      final state = c.read(notificationsControllerProvider);
      expect(state.unreadCount, 0);
      expect(state.items.every((x) => x.isRead), isTrue);
      expect(api.markCalls, 1);
    },
  );

  test('known types are worded by the app, in the reader\'s language', () {
    expect(
      notificationText(Strings.fr, n('a', 'daily_quest_completed')),
      Strings.fr.notificationDailyQuest,
    );
    expect(
      notificationText(Strings.en, n('a', 'streak_freeze_spent')),
      Strings.en.notificationStreakFreeze,
    );
    expect(
      notificationText(Strings.fr, n('a', 'streak_freeze_refunded')),
      "Tu avais joué ce jour-là : ton bouclier t'est rendu.",
    );
    expect(
      notificationText(Strings.en, n('a', 'streak_freeze_refunded')),
      'You played that day after all, so your shield is back.',
    );
    // A tutoring reminder: the server's French names the tutor and time;
    // English says the same without them (no parameters on the wire yet).
    expect(
      notificationText(Strings.fr, n('a', 'tutoring_session_soon')),
      'Message du serveur',
    );
    expect(
      notificationText(Strings.en, n('a', 'tutoring_session_soon')),
      'Your tutoring session is coming up soon.',
    );
    expect(
      notificationText(Strings.en, n('a', 'something_new')),
      'Message du serveur',
      reason: 'an unknown type falls back to the server text',
    );
  });

  test('relative times read naturally', () {
    expect(
      Strings.fr.notificationsAgo(const Duration(seconds: 20)),
      'à l’instant',
    );
    expect(
      Strings.fr.notificationsAgo(const Duration(minutes: 5)),
      'il y a 5 min',
    );
    expect(Strings.fr.notificationsAgo(const Duration(hours: 3)), 'il y a 3 h');
    expect(
      Strings.fr.notificationsAgo(const Duration(days: 1, hours: 2)),
      'hier',
    );
    expect(Strings.en.notificationsAgo(const Duration(days: 4)), '4 days ago');
  });

  testWidgets('the panel lists them, new ones marked, then reads them all', (
    tester,
  ) async {
    final api = _FakeApi(
      NotificationInbox(
        unreadCount: 1,
        items: [
          n('a', 'daily_quest_completed', ago: const Duration(hours: 2)),
          n(
            'b',
            'streak_freeze_spent',
            read: true,
            ago: const Duration(days: 2),
          ),
        ],
      ),
    );
    final c = _container(api);
    addTearDown(c.dispose);
    c.listen(notificationsControllerProvider, (_, _) {});
    // Load the inbox before opening, as the bell does in the app.
    await c.read(notificationsControllerProvider.notifier).refresh();
    expect(c.read(notificationsControllerProvider).unreadCount, 1);

    await tester.pumpWidget(app(c, const NotificationsPanel()));
    // Opening reads all: locally first, then the server (ADR 0097).
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text(Strings.fr.notificationDailyQuest), findsOneWidget);
    expect(find.text('il y a 2 h'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-unread')),
      findsOneWidget,
      reason: 'the unread dot stays for this opening',
    );
    expect(api.markCalls, 1);
    expect(c.read(notificationsControllerProvider).unreadCount, 0);
  });

  testWidgets('an empty inbox says so', (tester) async {
    final c = _container(
      _FakeApi(const NotificationInbox(unreadCount: 0, items: [])),
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c, const NotificationsPanel()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text(Strings.fr.notificationsEmpty), findsOneWidget);
  });

  group('the header bell', () {
    Widget header({int unread = 0, VoidCallback? onTap}) => MaterialApp(
      theme: TutolysTheme.village(),
      home: Scaffold(
        body: VillageHeader(
          name: 'Yelhan',
          subtitle: '',
          stats: const [],
          onNotifications: onTap ?? () {},
          unreadNotifications: unread,
          notificationsLabel: 'Notifications',
        ),
      ),
    );

    testWidgets('shows the unread count as a badge', (tester) async {
      await tester.pumpWidget(header(unread: 2));
      expect(find.byKey(const ValueKey('header-badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('no badge when nothing is unread', (tester) async {
      await tester.pumpWidget(header());
      expect(find.byKey(const ValueKey('header-badge')), findsNothing);
    });

    testWidgets('caps a big count at 9+', (tester) async {
      await tester.pumpWidget(header(unread: 14));
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('opens the inbox', (tester) async {
      var opened = 0;
      await tester.pumpWidget(header(onTap: () => opened++));
      await tester.tap(find.byKey(const ValueKey('header-notifications')));
      expect(opened, 1);
    });
  });
}
