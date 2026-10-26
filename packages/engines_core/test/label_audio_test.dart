import 'package:design_system/design_system.dart';
import 'package:engine_sdk/engine_sdk.dart';
import 'package:engines_core/engines_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answer labels read on request only (app ADR 0087): a speaker on the
/// tile, or a long press. Never by itself, never on a plain tap.
class _Recorder implements ContentSpeaker {
  final spoken = <String>[];

  @override
  void speak({required String audioRef, required String partId}) =>
      spoken.add(audioRef);
}

Widget host(Widget child, {ContentSpeaker? speaker}) {
  final body = Scaffold(
    body: Center(child: SizedBox(width: 260, child: child)),
  );
  return MaterialApp(
    theme: TutolysTheme.village(),
    home: speaker == null
        ? body
        : ContentSpeakerScope(speaker: speaker, child: body),
  );
}

void main() {
  group('AnswerTile', () {
    testWidgets('no speaker without a host speaker or a recording', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnswerTile(
            label: 'chat',
            audioRef: 'q0_opt_a',
            state: AnswerTileState.idle,
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

      await tester.pumpWidget(
        host(
          AnswerTile(label: 'chat', state: AnswerTileState.idle, onTap: () {}),
          speaker: _Recorder(),
        ),
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('a tap chooses silently; the speaker and a long press play', (
      tester,
    ) async {
      final speaker = _Recorder();
      var taps = 0;
      await tester.pumpWidget(
        host(
          AnswerTile(
            label: 'chat',
            audioRef: 'q0_opt_a',
            state: AnswerTileState.idle,
            onTap: () => taps++,
          ),
          speaker: speaker,
        ),
      );
      await tester.tap(find.text('chat'));
      expect(taps, 1);
      expect(speaker.spoken, isEmpty);

      await tester.tap(find.byKey(const ValueKey('tile-speak-q0_opt_a')));
      expect(speaker.spoken, ['q0_opt_a']);
      expect(taps, 1);

      await tester.longPress(find.text('chat'));
      expect(speaker.spoken, ['q0_opt_a', 'q0_opt_a']);
      expect(taps, 1);
    });

    testWidgets('a screen reader gets a "listen" action', (tester) async {
      final handle = tester.ensureSemantics();
      final speaker = _Recorder();
      await tester.pumpWidget(
        host(
          AnswerTile(
            label: 'chat',
            audioRef: 'q0_opt_a',
            state: AnswerTileState.idle,
            onTap: () {},
          ),
          speaker: speaker,
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('chat'));
      expect(node.getSemanticsData().customSemanticsActionIds, isNotEmpty);
      handle.dispose();
    });
  });

  group('engines carry label recordings to their tiles', () {
    test('every label model parses audio_ref', () {
      final sort = const SortBucketsEngine().parse({
        'buckets': [
          {'id': 'v', 'label': 'Vivant', 'audio_ref': 'b_v'},
          {'id': 'n', 'label': 'Non vivant'},
        ],
        'items': [
          {
            'id': 'chat',
            'label': 'un chat',
            'correct_bucket': 'v',
            'audio_ref': 'i_chat',
          },
          {'id': 'roche', 'label': 'une roche', 'correct_bucket': 'n'},
        ],
      }).valueOrNull!;
      expect(sort.buckets.first.audioRef, 'b_v');
      expect(sort.item('chat').audioRef, 'i_chat');

      final compose = const ComposeSlotsEngine().parse({
        'tiles': [
          {'id': 'ba', 'label': 'ba', 'audio_ref': 't_ba'},
          {'id': 'le', 'label': 'le'},
        ],
        'target': ['ba', 'le'],
      }).valueOrNull!;
      expect(compose.tile('ba').audioRef, 't_ba');
      expect(compose.tile('le').audioRef, isNull);
    });

    testWidgets('mcq options show a speaker; choosing stays silent', (
      tester,
    ) async {
      const engine = SingleChoiceEngine();
      final content = engine.parse({
        'options': [
          {'id': 'a', 'label': 'un chat', 'audio_ref': 'q0_opt_a'},
          {'id': 'b', 'label': 'un chien', 'audio_ref': 'q0_opt_b'},
        ],
        'correct': 'a',
        'shuffle': false,
      }).valueOrNull!;
      final speaker = _Recorder();
      final dispatched = <Object>[];
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => engine.buildView(
              context,
              EngineView(
                content: content,
                state: engine.initialize(content, const EngineSeed(1)),
                dispatch: dispatched.add,
                locale: const Locale('fr'),
                enabled: true,
              ),
            ),
          ),
          speaker: speaker,
        ),
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2));
      await tester.tap(find.text('un chien'));
      expect(dispatched, hasLength(1));
      expect(speaker.spoken, isEmpty);
      await tester.tap(find.byKey(const ValueKey('tile-speak-q0_opt_b')));
      expect(speaker.spoken, ['q0_opt_b']);
    });
  });
}
