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

### Armed on the first gesture

Hafid may tap the speaker within seconds of opening a game, and on his
machine the sink takes longer than the Backend's 250 ms of leading
silence to wake. So `AudioOutputKeepAlive.armOnFirstGesture()`, called
once at startup, takes a hold from the **first pointer-down anywhere in
the app**. That pointer-down is a user gesture, so the browser lets the
context start. From then on the output stays awake while the app is
visible; it still turns off when the app is hidden. The activity-scoped
holds remain. On native it does nothing. One test: no hold before a tap,
a hold after the first tap with the context woken inside the gesture, and
only one hold however many taps follow. The startup call itself is one
line in `lib/main.dart`, which belongs to the app session.

### `?audiodebug=1`

The keep-alive build still clipped the first tap on Hafid's machine,
while a second tap during playback still worked. Rather than guess again,
the web audio path now traces itself when the page URL has
`?audiodebug=1` (`AudioDebug`; off otherwise, always off on native). Each
console line is timestamped from startup and covers:

- the context's state, clock, `baseLatency` and `outputLatency`, and
  whether the keep-alive node runs, at app start, at the first gesture,
  at each keep-alive change, before each clip's resume, and at its start;
- which path served the tap: `ChannelAudioCoordinator` → which
  `ChannelPlayer`, the legacy `ExercisePromptAudio`, or the audioplayers
  path (logged as not expected on web);
- each clip's byte length and **sha**, so an old cached pre-silence file
  is recognisable;
- the decoded clip's duration, the **RMS of its first 300 ms** and the
  **first audible millisecond**, which shows whether the lead silence and
  the whole head are really in the buffer.

Checked in a real browser on the built app: the trace prints app start,
first gesture, keep-alive on, and the context running with its
keep-alive node 2 ms after the tap.

Suspects checked while adding it:
- **No web path uses audioplayers or an `<audio>` element.** The shell's
  speaker goes through play_screen `_speak` → `ChannelAudioCoordinator` →
  `platformChannelPlayer()` → `WebAudioChannelPlayer`, and the legacy
  `ExercisePromptAudio` defaults to the same player.
- **Audio re-sync after regeneration:** `generate_audio` recomputes the
  exercise's `content_hash`, so the device does re-fetch the envelope and
  its clip. One gap: the clip **URL doesn't change**
  (`/media/exercise_audio/<id>/audio.wav`). If the browser's HTTP cache
  serves the old bytes, the sha check refuses them, silently, and the old
  cached clip keeps playing. The trace's sha and first-audible-ms will
  show it if so.

### Bluetooth: a keep-alive the codec can't drop

Hafid listens over **Bluetooth** (Chrome, Linux, PipeWire), and the
keep-alive build still lost "2–3 words" on the first tap. The first
keep-alive was a DC constant at gain 0.0001, about −80 dBFS or a few LSB
at 16-bit. A Bluetooth codec (SBC/AAC) can encode that as digital
silence, or the chain can filter it out as DC. Either way the headset
still powers its audio path down and loses the first ~0.5–1 s while it
resumes. The context and the sink were never the same question.

The changes:
- **The default signal is a 25 Hz sine at −60 dBFS**
  (`KeepAliveConfig.defaultToneHz` = 25,
  `KeepAliveConfig.defaultLevel` = 0.001). That's about 33 LSB at
  16-bit, far above any codec's silence threshold. It's a real AC signal,
  so no DC filter removes it, and it stays inaudible: at 25 Hz the ear's
  threshold is around 60 dB SPL, well above what −60 dBFS through
  headphones gives.
- **Variants, chosen from the page URL** so they can be compared on
  Hafid's headset without a rebuild:
  - `?audiokeepalive=tone` (the default), `noise` (low white noise,
    looped), `dc` (the old signal, to compare) or `off`;
  - `&audiolevel=0.002`, capped at 0.05, so a typo can never make it
    audible;
  - `&audiopreroll=300`: each clip's first sample is scheduled that many
    ms later, up to 2000, while the signal is already transmitting. A
    resume never gets it. The default is 0, because with the signal
    running the sink should already be awake.
- The `?audiodebug=1` trace now names the active variant
  (`keepAlive: tone @ 0.001 25Hz, pre-roll 0ms`).
- The pre-roll is scheduled on the context's clock
  (`start(currentTime + preRoll)`), so it is sample-accurate.

Verification:
- 3 more tests (16 in `web_audio_player_test.dart`): the defaults; URL
  variants with the level and pre-roll caps, and an unknown kind falling
  back to tone; the pre-roll on a clip's first start but not on a resume.
- In a real browser on the built app: `tone`, `noise` at 0.002 with a
  300 ms pre-roll, and `dc` each start with no console errors, and each is
  named in the trace.
- Whether the codec keeps the headset awake can only be shown on
  Bluetooth hardware, so it's Hafid's test.

### What Hafid's trace showed, and the threshold ladder

Hafid's `?audiodebug=1` trace, on Bluetooth with Chrome on Linux, ruled
out everything on the browser side:
- the new clip played, with the first audible sample at 277 ms, which is
  the lead silence, and sha `de0bb64fbfc5`;
- the context was running before and during playback;
- the keep-alive ran;
- the whole head was decoded, and playback started at offset 0.

(`outputLatency` read 0.168 s, which is a Bluetooth path.) So the browser
emits the whole clip, and the first words are lost downstream, in the
headset's or PipeWire's Bluetooth path. The likeliest explanation is a
noise gate or auto-volume soft start that still reads −60 dBFS at 25 Hz as
silence. "A second tap during playback works" fits a gate held open by
the first clip.

Changes:
- The trace's start line now says the pre-roll and the context time
  scheduled for the first sample. It previously logged only the offset,
  which read as if the pre-roll were ignored. It wasn't: in the browser
  harness, a 600 ms clip with a 400 ms pre-roll ended 1003 ms after
  `start()` on the audio clock.
- Pausing inside the pre-roll could compute a negative offset. That's
  fixed (a test caught it), and the clip's clock now starts at its first
  sample, not at `start()`.
- URL values tolerate trailing junk ("0.002%20(" from a pasted link
  broke one of Hafid's runs).
- **`&audiotonehz=` (15–200 Hz).** A headset's DSP may filter 25 Hz out
  before its gate sees it. The range is capped on purpose, because a
  "high inaudible" tone (17 kHz and up) is plainly audible to children.

The levels are being laddered on Hafid's headset to find its gate
threshold: 0.005, 0.01 and 0.02 at 25 Hz; 0.01 at 50 Hz; and an 800 ms
pre-roll. If one works, it becomes the web default, as a named constant
here. If nothing short of audible works, the fallback is honest rather
than clever: a longer lead silence for web only (600–800 ms), or a soft,
intentional chime before each read-aloud, so the gate opens on a sound
the child is meant to hear.
