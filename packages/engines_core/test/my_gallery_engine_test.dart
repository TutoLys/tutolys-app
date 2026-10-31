import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_shelf.dart';

const fr = Locale('fr');
const ctx = EvaluationContext(attemptNumber: 1, skillNodeIds: ['s']);

const gallery = <String, Object?>{
  'reasons': [
    {'id': 'fier', 'label': 'J’en suis fier'},
    {'id': 'drole', 'label': 'C’est drôle'},
  ],
  'visitors': [
    {
      'character': 'grand_maman',
      'comment': 'Quelle belle galerie, mon trésor !',
    },
  ],
  'max_hang': 2,
};

Map<String, Object?> envelope(String engine, Map<String, Object?> config) => {
  'exercise_id': '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
  'version': 1,
  'content_hash': 'h',
  'engine_key': engine,
  'engine_min_version': 1,
  'skill_node_id': 'ad24bcba-93d0-5b4e-ab56-ec76e3409a53',
  'subject': 'FR',
  'grade': 1,
  'rank': 0,
  'prompt': {'text': 'Accroche tes créations.'},
  'config': config,
};

ActivitySessionController controllerFor(
  String engine,
  Map<String, Object?> config,
) => ActivitySessionController(
  envelope: QuestionEnvelope.parse(envelope(engine, config)).valueOrNull!,
  kidId: 'kid',
  engines: LearningEngineRegistry([
    eraseEngine(const MyGalleryEngine()),
    eraseEngine(const ComposeSlotsEngine()),
  ]),
  evaluators: EvaluatorRegistry(const [
    MyGalleryEvaluator(),
    ComposeBuildEvaluator(),
  ]),
  store: InMemoryActivitySessionStore(InMemoryEventOutbox()),
  appVersion: '0.2.0',
  seed: 3,
);

Widget app(ActivitySessionController c, FakeShelf? shelf, {bool dark = false}) {
  final body = Scaffold(
    body: LearningActivityView(controller: c, locale: fr, onDone: () {}),
  );
  return MaterialApp(
    theme: dark ? TutolysTheme.villageDark() : TutolysTheme.village(),
    home: shelf == null ? body : CreationShelfScope(shelf: shelf, child: body),
  );
}

void tallView(WidgetTester tester, {double width = 1000}) {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => pumpEventQueue());
  await tester.pump();
  await tester.pump();
}

