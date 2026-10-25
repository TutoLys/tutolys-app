# ADR 0024: Kid avatars, and several kids on one device

Date: 2026-10-25. Status: accepted (Hafid's go, same day).

## Context

Hafid, looking at Profil: the hero (the fox, name, grade) repeated the
header right above it. He also asked for two things:

- the kid can change their avatar, with new ones unlocked by playing;
- the kid can switch profile. When several kids share one device, the app
  should show them to choose from, with the pairing code as the way to add
  one.

The design already answers the first point. Its `.profile-hero` is a
horizontal card (avatar with an edit dot, name, three stat cards), and
both the header and the hero show the *kid's* avatar (`asset-profil`),
never the mascot. The 2026-10-24 interview already decided the second:
one device token per kid, attribution rides the credential, and "Qui
joue ?" on launch.

## Decisions

**Profil hero = the design's card.** The stats are the design's three:
level over the XP total, current streak, and badges earned. The
mastered-skills count already lives on Progrès, so Profil stops repeating
it too.

**Avatar catalog lives in the app** (`avatars.dart`, art brief
`docs/design/AVATARS.md`).
- Six free starters, so every child can pick one who looks like them.
  Choosing who you are is never locked behind play.
- Eleven unlockables: levels 2/3/5/10/20 plus the eight existing
  achievements, so an avatar and its badge unlock together. No new
  reward rule was invented.
- Unlocks are recorded once per kid in `app_state` (`AvatarStore`) and
  never revoked, the same rule as achievements. This matters because a
  `LevelCurve` retune restates every level, and a kid must not lose an
  avatar they're wearing.
- Locked avatars are shown dimmed, with what unlocks them. Seeing the
  reward is the point.
- Until the art arrives, only Léa is drawn; the rest show a neutral face.

**Avatar selection is local-first.** A kid who never picked one adopts
the backend's `Kid.avatar_key`. After that, the device's choice wins and
is pushed with `PATCH /api/v1/me/profile` (backend work order
`BACKEND_WORKORDER_PROFILE.md`, P1). The push is best effort: offline or
a 404 keeps it local.
- **Unlock rules are not enforced server-side**, on purpose. It's
  cosmetic, on the kid's own profile, so a forged request gains nothing.
  A server allowlist would also make an older backend reject a newer
  app's avatar.

**Several kids per device.** `SessionStore` holds a list of
`(kid, device_token)` plus the active kid id, in the secure store. The
old single-pairing keys migrate on first read, the new list is written
before the old keys are deleted, and `device_id` is untouched. The server
side already supports this: `Device` is unique on `(kid, device_id)`, and
exchange upserts on that pair, so pairing kid B leaves kid A's row alone.
The work order's P3 pins it with tests.
- **Switching kid switches token.** The access token is refreshed with
  the new kid's own device token *before* the state changes, so nothing
  loads for the new kid on the old kid's credential. Offline, the switch
  still happens, with no access token, like an offline launch.
- **A revoked kid is dropped alone.** Their siblings carry on, and the app
  only goes back to pairing when no kid is left. The guardian PIN is
  cleared with the last kid, not the first.
- **Everything resets on a switch.** `_PairedShell` is keyed on the kid
  id (a fresh router and fresh pages). Every kid-scoped provider watches
  `activeKidIdProvider`, which now includes `ProgressController` and
  `PathController`, which used to `read` the session once.

**"Qui joue ?"** (`ProfileStage.choosing`, drawn by `AppShell`):
- It opens on launch when several kids are paired, and from the header
  (its tooltip reads "Ce n'est pas moi") and from Profil's "Changer de
  profil".
- It shows one tile per kid with their avatar, plus "Ajouter un profil".
  That opens the pairing screen with a back button and the hint "demande à
  un parent un code" (`ProfileStage.adding`).
- With one kid, the header opens Profil instead.

## Not done

- **Picture passcode (B-A0.5).** A tap on a tile is enough for now, so a
  sibling *can* choose someone else's tile. The switcher shipped first;
  whether that is acceptable until the passcode lands is **Hafid's call,
  not yet made**. The passcode needs a backend credential that doesn't
  exist yet.
- **"Qui joue ?" on resume past a threshold**: launch only, for now.
- **Unlock state is per device**, like quest history: an avatar unlocked
  by an achievement on another device isn't known here until it is earned
  here too. Level unlocks follow the server's level, so those do carry
  over.
- **Avatar art**: 16 of 17 avatars are still to be drawn.
- **Live verification is API-level only.** `dev-stack/scripts/e2e_profile.py`
  (2026-10-25, 22/22) pairs two kids on one `device_id` and checks
  `/me/profile` GET/PATCH and per-kid token refresh against the real
  backend. The Flutter UI driving those calls was not run live.
