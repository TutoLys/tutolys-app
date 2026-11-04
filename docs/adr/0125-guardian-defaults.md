# ADR 0125: A guardian's answers start a child's settings

- Status: accepted
- Date: 2026-11-03
- Source: `Platforms/PLAN_PARENT_ONBOARDING_QUESTIONS.md`, approved by Hafid;
  the contract is backend ADR 0220 (`2519d5a`)

## Decisions

1. **The defaults ride `GET /me/profile`.** `AvatarController` already reads
   it on every rebuild, so it hands the `defaults` block to
   `KidDefaultsStore` and no new request exists. They are held per kid in
   `app_state` (`guardian.defaults`), so they work offline and a sibling
   gets none of them. A served `{}` clears them; a response with no block
   changes nothing. A read that finishes after the kid changed is dropped.
2. **A default is never copied into a setting.** The effective value is
   what the family set on the device, else the default, else the app's own.
   `applyKidDefaults` computes it, and `SettingsController` holds the
   result, so a later portal edit reaches anything the family never
   touched. Only `music`, `sound_effects` and `reduce_motion` have
   defaults. Réglages shows the value with no hint of where it came from.
3. **A stored key now means a choice.** Before this, one change saved every
   setting, so stored rows proved nothing. `SettingsController` now writes
   only what changed. For rows already on a device, the first read deletes
   any of the three that repeat the app default and leaves
   `settings.choices_only` behind. A value that differs from the default
   can only have been chosen, so it stays. The cost: a family that switched
   music off and back on before this update counts as never having touched
   it. That matters only if a guardian then asks for fewer sounds.
4. **Automatic reading is a per-child exception to reading on tap**
   (Hafid's D1). `auto_read_prompts: true` reads each question when it
   appears. Réglages' read-aloud off still silences it, and it never reads
   a prompt whose `speech_policy` is `never`, as in a reading test. The
   speaker stays. There is no separate Réglages control: read-aloud off is
   how a family stops it. Only the new runtime does this; the legacy host
   serves nothing published.
5. **The "Joue N minutes" target follows `session_minutes`.** The backend
   still pays that quest on its own target (`QUEST_MINUTES_TARGET`), so
   where the two differ the quest shows no XP chip, the rule the quest
   board already follows for a promise nobody keeps. Asked of Orgs & tutors.
6. **The pause is one line on the celebration.** It shows when today's
   play time, the same measure as the quest, has reached `session_minutes`.
   Nothing else changes: both buttons stay, and it is never read aloud.
   Today's total means a kid who played in the morning sees it after their
   first lesson that evening; a true session timer isn't worth a second
   clock for one soft line. Practice records no time, so it never offers one.
7. **`first_subject` opens Carte, and with it Village's recommended lesson,**
   which reads the Carte's frontier. It applies only while the subject is
   in the kid's programme, the kid hasn't picked a subject since launch,
   and this device has no played day. That last check is needed because
   the server stops sending it only at the first mastery row, which lags a
   lesson. Progrès keeps its own subject.

## Consequences

- `PARENT_QUESTIONS_ENABLED` is off in production until counsel answers, so
  there `defaults` is always `{}` and none of this shows.
- The defaults reach the settings a moment after the first frame on a
  launch. They don't hold the splash: a slow read must not delay the app
  for three settings that aren't the theme or language.
