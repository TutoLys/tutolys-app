# ADR 0119: phrase_lab, L'atelier des phrases (slice 1: group and test)

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` §2.2 #1, step 1 of §2.3.
Hafid's go on 2026-11-03. The backend schema is backend ADR 0211.

## Context
101 français leaves for grades 2–6 ask for **groups of words** and their
functions: sujet, prédicat, complément de phrase, GN, GV, CD, CI and so on.
Another 80 ask for transformations, and 50 for agreement chains. `find_it`
taps one word, and nothing tapped a group. The PFEQ itself finds functions
by **manipulation**: a CP can be deleted and moved, and a sujet is replaced
by « il » or framed by « C'est… qui ».

## Decisions
1. **One sentence as tappable tokens.** Punctuation is its own token, so it
   can't end up in a bracket by accident.
2. **Task `group`:**
   - Tap a group's first and last word to bracket it; the taps can come in
     either order. A bracket can't overlap another.
   - Name it from the tray. With one label in the tray, the bracket names
     itself.
   - Tapping a bracket selects it; tapping it again undoes it.
   - VALIDER waits for one named bracket per asked group (« Groupes : n /
     m »).
   - Each group is graded on its exact words and its name, with partial
     credit. A right group locks. A wrong one comes off, and the same name
     can't go back on the same words.
3. **Task `test`:**
   - The group under test is framed. Each of 1–3 tests is a button; running
     it shows the lesson's changed sentence (a `reveal`, ADR 0118).
   - The child says « Ça marche » or « Ça ne marche pas ». They can't judge
     a test they haven't run.
   - An optional conclusion names the group.
   - Each verdict, and the conclusion, is an item.
4. **The lesson writes everything a child reads:**
   - **The changed sentences.** Capitals, commas and elision are French's
     business, so the engine never moves words itself.
   - **The label words.** A français lesson keeps its terms in an English
     app.
   - **The button text,** optionally; it defaults to « Effacer le
     groupe »… in the app's language.
5. **No new answer kind.** The answer is a `BlanksAnswer`: span key → label
   for `group`, test id → `ok`/`not_ok` plus `conclusion` for `test`.
6. **Slices 2 and 3 (`transform`, `agree`) come later as new `task`
   values.** An app without them sees `ParseUnsupported`, so it shows
   « mise à jour », not a content error.
7. **No how-to line in the shell.** It's keyed by engine, and the two tasks
   need different words. The lesson's prompt says what to do.

## Tests
`test/phrase_lab_engine_test.dart` (20):
- parse: both shapes, and 6 refusals;
- an unknown task is unsupported;
- bracketing in either order, the overlap refusal, label then undo;
- VALIDER waits for all groups;
- partial credit with lock and removal;
- self-naming with a single label;
- snapshot round trip;
- tests that must run before being judged;
- per-item grading and retry;
- two play-throughs in the shell to « Bravo ! », and a 360 px phone.

`backend_samples_test` parses `samples/fr_phrase_lab.json` with the app's
parser.
