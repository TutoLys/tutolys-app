# ADR 0102: The diagnostic in the app (« Partie découverte »)

- Status: accepted (plan); building behind a flag
- Date: 2026-10-31
- Source: `Platforms/PLAN_DIAGNOSTIC.md` §2, §3, §8 (Hafid's go, relayed by
  the Manager)

## Context

A kid who joins mid-year starts at their nominal grade, which is often wrong
per strand. The diagnostic finds a level per strand and feeds the Carte's
starting node and the review channel. The backend owns the spec and the
authoritative estimate; the app runs the same estimator on the device,
offline, so a kid can play it with no network (D6: grading stays on the
device).

## Decisions

1. **One flag, off by default.** `diagnosticEnabledProvider` reads the
   backend's `DIAGNOSTIC_ENABLED` (via the item-pool endpoint answering at
   all) **and** a build define `DIAGNOSTIC=true` for local work. With the flag
   off, nothing is drawn: no offer, no Réglages entry, no route.

2. **A pure-Dart package, `packages/diagnostic_estimator`.** No Flutter, no
   I/O: Rasch 1PL, EAP on a fixed grid, the start-point rule (nominal − 1 +
   months elapsed ÷ 10), the range (nominal − 3 … nominal + 1), item
   selection by maximum information near the estimate, the stop rules (SE <
   0.5 or 8 items per strand, ~40 per subject), bands (behind ≥ 0.75 below
   expected, at level, ahead), per-leaf P(mastered). **It is written against
   `tutolys-backend/docs/diagnostic-spec.md` and must pass that repo's test
   vectors verbatim**; the fixtures are copied into the package's `test/`
   with their source path and sha256, and a test fails if the two drift.
   Not started until the spec lands: guessing the numbers would make the two
   sides disagree by construction.

3. **The flow reuses the activity runtime, with the outcome hidden.** Each
   series (5–10 items) is one `ActivitySessionController` with
   `maxAttempts: 1`. During the diagnostic the banner is always the neutral
   « On continue ! », whatever the answer, and there is no hint. That needs
   one switch on `LearningActivityView` (`revealOutcome: false`), which is in
   `engines_core`, **Engines' area: requested from them, not edited here.**
   Until it lands the flow runs on a fake host in tests only.

4. **Screens**, all under `lib/features/diagnostic/`:
   - **Intro**: the fox, « Montre-moi ce que tu sais déjà ! », one button,
     and « Plus tard ». Never the words *test*, *examen* or *note*.
   - **Series**: progress as a path of steps, not a score. At the end of a
     series: the existing celebration, with effort XP only (the backend
     awards it; the app shows what the server credits, never a local
     per-question XP).
   - **Pause / resume**: closing at any point keeps the session. State lives
     per kid in `app_state` (`diagnostic_session`): subject, responses so
     far, item ids served, the pool's version. Resume picks up at the next
     item; partial results count.
   - **Results for the kid**: strengths only, encouraging, no numbers, no
     grade levels, no "behind". The adult report is the portal's job.

5. **Offer after pairing.** A new pairing shows the intro as an offer,
   skippable. Between November and June it is marked recommended (« On
   commence par une partie découverte ? »); in September–October it is
   offered more quietly. Declining is remembered per kid and the offer
   moves to Réglages › Ma progression.

6. **Applying results.** The backend writes mastery seeds (`source =
   diagnostic`, low weight), starting nodes and review entries; the app
   reads them through the existing `/me/progress` and curriculum payloads.
   Locally, until the server answers, the device's own estimate sets the
   Carte focus (the starting node) and nothing else: no local mastery, no
   unlocking. That keeps the server authoritative (§3) and the monotonic
   rule intact.

7. **Telemetry.** Every event from a diagnostic series carries
   `context: "diagnostic"` and the diagnostic session id. They never count
   toward lesson completion (`nodeProgressProvider`), quests, `HomeStats`,
   the local streak, or XP shown per question.

8. **Offline.** The pool for (subject, grade band) downloads when the
   diagnostic starts, with its audio, and is kept until the session is
   submitted. Submission goes through the outbox, so a session played
   offline is submitted when the network returns.

## Dependencies

- Backend: `docs/diagnostic-spec.md` + fixtures, the pool endpoint, the
  submission endpoint, result fields on `/me/progress`. The Manager pings
  when the spec exists.
- Engines: `revealOutcome: false` on `LearningActivityView`; the item bank.
- Telemetry: accepting `context: diagnostic`.

## Consequences

- Nothing ships visibly until the flag turns on.
- The estimator package is blocked on the spec; the screens, resume state,
  offer, flag and telemetry tagging are not, and are built first, tested
  against a fake pool and a fake estimator interface
  (`DiagnosticEstimator`), which the real package then implements.
