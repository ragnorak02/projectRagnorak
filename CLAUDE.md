# GLOBAL RULES (LUMINA)

This project inherits the LUMINA studio rules.

Non-negotiable:

- Claude must verify work before declaring completion
- Claude must confirm working directory before changing files
- Claude must print scene trees after scene modifications
- Claude must not skip unstable foundations
- Claude must not mark checklist items complete without proof
- Claude must not expand future systems before current systems are stable
- Claude must respect completed systems and extend architecture instead of rewriting stable working systems
- Claude must prefer deterministic, modular systems over fast one-off implementations
- Claude must not silently change design contracts defined in this file
- Claude must keep controller-first support working at all times

If local rules conflict with global rules, **global rules win**.

---

# Mandatory Verification Protocol

Claude must run verification before completing tasks involving:

- code changes
- scene changes
- gameplay systems
- UI systems
- signals or input systems
- save/load systems
- combat systems
- AI systems
- camera systems
- party systems
- zone streaming systems

Verification output must include:

- scene node tree
- attached scripts
- signal connections
- interaction confirmation
- current phase item(s) completed
- tests run
- pass/fail summary

Completion without verification output is **invalid**.

---

# Implementation Protocol

Before implementing any major feature Claude must:

1. Explain the architecture change
2. List files to modify
3. Identify which phase/checklist items are being worked on
4. Implement the feature
5. Run verification
6. Print verification proof
7. Update project_status.json if milestone/progress changed

Claude must not silently modify large systems without explanation.

---

# PROJECT

Title: **Ragnorak**
Internal Energy/World Core Name: **Lumina**
Engine: Godot 4.6
Renderer: 3D (Forward+)
Camera: Freely rotatable third-person action camera
Platform: PC
Primary Input: Xbox Controller
Secondary Input: Keyboard + Mouse

Executable Path:

Z:/godot/godot.exe

Combat Inspiration:

Final Fantasy VII Remake style hybrid combat:
- real-time movement and attacks
- tactical slow-time menu
- ATB-based command execution
- party switching
- stagger windows
- character synergy

Team Attack Inspiration:

Chrono Trigger style combo attacks:
- duo techniques
- trio techniques
- character ability synergy
- shared payoff windows

---

# LUMINA Studio Rules

- `project_status.json` is the **single source of truth**
- `CLAUDE.md` defines development checkpoints, architecture, and design contracts
- Launcher reads **JSON only**
- Never delete checklist items
- Mark unused items **N/A**
- Timestamps use **ISO8601 minute precision**
- All major systems must be testable
- Debug flags must default false
- Stable completed phases must not be casually rewritten
- If the repo already passed tests, preserve that stability first

---

# Launcher Contract

Required files:

game.config.json
project_status.json
achievements.json

Test command: `tests/run-tests.bat`
Headless boot: `Z:/godot/godot.exe --path . --headless --quit-after 1`
Headless test: `Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn`

Launcher metadata must remain valid.

---

# Godot Execution Contract (MANDATORY)

Godot installed at:

Z:/godot

Claude MUST use:

Z:/godot/godot.exe

Rules:

- Never assume PATH
- Never use a different Godot install
- Never use Downloads folder engine copies
- Never reinstall the engine
- If new `class_name` scripts are added, run import when needed

## Headless Boot

Z:/godot/godot.exe --path . --headless --quit-after 1

## Headless Test Runner

Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn

## Script Registration

If adding new `class_name` scripts:

Z:/godot/godot.exe --path . --headless --import

---

# Project Overview

Ragnorak is a fantasy hybrid action RPG inspired by Final Fantasy VII Remake.

It is a controller-first 3D combat game with:
- tactical slow-time menu
- ATB-based command execution
- semi-open world exploration with connected zones
- handcrafted dungeons
- traversal-based progression
- party mechanics
- reactor-city worldbuilding
- post-catastrophe world-state shift

---

# World Lore — Lumina

The world is powered by an energy source called **Lumina**.

Lumina powers:
- cities
- military infrastructure
- magic systems
- reactors
- magical technology
- industrialized fantasy civilization

Lumina performs best when **super-cooled**.

Because of this:
- many reactors are built underwater
- other reactors are embedded in glaciers or iceberg regions
- frozen coasts and ocean cities become major energy centers
- some towns grow around reactor infrastructure

Lumina is both:
- an industrial power source
- a magical force tied to civilization itself

---

# World Event — Ragnorak

At the midpoint of the story a catastrophic event called **Ragnorak** occurs.

Effects:
- Lumina becomes corrupted
- magical instability spreads
- spirits begin appearing
- monsters emerge in areas that previously had only soldiers and machines
- the world grows darker and more mystical
- combat systems escalate
- Light and Dark elements become available later in progression

Before Ragnorak:
- enemies are mostly soldiers and machines
- conflict is more political / military / industrial

After Ragnorak:
- enemies include monsters, corrupted spirits, magical abominations
- the tone shifts toward corruption, survival, and supernatural conflict

---

# Core Gameplay Loop

Large Hub Town
-> Explore Connected Zones
-> Fight Enemies (Real-Time + Tactical)
-> Obtain Gear / Materials
-> Complete Quests
-> Unlock Traversal Abilities
-> Access New Areas
-> Progress Story
-> Experience Ragnorak World Shift
-> Re-explore altered world
-> Repeat

---

# Core Pillars

- Controller-first gameplay feel
- Satisfying hybrid tactical combat
- Exploration through traversal progression
- System stability over feature speed
- Deterministic, bug-resistant architecture
- Distinct reactor-fantasy world identity
- Party synergy through coordinated combat
- Midpoint world-state escalation

---

# Main Characters

## Protagonist

Name: **Amaro**

Background:
- village boy
- joins the local military
- becomes involved in Lumina conflict

Combat identity:
- Magic Knight
- sword + magic hybrid
- balanced melee fighter
- moderate speed
- magic woven into combos
- rooted while casting unless a later explicit mechanic changes that rule

## First Party Member

Name: **Taighe**

Description:
- female
- long blue hair
- mage archetype

Combat identity:
- ranged elemental caster
- support damage
- synergy partner for Amaro
- strong fit for combo/team attacks

---

# Party Structure

Party size:
- 3 active
- 3 reserves

Rules:
- player controls one active character at a time
- inactive active-party characters use AI
- reserve party members can be swapped in when allowed
- switching has a short cooldown
- party members join later via story progression
- party members may unlock traversal functions
- party systems must not begin until single-character combat slice is stable

---

# Team Attack System

Inspired by Chrono Trigger.

Rules:
- abilities can combine between characters
- duo and trio attacks exist
- team attacks are based on character ability combinations, not generic supers
- team attacks consume a shared team meter
- team attacks should benefit from stagger windows and tactical planning
- team attacks must remain readable and animation-safe

Example directions:
- Amaro melee slash + Taighe ice burst
- Wind lift + fire detonation
- Earth bind + aerial finisher

---

# Element System

Early game elements:
- Fire
- Ice
- Wind
- Earth

Post-Ragnorak / later progression:
- Light
- Dark

Rules:
- Light and Dark do not appear in standard early-game progression
- Their unlock should feel like a true world-state escalation
- Enemy resistances/weaknesses may expand after Ragnorak
- Party combat design must account for 4 early elements and 2 late elements

---

# World Structure

The world is semi-open and mostly seamless.

Rules:
- connected explorable regions
- loading boundaries are allowed at major transitions
- no traditional overworld map required
- zone boundaries may exist at gates, caves, dungeons, elevators, deep facilities, etc.

World includes:
- several large hub towns
- smaller towns / villages / outposts
- field routes
- military facilities
- reactor cities
- coastal and frozen regions
- handcrafted dungeons
- hidden traversal-gated areas

Puzzles:
- light
- simple
- traversal-oriented
- never the main focus over combat/exploration

---

# Town Design

Large hub towns can contain:
- vendors
- inn/save points
- military presence
- reactor infrastructure
- major story NPCs
- equipment services
- quest hubs

Smaller towns can contain:
- side quests
- rest/shop functions
- localized story beats
- travel staging

---

# Architecture Summary

## Autoloads

- Events — Signal bus for cross-system communication
- GameManager — Global game state, pause stack, time scale stack, hit stop
- InputManager — Device detection, action helpers, controller-first routing
- AudioManager — SFX pool and music playback
- SaveManager — Save/load with autosave, manual, quicksave
- PartyManager — Active/reserve party composition, swapping rules
- QuestManager — Quest state, objectives, tracker
- DebugFlags — Global debug toggles

## Scene Structure

- MainMenu -> GameWorld -> Zone scenes
- Player persists in GameWorld shell
- Zones load as children of ZoneContainer
- Camera rig follows active player character
- World streaming boundaries and load transitions are isolated in dedicated systems
- Boss arenas use explicit scene ownership and transitions

## State Machine Architecture

Separate state domains must exist and remain independent:

- LocomotionState — Idle, Run, Jump, Fall, Land, Dodge, Climb, WallRun, Glide
- CombatState — Attack1-3, JumpAttack, Ability, Flinch, Staggered, Downed
- TargetingState — LockOnIdle, LockOnStrafe, TargetSwitching
- TacticalMenuState — TacticalIdle, TacticalSelecting, TacticalExecuting
- CameraState — Free, LockedOn, Reset, Obstructed
- EnemyAIState — Idle, Patrol, Chase, Reposition, Attack, Hurt, Staggered, Dead
- BossState — Intro, Phase1, Phase2, Break, Enraged, Death
- PartyState — Solo, ActiveParty, Switching, DownedMember, ReserveSwapPending

## System Ownership

- PlayerController -> movement input
- CombatSystem -> combo flow and attack logic
- AbilitySystem -> spell/skill execution
- TargetingSystem -> target acquisition/switching
- CameraRig -> orbit/collision/framing
- TacticalMenu -> slow-time/menu state
- EnemyBrain -> enemy decisions and spacing logic
- BossBrain -> boss phase and arena logic
- SaveSystem -> persistence
- InventorySystem -> item/equipment data
- QuestSystem -> active objective tracking
- PartySystem -> active/reserve state, ally AI contracts
- TraversalSystem -> traversal flags and gate evaluation

No system may directly own another system’s state.

---

# CORE DESIGN CONTRACT

## Fixed Rules

- [ ] Protagonist has fixed identity and story
- [ ] Game is gameplay-heavy with light story
- [ ] World uses Lumina as core energy source
- [ ] Lumina powers cities, reactors, and magic infrastructure
- [ ] Lumina reactors prefer underwater and glacial cooling
- [ ] World is semi-open with connected zones
- [ ] Large regions may use loading transitions
- [ ] Several large towns exist
- [ ] Smaller towns / villages also exist
- [ ] Dungeons are handcrafted and deterministic
- [ ] Puzzles are light and simple
- [ ] Basic attacks are unlimited (no stamina)
- [ ] Spells use MP
- [ ] Tactical mode slows to 5%
- [ ] Tactical mode is free to open
- [ ] Tactical mode cannot execute without ATB/resources
- [ ] Tactical mode may open with zero ATB for observation
- [ ] Dodge is timing-based
- [ ] Dodge has no invulnerability frames
- [ ] Basic attacks cancel into dodge
- [ ] Spells/skills cannot cancel into dodge
- [ ] Enemies may interrupt casting
- [ ] Lock-on prefers nearest enemy
- [ ] Camera shifts toward locked target
- [ ] Attacks softly track toward target
- [ ] Jump attacks exist in free roam
- [ ] Jump is free-roam only; battle uses abilities for lift
- [ ] Game has two modes: Free Roam and Battle (Battle starts when any enemy engages, ends 3s after the last disengages)
- [ ] Basic attack X: tap = light, hold = heavy; 3-step mixable combos, step 3 is a finisher (blast scales with heavies)
- [ ] Each character has a unique ability on Y in battle (Amaro: Arcane Stance)
- [ ] Command Menu can open while airborne
- [ ] Battle/Free Roam can be toggled by hand; a manual stand-down suppresses auto-battle until damage is dealt/taken or a new enemy engages
- [ ] Offensive commands always open the target step (enemies nearest-first + Fire Forward)
- [ ] Per-spell range: target list and lock-on reach = active member's max offensive range; rows beyond the selected ability's range are darkened "Out of range" and cannot be confirmed; Fire Forward always works. Out of range: the reticle dims while the "OUT OF RANGE" label stays large on a dark pill; the target bar keeps its dark panel and dims only its content
- [ ] Party switch swaps identities, not bodies (data, HP/MP/ATB, commands, model, position); camera/lock-on/state machine stay on the Player node; 1.0s cooldown; blocked in dodge/cast/attack/flinch/carry/menus/dialogue/dead
- [ ] Abilities v5: Sword Slash (Amaro, 0 MP), Water Geyser and Wind Crescent (Taighe, spawn at target); Taighe unique = Super Jump (~5x jump)
- [ ] Aerial Command Menu: opened airborne it lists aerial_only abilities first (Plunge Strike / Air Burst); ground_only rows grey "Grounded only"
- [ ] Air combo holds altitude (up to 3 L/H strikes, ~2 m/s drift, once per airtime); air dodge once per airtime, stick-back = backflip, otherwise air dash
- [ ] Lock-on camera keeps the target at least 18 degrees beside the player
- [ ] Menus navigate through MenuNav (stick hysteresis + hold repeat, unscaled); never step a menu on a raw joypad-motion press
- [ ] Settings > Options: Minimap On/Off, Minimap Rotating/North-Up, Control Hints, Damage Numbers
- [ ] Rigless models: RiglessVisual gives un-rigged meshes procedural motion and never mutates the body; generated (Hunyuan) materials have metal stripped on load; new models only after user approval (docs/rigless_models.md)
- [ ] HUD: Free Roam/Battle chip top-left, control hints bottom-left, minimap top-right (rotates with camera; enemies red, NPCs white, chests gold, exits cyan; hidden in full-screen menus/dialogue)
- [ ] Basic attack is data-driven per member (PartyMemberData.basic_attack_profile): Amaro = sword combo; Taighe = mage bolts (tap = quick bolt, hold = charged shot, soft-track lock-on, 0 MP, builds stagger), mixable L/H 3-step whose step 3 is a ranged burst scaling with heavies (Arcane Burst 2 m -> Lumina Nova 4.5 m); same timing, dodge-cancel and air-combo rules as melee; AI-controlled members use the same profile
- [ ] Enemies pick a target among the party by threat (damage dealt, proximity, stickiness, crowd spread), keyed by member id so a party switch keeps the enemy on the same member; re-evaluated every 0.5 s, voluntary switches at most once per 2 s; downed/dead members are dropped at once
- [ ] Spacing around ANY targeted member: ring slots at preferred radius (attack_range - 0.2, 1.8 m), stop distance 1.5 m from every party member (downed included), enemy separation 1.3 m, at most 2 simultaneous attackers per member
- [ ] AI companion has a Hurtbox (same layers as the Player): hits flinch it (0.45 s, no actions, string interrupted); 0 HP = downed (no actions, not targetable, hurtbox off, switch onto it blocked)
- [ ] Rigged models never show a T-pose: Amaro's idle is a held walk pose (passing frames averaged) with a cosmetic IdleLayer bob/lean; the walk is in place and loops; this holds when AI-controlled and in the Command Menu
- [ ] NPCs face the street/approach path by default (_add_npc face_point); model NPCs turn toward the player during dialogue and back after (cosmetic, RiglessVisual)
- [ ] Dungeon elite Goblin Chief: 2.4 m rigless model, with the body (capsule/hurtbox/lock-on/health bar) scaled to match
- [ ] Ability VFX are translucent additive (unshaded, no depth write) and fade within 0.25 s (Sword Slash); multi-hit spells show a hit flash per hit; the target stays readable through every effect
- [ ] Ledge grab is automatic
- [ ] Quicksave disabled in combat
- [ ] Enemy states reset per zone
- [ ] 3 active party members supported
- [ ] 3 reserve party members supported
- [ ] AI companions control inactive members
- [ ] Team attacks use shared team meter
- [ ] Party members may provide traversal abilities
- [ ] Equipment visually changes character
- [ ] Amaro is a melee/magic hybrid
- [ ] Taighe is an elemental mage
- [ ] Early elements are Fire/Ice/Wind/Earth
- [ ] Light/Dark unlock after Ragnorak
- [ ] Ragnorak alters world state and enemy composition
- [ ] Early enemies are soldiers and robots
- [ ] Post-Ragnorak enemies include monsters and spirits
- [ ] Bosses use multi-phase design
- [ ] Bosses may use breakable parts
- [ ] Bosses may use rage/enrage states
- [ ] Traversal includes Double Jump, Wall Run, Glide
- [ ] Party switching has slight cooldown
- [ ] Team attacks are combo-based and character-specific
- [ ] Enemy spacing must prevent overlap with player

---

# INPUT CONTRACT (MANDATORY)

## Xbox Controller

- [ ] Move -> Left Stick
- [ ] Camera -> Right Stick
- [ ] Jump -> A (Free Roam only)
- [ ] Command Menu -> A (Battle)
- [ ] Attack -> X (tap Light / hold Heavy)
- [ ] Dodge -> B
- [ ] Interact / Pick up / Carry -> Y (Free Roam, prompt shown; tap Y put down, hold Y aim, X throw)
- [ ] Command Menu -> Y (Free Roam, no prompt shown)
- [ ] Unique Ability -> Y (Battle)
- [ ] Run -> L3 (hold, Free Roam)
- [ ] Menu confirm -> A / Menu back -> B (one layer)
- [ ] Lock-On -> Right Trigger
- [ ] Camera Reset -> Right Stick Click
- [ ] Pause -> Start
- [ ] Target switch -> D-pad Left/Right
- [ ] Target switch left supported
- [ ] Target switch right supported
- [ ] Character switch -> D-pad Up/Down (gated)
- [ ] Character switch supported
- [ ] Battle / Free Roam toggle -> View
- [ ] Party switch -> D-pad Up/Down
- [ ] Target step: A confirm, Y Fire Forward, B back
- [ ] LB / RB / LT unbound (reserved)
- [ ] Tactical menu full navigation supported
- [ ] Inventory/menu full navigation supported
- [ ] No gameplay-critical mouse-only behavior exists

## Keyboard / Mouse

- [ ] Move -> WASD
- [ ] Camera -> Mouse
- [ ] Jump -> Space (Free Roam only)
- [ ] Attack -> Left Mouse (tap Light / hold Heavy)
- [ ] Dodge -> Shift
- [ ] Run -> Left Ctrl (hold)
- [ ] Interact -> E
- [ ] Tactical/Command Menu -> Q (both modes)
- [ ] Unique Ability -> R (Battle)
- [ ] Battle / Free Roam toggle -> F
- [ ] Party switch -> Tab
- [ ] Target step: Enter/Space confirm, E Fire Forward, Esc back
- [ ] Lock-On -> Middle Mouse
- [ ] Pause -> Escape
- [ ] Keyboard fallback works through full game loop

## Input Validation

- [ ] Controller works from title through gameplay
- [ ] Keyboard works from title through gameplay
- [ ] Input device switching does not lock controls
- [ ] Menus work on controller
- [ ] Menus work on keyboard
- [ ] Tactical mode usable on controller
- [ ] Tactical mode usable on keyboard
- [ ] Party switching usable on controller
- [ ] Camera reset usable on controller
- [ ] Lock-on switching usable on controller
- [ ] A never jumps in battle; Y never interacts in battle
- [ ] B in every menu backs out one layer

---

# COMBAT IDENTITY

Combat style is a **middle-ground hybrid**.

Rules:
- moderate speed
- not slow/heavy like pure greatsword combat
- not hyper-fast like pure character action
- magic can be mixed into combos
- melee and magic should feel integrated
- grounded readability is more important than spectacle spam

Amaro-specific direction:
- melee chain can lead into magical follow-up
- magic can complement combos rather than replacing them
- tactical mode remains central to command flow
- animation timing must stay readable and safe

---

# ENEMY DESIGN RULES

Early game enemies:
- soldiers
- guards
- local military opponents
- robots / security units

Post-Ragnorak enemies:
- monsters
- corrupted spirits
- magical abominations
- corrupted machine/magic hybrids

Enemy archetypes:
- melee chaser
- ranged pressure unit
- defensive guard
- stagger-heavy brute
- support caster
- aerial harassment enemy
- boss elite

---

# ENEMY COMBAT SPACING RULE (MANDATORY)

Enemies must **never overlap the player**.

Required behavior:
- enemies stop at valid attack range
- melee enemies maintain roughly **5–10 feet** spacing
- enemies circle or reposition instead of dogpiling
- enemies avoid occupying the same point as the player
- enemies avoid unnecessary overlap with each other
- attack animations must land from proper range rather than model-overlap

Required AI logic:
- preferred combat radius
- stop distance
- retreat/reposition logic
- local separation or ring slotting
- attack queueing or staggered entry logic for groups
- lock-on-safe movement around player

Verification required:
- 1v1 spacing
- 1v2 spacing
- 1v3 spacing
- lock-on during reposition
- tactical mode while enemies reposition
- no sliding into player collider
- no camera collapse due to stacking

---

# STAGGER SYSTEM

A stagger system must exist.

Rules:
- enemies build stagger through pressure, weakness exploitation, specific skills, or combo routes
- staggered enemies take increased damage
- team attacks should strongly benefit from stagger windows
- bosses may use stagger thresholds, break windows, or stagger phases
- stagger should deepen combat without making all enemies trivial

---

# TACTICAL MODE RULES

Tactical mode behavior is fixed.

- [ ] Opens at any time unless explicitly blocked
- [ ] Slows game to 5% speed
- [ ] Shows Abilities / Magic / Items
- [ ] Can open with zero ATB for observation
- [ ] Commands grey out when unavailable
- [ ] Disabled during stun
- [ ] Disabled during knockdown
- [ ] Disabled during cutscenes
- [ ] Disabled during invalid forced states
- [ ] Opening tactical mode must not corrupt combo state
- [ ] Opening tactical mode must not corrupt lock-on state
- [ ] Closing tactical mode must restore correct time scale

---

# 3D COMBAT BUG PREVENTION RULES

## State Machine Separation

- [ ] LocomotionState exists
- [ ] CombatState exists
- [ ] TargetingState exists
- [ ] TacticalMenuState exists
- [ ] CameraState exists
- [ ] EnemyAIState exists
- [ ] BossState exists
- [ ] PartyState exists
- [ ] States cannot overlap ambiguously
- [ ] Illegal transitions blocked
- [ ] SpellCast cannot transition to Dodge
- [ ] Stunned cannot enter TacticalMode
- [ ] Knockdown blocks ability use
- [ ] Cutscene blocks TacticalMode
- [ ] Pause blocks combat execution
- [ ] Dead blocks movement and abilities
- [ ] CharacterSwitch cannot occur in illegal states
- [ ] Traversal-only states do not corrupt combat state
- [ ] Tactical mode cannot leave player in invalid recovery state

## Animation-Driven Combat

- [ ] Basic attack hit windows animation-driven
- [ ] Jump attack windows animation-driven
- [ ] Dodge startup/recovery windows defined
- [ ] Spell cast phases defined
- [ ] Interrupt windows defined
- [ ] Hit reactions defined
- [ ] Team attacks are animation-safe
- [ ] Stagger reactions have defined timings
- [ ] Boss break windows are animation-defined
- [ ] No guesswork-only timer combat where animation events are needed

## Cross-System Safety

- [ ] Systems communicate via signals or approved APIs
- [ ] UI does not directly mutate combat internals
- [ ] Camera does not directly mutate combat state
- [ ] Enemy scripts do not manipulate player camera
- [ ] Abilities do not rewrite unrelated systems
- [ ] Boss scripts do not bypass core combat ownership
- [ ] Party switching does not directly rewrite camera internals
- [ ] Traversal systems do not directly mutate combat internals
- [ ] Save/load cannot restore illegal transient combat states

---

# SCENE TREE DISCIPLINE

## Player Root

- [ ] CharacterBody3D root
- [ ] VisualRoot separated from logic
- [ ] CameraAnchor exists
- [ ] InteractionAnchor exists
- [ ] HitboxAnchor exists
- [ ] Hurtbox exists
- [ ] Ledge detection exists
- [ ] Wall run detection hook exists
- [ ] Glide support hook exists
- [ ] LockOn pivot/support exists

## Enemy Root

- [ ] NavigationAgent3D
- [ ] VisualRoot separated
- [ ] Hurtbox exists
- [ ] AttackOrigin exists
- [ ] AggroArea exists
- [ ] LockOnPoint exists
- [ ] Combat radius settings exist
- [ ] Separation/spacing hooks exist

## Camera Rig

- [ ] Separated from player visuals
- [ ] YawPivot/PitchPivot structure
- [ ] SpringArm3D for collision
- [ ] Lock-on framing support
- [ ] Camera reset support
- [ ] Obstruction recovery support
- [ ] Boss framing override support

## Boss Root

- [ ] Boss root standardized
- [ ] Boss hurtbox root exists
- [ ] Breakable parts optional support exists
- [ ] Arena controller hook exists
- [ ] Phase transition hooks exist
- [ ] LockOn priority point exists

---

# VERTICAL SLICE GATE (MANDATORY)

## Required Content

- [ ] One player character
- [ ] One enemy type
- [ ] One combat arena
- [ ] One lock-on flow
- [ ] One dodge flow
- [ ] One grounded combo chain
- [ ] One jump attack
- [ ] One spell
- [ ] Tactical menu open/close
- [ ] ATB gain and execution
- [ ] Save/load in combat zone
- [ ] Enemy spacing logic working
- [ ] Controller-first combat loop working

## Required Verification

- [ ] Player can enter combat
- [ ] Player can lock on and unlock
- [ ] Player can attack and hit reliably
- [ ] Player can dodge and recover
- [ ] Spell cast roots correctly
- [ ] Spell interruption works
- [ ] Tactical menu does not break combat
- [ ] Camera remains stable while locked on
- [ ] Save/load returns valid state
- [ ] No softlock in combat loop
- [ ] Enemies do not overlap player
- [ ] 1v3 encounter remains readable
- [ ] Controller-only loop playable

No party, boss, or advanced traversal until slice is stable.

---

# DEBUG FLAGS

All default false.

- [ ] DEBUG_COMBAT
- [ ] DEBUG_AI
- [ ] DEBUG_PLAYER
- [ ] DEBUG_CAMERA
- [ ] DEBUG_INVENTORY
- [ ] DEBUG_QUESTS
- [ ] DEBUG_SAVE
- [ ] DEBUG_PARTY
- [ ] DEBUG_BOSS
- [ ] DEBUG_TRAVERSAL
- [ ] DEBUG_TARGETING
- [ ] DEBUG_WORLD_STREAMING

---

# AUTOMATION CONTRACT

After major system updates:

- [ ] Update project_status.json
- [ ] Run headless boot verification
- [ ] Run relevant regression tests
- [ ] Print scene trees if scenes changed
- [ ] Print key verification proof
- [ ] Only then mark checklist items complete

If progress phase/current task changes, update JSON accordingly.

---

# EXPANSION GATING RULES

- [ ] Party system blocked until single-character combat stable
- [ ] Bosses blocked until lock-on/camera/tactical stable
- [ ] Traversal expansion blocked until jump/camera/ledge stable
- [ ] Additional abilities blocked until one spell pipeline verified
- [ ] World expansion blocked until save/load stable
- [ ] UI polish blocked until menu navigation stable
- [ ] Reserve party logic blocked until active party switching stable
- [ ] Team attacks blocked until party switching stable
- [ ] Post-Ragnorak content blocked until baseline world loop stable
- [ ] Advanced boss mechanics blocked until stagger implementation stable

---

# STRUCTURED DEVELOPMENT CHECKLIST

LUMINA STANDARD — EXPANDED RAGNORAK CHECKLIST — 560 ITEMS

Completed steps archived in `completed_steps.md`.

---

# COMPLETED PHASES (1-384) — See completed_steps.md

- Phase 1 — Foundation & Project Setup (1-20) — COMPLETE
- Phase 2 — Player Locomotion Core (21-40) — COMPLETE
- Phase 3 — Camera & Targeting Core (41-65) — COMPLETE
- Phase 4 — Basic Combat Core (66-95) — COMPLETE
- Phase 5 — Enemy Core & Damage Loop (96-120) — COMPLETE
- Phase 6 — MP, ATB & Ability Pipeline (121-150) — COMPLETE
- Phase 7 — Tactical Mode Core (151-175) — COMPLETE
- Phase 8 — HUD, Menus & UX (176-200) — COMPLETE
- Phase 9 — Inventory & Equipment (201-230) — COMPLETE
- Phase 10 — Quests & NPC Interaction (231-255) — COMPLETE
- Phase 11 — Save System (256-280) — COMPLETE
- Phase 12 — World & Traversal (281-310) — COMPLETE
- Phase 13 — Party System (311-340) — COMPLETE
- Phase 14 — Audio & VFX (341-365) — COMPLETE
- Phase 15 — Combat Polish (366-372) — COMPLETE
- Phase 15 — UX / Accessibility (373-378) — COMPLETE
- Phase 15 — Performance / Stability (379-384) — COMPLETE

---

# MACRO PHASE 15 — POLISH, QA, AND REGRESSION (366-400) — IN PROGRESS

## Regression Tests

- [ ] 385. Combat regression test
- [ ] 386. Lock-on regression test
- [ ] 387. Tactical menu regression test
- [ ] 388. Inventory regression test
- [ ] 389. Save/load regression test
- [ ] 390. Quest progression regression test
- [ ] 391. Party switching regression test
- [ ] 392. Traversal regression test

## Final Validation

- [ ] 393. Verify title-to-save-to-combat loop
- [ ] 394. Verify town-to-field-to-dungeon loop
- [ ] 395. Verify controller-only play session
- [ ] 396. Verify keyboard-only play session
- [ ] 397. Verify hybrid combat loop repeatedly
- [ ] 398. Verify no major softlocks remain
- [ ] 399. Update project_status.json truthfully
- [ ] 400. Print final verification output

---

# MACRO PHASE 16 — REACTOR WORLD BUILDING & LUMINA SYSTEMS (401-425)

## Lumina Infrastructure

- [ ] 401. Define Lumina terminology in lore/data
- [ ] 402. Create Lumina reactor environmental design rules
- [ ] 403. Create underwater reactor zone concept
- [ ] 404. Create glacier/iceberg reactor zone concept
- [ ] 405. Define how Lumina powers cities
- [ ] 406. Define visual motifs for Lumina technology
- [ ] 407. Define military usage of Lumina
- [ ] 408. Define civilian usage of Lumina

## Zone Hooks

- [ ] 409. Add reactor facility zone hook
- [ ] 410. Add reactor city hub hook
- [ ] 411. Add coastal infrastructure route hook
- [ ] 412. Add frozen-region route hook
- [ ] 413. Add Lumina hazard/environment interaction hook
- [ ] 414. Add reactor security encounter hook

## World Identity Validation

- [ ] 415. Verify world feels distinct from generic fantasy
- [ ] 416. Verify Lumina identity appears in UI/lore naming
- [ ] 417. Verify reactor zones have gameplay relevance
- [ ] 418. Verify cooling logic supports worldbuilding
- [ ] 419. Verify environmental storytelling opportunities exist
- [ ] 420. Verify faction/military integration supports story
- [ ] 421. Verify hub towns reflect Lumina dependence
- [ ] 422. Verify visual motifs remain consistent
- [ ] 423. Verify no lore contradictions between zones
- [ ] 424. Verify post-Ragnorak shift can meaningfully corrupt Lumina spaces
- [ ] 425. Document Lumina world rules for future content

---

# MACRO PHASE 17 — RAGNORAK WORLD SHIFT & POST-MIDPOINT SYSTEMS (426-450)

## World Shift Framework

- [ ] 426. Define Ragnorak trigger architecture
- [ ] 427. Define world-state flag for pre/post Ragnorak
- [ ] 428. Add post-Ragnorak zone variants hook
- [ ] 429. Add corrupted environmental effects hook
- [ ] 430. Add spirit/monster spawn sets
- [ ] 431. Add pre/post quest state compatibility
- [ ] 432. Add post-shift NPC dialogue support

## Combat Escalation

- [ ] 433. Add Light element hook
- [ ] 434. Add Dark element hook
- [ ] 435. Add post-shift elemental interactions
- [ ] 436. Add corrupted enemy ability hooks
- [ ] 437. Add post-shift stagger/weakness tuning
- [ ] 438. Add post-shift team attack expansion hooks

## Validation

- [ ] 439. Verify pre/post shift save compatibility
- [ ] 440. Verify world-state transition does not break progression
- [ ] 441. Verify zone reload respects new world state
- [ ] 442. Verify enemy pools change correctly
- [ ] 443. Verify quest markers update across world-state shift
- [ ] 444. Verify late elements stay locked before midpoint
- [ ] 445. Verify post-shift content feels meaningfully escalated
- [ ] 446. Verify dialogue and NPCs reflect catastrophe
- [ ] 447. Verify no duplicated zone ownership bugs
- [ ] 448. Verify post-shift combat remains readable
- [ ] 449. Verify post-shift VFX hooks do not destabilize gameplay
- [ ] 450. Regression test pre/post Ragnorak state loads

---

# MACRO PHASE 18 — ADVANCED PARTY, RESERVES, AND TEAM ATTACKS (451-480)

## Reserve Management

- [ ] 451. Implement reserve roster UI
- [ ] 452. Implement reserve swap rules
- [ ] 453. Implement reserve lockout restrictions if needed
- [ ] 454. Persist reserve composition in save data
- [ ] 455. Add reserve member progression hooks

## Character Switching

- [ ] 456. Add switch cooldown system
- [ ] 457. Verify switch cooldown presentation
- [ ] 458. Verify switch input clarity on controller
- [ ] 459. Verify switch preserves target context when appropriate
- [ ] 460. Verify switch safely exits illegal states

## Team Attack Expansion

- [ ] 461. Create duo technique framework
- [ ] 462. Create trio technique framework
- [ ] 463. Add synergy requirement data structure
- [ ] 464. Add shared meter tuning rules
- [ ] 465. Add stagger bonus integration
- [ ] 466. Add tactical menu team attack category/hook if needed
- [ ] 467. Add cinematic team attack framing rules
- [ ] 468. Add fail-safe if partner unavailable/downed

## Validation

- [ ] 469. Verify duo technique trigger logic
- [ ] 470. Verify trio technique trigger logic
- [ ] 471. Verify reserve swapping does not corrupt active party
- [ ] 472. Verify team attacks do not corrupt camera state
- [ ] 473. Verify team attacks do not corrupt tactical state
- [ ] 474. Verify team attacks correctly consume shared meter
- [ ] 475. Verify downed allies cannot illegitimately participate
- [ ] 476. Verify reserve members persist through save/load
- [ ] 477. Verify controller support for reserve management
- [ ] 478. Verify team attack animations recover safely
- [ ] 479. Regression test active/reserve transitions
- [ ] 480. Regression test team attacks during stagger windows

---

# MACRO PHASE 19 — ADVANCED TRAVERSAL & WORLD GATING (481-505)

## Traversal Abilities

- [ ] 481. Implement double jump proper
- [ ] 482. Tune double jump input window
- [ ] 483. Verify double jump air state safety
- [ ] 484. Implement wall run entry rules
- [ ] 485. Implement wall run movement logic
- [ ] 486. Implement wall run exit logic
- [ ] 487. Verify wall run camera behavior
- [ ] 488. Implement glide state
- [ ] 489. Implement glide physics tuning
- [ ] 490. Verify glide landing safety

## Gating / World Use

- [ ] 491. Create traversal gate tagging system
- [ ] 492. Create hidden area traversal rules
- [ ] 493. Create traversal reward pathing guidelines
- [ ] 494. Integrate party-specific traversal hooks
- [ ] 495. Prevent traversal from bypassing critical blockers

## Validation

- [ ] 496. Verify double jump does not corrupt combat state
- [ ] 497. Verify wall run does not corrupt lock-on/camera
- [ ] 498. Verify glide does not corrupt landing/combat entry
- [ ] 499. Verify traversal works on controller
- [ ] 500. Verify traversal works on keyboard
- [ ] 501. Verify traversal gates are readable
- [ ] 502. Verify traversal rewards persist
- [ ] 503. Regression test traversal load transitions
- [ ] 504. Regression test traversal save/load state
- [ ] 505. Regression test traversal + combat re-entry

---

# MACRO PHASE 20 — BOSS SYSTEMS, BREAK PARTS, AND ENRAGE (506-530)

## Boss Framework

- [ ] 506. Create BossBrain architecture
- [ ] 507. Create boss intro sequence hook
- [ ] 508. Create multi-phase boss framework
- [ ] 509. Create boss health phase thresholds
- [ ] 510. Create boss stagger interaction rules
- [ ] 511. Create boss arena controller
- [ ] 512. Create boss music/event hooks

## Breakable Parts

- [ ] 513. Create breakable part data structure
- [ ] 514. Add boss weak-point targeting support
- [ ] 515. Add break-state feedback
- [ ] 516. Add break-state reward/penalty rules
- [ ] 517. Verify breakable parts integrate with lock-on

## Rage / Enrage

- [ ] 518. Create enrage trigger rules
- [ ] 519. Create visual/audio indication for enrage
- [ ] 520. Create boss behavior changes under enrage
- [ ] 521. Verify enrage does not softlock tactical mode
- [ ] 522. Verify enrage phase transitions are stable

## Validation

- [ ] 523. Verify boss phase transitions preserve camera safety
- [ ] 524. Verify boss phase transitions preserve lock-on safety
- [ ] 525. Verify breakable parts save no illegal transient state
- [ ] 526. Verify boss death cleanup is stable
- [ ] 527. Verify arena transitions restore world state
- [ ] 528. Regression test boss fights with party switching
- [ ] 529. Regression test boss fights with tactical mode spam
- [ ] 530. Regression test boss fights with stagger/team attacks

---

# MACRO PHASE 21 — CONTENT PIPELINE, ASSETS, AND PRESENTATION UPGRADE (531-545)

## Visual Pipeline

- [ ] 531. Define placeholder-to-final asset swap protocol
- [ ] 532. Define character model replacement protocol
- [ ] 533. Define equipment visual swap protocol
- [ ] 534. Define enemy model replacement protocol
- [ ] 535. Define boss asset replacement protocol

## Animation / Audio Pipeline

- [ ] 536. Define placeholder-to-final animation upgrade path
- [ ] 537. Define final audio import standards
- [ ] 538. Define spell VFX asset organization
- [ ] 539. Define team attack cinematic asset organization

## Content Safety

- [ ] 540. Verify asset swaps do not break scene ownership
- [ ] 541. Verify animation swaps preserve event timings
- [ ] 542. Verify equipment visuals preserve attachment rules
- [ ] 543. Verify final asset loads do not regress performance catastrophically
- [ ] 544. Verify content pipeline is documented for future characters/zones
- [ ] 545. Verify final asset pass remains launcher/compliance safe

---

# MACRO PHASE 22 — RELEASE READINESS, COMPLIANCE, AND STUDIO PIPELINE FINALIZATION (546-560)

## Compliance

- [ ] 546. Verify launcher contract remains valid
- [ ] 547. Verify game.config.json remains accurate
- [ ] 548. Verify project_status.json remains accurate
- [ ] 549. Verify achievements.json contract exists and remains valid
- [ ] 550. Verify testCommand executes without manual steps

## Release Readiness

- [ ] 551. Create release candidate checklist
- [ ] 552. Verify title-to-endgame loop has no known blockers
- [ ] 553. Verify controller-first promise is upheld
- [ ] 554. Verify no critical save corruption cases remain
- [ ] 555. Verify no critical combat softlocks remain
- [ ] 556. Verify no critical party-switch bugs remain
- [ ] 557. Verify no critical world-state transition bugs remain
- [ ] 558. Verify performance baseline acceptable
- [ ] 559. Final regression sweep across all major systems
- [ ] 560. Print final verification proof before claiming production-ready milestone

---

# Current Focus

Current Phase: Macro Phase 15 — Polish, QA, and Regression
Current Task: Regression tests and final validation (items 385-400)
Next Milestone: Phase 15 complete (item 400)

## Completed Phases
- Phase 1 — Foundation & Project Setup (items 1-20)
- Phase 2 — Player Locomotion Core (items 21-40)
- Phase 3 — Camera & Targeting Core (items 41-65)
- Phase 4 — Basic Combat Core (items 66-95)
- Phase 5 — Enemy Core & Damage Loop (items 96-120)
- Phase 6 — MP, ATB & Ability Pipeline (items 121-150)
- Phase 7 — Tactical Mode Core (items 151-175)
- Phase 8 — HUD, Menus & UX (items 176-200)
- Phase 9 — Inventory & Equipment (items 201-230)
- Phase 10 — Quests & NPC Interaction (items 231-255)
- Phase 11 — Save System (items 256-280)
- Phase 12 — World & Traversal (items 281-310)
- Phase 13 — Party System (items 311-340)
- Phase 14 — Audio & VFX (items 341-365)

---

# Known Gaps

- Placeholder art only
- No final audio assets
- No final 3D character models or animations
- Art pipeline still evolving
- Vertical slice milestone must remain formally verified before major expansions
- Team attack content not yet production-implemented
- Post-Ragnorak content not yet production-implemented
- Boss framework not yet production-implemented

---

# Long-Term Vision

- Semi-open world with multiple connected regions
- Large reactor cities and glacial/ocean Lumina infrastructure
- Midpoint catastrophe that transforms world state
- Boss encounters with unique mechanics
- Full party system with AI companions and reserves
- Equipment-driven visual progression
- Cinematic story moments
- Replayable exploration content
- Stable, modular, Claude-friendly studio pipeline

---

# Locked Naming / Identity Rules

These names are locked unless explicitly changed by the user:

- Lumina — world energy source
- Ragnorak — midpoint catastrophic event
- Amaro — protagonist
- Taighe — first blue-haired mage party member

---

END OF FILE