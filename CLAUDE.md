# GLOBAL RULES (LUMINA)

This project inherits the LUMINA studio rules.

Non-negotiable:

- Claude must verify work before declaring completion
- Claude must confirm working directory before changing files
- Claude must print scene trees after scene modifications
- Claude must not skip unstable foundations
- Claude must not mark checklist items complete without proof
- Claude must not expand future systems before current systems are stable

If local rules conflict with global rules, **global rules win**.

---

# Mandatory Verification Protocol

Claude must run verification before completing tasks involving:

- code changes
- scene changes
- gameplay systems
- UI systems
- signals or input systems

Verification output must include:

- scene node tree
- attached scripts
- signal connections
- interaction confirmation

Completion without verification output is **invalid**.

---

# PROJECT

Working Title: Korean Fantasy Hybrid Action RPG

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
- party expansion later

---

# LUMINA Studio Rules

- `project_status.json` is the **single source of truth**
- `CLAUDE.md` defines development checkpoints
- Launcher reads **JSON only**
- Never delete checklist items
- Mark unused items **N/A**
- Timestamps use **ISO8601 minute precision**

---

# Launcher Contract

Required files:

game.config.json
project_status.json
achievements.json

Test command: `tests/run-tests.bat`
Headless boot: `Z:/godot/godot.exe --path . --headless --quit-after 1`
Headless test: `Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn`

---

# Project Overview

Korean Fantasy Hybrid Action RPG inspired by Final Fantasy VII Remake. Controller-first 3D combat with tactical slow-time menu, ATB-based command execution, semi-open world exploration with connected zones, handcrafted dungeons, party mechanics, and traversal-based progression.

---

# Core Gameplay Loop

Town Hub
-> Explore Connected Zones
-> Fight Enemies (Real-Time + Tactical)
-> Obtain Gear / Materials
-> Complete Quests
-> Unlock Traversal Abilities
-> Access New Areas
-> Repeat

---

# Core Pillars

- Controller-first gameplay feel
- Satisfying hybrid tactical combat
- Exploration through traversal progression
- System stability over feature speed
- Deterministic, bug-resistant architecture

---

# Architecture Summary

## Autoloads

- Events — Signal bus for cross-system communication
- GameManager — Game state, time scale stack, hit stop
- InputManager — Device detection, movement helpers
- AudioManager — SFX pool and music playback
- SaveManager — Save/load with autosave, manual, quicksave
- DebugFlags — Global debug toggles

## Scene Structure

- MainMenu -> GameWorld -> Zone scenes
- Player persists in GameWorld shell
- Zones load as children of ZoneContainer
- Camera rig follows active player character

## State Machine Architecture

Six separate state domains (implemented as needed):
- LocomotionState — Idle, Run, Jump, Fall, Land, Dodge
- CombatState — Attack1-3, JumpAttack, Ability, Flinch
- TargetingState — LockOnIdle, LockOnStrafe
- TacticalMenuState — TacticalIdle
- CameraState — Free, LockedOn, Reset
- EnemyAIState — Idle, Chase, Attack, Hurt, Dead

## System Ownership

- PlayerController -> movement input
- CombatSystem -> combo flow and attack logic
- AbilitySystem -> spell/skill execution
- TargetingSystem -> target acquisition/switching
- CameraRig -> orbit/collision/framing
- TacticalMenu -> slow-time/menu state
- EnemyBrain -> enemy decisions
- SaveSystem -> persistence
- InventorySystem -> item/equipment data
- QuestSystem -> active objective tracking

---

# CORE DESIGN CONTRACT

## Fixed Rules

- [ ] Protagonist has fixed identity and story
- [ ] Game is gameplay-heavy with light story
- [ ] World is semi-open with connected zones
- [ ] Large regions may use loading transitions
- [ ] Multiple towns exist
- [ ] Dungeons are handcrafted and deterministic
- [ ] Puzzles are light and simple
- [ ] Basic attacks are unlimited (no stamina)
- [ ] Spells use MP
- [ ] Tactical mode slows to 10%
- [ ] Tactical mode free to open
- [ ] Tactical mode cannot execute without ATB
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
- [ ] Party members arrive later
- [ ] AI companions control inactive members
- [ ] Team attacks use shared team meter
- [ ] Party members may provide traversal abilities
- [ ] Equipment visually changes character

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

