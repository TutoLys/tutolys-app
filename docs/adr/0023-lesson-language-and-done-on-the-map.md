# ADR 0023 — Lessons in the chosen language, and done on the map

Date: 2026-10-25
Status: accepted

## Context

Two work orders arrived together:

- **Backend** (`Platforms/APP_WORKORDER_LESSON_LANGUAGE.md`, backend ADR
  0026). The manifest can now serve a lesson in a requested language
  (`?locale=`), falling back to the language a lesson was authored in when
  it has no version in the requested one. Each entry reports its own
  `locale`, and `manifest_hash` folds locale in. The app sent no locale, so
  an English-mode kid got an English shell around a French question.
- **Engine games** (ADR 0022). A finished exercise should show as done on
  the Carte, and the end-of-exercise celebration should show quest
  progress, through the hooks that ADR left: `nodeProgressProvider` and
  `celebrationRowsProvider`.

The work order asked one question first: who is English mode for? Hafid
answered (2026-10-25):

> Only fr and eng should stay in their own languages. […] the rest should
> adapt to the language chosen in the app. […] it does not make sense to
> convert an fr exo to eng or eng to fr. If we need translation exercises,
> it'll be done at the lesson config side.

## Decision

### Which language a subject is taught in

`lib/features/path/subject_language.dart` holds the rule in one place:

- **Français and English are language subjects.** They are always taught
  in their own language, whatever the app is set to: `FR` asks for
  `fr-CA`, `EN` for `en-CA`. A translation exercise (an English sentence,
  French words) is authored that way in the lesson content, and the app
  presents it exactly as authored.
- **Every other subject** (mathématique, science, univers social, CCQ)
  follows the app's language.
- The app never converts a lesson. A translation is a separate authored
  exercise on the same node and rank (backend ADR 0026).

The same rule decides skill names on the Carte. Where a subject asks for
English and a leaf has no `label_en`, the French name shows. That is a
content gap (455 of 526 grade-1 leaves have no English name, measured live
on 2026-10-25), not a reason to hide a node or to machine-translate.

### Sync

- `ContentApi.fetchManifest` sends `locale`; `ContentSync.sync` passes it.
  `PathController` asks for `contentLocaleFor(subject, appLocale)`.
- **Re-sync on a language change**, but only when it changes what the
  current subject asks for. Français and English need none.
- **The shared cache keeps both languages.** Siblings on one device share
  the content cache (ADR 0014) and may have chosen different languages,
  and one kid can switch back. Withdrawing every cached exercise absent
  from this manifest would delete the French version of a lesson because
  this manifest asked for English, and the two kids would re-download each
  other's versions forever. A cached exercise is removed only when its
  lesson (node + rank) is wanted in no language at all, or is wanted in its
  own language under a newer id.
- **Picking a version** (`pickLessonsByNode`): per lesson, the version in
  the asked language, else French, else whatever was authored; then the
  first rank per node, as before.

### A lesson in the other language is marked

When the backend falls back (an English-mode maths path where a lesson
exists only in French), the node wears a small muted **`FR`** tag at the
corner of its orb, and the active card repeats it beside its status.
Screen readers hear "Leçon en français" / "Lesson in French". Quiet, but
never silent and never hidden, as the work order asked. The design has no
pattern for this; this one is ours and can change.

Read-aloud needs nothing here: audio is generated per exercise in the
exercise's own language, so a French fallback lesson speaks French.

### Done on the map

- New `PathNodeState.completed`, from `nodeProgressProvider` (written by
  the play screen after every completed exercise). Drawn as the mastered
  check in blue, not gold: done here, not yet mastered on the server.
  Mastery outranks it, it stays tappable for a replay, and a node with
  nothing synced to play stays locked.
- The fox and the Continuer card move to the first playable node that is
  neither mastered nor completed.
- Completion counts toward no percentage. Village and Progrès stay on
  server mastery, so nothing is counted twice.

### Quest rows on the celebration

`questCelebrationRows` (`lib/features/quests/quest_celebration.dart`) is
installed over `celebrationRowsProvider` in `main.dart`:

- Real quests only, from `buildDailyQuests`, worded in the app's language.
- The local quests read `HomeStats`, which the play screen writes before
  the celebration builds. The value is forgotten whenever no celebration
  listens, and refreshed with `nodeProgressProvider`, so every number
  includes the exercise just finished.
- The daily challenge is the server's and lags until telemetry is
  uploaded, so it shows only once already done, never as a stale number.
- `Strings.playXpEarned` is removed: the celebration is the XP moment.

## Consequences

- A kid who switches the app to English gets maths, science, univers
  social and CCQ in English as soon as English lessons exist, and French
  ones tagged `FR` until then. Français and English lessons never move.
- Authoring cost follows from the decision: each non-language subject
  needs an English version per lesson to be fully English. Every lesson
  authored French-only today is shown tagged in English mode, not hidden.
- Not done here, and not ours: the play screen's own header could repeat
  the language tag (it is the engine session's file), and the question of
  whether the `EN` tree should be ESL or English Language Arts stays open
  (backend ADR 0025).
