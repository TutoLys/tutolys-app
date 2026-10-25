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
