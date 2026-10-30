# Art brief: the second-language buildings (optional)

For ADR 0101. **Nothing is blocked on this.** Today ESL wears the Anglais
building and FLS the Français one, and that is correct: a child knows the
subject by its language, and never has both pairs.

## Why distinct art might still be worth it

A French-school kid sees Français (language of instruction) and Anglais
(second language). An English-school kid sees English and Français. The
Français building means two different subjects to two different children.
That's fine for the child. A parent with kids at both kinds of school, or
a teacher looking at screenshots, may want to tell them apart at a glance.

## If drawn

Two buildings, same family as the others (`asset-bldg-*.webp`, about
440×420, transparent, the soft 3D village style):

- **ESL**: the Anglais building's twin, smaller and friendlier, a
  "welcome" cottage. A door with a « Hello! » sign, a little bridge or
  path that reads as "crossing into another language".
- **FLS**: the same cottage in the Français building's palette, with
  « Bonjour ! » on the sign and a fleur-de-lys ⚜️ on the flag. **No maple
  leaf.**

Both should sit on the plot the design gives Anglais (0.12, 0.76) without
crowding Mathématiques above or CCQ to the right. They're drawn at full
size, not `small`.

Files: `assets/images/asset-bldg-esl.webp`, `asset-bldg-fls.webp`. Then
change two lines in `subjectArt` (`lib/features/path/subject_pills.dart`).
