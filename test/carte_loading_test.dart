import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_app/core/i18n/strings.dart';
import 'package:tutolys_app/data/api/content_api.dart';
import 'package:tutolys_app/data/api/curriculum_api.dart';
import 'package:tutolys_app/features/path/path_controller.dart';

import 'path_screen_test.dart'
    show FakeContentApi, FakeCurriculumApi, appUnder, exercise, openCarte;

const _leaf = CurriculumLeaf(
  id: 'leaf-1',
  labelFr: 'Compter',
  labelEn: '',
  stableKey: 'mathematique/sens-et-ecriture-des-nombres/b:A/o:1',
);

/// A manifest whose parse blows up, like a bad cast on unexpected content.
class _Throwing extends FakeContentApi {
  _Throwing(super.content);

  @override
  Future<ManifestResult> fetchManifest({
    required String accessToken,
    String? subject,
    String? locale,
  }) async => throw StateError('bad manifest');
}

/// A curriculum server that never answers.
class _Hanging extends FakeCurriculumApi {
  _Hanging() : super(const {});
  final never = Completer<CurriculumTreeResult>();
  int calls = 0;

  @override
  Future<CurriculumTreeResult> fetchTree({
    required String accessToken,
    required String subject,
  }) {
    calls++;
    return never.future;
  }
}

/// A1: the Carte never stays on its loader.
void main() {
  final content = {'ex-1': exercise(id: 'ex-1', skillNodeId: 'leaf-1')};

  testWidgets('a throw in the lesson sync still draws the map', (tester) async {
    await openCarte(
      tester,
      appUnder(
        leaves: const [_leaf],
        content: content,
        contentApi: _Throwing(content),
      ),
    );
    expect(find.byKey(const ValueKey('carte-path')), findsOneWidget);
    final state = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('carte-path'))),
    ).read(pathControllerProvider);
    expect(state.loading, isFalse);
    expect(state.syncFailed, isTrue);
    expect(state.leaves, hasLength(1));
    expect(
      find.byKey(const ValueKey('path-orb-leaf-1'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('carte-stale')), findsOneWidget);
    // A10: nothing playable and unreachable: kid words and a Réessayer,
    // never "connecte-toi".
    expect(find.byKey(const ValueKey('carte-gap-retry')), findsOneWidget);
    expect(find.text(Strings.fr.pathEmptyOffline), findsOneWidget);
    expect(Strings.fr.pathEmptyOffline, isNot(contains('Connecte')));
  });

  testWidgets('a silent server: the fox and Réessayer after 8 s, then the '
      'cache after 15 s', (tester) async {
    final hanging = _Hanging();
    await tester.pumpWidget(
      appUnder(leaves: const [], content: content, curriculum: hanging),
    );
    await tester.pump();
    await tester.tap(find.text('Carte'));
    await tester.pump();
    expect(find.byKey(const ValueKey('carte-slow')), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const ValueKey('carte-slow')), findsOneWidget);
    expect(find.text(Strings.fr.pathSlow), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('carte-path'))),
    );
    expect(container.read(pathControllerProvider).loading, isFalse);
    expect(find.byKey(const ValueKey('carte-slow')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('refreshes in flight share one load', (tester) async {
    final hanging = _Hanging();
    await tester.pumpWidget(
      appUnder(leaves: const [], content: content, curriculum: hanging),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final notifier = container.read(pathControllerProvider.notifier);
    await tester.pump();
    final before = hanging.calls;
    unawaited(notifier.refresh());
    unawaited(notifier.refresh());
    unawaited(notifier.refresh());
    await tester.pump();
    expect(hanging.calls, before, reason: 'joined the load already running');
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
  });
}
