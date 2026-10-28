# ADR 0037: Erasing a kid's local data when they leave the device

Date: 2026-10-26. Status: accepted, revised the same day (see the end).

## Context

Until now, removing a kid from a device dropped only their credential.
Their queued events, streak days, engine settings, unfinished sessions,
own `app_state` keys and (since ADR 0036) creations all stayed on the
device. Nothing could use them again: without the token the events can
never upload, and a re-pair starts a new local life.

Hafid's ruling (2026-10-26, through the Manager): **ask first.**

## Decision

**When a guardian removes a kid** (Réglages → sign out, behind the PIN),
`RemoveKidDialog` tells them, in plain words and in both languages
(`Strings.removeKid*`), what is kept on the device: the number of play
results not yet sent, and the number of creations in "Mes créations".
Then it offers three choices:

1. **"Envoyer puis effacer"**: `OutboxFlusher.sendAllNow` uploads every
   queued event while the token still works. It ignores backoff, because
   a person is waiting and the rows are deleted next either way. If it
   empties the outbox, the removal goes ahead. If a round sends nothing
   (offline, a rejected credential, events the server refuses), the
   dialog says so and offers **"Réessayer"** or **"Effacer quand même"**.
2. **"Effacer maintenant"**: erases at once, unsent results included.
3. **"Annuler"**: nothing happens.

When nothing is unsent, "Envoyer puis effacer" is not shown: there would
be nothing to send.

**When the server rejects the credential** (HTTP 401 on refresh: revoked,
archived or erased), there is nobody to ask, and nothing could upload
anyway. The data is erased at once, with no prompt.

**What "erase" means** is `KidLocalData.wipe`. In one transaction, it
deletes every kid-scoped row: `event_outbox`, `played_date`,
`engine_settings`, `activity_session`, `creation`, and the kid's
`app_state` rows. It leaves alone what the device shares: the content
caches (`exercise_cache`, `audio_cache`, `asset_cache`,
`skill_node_cache`) and `app_state` rows owned by `deviceScope`.
`SessionController._forgetActiveKid` calls it on both paths.
`CreationStore.eraseKid` (ADR 0036) is gone, because this covers it.

## A risk worth naming

A 401 on refresh now deletes data, not just a credential. If the backend
ever answered 401 wrongly (a signing-key mix-up, a bad deploy), every
device that refreshed in that window would lose its kids' unsent results,
not only their pairing. Before this ADR, a re-pair recovered everything.
The server's own erasure has already happened when the 401 is real, so a
prompt wouldn't help: the guardian couldn't send anything either. The
mitigation belongs on the backend: a 401 on refresh must only ever mean
revoked, archived or erased.

## Not done

- **No local export.** `GO_LIVE_CHECKLIST` Track D tracks it. When one
  is built, it should read what `KidLocalData` erases.
- **No prompt on server rejection**, as above.

## Consequences

- `DriftEventOutbox.pending` and `OutboxFlusher.flush` take an
  `ignoreBackoff` flag, used only by `sendAllNow`.
- Tests: `kid_local_data_test.dart` (erases exactly one kid's rows, with
  device scope kept), `outbox_test.dart` (draining several batches past
  backoff, and every failure mode), `remove_kid_dialog_test.dart` (the
  three choices, a failed send, and nothing unsent), `multi_kid_test.dart`
  (forget erases), and `profile_screen_test.dart` (the PIN then the
  confirmation).

## Revision (2026-10-26): erase on rejection only when the server says why

The Manager's call, on the risk above: don't rely on the backend never
sending a wrong 401. A rejected refresh erases local data **only when the
401's body carries `"reason"` set to exactly `revoked`, `archived` or
`erased`** (`RejectionReason`, parsed in `PairingApi.refresh`). A bare
401, or one with any other value, still drops the token and asks for a
re-pair, as before ADR 0037, and keeps the kid's local data. If the same
kid is paired again, their queued results upload under the new token.

Until Backend sends the field, no rejection erases anything. That's the
safe side. A guardian's removal through the dialog is unchanged and
always erases.

The field Backend should send: `{"detail": "...", "reason": "revoked" |
"archived" | "erased"}` on `POST /api/v1/pairing/refresh` 401s.

Tests: `pairing_api_refresh_test.dart` (each reason parses; a missing,
unknown, wrongly-cased or non-string reason is bare) and
`multi_kid_test.dart` (each reason erases; a bare 401 keeps the data).

## Known gap (2026-10-26): erasure never reaches the device

Backend shipped `reason` in `9002326`, with only `revoked` and `archived`.
Any other 401 has no `reason` key at all. The seat gate stays a 403 with
its own code, so it never reaches this path.

**`erased` will never arrive.** The server's erasure flow hard-deletes the
kid's `Device` row (backend ADR 0018). After that, the kid's token is
unknown to the server, so its refresh comes back as a **bare 401**. By the
rule above, a bare 401 keeps the local data. So **erasing a kid on the
server does not erase anything on their devices**: their queued results,
streak days, settings, unfinished sessions and creations stay until a
guardian removes the profile through the dialog. `/me/profile` can't
signal it either, because the token is already dead.

The app still parses `erased`, so it costs nothing to keep, but nothing
sends it today. Don't assume a server-side erasure wipes devices.

Backend is writing up options for Hafid and counsel:
- a non-identifying tombstone of the token hash, so refresh can answer
  `erased`;
- guardian instructions in the erase flow;
- on the app side, offering the removal dialog after N days of bare 401s.

Nothing changes in the app until that's decided.

## Revision — 2026-10-28: no seat is not a lost pairing

The backend has a third answer besides "good" and "rejected": **403
`seat_required`**. The pairing is fine, but the child holds no seat right
now, because a family's plan or a school stopped covering them. It comes
on refresh, on pairing exchange, and on every seated content or progress
endpoint. The backend's own message is "Demande à un parent de t'ajouter."

Until now the app treated it as a generic failure: it stayed paired with
no token, retried every 60 s forever, showed stale data, and told the
child nothing. That was found in the pro-role walk-through; the Manager
said go on the plan.

- **It's not a rejection, so nothing is erased and nothing is forgotten.**
  `RefreshNoSeat` keeps the device token, as the backend asks, "for when a
  seat comes back". This revision's erase rules apply only to
  `RefreshRejected`.
- **`SessionState.noSeat`** is a paired kid with no access token. The
  shell shows `NoSeatScreen` in place of the village. On it:
  - the fox and "Demande à un parent de t'ajouter.";
  - "Réessayer", which runs a refresh;
  - "Qui joue ?" when there are siblings, so one of them can play
    meanwhile.
  - **No money, plans or prices**, which a test pins.
- **When it's checked again:** on "Réessayer", on every return to the app,
  and every 5 minutes. A seat that comes back lets the child straight in.
- **Mid-session:** a Dio check on the API client sees a `seat_required`
  403 on a kid's own call (one carrying a token) and asks the session for
  a refresh. A burst of 403s shares one refresh. Exchange and refresh carry
  no token and never trigger it.
- **Pairing a child with no seat** now says "Ce profil n'a pas encore de
  place. Demande à un parent de t'ajouter." instead of a generic error.
- **Also fixed:** the pairing screen's title now uses the design's display
  face (Baloo 2). Before, it fell back to the platform font.
