import 'dart:convert';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Counts lookups, so a test can tell a rebuild from a reload.
class _Counting extends InMemoryImageResolver {
  _Counting(super.seed);
  int calls = 0;

  @override
  Future<Uint8List?> bytesFor({
    required String exerciseId,
    required String ref,
  }) {
    calls++;
    return super.bytesFor(exerciseId: exerciseId, ref: ref);
  }
}

Widget host(ImageResolver? resolver, {Key? key}) {
  final image = SizedBox(
    width: 64,
    height: 64,
    child: ContentImage(
      key: key,
      ref: 'img_a',
      fallback: const Text('chat'),
      semanticLabel: 'chat',
    ),
  );
  return MaterialApp(
    home: resolver == null
        ? image
        : ImageResolverScope(
            resolver: resolver,
            exerciseId: 'ex1',
            child: image,
          ),
  );
}

void main() {
  testWidgets('no scope above it: the fallback, never a throw', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pump();
    expect(find.text('chat'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('not synced: the fallback', (tester) async {
    await tester.pumpWidget(host(InMemoryImageResolver()));
    await tester.pump();
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('synced: the picture, named for screen readers', (tester) async {
    await tester.pumpWidget(host(InMemoryImageResolver({'ex1/img_a': _png})));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('chat'), findsOneWidget);
  });

  testWidgets('bytes that don\'t decode fall back like missing ones', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        InMemoryImageResolver({
          'ex1/img_a': Uint8List.fromList([1, 2, 3, 4]),
        }),
      ),
    );
    await tester.pump();
    // Decoding happens off the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('chat'), findsOneWidget);
  });

  testWidgets('a rebuild doesn\'t look the picture up again', (tester) async {
    final resolver = _Counting({'ex1/img_a': _png});
    const key = ValueKey('img');
    await tester.pumpWidget(host(resolver, key: key));
    await tester.pump();
    await tester.pumpWidget(host(resolver, key: key));
    await tester.pump();
    expect(resolver.calls, 1);
  });
}
