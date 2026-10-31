# ADR 0109: A forgotten parent PIN is reset with a fresh pairing code

- Status: accepted
- Date: 2026-10-31
- Source: `Platforms/ux-review/kid-app.md` A5 (« NIP oublié ? »); Hafid chose
  option A, relayed by the Manager

## Context

The parent PIN lives only on the device (ADR 0010), so the website can't
reset it, and before this a forgotten PIN cost a full sign-out the PIN itself
guards. A5 skipped « NIP oublié ? » because the app couldn't honestly offer
one. Two options went to Hafid: (A) prove you're the adult with a fresh
pairing code from the portal, or (B) a backend reset. He chose A.

## Decisions

1. **« NIP oublié ? »** sits under the PIN field, and stays live while the
   gate waits after wrong tries, when it's needed most.
2. It explains, in "vous": on the site, open Appareils, create a pairing code
   for one of your children, and type it here. The six boxes are the pairing
   screen's (`TutolysCodeField`, same alphabet).
3. **A good code is an ordinary kid pairing** (`resetGuardianPinWithCode`).
   Only someone signed in to the portal can make one, which is the proof.
   - For the kid playing, it renews their device token, as re-pairing always
     has.
   - For another of the family's children, it adds them, like « Ajouter un
     profil ». The kid who was playing stays active.
   - A refresh in flight is awaited first, so a late answer on the old token
     can't drop the kid as revoked.
4. Then the PIN and its wrong-try count are cleared (`clearGuardianPin`), and
   the adult chooses a new one. The guarded action goes ahead only once they
   have. « Plus tard » leaves no PIN, and the next gate goes through the adult
   check (A5).
5. **No backend change.** A rejected, offline or seatless code shows the
   pairing screen's own messages, and the PIN stays.

## Consequences

- A child can't use it: making a code needs the parent's portal session.
- A class tablet has no kid codes. A teacher who forgets the PIN still
  re-pairs the class.