---

# 3D COMBAT BUG PREVENTION RULES

## State Machine Separation

- [ ] LocomotionState exists
- [ ] CombatState exists
- [ ] TargetingState exists
- [ ] TacticalMenuState exists
- [ ] CameraState exists
- [ ] EnemyAIState exists
- [ ] States cannot overlap
- [ ] Illegal transitions blocked
- [ ] SpellCast cannot transition to Dodge
- [ ] Stunned cannot enter TacticalMode
- [ ] Knockdown blocks ability use
- [ ] Cutscene blocks TacticalMode
- [ ] Pause blocks combat execution
- [ ] Dead blocks movement and abilities

## Animation-Driven Combat

- [ ] Basic attack hit windows animation-driven
- [ ] Jump attack windows animation-driven
- [ ] Dodge startup/recovery windows defined
- [ ] Spell cast phases defined
- [ ] Interrupt windows defined
- [ ] Hit reactions defined

## Cross-System Safety

- [ ] Systems communicate via signals or approved APIs
- [ ] UI does not directly mutate combat internals
- [ ] Camera does not directly mutate combat state
- [ ] Enemy scripts do not manipulate player camera
- [ ] Abilities do not rewrite unrelated systems

---

# SCENE TREE DISCIPLINE

## Player Root

- [ ] CharacterBody3D root
- [ ] VisualRoot separated from logic
- [ ] CameraAnchor exists
- [ ] InteractionAnchor exists
- [ ] HitboxAnchor exists
- [ ] Hurtbox exists

## Enemy Root

- [ ] NavigationAgent3D
- [ ] VisualRoot separated
- [ ] Hurtbox exists
- [ ] AttackOrigin exists
- [ ] AggroArea exists
- [ ] LockOnPoint exists

## Camera Rig

- [ ] Separated from player visuals
- [ ] YawPivot/PitchPivot structure
- [ ] SpringArm3D for collision
- [ ] Lock-on framing support
- [ ] Camera reset support

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

---

# AUTOMATION CONTRACT

After major system updates:

- [ ] Update project_status.json
- [ ] Run headless boot verification
- [ ] Run relevant regression tests
- [ ] Print scene trees if scenes changed
- [ ] Print key verification proof
- [ ] Only then mark checklist items complete

---

# EXPANSION GATING RULES

- [ ] Party system blocked until single-character combat stable
- [ ] Bosses blocked until lock-on/camera/tactical stable
- [ ] Traversal expansion blocked until jump/camera/ledge stable
- [ ] Additional abilities blocked until one spell pipeline verified
- [ ] World expansion blocked until save/load stable
- [ ] UI polish blocked until menu navigation stable

---

# STRUCTURED DEVELOPMENT CHECKLIST

LUMINA STANDARD — GRANULAR RPG CHECKLIST — 400 ITEMS

---

# MACRO PHASE 1 — FOUNDATION & PROJECT SETUP (1-20)

## Repo / Project Setup

- [ ] 1. Create/verify standard repo structure
- [ ] 2. Verify Godot 4.6 project opens cleanly
- [ ] 3. Verify project boot scene configured
- [ ] 4. Add/verify standard folders
- [ ] 5. Create base autoload list plan
- [ ] 6. Add initial debug flags
- [ ] 7. Establish naming conventions
- [ ] 8. Create architecture note for state machine separation

## Input / Bootstrap

- [ ] 9. Configure Xbox InputMap
- [ ] 10. Configure keyboard/mouse InputMap
- [ ] 11. Verify simultaneous input support
- [ ] 12. Add temporary control overlay
- [ ] 13. Verify title/menu navigation on controller
- [ ] 14. Verify title/menu navigation on keyboard

