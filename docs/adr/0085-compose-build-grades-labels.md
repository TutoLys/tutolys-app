# ADR 0085 — `compose_build` grades by label, not by tile id

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker found the bug in strand 2. In ordered mode,
`ComposeBuildEvaluator` compared tile ids with the target's ids. With
three "3" tiles for "3 + 3 + 3 = 9", putting the second "3" in the first
slot was graded wrong although the board reads correctly. Any word with a
repeated letter ("balle") had the same trap. The Questions Maker scanned
the published lessons and found none affected.

## Decision

- **Both modes compare labels.** Tiles that read the same are
  interchangeable.
- **Ordered:** a slot is right when its tile's label equals the target's
  label at that position.
- **Unordered:** labels are counted as a multiset. A slot is right while
  its label is still owed, so two "3"s need two "3"s in the target.
- **Slot-by-slot results are unchanged** (keyed by slot index), so
  feedback, locking and telemetry need no change.
- **The legacy widget engine (`compose_build_engine.dart`) is left as it
  is.** It serves nothing published (ADR 0022).

## Consequences

- Tests: `test/compose_slots_labels_test.dart` covers repeated digits, the
  repeated letter in "balle", a different label still being wrong, and
  unordered counting.
- The backend's `_check_compose_build` doesn't need to change: it already
  allows tiles with the same label.
