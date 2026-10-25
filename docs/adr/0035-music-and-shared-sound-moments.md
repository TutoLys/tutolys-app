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

- macOS and iOS: AVFoundation doesn't play Ogg Vorbis. When those
  targets exist, ship an AAC copy and trim its encoder priming. Linux
  (GStreamer) and the web (Chrome, Firefox, Edge) play it. Safari on the
  web is untested.
- The legacy engine host doesn't emit `AnswerEvaluated`, so it gets only
  the end jingle. It serves nothing published.
