# ADR 0116: Mobile review calls AM9, AM13, AM14 and AM17

- Status: accepted
- Date: 2026-11-01
- Source: `Platforms/ux-review/mobile-2026-10-31.md` AM9, AM13, AM14, AM17;
  Hafid's « yes to all », relayed by the Manager

## Decisions

1. **AM17, pairing.**
   - Adding a profile (from « Qui joue ? ») shows one sentence, « Demande
     à un parent un code… ». The family hint under the boxes repeated it,
     so it's gone in that mode.
   - The button reads « Ajouter » when the code adds someone: a profile
     or a class.
   - First launch keeps « Se connecter »: on an empty device, « Ajouter »
     doesn't say what's being added. Changing it is a one-line string swap
     if Hafid wants it everywhere.
   - Keyboard at 375 px: the AM22 layout already moves the logo and title
     aside. A new test pins the button above a 336 px keyboard in
     add-profile mode.
2. **AM14, Quêtes.** Each quest wears Village's chip: the same gradient and
   the same ⚡ ✓ ⏱ icon, shared through `questChipColors` and
   `questIconFor`. The green check circle shows only once a quest is done.
   An empty circle read as a radio button.
3. **AM13, one stat strip.** Profil's level, streak and badges are one
   3-up row (`Row` of `Expanded`, icon over value over label), never a
   wrap, so « Niv. 1 » can't sit alone on a second line. Progrès drops its
   three cards and keeps only the per-subject detail. The header still
   shows XP and streak, as the design draws it.
4. **AM9, Carte.**
   - **Below `Breakpoints.compact`, « Continuer » is a card pinned under
     the path**, so it sits above the tab bar, and `SkillPath` draws no card
     under the orb (`inlineCard: false`). Wider screens keep the design's
     card under the active orb: their rows are already tall enough that it
     covers nothing.
   - **Short labels.** Each curriculum leaf may carry
     **`short_label_fr` / `short_label_en`**, a 2–4 word kid label written in
     content, served on `GET /api/v1/curriculum/tree`. The app caches them
     in `skill_node_cache` (schema v11, tested 10 → 11) and the Carte and
     « Révision » show them. The full statement stays in `label_*` for
     parent reports.
   - **Fallback (`kidLabel`/`trimLabel`).** The statement is cut cleanly:
     first clause if it stands alone, cut at a word near 24 characters
     with no dangling « de », « et » or « l' », then an ellipsis.
     « par ordre croissant ou dé… » becomes « par ordre croissant… ».
     That's about two caption lines at phone size. One line would leave
     one or two words under an orb as narrow as 78 px.

## Asked of others

- Content and backend: author and serve `short_label_fr` /
  `short_label_en` per leaf. Blank or missing counts as none, and an older
  backend needs nothing.

## Consequences

- Until short labels arrive, every caption is a trimmed statement:
  readable, but not a kid's wording.
- The Carte on a phone loses about 90 px of path height to the pinned
  card. In exchange, nothing covers a node.

## Addendum, 2026-11-01: the verify pass at 5286654

- **AM17.** Phone browsers often shrink the window for the keyboard rather
  than report an inset, so at 375×476 « Ajouter » was below the fold. A
  window shorter than 600 px now counts as keyboard-up: the logo and title
  step aside, and the scroll anchors to the bottom.
- **AM9, trim.** The fallback still ended on « d’un », « d’une », « non »,
  and on « (ajout, ». Elided articles (« d’ », « l’ », « qu’ ») now dangle
  when what follows is a function word. More French and English function
  words are listed. A trailing comma or colon is dropped, and so is an
  aside whose « ( » the cut can't close.
- **AM9, screen readers.** A node reads the skill's full statement
  (`PathNode.spokenLabel`), and the trimmed caption is excluded, so
  « par ordre croissant…. » is no longer read, and nothing is read twice.
- **AM14.** The done check sits at the end of the row, as on Village, so
  every chip stays in one column.
- **Lost pairing after the rebuild: not the upgrade.** The pairing lives in
  the secure store (`localStorage` on the web), which the drift upgrade and
  Repair never touch. The app drops a pairing only after the server
  rejects its token or a guardian signs out. The backend log shows no
  rejected refresh, and no device request at all between the rebuild and a
  fresh pairing two minutes later. So the browser started with empty
  storage.

## Addendum, 2026-11-01: short-label check

- **Orb label.** A screen reader hears the short label, or the trimmed name
  without its ellipsis. Hearing the full statement (up to 300 characters)
  on every orb was too long. That statement is now the orb's semantic
  hint (`PathNode.fullStatement`), reachable on request, and left out when
  it is the label already.
- **Language.** The Carte already chose the label language by subject
  (`showsEnglishLabels`, ADR 0023), so short labels follow it: an EN or
  ESL orb shows `short_label_en` in a French app, and an FR or FLS orb
  shows `short_label_fr` in an English app. « Révision » used the app
  language and now uses the same rule (`kidLabelFor`). The Continuer card
  and Village's « Continuer » use the Carte node's label, so they follow
  too.
