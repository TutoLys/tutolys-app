# ADR 0053 — Learning reminders, local only

Date: 2026-10-28
Status: accepted

## Context

Hafid asked for Duolingo-style reminders: "time to learn", and "your
streak is about to break". The plan is in
`docs/plan-2026-10-28-pill-tabs-and-reminders.md`, part B. His answers,
relayed by the Manager on 2026-10-28:

1. **Local scheduled notifications only.** Push (FCM/APNs) stays out
   until counsel reviews it.
   - He also wants **email** reminders to a parent who opts in. The
     backend builds those as an adult notification type. The app sends no
     email; it keeps its own copy and timing consistent with them (below).
2. **Mobile is where they really work.** On Linux they fire only while
   the app runs, and on web there are none. Both accepted.
3. **"Nouvelles quêtes"** is still open. That toggle is **left untouched**
   here.
4. The **08:00–19:30** window and the **3-day back-off** are accepted.

## Decision

### The rules: `planReminders`, pure and tested

- **At most one reminder per kid per day**, and only on a day not yet
  played.
- **The time:**
  - The guardian chooses it, every half hour from 08:00 to 19:00. The
    default is 17:00.
  - Nothing fires outside 08:00–19:30, whatever is stored.
- **The flame reminder replaces the day's ordinary one**, at the same
  time, when all of these hold:
  - the streak is 2 or more;
  - today isn't played yet;
  - **no shield is ready**, because a ready shield already protects the
    streak.

  If the shield's state is unknown, the ordinary reminder goes out.

  This needs no second toggle. The evening "your flame is waiting"
  reminder with its own switch waits for Hafid's answer on question 3.
- **Back-off:** after 3 days reminded without play, nothing until the kid
  plays again.
  - The count starts at the last played day, or at the day reminders were
    turned on if that's later.
- **Several kids due within 30 minutes of each other** get one reminder,
  at the earliest time, with no name: "Qui veut jouer au village
  aujourd'hui ?"
  - It's worded in the language most of them use, and in French on a tie.
  - A tap opens "Qui joue ?".
- **Never on a class tablet.**
- **Only the next 2 days are scheduled**, and the whole plan is replaced
  on:
  - launch, and every return to the app;
  - every finished lesson (today is played, so today's reminder goes);
  - a change to reminders, their time or the language;
  - a kid added or removed;
  - midnight, when the app is simply left open.

  So a stale reminder never outlives a change.

### Platforms (`ReminderSupport`)

The plugin is `flutter_local_notifications` 22.

| platform | support |
|---|---|
| Android, iOS, macOS | `scheduled`: `zonedSchedule` at the instant, firing with the app closed |
| Linux, Windows | `whileRunning`: one in-process timer per reminder, shown with `show()`. The plugin can't schedule on Linux. |
| web | `none`: no reminders and no browser permission prompt in front of a child |

Each reminder is one-off at an absolute instant, converted by `DateTime`,
so daylight saving is already in it. No time-zone database or
`flutter_timezone` is needed.

### Who decides

- **Turning reminders on and choosing their time need the guardian PIN.**
  The OS permission is requested at that moment, while the guardian holds
  the device. If permission is refused, reminders stay off and the screen
  says that notifications are blocked.
- **Turning them off needs nothing**, because doing less is always safe.
- **Off by default, under a new key** (`settings.reminders_on`). The old
  `daily_reminders` flag defaulted to on while it did nothing, so a stored
  "true" was never a guardian's choice and is ignored.
- On web and on a class tablet the switch is greyed, with a line saying
  why. On Linux the line says "only while TutoLys is open".

### The words

They're kind and short, with no loss, no guilt and no sad fox; a test
checks for this. The kid's own app language is used.

- "Le renard a préparé une nouvelle leçon. On joue ?"
- "Ta flamme brille encore aujourd'hui. Une petite leçon la garde
  allumée !"
- "Qui veut jouer au village aujourd'hui ?"
- The English equivalent of each.

**Consistency with the backend's parent emails:**
- The same time window and the same back-off apply.
- An email speaks to the parent, so its wording may differ, but it should
  carry the same tone.
- The backend owns the email's schedule. Nothing here sends one.

## Consequences

- On the platforms we ship today, reminders work only on Linux, and only
  while the app is open. They become real reminders once mobile ships.
  The mobile code path is built but can't be run in this repo, which has
  no `android/` or `ios/`.
- `AppShell` triggers rescheduling. A plugin that fails to start (a test,
  an unsupported desktop) falls back to `NoReminderSink`, which means no
  reminders, never a crash.
- Tests:
  - `test/reminder_policy_test.dart`: every rule, the wording, platform
    support, and the Linux timers.
  - `test/reminders_settings_test.dart`:
    - the coordinator, against a real local database;
    - the settings migration;
    - the tab: the PIN to turn on and to choose the time, OS permission
      refused, no PIN to turn off, web, Linux and the class tablet;
    - "Nouvelles quêtes" untouched.
- The web and Linux builds both compile with the plugin. No reminder has
  been seen firing on a real desktop yet.

## Revision — 2026-10-28: "Ma flamme"

Hafid answered question 3: the "Nouvelles quêtes" switch becomes **"Ma
flamme"** ("My flame"), the evening streak reminder.

- **Its own switch,** `flameReminders`, under a new key
  (`settings.flame_reminders`).
  - It is off by default.
  - It is turned on behind the guardian PIN and the OS permission, and
    off without either, exactly like "Rappels quotidiens".
  - The old `quest_notifications` flag defaulted to on while doing
    nothing, so it is ignored, for the same reason as `daily_reminders`.
- **At 18:30**, inside the window, late enough to leave the day for
  playing.
- **When it fires.** All of these must hold:
  - the streak is 2 or more;
  - no shield is ready;
  - the day isn't played yet;
  - the day is today, or tomorrow once today is played. If today isn't
    played, the streak has already broken by tomorrow, so there is
    nothing to save.
- **At most one a day still holds:** when the flame is due, it replaces
  that day's ordinary reminder.
- **It backs off like the daily one.** Merged with another kid's reminder,
  it becomes the unnamed "Qui veut jouer ?".
- **The daily reminder always uses the plain wording now.** The flame
  wording is only for "Ma flamme", which replaces the interim rule above
  (the daily reminder borrowing the flame wording).
- **Strings:** `settingsQuestNotifications` is gone, replaced by
  `settingsFlameReminders` and its sub-line.

## Revision — 2026-10-29: where the switches live

They moved from their own Notifications tab into a section of Réglages'
Expérience tab (ADR 0051, revision 2026-10-29). Nothing else changed.
