# v9 plan: Smash-style combat, Walled City, Forest, Cave + Fairy

Written 2026-11-15 at the end of the v8 session, for a fresh session.
Recommended: run the new session on Fable (`/model`). Helper agents (also on
Fable) can build the city / forest / cave layouts in parallel while the main
session does combat (Part A). Read CLAUDE.md first (design + input contracts).
Every CLAUDE.md contract line that changes must be updated in the same change.

State at hand-off: v8 committed (4d4ccd4), 1920/1920 tests across 22 suites.
Relevant existing systems:
- Player state machine: `src/player/states/*`. v8 added DodgeReady and Focus.
- Combo: `src/combat/combo_component.gd` + MeleeStrike state.
  - Tap = light, hold = heavy; 3-step string.
  - Per-member BasicAttackProfile (`src/combat/basic_attacks/`).
- Unique ability (Y in battle): `src/combat/stance_component.gd` + `unique_abilities/`.
  - Amaro = Arcane Stance; Taighe = Arcane Focus (channel).
- Lock-on: LockOnComponent, LockOnIdle / LockOnStrafe states.
  - Target switch is on D-pad Left/Right today.
- Quests: QuestManager autoload + `src/quests/`.
- Shops, inventory and equipment exist (Phase 9).
- Party: PartySystem.
  - Swaps identities on one Player body.
  - CompanionAI drives the other body.
- Zones extend `src/world/zone_base.gd`.
  - ZoneBounds (walls + edge line) and lit ZonePortals (v7).
- Rigless models: RiglessVisual (procedural motion; Hunyuan .glb models).
  - New models only after the user approves them (`docs/rigless_models.md`).

---

## Part A: Combat (Smash Bros style)

### A1. Lock-on rework (Right Trigger)
- Tapping RT locks onto the nearest enemy. Further taps cycle to the next enemy.
- Holding RT (about 0.5 s) leaves lock-on.
- Lock-on visuals:
  - A red reticle around the locked enemy.
  - A "LOCK-ON" banner at the top of the screen while it is active.
- Movement while locked on is centred on the target:
  - The hero always faces the target.
  - Back = walk backwards; left/right = circle-strafe.
  - Amaro (rigged, walk clip only): play the walk in reverse for back, and an
    in-place side-lean variant for strafe.
- Keep the D-pad target switch as well, unless the user says otherwise.
- Keyboard: middle mouse does the same (tap / cycle / hold to exit).

### A2. Dash into sprint
- A forward dodge with the stick still held forward goes straight into a sprint
  run (faster than L3 run).
- Releasing the stick stops it. Works in Free Roam and Battle.

### A3. Dash attack
- Tapping X while sprinting gives a dash attack that can chain into a short combo
  (2-3 hits).

### A4. Directional attacks (Smash style)
- Direction is the stick relative to the lock-on target (or relative to facing
  when not locked on).
- Each of the four directions plus X is a different attack:
  - neutral X = the existing 3-step light/heavy combo;
  - forward + X, back + X, left + X, right + X = four separate attacks.
- Example set for Amaro (to be confirmed with the user):
  - forward: lunge stab;
  - back: retreating cut that hops away;
  - left/right: sweeping cuts that move you to that side.
- Taighe gets magic versions (bolt spread, frost wall, side-step shots...).

### A5. Directional specials (Y in battle)
- neutral Y = the current unique ability.
- forward / back / left / right + Y = four more special moves per character.
  - Example: back + special is different from forward + special.
- Specials cost MP or have cooldowns.

### A6. Weaving (cancel routes)
- Attacks can cancel into specials and dodges, and dodges into attacks.
- Defined per character in data (a cancel table on the profile), so Amaro and
  Taighe play differently.
- Contract rules that still apply:
  - spells / skills cannot cancel into dodge;
  - basic attacks can.

### A7. Data-driven move list
- Every move lives in data with these fields:
  - name, input, power, speed (startup/active/recovery), MP cost, stagger,
    effects.
- The AI companion uses a subset.

### A8. Move List screen (Start / Pause menu)
- A new "Move List" page.
- Pick a character to see:
  - their portrait;
  - a table of every move: name, controls (button glyphs), power, speed, MP,
    stagger, special effects.
- It is generated from the A7 data, so it can never get out of date.

---

## Part B: Walled City (new starting area, replaces the current town)

