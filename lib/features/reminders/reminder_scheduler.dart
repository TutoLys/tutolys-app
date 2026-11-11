import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/diagnostics/diag_log.dart' show recordCaught;
import '../../core/i18n/strings.dart';
import 'reminder_policy.dart';

/// What a platform can do with reminders (ADR 0053).
enum ReminderSupport {
  /// The OS keeps them and fires them with the app closed (Android, iOS,
  /// macOS).
  scheduled,

  /// Linux: the plugin can show a notification but not schedule one, so
  /// they fire only while TutoLys is running, even minimised.
  whileRunning,

  /// Web: nothing. Closed-tab reminders would need push, and a browser
  /// permission prompt in front of a child is what we don't want.
  none,
}

ReminderSupport reminderSupportFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return ReminderSupport.none;
  return switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => ReminderSupport.scheduled,
    TargetPlatform.linux || TargetPlatform.windows => ReminderSupport.whileRunning,
    _ => ReminderSupport.none,
  };
}

final ReminderSupport currentReminderSupport = reminderSupportFor(
  isWeb: kIsWeb,
  platform: defaultTargetPlatform,
);

/// This platform's support, overridable so Réglages can be tested as any
/// platform.
final reminderSupportProvider = Provider<ReminderSupport>(
  (ref) => currentReminderSupport,
);

/// The reminder's words, in the language [r] says.
({String title, String body}) reminderText(PlannedReminder r) {
  final t = r.english ? Strings.en : Strings.fr;
  return (
    title: t.reminderTitle,
    body: switch (r.kind) {
      ReminderKind.learn => t.reminderLearnBody,
      ReminderKind.flame => t.reminderFlameBody,
      ReminderKind.several => t.reminderSeveralBody,
    },
  );
}

/// Replaces whatever was scheduled with [plan].
abstract class ReminderSink {
  Future<void> replaceAll(List<PlannedReminder> plan);

  /// Asks the OS for permission, while the guardian holds the device.
  /// True when reminders can be shown.
  Future<bool> requestPermission() async => true;
}

class NoReminderSink extends ReminderSink {
  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {}

  @override
  Future<bool> requestPermission() async => false;
}

/// Shows a reminder now. The plugin, behind a seam for tests.
typedef ShowReminder = Future<void> Function(int id, PlannedReminder r);

/// Linux: one in-process timer per reminder, shown when it fires.
class RunningReminderSink extends ReminderSink {
  RunningReminderSink({required this.show, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final ShowReminder show;
  final DateTime Function() _now;
  final _timers = <Timer>[];

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    final now = _now();
    for (var i = 0; i < plan.length; i++) {
      final r = plan[i];
      final id = i + 1;
      _timers.add(
        Timer(r.at.difference(now), () {
          show(id, r).catchError(
            (Object e, StackTrace s) => recordCaught('reminder_show', e, s),
          );
        }),
      );
    }
  }
}

/// Android, iOS, macOS: the OS schedules each reminder at its instant.
///
/// One-off reminders at absolute instants, converted from local time by
/// `DateTime` itself, so no time-zone database is needed: daylight saving
/// is already in the instant.
class ScheduledReminderSink extends ReminderSink {
  ScheduledReminderSink(this.plugin);

  final FlutterLocalNotificationsPlugin plugin;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {
    await plugin.cancelAll();
    for (var i = 0; i < plan.length; i++) {
      final r = plan[i];
      final text = reminderText(r);
      await plugin.zonedSchedule(
        id: i + 1,
        title: text.title,
        body: text.body,
        scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        notificationDetails: reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminderPayload,
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final mac = plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (mac != null) {
      return await mac.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }
}

/// Every reminder carries this, so a tap knows it came from one.
const reminderPayload = 'tutolys.reminder';

const reminderDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'reminders',
    'Rappels',
    channelDescription: 'Rappels pour apprendre',
  ),
  iOS: DarwinNotificationDetails(),
  macOS: DarwinNotificationDetails(),
  linux: LinuxNotificationDetails(),
  windows: WindowsNotificationDetails(),
);

/// The plugin refuses to start on Windows without these (ADR 0127). The
/// GUID is fixed: Windows keys the toast's activator on it.
const windowsReminderInit = WindowsInitializationSettings(
  appName: 'TutoLys',
  appUserModelId: 'Ca.Tutolys.App',
  guid: '14db7fd5-ddec-4e73-8214-26b244ecad7e',
);

const _darwinInit = DarwinInitializationSettings(
  requestAlertPermission: false,
  requestBadgePermission: false,
  requestSoundPermission: false,
);

/// Starts the plugin and picks the sink for this platform. [onTap] runs
/// when a reminder is tapped while the app is running.
Future<ReminderSink> createReminderSink({
  required void Function() onTap,
}) async {
  if (currentReminderSupport == ReminderSupport.none) return NoReminderSink();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission is asked for only when a guardian turns reminders on.
      iOS: _darwinInit,
      macOS: _darwinInit,
      linux: LinuxInitializationSettings(defaultActionName: 'Ouvrir'),
      // Required on Windows: without it `initialize` throws (ADR 0127).
      windows: windowsReminderInit,
    ),
    onDidReceiveNotificationResponse: (response) {
      if (response.payload == reminderPayload) onTap();
    },
  );
  if (currentReminderSupport == ReminderSupport.scheduled) {
    return ScheduledReminderSink(plugin);
  }
  return RunningReminderSink(
    show: (id, r) {
      final text = reminderText(r);
      return plugin.show(
        id: id,
        title: text.title,
        body: text.body,
        notificationDetails: reminderDetails,
        payload: reminderPayload,
      );
    },
  );
}
