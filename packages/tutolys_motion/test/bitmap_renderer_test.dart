import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tutolys_motion/tutolys_motion.dart';

CharacterActorState _state(
  Reaction r, {
  int generation = 0,
  bool reduced = false,
  CharacterManifest? manifest,
}) => CharacterActorState(
  manifest: manifest ?? BitmapCharacterRenderer.fox,
  reaction: r,
  generation: generation,
  reducedMotion: reduced,
);

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: TutolysTheme.village(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(child: SizedBox.square(dimension: 96, child: child)),
  ),
);

Transform _outerTransform(WidgetTester tester) => tester.widget<Transform>(
  find
      .descendant(
        of: find.byType(BitmapCharacterView),
        matching: find.byType(Transform),
      )
      .first,
);

/// Lets the first frame's own housekeeping (image resolution, route setup)
/// finish, so `hasScheduledFrame` reports only what the widget asked for.
Future<void> _settleFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('pose slots', () {
    test('every slot falls back to pose.default when it has no art', () {
      for (final r in Reaction.values) {
        expect(
          BitmapCharacterRenderer.poseAsset(BitmapCharacterRenderer.fox, r),
          'assets/characters/fox/pose-default.webp',
          reason: r.name,
        );
      }
    });

    test('a filled slot wins, and empty ones follow the fallbacks to it', () {
      final m = CharacterManifest(
        id: 'fox',
        version: 3,
        rendererType: RendererType.bitmap,
        supported: Reaction.values.toSet(),
        fallbacks: {Reaction.victory: Reaction.celebrating},
        assets: const {
          'pose.default': 'd.webp',
          'pose.celebrating': 'c.webp',
        },
      );
      expect(BitmapCharacterRenderer.poseAsset(m, Reaction.celebrating), 'c.webp');
      expect(BitmapCharacterRenderer.poseAsset(m, Reaction.victory), 'c.webp');
      expect(BitmapCharacterRenderer.poseAsset(m, Reaction.thinking), 'd.webp');
    });

    test('a fallback cycle ends on pose.default, not a hang', () {
      final m = CharacterManifest(
        id: 'x',
        version: 1,
        rendererType: RendererType.bitmap,
        supported: Reaction.values.toSet(),
        fallbacks: {
          Reaction.victory: Reaction.celebrating,
          Reaction.celebrating: Reaction.victory,
        },
        assets: const {'pose.default': 'd.webp'},
      );
      expect(BitmapCharacterRenderer.poseAsset(m, Reaction.victory), 'd.webp');
    });
  });

  group('manifest as data', () {
    test('fromJson reads a delivered manifest', () {
      final m = CharacterManifest.fromJson({
        'id': 'owl',
        'version': 2,
        'renderer': 'bitmap',
        'supported': ['celebrating', 'thinking', 'dancing'],
        'fallbacks': {'victory': 'celebrating', 'jumping': 'idle'},
        'assets': {'pose.default': 'owl.webp', 'bad': 3},
      });
      expect(m.id, 'owl');
      expect(m.rendererType, RendererType.bitmap);
      // `dancing` and `jumping` don't exist on this build: dropped.
      expect(m.supported, {
        Reaction.celebrating,
        Reaction.thinking,
        Reaction.idle,
      });
      expect(m.resolve(Reaction.victory), Reaction.celebrating);
      expect(m.assets, {'pose.default': 'owl.webp'});
    });

    test('an unknown renderer reads as placeholder, so it still draws', () {
      final m = CharacterManifest.fromJson({
        'id': 'x',
        'renderer': 'spine',
      });
      expect(m.rendererType, RendererType.placeholder);
    });
  });

  group('motion recipes', () {
    test('every one-shot starts and ends at rest, so nothing jumps', () {
      for (final r in Reaction.values) {
        final shot = MotionRecipe.of(r).oneShot;
        if (shot == null) continue;
        for (final t in [0.0, 1.0]) {
          final p = shot(t);
          expect(p.dy, closeTo(0, 1e-3), reason: '${r.name} dy@$t');
          expect(p.turns, closeTo(0, 1e-3), reason: '${r.name} turns@$t');
          expect(p.scaleY, closeTo(1, 1e-3), reason: '${r.name} scale@$t');
        }
      }
    });

    test('correct hops up, Presque sways, victory throws confetti', () {
      final hop = MotionRecipe.of(Reaction.celebrating);
      expect(hop.oneShot!(0.47).dy, lessThan(-0.15));
      expect(hop.particles, ParticleKind.stars);

      final presque = MotionRecipe.of(Reaction.encouraging);
      expect(presque.oneShot!(0.15).turns, isNot(closeTo(0, 1e-3)));
      expect(presque.oneShot!(0.15).dy, 0, reason: 'a sway, not a hop');
      expect(presque.particles, ParticleKind.none);

      expect(MotionRecipe.of(Reaction.victory).particles, ParticleKind.confetti);
      expect(MotionRecipe.of(Reaction.explaining).particles, ParticleKind.sparkles);
    });
  });

  group('BitmapCharacterView', () {
    testWidgets('idle breathes: a ticker is running', (tester) async {
      await tester.pumpWidget(_host(BitmapCharacterView(state: _state(Reaction.idle))));
      expect(find.byType(Image), findsOneWidget);
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        _outerTransform(tester).transform.getTranslation().y,
        lessThan(0),
        reason: 'mid-breath, lifted',
      );
    });

    testWidgets('reduced motion (OS/app setting) rests flat, no ticker', (tester) async {
      await tester.pumpWidget(
        _host(BitmapCharacterView(state: _state(Reaction.idle)), reduced: true),
      );
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_outerTransform(tester).transform.getTranslation().y, 0);

      // A cue under reduced motion changes the pose but never animates it.
      await tester.pumpWidget(
        _host(
          BitmapCharacterView(state: _state(Reaction.celebrating, generation: 1)),
          reduced: true,
        ),
      );
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_outerTransform(tester).transform.getTranslation().y, 0);
    });

    testWidgets("the director's reducedMotion flag alone also rests it", (tester) async {
      await tester.pumpWidget(
        _host(BitmapCharacterView(state: _state(Reaction.idle, reduced: true))),
      );
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a hidden IndexedStack tab stops the ticker', (tester) async {
      Widget stack(int index) => _host(
        IndexedStack(
          index: index,
          children: [
            const SizedBox(),
            BitmapCharacterView(state: _state(Reaction.idle)),
          ],
        ),
      );
      await tester.pumpWidget(stack(1));
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(stack(0));
      await tester.pump();
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(stack(1));
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'resumes when shown');
    });

    testWidgets('a correct answer hops once, then returns to breathing', (tester) async {
      await tester.pumpWidget(_host(BitmapCharacterView(state: _state(Reaction.idle))));
      await tester.pumpWidget(
        _host(BitmapCharacterView(state: _state(Reaction.celebrating, generation: 1))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final mid = _outerTransform(tester).transform.getTranslation().y;
      expect(mid, lessThan(-96 * 0.1), reason: 'in the air');
      expect(find.byType(CustomPaint), findsWidgets, reason: 'stars');

      await tester.pump(const Duration(milliseconds: 500));
      final after = _outerTransform(tester).transform.getTranslation().y;
      expect(after, greaterThan(-96 * 0.05), reason: 'landed, back to a breath');
    });

    testWidgets('mounting on victory plays it (the celebration screen)', (tester) async {
      await tester.pumpWidget(
        _host(BitmapCharacterView(state: _state(Reaction.victory, generation: 4))),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      expect(_outerTransform(tester).transform.getTranslation().y, lessThan(-96 * 0.1));
    });

    testWidgets('missing art draws the painted fox instead of nothing', (tester) async {
      final noArt = CharacterManifest(
        id: 'ghost',
        version: 1,
        rendererType: RendererType.bitmap,
        supported: {Reaction.celebrating},
      );
      await tester.pumpWidget(
        _host(BitmapCharacterView(state: _state(Reaction.idle, manifest: noArt))),
      );
      expect(find.byType(TutolysMascot), findsOneWidget);
    });
  });

  testWidgets('end to end: a runtime event moves the bitmap fox, no engine involved', (
    tester,
  ) async {
    final events = StreamController<RuntimeEvent>.broadcast();
    final registry = CharacterRegistry(
      manifests: [BitmapCharacterRenderer.fox],
      renderers: const [BitmapCharacterRenderer(), PlaceholderCharacterRenderer()],
    );
    final director = AnimationDirector(
      events: events.stream,
      cast: const CastAssignment({ActorRole.guide: 'fox'}),
      registry: registry,
    );
    addTearDown(director.dispose);
    addTearDown(events.close);

    await tester.pumpWidget(
      _host(CharacterStage(director: director, registry: registry, size: 96)),
    );
    expect(find.byType(BitmapCharacterView), findsOneWidget);

    events.add(
      const AnswerEvaluated(
        questionIndex: 0,
        result: EvaluationResult(
          outcome: Outcome.correct,
          score: 1,
          attemptNumber: 1,
          evaluator: 'e',
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<BitmapCharacterView>(find.byType(BitmapCharacterView)).state.reaction,
      Reaction.celebrating,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_outerTransform(tester).transform.getTranslation().y, lessThan(-96 * 0.1));
    // Let the director's hold timer run out before teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  group('XpPop', () {
    testWidgets('floats up and fades, then stops ticking', (tester) async {
      await tester.pumpWidget(_host(const XpPop(xp: 10)));
      expect(find.text('+10 XP'), findsOneWidget);
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduced motion: shown still, no ticker', (tester) async {
      await tester.pumpWidget(_host(const XpPop(xp: 10), reduced: true));
      expect(find.text('+10 XP'), findsOneWidget);
      await _settleFrame(tester);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
