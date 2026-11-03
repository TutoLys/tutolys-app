# ADR 0123: The profile menu replaces "Qui joue ?" inside the app

- Status: accepted
- Date: 2026-11-03
- Source: Hafid's ask, relayed by the Manager: "instead of opening this when
  we click on the icon, we should have a cool dropdown or something like
  that listing the profiles"

## Decisions

1. **Tapping the header's avatar opens a menu in place**
   (`showProfileMenu`). It lists each kid on the device with their avatar,
   name and grade, marks the kid playing, and ends with « Ajouter un
   profil ».
2. **It always opens, even for one kid.** Before, one kid's tap went to
   Profil. Profil is still a tab, and the menu is how a family finds
   « Ajouter un profil ».
3. **Profil's « Changer de profil » opens the same menu,** under the
   header's avatar, so the full screen is no longer reached from the app.
4. **Tablet and desktop get a card anchored to the avatar; a phone gets a
   bottom sheet,** the same split as the bell's panel. The card opens under
   the anchor, or over it if the anchor sits in the lower half.
5. **Switching stays one path.** `enterAs` (was the picker's private
   `_enter`) does the passcode check and the token switch for both the
   picker and the menu. The menu closes first and the caller goes on from
   its own context, because a passcode screen outlives the menu.
6. **"Qui joue ?" stays** for launch, for the resume lock, for a class
   tablet's forced confirmation, and after a kid is forgotten.
7. **Backing out of "Ajouter un profil" returns to where it was opened.**
   From the menu that is the app, and from launch "Qui joue ?"
   (`cancelAdding`). Otherwise the menu's own flow would land on the screen
   it replaces.
8. **On a class tablet,** the menu has no « Ajouter un profil », as on the
   picker, and the kid playing is marked, but tapping them still asks for
   their passcode, because a class tablet always asks.

## Consequences

- The header's identity is now labelled « Changer de profil » for everyone,
  and shows a small chevron except on a phone, where there is no room.
- Tapping the kid already playing just closes the menu; it doesn't open
  Profil.
- Keyboard: focus starts on the kid playing, the arrows and Tab move, Enter
  picks, and Esc closes. The arrows are mapped here because Flutter web
  binds them to scrolling.
- Reduced motion: no scale or fade on the card, and no slide on the sheet.
