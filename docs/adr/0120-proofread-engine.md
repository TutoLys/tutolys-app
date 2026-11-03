# ADR 0120: proofread, Le brouillon de Léa

Date: 2026-11-03 · Status: accepted
Source: `Platforms/PLAN_GRADES_2_6_ENGINES.md` §2.2 #2, step 2 of §2.3.
Hafid's go on 2026-11-03. The backend side is backend ADR 0212.

## Context
126 français leaves for grades 2–6 are revision procedures: « relire chaque
phrase à l'aide d'une procédure », « vérifier et corriger chaque type
d'accord », « vérifier l'orthographe des mots »… The child's own text never
enters the app, because there is no free typing (Hafid, 2026-11-03). What an
app can do is have the child apply the procedure to someone else's draft.

## Decisions
1. **A village character's draft** of 1–8 sentences, plus a **checklist of
   1–4 passes**. Each pass names what it checks (« Je vérifie la finale des
   verbes. ») and its words (`targets`). A word belongs to one pass only.
2. **In each pass, the child decides every marked word.** They tap it, then
   say « C'est bien écrit » or pick a spelling. A wrong word carries `fix`
   and `options`. A right word may carry decoy options; without them, the
   only choice is to keep it.
3. **The child chooses the step order, the engine doesn't.** « Étape
   suivante » opens the next pass once this one is decided, and emits a
   `reveal` (`pass`). VALIDER, on the last pass, grades every word of every
   pass:
   - each word is an item;
   - a missed mistake and a false alarm both count as wrong;
   - right words lock;
   - a wrong decision is cleared and can't be made again;
   - the board goes back to the first step with something left.
4. **Every mistake must be in some pass**, a draft has at least one, and a
   fix is always among its options. These are checked in parse, so a
   lesson can't be unsolvable.
5. **Why not a `find_it` mode:** the flow differs. It's a staged procedure,
   with a decision per word and a fix step. Kept apart, find_it stays a
   one-tap "find the thing".

## Tests
`test/proofread_engine_test.dart` (12):
- parse, and 5 refusals;
- only the current step's words open;
- the next step waits, and reveals;
- all right is correct;
- a missed mistake and a false alarm as items, and going back to step 1;
- the same wrong choice is refused;
- snapshot round trip;
- a two-step play-through in the shell to « Bravo ! ».

`backend_samples_test` parses `samples/fr_proofread.json`.