## Base Scene Structure

- [ ] 15. Create initial MainMenu scene
- [ ] 16. Create initial test combat arena scene
- [ ] 17. Create initial player scene root layout
- [ ] 18. Create initial enemy scene root layout
- [ ] 19. Create initial camera rig scene
- [ ] 20. Verify all base scenes boot without errors

---

# MACRO PHASE 2 — PLAYER LOCOMOTION CORE (21-40)

## Player Movement

- [ ] 21. Implement grounded movement
- [ ] 22. Implement acceleration/deceleration
- [ ] 23. Implement facing/orientation rules
- [ ] 24. Implement run speed tuning
- [ ] 25. Verify controller analog movement
- [ ] 26. Verify keyboard movement parity

## Jump / Air Control

- [ ] 27. Implement jump
- [ ] 28. Implement jump buffering if needed
- [ ] 29. Implement fall handling
- [ ] 30. Implement air control tuning
- [ ] 31. Implement landing recovery
- [ ] 32. Implement jump attack placeholder hook
- [ ] 33. Verify jump on controller
- [ ] 34. Verify jump on keyboard

## Ledge / Climb Foundations

- [ ] 35. Add ledge detection probes
- [ ] 36. Implement automatic ledge grab
- [ ] 37. Implement climb-up flow
- [ ] 38. Verify ledge grab accuracy
- [ ] 39. Verify climb does not break camera
- [ ] 40. Verify locomotion state transitions valid

---

# MACRO PHASE 3 — CAMERA & TARGETING CORE (41-65)

## Free Camera

- [ ] 41. Implement free camera rotation
- [ ] 42. Implement vertical clamp rules
- [ ] 43. Implement camera follow smoothing
- [ ] 44. Implement camera reset behind player
- [ ] 45. Verify right stick orbit
- [ ] 46. Verify mouse camera

## Camera Collision

- [ ] 47. Implement wall collision handling
- [ ] 48. Implement near-wall zoom
- [ ] 49. Prevent camera clipping
- [ ] 50. Verify recovery after obstruction
- [ ] 51. Verify no floor clipping
- [ ] 52. Verify no jitter near corners

## Lock-On Basics

- [ ] 53. Implement nearest-enemy lock
- [ ] 54. Implement lock clear
- [ ] 55. Implement target death cleanup
- [ ] 56. Implement target range-loss handling
- [ ] 57. Implement target obstruction handling
- [ ] 58. Implement lock-on strafe movement
- [ ] 59. Implement lock-on camera framing
- [ ] 60. Implement target switch left/right

## Lock-On Validation

- [ ] 61. Verify lock-on target selection
- [ ] 62. Verify target switch stability
- [ ] 63. Verify camera stability during switch
- [ ] 64. Verify lock-on recovery on target loss
- [ ] 65. Verify no softlock between free/lock-on

---

# MACRO PHASE 4 — BASIC COMBAT CORE (66-95)

## Base Combat Framework

- [ ] 66. Create CombatSystem
- [ ] 67. Create CombatState definitions
- [ ] 68. Create hurtbox/hitbox conventions
- [ ] 69. Define damage event pipeline
- [ ] 70. Define attack request flow

## Basic Attack Chain

- [ ] 71. Implement attack 1
- [ ] 72. Implement attack 2
- [ ] 73. Implement attack 3
- [ ] 74. Define combo input windows
- [ ] 75. Define combo recovery windows
- [ ] 76. Implement soft target tracking
- [ ] 77. Add animation-driven hit windows
- [ ] 78. Add hit reaction to enemy
- [ ] 79. Verify combo completes reliably
- [ ] 80. Verify combo respects legal states

## Jump Attack

- [ ] 81. Implement jump attack trigger
- [ ] 82. Define jump attack timing
- [ ] 83. Define jump attack hit window
- [ ] 84. Define landing recovery after jump attack
- [ ] 85. Verify jump attack integrates with locomotion

