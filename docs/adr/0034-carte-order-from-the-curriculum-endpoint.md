# ADR 0034: the Carte reads document order and areas from the backend

Date: 2026-10-25
Status: accepted

## Context

The Carte and Progrès split a subject into titled stretches. The device
used to rebuild both the titles and the order from a table copied by hand
(`learning_areas.dart`). Two things went wrong with that:

- Strands were sorted alphabetically inside an area, so math opened on
  "opérations" instead of strand 1 (`94812b0`).
- Français past the round-2 rebuild was mostly missing from the table.
  Lire, Apprécier and Communiquer oralement showed up untitled, at the end,
  in alphabetical order.

The backend now sends `doc_order`, `strand {key, label_fr, label_en,
ordinal}` and `area {label_fr, label_en, ordinal}` on every leaf of
`/curriculum/tree` (backend ADR 0044, `e417773`), ordered by document
position. That came from work order `Platforms/BACKEND_WORKORDER_CURRICULUM_ORDER.md`.

## Decision

- `skill_node_cache` gains seven nullable columns (schema v7): `doc_order`,
  `strand_key`, `strand_label_fr/en`, `area_label_fr/en` and
  `area_ordinal`. Curriculum sync fills them.
- When **every** cached leaf of a subject has a `doc_order`,
  `groupLeavesByArea` uses the backend's data:
  - Areas are ordered by their ordinal and titled with the document's own
    label. The English title is used when the backend has one, and French
    otherwise.
  - Leaves follow `doc_order`.
  - A leaf with no area (its parent was archived) goes last, untitled. It
    is never dropped.
- Otherwise, for example a cache filled before this change or by an older
  backend, the table stays the fallback, with `94812b0`'s strand-order fix.
  A mixed cache counts as old, so the order is never half one rule and half
  the other.
- **The full strand label is kept as sent** ("Compétence Lire des textes
  variés — Section Stratégies"). Section titles use the area. A short
  strand form, if one is ever needed, is the strand label with
  `area.label_fr` and the separator stripped off the front. That's done on
  the device; no invented text comes from the server.
- The v7 migration step is bounded by `to` as well as `from`, so a
  migration test that stops at an older version doesn't get the new
  columns.

## Not done

- `doc_order` only orders. It isn't an index, and it isn't stored as an
  identity.
- `learning_areas.dart` can be deleted once no install can still hold a v6
  cache. That happens one sync after upgrade, but offline devices make
  "when" fuzzy.
