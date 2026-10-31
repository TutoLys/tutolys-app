# ADR 0107: Back leaves a game like ✕; phones stay upright (AM20–AM24)

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/ux-review/mobile-2026-10-31.md`, « Using it like a parent
  (and a child) on a phone », relayed by the Manager

## Decisions

1. **AM20: a game has its own URL, and every way out asks the same thing.**
   - `GoRouter.optionURLReflectsImperativeAPIs` is on, so `push('/play')`
     writes `#/play`.
   - Before, the address bar kept the page underneath. The browser's Back
     then moved that hidden page while the game stayed on screen, and on
     quitting the child landed somewhere else.
   - The `/play` route's `onExit` asks `PlayScreenState.confirmLeave()`.
     go_router calls it on a pop (✕, Android Back) and on a URL change (the
     browser's Back). A série already started opens « Tu veux arrêter ? »:
     Continuer stays, and Arrêter exits the session and leaves.
   - When the game decided to leave itself (finished, or confirmed on ✕) it
     sets `_leaving`, so nothing is asked twice.
   - The QA lesson picker plays through the same route too. It closes, the
     game plays at `#/play`, and the picker reopens afterwards.
2. **The sheet is copied for now.** The ✕ sheet is private to engines_core,
   which is the Engines session's package. `lib/features/play/stop_sheet.dart`
   copies it, and should call Engines' version once it's exported. Asked of
   Engines.
3. **AM21: phones stay in portrait.**
   - On Android and iOS, a screen whose short side is under 600px locks to
     portrait (`lockPhonesToPortrait`, a no-op elsewhere).
   - The installed web app was already portrait (`manifest.json`).
   - A phone's browser tab can't be locked, so a two-column activity layout
     in landscape belongs to the activity shell (engines_core). Asked of
     Engines.
   - Locking was chosen over a second layout for the app chrome: a grade-1
     child holds a phone upright, and one layout per screen stays one.
4. **AM22: the keyboard never covers the pairing code.** While it is up, the
   logo and « Salut ! » step aside. The form scrolls anchored to the bottom,
   so the six boxes and « Se connecter » sit just above the keyboard.
5. **AM23:** under 500px tall, the header is 56px instead of 92px.
6. **AM24: the web page allows pinch-zoom.** `maximum-scale=1.0,
   user-scalable=no` is gone from the viewport (WCAG 1.4.4). The app never
   clamps the OS text size, so large text already applies.
   - `flutter_native_splash:create` writes that meta back when regenerated.
   - A test reads `web/index.html` and fails if it returns.

## Consequences

- A refresh on `#/play` still goes to the Carte: the request lives only in
  memory (unchanged).
- Until Engines exports its sheet, the two copies have to stay alike.
