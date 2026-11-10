import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/diagnostics/boot_log.dart';
import 'package:tutolys_app/core/diagnostics/diag_log.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/local_db/app_settings.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/features/launch/boot_stuck_view.dart';
import 'package:tutolys_app/features/launch/launch_flow.dart';
import 'package:tutolys_app/features/launch/tutolys_loader_screen.dart';
import 'package:tutolys_app/features/settings/settings_controller.dart';

final _fr = Strings.of(const Locale('fr', 'CA'));

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(1024, 800), disableAnimations: true),
  child: MaterialApp(
    locale: const Locale('fr', 'CA'),
    supportedLocales: const [Locale('fr', 'CA'), Locale('en', 'CA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: TutolysTheme.village(),
    home: child,
  ),
);

/// A settings store whose read never answers: the 2026-10-26 hang.
class _HangingStore extends AppSettingsStore {
  _HangingStore(super.db) : super(kidId: 'k');

  @override
  Future<AppSettings> read() => Completer<AppSettings>().future;
}

/// Startup diagnostics (ADR 0038, observability work order A1–A3).
void main() {
  group('scrubbing', () {
    test('removes a JWT, a bearer token, an email and a pairing code', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJraWQifQ.c2lnbmF0dXJlX2hlcmU';
      final out = DiagLog.scrub(
        'token $jwt for lea.parent+1@example.test code K7M2QX '
        'Authorization: Bearer abc.def',
      );
      expect(out, isNot(contains('eyJ')));
      expect(out, isNot(contains('@')));
      expect(out, isNot(contains('K7M2QX')));
      expect(out, isNot(contains('abc.def')));
      expect(out, contains('<jwt>'));
      expect(out, contains('<email>'));
      expect(out, contains('<code>'));
    });

    test('removes a prefixed device token, wherever it appears', () {
      final out = DiagLog.scrub(
        'refresh failed {device_token: tld_Q3x-9_aZ.k~} retrying',
      );
      expect(out, isNot(contains('tld_')));
      expect(out, isNot(contains('Q3x')));
      expect(out, contains('<device-token>'));
      expect(out, contains('retrying'));
    });

    test('keeps ordinary words and error names', () {
      const text = 'TimeoutException after 0:00:10 in SESSION RESTORE';
      expect(DiagLog.scrub(text), text);
    });
  });

  group('the ring buffer', () {
    test('keeps the last 200, scrubbed, with the top 5 frames', () {
      final log = DiagLog();
      for (var i = 0; i < 205; i++) {
        log.record('caught:test', StateError('n$i'), StackTrace.current);
      }
      expect(log.entries, hasLength(200));
      expect(log.entries.first.message, contains('n5'));
      expect(log.entries.last.frames.length, lessThanOrEqualTo(5));
    });

    test('round-trips for the previous run', () {
      final log = DiagLog()..record('zone', StateError('boom'));
      final next = DiagLog()..restore(DiagLog.encode(log.entries));
      expect(next.previousRun.single.message, contains('boom'));
      expect(next.previousRun.single.kind, 'zone');
      expect((DiagLog()..restore('not json')).previousRun, isEmpty);
    });

    testWidgets('an error thrown in a frame callback lands in it', (
      tester,
    ) async {
      final log = DiagLog();
      final framework = FlutterError.onError;
      final platform = tester.binding.platformDispatcher.onError;
      log.installHooks();
      try {
        await tester.pumpWidget(const SizedBox());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          throw StateError('boom for kid@example.test');
        });
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());
      } finally {
        FlutterError.onError = framework;
        tester.binding.platformDispatcher.onError = platform;
      }
      final entry = log.entries.single;
      expect(entry.kind, 'flutter');
      expect(entry.type, 'StateError');
      expect(entry.message, isNot(contains('@')));
    });
  });

  group('the boot log', () {
    testWidgets('a step past its timeout is recorded and fails', (
      tester,
    ) async {
      final boot = BootLog(verbose: false);
      Object? error;
      boot
          .run(
            'db_open',
            () => Completer<void>().future,
            timeout: const Duration(seconds: 10),
          )
          .catchError((Object e) => error = e);
      await tester.pump(const Duration(seconds: 9));
      expect(boot.stuckOn?.name, 'db_open');
      await tester.pump(const Duration(seconds: 2));
      expect(error, isA<TimeoutException>());
      expect(boot.steps.single.outcome, BootOutcome.timeout);
      expect(boot.stuckOn, isNull);
    });

    test('prints each step in the agreed format', () {
      final boot = BootLog(verbose: false)..mark('first_frame');
      expect(
        boot.steps.single.describe(),
        matches(RegExp(r'^\[boot \+\d+\.\d{3}s\] first_frame ok \(\d+ ms\)$')),
      );
    });
  });

  group('the stuck screen', () {
    testWidgets('replaces the loader after 15 s, names the step, retries', (
      tester,
    ) async {
      final boot = BootLog(verbose: false)..start('db_open');
      var retries = 0;
      await tester.pumpWidget(
        _host(
          LaunchFlow(
            stage: LaunchStage.restoring,
            startProgress: 0.1,
            onFinished: () {},
            onRetry: () => retries++,
            bootLog: boot,
            diagLog: DiagLog(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 14));
      expect(find.byType(BootStuckView), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text(_fr.bootStuckTitle), findsOneWidget);
      expect(find.textContaining('db_open'), findsNothing);

      await tester.tap(find.text(_fr.bootDetails));
      await tester.pump();
      expect(find.textContaining(_fr.bootStuckOn('db_open')), findsOneWidget);

      await tester.tap(find.text(_fr.retry));
      await tester.pump();
      await tester.pump();
      expect(retries, 1);
      expect(find.byType(TutolysLoaderScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a settings read that never answers stops holding boot', (
    tester,
  ) async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_HangingStore(db)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(settingsReadyProvider, (_, _) {});

    await tester.pump(const Duration(seconds: 5));
    expect(sub.read(), isFalse);
    await tester.pump(BootLog.localTimeout);
    await tester.pump();
    expect(sub.read(), isTrue);
    expect(container.read(settingsControllerProvider), const AppSettings());
  });
}
