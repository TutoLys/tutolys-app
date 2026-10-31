# ADR 0105: Bundled colour emoji, big answers, a thumb-sized counters board

Date: 2026-10-31 · Status: accepted
Source: UX review, mobile pass (`Platforms/ux-review/mobile-2026-10-31.md`),
items AM1–AM4. Supersedes the "bundle a font" rejection in ADR 0103.

## Context
At 375 px on the web build:
- **AM2:** pictorial emoji (🐟 🏖️ 🏫) drew as grey line glyphs. Flutter
  web's font fallback picked a monochrome font. ADR 0103 painted the colour
  *shapes* (🟦 ⚪ ⭐) and left the rest, so « Combien de poissons ? » still
  couldn't be answered.
- **AM3:** answer labels were 15 px, left-aligned in 343 px tiles, smaller
  than the question, with the bottom 40 % of the screen empty.
- **AM1:** the counters board's − and + were 40 px hit areas touching each
  other, and its main gesture was a drag from one 24 px « Réserve » dot.
- **AM4:** the fox and speaker took 140 px of the question row, so a prompt
  wrapped to 4–5 lines.

## Decisions
1. **Ship a colour emoji font, cut to what the lessons use.**
   `packages/engines_core/fonts/TutolysEmoji.ttf` is Noto Color Emoji (SIL
   OFL 1.1, `fonts/OFL.txt`) subset to the 463 emoji in
   `tutolys-backend/content`, plus ZWJ, VS16 and the keycap mark: 1.16 MB.
   - ADR 0103 rejected the font at 11 MB; the subset is a tenth of that and
     works offline, which the CDN fallback never did.
   - It is the **last** entry of `fontFamilyFallback`, so letters and
     digits still come from Baloo 2; only glyphs Baloo lacks reach it.
   - Applied once, in the activity shell (`DefaultTextStyle.merge`, inside
     its `Material`, which replaces rather than merges the default style),
     and in `SwatchText` for content text drawn elsewhere.
   - The painted swatches (ADR 0103) stay: they're exact and cost nothing.
   - `test/emoji_font_test.dart` fails when content uses an emoji the font
     lacks; `tool/build_emoji_font.py` rebuilds it. A golden shows 🐟 🏖️ 🏫
     in colour.
   - Emoji outside the engines (Quêtes, Village) are the app's text and
     still use the platform fallback. The app theme can add the same
     family if it wants them too.
2. **Answers are big.** `AnswerTile` gains two modes:
   - `prominent` (mcq, speed_tap lists): centred, 24 px when the label is
     24 characters or fewer, 19 px when longer, 44 px for a picture-only
     label; 64 px tall at least.
   - `square` (balance_scale, the pick-one row of measure_tool and
     fraction_slice): the label centred at 30 px, scaled down rather than
     cut, the state icon under it.
   - `ChoiceLayout` lays out a choice question: two or three answers of six
     characters or fewer, with no picture, are one row of square tiles (112
     px at 375); four are a 2 × 2 grid; anything else is the list.
   - Other engines' tiles (pair_match, sort_buckets, timeline…) are
     unchanged: their slots are narrow, and 24 px words would break.
3. **Counters board.**
   - − and + are 56 px round buttons with 24 px glyphs, 16 px apart.
   - The reserve is a 64 px pile under the board, in the thumb zone. A tap
     adds one counter (to the mat, else the first plate with room); a drag
     still works.
4. **Below 420 px the prompt row drops the fox.** The 56 px speaker stays to
   its left (Hafid's rule). Foxy still appears in the celebration.

## Consequences
- The web build downloads 1.16 MB more at start, once, then caches it.
- A new emoji in content fails the engines suite until the font is rebuilt.
  That is deliberate: a grey fish is a question nobody can answer.
- Tests: `emoji_font_test.dart` (4), `answer_layout_test.dart` (7), one new
  counters test, and both goldens refreshed (picture answers are centred).

## Re-check, same day
ux-review confirmed AM1–AM4 at 375 (`ux-review/shots/mobile/after/`). It
found four more, now done:
- **data_graph and passage_reader** answers use the same big answers
  (`ChoiceLayout` and `prominent`), so a number becomes a square tile.
- **A line of pictures in a question** (« 🐟🐟 » above « Combien de
  poissons ? ») is what a counting question counts, so it draws at 40 px,
  not at the text's 20. The whole question is still one screen-reader
  label.
- **AM25:** measure_tool's « 40 °C » fell half under VALIDER. Up to three
  short pick-one answers now share one row, each 96 px tall.
- **AM26:** data_graph's chart is 260 px tall (was 220), so pictograph
  faces are ~26 px, and its axis is 15 px (was 12, and « 0 » was clipped).
- **AM27 (second re-check):** passage_reader's third answer sat half under
  VALIDER with nothing to say the page scrolls. The shell's scrolling body
  now fades out at the bottom and shows a 48 px ↓ button (« Voir la
  suite ») while there's more below. It's in the shell, so every engine
  whose body scrolls gets it.
- **Third re-check (AM28–AM32):**
  - A part a tap reveals (a discussion's friends, then its clue) scrolls
    itself into view (`RevealIntoView`), instantly when motion is reduced.
    The grey VALIDER's nudge now says « Termine d'abord ta réponse ! »,
    which is true at every step; « Choisis d'abord » was wrong once the
    child had chosen.
  - Each question opens with its body scrolled to the top: the shell keys
    the scroll on the question index.
  - The ↓ cue hides while « Bravo ! » / « Presque » shows.
  - In a discussion, each passage sentence carries the number its cite
    button uses.
  - A chosen answer shows a filled dot and a 3 px edge. A dot, not ✓,
    because ✓ means « right ».
