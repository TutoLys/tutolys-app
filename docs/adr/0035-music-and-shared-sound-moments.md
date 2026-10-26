# ADR 0035: background music, and three sound moments shared by every engine

Date: 2026-10-25
Status: accepted. The right/retry sounds are pending Hafid's pick.

## Context

Réglages had a music toggle and an effects toggle with nothing behind
them: no music and no effects existed (ADR 0034's settings audit, app
`59d1215`). Hafid supplied audio in `Assets/Sounds`:
- six ElevenLabs "seamless loop" music tracks;
- four theme songs, in French and English, some in two styles;
- a win jingle (Pixabay);
- a voice saying "nooo".

He also asked that every engine share the same sounds for three moments:
a right answer at VALIDER, a wrong one at VALIDER, and the end-of-activity
screen.

## Decision

### Music

- **Two loops**, chosen by measurement, since no one in this session can
  listen: the two calmest by spectral centroid and onset rate (`…23_05_23`
  at ~1.4 kHz, `…23_08_11` at ~2.2 kHz), with no lead or trail silence.
  - Two others start with ~0.5 s of silence, so they would gap on every
    loop.
  - One has a large level jump at the seam.
  - Hafid can swap either by ear; the selection is a list in
    `app_sounds.dart`.
- **Made seamless, not trusted to be.** Each loop's last 250 ms is
  crossfaded into its first, at equal power. After decoding, the jump at
  the wrap is 0.003–0.004, below the tracks' normal sample-to-sample step.
- **Small:** mono Ogg Vorbis q1, normalised to -20 LUFS, about 220 KB per
  30 s loop (the originals are 720 KB stereo MP3). Vorbis because the
  Ogg container carries exact sample counts, so a decoded buffer has no
  encoder padding to click at the loop point, which MP3 and AAC both
  have.
- **Lazy on the web:** Flutter fetches an asset when it is first loaded,
  so music isn't part of the first download.
- **Where it plays:** the shell pages (`VillageShell` mounted), one track
  per launch. It stops inside an activity (`PlayScreen`), while the app is
  hidden, and when the toggle is off. It comes back when each of those
  ends (`MusicDirector`). The browser holds it until the first tap, as it
  does all audio.
- **Level:** master volume × 0.35 (`musicVolume`), ducked to 30% of that
  under narration, live with the slider.
- **Engine SDK:** `AudioRequest.loop`. `ChannelPlayer.play(loop:)` loops
  the Web Audio buffer source natively (seamless), and on native platforms
  uses audioplayers' `ReleaseMode.loop`. A looped clip that is paused
  resumes from its start.

### Three shared sound moments

- `SfxMoment.answerRight` / `answerRetry` play on `AnswerEvaluated`, once
  per VALIDER, from the play screen. That's the host of the shell (D3),
  so no engine plays its own and every runtime engine gets the same cue.
  `activityComplete` plays once, as the celebration opens.
- They play on the SFX channel, so the Réglages toggle and master volume
  apply.
- **Slots:** `activityComplete` is the win jingle (trailing silence
  trimmed, -16 LUFS, 40 KB). Right and retry are **silent placeholders**
  (null) until Hafid picks from Engines' candidates in
  `Assets/Sounds/generated/`. Filling a slot is one line in `sfxAssets`.
- **The "nooo" clip is left out on purpose.** The design's Decision Log
  rules out punishing feedback: no red, an amber "retry", no hearts or
  lives. A voice saying "nooo" to a six-year-old after a wrong answer
  contradicts that, so it isn't bundled anywhere.

### Theme songs: proposed, not built

