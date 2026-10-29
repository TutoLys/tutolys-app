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

## Revision — 2026-10-29: four tabs, no cut pill, Réglages on the left

Hafid, from a screenshot of Réglages at desktop width: "Add notifs to
experience". In the same screenshot the last pill was cut at the card
edge, and the column floated in the middle of a 1950px window.

- **Notifications is a section of Expérience**, under its own heading
  below Langue and Réduire les animations. That leaves four pills:
  Apparence, Son et musique, Expérience, Zone parent. ADR 0053's rules
  are unchanged: off by default, the guardian PIN to turn on, none on
  web or a class tablet.
  - The old stored name `notifications` stays valid
    (`SettingsTab.notificationsSection`). A kid who last left Réglages
    there, or a link to it, opens Expérience scrolled to the heading.
- **A pill is never cut without a sign.** When the pills don't fit, the
  edge with more pills fades over 28px, and the fade follows the scroll.
  The row also drags with a mouse or trackpad, which Flutter allows only
  for touch by default, so a pill past the edge was unreachable on
  desktop except by keyboard. This is in `PillTabs`, so the Carte's
  subject pills and Profil get it too.
  - Wrapping onto a second line was considered and rejected: the panel
    would jump by a row whenever the window crossed the width where the
    pills stop fitting.
- ~~**Réglages sits on the left**~~ — reversed the same day, see below.
- **The Quêtes badge stays red.** The design draws it `#EF4444`, and its
  own note says "Badge rouge « 3 » sur Quêtes". Its no-red rule is for a
  wrong answer (the amber "presque" state), not for a count.

Tests in `test/pill_tabs_test.dart`:
- four pills, with Notifications inside Expérience;
- the old name opens Expérience, scrolled to the section;
- at 375, 768, 1024 and 1950 (as the width the shell leaves the page),
  any pill past an edge has that edge fading;
- on a phone the fade swaps sides once the row is dragged.

## Revision — 2026-10-29 (later): every page column centred, one wrapper

Hafid, on the left-aligned Réglages: "WHY PUSH IT TO THE LEFT THO!" He
wants every page's column centred in the page area, the part of the
window right of the sidebar and under the header.

- **One wrapper, `PageColumn`** (`lib/core/widgets/page_column.dart`). It
  centres with equal side padding computed from the page's own width,
  never from the window's. Réglages, Profil, Aide, À propos and both of
  Quêtes' views use it. Progrès keeps its `ListView` (pull to refresh)
  and takes the same padding from `PageColumn.insets`.
- **Wider on a wide page.** The column is `PageWidth.column` (680) and
  becomes `PageWidth.columnWide` (880) once the page area is at least
  `PageWidth.wideFrom` (1360) wide, about a 1600px window with the
  sidebar. Then it isn't a thin strip. À propos stays narrow (560 → 680).
  Quêtes and Progrès stay at `PageWidth.content` (1040).
- **The old centring was already right inside the shell.** Measured in a
  widget test of the shell (sidebar, header, `IndexedStack`), the old
  `Center` + `ConstrainedBox` put the column's centre exactly on the page
  area's centre at 1024 and 1950. The offset in Hafid's Profil screenshot
  (column centre ≈1370 in a page area of 220–1950) matches a Flutter view
  about 2,516px wide, so the window was likely wider than the captured
  area. The :8080 build at a real 1950px viewport measures `flutter-view`
  at exactly 1950. The wrapper doesn't depend on any of this: it reads
  only the width it's given.

Tests:
- `test/page_column_test.dart`: the insets maths. Réglages, Aide and À
  propos inside the shell at 1024 and 1950, where the scroll view spans
  exactly the page area and the column's centre is the page area's
  centre. The wide width applies at 1950.
- `test/profile_screen_test.dart`: Profil, the same check at 1024 and
  1950.
