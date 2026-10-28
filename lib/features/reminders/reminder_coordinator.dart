import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diag_log.dart' show recordCaught;
import '../../data/local_db/app_settings.dart';
import '../../data/local_db/database.dart';
import '../../data/local_db/streak_local.dart';
import '../pairing/pairing_controller.dart';
import '../progress/progress_cache.dart';
import 'reminder_policy.dart';
import 'reminder_scheduler.dart';

/// Keeps the device's reminders in step with every paired kid (ADR 0053).
///
/// [reschedule] is called on launch, on return to the app, after every
/// finished lesson, when reminder settings change and when kids are added
/// or removed. Each call replaces the whole schedule, so nothing stale
/// survives a change. Calls are serialised; one that fails is recorded on
/// the device and changes nothing.
class ReminderCoordinator {
  ReminderCoordinator({
    required this.db,
    required Future<ReminderSink> Function() sink,
    DateTime Function()? clock,
  }) : _sink = sink, // ignore: prefer_initializing_formals
       _now = clock ?? DateTime.now;

  final LocalDatabase db;
  final Future<ReminderSink> Function() _sink;
  final DateTime Function() _now;

  Future<void> _last = Future.value();
  Timer? _midnight;

  /// [active] is the playing kid's settings as the app holds them, which may
  /// be ahead of what's on disk while a write is still landing.
  Future<void> reschedule(SessionState session, {AppSettings? active}) {
    final run = _last.then((_) => _run(session, active));
    _last = run.catchError(
      (Object e, StackTrace s) => recordCaught('reminders', e, s),
    );
    return _last;
  }

  Future<void> _run(SessionState session, AppSettings? active) async {
    final sink = await _sink();
    if (sink is NoReminderSink) return;
    final now = _now();
    final plan = session.status == SessionStatus.paired
        ? planReminders(
            kids: [
              for (final kid in session.kids)
                await inputFor(
                  kid.id,
                  settings: kid.id == session.kid?.id ? active : null,
                ),
            ],
            now: now,
            classTablet: session.isClassroom,
          )
        : const <PlannedReminder>[];
    await sink.replaceAll(plan);
    // The plan covers two days; plan again after midnight in case the app
    // is simply left open (the Linux case).
    _midnight?.cancel();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 1);
    _midnight = Timer(tomorrow.difference(now), () {
      reschedule(session).ignore();
    });
  }

  /// One kid's reminder facts, all from this device.
  Future<KidReminderInput> inputFor(String kidId, {AppSettings? settings}) async {
    final s = settings ?? await AppSettingsStore(db, kidId: kidId).read();
    final streak = StreakLocal(db, kidId: kidId, clock: _now);
    final cached = await ProgressCache(db, kidId: kidId).read();
    final balance =
        cached?.streakFreeze?.balance ?? cached?.freezesAvailable;
    final local = await streak.currentStreak();
    final server = cached?.currentStreakDays;
    return KidReminderInput(
      kidId: kidId,
      enabled: s.dailyReminders,
      flameEnabled: s.flameReminders,
      minutes: s.reminderMinutes,
      english: s.english,
      playedDays: await streak.playedDays(),
      enabledOn: s.remindersOnSince,
      // The larger, as everywhere a streak is shown (ADR 0032).
      streak: server != null && server > local ? server : local,
      shieldReady: balance == null ? null : balance > 0,
    );
  }

  void dispose() => _midnight?.cancel();
}

/// The platform's sink, made once. A plugin that can't start (a test, an
/// unsupported desktop) means no reminders, never a crash.
final reminderSinkProvider = FutureProvider<ReminderSink>((ref) async {
  try {
    return await createReminderSink(
      onTap: () {
        // Several kids share a device: a reminder names nobody, so tapping
        // it asks who's playing.
        final session = ref.read(sessionControllerProvider);
        if (session.choosesWhoPlays) {
          ref.read(sessionControllerProvider.notifier).chooseProfile();
        }
      },
    );
  } on Object catch (e, s) {
    recordCaught('reminder_sink', e, s);
    return NoReminderSink();
  }
});

final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final coordinator = ReminderCoordinator(
    db: ref.watch(localDatabaseProvider),
    sink: () => ref.read(reminderSinkProvider.future),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