They're bigger, have lyrics and want attention, so they should never
autoplay on an ordinary visit. Proposed, each in the app's language:
1. **First launch after pairing**, once, under the welcome screen ("Joue
   avec TutoLys !" / "Play with TutoLys!").
2. **Level-up celebration** (ADR 0033's levels): a short excerpt, at most
   once a day.
3. **À propos:** a "listen to our song" button, played only when tapped.

Hafid's call which, if any.

## Not done

- ~~macOS and iOS can't play Ogg.~~ Superseded: AAC everywhere, see the
  revision below.
- The legacy engine host doesn't emit `AnswerEvaluated`, so it gets only
  the end jingle. It serves nothing published.

## Revision 2026-10-25: AAC in .m4a everywhere, not Ogg

The scaling plan moves lesson audio to compressed files, and the format
has to play on every target. Ogg Vorbis doesn't: macOS, iOS, Safari and
Windows' Media Foundation can't decode it.

- **AAC-LC in an MP4 (.m4a) container** is the one format for the app's
  own sounds and, as agreed with Backend, for lesson audio. Every
  browser's `decodeAudioData` and every native platform decodes it.
  Linux needs GStreamer's libav plugin (`gstreamer1.0-libav`) on top of
  ADR 0013's GStreamer packages.
- **The loop stays seamless.** AAC's encoder priming is the usual reason
  to avoid it for loops, but ffmpeg writes an MP4 edit list, and Chrome
  honours it. Decoded in the browser, `village-1.m4a` is exactly
  1,428,000 samples, the same as its source, with no leading silence.
- Music is 64 kbps mono (about 245 KB per loop, slightly bigger than the
  Ogg). The jingle is 80 kbps (54 KB). The Ogg files are removed.

## Revision 2026-10-26: Hafid's picks, and the mascot's song

Hafid listened to every candidate (`Assets/Sounds/listen_all.html`) and
picked:

| moment | sound | file |
|---|---|---|
| right answer | `generated/right_b`, warm marimba | `sfx/answer-right.m4a` |
| wrong answer | `generated/wrong_a`, soft low "boop-boop" | `sfx/answer-retry.m4a` |
| end of lesson | `generated/hafid_win_matched`, his own jingle, levelled | `sfx/activity-complete.m4a` |
| background | loops #4 (`…T23_16_40`) and #6 (`…T23_35_26`) | `music/village-1/2.m4a` |
| Village mascot | `Joue avec TutoLys ! 2n style` / `Play with TutoLys!` | `songs/mascot-fr/en.m4a` |

The right and retry slots are no longer silent. The background loops
replace the two picked by measurement above. Loop #4 starts with 0.5 s
of silence; it's trimmed before the seam is made.

**`tools/sounds/build_app_sounds.py`** rebuilds every file from the
masters, so the next swap is one line there:
- AAC-LC .m4a, mono. Music 64 kbps, effects 80 kbps, songs 96 kbps.
- Effects and songs at **-19 LUFS** (the generated set's level, 4 dB
  under narration). Music at **-20 LUFS**, then 0.35 of master volume in
  the app. The old jingle was -16; it now matches the other effects.
- Loops: leading silence trimmed, then the last 250 ms folded into the
  first at equal power. The jump at the wrap is 0.014 and 0.008, under
  each track's own 99th-percentile sample step (0.035, 0.015). The
  container's length is exact (1,403,184 samples for loop #4); the
  ffmpeg command-line decoder appends 720 samples of encoder padding,
  but browsers honour the container.
- Songs are about 28 and 34 s, 340 and 415 KB. Fetched on first tap.

### The mascot's song

Tapping the fox in the Village scene (and on a phone, in the greeting
row) plays the song **in the app's language**, not a subject's.
- `MusicDirector.toggleSong`: a second tap while it plays **stops** it.
  Never two copies.
- The loop **pauses** while it sings, rather than ducking: two pieces of
  music in different keys clash. The loop comes back from its start when
  the song ends or is stopped.
- It plays on the `character` channel, so a voice read aloud takes over
  from it, and master volume applies. The music toggle doesn't silence
  it: the child asked for it.
- Opening an activity or hiding the app stops it.
- The fox is a button for screen readers ("Faire chanter TutoLys").
- This settles the "theme songs" proposal above for the Village only.
  First launch, level-up and À propos stay unbuilt.

### Clipping over Bluetooth

Hafid hears the first part of sounds cut off, on a plain HTML page too.
His output is a Bluetooth sink, which sleeps when idle. The keep-alive
(ADR 0043) already covers every app sound on the web: all channels
(narration, effects, music, the song) play through one shared
`AudioContext`. `AudioOutputKeepAlive.armOnFirstGesture` holds the output
awake from the first pointer-down for the whole session, and stops it
while the app is hidden. Native targets play through audioplayers and
have no keep-alive. A plain HTML page has none at all, which is why the
listening page clips.
