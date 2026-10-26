import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/net/recovery.dart';
import 'package:tutolys_app/data/api/notifications_api.dart';
import 'package:tutolys_app/data/api/progress_api.dart';
import 'package:tutolys_app/data/local_db/database.dart';
import 'package:tutolys_app/data/local_db/session_store.dart';
import 'package:tutolys_app/features/notifications/notifications_controller.dart';
import 'package:tutolys_app/features/pairing/pairing_controller.dart';
import 'package:tutolys_app/features/path/path_controller.dart';
import 'package:tutolys_app/features/progress/progress_controller.dart';

class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.paired,
    kid: PairedKid(id: 'k1', displayName: 'Yelhan', gradeLevel: 1),
    accessToken: 'token',
  );
}

/// Down for [failures] calls, then up: the backend's 35-minute outage.
class _OutageProgressApi extends ProgressApi {
  _OutageProgressApi(this.failures) : super(dio: Dio());
  int failures;
  int calls = 0;

  @override
  Future<ProgressResult> fetchMyProgress({required String accessToken}) async {
    calls++;
    if (failures > 0) {
      failures--;
      return const ProgressFailed('502');
    }
    return const ProgressFetched(
      ProgressSnapshot(masteries: [], currentStreakDays: 4, totalXp: 63),
    );
  }
}

class _Inbox extends NotificationsApi {
  _Inbox() : super(dio: Dio());
  int calls = 0;
  @override
  Future<NotificationsResult> fetch({required String accessToken}) async {
    calls++;
    return const NotificationsUnavailable();
  }
}

class _Path extends PathController {
  int refreshes = 0;
  @override
  PathState build() => const PathState(loading: false);
  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  group('RecoveryScheduler', () {
    test('backs off 5, 10, 20, 40, then 60 s, and stays at 60', () {
      final s = RecoveryScheduler(retryAll: () async {});
      expect(
        [for (var i = 1; i <= 7; i++) s.backoffAfter(i).inSeconds],
        [5, 10, 20, 40, 60, 60, 60],
      );
    });
  });

  testWidgets('after an outage, reads resume on their own and the header '
      'catches up (Hafid\'s 40-minute freeze)', (tester) async {
    final progress = _OutageProgressApi(4);
    final inbox = _Inbox();
    final path = _Path();
    final db = LocalDatabase.memory();
    final c = ProviderContainer(
      overrides: [
        sessionControllerProvider.overrideWith(_Session.new),
        progressApiProvider.overrideWithValue(progress),
        notificationsApiProvider.overrideWithValue(inbox),
        notificationsPollingProvider.overrideWithValue(false),
        pathControllerProvider.overrideWith(() => path),
        localDatabaseProvider.overrideWithValue(db),
        activeKidIdProvider.overrideWithValue('k1'),
      ],
    );
    addTearDown(db.close);

    Future<void> settleIo() => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    // First read fails: nothing shown yet.
    c.read(progressControllerProvider);
    await settleIo();
    await tester.pump();
    expect(progress.calls, 1);
    expect(c.read(progressControllerProvider).currentStreakDays, isNull);

    // No tap, no reload: the scheduler keeps asking, further apart.
    for (final wait in [5, 10, 20, 40]) {
      await tester.pump(Duration(seconds: wait));
      await settleIo();
    }
    expect(progress.calls, 5, reason: '1 + 4 retries, the last one succeeds');
    expect(c.read(progressControllerProvider).currentStreakDays, 4);
    expect(c.read(progressControllerProvider).totalXp, 63);
    expect(path.refreshes, greaterThan(0), reason: 'the Carte re-syncs too');
    expect(inbox.calls, greaterThan(0), reason: 'and the inbox');
    expect(
      c.read(recoveryProvider).failing,
      isTrue,
      reason: 'the inbox here never comes back, so retries continue',
    );
    // Disposed inside the test, so its pending retry timer goes with it.
    c.dispose();
  });

  testWidgets('coming back to the app retries at once', (tester) async {
    var runs = 0;
    final s = RecoveryScheduler(retryAll: () async => runs++);
    addTearDown(s.dispose);
    s.nudge();
    await tester.pump();
    expect(runs, 1);
  });

  testWidgets('the first success after failures re-runs every reader once', (
    tester,
  ) async {
    var runs = 0;
    final s = RecoveryScheduler(retryAll: () async => runs++);
    addTearDown(s.dispose);
    s.reportFailure();
    s.reportSuccess();
    await tester.pump();
    expect(runs, 1);
    s.reportSuccess();
    await tester.pump();
    expect(runs, 1, reason: 'only on the way out of a failure');
  });
}
