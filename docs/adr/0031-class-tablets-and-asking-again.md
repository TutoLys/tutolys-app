# ADR 0031 — Class tablets, and asking "Qui joue ?" again

Date: 2026-10-27
Status: accepted

## Context

ADR 0039 added the picture passcode. It was live-checked against the
dev-stack on 2026-10-27, once backend `ffaaf46` (ADR 0124) landed, using
the app's own `PasscodeService` and a fresh QA kid pair. Every step
behaved as designed:

- a code was saved;
- a wrong try was rejected;
- the right one was accepted, and the fresh token it returned worked on
  a device endpoint;
- a kid with no code went straight through;
- clearing the code worked;
- the cached server verifier matched offline, so the app's HMAC is the
  backend's.

Three pieces were still missing:

- **Class tablets (O8).** Backend `f578095` (ADR 0125) added
  `POST /api/v1/pairing/class-exchange`. A teacher's 30-minute class code
  pairs one shared tablet for every consented learner at once, with
  `passcode_required: true`. Its errors: `400` for a bad or expired code,
  `400 empty_class`, and `403 organization_not_entitled`.
- **Asking again on resume.** CLAUDE.md's "Qui joue ?" decision asks
  again after a pause past a threshold.
- **Prompting the guardian at pairing**, which the work order asks for
  ("set by the adult at pairing").

## Decision

### Pairing a class

The pairing screen has an "Ajouter une classe" switch. It takes the same
six characters in the same field; only the words and the endpoint change.
Each learner becomes an ordinary pairing in the multi-kid `SessionStore`.
`saveClassPairings` also:

- marks the tablet with its `Classroom` (`classroom` key);
- caches "no passcode" for a learner the server says has none.

The tablet then opens on "Qui joue ?" with **nobody chosen**. The store
still has an active kid, because a paired state needs one, but nothing of
theirs loads while the picker is up, and the picker asks first.

Pairing again with a new code adds new learners and re-tokens the
existing ones. The classroom key goes with the last pairing.

### "Qui joue ?" on a class tablet

- The class name sits under the title.
- **Every kid needs a passcode.** A kid with none is re-checked with the
  server first, in case one was set in the portal since the last sync. If
  there is still none, they see "Ton code images n'est pas encore prêt"
  and wait for an adult, who can set it there and then ("Je suis
  l'adulte", behind the guardian PIN). Once it's saved, the kid goes
  straight on to tap it.
- Nobody plays a profile without their own code, the store's active kid
  included.

### `mustConfirm`: when nobody has said who they are

`SessionState.confirmEveryone` is set:

- after a pause past the threshold;
- after the app picked the next kid itself, because the active one was
  revoked or removed.

It is always in effect on a class tablet (`mustConfirm`). While it holds,
"Qui joue ?" asks the active kid for their passcode too, offers no
"Retour", and doesn't single anyone out as current. A successful switch
clears it.

### Asking again on resume

`SessionController.noteAway`/`noteBack` receive the app's lifecycle from
`AppShell`. Past **10 minutes** away on a family device, or **2 minutes**
on a class tablet, `lockForResume` opens the picker with
`confirmEveryone`:

- 10 minutes is long enough for a kid to answer the door, short enough
  that a sibling who picks the device up later is asked;
- a class tablet changes hands between activities, hence 2 minutes.

A device with one kid and no class is never asked.

### A revoked learner

The school removing a learner, or a guardian revoking the school, revokes
that kid's class `Device`. The next refresh is refused with a reason, and
ADR 0037 erases the kid's local data, as for any revoked kid. The app
then opens the picker with `confirmEveryone`, rather than dropping
whoever is holding the tablet into the next kid's profile, which it did
before for a revoked kid at launch.

### The guardian prompt

When a family device goes from one kid to two or more, `AppShell` offers
"Plusieurs enfants sur cet appareil", if some kid here has no code yet.
"Choisir les codes" goes through the guardian PIN to the Codes images
list. The guardian is holding the device with the code at that moment,
which makes it the right time to ask. A class tablet doesn't get this
prompt: its codes are the school's, set in the portal or at the waiting
screen.

## Consequences

- The class's `avatar_key` from the exchange isn't applied yet. Avatars
  on a class tablet come from each kid's device-local choice, as before.
- The thresholds are constants. If schools want their own, they'd become
  a setting.
- Nothing here changes a single-kid family device: there's no picker, no
  prompt, and nothing on resume.

## Revision — 2026-10-28: three gaps from the pro-role walk-through

The Manager asked for a walk through the app as each school role touches
it. The API side was walked against the dev-stack demo school, and it
behaved as the app expects:
- the class code and the class exchange's fields;
- a seat through the school;
- the school removing a learner, after which the refresh is refused with
  `revoked`.

The screens, rendered with the real fonts, showed three app-side gaps,
now fixed:

- **Every learner showed the same default face.** The class exchange's
  `avatar_key` was ignored, so on a class tablet, where nobody is chosen
  yet, the whole class saw one face. Now `pairClass` stores each
  learner's `avatar_key` (when it's a known key) and `sex` in their own
  `AvatarStore`. This supersedes the first consequence above.
- **"Ajouter un profil" showed on a class tablet.** The school decides who
  is on its tablet, and a child mustn't be able to pair a family code
  onto it. The tile now shows only on family devices.
- **The class-code screen showed the family's hint**, "Demande ton code à
  la personne responsable de ton compte". Now it shows none; its
  subtitle already says the teacher shows the code.
