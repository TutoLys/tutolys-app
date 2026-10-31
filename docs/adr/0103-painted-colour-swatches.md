# ADR 0103: Colour-shape emoji are painted, not drawn from a font

Date: 2026-10-31 · Status: accepted · UX review N17 (P1)

## Context
On Flutter web, the font fallback picked Noto Sans Symbols 2, a monochrome
font, for U+1F7E0–1F7EB (🟦🟩🟨…), ⚪⚫⬜⬛ and ⭐. ESL « Colours » asked
"Find blue." over three identical grey squares. 78 content files use
these glyphs across 11 engines, and in the colour lessons (ESL/FLS 01–02,
English 22/23, math 54/55/57) the colour *is* the answer.

## Decision
`SwatchText` (`engines_core/lib/src/widgets/swatch_text.dart`) replaces
`Text` wherever content text is drawn: AnswerTile, the prompt row, and the
label sites of sort_buckets, find_it, counters_board, data_graph,
fill_blank, balance_scale and timeline_order. Each of the 19 colour shapes
becomes a painted square, circle or star, with Noto's colours and a thin
edge so white still shows on white. A string with no such glyph is still a
plain `Text`, and the screen-reader name is still the original string.

Not chosen: bundling a colour emoji font as the first fallback. It also
fixes other emoji (🐟 draws as an outline too), but the full font is 11 MB.
A subset would need build tooling, and whether CanvasKit draws CBDT
couldn't be verified here. The theme's font fallback also belongs to the
app's design system, which isn't this package's code. That's still worth
doing for the non-shape emoji, as a separate fix by the app session.

The red swatches (🔴🟥) paint red. That red is the content's own colour
name; the no-red rule is about feedback, and the validator already warns
authors about red pieces.

## Tests
`test/swatch_text_test.dart`: a colour is painted in its own colour; three
answers give three colours; plain text stays plain; a golden
(`goldens/colour_answers.png`); and a scan of the backend content tree that
fails if a colour shape appears without a swatch.
