# ADR 0092 — `my_gallery`, and keeping creations

Date: 2026-10-26
Status: accepted

## Context

The Questions Maker's ELA request 5, "Ma galerie au village", for
"selects pieces to publish". It needs the child's own creations. The
Flutter app session built the per-kid local store ("Mes créations",
`CreationShelf` in engine_sdk, `6d7bb28`): kid-scoped, on the device only,
erased and exported with the kid. This ADR covers the engine side: saving
into the shelf, drawing creations again, and the gallery.

## Decision

### Keeping a creation

- **`KeepCreationButton`** ("Garder dans mes créations") appears under
  finished work in four engines, each saving its own structured payload,
  never a picture:
  - `compose_build`: `{labels}`, in slot order;
  - `pattern_machine`: `{pieces}`, the whole sequence, via the new
    `PatternPiece.toJson`;
  - `geometry_lab`: `{pegs, band}`;
  - `mail_studio`: `{recipient, template, lines}`.
- **Saving is the child's choice**, never automatic, so the shelf holds
  what they're proud of rather than every attempt (answering the Flutter
  app's question 3).
- The button is drawn only when the host provides a `CreationShelfScope`.
- **`CurrentExercise`**, an inherited widget the shell puts above every
  engine, gives the exercise id the shelf needs. The engine contract stays
  unchanged.
- **`creationView(creation)`** draws each payload version 1 again. It
  returns null for anything it doesn't know (an engine or payload version
  from a newer app); the gallery skips those rather than drawing them
  wrong.

### The gallery

`MyGalleryEngine` + `MyGalleryEvaluator`, key `my_gallery`, explicit
submit, `BlanksAnswer` (`hang_<id>` → reason), **practice evidence** (ADR
0088).

- The view reads the shelf, newest first, up to 24 creations, optionally
  filtered by `engines`, and reports the ids it can draw (`GalleryLoaded`).
- The child hangs 1 to `max_hang` creations (up to the shelf's 3), shown
  with a gold frame, and picks a reason tile for each.
- VALIDER is right for any such choice. After it, the shelf is updated:
  other creations are taken down first, so its limit is never hit. Then
  the `visitors` (village characters) come by with their kind words.
- **An empty gallery doesn't trap the child.** Foxy explains how to keep
  a creation, and VALIDER lets them carry on (`{empty: true}`).

## Consequences

- Tests:
  - `test/my_gallery_engine_test.dart` covers parse; hanging up to the
    limit, with reasons; practice evidence; `creationView` for all four
    payloads, refusing unknown ones; end to end, keeping a compose_build
    sentence in the shell and then hanging it in the gallery against an
    in-memory shelf (the shelf records it hung, and the visitor appears);
    and the empty gallery on a phone.
  - The whole app suite passes (656).
- The answers to the Flutter app's questions, given on 2026-10-26: "hung"
  is a persistent flag on the shelf, 3 at most, and saving is an explicit
  "Garder".
