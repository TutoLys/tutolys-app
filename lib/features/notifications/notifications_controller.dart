import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/notifications_api.dart';
import '../pairing/pairing_controller.dart';

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

/// The kid's inbox behind the header bell.
///
/// Read once on build and then on a timer; it never invents anything while
/// the backend is unreachable, it keeps what it last had.
class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    // Rebuilds when the kid changes, so one kid's inbox never shows for
    // another.
    ref.watch(activeKidIdProvider);
    if (ref.watch(notificationsPollingProvider)) {
      final timer = Timer.periodic(notificationsPollEvery, (_) => refresh());
      ref.onDispose(timer.cancel);
    }
    Future.microtask(refresh);
    return const NotificationsState();
  }

  Future<void> refresh() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    final result = await ref
        .read(notificationsApiProvider)
        .fetch(accessToken: token);
    if (!ref.mounted) return;
    if (result case NotificationsFetched(:final inbox)) {
      state = NotificationsState(
        unreadCount: inbox.unreadCount,
        items: inbox.items,
      );
    }
  }

  /// Opening the inbox reads everything in it. Applied at once, so the
  /// badge clears the moment the kid looks; if the server misses it, the
  /// next poll brings the true count back rather than hiding it.
  Future<void> markAllRead() async {
    if (state.unreadCount == 0 && state.items.every((n) => n.isRead)) return;
    state = NotificationsState(
      unreadCount: 0,
      items: [for (final n in state.items) n.read()],
    );
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    await ref.read(notificationsApiProvider).markAllRead(accessToken: token);
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );
