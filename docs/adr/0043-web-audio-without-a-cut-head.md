# ADR 0043 — Read-aloud on web: a decoded buffer on a warm context

Date: 2026-10-25
Status: accepted

## Context

Hafid, on the :8080 web preview in a desktop browser: tapping the speaker
often cut the first word or two, by a different amount each time. On
"L'eau passe-t-elle à travers ? Range chaque objet." it sometimes started
at "…elle", sometimes at "à travers", and once played right.

Both audio paths, `ChannelAudioCoordinator` (the new runtime) and
`ExercisePromptAudio` (the legacy runner), played web audio the same way:
`stop()`, then `play(BytesSource(bytes))`.

Reading audioplayers 6.8.1 / audioplayers_web 5.3.0 shows why that loses
the head of a clip:
- `setSourceBytes` turns the bytes into a **data URI labelled
  `audio/mpeg`**, but Piper writes WAV, so the browser has to sniff it.
- "Prepared" fires on the element's `loadeddata`, which comes before it can
  play through. `play()` waits for that event, so waiting longer within
  audioplayers fixes nothing.
- The element is routed through a Web Audio context created lazily per
  player. That context can still be suspended or waking when the element
  starts, while the element's own clock runs.
- With the default release mode the element is torn down after every
  clip, so each replay starts cold again.

## Decision

In a browser, both paths now play through **`WebAudioChannelPlayer`**
(`engine_sdk/lib/src/audio/`), not audioplayers:

1. `ensureRunning()`: resume the **one shared `AudioContext`** if it is
   suspended, and once per page play a single silent frame so the output
   device is already open. The first play is always a tap, so the browser
   allows the context. It is never suspended or closed by us, so it stays
   warm.
2. `decode()`: decode the **whole clip** into memory (`decodeAudioData`,
   on a copy, because it detaches its input).
3. Only then `start()` an `AudioBufferSourceNode` at offset 0. Playback is
   sample-accurate from the first sample; there is no streaming and no
   buffering.

The details:
- **One player per channel**, as the coordinator already did, and one
  context for the whole app. Safari caps the number of contexts.
- **A tap during decoding replaces the clip.** A generation counter means
  a stale decode never starts, and `stop()` during decoding means nothing
  plays.
- **Pause and resume** continue from the paused offset, waking the context
  first. Volume follows the playing voice, for music ducking.
- **Native platforms are unchanged.** audioplayers plays from a temp file
  there, and the bug wasn't reported there.
  `platformChannelPlayer()` picks per platform.
- `ExercisePromptAudio` keeps its constructor (an optional `AudioPlayer`
  still means audioplayers) and gains `channel:`.
- The JS backend is behind a small `WebAudioBackend` interface. The
  ordering is unit-tested without a browser, and the JS file is selected by
  a `dart.library.js_interop` conditional import.
- `package:web` is now a direct dependency of engine_sdk, at the 1.1.1
  already in the tree through audioplayers_web. `pub get` was run in
  engine_sdk, engines_core, tutolys_motion, design_system and the app.

The Backend session is also adding about 250 ms of leading silence to
generated audio, as a cross-platform safety net. This fix doesn't rely on
it.

## Verification

- `engine_sdk/test/web_audio_player_test.dart` (8 tests, fake backend):
  - wake, decode, then start at 0, in that order;
  - a tap during decoding: the stale clip never starts;
  - stop during decoding: nothing plays;
  - a replay stops the old voice, then restarts from 0;
  - completion fires once, and not after a stop;
  - pause and resume at the right offset after waking;
  - volume follows the voice;
  - the legacy `ExercisePromptAudio` plays through the same player.
- **In a real browser** (this session's built-in Chromium pane): the
  **real JS backend**, compiled with `dart compile js` into a harness page
  and triggered by a real click. Five plays of a generated 600 ms WAV each
  ran **608 ms on the audio clock**, the full clip plus one 8 ms render
  quantum. Preparing took 17 ms on the first play, with the context cold,
  and 1–2 ms after.
- **Not reproduced here:** the cut itself. The same page, re-creating
  audioplayers' old path, showed a context already running at `play()`.
  The pane's page already had user activation, and the sandbox has no
  real output device to wake. So this verifies the new path plays the
  whole clip from the start; it can't show the old one failing.
  Confirming on Hafid's machine is the real test.
- `flutter build web --profile` compiles, and the bundle contains the new
  path. engine_sdk 147, engines_core 176 and app 481 tests pass; analyze is
  clean.

## Revision, same day: keep the output awake

The first fix shipped, and Hafid still heard the start clipped. His key
observation: "if I click once and it cuts it, and I click again before
the sentence ends, it always works just fine". So the decode/start path
was right. What loses the head is the **operating system's audio
output** waking from idle suspend. PipeWire and PulseAudio suspend the
sink after about 5 s of silence, and Bluetooth headsets do the same. The
first sound after that loses roughly 200–500 ms while the sink resumes,
and a replay while it's awake is fine. This session's sandbox has no real
sink, which is why the first fix couldn't reproduce or catch it.

The fix:

- **A keep-alive signal.** `WebAudioBackend.setKeepAlive(on)` runs a
  `ConstantSourceNode` through a `GainNode` at **0.0001** on the shared
  context while on. That's inaudible but not exactly 0, because some
  stacks treat true silence as idle and suspend anyway. It starts only
  once the context is running, so after a user gesture. If it's wanted
  before that, the next `ensureRunning()` starts it.
- **Only while an activity is on screen.** `AudioOutputKeepAlive` is
  reference-counted, and `AudioOutputKeepAliveScope` holds it while
  mounted. `ActivityShell`, the chrome of every activity on both the new
  runtime and the legacy runner, now wraps its tree in that scope.
  Entering an activity is a tap, so the context is resumed right then,
  and the output is awake before the first read-aloud.
- **Never in the background.** An `AppLifecycleListener` turns it off on
  `hidden`, `paused` and `detached`, and back on at `resumed`. When the
  last activity leaves, it stops.
- **Belt and braces.** When `ensureRunning()` had to wake the context (it
  now returns whether it did), the player waits **50 ms** before starting
  the clip. An already-awake context starts immediately.
- **Native is unaffected.** There the keep-alive has no backend and does
  nothing.

The Backend session's ~250 ms of leading silence in generated clips
stays as a third layer.

### Verification of the revision

- 5 more tests (13 in `web_audio_player_test.dart`):
  - the 50 ms pause happens only after a wake (49 ms: nothing yet; 51 ms:
    playing; awake: immediate);
  - keep-alive on while any holder is mounted, off when the last leaves,
    with an extra release harmless;
  - off while the app is hidden and back on at resumed;
  - the scope widget holds it exactly while mounted;
  - native does nothing.
- The real JS backend in the browser pane: keep-alive on, five 600 ms
  clips each played 608 ms on the audio clock, toggling off/on/off raised
  no errors, and the console was clean. The bundle from
  `flutter build web --profile` contains it.
- **Not provable here:** that the sink stays awake. That needs a real
  output device, so Hafid's machine is the test, after more than 5 s of
  quiet on a question.
- engine_sdk 152, engines_core 176. App: 498 pass on HEAD plus these
  changes. In the shared tree one `profile_screen_test` fails, and it
  belongs to the app session's uncommitted profile/progress work, not this.
