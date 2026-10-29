import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/notifications_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/local_inbox.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/assignments/assignments_controller.dart';
import 'package:tutolys_app/features/notifications/local_facts.dart';
import 'package:tutolys_app/features/notifications/local_notifications.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/notifications/notifications_panel.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';

/// A server that can drop off the network.
class _Server extends NotificationsApi {
  _Server() : super(dio: Dio());
  bool offline = false;
  NotificationInbox inbox = const NotificationInbox(unreadCount: 0, items: []);
  int markCalls = 0;

  @override
  Future<NotificationsResult> fetch({required String accessToken}) async =>
      offline ? const NotificationsUnavailable() : NotificationsFetched(inbox);

  @override
  Future<bool> markAllRead({required String accessToken}) async {
    if (offline) return false;
    markCalls++;
    inbox = NotificationInbox(
      unreadCount: 0,
      items: [for (final n in inbox.items) n.read()],
    );
    return true;
  }
}

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    accessToken: 'token',
    kid: PairedKid(id: 'lea', displayName: 'Léa', gradeLevel: 1),
  );
}

/// The offline inbox (ADR 0097).
void main() {
  group('the facts each trigger writes', () {
    test('quests: the daily challenge uses the backend\'s own key', () {
      final facts = notificationFacts(
        day: '2026-10-29',
        newQuests: ['challenge', 'exercises', 'minutes'],
        questTargets: {'exercises': 5, 'minutes': 10},
      );
      expect(facts.map((f) => f.factKey), [
        'daily_quest:2026-10-29',
        'quest:2026-10-29:exercises',
        'quest:2026-10-29:minutes',
      ]);
      expect(facts.first.type, 'daily_quest_completed');
      expect(facts[1].params, {'quest': 'exercises', 'target': 5});
    });

    test('achievements, and the Série rewards at 3 and 7 days', () {
      final facts = notificationFacts(
        day: '2026-10-29',
        newUnlocks: ['explorer', 'streak3', 'streak7'],
      );
      expect(facts.map((f) => (f.factKey, f.type)), [
        ('achievement:explorer', 'achievement_earned'),
        ('achievement:streak3', 'streak_milestone'),
        ('achievement:streak7', 'streak_milestone'),
      ]);
      expect(facts[1].params['days'], 3);
      expect(facts[2].params['days'], 7);
    });

    test('a level, keyed by grade', () {
      final facts = notificationFacts(day: 'd', levelReached: 4, grade: 1);
      expect(facts.single.factKey, 'level:g1:4');
      expect(facts.single.type, 'level_reached');
    });
  });

  group('writing them', () {
    late LocalDatabase db;
    setUp(() => db = LocalDatabase.memory());
    tearDown(() => db.close());

    test('each fact lands once, however often the board re-runs', () async {
      final inbox = LocalInbox(db, kidId: 'lea');
      for (var i = 0; i < 3; i++) {
        await writeLocalNotifications(
          inbox,
          day: '2026-10-29',
          newQuests: {'challenge'},
          newUnlocks: {'streak3'},
        );
      }
      expect(await inbox.list(), hasLength(2));
    });

    test(
      'a level is announced only when it rises past the last seen',
      () async {
        final inbox = LocalInbox(db, kidId: 'lea');
        Future<int> at(int level) => writeLocalNotifications(
          inbox,
          day: 'd',
          newQuests: const {},
          newUnlocks: const {},
          level: level,
          grade: 1,
        );
        expect(await at(7), 0, reason: 'first look: remembered, not announced');
        expect(await at(7), 0);
        expect(await at(8), 1);
        expect((await inbox.list()).single.factKey, 'level:g1:8');
      },
    );

    test('siblings never see each other\'s notifications', () async {
      final lea = LocalInbox(db, kidId: 'lea');
      final noah = LocalInbox(db, kidId: 'noah');
      await lea.add('achievement:streak3', 'streak_milestone');
      expect(await lea.list(), hasLength(1));
      expect(await noah.list(), isEmpty);

      await noah.markAllRead();
      expect((await lea.list()).single.isRead, isFalse);
      expect(await lea.readPending(), isFalse);
      expect(await noah.readPending(), isTrue);
    });

    test('works with no network at all: written and listed locally', () async {
      final inbox = LocalInbox(db, kidId: 'lea');
      await inbox.add('quest:d:exercises', 'quest_completed');
      final merged = mergeInboxes(local: await inbox.list());
      expect(merged.state.unreadCount, 1);
      expect(merged.state.items.single.local, isTrue);
    });
  });

  group('merging with the server', () {
    final day = DateTime(2026, 10, 29, 15);
    NotificationDto served(String id, String type, {bool read = false}) =>
        NotificationDto(
          id: id,
          type: type,
          message: 'm',
          createdAt: day,
          isRead: read,
        );
    LocalNotification local(String key, String type, {bool read = false}) =>
        LocalNotification(
          factKey: key,
          type: type,
          params: const {},
          createdAt: day,
          isRead: read,
        );

    test('the same fact from both sources shows once, as the server\'s', () {
      final merged = mergeInboxes(
        local: [
          local('daily_quest:2026-10-29', 'daily_quest_completed'),
          local('achievement:streak3', 'streak_milestone'),
        ],
        server: NotificationInbox(
          unreadCount: 2,
          items: [
            served('s1', 'daily_quest_completed'),
            served('s2', 'streak_freeze_spent'),
          ],
        ),
      );
      final ids = merged.state.items.map((n) => n.id).toList();
      expect(ids, containsAll(['s1', 's2', 'local:achievement:streak3']));
      expect(ids, hasLength(3));
      expect(merged.state.unreadCount, 3);
    });

    test('server-only types stay the server\'s', () {
      final merged = mergeInboxes(
        local: const [],
        server: NotificationInbox(
          unreadCount: 1,
          items: [served('s2', 'streak_freeze_spent')],
        ),
      );
      expect(merged.state.items.single.local, isFalse);
    });

    test('read on either side is read; the server\'s read reaches the local '
        'twin', () {
      final a = mergeInboxes(
        local: [
          local('daily_quest:2026-10-29', 'daily_quest_completed', read: true),
        ],
        server: NotificationInbox(
          unreadCount: 1,
          items: [served('s1', 'daily_quest_completed')],
        ),
      );
      expect(a.state.unreadCount, 0);

      final b = mergeInboxes(
        local: [local('daily_quest:2026-10-29', 'daily_quest_completed')],
        server: NotificationInbox(
          unreadCount: 0,
          items: [served('s1', 'daily_quest_completed', read: true)],
        ),
      );
      expect(b.readOnServer, {'daily_quest:2026-10-29'});
    });
  });

  group('the offline read queue', () {
    late LocalDatabase db;
    late _Server server;
    late ProviderContainer c;

    setUp(() {
      db = LocalDatabase.memory();
      server = _Server();
      c = ProviderContainer(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          notificationsApiProvider.overrideWithValue(server),
          notificationsPollingProvider.overrideWithValue(false),
          assignmentsPollingProvider.overrideWithValue(false),
          sessionControllerProvider.overrideWith(_Session.new),
          sessionStoreProvider.overrideWithValue(SessionStore()),
        ],
      );
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a read made offline is kept, then sent once back online, and '
        'nothing is duplicated', () async {
      server.inbox = NotificationInbox(
        unreadCount: 1,
        items: [
          NotificationDto(
            id: 's1',
            type: 'daily_quest_completed',
            message: 'm',
            createdAt: DateTime.now(),
            isRead: false,
          ),
        ],
      );
      c.listen(notificationsControllerProvider, (_, _) {});
      await settle();
      final notifier = c.read(notificationsControllerProvider.notifier);

      // Offline: the board writes the same daily quest, and a reward.
      server.offline = true;
      final inbox = c.read(localInboxProvider);
      await writeLocalNotifications(
        inbox,
        day: isoDayOf(DateTime.now()),
        newQuests: {'challenge'},
        newUnlocks: {'streak3'},
      );
      await notifier.refresh();
      var state = c.read(notificationsControllerProvider);
      expect(state.items, hasLength(2), reason: 'daily quest once, + reward');
      expect(state.unreadCount, 2);

      await notifier.markAllRead();
      await notifier.refresh();
      state = c.read(notificationsControllerProvider);
      expect(state.unreadCount, 0, reason: 'offline, the read holds');
      expect(await inbox.readPending(), isTrue);
      expect(server.markCalls, 0);

      // Back online: the queued read goes first, then nothing is doubled.
      server.offline = false;
      await notifier.refresh();
      state = c.read(notificationsControllerProvider);
      expect(server.markCalls, 1);
      expect(await inbox.readPending(), isFalse);
      expect(state.items, hasLength(2));
      expect(state.unreadCount, 0);
    });
  });

  test('every new type is worded in both languages', () {
    for (final t in [Strings.fr, Strings.en]) {
      for (final n in [
        NotificationDto(
          id: 'a',
          type: 'quest_completed',
          message: '',
          createdAt: DateTime(2026),
          isRead: false,
          params: const {'quest': 'exercises', 'target': 5},
        ),
        NotificationDto(
          id: 'b',
          type: 'achievement_earned',
          message: '',
          createdAt: DateTime(2026),
          isRead: false,
          params: const {'achievement': 'explorer'},
        ),
        NotificationDto(
          id: 'c',
          type: 'streak_milestone',
          message: '',
          createdAt: DateTime(2026),
          isRead: false,
          params: const {'days': 7},
        ),
        NotificationDto(
          id: 'd',
          type: 'level_reached',
          message: '',
          createdAt: DateTime(2026),
          isRead: false,
          params: const {'level': 3},
        ),
      ]) {
        expect(notificationText(t, n), isNotEmpty);
      }
    }
  });
}

String isoDayOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