void main() {
  const engine = MyGalleryEngine();
  const evaluator = MyGalleryEvaluator();

  group('parse and reduce', () {
    test('rejects a gallery that can\'t be played', () {
      String? reason(Map<String, Object?> config) =>
          switch (engine.parse(config)) {
            ParseInvalid(:final reason) => reason,
            _ => null,
          };
      expect(reason({...gallery, 'max_hang': 4}), contains('max_hang'));
      expect(
        reason({...gallery, 'visitors': <Object>[]}),
        contains('visitors'),
      );
      expect(
        reason({
          ...gallery,
          'engines': ['mcq'],
        }),
        contains('keep creations'),
      );
    });

    test('hang up to the limit, each with a reason; practice evidence', () {
      final c = engine.parse(gallery).valueOrNull!;
      var s = engine.initialize(c, const EngineSeed(1));
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const GalleryLoaded(['a', 'b', 'c'])).state;
      for (final id in ['a', 'b', 'c']) {
        s = engine.reduce(s, ToggleHang(id)).state;
      }
      expect(s.hung.keys, ['a', 'b']);
      expect(engine.extractAnswer(s), isNull);
      s = engine.reduce(s, const SetHangReason('a', 'fier')).state;
      s = engine.reduce(s, const SetHangReason('b', 'drole')).state;
      final r = evaluator.evaluate(c, engine.extractAnswer(s)!, ctx);
      expect(r.outcome, Outcome.correct);
      expect(r.evidence, EvidenceLevel.practice);
      final empty = engine
          .reduce(
            engine.initialize(c, const EngineSeed(1)),
            const GalleryLoaded([]),
          )
          .state;
      expect(engine.extractAnswer(empty)!.blanks, {'empty': 'true'});
    });
  });

  group('creationView', () {
    Creation made(String engine, Map<String, Object?> payload, {int v = 1}) =>
        Creation(
          id: 'x',
          engineKey: engine,
          exerciseId: 'e',
          payloadVersion: v,
          payload: payload,
          hung: false,
          createdAt: DateTime(2026),
        );

    test('draws what each creator engine keeps, refuses the rest', () {
      final piece = const PatternPiece.shape(shape: PatternShape.star).toJson();
      expect(PatternPiece.fromJson(piece)!.key, 's:star:blue:medium:0');
      for (final (engine, payload) in [
        (
          'compose_build',
          {
            'labels': ['Le', 'chat'],
          },
        ),
        (
          'pattern_machine',
          {
            'pieces': [piece, piece],
          },
        ),
        (
          'geometry_lab',
          {
            'pegs': 5,
            'band': [
              [0, 0],
              [0, 2],
              [2, 2],
            ],
          },
        ),
        (
          'mail_studio',
          {
            'recipient': 'journal',
            'template': 'article',
            'lines': ['Bonjour'],
          },
        ),
      ]) {
        expect(
          creationView(made(engine, payload), locale: fr),
          isNotNull,
          reason: engine,
        );
      }
      expect(creationView(made('mcq', {}), locale: fr), isNull);
      expect(
        creationView(
          made('compose_build', {
            'labels': ['a'],
          }, v: 2),
          locale: fr,
        ),
        isNull,
      );
      expect(
        creationView(made('pattern_machine', {'pieces': 'oops'}), locale: fr),
        isNull,
      );
    });
  });

  group('in the shell', () {
    testWidgets('keep a compose_build sentence, then hang it in the gallery', (
      tester,
    ) async {
      tallView(tester);
      final shelf = FakeShelf();
      final compose = controllerFor('compose_build', {
        'tiles': [
          {'id': 'le', 'label': 'Le'},
          {'id': 'chat', 'label': 'chat'},
          {'id': 'dort', 'label': 'dort'},
          {'id': 'vole', 'label': 'vole'},
        ],
        'target': ['le', 'chat', 'dort'],
        'shuffle': false,
        'creation': true,
      });
      await tester.runAsync(compose.start);
      await tester.pumpWidget(app(compose, shelf));
      expect(find.byKey(const ValueKey('creation-keep')), findsNothing);
      for (final id in ['le', 'chat', 'dort']) {
        await tester.tap(find.byKey(ValueKey('compose-tile-$id')));
        await settle(tester);
      }
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('creation-keep')));
      await settle(tester);
      expect(find.byKey(const ValueKey('creation-kept')), findsOne);
      expect(shelf.items.single.payload, {
        'labels': ['Le', 'chat', 'dort'],
      });
      expect(
        shelf.items.single.exerciseId,
        '6f1a4a18-7a3b-4c1e-9f51-6d2a1b2c3d4e',
      );
      compose.dispose();

      final c = controllerFor('my_gallery', gallery);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, shelf));
      await settle(tester);
      final id = shelf.items.single.id;
      expect(find.text('Le chat dort'), findsOne);
      // N12: it opens on the wall; tapping a creation shows it big.
      expect(find.byKey(const ValueKey('gallery-wall')), findsOne);
      await tester.tap(find.byKey(ValueKey('gallery-wall-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('gallery-large-$id')), findsOne);
      await tester.tap(find.byKey(const ValueKey('gallery-large-close')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('gallery-start-hanging')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('gallery-card-$id')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('gallery-reason-$id-fier')));
      await settle(tester);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      await settle(tester);
      expect(
        find.byKey(const ValueKey('gallery-visitor-grand_maman')),
        findsOne,
      );
      expect(shelf.items.single.hung, isTrue);
      c.dispose();
    });

    testWidgets('a compose_build answer with no creation flag is not kept', (
      tester,
    ) async {
      tallView(tester);
      final offered = await offersKeep(
        tester,
        c: controllerFor('compose_build', {
          'tiles': [
            {'id': 'six', 'label': '6'},
            {'id': 'huit', 'label': '8'},
            {'id': 'sept', 'label': '7'},
          ],
          'target': ['six', 'huit'],
          'shuffle': false,
        }),
        app: (c) => app(c, null),
        solve: const [PlaceTile('six'), PlaceTile('huit')],
      );
      expect(offered, isFalse);
    });

    for (final dark in [false, true]) {
      testWidgets('reason tiles pad and wrap their words at 375 px '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        tallView(tester, width: 375);
        final shelf = FakeShelf();
        await shelf.save(
          engineKey: 'compose_build',
          exerciseId: 'e',
          payload: {
            'labels': ['Le', 'chien', 'court', 'vite'],
          },
        );
        final c = controllerFor('my_gallery', {
          ...gallery,
          'reasons': [
            {'id': 'fier', 'label': 'Je suis fier ou fière'},
            {'id': 'travail', 'label': 'J’ai travaillé fort'},
          ],
        });
        await tester.runAsync(c.start);
        await tester.pumpWidget(app(c, shelf, dark: dark));
        await settle(tester);
        final id = shelf.items.single.id;
        await tester.tap(find.byKey(const ValueKey('gallery-start-hanging')));
        await settle(tester);
        await tester.tap(find.byKey(ValueKey('gallery-card-$id')));
        await settle(tester);
        for (final r in ['fier', 'travail']) {
          final tile = find.byKey(ValueKey('gallery-reason-$id-$r'));
          final box = tester.getRect(tile);
          final text = tester.getRect(
            find.descendant(of: tile, matching: find.byType(Text)).first,
          );
          expect(text.left - box.left, greaterThanOrEqualTo(12), reason: r);
          expect(box.right - text.right, greaterThanOrEqualTo(12), reason: r);
          expect(box.height, greaterThanOrEqualTo(48), reason: r);
        }
        expect(tester.takeException(), isNull);
        c.dispose();
      });
    }

    testWidgets('an empty gallery says so and lets the child go on', (
      tester,
    ) async {
      tallView(tester, width: 375);
      final c = controllerFor('my_gallery', gallery);
      await tester.runAsync(c.start);
      await tester.pumpWidget(app(c, null));
      await settle(tester);
      expect(find.byKey(const ValueKey('gallery-empty')), findsOne);
      await tester.tap(find.text('VALIDER'));
      await settle(tester);
      expect(find.text('Bravo !'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });
}
