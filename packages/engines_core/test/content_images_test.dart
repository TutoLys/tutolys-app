import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real 1x1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const _exerciseId = '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e';

Map<String, Object?> envelope(
  String engineKey,
  Map<String, Object?> config, {
  String? promptImage,
}) => {
  'exercise_id': _exerciseId,
  'version': 1,
  'content_hash': 'h',
  'engine_key': engineKey,
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'SCI',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Question', 'image_ref': ?promptImage},
  'config': config,
};

final _registry = LearningEngineRegistry([
  eraseEngine(const SingleChoiceEngine()),
  eraseEngine(const SortBucketsEngine()),
  eraseEngine(const FindItEngine()),
  eraseEngine(const TimelineOrderEngine()),
]);

Future<ActivitySessionController> pump(
  WidgetTester tester,
  Map<String, Object?> env, {
  Set<String> synced = const {},
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = ActivitySessionController(
    envelope: QuestionEnvelope.parse(env).valueOrNull!,
    kidId: 'kid',
    engines: _registry,
    evaluators: EvaluatorRegistry(const [
      McqExactEvaluator(),
      SortBucketsEvaluator(),
      FindItEvaluator(),
      TimelineOrderEvaluator(),
    ]),
    store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
    appVersion: '0.2.0',
    seed: 3,
  );
  await tester.runAsync(c.start);
  await tester.pumpWidget(
    MaterialApp(
      theme: TutolysTheme.village(),
      home: Scaffold(
        body: ImageResolverScope(
          resolver: InMemoryImageResolver({
            for (final ref in synced) '$_exerciseId/$ref': _png,
          }),
          exerciseId: _exerciseId,
          child: LearningActivityView(
            controller: c,
            locale: const Locale('fr'),
            onDone: () {},
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  return c;
}

Finder imageIn(Finder f) =>
    find.descendant(of: f, matching: find.byType(Image));

void main() {
  const mcq = <String, Object?>{
    'options': [
      {'id': 'a', 'label': 'chat', 'image_ref': 'img_chat'},
      {'id': 'b', 'label': 'roche'},
    ],
    'correct': 'a',
    'shuffle': false,
  };

  testWidgets('an option picture shows once synced, beside its label', (
    tester,
  ) async {
    final c = await pump(tester, envelope('mcq', mcq), synced: {'img_chat'});
    final tile = find.widgetWithText(AnswerTile, 'chat');
    expect(imageIn(tile), findsOneWidget);
    expect(find.text('chat'), findsOneWidget, reason: 'the label stays');
    expect(imageIn(find.widgetWithText(AnswerTile, 'roche')), findsNothing);
    c.dispose();
  });

  testWidgets('not synced yet: the tile is its label, no empty frame', (
    tester,
  ) async {
    final c = await pump(tester, envelope('mcq', mcq));
    expect(imageIn(find.widgetWithText(AnswerTile, 'chat')), findsNothing);
    expect(find.text('chat'), findsOneWidget);
    c.dispose();
  });

  testWidgets('the prompt picture is drawn above the question', (tester) async {
    final c = await pump(
      tester,
      envelope('mcq', mcq, promptImage: 'img_scene'),
      synced: {'img_scene'},
    );
    final image = find.byKey(const ValueKey('prompt-image'));
    expect(imageIn(image), findsOneWidget);
    expect(
      tester.getTopLeft(image).dy,
      lessThan(tester.getTopLeft(find.text('Question')).dy),
    );
    c.dispose();
  });

  testWidgets('sort_buckets: item and bucket pictures', (tester) async {
    final c = await pump(
      tester,
      envelope('sort_buckets', {
        'buckets': [
          {'id': 'v', 'label': 'Vivant', 'image_ref': 'img_v'},
          {'id': 'n', 'label': 'Non vivant'},
        ],
        'items': [
          {
            'id': 'chat',
            'label': 'chat',
            'correct_bucket': 'v',
            'image_ref': 'img_chat',
          },
          {'id': 'roche', 'label': 'roche', 'correct_bucket': 'n'},
        ],
      }),
      synced: {'img_v', 'img_chat'},
    );
    expect(
      imageIn(find.byKey(const ValueKey('sort-bucket-v'))),
      findsOneWidget,
    );
    expect(
      imageIn(find.byKey(const ValueKey('sort-item-chat'))),
      findsOneWidget,
    );
    c.dispose();
  });

  testWidgets('find_it grid: a picture fills the square, label until synced', (
    tester,
  ) async {
    final config = <String, Object?>{
      'layout': 'grid',
      'columns': 2,
      'scene_items': [
        {'id': 'a1', 'label': '🏫', 'image_ref': 'img_school'},
        {'id': 'b1', 'label': ''},
        {'id': 'a2', 'label': '🏠', 'image_ref': 'img_house'},
        {'id': 'b2', 'label': ''},
      ],
      'correct_ids': ['a1'],
    };
    final c = await pump(
      tester,
      envelope('find_it', config),
      synced: {'img_school'},
    );
    expect(imageIn(find.byKey(const ValueKey('find-cell-a1'))), findsOneWidget);
    expect(imageIn(find.byKey(const ValueKey('find-cell-a2'))), findsNothing);
    expect(find.text('🏠'), findsOneWidget, reason: 'fallback is the label');
    c.dispose();
  });

  testWidgets('timeline: a placed item keeps its picture', (tester) async {
    final c = await pump(
      tester,
      envelope('timeline_calendar', {
        'items': [
          {'id': 'oeuf', 'label': 'œuf', 'order': 0, 'image_ref': 'img_egg'},
          {'id': 'chenille', 'label': 'chenille', 'order': 1},
          {'id': 'papillon', 'label': 'papillon', 'order': 2},
        ],
      }),
      synced: {'img_egg'},
    );
    expect(
      imageIn(find.byKey(const ValueKey('timeline-item-oeuf'))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('timeline-item-oeuf')));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    expect(
      imageIn(find.byKey(const ValueKey('timeline-slot-0'))),
      findsOneWidget,
    );
    c.dispose();
  });
}
