# ADR 0094 — `compose_build` free mode: a frame instead of a target

Date: 2026-10-29
Status: accepted

## Context

Hafid wants real creation lessons, so the gallery has something in it. A
sentence with one fixed `target` has one right answer, so it isn't a
creation (ADR 0093). A free sentence builder needs to accept any
well-formed sentence from the tiles.

## Decision

- **An optional `frame`, used instead of `target`:** one list per slot of
  the tiles that fit there, e.g. [Le chat, Mon lapin] [dort, saute]
  [dans le jardin., sur le lit.]. Any pick across the slots is a
  sentence, so the author writes the grammar once and every combination
  is accepted.
- **Slots are disjoint:** a tile fits one slot only. Each tile places
  once, so any pick fills every slot.
- **Tiles in no slot are misfits:** "dormir" where a conjugated verb goes.
  Grading is per slot, with partial credit, as before. A slot is right
  when the placed label is one its slot accepts.
- `frame` with `target` or `ordered` is a parse error. A frame is always
  ordered.
- **Agreement is the author's job.** The frame can't express "la" needing
  a feminine noun, so authors put the determiner inside the noun-group
  tile ("Le chat", "Ma poule"), with every group in a slot agreeing with
  every verb in the next.

## Consequences

- An app older than this commit can't parse a frame lesson (it has no
  `target`). It shows that one lesson as unavailable rather than
  crashing. No app has shipped yet, so the engine version stays 1.
- content_cli accepts `creation` on compose_build only with a frame that
  offers more than one sentence (backend ADR 0090).
- Tests: `test/compose_free_test.dart`.
