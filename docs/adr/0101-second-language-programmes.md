# ADR 0101 — The kid's subjects come from the backend: ESL and FLS

Date: 2026-10-30
Status: accepted. Answers `Platforms/APP_WORKORDER_SECOND_LANGUAGES.md`
(backend `c82da89`, `2661d89`). Extends ADR 0023.

## Context

The PFEQ is symmetric. A French-language school teaches Français (FR) and
Anglais, langue seconde (ESL). An English-language school teaches English
Language Arts (EN) and Français, langue seconde (FLS). One field on the
kid, `school_language`, picks the pair. A child gets one pair, never
both.

Before this, four places each held their own subject list, and the list
was `MATH, FR, EN, SCI, SOC, CCQ`: every kid was shown both languages of
instruction and neither second language. The backend now serves the
kid's list with the curriculum tree and the manifest:

```json
{ "subjects": ["MATH", "FR", "SCI", "SOC", "CCQ", "ESL"],
  "school_language_required": true }
```

## Decision

### One list, from the backend

- `Programme` (`data/local_db/programme_store.dart`) is that payload.
  It's read from every curriculum tree response
  (`CurriculumTreeFetched.programme`, `CurriculumSyncReport.programme`).
  The Carte syncs a tree on every load and its background prefetch syncs
  one per subject, so the list stays fresh.
- `programmeProvider` holds the active kid's list. `ProgrammeStore` keeps
  it per kid in `app_state`, so the Village opens right offline and
  siblings at schools of different languages each get their own. An
  answer that lands after a kid switch is stored for the kid it was asked
  for and shown only if that kid is still playing.
- Before any answer it's `frenchProgramme`, the backend's own fallback.
- `programmeSubjectsProvider` replaces `pathSubjects` and `realSubjects`.
  It drives the subject pills (Carte and Progrès), the background
  prefetch, the Village, Profil's subject rows and the "all subjects"
  achievements. The next subject the backend adds gets a pill and a
  Carte with no app change, under a generic building (`subjectArtFallback`)
  until it has art.
- If an adult changes the school's language while the Carte shows a
  subject that left the programme, the Carte moves to Math.
- A tree request for the other programme's subject is a 400 from the
  backend. Driving from the list means the app never makes one.

### The Village keeps the design's shape

There are six plots, not seven subjects. The language of instruction
stands where the design put Français (FR or EN). The second language
stands where it put Anglais (ESL or FLS). So every child sees the
design's village: six buildings plus the gallery. A code with no plot,
such as a future subject, has no building but keeps its pill.

ESL wears the Anglais building and FLS the Français one. A child knows
the subject by its language's name: « Anglais » at a French school,
« Français » at an English one. Since a kid never has both pairs, the
names never collide. Distinct second-language art is optional; the brief
is `docs/design/SECOND_LANGUAGES.md`.

### Honest empty state

ESL and FLS have no lessons yet. `subjectsWithoutLessonsProvider` lists a
kid's subjects that synced (`ContentFreshness`) and have no manifest
entry at their grade. Their building's pill says « Bientôt », not
« À découvrir » or « 0 % », both on the scene and on the phone grid. The
building stays in colour and opens its Carte, which already says lessons
are coming (`CarteGap.noLessonsYet`). A subject that never synced isn't
called empty. The prefetch now marks each subject synced, so this works
without visiting every Carte.

### Lesson language

ESL and FLS join FR and EN in `languageSubjects`. An ESL lesson is asked
for in English and an FLS one in French, whatever the app is set to. They
are never tagged "FR" as a fallback. The chrome still follows the app.

### The school's language is asked of an adult

The child is never asked. When `school_language_required` is true, Zone
parent shows a line asking an adult to set the school's language on the
website, and saying the French programme is followed meanwhile. The
field is read-only on the device; only the portal sets it (backend ADR
0102). The pairing prompt doesn't ask, because the device can't save the
answer.

## Consequences

- CCQ, ESL and FLS reach every subject list without app changes.
- The "all subjects" achievements count the kid's own programme. A
  subject with no lessons still blocks them, as CCQ already did; worth
  revisiting once content lands.
- `learning_areas.dart` has no map for ESL or FLS. Their Carte would
  show one untitled stretch, but the backend's strand labels come with
  the tree, so nothing is needed today.
- Tests: `test/second_languages_test.dart`, plus `village_scene_test`
  rewritten for both programmes.
