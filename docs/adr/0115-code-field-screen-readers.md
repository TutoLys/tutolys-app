# ADR 0115: The pairing code works with a screen reader (K17)

- Status: accepted
- Date: 2026-11-01
- Source: `Platforms/ux-review/mobile-2026-11-01-verify.md` K17; the
  Manager's go (a plain accessibility bug)

## Context

With semantics on (TalkBack, VoiceOver, or Flutter web's accessibility
tree), the pairing code's input read as disabled. Tapping it didn't focus,
and typing went nowhere. Two causes in `TutolysCodeField`:
- The real input sat under `Opacity(0)`. A fully transparent `Opacity`
  drops its child from the semantics tree unless `alwaysIncludeSemantics`
  is set. What remained was the wrapper's `Semantics(textField: true)`,
  with no enabled state and no tap action, which reads as disabled.
- The input was 1 px tall, so even a visible node could barely be tapped.

## Decisions

1. The real input keeps its semantics (`alwaysIncludeSemantics: true`) and
   is laid over the boxes (`Positioned.fill`), so it takes the taps and its
   node covers the whole code. No cursor, no selection handles; it stays
   invisible.
2. The label lives on the input (`semanticLabel`, default « Code de
   connexion »), and the wrapper `Semantics` is gone: there is one text
   field, enabled, with a tap action. It reads as disabled only while a
   code is being checked.
3. The six drawn boxes are `ExcludeSemantics`.
4. The field redraws its boxes on every change itself, rather than relying
   on the parent to rebuild per keystroke.

Tests (`code_field_semantics_test.dart`) run with semantics on. One
labelled, enabled text field. A semantics tap opens the keyboard and
typing fills the code. Disabled while submitting.

## Consequences

- The pairing screen and « NIP oublié ? » (ADR 0109) get the fix together;
  both use this field.

## Addendum (2026-11-01): one line, with Go

ux-review saw the field announced as a textarea, so phone keyboards showed
↵ instead of Go. The input is now one line (`maxLines: 1`) with
`TextInputAction.go`. Six characters still submit on their own, and Go
submits a full code (a short one is ignored). The semantics are unchanged:
one enabled, labelled field covering the boxes. « NIP oublié ? » uses the
same field, so it changes too.