## Dodge

- [ ] 86. Implement dodge startup/motion/recovery
- [ ] 87. Add cooldown
- [ ] 88. Allow cancel from normal attacks
- [ ] 89. Block cancel from spells/skills
- [ ] 90. Verify no invulnerability frames
- [ ] 91. Verify timing-based feel
- [ ] 92. Verify dodge blocked in illegal states
- [ ] 93. Verify dodge recovery returns valid state
- [ ] 94. Verify dodge during lock-on stable
- [ ] 95. Verify dodge does not break camera

---

# MACRO PHASE 5 — ENEMY CORE & DAMAGE LOOP (96-120)

## Enemy Basics

- [ ] 96. Create one base enemy type
- [ ] 97. Implement idle state
- [ ] 98. Implement aggro detection
- [ ] 99. Implement pursuit behavior
- [ ] 100. Implement basic attack
- [ ] 101. Implement attack telegraph
- [ ] 102. Implement enemy hurt reaction
- [ ] 103. Implement enemy death
- [ ] 104. Implement death cleanup for lock-on

## Damage / Hit Logic

- [ ] 105. Implement player taking damage
- [ ] 106. Implement enemy taking damage
- [ ] 107. Add hit pause/feedback
- [ ] 108. Add stagger placeholder
- [ ] 109. Verify no duplicate damage events
- [ ] 110. Verify hitboxes disable after window

## Casting Interruption

- [ ] 111. Implement enemy interrupt rules
- [ ] 112. Implement player cast interruption
- [ ] 113. Verify interruption in legal windows only
- [ ] 114. Verify interrupted spell returns valid state

## Stability Pass

- [ ] 115. Verify full duel works repeatedly
- [ ] 116. Verify lock-on correct during enemy death
- [ ] 117. Verify enemy cannot attack while dead
- [ ] 118. Verify no null references after death
- [ ] 119. Verify re-entering arena resets correctly
- [ ] 120. Verify combat loop survives repeated tests

---

# MACRO PHASE 6 — MP, ATB, AND ABILITY PIPELINE (121-150)

## MP

- [ ] 121. Create MP resource
- [ ] 122. Implement MP consumption
- [ ] 123. Implement MP regen rules
- [ ] 124. Implement insufficient MP handling
- [ ] 125. Add UI indicator for insufficient MP

## ATB

- [ ] 126. Create ATB resource system
- [ ] 127. Define ATB fill rules
- [ ] 128. Add ATB UI bar
- [ ] 129. Prevent command execution at zero ATB
- [ ] 130. Allow menu open at zero ATB

## Ability System

- [ ] 131. Create AbilitySystem
- [ ] 132. Define ability request pipeline
- [ ] 133. Define cast start/release/recovery phases
- [ ] 134. Define root-in-place casting rule
- [ ] 135. Define interruption integration
- [ ] 136. Define cooldown/resource structure

## First Spell

- [ ] 137. Implement one spell ability
- [ ] 138. Connect animation timing to spell release
- [ ] 139. Connect MP cost
- [ ] 140. Connect ATB cost
- [ ] 141. Block dodge cancel during spell
- [ ] 142. Verify enemy interruption works
- [ ] 143. Verify insufficient MP behavior
- [ ] 144. Verify spell returns valid state
- [ ] 145. Verify spell works while locked on
- [ ] 146. Verify spell works while not locked on

## Extension Path

- [x] 147. Add placeholder for additional abilities
- [x] 148. Ensure data-driven extension path
- [x] 149. Verify ability menu can scale
- [x] 150. Verify no hardcoded assumptions block expansion

---

# MACRO PHASE 7 — TACTICAL MODE CORE (151-175)

## Tactical Menu Framework

- [ ] 151. Create TacticalMenuState
- [ ] 152. Implement open/close input
- [ ] 153. Implement global slow-time to 10%
- [ ] 154. Restore time scale correctly on close
- [ ] 155. Add menu shell UI

