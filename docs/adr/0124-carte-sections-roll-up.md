# ADR 0124: The Carte's sections roll up

- Status: accepted
- Date: 2026-11-03
- Source: Hafid's ask, relayed by the Manager: "Can we make them collapse in
  a fun and cool way"

## Decisions

1. **Each section has a header row that is the tap target.** It shows the
   title, a count (« 3/7 »), a mini orb trail of at most 8 dots, and a
   chevron. The trail shows while closed. A long section samples its
   progress across the dots, and the next lesson's dot is gold.
2. **Only the section holding the next lesson starts open,** so the Carte
   opens on what's next. While closed, that section's header shows the fox.
3. **A kid's own choice wins and is remembered,** per kid, in one
   `app_state` row (`carte.sections`), keyed by the section's first leaf so
   it survives a language change.
4. **One exception: when a finished lesson moves the next lesson into a
   section, that section's choice is dropped,** so it opens. A kid must not
   finish a lesson and land on a closed Carte. Only a finished lesson does
   this, not a subject switch or a late sync.
5. **The roll-up is one 340 ms motion.** A clip edge moves up the path, each
   orb shrinks as the edge reaches it, and the trail's dots pop in one by
   one, the last orb's first. Opening is the same in reverse, and a tap
   mid-roll turns it around. The chevron overshoots slightly. This is shell
   UI, so ADR 0118's engine rule doesn't apply. Only the header's fox
   loops, and `BreathingMascot` already stops when its tab is hidden.
6. **A long path keeps the same duration.** The edge covers the first 900 px
   evenly and the rest in the motion's last beat, so what the kid can see
   gets most of the time.
7. **Reduced motion is an instant toggle:** no frames between open and
   closed.
8. **A closed section builds no path.** Its orbs are out of the tab order,
   and Français stays cheap however many sections it has.
9. **Opening a section brings it into view:** to the next lesson if it's in
   there, otherwise only if the header was in the lower half of the screen.
10. **A subject with one section has no header** and stays as it was.

## Consequences

- The header row repeats the pinned strand title when a section sits at the
  very top. The pinned title stays, because it names the section while the
  kid scrolls inside a long one (Hafid's "freeze row").
- Tests that reach an orb outside the next lesson's section now open that
  section first.
- Orb tap targets are unchanged once a section is open.
