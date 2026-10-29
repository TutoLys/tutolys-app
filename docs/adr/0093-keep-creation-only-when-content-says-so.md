# ADR 0093 — "Garder dans mes créations" only when the content says so

Date: 2026-10-29
Status: accepted (amends ADR 0092)

## Context

ADR 0092 tied `KeepCreationButton` to the engine: any finished
`compose_build`, `pattern_machine`, `geometry_lab` or `mail_studio`
question offered to keep the result. Those engines also serve closed
questions. On math lesson 29 ("Compte par bonds de 2 : 0, 2, 4. Quels
nombres viennent ensuite ?") the child places 6 and 8 and is offered to
keep that as a creation, which means nothing. Hafid keeps the feature.

## Decision

- A new optional config key, **`creation`** (boolean, default `false`),
  on all four engines. The button shows only when it is `true`.
- It is **optional with a default**, so content without it keeps working
  and older installs, whose parsers ignore keys they don't know, are not
  broken. The backend schemas (`additionalProperties: false`) gained the
  key in the same change (backend ADR 0089).
- A non-boolean `creation` is a parse error, like `ordered` and `shuffle`.
- Authors set it only on open work: a sentence the child builds, a free
  shape, a message. Never on a question with one right answer. The
  backend refuses it on a `geometry_lab` copy.
- `my_gallery` is unchanged; its empty state still lets the child go on.

## Consequences

- Flagged: `samples/fr_mail_studio.json` (questions 1–2: backend ADR 0090 found that 3–4 allow one message) and
  `samples/math_geometry_lab.json` (the 5 builds, not the copy). No math
  lesson, no français word or syllable lesson, and no `pattern_machine`
  content: that engine has no invent mode yet, so every pattern has one
  answer.
- Not flagged: `pfeq_grade1_english/10_build_a_sentence.json`. Each
  sentence has one fixed target, so it has one right answer. It gets the
  flag only once compose_build has a free-build mode where the child picks
  their own words.
- Tests: `offersKeep` (`test/support/fake_shelf.dart`) plays each engine
  in the shell with the flag on and off.
