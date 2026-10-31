import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/feedback_api.dart';
import '../../data/local_db/feedback_queue.dart';
import '../pairing/pairing_controller.dart';

/// The most a message may hold, in Unicode code points, matching the
/// backend's 4,000-character limit (work order F1, security 2).
const feedbackMaxLength = 4000;

/// Code points, which is what the backend counts.
int feedbackLength(String text) => text.trim().runes.length;

/// The only context a message carries (work order, security 5): an
/// allowlist. Never a token, an answer, or a telemetry id.
class FeedbackContext {
  const FeedbackContext({
    required this.appVersion,
    required this.platform,
    required this.locale,
    required this.route,
  });

  final String appVersion;

  /// `web`, `linux`, `android`…
  final String platform;

  /// `fr` or `en`.
  final String locale;

  /// The page the message was written from.
  final String route;

  static String currentPlatform() =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  Map<String, String> toJson() => {
    'app_version': appVersion,
    'platform': platform,
    'locale': locale,
    'route': route,
  };
}

/// What happened to a message the guardian just sent.
enum FeedbackOutcome { sent, queued }

final feedbackApiProvider = Provider<FeedbackApi>(
  (ref) => FeedbackApi(dio: ref.watch(dioProvider)),
);

/// The active kid's sender, or null before anyone has paired.
final feedbackSenderProvider = Provider<FeedbackSender?>((ref) {
  final kidId = ref.watch(activeKidIdProvider);
  if (kidId == null) return null;
  return FeedbackSender(
    queue: FeedbackQueue(ref.watch(localDatabaseProvider), kidId: kidId),
    api: ref.watch(feedbackApiProvider),
    accessToken: () => ref.read(sessionControllerProvider).accessToken,
  );
});

/// Queues a message first, then tries to send everything queued (app ADR
/// 0104). Queuing first means a message survives the app closing mid-send;
/// the `client_id` makes a resend of one already stored harmless.
class FeedbackSender {
  FeedbackSender({
    required this.queue,
    required this.api,
    required this.accessToken,
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final FeedbackQueue queue;
  final FeedbackApi api;
  final String? Function() accessToken;
  final String Function() _newId;
  final DateTime Function() _clock;

  Future<void>? _flushing;

  Future<FeedbackOutcome> submit({
    required FeedbackKind kind,
    required String text,
    required FeedbackContext context,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || feedbackLength(trimmed) > feedbackMaxLength) {
      throw ArgumentError.value(text, 'text', 'empty or over the limit');
    }
    final item = QueuedFeedback(
      clientId: _newId(),
      kind: kind,
      text: trimmed,
      context: context.toJson(),
      createdAt: _clock(),
    );
    await queue.add(item);
    await flush();
    final left = await queue.pending();
    return left.any((i) => i.clientId == item.clientId)
        ? FeedbackOutcome.queued
        : FeedbackOutcome.sent;
  }

  /// Sends what's queued, oldest first, and stops at the first message that
  /// must wait. One flush at a time; a second call joins the running one.
  /// Never throws.
  Future<void> flush() => _flushing ??= _flush().whenComplete(() {
    _flushing = null;
  });

  Future<void> _flush() async {
    try {
      for (final item in await queue.pending()) {
        final token = accessToken();
        if (token == null) return;
        final result = await api.send(accessToken: token, body: item.toBody());
        if (result == FeedbackSendResult.retryLater) return;
        await queue.remove(item.clientId);
      }
    } on Object {
      // Storage trouble leaves the queue as it was, for the next try.
    }
  }
}
