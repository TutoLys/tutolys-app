# ADR 0084 — `counters_board`: manipulatives for story problems

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker asked for this engine for strand 2. It covers:
- math SO 2: add, take away, put together and compare with objects;
- math SO 3: equal groups, arrays, sharing, repeated addition;
- two strand-1 leaves that were only proxied until now: "dénombrer en
  groupant" and "représenter avec des groupements de dix".

The content contract is backend ADR 0082.

## Decision

`CountersBoardEngine` + `CountersBoardEvaluator`
(`packages/engines_core/lib/src/counters_board/`), key `counters_board`,
explicit submit. The answer is a `BlanksAnswer` holding the final board:
`mat` and `plate_i`, or `rows` and `cols`.

- **Three modes:**
  - `free`: one mat, for adding or taking away.
  - `plates`: 1–6 plates, for equal groups and fair shares.
    `ten_frames` draws each plate as a 2 × 5 ten-frame holding 10.
  - `array`: the child sets rows × columns with steppers.
- **Moving counters:** every area has − and + buttons.
  - + on a plate takes from the mat's pile first (sharing out a heap),
    otherwise from the reserve.
  - − on a plate puts the counter back on the mat if there is one,
    otherwise it goes away.
  - Counters can also be dragged between areas and to or from the
    reserve, but dragging is never the only way.
  - `supply: false` removes the reserve, so only what's on the board can
    be used (take-away, sharing).
- **Graded on the final board, never on the moves.** Every rule set in
  `target` must hold: `total`, `mat`, `per_plate`, `plates` (each plate,
  in order), `removed` (start total minus final total), `rows` and `cols`
  (`either_way` accepts the swap). Each rule is its own item.
- **Near misses:** content lists board signatures with a `diagnosis`
  (`{code, taxonomy_version}`), the same shape `mcq` options use. A wrong
  board that matches one carries that code; any other wrong board is
  unclassified. The engine invents no codes.
- **Parse checks the target can be reached:**
  - totals against the start and the supply;
  - plates plus the mat adding up to the total;
  - per-plate counts within a plate's capacity;
  - rows × cols matching the total;
  - rules that don't fit the mode.
- **The reducer enforces the caps** (at most 40 counters; 20 per plate,
  or 10 on a ten-frame; the reserve only with `supply`). The state carries
  its content, as `path_planner`'s does.
- **Counters** are pattern_machine pieces (a red circle by default) or a
  `symbol` (an emoji), the way `balance_scale` draws its counters.
- **Screen reader:** every area speaks its count ("Assiette 1 : 4
  jetons"), and an array speaks its rows, columns and total.

## Consequences

- Tests: 10 in `test/counters_board_engine_test.dart`, covering:
  - parse (reachability, mode rules, near misses);
  - take-away with a diagnosis;
  - sharing from the pile;
  - ten-frames and the reserve;
  - arrays with and without `either_way`;
  - snapshot;
  - in the shell: sharing, wrong then right; a drag from the reserve;
  - layout on a phone.
- Its sample is added to `backend_samples_test.dart`.
- The sample's near-miss codes are proposals. The backend's error
  taxonomy doesn't hold them yet.