## Menu Categories

- [ ] 156. Add Abilities category
- [ ] 157. Add Magic category
- [ ] 158. Add Items category
- [ ] 159. Add controller navigation
- [ ] 160. Add keyboard navigation

## Execution Rules

- [ ] 161. Grey out unavailable commands
- [ ] 162. Grey out commands lacking ATB
- [ ] 163. Grey out commands lacking MP
- [ ] 164. Permit viewing without resources
- [ ] 165. Execute command on confirm
- [ ] 166. Return safely after execution

## Tactical Restrictions

- [ ] 167. Block during stun
- [ ] 168. Block during knockdown
- [ ] 169. Block during cutscenes
- [ ] 170. Block during forced states

## Tactical Validation

- [ ] 171. Verify no incorrect combo reset
- [ ] 172. Verify lock-on preserved
- [ ] 173. Verify exits to correct state
- [ ] 174. Verify repeated open/close no softlock
- [ ] 175. Verify time scale cleanup

---

# MACRO PHASE 8 — HUD, MENUS, AND UX (176-200)

## Gameplay HUD

- [ ] 176. Add HP display
- [ ] 177. Add MP display
- [ ] 178. Add ATB display
- [ ] 179. Add target indicator
- [ ] 180. Add interaction prompt
- [ ] 181. Add quest tracker placeholder
- [ ] 182. Add control overlay if needed

## Pause / Main Menu

- [ ] 183. Create title screen
- [ ] 184. Add Continue option
- [ ] 185. Add New Game option
- [ ] 186. Add Options option
- [ ] 187. Add Exit option
- [ ] 188. Create pause menu
- [ ] 189. Add Resume
- [ ] 190. Add Inventory
- [ ] 191. Add Quest Log
- [ ] 192. Add Settings
- [ ] 193. Add Return to Title

## Menu Validation

- [ ] 194. Verify menu navigation on controller
- [ ] 195. Verify menu navigation on keyboard
- [ ] 196. Verify focus states visible
- [ ] 197. Verify menus do not corrupt gameplay
- [ ] 198. Verify pause cannot conflict with tactical
- [ ] 199. Verify menus recover after combat
- [ ] 200. Verify title-to-game flow

---

# MACRO PHASE 9 — INVENTORY & EQUIPMENT (201-230)

## Inventory Core

- [ ] 201. Create InventorySystem
- [ ] 202. Add Consumables category
- [ ] 203. Add Equipment category
- [ ] 204. Add Key Items category
- [ ] 205. Add item data structure
- [ ] 206. Add stack handling

## Equipment Slots

- [ ] 207. Implement Head slot
- [ ] 208. Implement Cape slot
- [ ] 209. Implement Chest slot
- [ ] 210. Implement Pants slot
- [ ] 211. Implement Shoes slot
- [ ] 212. Implement Gloves slot
- [ ] 213. Implement Left Hand slot
- [ ] 214. Implement Right Hand slot
- [ ] 215. Implement Accessory 1
- [ ] 216. Implement Accessory 2

## Equipment Effects

- [ ] 217. Add stat application
- [ ] 218. Add equipment swap logic
- [ ] 219. Add visual change hooks
- [ ] 220. Verify removing equipment restores state

## Item Use

- [ ] 221. Implement ally-target item use
- [ ] 222. Block invalid item targeting
- [ ] 223. Integrate tactical menu item selection
- [ ] 224. Integrate out-of-battle item use
- [ ] 225. Verify item quantity respected
- [ ] 226. Verify item use respects battle state
- [ ] 227. Verify no duplicate consumption
- [ ] 228. Verify item UI on controller
- [ ] 229. Verify item UI on keyboard
- [ ] 230. Verify equipment/inventory persists

---

# MACRO PHASE 10 — QUESTS & NPC INTERACTION (231-255)

## Interaction System

