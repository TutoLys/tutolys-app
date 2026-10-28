# Plan — pill tabs on long pages, and learning reminders (2026-10-28)

Hafid's asks of 2026-10-28, relayed by the Manager. Plan only; nothing is
built yet. Part A is ready to build on a "go". Part B waits for Hafid's OK
on the plan itself.

---

## A. Long stacked pages become pill tabs

### Which pages

| page | today | plan |
|---|---|---|
| **Réglages** | 5 stacked groups, the parent zone, then 3 links and sign-out | **tabs** (first) |
| **Profil** | hero card, then 3 stacked cards: *Par matière*, *Badges*, *Activité récente* | **tabs under the hero** (second) |
| Progrès | already has the subject pills | no change |
| Quêtes | already has the *Mes quêtes / Ma série* pill switch | no change |
| Aide & support | one FAQ list of expanding rows | no change: one list isn't a stack of categories |
| À propos, Village, Carte | short, or not cards | no change |

### Réglages tabs

The five tabs are **Apparence · Son · Expérience · Notifications · Parents**.

- **Parents** holds the parent zone, the picture codes and sign-out.
- **Aide & support**, **À propos** and the version line stay **under every
  tab** as a footer, so they're never a tap away from wherever you are.

### Profil tabs

The hero stays on top. The three cards it currently stacks become the tabs
**Par matière · Badges · Récent**.

### One shared widget

`SubjectPills` becomes a thin wrapper over a new generic `PillTabs` in
`lib/core/widgets`. It takes `(key, label, leading)` items, where `leading`
is a building image or an icon. The look is identical to the Carte pills:
`navActiveFill`, the stadium shape and the `compact` sizes.

- **Phone:** the row scrolls horizontally, as the Carte's does. The
  selected pill is scrolled into view when the page opens.
- **Keyboard:** Tab moves focus into the row. ←/→ move between pills,
  and Home/End jump to the first and last. Enter or Space selects. The
  focus ring is visible.
- **Screen reader:** each pill is announced as a tab, selected or not,
  with "n of N". The panel is announced by its tab's name.
- **Reduced motion:** the panel swaps instantly. Otherwise it fades in
  over `Motion.quick`. Neither page slides.
- **Remembered per kid:** the last tab is stored in `app_state` under
  `ui.settings.tab` and `ui.profile.tab`, scoped to the kid (ADR 0014).
  Switching kid restores that kid's tab.
- **Deep links:** the shell can open a page on a given tab, for example
  `openSettings(tab: notifications)`. Part B uses that when a reminder
  needs the guardian. An explicit tab wins over the remembered one.
- **Tests:** tabs switch content; the tab is remembered per kid; arrow
  keys and Enter work; reduced motion swaps with no animation; semantics
  report selected; no overflow at 360 px; i18n coverage.
- **Cost:** 3 commits, about a day, plus an ADR.

---

## B. Learning reminders ("time to learn", "your flame is waiting")

### Local, not push (the recommendation)

**Local scheduled notifications.** The app schedules them on the device
itself, and nothing leaves it.

- No Google or Apple token is involved, and no server ever learns when a
  child is reminded.
- No new processor is added, so the privacy drafts don't change.

**Push (FCM/APNs)** would send a device token, plus timing that reveals a
child's habits, to Google and Apple. That needs counsel and a PIA first,
like M2. **Not in this plan.**

### What works on which platform

The plugin would be `flutter_local_notifications`. A spike confirms the
exact versions before anything is built.

| platform | today | reminders |
|---|---|---|
| Android, iOS | build-ready, not shipped | **fully scheduled.** They fire with the app closed and survive a reboot. This is where reminders really matter. |
| macOS, Windows | not built yet | scheduled (`zonedSchedule`), to confirm in the spike |
| **Linux** | shipped | **show only, no scheduling.** A reminder can fire only while TutoLys is running, even minimised. Closed means silent. |
| **Web** | shipped | **no closed-app reminders without push.** In an open tab, the browser Notification API could fire at the time. That needs a permission prompt, which only the adult should ever see. |

So on the two platforms we ship today, reminders work **only while the app
is open**. They become real reminders once mobile ships.

My recommendation is to build the scheduling logic and the Réglages tab
now (testable, no platform risk). Linux would get "fires while running"
only, and web nothing, rather than a browser permission prompt in front
of a child.

### The two reminders