- New Game starts here. The current town hub is retired.
- Update every portal, save id, minimap and test that uses `town_hub`.
- Layout:
  - Tall stone walls all around.
  - A gate at one end.
  - One main street running to a large, simple castle at the far end.
- Buildings: houses and buildings line both sides of the street, so it never
  looks empty.
- Shops along the street:
  - a new Weapon Shop;
  - every shop the current town already has.
- Quest giver just inside the gate:
  - Talking to him gives quest 1.
  - A popup shows the new quest, and the tracker on screen updates.
- Exit gate to the Forest (lit exit, v7 style).

## Part C: Forest

- Trails through the trees, a ZoneBounds edge, and lit exits (back to the city,
  and into the cave).
- Monsters:
  - Several groups along the trails.
  - Groups come back over time, so kill counts can always be finished.
- Rangers: NPCs you can talk to and take quests from.
- Cave entrance leading to the Cave area.

## Part D: Cave + Fairy companion

- The Cave is a small, darker handcrafted area.
- Cave quest: find the magic fairy.
  - Once found, she guides you through the cave and out.
- The fairy is a permanent GUEST ally:
  - Always AI-controlled and never swapped in.
  - Her own HP and MP.
  - Her own attacks and magic.
  - She follows and floats near the player.
- She has to fit beside PartySystem's 3 active / 3 reserve rule.
  - Proposal: a separate guest slot that does not count toward the 3.
- She is saved and loaded with the party.

## Part E: Quests

- Quest 1, given by the city quest giver: "Kill 10 monsters in the Forest".
  - Tracker shows 0/10 ... 10/10, then "return to the quest giver".
  - Reward: a lot of gold + weapons, and the quest giver sends you to the cave
    (this starts Quest 2).
- Quest 2, "The Cave" (chained, confirmed by the user 2026-11-15):
  - Go to the cave and find the fairy; she guides you through it.
  - Reward: the fairy joins as a permanent guest ally.
- Ranger quests (Part C): 1-2 simple ones to start, for example "clear the trail
  camp" or "bring back 3 pelts".
- All quest state saves and loads.

## Part F: Assets

### Already in the repo (assets/models/characters)
- alchemist_female1, goblin_male2, goblinchief_male1, kobold_female1,
  kobold_queen1, pirate_female1, princess1 (Taighe), teacher_female2.
- Plus the red knight (Amaro).

### Needed from the user (Hunyuan), by priority
1. City buildings:
   - 2-3 house variants;
   - shop fronts: weapon shop, item shop, inn;
   - castle;
   - wall segment + gate;
   - market stall;
   - well or fountain.
2. City NPCs:
   - quest giver (guard captain or elder);
   - weapon smith;
   - shopkeeper;
   - 3-4 townsfolk (male/female, young/old);
   - 1-2 guards.
3. Forest props:
   - 3-4 tree types (pine, oak, dead tree);
   - bushes;
   - rocks / boulders;
   - fallen log;
   - tree stump;
   - ranger camp (tent + campfire).
4. Forest NPCs: 2 rangers (one male, one female).
5. Monsters (forest): 2-3 types, for example wolf, giant boar, forest goblin
   (goblin_male2 can stand in), and spider.
6. Cave:
   - entrance arch / rock face;
   - stalagmites;
   - glowing crystals;
   - a cave monster (bat or slime).
7. Fairy companion (the user is generating her).
8. Weapons (shop / reward):
   - 3-4 swords for Amaro;
   - 2-3 staves for Taighe.
   - Icons are fine at first; models are needed for visible equipment.
9. Portraits for the Move List screen (A8): Amaro, Taighe and the fairy.
   - A rendered capture of each model is acceptable at first.

Until models arrive, use simple primitive placeholders (boxes / cylinders
coloured per type), so the layouts and quests can be built and tested first.

---

## Order of work (suggested)

1. A1 lock-on rework (needed by A4 / A5).
2. A7 move data → A4 directional attacks → A2 / A3 dash → A5 specials → A6
   cancels → A8 Move List screen.
3. B city (placeholder buildings) + New Game hook + retire town_hub.
4. C forest + E quest 1 (kill 10) + rangers.
5. D cave + fairy guest ally + the rest of the quest chain.
6. Swap placeholders for the user's models as they arrive.

Each step: tests (new suite tests/test_v9.gd, plus updates to old suites
where the contract changes), full regression, CLAUDE.md contract lines,
project_status.json, then report to the user. Commit only when asked.
