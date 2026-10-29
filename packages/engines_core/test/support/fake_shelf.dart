import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory [CreationShelf], as the Flutter app's real store behaves:
/// newest first, at most [CreationShelf.maxHung] hung.
class FakeShelf implements CreationShelf {
  final items = <Creation>[];
  var _next = 0;

  @override
  Future<Creation> save({
    required String engineKey,
    required String exerciseId,
    required Map<String, Object?> payload,
    int payloadVersion = 1,
  }) async {
    final c = Creation(
      id: 'c${_next++}',
      engineKey: engineKey,
      exerciseId: exerciseId,
      payloadVersion: payloadVersion,
      payload: payload,
      hung: false,
      createdAt: DateTime(2026, 10, 26, 9, _next),
    );
    items.insert(0, c);
    return c;
  }

  @override
  Future<List<Creation>> list({
    Set<String>? engineKeys,
    bool? hung,
    int? limit,
  }) async => [
    for (final c in items)
      if ((engineKeys == null || engineKeys.contains(c.engineKey)) &&
          (hung == null || c.hung == hung))
        c,
  ].take(limit ?? 999).toList();

  @override
  Future<void> setHung(String id, bool hung) async {
    final i = items.indexWhere((c) => c.id == id);
    if (i < 0) return;
    if (hung && items.where((c) => c.hung).length >= CreationShelf.maxHung) {
      throw StateError('full');
    }
    final c = items[i];
    items[i] = Creation(
      id: c.id,
      engineKey: c.engineKey,
      exerciseId: c.exerciseId,
      payloadVersion: c.payloadVersion,
      payload: c.payload,
      hung: hung,
      createdAt: c.createdAt,
    );
  }

  @override
  Future<void> remove(String id) async => items.removeWhere((c) => c.id == id);
}

/// Whether a finished exercise offers "Garder dans mes créations", with a
/// shelf present, for content with and without `creation: true`. The
/// engines show the button only when the content asks (app ADR 0093).
///
/// Starts [c], dispatches [solve] through the controller and submits.
Future<bool> offersKeep(
  WidgetTester tester, {
  required ActivitySessionController c,
  required Widget Function(ActivitySessionController) app,
  required List<Object> solve,
}) async {
  await tester.runAsync(c.start);
  await tester.pumpWidget(
    CreationShelfScope(shelf: FakeShelf(), child: app(c)),
  );
  for (final action in solve) {
    await tester.runAsync(() => c.dispatch(action));
  }
  await tester.runAsync(c.submit);
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
  expect(find.text('Bravo !'), findsOneWidget);
  final offered = find
      .byKey(const ValueKey('creation-keep'))
      .evaluate()
      .isNotEmpty;
  c.dispose();
  return offered;
}
