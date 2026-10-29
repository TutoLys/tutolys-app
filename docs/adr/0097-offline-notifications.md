# ADR 0097 — Notifications with no connection

Date: 2026-10-29
Status: accepted

## Context

Hafid: "build offline notifications after the window." The bell (backend
ADR 0024) only showed what `GET /api/v1/me/notifications` returned, so a
child who finished a quest offline heard nothing until the server's next
scheduled job, and only if they were online then. Reading the inbox
offline was lost too: the POST failed and nothing remembered it.

What already existed and is kept:

- **The bell** in the header, with an unread count and its panel.
- **Scheduled local reminders** (ADR 0053):
  - OS-level, no push server.
  - Per-kid toggles in Réglages, nothing outside 08:00–19:30 (the
    evening quiet hours), and a 3-day back-off.
  - Never on a class tablet, and no kid's name in the OS notification.
  - Worded through `Strings` in the kid's language.
  - On web only if the browser allows, and quietly nothing otherwise.

  The Manager's brief asked for exactly this; nothing new was needed there.

## Decision

### A local inbox per kid

- New table `local_notification` (schema v10), per kid (ADR 0014), keyed
  by `(kid_id, fact_key)`. `LocalInbox` writes it and lists it.
- **Fact keys use the backend's format**, `<kind>:<identity>`:

  | trigger | fact key | type |
  |---|---|---|
  | daily challenge done | `daily_quest:<day>` (the backend's own) | `daily_quest_completed` |
  | another quest done | `quest:<day>:<kind>` | `quest_completed` |
  | achievement earned | `achievement:<key>` | `achievement_earned` |
  | Série reward (chest at 3 days, Gardien at 7) | `achievement:streak3` / `streak7` | `streak_milestone` |
  | level reached | `level:g<grade>:<n>` | `level_reached` |

- Written by the quest board the moment it learns something, online or
  not. It diffs what is newly done or earned against `QuestLog`, so a fact
  lands once, however often the board re-runs (`notificationFacts` is the
  pure part).
- **Levels**: the year level (ADR 0033) is this device's count merged
  with the server's. A level is announced only when it rises past the last
  one announced at that grade. The first look only remembers it, so an
  upgrade doesn't announce a level reached long ago. The wording ("tu
  montes au niveau N de ton année") celebrates the play, not a server
  number.
- Worded at display time from the row's params, so a language change
  rewords old rows too.

### Merging with the server

- The bell shows the server's items, plus every local one the server didn't
  also send (`mergeInboxes`). **The same fact shows once**, as the server's,
  and it's read if either side read it. If the server says a fact is read,
  the local twin is marked read too.
- The kid API doesn't serve `dedupe_key` yet, so a served item's fact key
  is derived. For `daily_quest_completed` it is the `created_at` day, taken
  both as a local day and as a UTC day, since the backend's day boundary is
  still UTC. Work order N1 asks for the real key.
- **Server-only types stay server-only**: the streak freeze spent or
  refunded (the server decides it), and tutoring reminders. The app never
  writes those.
- The last server inbox is kept in memory while the backend is
  unreachable, so going offline doesn't empty the bell.

### Reading offline

- Opening the bell marks every local row read and sets a per-kid
  `notifications.read_pending` flag, then POSTs if it can.
- If the POST fails or there's no token, the flag stays. While it's set,
  what the server last said was unread shows read.
- On the next refresh with a token, the queued POST goes **before** the
  fetch, so the fetched inbox already reflects the read. The flag clears
  only when the server takes it.

### Kid scoping

Rows, the read flag and the level memory are all per kid. Switching kid
rebuilds the controller and drops the cached server inbox.

## Backend: `Platforms/BACKEND_WORKORDER_OFFLINE_NOTIFICATIONS.md`

- **N1**: serve `dedupe_key` on each kid notification.
- **N2** (optional): accept client fact keys, so the backend can skip
  writing a fact the device already announced. Not needed for correctness,
  since the app dedupes.

## Consequences

- A child hears about a quest, an achievement or a level the moment it
  happens, on a plane or anywhere.
- Notifications the app writes stay on the device. Another device of the
  same kid shows only the server's, as before.
- Old notifications aren't pruned yet. At most a few rows a day per kid,
  so this can wait.
