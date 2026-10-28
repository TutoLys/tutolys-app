import 'package:flutter/foundation.dart';

/// Learning reminders: what to schedule, decided without any plugin or clock
/// of its own, so every rule is a plain test (app ADR 0053).
///
/// Hafid's go on the plan (2026-10-28,
/// `docs/plan-2026-10-28-pill-tabs-and-reminders.md` part B):
/// - local scheduled notifications only, nothing leaves the device;
/// - at most one reminder per kid per day, only on a day not yet played;
/// - "Ma flamme" (Hafid, 2026-10-28): an evening reminder when the streak
///   is at risk and no shield is ready, which wins over the daily one;
/// - only between 08:00 and 19:30;
/// - after 3 days reminded without play, none until the kid plays again;
/// - several kids due within 30 minutes share one reminder with no name;
/// - never on a class tablet.

/// The earliest and latest a reminder may fire, in minutes after midnight.
const reminderWindowStart = 8 * 60;
const reminderWindowEnd = 19 * 60 + 30;

/// The times a guardian can choose: every half hour from 08:00 to 19:00.
final reminderSlots = List<int>.unmodifiable([
  for (var m = reminderWindowStart; m <= 19 * 60; m += 30) m,
]);

/// A new reminder's time until the guardian picks one: after school.
const defaultReminderMinutes = 17 * 60;

/// "Ma flamme", the evening reminder when the streak is at risk: late
/// enough to leave the day for playing, inside the window.
const flameReminderMinutes = 18 * 60 + 30;

/// Reminders stop after this many days in a row reminded without play.
const reminderBackOffDays = 3;

/// Kids due within this long of each other get one shared reminder.
const reminderMergeWindow = Duration(minutes: 30);

/// How far ahead anything is scheduled. Rescheduled on every app open and
/// every finished lesson, so nothing stale outlives a change.
const reminderHorizonDays = 2;

/// What one kid's reminders depend on.
@immutable
class KidReminderInput {
  const KidReminderInput({
    required this.kidId,
    required this.enabled,
    this.flameEnabled = false,
    required this.minutes,
    required this.english,
    required this.playedDays,
    this.enabledOn,
    this.streak,
    this.shieldReady,
  });

  final String kidId;

  /// "Rappels quotidiens".
  final bool enabled;

  /// "Ma flamme": the evening reminder when the streak is at risk.
  final bool flameEnabled;

  /// The chosen time, in minutes after midnight.
  final int minutes;

  /// The kid's app language: their reminder is worded in it.
  final bool english;

  /// Local calendar days with a finished lesson (`StreakLocal`).
  final Set<DateTime> playedDays;

  /// The day reminders were turned on: the back-off counts from here for a
  /// kid who hasn't played since.
  final DateTime? enabledOn;

  /// The streak as this device knows it.
  final int? streak;

  /// Whether a streak shield is ready. Null when unknown.
  final bool? shieldReady;
}

enum ReminderKind {
  /// "Le renard a préparé une nouvelle leçon. On joue ?"
  learn,

  /// "Ma flamme": the streak is at risk and no shield would save it.
  flame,

  /// Several kids at once, named nowhere: "Qui veut jouer ?"
  several,
}

@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.kind,
    required this.english,
    required this.kidIds,
  });

  final DateTime at;
  final ReminderKind kind;
  final bool english;
  final List<String> kidIds;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.at == at &&
      other.kind == kind &&
      other.english == english &&
      listEquals(other.kidIds, kidIds);

  @override
  int get hashCode => Object.hash(at, kind, english, Object.hashAll(kidIds));

  @override
  String toString() => 'PlannedReminder($at, $kind, en=$english, $kidIds)';
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Every reminder to schedule from [now] over the next [days] days, in time
/// order. Empty on a class tablet.
List<PlannedReminder> planReminders({
  required List<KidReminderInput> kids,
  required DateTime now,
  bool classTablet = false,
  int days = reminderHorizonDays,
}) {
  if (classTablet) return const [];
  final today = _day(now);
  final single = <PlannedReminder>[];

  for (final kid in kids) {
    if (!kid.enabled && !kid.flameEnabled) continue;
    final minutes = kid.minutes.clamp(reminderWindowStart, reminderWindowEnd);
    final last = _lastActivity(kid);
    final playedToday = kid.playedDays.contains(today);
    for (var d = 0; d < days; d++) {
      final day = DateTime(today.year, today.month, today.day + d);
      // Only a day not played yet. Tomorrow is unknown, and rescheduling
      // after the next lesson takes it back if it gets played.
      if (kid.playedDays.contains(day)) continue;
      if (last != null && _daysBetween(last, day) > reminderBackOffDays) {
        continue;
      }
      // The streak is at risk on a day not played: today, or tomorrow when
      // today is played (otherwise it has already broken by then). Only
      // when no shield is ready: a ready one already protects it.
      final atRisk =
          (d == 0 || (d == 1 && playedToday)) &&
          (kid.streak ?? 0) >= 2 &&
          kid.shieldReady == false;
      // At most one a day: the flame, when it's due, wins.
      final PlannedReminder? reminder;
      if (kid.flameEnabled && atRisk) {
        reminder = PlannedReminder(
          at: DateTime(day.year, day.month, day.day, 0, flameReminderMinutes),
          kind: ReminderKind.flame,
          english: kid.english,
          kidIds: [kid.kidId],
        );
      } else if (kid.enabled) {
        reminder = PlannedReminder(
          at: DateTime(day.year, day.month, day.day, 0, minutes),
          kind: ReminderKind.learn,
          english: kid.english,
          kidIds: [kid.kidId],
        );
      } else {
        reminder = null;
      }
      if (reminder != null && reminder.at.isAfter(now)) single.add(reminder);
    }
  }
  return _merge(single);
}

/// The kid's last played day, or the day reminders were turned on if that
/// is later: nothing to back off from before reminders existed.
DateTime? _lastActivity(KidReminderInput kid) {
  DateTime? last = kid.enabledOn == null ? null : _day(kid.enabledOn!);
  for (final d in kid.playedDays) {
    if (last == null || d.isAfter(last)) last = d;
  }
  return last;
}

int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// Reminders within [reminderMergeWindow] of the earliest in a group become
/// one, at that earliest time.
List<PlannedReminder> _merge(List<PlannedReminder> all) {
  final sorted = [...all]..sort((a, b) => a.at.compareTo(b.at));
  final out = <PlannedReminder>[];
  var group = <PlannedReminder>[];

  void flush() {
    if (group.isEmpty) return;
    if (group.length == 1) {
      out.add(group.single);
    } else {
      final english = group.where((r) => r.english).length;
      out.add(
        PlannedReminder(
          at: group.first.at,
          kind: ReminderKind.several,
          // The language most of them play in; French on a tie.
          english: english * 2 > group.length,
          kidIds: [for (final r in group) ...r.kidIds],
        ),
      );
    }
    group = [];
  }

  for (final r in sorted) {
    if (group.isNotEmpty &&
        r.at.difference(group.first.at) > reminderMergeWindow) {
      flush();
    }
    group.add(r);
  }
  flush();
  return out;
}
