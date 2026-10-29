import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/core/startup/storage_problem.dart';
import 'package:tutolys_app/data/local_db/database.dart';

/// K5 (ADR 0099): a store that won't open after an upgrade retries on a
/// fresh worker, and otherwise says "storage", never "Internet".
void main() {
  group('openLocalDatabaseWithRetry', () {
    test('first open works: no retry', () async {
      final versions = <String>[];
      final opened = await openLocalDatabaseWithRetry(
        assetVersion: '1.0.0+abc',
        open: (v) {
          versions.add(v);
          return LocalDatabase.memory();
        },
      );
      expect(opened.ok, isTrue);
      expect(opened.retried, isFalse);
      expect(versions, ['1.0.0+abc']);
      await opened.db.close();
    });

    test('a poisoned worker: the retry uses a brand-new worker URL', () async {
      final versions = <String>[];
      var probes = 0;
      final opened = await openLocalDatabaseWithRetry(
        assetVersion: '1.0.0',
        clock: () => DateTime.fromMicrosecondsSinceEpoch(42),
        open: (v) {
          versions.add(v);
          return LocalDatabase.memory();
        },
        probe: (db) async {
          if (probes++ == 0) throw StateError('TypeError: Failed to fetch');
        },
      );
      expect(opened.ok, isTrue);
      expect(opened.retried, isTrue);
      expect(versions, ['1.0.0', '1.0.0-retry42']);
      await opened.db.close();
    });

    test('still failing: the error comes back instead of a hang', () async {
      final opened = await openLocalDatabaseWithRetry(
        assetVersion: '1.0.0',
        open: (_) => LocalDatabase.memory(),
        probe: (db) async => throw StateError('corrupt'),
      );
      expect(opened.ok, isFalse);
      expect(opened.error, isA<StateError>());
      await opened.db.close();
    });

    test('a probe that never answers times out', () async {
      final opened = await openLocalDatabaseWithRetry(
        assetVersion: '1.0.0',
        timeout: const Duration(milliseconds: 20),
        open: (_) => LocalDatabase.memory(),
        probe: (db) => Future<void>.delayed(const Duration(seconds: 5)),
      );
      expect(opened.ok, isFalse);
      await opened.db.close();
    });
  });

  group('the storage screen', () {
    Widget screen({
      required Future<void> Function() onRetry,
      bool canRepair = false,
      Future<void> Function()? repair,
      Strings t = Strings.fr,
    }) => MaterialApp(
      theme: TutolysTheme.village(),
      home: StorageProblemScreen(
        strings: t,
        onRetry: onRetry,
        canRepair: canRepair,
        repair: repair,
      ),
    );

    test('says storage, never Internet, in both languages', () {
      for (final t in [Strings.fr, Strings.en]) {
        final words = '${t.storageProblemTitle} ${t.storageProblemBody}'
            .toLowerCase();
        expect(words, isNot(contains('connecte')));
        expect(words, isNot(contains('connect to')));
        expect(words, anyOf(contains('rangement'), contains('storage')));
      }
    });

    testWidgets('Réessayer opens again', (tester) async {
      var retries = 0;
      await tester.pumpWidget(screen(onRetry: () async => retries++));
      await tester.tap(find.byKey(const ValueKey('storage-retry')));
      await tester.pump();
      expect(retries, 1);
      expect(find.byKey(const ValueKey('storage-repair')), findsNothing);
    });

    testWidgets('Réparer says what is lost before it resets', (tester) async {
      var repaired = 0;
      await tester.pumpWidget(
        screen(
          onRetry: () async {},
          canRepair: true,
          repair: () async => repaired++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('storage-repair')));
      await tester.pumpAndSettle();
      expect(find.text(Strings.fr.storageRepairBody), findsOneWidget);
      await tester.tap(find.text(Strings.fr.cancel));
      await tester.pumpAndSettle();
      expect(repaired, 0, reason: 'nothing without a yes');

      await tester.tap(find.byKey(const ValueKey('storage-repair')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('storage-repair-go')));
      await tester.pumpAndSettle();
      expect(repaired, 1);
    });
  });
}
