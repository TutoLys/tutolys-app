# ADR 0128 — La calculatrice: the `calculator` engine

Date: 2026-11-15
Status: accepted

## Context

`codex/ENGINES_NEEDED_2026-11-08.md` item 1. Grades 3–4 ask the child to use a
calculator for × and ÷ and to find a keying mistake (leaf `8793796c`). Grades
5–6 add the memory keys (leaf `f1551c2a`). Until now these were taught with an
mcq about a laid-out key sequence, which is only a proxy.

## Decision

- **One engine, three tasks.**
  - `key`: key the given calculation, then press =. It's graded on the line
    the child worked out, so typing the answer's digits isn't keying the
    calculation. The two numbers of a single + or × may be swapped.
  - `repair`: the line opens with one mistake already keyed. The child fixes
    it with ⌫ or C, then presses =.
  - `solve`: a problem in the prompt, solved by any route and graded on the
    screen. With `require_memory`, a right answer reached without MR is
    partial.
- **A school calculator with a two-line screen**: the keyed line on top, the
  result below. × and ÷ come before + and −. Numbers are exact rationals
  (0,1 + 0,2 shows 0,3), shown with at most 8 decimals, the comma, and a true
  minus.
- **Keys appear only when asked for.** The digits, + − × ÷, =, C and ⌫ are
  always there. `memory` adds M+ M− MR MC and shows the memory on the screen,
  as the lessons file requires. `sign` adds +/−, and `decimals` adds the
  comma.
- **Diagnoses reuse the taxonomy.** `math.calculator.key_misread` covers a
  wrong digit or operation, and `math.calculator.key_order` covers the right
  keys in another order. One new code, `math.calculator.memory_not_used`,
  must be registered by Backend.
- Nothing animates in the engine. Each key press is an `item_placed`
  interaction.

## Consequences

- Tests: `test/calculator_engine_test.dart` covers parse refusals,
  precedence, exact decimals, ÷ 0 as E, editing, memory, sign, grading for
  each task, snapshot round-trip, and the shell at desktop and phone width.
  On a phone, the bottom keys sit under the VALIDER bar until the child
  scrolls.
- Backend: schema, content_cli check and sample (backend ADR 0401). Backend
  must run `content sync-engines --only calculator --activate` and register
  `math.calculator.memory_not_used`.
- Not yet played in a browser. That is the bar for telling `content-direct`
  it's usable.
