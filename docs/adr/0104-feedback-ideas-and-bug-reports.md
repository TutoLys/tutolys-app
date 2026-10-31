# ADR 0104: Feature suggestions and bug reports from the app (« Une suggestion ? Un bug ? »)

- Status: accepted; built against a provisional contract
- Date: 2026-10-31
- Source: `Platforms/BACKEND_WORKORDER_FEEDBACK.md` F3 (Hafid, relayed by
  the Manager: feedback before the diagnostic)

## Context

Hafid wants users to suggest features and report bugs from the website and
the app. Backend is building `POST /api/v1/feedback` (F1), which accepts a
paired device's token. The app's half sits in Aide & support.

## Decisions

1. **Where:** a card in Aide & support, between the FAQ and « Pour les
   parents ». It opens a dialog with a choice between « Suggérer une
   fonctionnalité » and « Signaler un bug »,
   plain text up to 4,000 characters, and a line asking the child not to
   write their name, school or address.
2. **The guardian PIN sends.** The kid may write; « Envoyer » goes through
   `requireGuardianPin`, with its own wording. Backing out keeps the text in
   the form and sends nothing. A child may type personal details, and an
   adult sees the message before it leaves.
3. **The limit counts code points** (`runes`), as Python's `len` does on the
   backend. The counter turns amber past it (never red), and « Envoyer »
   stays disabled.
4. **Context is an allowlist:** `app_version`, `platform`, `locale`, `route`.
   No token, no answers, no telemetry id. The token rides the
   `Authorization` header only. Nothing is logged.
5. **Its own queue, never the telemetry outbox.** `FeedbackQueue` is one
   JSON key per kid in `app_state` (`feedback.queue`). Removing the kid from
   the device erases it with the rest of their rows (`KidLocalData.wipe`),
   and a sibling's message never goes out under another child's token.
   Capped at 20; past that the oldest is dropped and counted
   (`feedback.evicted_total`), never silently.
6. **Queue first, then send.** A message survives the app closing mid-send.
   Each carries a `client_id` (uuid v4) so the backend can ignore a resend
   of one it already stored. The queue flushes after a submit, whenever a
   new access token arrives, and when the app resumes. It goes oldest first
   and stops at the first message that has to wait.
7. **What counts as final:** only 400, 413 and 422, which are refusals of the
   message itself. The message is dropped, since resending the same bytes
   can never succeed. Everything else (offline, 401, 403, a 404 before the
   endpoint is deployed, 429, 5xx) is retried later.

## Provisional

The body (`client_id`, `kind` = `feature` | `bug`, `text`, `context`) is the app's proposal.
When Backend sends the contract, `FeedbackApi` and `QueuedFeedback.toBody`
are the only places to change. Until the endpoint exists, a message waits
in the queue (404 means try later), so nothing is lost meanwhile.

## Consequences

- Kids' text stays on the device only as long as it is unsent, and goes when
  the kid is removed.
- No screenshots or uploads (work order, security 2).

## Revision 2026-10-31: "feature", never "idea"

Hafid's wording: « Suggérer une fonctionnalité » / « Signaler un bug » (EN
"Suggest a feature" / "Report a bug"), and the card's title is now « Une
suggestion ? Un bug ? ». The kind sent is `feature` | `bug`. A message
queued as `idea` before this change (pre-release only) reads as `feature`.