- [ ] 231. Create interaction prompt system
- [ ] 232. Implement NPC interaction
- [ ] 233. Implement chest interaction
- [ ] 234. Implement lever/object interaction
- [ ] 235. Verify interaction priority rules

## Dialogue

- [ ] 236. Create basic dialogue UI
- [ ] 237. Support controller dialogue advance
- [ ] 238. Support keyboard dialogue advance
- [ ] 239. Allow light story delivery
- [ ] 240. Support optional movement during conversations

## Quest Core

- [ ] 241. Create QuestSystem
- [ ] 242. Create active quest tracking
- [ ] 243. Create objective list
- [ ] 244. Create map marker hook
- [ ] 245. Create current quest display
- [ ] 246. Create story quest type
- [ ] 247. Create side quest type
- [ ] 248. Create exploration quest type

## Quest Log UI

- [ ] 249. Create quest log screen
- [ ] 250. Show tracked objectives
- [ ] 251. Show map markers
- [ ] 252. Show quest status
- [ ] 253. Verify quest UI on controller
- [ ] 254. Verify quest UI on keyboard
- [ ] 255. Verify quest progression updates

---

# MACRO PHASE 11 — SAVE SYSTEM (256-280)

## Save Core

- [ ] 256. Create SaveSystem
- [ ] 257. Implement autosave slot
- [ ] 258. Implement three manual save slots
- [ ] 259. Implement data versioning
- [ ] 260. Persist player position
- [ ] 261. Persist current zone
- [ ] 262. Persist inventory
- [ ] 263. Persist equipment
- [ ] 264. Persist quests
- [ ] 265. Persist party state
- [ ] 266. Persist progression flags

## Save UI

- [ ] 267. Create save slot UI
- [ ] 268. Create load slot UI
- [ ] 269. Create continue logic from title
- [ ] 270. Show save metadata

## Quicksave

- [ ] 271. Implement quicksave
- [ ] 272. Block quicksave during combat
- [ ] 273. Add feedback when quicksave blocked
- [ ] 274. Verify quicksave resumes valid state

## Zone Reset Rules

- [ ] 275. Reset enemy states per zone
- [ ] 276. Verify zone reload correct
- [ ] 277. Verify autosave trigger points
- [ ] 278. Verify no corrupted state after saves
- [ ] 279. Verify manual load restores valid state
- [ ] 280. Verify continue flow from main menu

---

# MACRO PHASE 12 — WORLD & TRAVERSAL (281-310)

## Towns / Zones

- [ ] 281. Create first town hub
- [ ] 282. Create second town hook
- [ ] 283. Create first field zone
- [ ] 284. Create first dungeon zone
- [ ] 285. Create zone transition logic
- [ ] 286. Create loading transition handling

## Exploration

- [ ] 287. Add hidden area structure
- [ ] 288. Add chest reward structure
- [ ] 289. Add exploration gating logic
- [ ] 290. Add simple puzzle framework
- [ ] 291. Add switch puzzle support
- [ ] 292. Verify puzzles do not break combat

## Traversal Expansion

- [ ] 293. Add double jump hook
- [ ] 294. Add climb refinement
- [ ] 295. Add wall-break hook
- [ ] 296. Add traversal gating via party
- [ ] 297. Verify camera stable during traversal
- [ ] 298. Verify traversal cannot bypass blockers

## World Validation

- [ ] 299. Verify semi-open routing
- [ ] 300. Verify transitions preserve state
- [ ] 301. Verify loading transitions safe
- [ ] 302. Verify autosave in world sane
- [ ] 303. Verify exploration rewards persist
- [ ] 304. Verify puzzle completion persists
- [ ] 305. Verify field-town-dungeon loop
- [ ] 306. Verify no traversal softlocks
- [ ] 307. Verify return paths exist
- [ ] 308. Verify world navigation on controller
- [ ] 309. Verify world navigation on keyboard
- [ ] 310. Verify world loop playable end-to-end

---

# MACRO PHASE 13 — PARTY SYSTEM (311-340)

## Party Foundations

