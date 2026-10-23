# ADR 0005 — Phase 5's engine list, and `speed_tap` as the first addition

Date: 2026-10-20
Status: accepted (engine list proposed, not yet confirmed by Hafid)

## Context

B9's follow-up work surfaced that "12 engines, chosen from the 16 real
Godot archetypes" (CLAUDE.md's correction to plan §5.6) was never actually
resolved anywhere in the repo — only Set A (`mcq`, `pair_match`,
`compose_build`) exists in code. Hafid confirmed the rebuild should reach
feature parity with the old product (see `CLAUDE.md`'s 2026-10-20
correction) and said to start on Phase 5 ("lessons/skill tree") once the
subscriptions/billing backlog was captured.

`reference/engine-schemas/GAME-ARCHETYPES.md` (salvaged from the old
`tutolys-games` Godot project) turned out to hold real information missing
everywhere else: a maturity tier for all 16 archetypes (1 shipping, 3
built-not-content-proven, 12 "boilerplate built, needs a real content
pack"), each with a working JSON Schema. No row says which 12 of the 16
are the final launch set, though.

## Decision

Proposed the remaining 9 (on top of the 3 already built) from that
registry, favouring `AUDIT.md`'s own explicit callout — six mechanics
(`speed_tap`, `data_graph`, `compare_balance`, `find_it`, `memory_flip`,
`timeline_calendar`) the original plan omitted entirely despite having
real shipped prior art — plus three more for math/language coverage the
first nine don't hit (`construct`/token-build, `sort_buckets`,
`count_forward_path`). Dropped: `true_false`, `grid_navigate`,
`label_diagram`, `math_select`. **Not yet confirmed by Hafid** — flagged
explicitly as provisional, not a locked decision, the same mistake this
ADR is trying to avoid repeating.

Built `speed_tap` first because it's the cheapest of the nine: the
registry's own note calls it "the same `mcq` content shape... no new
content contract." Confirmed true while building it — its backend schema
(`docs/schemas/exercise/engines/speed_tap.content.schema.json`) is
`mcq`'s schema plus one new field, `time_limit_ms`, and its referential
check in `content_cli` is literally `_check_mcq` reused under a second
key, not a new function.

**A timeout is scored exactly like a wrong tap**, never an abandon the
engine decides on its own: a logged wrong attempt
(`answer_payload: {selected: null, timed_out: true}`), gentle feedback,
countdown restarts. This keeps `speed_tap` on the same forgiving
retry-until-correct contract every other engine already uses — the
alternative (ending the run on timeout) would make this the only engine
that can fail on its own, with no clear product reason for the
inconsistency.

## Consequences

- `EngineRegistry` now resolves 4 engines; `packages/engines_core` is at
  36 tests (was 27), app suite unaffected (115, the registry's own test
  just asserts one more key). Backend content_cli: 209 tests, a 4th
  sample (`content/samples/math_speed_tap.json`), `known_engine_keys()`
  now returns 4.
- The other 8 engines in the proposed list are not built yet. Each should
  follow the same shape: check the old archetype's content shape in
  `GAME-ARCHETYPES.md`/`reference/engine-schemas/*.content.schema.json`
  first — several may turn out to reuse an existing referential check the
  way `speed_tap` reused `mcq`'s, rather than needing a new one.
- Content authoring remains the larger, separate gap this round didn't
  touch: `AUDIT.md`'s finding that only 2 of 769 leaves have any exercise
  at all is unaffected by adding engines — real grade-1 math/French/
  English content has to be authored regardless of how many engines exist
  to play it.
