# ADR 0045 — `balance_scale`: compare, or level the scale

Date: 2026-10-25
Status: accepted

## Context

Catalogue #4 (`Platforms/ENGINE_CATALOGUE_2026-10-25.md`), moved ahead of
`fill_blank` and `label_image` at the Questions Maker's request:

- comparing numbers (<, >, =, missing term) is in grade-1 math strand 1,
  which it has already covered with `mcq` and `pair_match` as stand-ins;
- `label_image` waits on art;
- most of `fill_blank`'s français targets are in strands Hafid is holding.

This engine merges Hafid's B11 (the frog balance, `23.webp`) with
compare_choose's numeric form. The content contract is backend ADR 0053.

The Questions Maker asked for all four forms and three details:
- fixed sign ids;
- author-supplied options for the missing term, so each wrong value
  carries a meaning;
- an optional "=".

## Decision

`BalanceScaleEngine` + `BalanceScaleEvaluator`
(`packages/engines_core/lib/src/balance_scale/`), key `balance_scale`,
explicit submit.

**What goes on a pan:** one number, `a + b` / `a − b` (one operation per
side, terms 0–100, never below zero), or **counters**: one number drawn as
that many emoji. Counters are capped at **20**, because above that a
6-year-old can't count them and the question stops testing comparison.

**Mode `compare`:**
- The child picks < > = from tiles with the **fixed ids `lt`, `gt`, `eq`**.
  A sidecar can then name the reversed symbol, grade 1's main error.
- The right sign is **derived from the values at parse time, never
  authored**, so content can't disagree with its own arithmetic.
- `signs` can drop `eq` for early boards; parse rejects a board that
  doesn't offer the right sign.
- The scale **stays level while the child chooses, and after a wrong
  sign**: a tilt *is* the answer. It tips the true way once they're right.

**Mode `balance`:**
- Exactly one term is `null` (`4 + 1 = 1 + ?`). The child picks from **2–4
  authored options**; exactly one must level the scale, and parse checks
  this.
- A wrong value is shown in the gap and **tips the scale the way it
  would** ("1 + 5" is too heavy, so the right pan goes down). That's the
  toy's own feedback, and it says *too much / too little* without giving
  the answer away. The tried value then turns amber.

**Common to both modes:**
- **Drawn in code**, so there is no art: a post, a beam that tips about 8°,
  and two pans as white cards with a Québec-blue border. The middle disc
  shows the chosen sign, "?" or "=".
- The tilt animates at 450 ms with easeOutBack, and is instant when motion
  is reduced.
- **Screen reader:** the scale is read as "Plateau de gauche : 3 + 2.
  Plateau de droite : 6 moins 1. La balance est en équilibre.", as a live
  region so a tilt is announced. Signs are read as words ("plus petit
  que", "plus grand que", "égal à").
- A wrong pick is recorded like `mcq`'s (itemResults `{pick: false}`).

## Not done

- **Optional art:** a nicer three-layer balance and one counter sprite are
  on Hafid's asset list. Code-drawn ships today.
- **Error codes:** declared error codes per wrong choice, such as
  `reversed_symbol`, wait for LE-B3's taxonomy. Until then the sidecar
  carries the meaning.
- **Free entry:** a number pad for the missing term was deliberately not
  built, at the Questions Maker's request. Authored options are what make
  each wrong answer diagnostic.

## Consequences

- Strand-1 comparison lessons can move off their stand-ins.
- Tests: `test/balance_scale_engine_test.dart` has 13 tests:
  - parse, including the derived sign and the single levelling option;
  - reduce, evaluator, snapshot;
  - in the shell: level while choosing, tips once right; a wrong value tips
    its way; counters with no "="; spoken pans and signs; 20 counters a
    side on a phone.
  
  engines_core is now 209.