- [ ] 311. Add second party member
- [ ] 312. Add AI companion logic
- [ ] 313. Add battle switching logic
- [ ] 314. Add out-of-battle switching
- [ ] 315. Add party roster structure

## Party Combat

- [ ] 316. Add ally follow/support behavior
- [ ] 317. Add ally ability usage
- [ ] 318. Add ally revive support
- [ ] 319. Add downed ally state
- [ ] 320. Add revive-in-battle logic

## Team Meter / Attacks

- [ ] 321. Create shared team meter
- [ ] 322. Define fill rules
- [ ] 323. Define expenditure rules
- [ ] 324. Add one team attack
- [ ] 325. Add team attack UI hook
- [ ] 326. Verify team meter persistence

## Party Traversal

- [ ] 327. Add party-specific traversal hook
- [ ] 328. Support traversal gating in world
- [ ] 329. Verify party traversal scene safety

## Party Validation

- [ ] 330. Verify switching does not corrupt camera
- [ ] 331. Verify switching does not corrupt lock-on
- [ ] 332. Verify switching does not corrupt tactical
- [ ] 333. Verify ally AI no softlock
- [ ] 334. Verify revive works reliably
- [ ] 335. Verify ally targeting for items
- [ ] 336. Verify party HUD updates
- [ ] 337. Verify save/load preserves party
- [ ] 338. Verify team attack state valid
- [ ] 339. Verify controller support for party
- [ ] 340. Verify party combat loop stability

---

# MACRO PHASE 14 — AUDIO & VFX (341-365)

## Audio

- [ ] 341. Create AudioManager
- [ ] 342. Add menu SFX hooks
- [ ] 343. Add basic attack SFX
- [ ] 344. Add dodge SFX
- [ ] 345. Add spell SFX
- [ ] 346. Add hit reaction SFX
- [ ] 347. Add town music
- [ ] 348. Add field music
- [ ] 349. Add dungeon music
- [ ] 350. Add battle music hook

## VFX

- [ ] 351. Add attack hit sparks
- [ ] 352. Add spell effect VFX
- [ ] 353. Add dodge effect
- [ ] 354. Add lock-on indicator
- [ ] 355. Add interaction prompt polish
- [ ] 356. Add menu transition polish
- [ ] 357. Add team attack visual hook

## Presentation Validation

- [ ] 358. Verify no SFX duplication bugs
- [ ] 359. Verify audio state changes
- [ ] 360. Verify VFX cleanup
- [ ] 361. Verify tactical slow-time audio
- [ ] 362. Verify target indicator clarity
- [ ] 363. Verify VFX does not obstruct gameplay
- [ ] 364. Verify controller prompts readable
- [ ] 365. Verify presentation does not destabilize gameplay

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

- [ ] 373. Add camera sensitivity option
- [ ] 374. Add controller rebinding support
- [ ] 375. Add audio volume settings
- [ ] 376. Add gameplay settings hooks
- [ ] 377. Verify text readability
- [ ] 378. Verify menu focus clarity

## Performance / Stability

- [ ] 379. Profile combat scene
- [ ] 380. Profile world scene
- [ ] 381. Verify no node leaks
- [ ] 382. Verify scene transitions free resources
- [ ] 383. Verify no repeated signal connections
- [ ] 384. Verify no duplicate autoload bugs

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

# Current Focus

Current Phase: Macro Phase 15 — Polish, QA, and Regression
Current Task: UX/accessibility, performance profiling, regression tests (combat polish complete)
Next Milestone: Polish & QA complete (item 400)

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

- Red Knight 3D model integrated (Mixamo rig, walking animation); enemies/NPCs still placeholders
- No audio assets
- Art pipeline: Mixamo for animations + Meshy AI for model generation

---

# Long-Term Vision

- Semi-open world with multiple connected regions
- Boss encounters with unique mechanics
- Full party system with AI companions
- Equipment-driven visual progression
- Cinematic story moments
- Replayable content through exploration quests

---

END OF FILE
