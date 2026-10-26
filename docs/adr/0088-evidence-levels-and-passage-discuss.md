# ADR 0088 — Evidence levels, and passage_reader's `discuss` task

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's ELA creative engines (Hafid's go: "cool and
creative engines") share three rules:
- partners and audience are village characters only;
- no microphone (D8);
- grading is local, from structured choices, never free text.

Each mode must also declare what its result is evidence of, so reports
stay honest. The first of the engines is a `discuss` task on
`passage_reader`, for the leaf "uses other readers' interpretations".

## Decision

### Evidence levels

- **`EvidenceLevel`** in engine_sdk: `direct` (the default), `proxy`
  (planned or chosen stand-ins for the skill) and `practice`
  (participation only, never mastery). It's carried on
  `EvaluationResult.evidence` and in its `toJson`.
- **The recorder doesn't send it yet.** Telemetry's v2 `evaluation`
  object is `additionalProperties: false`, so a new key would get every
  attempt from these engines rejected. Work order **LE-T3** has telemetry
  accept `evaluation.evidence` first; only then does the recorder add it.
- **The backend can already be honest:** the level follows statically
  from each engine and mode in the content. Work order **LE-B9** has
  mastery skip practice and flag proxy.

### `discuss`

The steps unfold on one screen, and one VALIDER checks them together. The
shell ends a question on any correct verdict, so they can't be separate
checks.

1. The child answers `question` from `options`. This is their own
   reading and is never graded.
2. Two characters' `takes` appear, each resting on one sentence. Under
   each take, numbered chips let the child pick the sentence it rests on.
   This is **direct** evidence: item `take_<id>`.
3. Once both takes are matched, a new `clue` sentence appears, and stays.
   The child gives a final answer: keep it, change it, or pick a combined
   reading, which is just another option.
   - With `clue.accepts`, the final answer is the item `final` (**proxy**).
   - Without it, both takes stay valid, so the revision is **practice**
     and not an item at all.
4. Partial credit: right takes and a right final lock; a wrong cite goes
   amber and can't be repeated for that take; a wrong final goes amber.

Plumbing:
- `PassageReaderEngine`'s answer type widens to `AnswerValue`: blanks for
  `discuss`, a multi-select as before for `find` and `choose`. The state
  carries its `DiscussPart`, so the reducer can check actions.
- The village characters (`widgets/village_characters.dart`) are shared by
  every creative engine: names in both languages, colours, and portraits
  drawn as a disc with an initial and a mood mouth. A lesson's
  `image_ref` replaces the drawn portrait.

## Consequences

- Tests: 8 in `test/passage_discuss_test.dart`; 2 in the passage_reader
  tests changed for the wider answer type and the new task name.
- engine_sdk: `EvidenceLevel` is additive; existing results are `direct`.
