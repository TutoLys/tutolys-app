# ADR 0093 — The picture passcode on "Qui joue ?" (B-A0.5)

Date: 2026-10-26
Status: accepted

## Context

Several kids share one device, and "Qui joue ?" picked a kid on a tap
(ADR 0024). Any child could choose a sibling's tile, and their play then
landed on the sibling's mastery data, which is the data the product exists
to produce. Classroom devices made this a prerequisite (O8, Hafid's
decision). The work order (`Platforms/BACKEND_WORKORDER_A0.md` §B-A0.5)
asks for a per-kid **picture passcode**: three pictures in order, from
nine. It is framed as choosing who you are, not as logging in or as
security.

The backend half is `apps.passcodes`, built by the Orgs & tutors session
at the same time. This app is built against its views as they stand in
that session's working tree:

- `GET/PUT/DELETE /api/v1/me/passcode`, with the kid's own access token;
- `POST /api/v1/me/passcode/verify {sequence}`. On a match it returns
  `{access_token, expires_in}`. A wrong sequence is
  `403 {code: wrong_passcode}`, no passcode is `404 {code: no_passcode}`,
  and `429` is the per-kid throttle (10 a minute, 100 a day);
- the sequence is three **distinct** indexes, 0–8;
- the offline verifier is `{salt, verifier, algorithm: hmac-sha256-v1,
  image_set: v1}`. The verifier is the hex HMAC-SHA256 keyed on the salt,
  over `"<kid id>:<a>-<b>-<c>"`.

## Decision

### The pictures

Nine pictures from art the app already ships, chosen so no two look alike
at a glance: flame, chest, coin, bell, target, star, fox, the math house,
the science house (`passcode_pictures.dart`). **No new art was needed.**
Kid avatars were left out on purpose: on a screen about who you are, they
would read as other children. The backend only ever sees an index, so the
app owns which picture an index means, and **that list must never be
reordered**. Changing the art for good means a new `image_set` on both
sides.

### Checking

`PasscodeService.check` asks the server first, using the kid's own device
token refreshed into an access token. A match brings back an access token,
and `SessionController.switchTo` uses it as is rather than refreshing a
second time. When the server can't be reached, the check runs against the
cached verifier.

Wherever a check can't be made, the child is let through, because this is
data integrity, not security, and no child should be locked out of
playing. That covers being offline with nothing cached and a verifier this
app can't compute (an unknown `algorithm` or `image_set`). Three
corrections are made along the way:

- a wrong try online re-reads the kid's state, in case the passcode was
  changed in the portal since it was cached;
- a `no_passcode` answer is accepted and cached as "none";
- `429` says "take a little break" and is not counted as a wrong answer.

### The cache

`SessionStore` keeps each kid's last-known state in the secure store under
`passcode_<kidId>`: the server's verifier, or `none`. It never holds the
sequence. It is dropped with the kid's pairing.

`syncAll` refreshes every paired kid's state whenever a picker is about to
show: the launch picker, and "Qui joue ?" when it opens. A code a teacher
or parent sets in the portal is therefore asked for from the next choice
on. A kid the device has never learned about isn't asked.

### Where it's asked

- **"Qui joue ?"**, when switching to another kid. Tapping the current kid
  still just closes the picker.
- **The launch picker**: every kid is asked, including the last one who
  played, because the device doesn't know who picked it up.

The entry screen reads "C'est toi, Léa ?" and shows the kid's avatar.
"Ce n'est pas moi" is always on screen and returns to the picker without
switching anyone. A picture already picked is dimmed and can't be picked
again, matching the backend's rule that the three pictures are distinct.
An undo button takes back the last pick. A wrong try clears the slots,
shows an amber message (the design never uses red) and shakes the slots.
With reduced motion there is no shake, and the routes cut instead of
fading. There is no lock icon and no count of tries left.

### The guardian side

Réglages → **Codes images**, behind the 6-digit guardian PIN, lists every
kid paired on the device with Choisir/Changer and Retirer. The guardian
picks three pictures, then taps them again to confirm; a different order
starts over. Each kid's code is saved with **that kid's own credential**,
so a guardian sets every sibling's without switching to them.

Saving needs the server: a code only this device knew would be asked for
here and nowhere else. Offline, the screen says so and nothing is cached.

`requireGuardianPin` gained `confirmLabel`, `createSubtitle` and
`enterSubtitle`, so this gate doesn't say "Déconnecter". Sign-out keeps
its wording.

## Consequences

- Switching kid is now a real authentication event when a passcode
  exists, which was the work order's aim.
- 504 sequences and a verifier on the device are a deliberate choice, not
  a weakness to fix: the backend's model says the same.
- No "Qui joue ?" on resume past a threshold yet (CLAUDE.md's design asks
  for it); only launch and the header/Profil entry points ask.
- Setting the code at pairing time (the work order's "at pairing") isn't
  prompted. The guardian sets it from Réglages, or in the portal.
- If the backend's shapes change before it commits, `passcode_api.dart`
  is the one file that knows them.
