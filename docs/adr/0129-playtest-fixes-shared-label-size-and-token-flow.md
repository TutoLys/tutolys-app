# ADR 0129 — One label size per answer set, and a sentence spaced as written

Date: 2026-11-16
Status: accepted

## Context

The Manager asked for a browser play-test of the engines that had only passed
validators. Twenty grade-1 and grade-2 lessons were played against the
dev-stack (report: `Platforms/codex/ENGINE_PLAYTEST_2026-11-16.md`). Two
findings were rules every engine should share, not one-off bugs.

## Decision

- **A set of answers shares one label size.** `AnswerTile` used to size each
  label by its own length, so the longest option drew smaller than the rest.
  In univers social 89, that was the key in 4 of 6 questions: size gave it
  away. An engine now passes `AnswerTile.sharedLabelSize(labels)`, the
  smallest size any label in the set needs. This covers choice lists (mcq,
  speed_tap, data_graph, passage_reader) and big cards (compose_build,
  pair_match). A picture answer keeps its own size, because the picture is
  the content.
- **A big card never splits a word.** A 120 px compose card wrapped
  « pompier / s ». Big cards now lay out word by word, and a word too wide
  shrinks alone. This is not done with `LayoutBuilder`, which can't sit
  under the `IntrinsicWidth` that mail_studio uses.
- **Tokens are spaced the way the sentence is written.** `TokenFlow` joins
  closing punctuation (. , … ) ] ”) to the word before it, and an elided
  word (' ’ ( [ “) to the word after it. Joined tokens get no gap and never
  split across lines. The French space before ; : ! ? » is kept.
  `joinTokens` applies the same rule to text built from tokens.
  phrase_lab and proofread use both.
- **A tile can carry its own spoken name** (`semanticsLabel`), for labels
  that are only a sign (base_ten's « + »).

## Consequences

- Tests: `answer_tile_sizing_test.dart`, `token_flow_test.dart`, plus
  additions to the base_ten, counters_board, mail_studio and timeline tests.
  engines_core has 634 tests.
- An answer set's labels can be a little smaller than before when one long
  option forces the shared size down. That is the point: the cue goes away.
- Other engines that lay out tokens one per widget (fill_blank,
  passage_reader's sentences) were not changed. They should move to
  TokenFlow if they show the same gaps.
