# ADR 0010 — PIN gate before "sign out this device"

Date: 2026-10-23
Status: accepted

## Context

`GO_LIVE_CHECKLIST.md` Track D, item 4/4: no PIN/parental gate exists
anywhere in either client. Scoped deliberately narrow — **not** a
screen-time control (that's a separate, larger product decision, still
open) — just the one existing action that currently has zero friction: a
kid tapping `ProfileScreen`'s "sign out this device" button, which today
costs a guardian a full re-pair to undo.

## Decisions

**A PIN, not a math "parent gate" captcha.** The classic
solve-two-numbers pattern used by many kids' apps doesn't require
anything to be *set* by the adult, which is exactly why it was rejected
here: this product's own device-pairing design already treats "a
guardian deliberately acted" as the thing worth recording (see
`Kid.consent_given_at`/`consent_given_by` in `tutolys-backend`, ADR
0017) — a PIN the guardian chose is consistent with that, a generic
captcha anyone could solve is not.

**Not a security boundary — a friction gate.** Stored as a salted SHA-256
hash (`SessionStore.setGuardianPin`/`verifyGuardianPin`, same `crypto`
package already used for content checksums), never plaintext, because
there's no reason to store it carelessly even though its actual job is
narrower than a password: stopping a casual tap, not resisting a
determined adult who could just ask another adult for the number.

**Creating the PIN the first time *is* the gate.** There's no settings
screen anywhere in the app yet to set one up ahead of time. The first
time a guardian taps "sign out" on a given device, with no PIN stored,
`requireGuardianPin()` shows a create-PIN dialog (4 digits, entered
twice) instead of an enter-PIN dialog; successfully creating one both
protects future attempts and completes this one. Every later tap on the
same device asks for the PIN that already exists.

**Lives in `SessionStore`, not a new table.** It's device-local state
exactly like the device token and kid id already stored there — no
backend involvement, no sync. `clearPairing()` wipes it alongside the
rest of the credential: the next family to pair this device sets their
own PIN rather than inheriting a stranger's.

**Wired as a single `requireGuardianPin(context, ref)` call in front of
the existing `forget()`,** not folded into `SessionController` itself.
The gate is a UI concern (two dialogs) over storage the controller
doesn't otherwise touch; keeping it in `features/profile/pin_gate.dart`
means the controller's own tests didn't need to change at all.

## Verified

5 new widget tests in `test/profile_screen_test.dart` (`group('PIN
gate')`): no PIN set yet → sign-out prompts to create one, and doesn't
sign out; a mismatched confirmation shows the error and doesn't sign
out; a matching PIN is saved and the device is actually signed out; with
a PIN already set, the wrong one is rejected (device stays signed in);
the correct one signs it out. A hand-written `_FakeSessionStore` stands
in for the real `FlutterSecureStorage`-backed one — same pattern
`pairing_test.dart`'s existing `FakeSessionStore` already uses — since
no precedent exists anywhere in this codebase for mocking the real
federated secure-storage plugin's platform channel directly, and that
plugin's Linux backend isn't a simple single-channel mock in the first
place. `flutter analyze`: 0 issues. Full suite: all tests passed
(144, up from 139).

Attempted a live browser check (`flutter build web` + static serve,
same recipe ADR 0003 used to fix the web build originally): assets load
clean, zero console errors beyond an expected WebGL-fallback warning,
but `flt-glass-pane` mounts with zero children and no `flt-scene-host`
— the same sandbox-compositor limitation ADR 0003/0008 already
documented, not something this change caused. Not claimed as visually
verified; the widget tests above are the real verification, same
honesty standard as those two ADRs.

## Not done

No settings screen to create or change a PIN ahead of the first
sign-out attempt, or to reset a forgotten one short of fully re-pairing
the device (which already wipes it). No rate limiting or lockout on
repeated wrong PIN entry — deliberately out of scope, since the PIN is
a friction gate, not a security boundary, and a kid who keeps guessing
4-digit combinations is already getting the friction it exists to add.
Screen-time controls remain a separate, unscoped product decision.

## Revision (2026-10-26): 6 digits, and a restyled dialog

Hafid: the PIN is **6 digits**, not 4. This is the interview decision
recorded in `CLAUDE.md`, now built.

- `SessionStore.guardianPinLength = 6`. Every field is digits only
  (`FilteringTextInputFormatter.digitsOnly`), hidden, with the numeric
  keyboard and a `0/6` counter. Create refuses anything shorter.
- **Migration.** The hash doesn't reveal the length, so `setGuardianPin`
  now also stores `guardian_pin_digits`. A PIN stored without it was set
  when every PIN had 4 digits, so `guardianPinDigits()` reads it as 4.
  Such a PIN is asked for at 4 digits and still opens the gate, then the
  guardian must choose a 6-digit PIN before the action goes ahead. If they
  back out, the old PIN is left as it was and works next time: nobody is
  ever locked out. `clearPairing` removes the count with the PIN.
- **Look.** The plain Material `AlertDialog` is replaced by the design's
  modal card (`.streak-modal`: surface, 24px corners, navy shadow, at most
  380 wide), a Baloo 2 title, `VillagePalette` colours, Réglages' rounded
  fields, and a `.btn-gold` pill. Errors use the amber `retry` colour; the
  design never uses red. The buttons wrap rather than overflow.

Tests: the store reads a legacy PIN as 4 digits (`multi_kid_test`), and
the gate covers create at 6, short and non-digit input, enter at 6, and
both legacy paths: upgrade then proceed, and back out with the old PIN
still working (`profile_screen_test`). A rendered check of the dialog in
light and dark looked right. It was not checked in a browser.

The "Not done" items above still stand, with "4-digit combinations" now
6-digit ones.
