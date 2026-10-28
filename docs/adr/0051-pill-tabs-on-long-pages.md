# ADR 0051 — Pill tabs on long pages

Date: 2026-10-28
Status: accepted

## Context

Hafid (2026-10-28): long pages made of stacked cards should become
category tabs, using the same pills as the Carte's subject pills. Réglages
comes first, then any other page that is a long stack. The plan is in
`docs/plan-2026-10-28-pill-tabs-and-reminders.md`, part A, and the Manager
said go.

Two pages qualify:

- **Réglages**: five stacked groups, then the parent zone, the links and
  sign-out.
- **Profil**: a hero card, then three stacked cards.

The others don't:

- Progrès already has the subject pills.
- Quêtes already has its *Mes quêtes / Ma série* switch.
- Aide is a single FAQ list.
- À propos is short.

## Decision

### One widget: `PillTabs`

`lib/core/widgets/pill_tabs.dart` is the Carte's `.subject-tabs` row,
generalised. Each tab is a value, a label and an optional leading widget:
a building image on the Carte, an icon on Réglages. `SubjectPills` is now
a thin wrapper, so the Carte, Progrès, Réglages and Profil can't drift
apart.

**Keyboard**

- Tab reaches each pill, with a visible focus ring.
- ←/→ move to the neighbour and select it, wrapping at the ends.
- Home and End jump to the first and last pill.
- Enter and Space select.
- Arrows select as they move, because that's the usual pattern for a
  short tab row. A panel here is cheap to swap.

**Screen reader**

- The row is a `tabBar`, and each pill is a `tab` with its selected state
  and its place: "Son et musique, onglet 2 sur 5".
- The panel is a `tabPanel`.
- The tab bar sits inside the scroll view. A scrollable's own semantics
  node may not come between a tab bar and its tabs (Flutter asserts it).

**Phone:** the row scrolls horizontally, and the selected pill is
scrolled into view when it changes.

**Reduced motion:** `PillTabPanel` cross-fades over `Motion.quick`, and
swaps instantly when motion is reduced. Nothing slides.

### The tab is remembered per kid: `pageTabProvider(page)`

The chosen tab is stored in `app_state` under the kid's own owner
(ADR 0014), key `ui.<page>.tab`. Switching kid restores that kid's tab.

- Each page parses the stored name against its own tabs, so a tab that
  is renamed later falls back to the first.
- A choice made while the stored value is still loading wins over the
  late read.

**Deep link** = `select(tab)` before opening the page. It becomes the
remembered tab, so no second mechanism is needed. The reminders plan
(part B) will use it to open Réglages → Notifications.

### Réglages

The five tabs are **Apparence · Son et musique · Expérience ·
Notifications · Zone parent**.

- Each group's card loses its own heading, because the pill names it.
- Zone parent holds the parent card, the picture codes and sign-out.
- Aide & support, À propos and the version line sit under every tab, so
  they are never more than a tap away.

### Profil

The hero stays on top: avatar, name, grade, the three stats and "Changer
de profil". Under it are three tabs: **Par matière · Badges · Récent**.

- Each card loses its heading, because the pill names it.
- "Progression par matière" and "Activité récente" were too long for a
  pill, so the strings became `profileTabSubjects` ("Par matière") and
  `profileTabRecent` ("Récent").

## Consequences

- Sign-out is one tap further away: Zone parent, then sign-out. It was
  already behind the guardian PIN, and putting it in the parents' tab
  matches who uses it.
- Tests: `test/pill_tabs_test.dart` covers
  - tap, arrows (wrapping), Home/End and Enter;
  - semantics: tab role, selected state and position;
  - the instant swap under reduced motion and the fade otherwise;
  - the per-kid, per-page memory and the race with a late read;
  - Réglages' tabs, deep link, unknown-name fallback, and every tab at
    360 px with no overflow.
- `test/profile_screen_test.dart` covers Profil's tabs, the hero above
  every tab, and every tab at 360 px.
