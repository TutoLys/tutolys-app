# ADR 0013 — Read-aloud audio, multi-question exercises, XP display

Date: 2026-10-24
Status: accepted

## Context

The app-side half of this round's feature (backend: ADR 0021/0022/0023
in tutolys-backend, ADR 0009 in tutolys-telemetry): a grade-1/2 reader
needs the question read aloud, an exercise can now hold several
questions, and XP exists. Three pieces, all touching
`ExerciseRunner`/`ContentSync`, built together.

## Decisions

**Multi-question sequencing is composition, not a rewritten state
machine.** `ExerciseRunner` detects `config.questions[]` and delegates to
a new internal `_MultiQuestionSequencer`, which renders one child
`ExerciseRunner` at a time — keyed by question index — built from a
synthetic single-question envelope (the outer exercise's shared fields
plus that question's own `prompt`/`config`). The single-question
`ExerciseRunner` itself is completely unmodified for this: each question
gets a fresh `State`, so its existing start/finish/abandon-on-dispose
telemetry lifecycle applies per question for free, with zero new
bookkeeping. Telemetry sees exactly what it always has — one
`exercise_start`/`exercise_complete` pair per question, each with its
own `exercise_run_id`, all sharing the outer `exercise_id` — which is
also what lets the backend's XP ledger (ADR 0022) and mastery/streak
both stay untouched.

**`ExerciseResult` grew a `questionResults` field**, empty for a
single-question run, the real per-question breakdown for a
multi-question one — summed into the existing `attempts`/`correct`/
`elapsedMs` totals so a host that only wants the aggregate (recording
"played today") never needs to look at the breakdown, and one that does
(XP estimation) can.

**Audio is an injected interface (`AudioResolver`), same shape
`EventOutbox` already established** — `ExerciseRunner` never touches the
app's database or network directly; the app supplies a drift-backed
`DriftAudioResolver`, tests supply `InMemoryAudioResolver`. Resolution
retries on a later rebuild if it returns `null` (not synced yet) rather
than being marked "handled" forever on a miss — a real bug caught by a
test before it shipped: the first version only skipped retrying when
resolution *succeeded* in the author's head, but the code as written
treated any attempt, successful or not, as final.

**Playback splits by platform, and that split has to happen at the
import level, not behind a runtime `kIsWeb` check.** `dart:io` does not
compile for a web target at all — same class of problem ADR 0002/0003
already hit with drift's native backend. `audio_file_io.dart` (native,
writes a deterministic temp file, plays via `DeviceFileSource`) and
`audio_file_stub.dart` (web, throws — never reached) are selected by a
conditional import (`import 'audio_file_stub.dart' if (dart.library.io)
'audio_file_io.dart'`), with `kIsWeb` only deciding which of
`BytesSource` (web) or the platform file source (native) to use at
runtime. `DeviceFileSource` over `BytesSource` for native specifically
because `audioplayers` itself documents `BytesSource` as "only some
platforms" — an acknowledged gap this sidesteps rather than hopes past.

**Audio download/verification lives in `ContentSync`, not a separate
sync path.** After committing newly-verified exercise envelopes, each
one's `assets[]` (`{ref, url, sha256}`) is walked: an already-cached
asset with a matching hash is skipped, a fetch failure or offline is a
silent no-op (never fatal — the text prompt still works), and a hash
mismatch is refused with the exact same reasoning `_applyManifest`
already gives a tampered exercise. Stored in a new `AudioCacheTable`
(blob column, composite `exerciseId`+`ref` primary key) — not a column
on the exercise cache row, since one exercise can have several
questions' worth of audio that shouldn't all need re-downloading just
because one changed.

**XP shown two ways, deliberately different in authority.** The real
total (`ProgressState.totalXp`, from `/me/progress`) is a profile-screen
stat tile, always real, never null-means-unknown the way streak/freezes
are — the backend reads it from its own local ledger, not live
telemetry. The "+N XP!" moment right after finishing an exercise is a
*client-side estimate* (`xp_estimate.dart`, a hardcoded mirror of the
backend's formula) shown immediately via a `SnackBar`, because
`manage.py award_xp` hasn't run yet at that instant — same reasoning
`StreakLocal`'s offline estimate already established for showing a
provisional number ahead of the authoritative one syncing in later.

## Verified

Engine SDK: 6 new tests for the read-aloud button (no-audio-ref hides
it, disabled until resolved, enabled and tappable once resolved, a
failed/missing platform audio channel doesn't crash — `audioplayers`
genuinely can't play anything in this test environment, which is exactly
what `ExercisePromptAudio.play`'s own swallow-and-log design is for) and
7 new tests for multi-question sequencing (renders question one, not
two, until it finishes; each question gets its own `exercise_run_id` and
telemetry pair; the host's `onFinished` fires exactly once with
aggregated totals; a single-question run's `questionResults` stays
empty). 39 total in this package (was 33).

App: 6 new tests in `content_sync_test.dart` (downloads and caches an
asset, refuses a bad checksum same as a tampered exercise, never calls
`fetchAudio` when there are no assets, doesn't re-download an
already-cached unchanged asset, an offline/failed audio fetch doesn't
fail the exercise sync itself, a multi-question exercise's several
assets all get cached under their own refs) and 5 new tests in
`xp_estimate_test.dart` pinning the formula against the backend's own
(10 per question, +5 first-try-perfect, a three-question first-try-
perfect run earning exactly 3× a one-question one) — the direct test of
"XP adapts to question count." 2 new tests in `profile_screen_test.dart`
for the XP tile. 164 total app tests (was 151). `flutter analyze`: 0
issues across both the app and `engine_sdk`.

Live: `flutter build web` compiles clean (confirms the `dart.library.io`
conditional import resolves correctly for web — no `dart:io` compile
error), served and loaded with zero new console errors beyond the
already-documented sandbox WebGL-fallback warning. The backend half of
this feature (real multi-question content, real Piper-generated audio,
real XP awards) was already live-verified end to end against a real
`dev-stack` in tutolys-backend's own ADRs — this app consumes that same
real content/audio/XP through the code paths described above, exercised
here via realistic fakes (`FakeContentServer`, mirroring the real
backend's exact response shapes) rather than a second live run against
the same server, since the backend side already proved the wire
contract for real.

`flutter build linux` could not be completed in this sandbox: it failed
at the CMake configure step because `audioplayers_linux` requires
`gstreamer-1.0`/`gstreamer-app-1.0`/`gstreamer-audio-1.0` dev packages,
which aren't installed here, and this sandbox has no interactive sudo to
install them. This is a **real, new build-time system dependency** this
feature introduces for the Linux desktop target — not previously needed
by anything else in this app — named honestly rather than silently
assumed to work. Added to `CLAUDE.md`'s Gotchas list.

## Not done

No visual/audible confirmation that a speaker icon actually renders or
that sound actually plays — this sandbox's browser has no compositor
(the same limitation every Flutter web check this session has hit,
ADR 0003/0008/0010/0011/0012) and the Linux build couldn't complete at
all. The widget/unit tests above are the real verification; a real
device/browser check is worth doing before this ships to a kid.
