import 'dart:async';
import 'dart:typed_data';

import 'package:engine_sdk/engine_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every Web Audio call in order, so the test can say what happened
/// before the first sample played.
class FakeBackend implements WebAudioBackend {
  final log = <String>[];
  final voices = <FakeVoice>[];
  double now = 0;

  /// Lets a test hold a decode open, to tap again meanwhile.
  Completer<void>? decodeGate;

  /// Whether the next [ensureRunning] finds the context asleep.
  bool asleep = false;
  final keepAlive = <bool>[];

  @override
  Future<bool> ensureRunning() async {
    log.add('running');
    final woke = asleep;
    asleep = false;
    return woke;
  }

  @override
  void setKeepAlive(bool on) => keepAlive.add(on);

  @override
  Map<String, Object?> debugState() => {'state': 'running'};

  @override
  Map<String, Object?> debugBuffer(Object buffer) => {'durationMs': 0};

  @override
  Future<Object> decode(Uint8List bytes) async {
    log.add('decode ${bytes.length}');
    await decodeGate?.future;
    return 'buffer-${bytes.length}';
  }

  @override
  double get currentTime => now;

  KeepAliveConfig config = const KeepAliveConfig();
  final delays = <double>[];

  @override
  KeepAliveConfig get keepAliveConfig => config;

  @override
  WebVoice start(
    Object buffer, {
    double offsetSeconds = 0,
    double volume = 1,
    double delaySeconds = 0,
    bool loop = false,
  }) {
    log.add('start $buffer @$offsetSeconds${loop ? ' loop' : ''}');
    delays.add(delaySeconds);
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
  testWidgets('a context that had to wake gets 50 ms before the first sample', (
    tester,
  ) async {
    final b = FakeBackend()..asleep = true;
    final p = WebAudioChannelPlayer(b);
    final playing = p.play(bytes(4), cacheKey: 'q');
    await tester.pump(const Duration(milliseconds: 49));
    expect(b.voices, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    await playing;
    expect(b.voices, hasLength(1));
    // Already awake: no pause.
    await p.play(bytes(4), cacheKey: 'q');
    expect(b.voices, hasLength(2));
  });

  group('KeepAliveConfig', () {
    test('default: a 25 Hz tone at -60 dBFS, no pre-roll', () {
      final c = KeepAliveConfig.fromQuery(const {});
      expect(c.kind, KeepAliveKind.tone);
      expect(c.level, 0.001);
      expect(c.toneHz, 25);
      expect(c.preRollMs, 0);
    });

    test('the page URL picks a variant; levels and pre-roll are capped', () {
      final c = KeepAliveConfig.fromQuery(const {
        'audiokeepalive': 'noise',
        'audiolevel': '0.5',
        'audiopreroll': '99999',
      });
      expect(c.kind, KeepAliveKind.noise);
      expect(c.level, 0.05, reason: 'never loud enough to hear by mistake');
      expect(c.preRollMs, 2000);
      expect(
        KeepAliveConfig.fromQuery(const {'audiokeepalive': 'off'}).kind,
        KeepAliveKind.off,
      );
      expect(
        KeepAliveConfig.fromQuery(const {'audiokeepalive': 'banana'}).kind,
        KeepAliveKind.tone,
      );
    });

    test('junk after a value in a pasted link is ignored', () {
      final c = KeepAliveConfig.fromQuery(const {
        'audiokeepalive': 'noise (2)',
        'audiolevel': '0.002 (',
        'audiopreroll': '400ms',
        'audiotonehz': '50Hz',
      });
      expect(c.kind, KeepAliveKind.noise);
      expect(c.level, 0.002);
      expect(c.preRollMs, 400);
      expect(c.toneHz, 50);
    });

    test('the tone stays low: never a high whine a child would hear', () {
      expect(
        KeepAliveConfig.fromQuery(const {'audiotonehz': '18000'}).toneHz,
        200,
      );
    });

    test(
      'pausing during the pre-roll resumes from the start of the clip',
      () async {
        final b = FakeBackend()..config = const KeepAliveConfig(preRollMs: 400);
        final p = WebAudioChannelPlayer(b);
        await p.play(bytes(4), cacheKey: 'q');
        b.now = 0.2; // still inside the pre-roll
        await p.pause();
        await p.resume();
        expect(b.log.last, 'start buffer-4 @0.0');
      },
    );

    test('a pre-roll delays a clip\'s first sample, never a resume', () async {
      final b = FakeBackend()..config = const KeepAliveConfig(preRollMs: 300);
      final p = WebAudioChannelPlayer(b);
      await p.play(bytes(4), cacheKey: 'q');
      b.now = 1;
      await p.pause();
      await p.resume();
      expect(b.delays, [0.3, 0]);
    });
  });

  group('AudioOutputKeepAlive', () {
    testWidgets('on while any activity is mounted, off when the last leaves', (
      tester,
    ) async {
      final b = FakeBackend();
      final k = AudioOutputKeepAlive(b);
      k.acquire();
      k.acquire();
      expect(b.keepAlive.last, isTrue);
      expect(b.log, contains('running'), reason: 'woken on entry');
      k.release();
      expect(b.keepAlive.last, isTrue, reason: 'one holder left');
      k.release();
      expect(b.keepAlive.last, isFalse);
      k.release();
      expect(k.active, isFalse, reason: 'an extra release is harmless');
    });

    testWidgets('off while the app is hidden, back on when it returns', (
      tester,
    ) async {
      final b = FakeBackend();
      final k = AudioOutputKeepAlive(b)..acquire();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(b.keepAlive.last, isFalse, reason: 'never runs in the background');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(b.keepAlive.last, isTrue);
      k.release();
    });

    testWidgets('the scope widget holds it exactly while mounted', (
      tester,
    ) async {
      final b = FakeBackend();
      final k = AudioOutputKeepAlive(b);
      await tester.pumpWidget(
        AudioOutputKeepAliveScope(keepAlive: k, child: const SizedBox()),
      );
      expect(k.active, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(k.active, isFalse);
      expect(b.keepAlive.last, isFalse);
    });

    testWidgets('armed at startup, it holds from the first tap anywhere', (
      tester,
    ) async {
      final b = FakeBackend();
      final k = AudioOutputKeepAlive(b)..armOnFirstGesture();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(),
        ),
      );
      expect(k.active, isFalse, reason: 'no gesture yet');
      await tester.tapAt(const Offset(10, 10));
      expect(k.active, isTrue);
      expect(b.log, contains('running'), reason: 'woken inside the gesture');
      await tester.tapAt(const Offset(10, 10));
      k.release();
      expect(k.active, isFalse, reason: 'one hold, taken once');
    });

    test('the trace is off unless the page asked for it', () {
      expect(AudioDebug.enabled, isFalse);
      AudioDebug.log('not printed');
    });

    test('native: no backend, nothing happens', () {
      final k = AudioOutputKeepAlive(null)..acquire();
      expect(k.active, isTrue);
      k.release();
    });
  });

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

  test(
    'a looping clip is started looped, and resumes from its start',
    () async {
      final backend = FakeBackend();
      final p = WebAudioChannelPlayer(backend);
      await p.play(bytes(4), cacheKey: 'music', loop: true);
      expect(backend.log.last, endsWith('@0.0 loop'));
      await p.pause();
      await p.resume();
      expect(backend.log.last, endsWith('@0.0 loop'));
    },
  );
}
