import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/notifications_api.dart';
import '../../data/local_db/local_inbox.dart';
import 'local_notifications.dart';
import '../pairing/pairing_controller.dart';
import '../../core/net/recovery.dart';
import '../../core/time/quebec_day.dart';

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => NotificationsApi(dio: ref.watch(dioProvider)),
);

/// How often the bell asks for news. The backend fires at most a couple of
/// notifications a day, from scheduled jobs (ADR 0024), and there is no
/// push: polling every few minutes is the whole delivery mechanism.
const notificationsPollEvery = Duration(minutes: 3);

/// Whether the bell polls. On in the app; tests that keep a provider
/// container alive past their widgets turn it off, as they do the outbox
/// flusher's timer, so no periodic timer outlives the test.
final notificationsPollingProvider = Provider<bool>((ref) => true);

class NotificationsState {
  const NotificationsState({this.unreadCount = 0, this.items = const []});

  final int unreadCount;
  final List<NotificationDto> items;
}

/// The kid's inbox behind the header bell: what the server sent, merged
/// with what the app wrote itself on this device (ADR 0097).
///
/// Works with no connection: the local inbox is always read, and the last
/// server inbox is kept while the backend is unreachable. The same fact
/// from both sources shows once. Opening the bell reads everything; offline
/// that read is queued and sent once the server is back.
class NotificationsController extends Notifier<NotificationsState> {
  /// The last server inbox, kept while the backend is unreachable.
  NotificationInbox? _server;

  @override
  NotificationsState build() {
    // Rebuilds when the kid changes, so one kid's inbox never shows for
    // another.
    ref.watch(activeKidIdProvider);
    _server = null;
    if (ref.watch(notificationsPollingProvider)) {
      final timer = Timer.periodic(notificationsPollEvery, (_) => refresh());
      ref.onDispose(timer.cancel);
    }
    Future.microtask(refresh);
    return const NotificationsState();
  }

  Future<void> refresh() async {
    final inbox = ref.read(localInboxProvider);
    final session = ref.read(sessionControllerProvider);
    final token = session.accessToken;
    final recovery = ref.read(recoveryProvider);
    if (token == null) {
      if (session.status == SessionStatus.paired) recovery.reportFailure();
    } else {
      final api = ref.read(notificationsApiProvider);
      // A read made offline goes first, so the inbox fetched next already
      // reflects it.
      if (await inbox.readPending()) {
        if (await api.markAllRead(accessToken: token)) {
          await inbox.clearReadPending();
        }
      }
      final result = await api.fetch(accessToken: token);
      if (!ref.mounted) return;
      if (result case NotificationsFetched(:final inbox)) {
        recovery.reportSuccess();
        _server = inbox;
      } else {
        recovery.reportFailure();
      }
    }
    final local = await inbox.list();
    final pending = await inbox.readPending();
    if (!ref.mounted) return;
    final merged = mergeInboxes(
      local: local,
      server: _server,
      readPending: pending,
    );
    // The server already says these facts are read: so do they here.
    await inbox.markRead(merged.readOnServer);
    if (!ref.mounted) return;
    state = merged.state;
  }

  /// Opening the inbox reads everything in it. Applied at once, so the
  /// badge clears the moment the kid looks. The local inbox remembers the
  /// read until the server has it, so a read made offline isn't lost.
  Future<void> markAllRead() async {
    if (state.unreadCount == 0 && state.items.every((n) => n.isRead)) return;
    state = NotificationsState(
      unreadCount: 0,
      items: [for (final n in state.items) n.read()],
    );
    final inbox = ref.read(localInboxProvider);
    await inbox.markAllRead();
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    if (await ref
        .read(notificationsApiProvider)
        .markAllRead(accessToken: token)) {
      await inbox.clearReadPending();
    }
  }
}

/// The fact keys a served notification may stand for, in the backend's
/// format (`daily_quest:<day>`). The served `dedupe_key` is the exact one;
/// for a backend that doesn't serve it, a daily quest's day comes from
/// `created_at`, as Québec's day (K8) and as a UTC day.
Set<String> serverFactKeys(NotificationDto n) {
  if (n.dedupeKey case final key?) return {key};
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return switch (n.type) {
    'daily_quest_completed' => {
      'daily_quest:${day(quebecNow(n.createdAt))}',
      'daily_quest:${day(n.createdAt.toUtc())}',
    },
    _ => const {},
  };
}

/// [mergeInboxes]'s answer.
typedef MergedInbox = ({NotificationsState state, Set<String> readOnServer});

/// Server items, plus every local one the server didn't also send. A fact
/// from both shows once, as the server's, read if either side read it.
///
/// [readPending]: the kid read everything while the server couldn't hear
/// it, so what the server last said was unread shows read until it does.
MergedInbox mergeInboxes({
  required List<LocalNotification> local,
  NotificationInbox? server,
  bool readPending = false,
}) {
  final byKey = {for (final l in local) l.factKey: l};
  final covered = <String>{};
  final readOnServer = <String>{};
  final items = <NotificationDto>[];
  var hiddenUnread = 0;
  if (server != null) {
    for (final n in server.items) {
      var read = n.isRead || readPending;
      for (final key in serverFactKeys(n)) {
        final twin = byKey[key];
        if (twin == null) continue;
        covered.add(key);
        if (twin.isRead) read = true;
        if (n.isRead && !twin.isRead) readOnServer.add(key);
      }
      items.add(read == n.isRead ? n : n.read());
    }
    // Unread beyond the served page (the backend caps the list).
    final shownUnread = server.items.where((n) => !n.isRead).length;
    hiddenUnread = readPending
        ? 0
        : (server.unreadCount - shownUnread).clamp(0, 1 << 30);
  }
  for (final l in local) {
    if (covered.contains(l.factKey)) continue;
    items.add(
      NotificationDto(
        id: 'local:${l.factKey}',
        type: l.type,
        message: '',
        createdAt: l.createdAt,
        isRead: l.isRead,
        params: l.params,
        local: true,
      ),
    );
  }
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return (
    state: NotificationsState(
      unreadCount: items.where((n) => !n.isRead).length + hiddenUnread,
      items: items,
    ),
    readOnServer: readOnServer,
  );
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );
