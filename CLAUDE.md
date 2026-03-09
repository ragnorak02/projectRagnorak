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

Ragnorak is a Korean fantasy hybrid action RPG inspired by Final Fantasy VII Remake.

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
- [ ] Tactical mode slows to 10%
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
- [ ] Jump attacks exist from early development
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
- [ ] Jump -> A
- [ ] Attack -> X
- [ ] Dodge -> B
- [ ] Interact -> Y
- [ ] Tactical Menu -> Left Trigger
- [ ] Lock-On -> Right Trigger
- [ ] Camera Reset -> Right Stick Click
- [ ] Pause -> Start
- [ ] Target switch left supported
- [ ] Target switch right supported
- [ ] Character switch supported
- [ ] Tactical menu full navigation supported
- [ ] Inventory/menu full navigation supported
- [ ] No gameplay-critical mouse-only behavior exists

## Keyboard / Mouse

- [ ] Move -> WASD
- [ ] Camera -> Mouse
- [ ] Jump -> Space
- [ ] Attack -> Left Mouse
- [ ] Dodge -> Shift
- [ ] Interact -> E
- [ ] Tactical Menu -> Q
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
- [ ] Slows game to 10% speed
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

---

# MACRO PHASE 1 — FOUNDATION & PROJECT SETUP (1-20)

## Repo / Project Setup

- [x] 1. Create/verify standard repo structure
- [x] 2. Verify Godot 4.6 project opens cleanly
- [x] 3. Verify project boot scene configured
- [x] 4. Add/verify standard folders
- [x] 5. Create base autoload list plan
- [x] 6. Add initial debug flags
- [x] 7. Establish naming conventions
- [x] 8. Create architecture note for state machine separation

## Input / Bootstrap

- [x] 9. Configure Xbox InputMap
- [x] 10. Configure keyboard/mouse InputMap
- [x] 11. Verify simultaneous input support
- [x] 12. Add temporary control overlay
- [x] 13. Verify title/menu navigation on controller
- [x] 14. Verify title/menu navigation on keyboard

## Base Scene Structure

- [x] 15. Create initial MainMenu scene
- [x] 16. Create initial test combat arena scene
- [x] 17. Create initial player scene root layout
- [x] 18. Create initial enemy scene root layout
- [x] 19. Create initial camera rig scene
- [x] 20. Verify all base scenes boot without errors

---

# MACRO PHASE 2 — PLAYER LOCOMOTION CORE (21-40)

## Player Movement

- [x] 21. Implement grounded movement
- [x] 22. Implement acceleration/deceleration
- [x] 23. Implement facing/orientation rules
- [x] 24. Implement run speed tuning
- [x] 25. Verify controller analog movement
- [x] 26. Verify keyboard movement parity

## Jump / Air Control

- [x] 27. Implement jump
- [x] 28. Implement jump buffering if needed
- [x] 29. Implement fall handling
- [x] 30. Implement air control tuning
- [x] 31. Implement landing recovery
- [x] 32. Implement jump attack placeholder hook
- [x] 33. Verify jump on controller
- [x] 34. Verify jump on keyboard

## Ledge / Climb Foundations

- [x] 35. Add ledge detection probes
- [x] 36. Implement automatic ledge grab
- [x] 37. Implement climb-up flow
- [x] 38. Verify ledge grab accuracy
- [x] 39. Verify climb does not break camera
- [x] 40. Verify locomotion state transitions valid

---

# MACRO PHASE 3 — CAMERA & TARGETING CORE (41-65)

## Free Camera

- [x] 41. Implement free camera rotation
- [x] 42. Implement vertical clamp rules
- [x] 43. Implement camera follow smoothing
- [x] 44. Implement camera reset behind player
- [x] 45. Verify right stick orbit
- [x] 46. Verify mouse camera

## Camera Collision

- [x] 47. Implement wall collision handling
- [x] 48. Implement near-wall zoom
- [x] 49. Prevent camera clipping
- [x] 50. Verify recovery after obstruction
- [x] 51. Verify no floor clipping
- [x] 52. Verify no jitter near corners

## Lock-On Basics

- [x] 53. Implement nearest-enemy lock
- [x] 54. Implement lock clear
- [x] 55. Implement target death cleanup
- [x] 56. Implement target range-loss handling
- [x] 57. Implement target obstruction handling
- [x] 58. Implement lock-on strafe movement
- [x] 59. Implement lock-on camera framing
- [x] 60. Implement target switch left/right

## Lock-On Validation

- [x] 61. Verify lock-on target selection
- [x] 62. Verify target switch stability
- [x] 63. Verify camera stability during switch
- [x] 64. Verify lock-on recovery on target loss
- [x] 65. Verify no softlock between free/lock-on

---

# MACRO PHASE 4 — BASIC COMBAT CORE (66-95)

## Base Combat Framework

- [x] 66. Create CombatSystem
- [x] 67. Create CombatState definitions
- [x] 68. Create hurtbox/hitbox conventions
- [x] 69. Define damage event pipeline
- [x] 70. Define attack request flow

## Basic Attack Chain

- [x] 71. Implement attack 1
- [x] 72. Implement attack 2
- [x] 73. Implement attack 3
- [x] 74. Define combo input windows
- [x] 75. Define combo recovery windows
- [x] 76. Implement soft target tracking
- [x] 77. Add animation-driven hit windows
- [x] 78. Add hit reaction to enemy
- [x] 79. Verify combo completes reliably
- [x] 80. Verify combo respects legal states

## Jump Attack

- [x] 81. Implement jump attack trigger
- [x] 82. Define jump attack timing
- [x] 83. Define jump attack hit window
- [x] 84. Define landing recovery after jump attack
- [x] 85. Verify jump attack integrates with locomotion

## Dodge

- [x] 86. Implement dodge startup/motion/recovery
- [x] 87. Add cooldown
- [x] 88. Allow cancel from normal attacks
- [x] 89. Block cancel from spells/skills
- [x] 90. Verify no invulnerability frames
- [x] 91. Verify timing-based feel
- [x] 92. Verify dodge blocked in illegal states
- [x] 93. Verify dodge recovery returns valid state
- [x] 94. Verify dodge during lock-on stable
- [x] 95. Verify dodge does not break camera

---

# MACRO PHASE 5 — ENEMY CORE & DAMAGE LOOP (96-120)

## Enemy Basics

- [x] 96. Create one base enemy type
- [x] 97. Implement idle state
- [x] 98. Implement aggro detection
- [x] 99. Implement pursuit behavior
- [x] 100. Implement basic attack
- [x] 101. Implement attack telegraph
- [x] 102. Implement enemy hurt reaction
- [x] 103. Implement enemy death
- [x] 104. Implement death cleanup for lock-on

## Damage / Hit Logic

- [x] 105. Implement player taking damage
- [x] 106. Implement enemy taking damage
- [x] 107. Add hit pause/feedback
- [x] 108. Add stagger placeholder
- [x] 109. Verify no duplicate damage events
- [x] 110. Verify hitboxes disable after window

## Casting Interruption

- [x] 111. Implement enemy interrupt rules
- [x] 112. Implement player cast interruption
- [x] 113. Verify interruption in legal windows only
- [x] 114. Verify interrupted spell returns valid state

## Stability Pass

- [x] 115. Verify full duel works repeatedly
- [x] 116. Verify lock-on correct during enemy death
- [x] 117. Verify enemy cannot attack while dead
- [x] 118. Verify no null references after death
- [x] 119. Verify re-entering arena resets correctly
- [x] 120. Verify combat loop survives repeated tests

---

# MACRO PHASE 6 — MP, ATB, AND ABILITY PIPELINE (121-150)

## MP

- [x] 121. Create MP resource
- [x] 122. Implement MP consumption
- [x] 123. Implement MP regen rules
- [x] 124. Implement insufficient MP handling
- [x] 125. Add UI indicator for insufficient MP

## ATB

- [x] 126. Create ATB resource system
- [x] 127. Define ATB fill rules
- [x] 128. Add ATB UI bar
- [x] 129. Prevent command execution at zero ATB
- [x] 130. Allow menu open at zero ATB

## Ability System

- [x] 131. Create AbilitySystem
- [x] 132. Define ability request pipeline
- [x] 133. Define cast start/release/recovery phases
- [x] 134. Define root-in-place casting rule
- [x] 135. Define interruption integration
- [x] 136. Define cooldown/resource structure

## First Spell

- [x] 137. Implement one spell ability
- [x] 138. Connect animation timing to spell release
- [x] 139. Connect MP cost
- [x] 140. Connect ATB cost
- [x] 141. Block dodge cancel during spell
- [x] 142. Verify enemy interruption works
- [x] 143. Verify insufficient MP behavior
- [x] 144. Verify spell returns valid state
- [x] 145. Verify spell works while locked on
- [x] 146. Verify spell works while not locked on

## Extension Path

- [x] 147. Add placeholder for additional abilities
- [x] 148. Ensure data-driven extension path
- [x] 149. Verify ability menu can scale
- [x] 150. Verify no hardcoded assumptions block expansion

---

# MACRO PHASE 7 — TACTICAL MODE CORE (151-175)

## Tactical Menu Framework

- [x] 151. Create TacticalMenuState
- [x] 152. Implement open/close input
- [x] 153. Implement global slow-time to 10%
- [x] 154. Restore time scale correctly on close
- [x] 155. Add menu shell UI

## Menu Categories

- [x] 156. Add Abilities category
- [x] 157. Add Magic category
- [x] 158. Add Items category
- [x] 159. Add controller navigation
- [x] 160. Add keyboard navigation

## Execution Rules

- [x] 161. Grey out unavailable commands
- [x] 162. Grey out commands lacking ATB
- [x] 163. Grey out commands lacking MP
- [x] 164. Permit viewing without resources
- [x] 165. Execute command on confirm
- [x] 166. Return safely after execution

## Tactical Restrictions

- [x] 167. Block during stun
- [x] 168. Block during knockdown
- [x] 169. Block during cutscenes
- [x] 170. Block during forced states

## Tactical Validation

- [x] 171. Verify no incorrect combo reset
- [x] 172. Verify lock-on preserved
- [x] 173. Verify exits to correct state
- [x] 174. Verify repeated open/close no softlock
- [x] 175. Verify time scale cleanup

---

# MACRO PHASE 8 — HUD, MENUS, AND UX (176-200)

## Gameplay HUD

- [x] 176. Add HP display
- [x] 177. Add MP display
- [x] 178. Add ATB display
- [x] 179. Add target indicator
- [x] 180. Add interaction prompt
- [x] 181. Add quest tracker placeholder
- [x] 182. Add control overlay if needed

## Pause / Main Menu

- [x] 183. Create title screen
- [x] 184. Add Continue option
- [x] 185. Add New Game option
- [x] 186. Add Options option
- [x] 187. Add Exit option
- [x] 188. Create pause menu
- [x] 189. Add Resume
- [x] 190. Add Inventory
- [x] 191. Add Quest Log
- [x] 192. Add Settings
- [x] 193. Add Return to Title

## Menu Validation

- [x] 194. Verify menu navigation on controller
- [x] 195. Verify menu navigation on keyboard
- [x] 196. Verify focus states visible
- [x] 197. Verify menus do not corrupt gameplay
- [x] 198. Verify pause cannot conflict with tactical
- [x] 199. Verify menus recover after combat
- [x] 200. Verify title-to-game flow

---

# MACRO PHASE 9 — INVENTORY & EQUIPMENT (201-230)

## Inventory Core

- [x] 201. Create InventorySystem
- [x] 202. Add Consumables category
- [x] 203. Add Equipment category
- [x] 204. Add Key Items category
- [x] 205. Add item data structure
- [x] 206. Add stack handling

## Equipment Slots

- [x] 207. Implement Head slot
- [x] 208. Implement Cape slot
- [x] 209. Implement Chest slot
- [x] 210. Implement Pants slot
- [x] 211. Implement Shoes slot
- [x] 212. Implement Gloves slot
- [x] 213. Implement Left Hand slot
- [x] 214. Implement Right Hand slot
- [x] 215. Implement Accessory 1
- [x] 216. Implement Accessory 2

## Equipment Effects

- [x] 217. Add stat application
- [x] 218. Add equipment swap logic
- [x] 219. Add visual change hooks
- [x] 220. Verify removing equipment restores state

## Item Use

- [x] 221. Implement ally-target item use
- [x] 222. Block invalid item targeting
- [x] 223. Integrate tactical menu item selection
- [x] 224. Integrate out-of-battle item use
- [x] 225. Verify item quantity respected
- [x] 226. Verify item use respects battle state
- [x] 227. Verify no duplicate consumption
- [x] 228. Verify item UI on controller
- [x] 229. Verify item UI on keyboard
- [x] 230. Verify equipment/inventory persists

---

# MACRO PHASE 10 — QUESTS & NPC INTERACTION (231-255)

## Interaction System

- [x] 231. Create interaction prompt system
- [x] 232. Implement NPC interaction
- [x] 233. Implement chest interaction
- [x] 234. Implement lever/object interaction
- [x] 235. Verify interaction priority rules

## Dialogue

- [x] 236. Create basic dialogue UI
- [x] 237. Support controller dialogue advance
- [x] 238. Support keyboard dialogue advance
- [x] 239. Allow light story delivery
- [x] 240. Support optional movement during conversations

## Quest Core

- [x] 241. Create QuestSystem
- [x] 242. Create active quest tracking
- [x] 243. Create objective list
- [x] 244. Create map marker hook
- [x] 245. Create current quest display
- [x] 246. Create story quest type
- [x] 247. Create side quest type
- [x] 248. Create exploration quest type

## Quest Log UI

- [x] 249. Create quest log screen
- [x] 250. Show tracked objectives
- [x] 251. Show map markers
- [x] 252. Show quest status
- [x] 253. Verify quest UI on controller
- [x] 254. Verify quest UI on keyboard
- [x] 255. Verify quest progression updates

---

# MACRO PHASE 11 — SAVE SYSTEM (256-280)

## Save Core

- [x] 256. Create SaveSystem
- [x] 257. Implement autosave slot
- [x] 258. Implement three manual save slots
- [x] 259. Implement data versioning
- [x] 260. Persist player position
- [x] 261. Persist current zone
- [x] 262. Persist inventory
- [x] 263. Persist equipment
- [x] 264. Persist quests
- [x] 265. Persist party state
- [x] 266. Persist progression flags

## Save UI

- [x] 267. Create save slot UI
- [x] 268. Create load slot UI
- [x] 269. Create continue logic from title
- [x] 270. Show save metadata

## Quicksave

- [x] 271. Implement quicksave
- [x] 272. Block quicksave during combat
- [x] 273. Add feedback when quicksave blocked
- [x] 274. Verify quicksave resumes valid state

## Zone Reset Rules

- [x] 275. Reset enemy states per zone
- [x] 276. Verify zone reload correct
- [x] 277. Verify autosave trigger points
- [x] 278. Verify no corrupted state after saves
- [x] 279. Verify manual load restores valid state
- [x] 280. Verify continue flow from main menu

---

# MACRO PHASE 12 — WORLD & TRAVERSAL (281-310)

## Towns / Zones

- [x] 281. Create first town hub
- [x] 282. Create second town hook
- [x] 283. Create first field zone
- [x] 284. Create first dungeon zone
- [x] 285. Create zone transition logic
- [x] 286. Create loading transition handling

## Exploration

- [x] 287. Add hidden area structure
- [x] 288. Add chest reward structure
- [x] 289. Add exploration gating logic
- [x] 290. Add simple puzzle framework
- [x] 291. Add switch puzzle support
- [x] 292. Verify puzzles do not break combat

## Traversal Expansion

- [x] 293. Add double jump hook
- [x] 294. Add climb refinement
- [x] 295. Add wall-break hook
- [x] 296. Add traversal gating via party
- [x] 297. Verify camera stable during traversal
- [x] 298. Verify traversal cannot bypass blockers

## World Validation

- [x] 299. Verify semi-open routing
- [x] 300. Verify transitions preserve state
- [x] 301. Verify loading transitions safe
- [x] 302. Verify autosave in world sane
- [x] 303. Verify exploration rewards persist
- [x] 304. Verify puzzle completion persists
- [x] 305. Verify field-town-dungeon loop
- [x] 306. Verify no traversal softlocks
- [x] 307. Verify return paths exist
- [x] 308. Verify world navigation on controller
- [x] 309. Verify world navigation on keyboard
- [x] 310. Verify world loop playable end-to-end

---

# MACRO PHASE 13 — PARTY SYSTEM (311-340)

## Party Foundations

- [x] 311. Add second party member
- [x] 312. Add AI companion logic
- [x] 313. Add battle switching logic
- [x] 314. Add out-of-battle switching
- [x] 315. Add party roster structure

## Party Combat

- [x] 316. Add ally follow/support behavior
- [x] 317. Add ally ability usage
- [x] 318. Add ally revive support
- [x] 319. Add downed ally state
- [x] 320. Add revive-in-battle logic

## Team Meter / Attacks

- [x] 321. Create shared team meter
- [x] 322. Define fill rules
- [x] 323. Define expenditure rules
- [x] 324. Add one team attack
- [x] 325. Add team attack UI hook
- [x] 326. Verify team meter persistence

## Party Traversal

- [x] 327. Add party-specific traversal hook
- [x] 328. Support traversal gating in world
- [x] 329. Verify party traversal scene safety

## Party Validation

- [x] 330. Verify switching does not corrupt camera
- [x] 331. Verify switching does not corrupt lock-on
- [x] 332. Verify switching does not corrupt tactical
- [x] 333. Verify ally AI no softlock
- [x] 334. Verify revive works reliably
- [x] 335. Verify ally targeting for items
- [x] 336. Verify party HUD updates
- [x] 337. Verify save/load preserves party
- [x] 338. Verify team attack state valid
- [x] 339. Verify controller support for party
- [x] 340. Verify party combat loop stability

---

# MACRO PHASE 14 — AUDIO & VFX (341-365)

## Audio

- [x] 341. Create AudioManager
- [x] 342. Add menu SFX hooks
- [x] 343. Add basic attack SFX
- [x] 344. Add dodge SFX
- [x] 345. Add spell SFX
- [x] 346. Add hit reaction SFX
- [x] 347. Add town music
- [x] 348. Add field music
- [x] 349. Add dungeon music
- [x] 350. Add battle music hook

## VFX

- [x] 351. Add attack hit sparks
- [x] 352. Add spell effect VFX
- [x] 353. Add dodge effect
- [x] 354. Add lock-on indicator
- [x] 355. Add interaction prompt polish
- [x] 356. Add menu transition polish
- [x] 357. Add team attack visual hook

## Presentation Validation

- [x] 358. Verify no SFX duplication bugs
- [x] 359. Verify audio state changes
- [x] 360. Verify VFX cleanup
- [x] 361. Verify tactical slow-time audio
- [x] 362. Verify target indicator clarity
- [x] 363. Verify VFX does not obstruct gameplay
- [x] 364. Verify controller prompts readable
- [x] 365. Verify presentation does not destabilize gameplay

---

# MACRO PHASE 15 — POLISH, QA, AND REGRESSION (366-400)

## Combat Polish

- [x] 366. Tune combo feel
- [x] 367. Tune dodge feel
- [x] 368. Tune jump attack feel
- [x] 369. Tune lock-on responsiveness
- [x] 370. Tune tactical responsiveness
- [x] 371. Tune camera sensitivity
- [x] 372. Tune camera collision smoothing

## UX / Accessibility

- [x] 373. Add camera sensitivity option
- [x] 374. Add controller rebinding support
- [x] 375. Add audio volume settings
- [x] 376. Add gameplay settings hooks
- [x] 377. Verify text readability
- [x] 378. Verify menu focus clarity

## Performance / Stability

- [x] 379. Profile combat scene
- [x] 380. Profile world scene
- [x] 381. Verify no node leaks
- [x] 382. Verify scene transitions free resources
- [x] 383. Verify no repeated signal connections
- [x] 384. Verify no duplicate autoload bugs

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