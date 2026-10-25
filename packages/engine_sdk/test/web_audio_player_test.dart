import 'dart:async';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every Web Audio call in order, so the test can say what happened
/// before the first sample played.
class FakeBackend implements WebAudioBackend {
  final log = <String>[];
  final voices = <FakeVoice>[];
  double now = 0;

  /// Lets a test hold a decode open, to tap again meanwhile.
  Completer<void>? decodeGate;

  @override
  Future<void> ensureRunning() async => log.add('running');

  @override
  Future<Object> decode(Uint8List bytes) async {
    log.add('decode ${bytes.length}');
    await decodeGate?.future;
    return 'buffer-${bytes.length}';
  }

  @override
  double get currentTime => now;

  @override
  WebVoice start(Object buffer, {double offsetSeconds = 0, double volume = 1}) {
    log.add('start $buffer @$offsetSeconds');
    final v = FakeVoice(volume);
    voices.add(v);
    return v;
  }
}

class FakeVoice implements WebVoice {
  FakeVoice(this.volume);
  final _ended = StreamController<void>.broadcast();
  double volume;
  bool stopped = false;

  void finish() => _ended.add(null);

  @override
  Stream<void> get ended => _ended.stream;

  @override
  void stop() => stopped = true;
}

Uint8List bytes(int n) => Uint8List(n);

void main() {
  test(
    'wakes the context and decodes the whole clip before it starts, from 0',
    () async {
      final b = FakeBackend();
      final p = WebAudioChannelPlayer(b);
      await p.play(bytes(4), cacheKey: 'q');
      expect(b.log, ['running', 'decode 4', 'start buffer-4 @0.0']);
    },
  );

  test(
    'a tap during decoding replaces the clip: the stale one never starts',
    () async {
      final b = FakeBackend()..decodeGate = Completer();
      final p = WebAudioChannelPlayer(b);
      final first = p.play(bytes(1), cacheKey: 'a');
      await pumpEventQueue();
      b.decodeGate = null;
      await p.play(bytes(2), cacheKey: 'b');
      // Let the first decode finish late.
      final gate = Completer<void>()..complete();
      b.decodeGate = gate;
      await first.timeout(const Duration(seconds: 1), onTimeout: () {});
      expect(b.log.where((l) => l.startsWith('start')), [
        'start buffer-2 @0.0',
      ]);
    },
  );

  test('stop during decoding means nothing plays', () async {
    final b = FakeBackend()..decodeGate = Completer();
    final p = WebAudioChannelPlayer(b);
    final playing = p.play(bytes(3), cacheKey: 'q');
    await pumpEventQueue();
    await p.stop();
    b.decodeGate!.complete();
    await playing;
    expect(b.voices, isEmpty);
  });

  test(
    'a replay stops the clip still playing, then starts again from 0',
    () async {
      final b = FakeBackend();
      final p = WebAudioChannelPlayer(b);
      await p.play(bytes(5), cacheKey: 'q');
      await p.play(bytes(5), cacheKey: 'q');
      expect(b.voices.first.stopped, isTrue);
      expect(b.log.last, 'start buffer-5 @0.0');
    },
  );

  test('completion is reported once, and not after a stop', () async {
    final b = FakeBackend();
    final p = WebAudioChannelPlayer(b);
    var completions = 0;
    p.onComplete.listen((_) => completions++);
    await p.play(bytes(1), cacheKey: 'q');
    b.voices.single.finish();
    await pumpEventQueue();
    expect(completions, 1);
    await p.play(bytes(1), cacheKey: 'q');
    await p.stop();
    b.voices.last.finish();
    await pumpEventQueue();
    expect(completions, 1, reason: 'a stopped clip does not complete');
  });

  test(
    'pause then resume continues where it stopped, after waking the context',
    () async {
      final b = FakeBackend();
      final p = WebAudioChannelPlayer(b);
      await p.play(bytes(8), cacheKey: 'q');
      b.now = 1.5;
      await p.pause();
      expect(b.voices.single.stopped, isTrue);
      b.log.clear();
      await p.resume();
      expect(b.log, ['running', 'start buffer-8 @1.5']);
    },
  );

  test('volume follows to the playing voice and the next one', () async {
    final b = FakeBackend();
    final p = WebAudioChannelPlayer(b);
    await p.play(bytes(1), cacheKey: 'q');
    await p.setVolume(0.3);
    expect(b.voices.single.volume, 0.3);
    await p.play(bytes(1), cacheKey: 'q');
    expect(b.voices.last.volume, 0.3);
  });

  test(
    'the legacy runner\'s ExercisePromptAudio plays through the same player',
    () async {
      final b = FakeBackend();
      final audio = ExercisePromptAudio(channel: WebAudioChannelPlayer(b));
      await audio.play(bytes(6), cacheKey: 'q');
      expect(b.log, ['running', 'decode 6', 'start buffer-6 @0.0']);
      await audio.stop();
      expect(b.voices.single.stopped, isTrue);
    },
  );
}