1. **"Time to learn"** (`dailyReminders`, Rappels quotidiens) fires once a
   day at the guardian's chosen time, **only if the kid hasn't finished a
   lesson today**. Playing cancels it.
2. **"Your flame is waiting"** fires once in the evening, only when all of
   these hold:
   - the streak is ≥ 2;
   - today isn't played yet;
   - **no shield is ready**, because a ready shield already protects the
     streak and we don't nag.

`questNotifications` (Nouvelles quêtes) has nothing to fire on: quests
renew at midnight, when it's quiet hours. The plan relabels it as the
toggle for the second reminder ("Ma flamme" / "My flame"). The other
option is to remove it. **Hafid's call.**

### Rules, so it can't nag

- **At most one reminder per kid per day.** If both are due, the streak
  one wins.
- **Quiet hours:** nothing between 19:30 and 08:00. The time picker only
  offers 08:00–19:00. School hours are left to the guardian's choice of
  time.
- **Back-off:** after 3 days with a reminder and no play, reminders pause
  until the kid next plays. This is Duolingo's own lesson: a reminder
  that's ignored becomes noise.
- **Rescheduled on every app open and every finished lesson.** Only the
  next 2 days are ever scheduled, so a deleted kid or a changed setting
  never leaves stale reminders behind.

### Who decides

- **The guardian, behind the PIN.** Both toggles default to on today and
  do nothing. Once they're real, they **default to off**. Turning one on,
  choosing its time and the OS permission prompt all happen behind the
  guardian PIN, in the Notifications tab. That's the deep link from part A.
- The kid can **turn reminders off** without the PIN, because doing less
  is always safe. Turning them back on needs the PIN.
- **Class tablets:** no reminders. The tab says so, because a school
  device must never ping.

### A shared device with several kids

- Settings are per kid (they already live on `app_state`).
- Scheduling is per device: each kid's due reminders are gathered, and
  any that fall in the same 30 minutes are **merged into one**: "Qui veut
  jouer ?" / "Who wants to play?"
- **No child's name on the lock screen**, because it's a shared screen.
  Tapping a reminder opens "Qui joue ?", or the kid directly when there's
  only one.

### Copy

Kind, short, and never guilt: no sad fox, no "you'll lose", no countdown.
A grown-up may well be the one reading it aloud.

| | FR | EN |
|---|---|---|
| daily | Le renard a préparé une nouvelle leçon. On joue ? | Your fox has a new lesson ready. Want to play? |
| daily (variant) | C'est l'heure d'une petite aventure au village ! | Time for a little adventure in the village! |
| flame | Ta flamme brille encore aujourd'hui. Une petite leçon la garde allumée ! | Your flame is still glowing today. One short lesson keeps it lit! |
| several kids | Qui veut jouer au village aujourd'hui ? | Who wants to play in the village today? |

The copy follows the **kid's** app language. A merged reminder for several
kids uses the language most of them have set, and French on a tie.

### What I need from Hafid

1. Local only, with push left out until counsel: yes or no?
2. On Linux, reminders only while the app is running, and none on web. Is
   that acceptable until mobile ships?
3. `questNotifications`: relabel it as "Ma flamme", or remove it?
4. Is 08:00–19:30 the right window, and is 3 ignored days the right
   back-off?

Cost once approved: a spike (½ day), then the scheduler, the policy and
its tests (1 day), then the Réglages tab, permission and deep link (½ day).

---

## C. School language subjects (waiting for Backend's contract)

Not planned in detail until the contract is out. What I'll check against
it:

- The subject lists are hard-coded in four places. A kid-driven
  `subjectsFor(kid)` would replace them:
  - `pathSubjects` in `path_controller.dart`;
  - `quest_board.dart`'s `realSubjects`;
  - `subject_pills.dart`;
  - `learning_areas.dart`.
- **`subject_language.dart`:**
  - Instructions follow the app language.
  - ESL is English *content* for a francophone kid, so its instructions
    stay in the app language.
  - ELA is English throughout.
  - French as a second language is French content with English
    instructions.
  - The rule needs to know *which* English and *which* French, not just
    `EN`/`FR`.
- Village buildings and labels: probably one "Anglais"/"English" building
  whose label and tree depend on the school. New art isn't needed.

## D. Unchanged

- The "Qui joue ?" wait times stay at 10 min (family) and 2 min (class).
- D6 is unchanged: `answer_payload` keeps being sent.
