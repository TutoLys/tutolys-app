# ADR 0089 — `mail_studio`: one piece of news, written for different readers

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's ELA request 2, "La poste du village". It covers
two leaves: writing for a familiar audience, and writing for a wider
one. The content contract is backend ADR 0085.

## Decision

`MailStudioEngine` + `MailStudioEvaluator`
(`packages/engines_core/lib/src/mail_studio/`), key `mail_studio`,
explicit submit, `BlanksAnswer` (slot id → its tile ids).

- **The task:** the child has news to tell and one village recipient: a
  character, plus an audience (`family`, `friend`, `teacher`, `public` or
  `younger`). They fill the lesson's 2–6 slots (format, greeting, details,
  sign-off) from tiles. A `many` slot takes several tiles.
- **Tiles:** each names the audiences it suits. A detail tile's
  `needed_by` says who can't follow without it: Grand-maman knows Max, the
  village paper's readers don't.
- **Grading:** a slot is right when all its tiles suit the recipient and
  nothing they need is missing. Partial credit per slot. After a check,
  right slots lock; misfit tiles go amber and leave; a fitting tile stays,
  so the child adds what's missing.
- **The recipient reacts** in the lesson's words. The first failing slot
  decides:
  - a misfit tile gives its `reaction`, and the portrait looks put off;
  - a missing needed tile gives its `missing_reaction` ("Qui est Max ?"),
    and the portrait looks confused;
  - a right message gives `delighted`.

  Without words from the lesson, the recipient says a generic line for
  the mood. The face is never the only cue.
- **The preview** renders the chosen tiles in the format's template, drawn
  in code: a pink card, a lined letter, a newspaper column under "LE
  JOURNAL DU VILLAGE", or a gold poster.
- **Parse requires a real choice in every slot:** a tile that doesn't
  suit, or in a `many` slot a detail the reader needs. A single slot can't
  need two tiles, and a tile can't be needed by an audience it doesn't
  suit.
- **Evidence:** direct for audience fit. The writing itself is a proxy,
  because the child chooses rather than writes. The result is recorded as
  direct (what each item measures is fit). The ADR states the writing
  caveat for reports.
- Tiles may carry `audio_ref`, read on request (ADR 0087).

## Consequences

- Tests: 7 in `test/mail_studio_engine_test.dart`, covering:
  - parse (no real choice, needed-but-unsuited, a single slot needing
    two);
  - the same news for the paper and for Grand-maman;
  - misfits putting the reader off;
  - a single slot swapping its tile;
  - snapshot;
  - in the shell, confused then delighted;
  - layout on a phone.
- Portraits are drawn until art exists (asset list sent to the Manager).
