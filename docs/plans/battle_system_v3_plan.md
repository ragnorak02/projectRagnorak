# Battle System v3 — Battle Mode / Free Roam, Light-Heavy Combos, Character Ability

Created: 2026-11-12
Owner: Head Agent (reviews and verifies all work)
Status: IMPLEMENTED — AWAITING USER APPROVAL AND CONTROLLER TEST
Previous plans: `controller_remap_plan.md` (v1), `controls_v2_carry_plan.md` (v2), `ui_modernization_plan.md`

---

## How to use this file (ALL AGENTS READ FIRST)

The protocol is the same as earlier plans:
1. Do only your package's tasks.
2. Edit only your **Owned files**. Put any change needed in another agent's file under **Cross-Agent Requests**.
3. Status lifecycle: `IN PROGRESS` (Started time) → `DONE — AWAITING REVIEW` (Finished time + Handoff Notes). Tick tasks as you go, never delete them, and mark unnecessary ones `N/A` with a reason.
4. Before DONE, run a headless boot (`Z:/godot/godot.exe --path . --headless --quit-after 1`) and your listed suites, each with a timeout.
5. The plan file is edited concurrently. Re-read it before each edit, keep edits small and stay inside your own section.
6. Don't commit. Don't edit `project_status.json` or `CLAUDE.md`.
7. Godot is `Z:/godot/godot.exe`. If you add a `class_name`, run `--headless --import`.
8. **Controller-first.** Code is action-based, never raw buttons.
9. Use **unscaled time** (`Time.get_ticks_msec`, tweens with `set_ignore_time_scale(true)`) for every hold/tap timer and every UI tween. Hit-stop runs at 0.01 and tactical mode at 0.05.

Working directory: `Z:/Development/lumina/games/projectRagnorak`

---

## User request (2026-11-12)

- The game should have two modes, **Free Roam** and **Battle**, so that each can have its own controls, like the modern FF-style hybrid.
- **X is attack.** Tap = light attack, hold = heavy attack. There are 3-step combos, and they can be mixed:
  - Light + Light + Heavy ends in a good blast.
  - Heavy + Heavy + Heavy ends in a considerably larger, more powerful blast.
  - There are no animations yet, so show coloured arc effects in front of Amaro.
- **In battle, Y = the character's unique ability.** For Amaro, Y turns X into magic: tap X fires small orbs, hold X fires a larger fireball.
- **B = dodge roll.** In menus, B cancels one layer at a time.
- **No jump in battle.** Abilities can provide lift later. In free roam, **A = jump**.
- In battle, **A opens the Command Menu**, and A confirms inside it.
- In free roam, **Y is contextual:** it interacts when a prompt is showing, and opens the Command Menu otherwise.
- The menu (pause and Command Menu) can open **while airborne**. Leave moves open for now.
- **Tactical slow-down halves from 10% to 5%.** "I want it real slow."

---

## Approved Design

### Modes
- **Battle Mode** starts when any enemy engages: an `EnemyBase` whose ai_state isn't IDLE or DEAD (this check already exists as `player._any_enemy_engaged()`).
- It ends **3.0s** after the last engaged enemy disengages or dies. Use real time.
- `Events.battle_mode_changed(in_battle: bool)` is emitted on every change.
- `player.in_battle` is read-only.
- Entering battle while carrying drops the crate (reason `forced`). Picking up is blocked in battle.

### Controller layout v3

| Button | Free Roam | Battle | Menus |
|---|---|---|---|
| **A** (joy 0) | Jump (double jump) | **Command Menu** | Confirm (`ui_accept`) |
| **X** (joy 2) | Attack (tap light / hold heavy) | Attack (tap light / hold heavy) | — |
| **Y** (joy 3) | Interact / pick up. With no prompt: **Command Menu** | **Unique ability** (Amaro: toggle Arcane Stance) | — |
| **B** (joy 1) | Dodge roll | Dodge roll | Back one layer (`ui_cancel`) |
| L3 (joy 7) | Run (hold) | — (no sprint in battle) | — |
| RT (axis 5) | Lock-on | Lock-on | — |
| D-pad L/R | Target switch | Target switch | navigate |
| D-pad U/D | Party switch (gated off) | Party switch (gated off) | navigate |
| R3 | Camera reset | Camera reset | — |
| Start | Pause | Pause | close |
| LB, RB, LT | **unbound** (reserved: shortcuts, guard, ally commands) | | |

**Keyboard:**
- Unchanged: WASD, Mouse, Space jump (free roam), LMB attack (hold for heavy), Shift dodge, E interact, Q Command Menu (both modes), MMB lock-on, Esc pause, Ctrl run.
- **New:** **R = unique ability** in battle.

### Input-action model (important)
One physical button means different things per mode, so InputMap actions are **physical-role** actions, and the player translates them per mode:
- `jump` = A + Space.
- `interact` = Y + E.
- `attack` = X + LMB.
- `dodge` = B + Shift.
- `tactical_mode` = **Q only** (keyboard). Controller command access is routed: A in battle, Y with no prompt in free roam.
- `unique_ability` = **R only** (keyboard). Controller access is routed: Y in battle.
- `sprint` = L3 + Ctrl.

`player.gd` exposes routing helpers that **all** states use. No state may hardcode the mode logic.
- `is_command_press(event)`: true for `tactical_mode` in either mode, OR `jump` in battle, OR `interact` in free roam when there's no interactable.
- `is_jump_press(event)`: true for `jump` in free roam only.
- `is_interact_press(event)`: true for `interact` in free roam when an interactable is present.
- `is_unique_press(event)`: true for `unique_ability` in battle, OR `interact` in battle.

### Melee combos (X)
- **Tap vs hold:** a press released before **0.22s** is Light. Held to 0.22s, Heavy starts immediately, without waiting for release. Use real time.
- **The combo string** holds up to 3 steps, each L or H. The next input is buffered during each strike's combo window. The string resets if no input comes in that window, and on dodge, hit or mode change.
- **Step 3 is a finisher:**

  | String | Finisher | Blast radius | Damage | Stagger |
  |---|---|---|---|---|
  | L-L-L | quick triple slash | — | 1.0× | small |
  | any string containing 1 heavy, ending on H (L-L-H, L-H-H counts as 2) | **blast** | 2.5m | 1.6× | medium |
  | 2 heavies ending on H | **bigger blast** | 3.5m | 2.2× | high |
  | **H-H-H** | **huge blast** | **5m** | **3.0×** | very high, plus a short screen shake |
  | ending on L after heavies | strong slash | — | 1.2× | medium |

  The blast scales with the number of H in the string, and only fires when the 3rd step is H.
- **Light vs heavy:** light strikes are fast (about 0.35s). Heavy strikes are slower (about 0.6s) with more forward lunge.
- **Effects** (no animations exist, so these are the feedback):
  - Light: a thin pale-cyan arc in front of Amaro.
  - Heavy: a wider gold arc.
  - Blast: an expanding ring plus a sphere flash at the impact point, gold to white, sized by the radius.
  - Reuse and extend `src/effects/attack_vfx.gd`.
- **Stagger:** enemies gain `stagger_value` / `stagger_max`. Heavies and blasts build much more than lights.
  - At max, the enemy is STAGGERED for 4s and takes `stagger_damage_multiplier` 1.6× damage.
  - The target bar picks this up automatically (it duck-types `stagger_value`, `stagger_max` and `is_staggered()`).
- **Contract checks:** basic attacks are unlimited (no MP or stamina), and basic attacks can be cancelled into dodge (B).
- **Free roam:** X attacks normally. Jump + X in free roam is the existing JumpAttack.

### Unique ability (Y in battle) — data-driven per character
- `PartyMemberData` gains `unique_ability_id: StringName`. Amaro uses `&"arcane_stance"`. Taighe gets a placeholder and is AI-controlled for now.
- **Amaro: Arcane Stance**
  - Y toggles it on and off. Entering or exiting shows a cyan glow ring around Amaro, and the HUD shows an "ARCANE" tag.
  - In stance, **tap X** fires a volley of 3 small fast orbs (light damage, small stagger) toward the lock-on target or along facing.
  - In stance, **hold X** charges for 0.4s and then fires one **large fireball**: a bigger projectile with an AoE burst on impact and medium stagger.
  - Stance attacks cost **no MP**, because basic attacks are unlimited. The charged fireball has a 1.5s cooldown.
  - Dodge works in stance. Leaving battle exits the stance automatically.
- Reuse `src/effects/spell_projectile.gd` and `.tscn` (Fire Bolt) where possible.

### Menus and time
- Tactical (Command Menu) time scale: **0.05** (was 0.1).
- The Command Menu can open from **Jump, Fall and Land** (airborne) as well as the ground states.
  - While it's open, the player is frozen in place (velocity zero), as on the ground.
  - On close, return to Fall if airborne.
  - Leave the other airborne restrictions open, as the user asked.
- The pause menu already opens anytime during gameplay. Verify it opens mid-air.
- B in every menu backs out exactly **one layer**, and closes only at the top layer. This is already true for the tactical menu; verify the pause sub-menus (quest log, save/load, settings).

### Out of scope
Taighe's real unique ability, ally commands, LB shortcuts, guard/parry, synergy, real animations, and the party switch (it stays gated).

---

## Work Packages

- **Wave 1:** **Q**, the foundation. It runs first and publishes its API and stub nodes.
- **Wave 2 (parallel):** **R** (melee + stagger), **S** (unique ability), **T** (state routing + time + menus).
- **Wave 3:** **U** (HUD/hints for modes), then **V** (tests and screenshots), then head review.

---

### Package Q — Battle Mode Framework, Input Map v3, Routing API, Stub Nodes
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12T18:51) — API PUBLISHED: yes (2026-11-12T18:50)
Owned files:
- `project.godot` (`[input]` only), `scripts/autoloads/settings_manager.gd`
- `src/player/player.gd`, `src/player/player.tscn` (add nodes)
- **new** `src/combat/battle_mode_component.gd`
- `resources/characters/party_member_data.gd`, `hero.tres`, `companion.tres`
- **new stub scripts** that R and S will fill: `src/combat/combo_component.gd`, `src/player/states/melee_strike_state.gd`, `src/combat/stance_component.gd`

- [x] Q0. (Done by Head.) Ask Head (Cross-Agent Request) to add `Events.battle_mode_changed(in_battle: bool)`, `Events.combo_step(step: int, kind: StringName)`, `Events.combo_finisher(kind: StringName, radius: float)`, `Events.stance_changed(member_id: StringName, stance: StringName)` and `Events.enemy_staggered(enemy)`. *Head pre-adds these at launch.*
- [x] Q1. Input map:
  - `jump` = joy 0 + Space.
  - `interact` = joy 3 + E.
  - `dodge` = joy 1 + Shift.
  - `tactical_mode` = Q only (remove joy 0).
  - New `unique_ability` = R only.
  - `attack` and `sprint` unchanged.
  - `ui_accept` / `ui_cancel` unchanged (A / B).
  - Bump `BINDINGS_VERSION` to 4. Add `unique_ability` to `REBINDABLE_ACTIONS`.
- [x] Q2. `battle_mode_component.gd`: polls the existing engaged-enemy check about every 0.2s. Enters immediately; exits after 3.0s of real time with no engaged enemies. Emits `battle_mode_changed`. Exposes `in_battle`.
- [x] Q3. `player.gd`: add `in_battle` (read-only, from the component) and the four routing helpers exactly as specified, plus `get_member_data()` if missing. Replace `handle_contextual_command()` with `is_command_press()`. Keep `is_in_combat` working (tests use it). Entering battle tells `CarryComponent` to drop the crate (reason `forced`), through its public `drop()`.
- [x] Q4. `player.tscn`:
  - Add `BattleModeComponent`, `ComboComponent` (stub), `StanceComponent` (stub) and `StateMachine/MeleeStrike` (stub state that returns to Idle).
  - Stubs must boot cleanly. R and S replace their bodies.
  - Print the scene tree in Handoff Notes.
- [x] Q5. `PartyMemberData`: add `@export var unique_ability_id: StringName`. hero.tres = `&"arcane_stance"`, companion.tres = `&""`.
- [x] Q6. **Publish the API** (routing helpers, component APIs, stub contracts) in Handoff Notes, and set `API PUBLISHED: yes (time)`.
- [x] Q7. Run the headless boot. Expect test_controls to fail on binding asserts; V updates them. List the failures in Handoff Notes.

Handoff Notes:
- **API PUBLISHED (Q6).** Stubs boot clean; R/S replace bodies but keep these signatures.
- **InputMap v3 (runtime dump):** jump = Space / A(0); interact = E / Y(3); dodge = Shift / B(1); attack = LMB / X(2) (unchanged); sprint = Ctrl / L3(7) (unchanged); `tactical_mode` = **Q only** (joy 0 removed); **new `unique_ability` = R (keycode 82) only**; ui_accept / ui_cancel unchanged (A / B). LB(9) is now unbound. `SettingsManager.BINDINGS_VERSION = 4`, `&"unique_ability"` added to `REBINDABLE_ACTIONS`. `get_action_label(&"tactical_mode", true)` and `(&"unique_ability", true)` return `"---"` (controller access is routed, so U must label A/Y from the mode, not from the InputMap).
- **player.gd routing helpers** (all return false for echo events and while a dialogue box is open — preserves the v2 dialogue gate):
  - `is_command_press(event) -> bool`: `tactical_mode` (Q) either mode, OR `jump` (A/Space) in battle, OR `interact` (Y/E) in free roam with no interactable.
  - `is_jump_press(event) -> bool`: `jump` in free roam only.
  - `is_interact_press(event) -> bool`: `interact` in free roam when `has_interactable()`. (State gating stays in `can_interact_now()`; player `_unhandled_input` now uses `is_interact_press(event) and can_interact_now()`.)
  - `is_unique_press(event) -> bool`: `unique_ability` (R) in battle, OR `interact` (Y/E) in battle.
  - `in_battle: bool` (read-only getter → `BattleModeComponent.in_battle`).
  - `request_transition(target: StringName, msg := {}) -> bool`: transitions honouring illegal transitions; for time-driven entries (combo heavy-at-threshold, stance). Returns false if blocked/unknown.
  - `get_member_data() -> Resource`: PartySystem entry whose node is this player, else `hero.tres`.
  - Component refs: `player.battle_mode: BattleModeComponent`, `player.combo: ComboComponent`, `player.stance: StanceComponent` (`get_node_or_null`, so null-check if you build a player by hand).
  - Kept: `is_in_combat` (now `_combat_signal_active or in_battle or _any_enemy_engaged()`), `try_interact`, `can_interact_now`, `has_interactable`, `is_dialogue_active`, `try_double_jump`, `can_double_jump`, `consume_air_jump_pending`, `wants_sprint`, `set_sprinting`, jump buffer helpers.
  - `handle_contextual_command(event)` is kept as a **DEPRECATED shim** (returns `is_dialogue_active()`) only so the pre-T states compile; T replaces its 4 callers (idle/run/lock_on_idle/lock_on_strafe) with `is_command_press()`, then Q/Head can delete it.
  - New illegal transitions: `MeleeStrike → TacticalIdle`, `Flinch/LedgeGrab/ClimbUp → MeleeStrike` (mirror Attack1).
  - Battle enter → `CarryComponent.drop(&"forced")` if carrying (via `BattleModeComponent.changed`, fires before `Events.battle_mode_changed`). Carry/ThrowAim already return to Idle/Fall when `is_carrying` goes false. Pick-up in battle is blocked by routing (Y/E is the unique ability in battle, so `is_interact_press` is false); T5 may add an explicit guard.
- **`BattleModeComponent`** (`src/combat/battle_mode_component.gd`, class_name, Node child of Player): signal `changed(in_battle)`; read-only `in_battle`; exports `poll_interval_sec = 0.2`, `exit_delay_sec = 3.0`; `force_check(credit_ms := 0)` (poll now; tests can credit real ms), `force_exit(reason := &"forced")`, `get_exit_time_remaining() -> float`. Polls `player._any_enemy_engaged()` with `Time.get_ticks_msec()`; enters immediately; exit timer starts at the first clear poll (exit 3.0–3.2s after disengage); per-poll credit capped at 500ms so paused time doesn't count. `Events.zone_exiting` → `force_exit`. Emits `Events.battle_mode_changed` on every change.
- **`ComboComponent` stub** (`src/combat/combo_component.gd`, class_name) — R fills: `const HOLD_THRESHOLD_MS := 220`; `on_attack_pressed() -> StringName` and `on_attack_released() -> StringName` (return a state name for the caller's `process_input` to return, or `&""`; heavy-at-threshold is started by the component via `player.request_transition(&"MeleeStrike", {...})`); `current_string() -> String` ("", "L", "LH", "HHH"); `reset(reason := &"manual")` (reasons `&"dodge"`, `&"hit"`, `&"mode_change"`, `&"timeout"`, `&"manual"`). Events kind values `&"light"` / `&"heavy"`. **Stub:** press returns `&"Attack1"` (legacy combo keeps working), release returns `&""`, reset clears.
- **`MeleeStrike` stub state** (`src/player/states/melee_strike_state.gd`, `StateMachine/MeleeStrike`) — R fills. msg contract `{"kind": &"light"|&"heavy", "step": 1..3}` (empty msg = light, step 1); vars `kind`, `step`. **Stub:** returns Idle (Fall if airborne) on the first physics tick; `exit()` disables the hitbox.
- **`StanceComponent` stub** (`src/combat/stance_component.gd`, class_name) — S fills: `toggle() -> bool` (new active state), `is_active() -> bool`, `current_stance() -> StringName` (&"" = none), `handle_attack_press() -> bool`, `handle_attack_release() -> bool` (true = consumed), `exit_stance(reason := &"manual")`; var `ability_id` resolved at `_ready` from `player.get_member_data().unique_ability_id`. Already connected: `Events.battle_mode_changed(false)` → `exit_stance(&"battle_end")`. **Stub:** inert (never consumes).
- **PartyMemberData:** `@export var unique_ability_id: StringName = &""`; hero.tres `&"arcane_stance"`, companion.tres `&""`.
- **Scene tree additions (player.tscn, ext_resource ids 31-34, load_steps 31→35; no existing node edited):**
  ```
  Player (CharacterBody3D, player.gd)
    StateMachine
      ... (unchanged) ... Carry, ThrowAim
      MeleeStrike (Node, melee_strike_state.gd)        <- NEW stub
    ... CarryAnchor, CarryComponent
    BattleModeComponent (Node, battle_mode_component.gd) <- NEW
    ComboComponent (Node, combo_component.gd)            <- NEW stub
    StanceComponent (Node, stance_component.gd)          <- NEW stub
    ThrowArc
  ```
- **Files:** `project.godot` ([input] only: jump/dodge/interact joy index swaps, tactical_mode joy 0 removed, new `unique_ability` block after tactical_mode, events copied from existing lines); `scripts/autoloads/settings_manager.gd` (version 4 + REBINDABLE_ACTIONS); `src/player/player.gd`; `src/player/player.tscn`; `resources/characters/party_member_data.gd`, `hero.tres`, `companion.tres`; new `src/combat/battle_mode_component.gd`, `src/combat/combo_component.gd`, `src/combat/stance_component.gd`, `src/player/states/melee_strike_state.gd`. Ran `--headless --import` (3 new class_names).
- **Runtime check (scratch script, real player.tscn):** labels jump Space/A, interact E/Y, dodge Shift/B, tactical_mode Q/---, unique_ability R/---, attack LMB/X, sprint Ctrl/L3. Free roam: A → jump (not command), Y no prompt → command, Q → command, R → nothing. Battle: A → command (not jump), Y/E/R → unique, Space → not jump, Q → command. Exit: still in battle after 2.9s credited, out after 3.1s; signals `[true, false]`; real-time `_process` exit measured 3119ms. `request_transition(&"MeleeStrike", {kind heavy, step 2})` → MeleeStrike (kind=heavy) → Fall next tick; Flinch → MeleeStrike blocked. get_member_data → Amaro / arcane_stance; StanceComponent.ability_id = arcane_stance.
- **Boot (Q7):** `Z:/godot/godot.exe --path . --headless --quit-after 1` → exit 0, no errors/warnings. `test_runner` 35/35 pass.
- **Expected failures for V (all from v2 buttons the tests press/assert; none are logic regressions):**
  - `test_controls` 127/156 (29 fail): tactical_mode bound to A; jump bound to Y / not A; interact bound to B; dodge bound to LB / not B; LB drives only dodge; ui_accept overlaps only tactical_mode (now jump); ui_cancel overlaps only interact (now dodge); BINDINGS_VERSION is 3 (×2: const + runtime); controller labels tactical_mode=A (now '---'), jump=Y, interact=B, dodge=LB; interaction hint [B] (now [Y]); carry prompt "[B] Put Down / Hold [B] Throw" (now [Y]); "A next to an interactable opens the Command Menu"; "B interacts in PLAYING" and its follow-on "Keyboard E interacts" (counts calls cumulatively, E itself works); "B inside the Command Menu does not interact" (menu didn't open via A); "Y on the floor enters Jump" + 3 double-jump follow-ons; 4 untargeted-spell asserts (they open the menu with A, which now jumps).
  - `test_carry` 61/74 (13 fail): jump while carrying presses Y (now interact → put down) and 2 follow-ons; tap B put-down + 6 follow-ons; hold B → ThrowAim, rooted, hold B + X throw (B is now dodge; Y is interact).

---

### Package R — Light/Heavy Mixable Combos, Blast Finishers, Stagger
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12)
Owned files: `src/combat/combo_component.gd`, `src/player/states/melee_strike_state.gd`, `src/player/states/attack_1_state.gd`, `attack_2_state.gd`, `attack_3_state.gd`, `jump_attack_state.gd`, `src/effects/attack_vfx.gd`, **new** `src/effects/blast_vfx.gd`, `src/enemies/enemy_base.gd`

- [x] R1. `combo_component.gd`:
  - Tap/hold detection on `attack`: 0.22s threshold on real time. Heavy starts at the threshold, light on release.
  - Holds the combo string (max 3), the input buffer during the combo window, and the reset rules.
  - API: `on_attack_pressed()`, `on_attack_released()`, `current_string()`, `reset(reason)`.
  - Emits `Events.combo_step` / `combo_finisher`.
- [x] R2. `melee_strike_state.gd`:
  - One data-driven strike state: kind L/H, step 1–3, duration, hit window, lunge, damage, stagger and arc VFX. Uses the existing player hitbox API (`enable_hitbox` / `disable_hitbox`).
  - Can cancel into dodge (contract: basic attacks cancel into dodge).
  - Step 3 runs the finisher table from the Approved Design.
- [x] R3. Existing Attack1/2/3 states:
  - Prefer routing X into MeleeStrike and keeping the old states (tests may reference them; grep `tests/`).
  - Only change them if needed, and keep any strings the tests look for.
  - JumpAttack (free roam, airborne) unchanged except the VFX colour.
- [x] R4. VFX:
  - Light arc is thin pale cyan. Heavy arc is wide gold.
  - New `blast_vfx.gd`: an expanding ring plus a flash sphere sized by radius. Damage applies to every enemy in radius once (an Area3D or distance query). H-H-H adds a small camera shake **through an existing event or signal**; never touch camera internals.
- [x] R5. `enemy_base.gd`:
  - Add `stagger_value`, `stagger_max` (default 100), `is_staggered()`, `stagger_damage_multiplier` (1.6), `add_stagger(amount)` and a STAGGERED state (4s, can't act, decays afterwards). Emit `Events.enemy_staggered`.
  - `take_damage` applies the multiplier while staggered.
  - Don't change the AI spacing logic.
- [x] R5b. (From UI review CAR-P4.) Restyle the enemy overhead HP bar and damage numbers in `enemy_base.gd` to the Lumina Frost palette (`UIStyle` colours and font). Thin cyan-to-red HP strip with a dark backing; damage numbers in the UIStyle body font, white with an outline, gold for crits/blasts and orange while staggered.
- [x] R6. Headless runtime checks:
  - L-L-L, L-L-H and H-H-H strings produce the right finishers and radii.
  - H-H-H damage is greater than L-L-H damage, which is greater than L-L-L damage.
  - Stagger fills and triggers.
  - Dodge cancels a light strike.
  - Report the numbers.

Handoff Notes:
- **Q's published signatures are unchanged**, so no request was filed.
  - `on_attack_pressed()` returns `&""` on the ground (the kind isn't known at press), or `&"JumpAttack"` when airborne outside a strike.
  - `on_attack_released()` returns `&"MeleeStrike"` when a light should start or chain now. The component holds the pending `{kind, step, string}`, and `MeleeStrike.enter()` pulls it when the msg is empty.
  - The heavy at 0.22s is started by `ComboComponent._process` through `player.request_transition(&"MeleeStrike", msg)`.
  - Hold timing uses `Time.get_ticks_msec()`. Strike timing uses game time, so hit-stop freezes it.
- **Additive R-internal API:**
  - ComboComponent: `get_finisher(string)` and `get_finisher_data(kind)` (static), `FINISHERS`, `take_pending_strike()`, `notify_strike_started/finished/exited()`, `has_buffered()`, `consume_buffered()`, `is_hold_pending()`, `last_reset_reason`.
  - MeleeStrike: `can_chain()`, `last_blast`.
- **Reset rules:**
  - New reset reason `&"complete"`: the finisher ended.
  - The mode-change reset is skipped while a strike or hold is running. The opening hit of a fight engages the enemy, and the reset would otherwise eat the string it starts.
  - The string also resets on `Events.player_hurt`, and when the player leaves the attack flow (Dodge, Flinch, TacticalIdle and so on; polled in `_process`).
- **Buffer:**
  - One slot, latest wins. Input is accepted at any point in a strike and chains at the strike's `chain_at`.
  - The window stays open 300ms real after a strike ends, so a hold that crosses the end still continues the string.
  - Input during the step-3 finisher is ignored.
- **Strike data** (`STRIKES` in `melee_strike_state.gd`):
  - Light: 0.35s, hit 0.06–0.20, chain 0.17, lunge 4.0 m/s × 0.10s, 12 dmg, 6 stagger.
  - Heavy: 0.60s, hit 0.18–0.36, chain 0.36, lunge 6.5 × 0.18s, 20 dmg, 18 stagger.
  - Blasts run 0.15s longer.
  - The lunge stops if an enemy is under 1.4m ahead, so models don't overlap. Enemy AI and spacing are untouched.
  - Dodge cancels at any point (when `dodge_ready`) and resets the string. No MP or ATB cost.
- **Finishers** (`ComboComponent.FINISHERS`; the multiplier applies to the step-3 strike's base damage):

  | Kind | Strings | Mult | Damage | Radius | Stagger |
  |---|---|---|---|---|---|
  | triple_slash | LLL | 1.0× | 12 | 0 | 10 (3 pale arcs) |
  | strong_slash | ending on L after heavies | 1.2× | 14.4 / 24 | 0 | 16 |
  | blast | 1 H, ending on H | 1.6× | 32 | 2.5 | 30 |
  | big_blast | 2 H, ending on H (LHH/HLH) | 2.2× | 44 | 3.5 | 45 |
  | huge_blast | HHH | 3.0× | 60 | 5.0 | 70, plus shake |

  - HHH shake: `Events.camera_shake_requested.emit(0.35, 0.35)`. camera_rig already listens, so no camera code was touched and no request was needed.
  - The blast centre is 1.5m in front of Amaro. `BlastVFX.detonate()` hits every living enemy in the radius once: a distance query on group `enemies`, ±2.5m vertical, calling `take_damage(dmg, player, &"blast")` and `add_stagger`.
  - Blast finishers don't use the hitbox, so there is no double hit.
- **VFX:**
  - New `AttackVFX.spawn_strike(parent, pos, fwd, kind, step, delay, tilt)`. Light is thin pale cyan `(0.62,0.93,1.0)`; heavy is wide gold `(1.0,0.74,0.25)`.
  - Legacy `spawn()` and its 4-colour table are kept, so the test strings are intact. The Jump Attack colour is now pale gold.
  - New `src/effects/blast_vfx.gd`: a ground ring expanding to the radius plus a sphere flash, gold to white. HHH adds a second white shock ring.
- **Stagger** (`enemy_base.gd`):
  - Fields: `stagger_value`, `stagger_max` = 100, `stagger_damage_multiplier` = 1.6, `is_staggered()`, `add_stagger(amount)`.
  - Exports: `stagger_break_time` = 4.0, `stagger_decay_delay` = 2.5, `stagger_decay_rate` = 12/s.
  - `AIState.STAGGERED` is **appended**, so existing indices are unchanged. It still counts as engaged for battle mode.
  - During a break: hitbox off, can't act, orange tint and a slight lean, and `Events.enemy_staggered` is emitted. Hits during a break don't flinch (no HURT re-entry). Afterwards the enemy returns to CHASE and the gauge drains at 60/s.
  - `take_damage(amount, source = null, hit_kind := &"")`: the third param is optional, so old callers are unchanged.
  - MeleeStrike sets `stagger` and `hit_kind` metas on the player hitbox (cleared at the end of the hit window and on exit), and `_on_hurtbox_hit` applies them.
  - Fixed: the enemy body material is now duplicated per instance. It was a shared sub-resource, so a flash or tint recoloured every enemy.
- **R5b:**
  - The overhead bar is a 0.05m HP strip: cyan, then stagger orange at 50%, then danger red at 25% (`hp_bar_color()`).
  - A hairline orange stagger strip sits below it (gold while broken), on a `UIStyle.GLASS_DEEP` backing.
  - Fills stay left-aligned through `QuadMesh.center_offset`, which is billboard-safe.
  - The bar now also shows on first damage.
  - Damage numbers use `UIStyle.font_body_bold()`, white with a dark outline. Blasts and finishers are gold and larger; numbers are orange while the enemy is staggered.
- **R3:** the attack_1/2/3 and jump_attack state files are untouched. X now routes to MeleeStrike through T's states, and the test_phase7/14/15 string checks still pass.
- **R6 runtime** (scratch script with the real player.tscn and enemy.tscn; e1 is 1.6m ahead, e2 is off-axis at 1.8/-2.6):

  | String | Finisher | Radius | Blast dmg (hits) | e1 dmg | Total dmg | e1 stagger |
  |---|---|---|---|---|---|---|
  | LLL | triple_slash | 0 | — | 36 | 36 (e2 untouched) | 22 |
  | LLH | blast | 2.5 | 32 (×2) | 56 | 88 | 42 |
  | LHH / HLH | big_blast | 3.5 | 44 (×2) | 76 | 120 | — |
  | HHH | huge_blast | 5.0 | 60 (×2) | 100 | 160 | 100 → STAGGERED |
  | HHL | strong_slash | 0 | — | — | 54.4 | — |
  | LHL | strong_slash | 0 | — | — | 46.4 | — |

  - **Order HHH 160 > LLH 88 > LLL 36: true.**
  - HHH emitted the shake (0.35, 0.35); LLH emitted none.
  - Hold at `Engine.time_scale = 0.01`: the heavy fired after 228ms real.
  - Dodge from a light strike: state `Dodge`, string '' (reset `dodge`).
  - Stagger:
    - Six adds of 18 gave [18,36,54,72,90,100], then STAGGERED and one `enemy_staggered`.
    - 10 dmg while staggered dealt 16.0 (1.6×).
    - The break lasted 3.97s, then CHASE. The gauge was 0 after recovery.
    - All duck-typed fields are present.
  - Timeout: a single tap, then idle, leaves string '' (reset `timeout`).
  - Real InputEvents through T's Idle/MeleeStrike: tap, tap, hold gave steps [1 light, 2 light, 3 heavy] and finisher `blast` 2.5.
- **Boot and suites:** headless boot exit 0, no errors.
  - Pass: test_runner 35/35, test_phase7 23/23, test_phase13 64/64, test_phase14 67/67, test_phase15 68/68, test_battle 129/129, test_carry 78/78, test_controls 208/208.
  - Failing, not in R's files:
    - test_performance: "Exactly 7 autoloads (got 8)".
    - test_ui_style: 6 pad-glyph asserts (Q's remap, for V).
    - test_phase8: "New Game loads test arena".
    - test_phase12: "return portals".

---

### Package S — Unique Ability Framework + Amaro's Arcane Stance
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12)
Owned files: `src/combat/stance_component.gd`, **new** `src/combat/unique_abilities/arcane_stance.gd`, **new** `src/effects/arcane_orb.gd` (+ `.tscn` if needed), **new** `src/effects/stance_aura_vfx.gd`; `src/effects/spell_projectile.gd` (extend only, without breaking Fire Bolt)

- [x] S1. `stance_component.gd`:
  - Loads the unique ability from `PartyMemberData.unique_ability_id` (a registry dict of id → script).
  - API: `toggle()`, `is_active()`, `current_stance()`, `handle_attack_press()`, `handle_attack_release()` (returns true if consumed), `exit_stance(reason)`.
  - Emits `Events.stance_changed`. Leaves the stance on `battle_mode_changed(false)`.
- [x] S2. `arcane_stance.gd`:
  - Tap X: a volley of 3 small orbs, staggered 0.06s apart, toward the lock target or facing.
  - Hold X: a 0.4s charge (show a growing orb at the hand), then one large fireball with an AoE burst and a 1.5s cooldown.
  - Uses real time. No MP cost.
- [x] S3. Orbs and fireball:
  - Use projectile scripts that call enemy `take_damage` and `add_stagger` (R5; check for it with `has_method` until R lands).
  - Small orb: 6 dmg, stagger 4. Fireball: 25 dmg, stagger 20, burst radius 2.5m.
- [x] S4. `stance_aura_vfx.gd`: a cyan ring and a soft glow at Amaro's feet while the stance is active.
- [x] S5. Integration contract with R and T:
  - In battle, T's states call `stance.handle_attack_press/release` **first**. If it returns true, the attack is consumed and no melee happens.
  - Coordinate this by Cross-Agent Request.
- [x] S6. Headless runtime checks: toggle on and off; tap spawns 3 orbs; hold spawns a fireball; the cooldown blocks a second charged shot; leaving battle exits the stance; Fire Bolt still works.

Handoff Notes:
- **Q's published signatures are unchanged** (`toggle`, `is_active`, `current_stance`, `handle_attack_press/release`, `exit_stance`, `ability_id`). No request to T was needed. T's states already call them (idle/jump/fall/dodge, etc.).
- **`StanceComponent`** (`src/combat/stance_component.gd`):
  - `REGISTRY` (:33) maps id → script path. Adding a character's Y ability takes one script, one registry line and the id in their `.tres`. `refresh_ability()` (:53) re-resolves from `player.get_member_data()` and is also called on every enter attempt.
  - `toggle()` (:80) enters only if the player is `in_battle`, GameState is PLAYING, HP > 0 and the ability is registered. Exiting is always allowed.
  - `current_stance()` returns the ability id (`&"arcane_stance"`); `&""` means off.
  - Extras for U: `get_display_name()` → `"ARCANE"`, and `stance.ability`. The ability exposes `is_charging()`, `get_charge_progress()`, `get_cooldown_remaining()`, `is_fireball_on_cooldown()`, signals `projectile_spawned`, `charge_started`, `charge_cancelled`, and counters `volleys_fired`, `orbs_fired`, `fireballs_fired`.
  - `Events.stance_changed(member_id, stance)` fires on enter, and with `&""` on exit. Runtime: `[&"hero", &"arcane_stance"]`, then `[&"hero", &""]`.
  - `battle_mode_changed(false)` → `exit_stance(&"battle_end")`.
  - `handle_attack_release()` returns true only if the matching press was taken by the stance. A press made before entering the stance falls through to the combo.
- **`arcane_stance.gd`** (`src/combat/unique_abilities/`), all on real time (`Time.get_ticks_msec`), no MP cost:
  - Tap (release < 220ms, the same split as melee) fires 3 orbs 60ms apart. The first goes out on the release frame. They fan out ±0.25m and home on the lock target, or fly along facing.
  - Hold ≥ 220ms starts a 400ms charge with a growing orb, `ArcaneChargeOrb`, front-right of the player. The fireball **auto-fires at about 620ms** and starts a 1.5s cooldown. The later release is consumed with no extra shot.
  - Releasing mid-charge cancels the shot (it fizzles). A hold during the cooldown doesn't charge, and its release fires a volley, so the stance never goes dead.
  - `BLOCKED_STATES` (:29) is Dodge, Flinch, LedgeGrab, ClimbUp, TacticalIdle, Ability, Carry and ThrowAim. Those states, a GameState other than PLAYING, or HP 0 cancel the charge and queued orbs, and mark the hold spent, so a missed release fires nothing. Dodge itself is never blocked.
- **`arcane_orb.gd`** (`class_name ArcaneOrb`, extends `spell_projectile.gd`; `ArcaneOrb.create(Kind.ORB|FIREBALL)`):
  - Damage is direct. It calls `take_damage(dmg, player)`, then `add_stagger(st)` if `has_method`. It sets no hurtbox meta, so damage is never applied twice. Dead enemies are skipped (the orb keeps flying).
  - Orb: 6 dmg, stagger 4. Fireball: 25 dmg, stagger 20.
  - The fireball's 2.5m AoE hits the direct target, then every other live enemy within reach, once each. It bursts on expiry too. The burst VFX is an unscaled tween.
- **`spell_projectile.gd`** (extend-only; defaults reproduce Fire Bolt exactly): adds the hook vars `hit_radius`, `visual_radius`, `core_color`, `glow_color`, `glow_energy` and `use_hurtbox_meta` (default true; the meta is set only when it's true), plus a virtual `_on_expired()` (default `queue_free`). Fire Bolt's behaviour and tween are untouched.
- **`stance_aura_vfx.gd`** (`class_name StanceAuraVfx`): `attach(player)` adds a persistent `StanceAura` child: a cyan torus ring, a translucent disc glow and an OmniLight, pulsing on real time. `flash(parent, pos, entering)` plays a one-shot expanding/contracting ring (unscaled tween) on enter/exit.
- Ran `--headless --import` (2 new class_names). **Boot:** exit 0, no errors or warnings.
- **S6 runtime (scratch SceneTree script, real `player.tscn` + `enemy.tscn` + floor): 38/38 PASS.**
  - Toggle is blocked in free roam. On/off works, and the aura is attached and removed.
  - Tap: 3 orbs, spawned at +0 / +55 / +117ms real time. Enemy HP 1000 → 982 (3×6). `stagger_value` 12.0 through R's `add_stagger`.
  - Hold: charging at 300ms (progress 0.20). The fireball fired at 628ms after the press, HP −25. The release was consumed with no volley.
  - Cooldown: a second hold right after doesn't charge (fireballs stays 1, 0.48s left), and its release fires a volley. After 1.5s a hold fires the fireball again.
  - A release mid-charge cancels the shot.
  - AoE: enemies at 0m and 1.5m apart each take −25.
  - A dodge mid-charge cancels it, and the release fires nothing.
  - TACTICAL_MODE mid-charge cancels it, there's no fireball after closing even with no release forwarded, and the next tap works.
  - `force_exit` of battle exits the stance and emits `&""`. Presses afterwards aren't consumed.
  - **Fire Bolt** (`spell_projectile.tscn`) keeps its damage meta and deals exactly 25, once.
- **Suites:** `test_runner` 35/35, `test_phase14` 67/67, `test_phase6_runner` 110/111. The one failure is "TacticalIdle has slot navigation", a source-string check that `tactical_idle_state.gd` contains `_navigate_slot`. That file is T's, so this isn't from S (see the request to T/V).

---

### Package T — State Routing, No-Jump Battle, Airborne Menu, Time 0.05, Menu Layers
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12)
Owned files:
- `src/player/states/idle_state.gd`, `run_state.gd`, `jump_state.gd`, `fall_state.gd`, `land_state.gd`, `lock_on_idle_state.gd`, `lock_on_strafe_state.gd`, `dodge_state.gd`
- `tactical_idle_state.gd`, `carry_state.gd`, `throw_aim_state.gd` (routing only)
- `scripts/autoloads/game_manager.gd`

- [x] T1. Every gameplay state uses Q's routing helpers:
  - Command → TacticalIdle.
  - Jump only in free roam (A does nothing as a jump in battle).
  - Interact only in free roam.
  - Unique → `StanceComponent.toggle()`.
  - Attack → first `stance.handle_attack_press` (battle), else `ComboComponent.on_attack_pressed`.
  - Releases are forwarded to both components, because hold detection needs the release.
  - Sprint is ignored in battle.
- [x] T2. Airborne Command Menu: Jump, Fall and Land accept the command press and enter TacticalIdle. TacticalIdle remembers whether it opened airborne and returns to Fall on close.
- [x] T3. `tactical_idle_state.gd`:
  - Confirm is `ui_accept` only. Remove the "non-key `tactical_mode` = confirm" path, since A is no longer `tactical_mode`. Keep the open-press guard: A in battle opens the menu and also equals `ui_accept`.
  - Keyboard Q still toggles the menu closed.
  - B backs out one layer. Verify this.
- [x] T4. `game_manager.gd`: tactical time scale 0.1 → **0.05** (a named const). Grep tests for 0.1 assertions (test_phase7 checks `is_equal_approx(Engine.time_scale, 0.1)`) and file a request to V.
- [x] T5. Carry: pick-up only in free roam. CarryState and ThrowAimState read throw/put-down through `interact` as before, which is Y on controller now. Verify the hold-Y-to-aim plus X-to-throw flow still works.
- [x] T6. Pause menu mid-air: verify it opens while airborne and that resuming continues the fall correctly. Verify that B backs out one layer in the quest log, save/load and settings, and closes the pause menu only at the top. File requests if any of the menu files need changes (they're not yours).
- [x] T6b. (From UI review.) After closing the Command Menu while locked on, the player sometimes ends in Idle rather than LockOnIdle (screenshot 18, after switching to a farther Sentry and pressing B three times). Find out whether lock-on drops by range during tactical mode, and fix it so closing the menu restores lock-on when the target is still valid.
- [x] T7. Headless runtime checks:
  - Free roam: A jumps, Y with no prompt opens the menu, Y near an NPC interacts.
  - Battle: A opens the menu and does not jump; Y toggles the stance.
  - The menu opens mid-air, freezes the player, and returns to Fall on close.
  - Time scale is 0.05 in the menu.

Handoff Notes:
- **T1 routing (all via Q helpers; no mode logic in states).** Idle/Run/LockOnIdle/LockOnStrafe: attack press -> `_route_attack_press()` (battle: `stance.handle_attack_press()` first, else `combo.on_attack_pressed()`); attack **release** -> `_route_attack_release()` (forwarded to BOTH; a stance-consumed release wins); dodge; lock_on; `is_command_press` -> TacticalIdle; `is_unique_press` -> `stance.toggle()` + handled; `is_jump_press` -> Jump (idle_state.gd:29-65, run_state.gd:55-91, lock_on_idle_state.gd:30-71, lock_on_strafe_state.gd:40-81). Jump/Fall: same; attack press -> stance first in battle, else JumpAttack; jump only via `is_jump_press` (jump_state.gd:41-77, fall_state.gd:35-71). Dodge: `combo.reset(&"dodge")` on enter; forwards releases but ignores returned states (dodge_state.gd:17-19, 54-62). No sprint in battle (run_state.gd:38). Carry jump via `is_jump_press` (carry_state.gd:106). The 4 `handle_contextual_command` callers are gone, so Q/Head can delete the shim.
- **T2.** Jump/Fall return TacticalIdle on the command press. `Land -> TacticalIdle` stays illegal (player.gd blocklist; test_phase7 asserts it), so Land **buffers** the press and opens the menu from Idle/LockOnIdle at the end of the 0.1s recovery via `request_transition` (land_state.gd:8-35, 44-46). Land now ends in LockOnIdle/LockOnStrafe when locked. TacticalIdle stores `_opened_airborne`, and `_exit_to_idle()` returns Fall if still airborne (tactical_idle_state.gd:31, 43, 233-242).
- **T3.** Confirm = `ui_accept` only, behind the open-press guard (tactical_idle_state.gd:227-228); the pad-`tactical_mode` confirm is removed. Close = Start or keyboard Q (key-only check kept). `_is_menu_owned_event` + `set_input_as_handled` kept (+ `unique_ability`), so B never dodges. Enter resets the combo, so a pending hold can't start a heavy from inside the menu (tactical_idle_state.gd:46-50).
- **T4.** `GameManager.TACTICAL_TIME_SCALE := 0.05` (game_manager.gd:15, 33). test_phase7 is already updated by V (23/23).
- **T6b root cause: not range.** TacticalIdle's target highlight emits `Events.lock_on_target_acquired(candidate)`, which overwrites `player.lock_on_target`. Leaving target select emitted `Events.lock_on_target_lost`, which cleared `player.is_locked_on` while `LockOnComponent.current_target` still held the original Sentry (desync). B x3 then reached `_exit_to_idle()` with `is_locked_on == false` -> Idle. Repro: after highlight + lost, `player.is_locked_on=false` while the component still = e1; the farther Sentry is 11.7m, under the 30m drop range. **Fix:** `_restore_lock_on()` (tactical_idle_state.gd:251-261) re-announces the component's target if it's valid and in range, else emits lost. `_cancel_target_selection`, `exit()` and `_exit_to_idle()` use it (`_exit_to_idle` restores before choosing LockOnIdle/Idle).
- **T7 runtime (scratch harness, real player.tscn, real `Input.parse_input_event`): 39/39 PASS.**
  - Free roam: A -> Jump. Y with no prompt -> TacticalIdle, time_scale 0.05; B -> Idle and 1.0 restored. Y near an NPC -> interact calls=1, no menu.
  - X press -> combo (stance skipped); release -> both. Dodge resets the combo (`dodge`).
  - Airborne: Y in Jump -> menu; drift 0.0006m over 30 frames, vel 0, still airborne; B -> Fall. Q from Fall opens/closes -> Fall. Q during Land -> menu after recovery.
  - Battle: A -> TacticalIdle with vy 0 / dy 0 (no jump), scale 0.05; the opening A doesn't confirm; B -> Idle (no dodge). Y and R toggle the stance (S's real stance went active). X -> stance first. Sprint off.
  - T6b: lock e1 -> Abilities -> Fire Bolt -> highlight e2 -> B x3 -> LockOnIdle with player and component on e1. Start from target select also restores. The unlocked case leaves no lock.
- **T5/T6 runtime: 28/29.** Pause opens mid-air, the player is frozen while paused, and Start resumes the jump, which lands normally. B in quest log / save-load / settings closes only the sub-menu, a 2nd B closes pause, no dodge; the save overwrite confirm backs out one layer. Y picks up a crate -> hold Y -> ThrowAim -> X throws -> Idle. In battle, Y near a crate does not pick it up. **1 FAIL (not my file):** Start while Settings is open closes the pause menu and leaves Settings open over gameplay (settings_menu.gd doesn't handle `pause`; quest log and save do). Request filed to Head.
- **Boot:** exit 0, no output. **Suites:** test_runner 35/35, test_phase7 23/23, test_carry 76/76, test_phase13 64/64, test_phase15 68/68, test_controls 203/208 (5 = V harness issues; request filed). test_phase8 64/65 ("New Game loads test arena scene") and test_phase12 64/65 ("Field and dungeon have return portals") fail outside T's files.

---

### Package U — Mode-Aware HUD & Hints
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12)
Owned files: `src/ui/hud/control_bar.gd`, `src/ui/hud/combat_hud.gd`, `src/ui/hud/tactical_menu.gd` (hints only), `src/ui/hud/interaction_prompt.gd` (glyph only), **new** `src/ui/hud/battle_banner.gd`

- [x] U1. Context hints use the routing:
  - Free roam: A Jump · X Attack · B Dodge · Y Interact/Command.
  - Battle: A Command · X Attack (hold Heavy) · Y Arcane Stance · B Dodge.
  - In stance: X Orbs (hold Fireball) · Y Exit Stance.
  - Carrying: Y Put Down / hold Y Throw.
- [x] U2. `battle_banner.gd`: a short slanted "BATTLE" banner on `battle_mode_changed(true)` and a subtle "CLEAR" on exit. It fades in unscaled time. Head registers it in zone_base and test_arena.
- [x] U3. `combat_hud.gd`: an "ARCANE" stance tag on the active row while the stance is on, plus a small combo-step indicator (L/H pips) above the party panel during a string.
- [x] U4. Command Menu hints: A Confirm, B Back. Check that the glyphs are right after Q's remap.
- [x] U5. Screenshots (windowed): free-roam hints, battle hints with the banner, stance on, the combo pips mid-string, an H-H-H blast, the airborne command menu.

Handoff Notes:
- **Files:** `src/ui/hud/control_bar.gd`, `src/ui/hud/combat_hud.gd`, `src/ui/hud/interaction_prompt.gd`, and the new `src/ui/hud/battle_banner.gd` (no class_name). `tactical_menu.gd` didn't need an edit (see U4). No other files were touched.
- **U1 `control_bar.gd`** (Q's request, CAR to U: DONE):
  - New contexts `BATTLE` and `STANCE` are appended to `Context`. They're picked from `player.in_battle` and `player.stance.is_active()`, both polled each frame, plus `Events.battle_mode_changed` / `stance_changed` for a same-frame swap. Carry/Aim still win over battle.
  - Hint sets as specified. Free roam: A Jump · X Attack · B Dodge · Y Command; with a prompt, pad Y reads **Interact** (keyboard keeps Q Command and adds E Interact). Battle: A Command · X Attack · Hold Heavy · Y Arcane Stance · B Dodge. Stance: A Command · X Orbs · Hold Fireball · Y Exit Stance · B Dodge. Carry/Aim are unchanged and already read Y (`interact`).
  - **Routed glyphs:** hint entries `[action, text, role]` with role `&"command"` / `&"unique"` set `ButtonGlyph.label_override` from the new `static routed_label(role, in_battle, controller)`. Pad: Command = `jump`'s button (A) in battle, `interact`'s button (Y) in free roam; Unique = `interact`'s button (Y). Keyboard: the real `tactical_mode` (Q) / `unique_ability` (R) binding. Pad labels come from `get_action_label(jump/interact)`, so they follow rebinds, and "---" never shows. `static routed_action()` gives the physical action for the gold held highlight.
  - The unique hint text is `stance.ability_id.capitalize()` ("Arcane Stance"); it's dropped for a member without a registered ability.
  - Device changes rebuild the set (overrides are per-device).
  - Kept: `CONTROLS` (v2 order, untouched), `refresh_labels()`, `get_control_label()`. Added `get_hint_entries() -> [[glyph label, text], ...]`.
- **U2 `battle_banner.gd`** (CanvasLayer, layer 10): a SlantPanel at 22% screen height, centred.
  - "BATTLE": gold Rajdhani 56, ember top line and side accents. Fades/slides in 0.16s, holds 1.1s, fades out 0.4s.
  - "CLEAR": cyan, smaller, 85% alpha. 0.22s in / 0.7s hold / 0.5s out.
  - All tweens are unscaled (`UIStyle.ui_tween`).
  - CLEAR is deferred one call and skipped if `Events.zone_exiting` fired, so no CLEAR shows over a load. The banner fades out fast when the Command Menu opens.
  - API: `get_text()`, `is_showing()`, `get_counts()`, `show_battle()`, `show_clear()`.
  - **Not registered yet.** See the request to Head below.
- **U3 `combat_hud.gd`:**
  - **Stance tag:** a cyan "ARCANE" pill next to the name on the **active** row, from `Events.stance_changed`; the text is `stance.get_display_name()`. It pulses softly (unscaled) and is re-applied after roster rebuilds.
  - **Combo pips:** a glass pill right-aligned above the rows reading "COMBO [L][H][ ]". The pips are skewed boxes: L is cyan, H is gold and wider. It's driven by `Events.combo_step` (step 1 clears).
  - `combo_finisher` adds the finisher name ("BLAST", "BIG BLAST", "HUGE BLAST"; radius ≥3 is larger and brighter, slashes are cyan).
  - `combo_reset` holds the string 0.55s real time (+0.5s after a finisher), then fades over 0.25s.
  - Helpers: `get_combo_pips()` ("LH"), `is_combo_visible()`, `get_stance_tag()`.
  - All 13 original connections, the failure flash texts and `_connect_signals` are unchanged; the 4 new connections were added there. Pip widgets live in a plain `Array`.
- **U4:** no edit needed. The tactical menu's footer hints are `ui_accept` / `ui_cancel` / `target_switch_*` GlyphHints, which Q's remap didn't change. Runtime shot `v3_07` shows **A Select · B Close** (category), and M's target phase shows D-Left/D-Right Switch · A Confirm · B Back. Nothing reads `tactical_mode` (which would be "---" on pad).
- **interaction_prompt.gd** (glyph only): the glyph is already `ButtonGlyph(interact)`, which is Y on pad and E on keyboard. Header comments are updated to Y. **One visual addition:** the pill is also suppressed while `in_battle`, through `Events.battle_mode_changed`. In battle Y/E is the unique ability and interact is routed off, so "[Y] Talk" would be wrong. It uses the same `is_suppressed()` mechanism as the UI fix-up, so the prompt state and `get_prompt_text()` / `get_key_hint()` / carry logic are untouched.
- **U5 screenshots** (windowed 1920×1080, field_zone + town_hub through zone_base's real HUD; the banner is added by the driver): driver `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/u_shots.gd`. The real InputEventActions run A/Y/X taps and holds through T's states. **Runtime 24/24 PASS.** I looked at every shot.
  - `docs/ui_screenshots/v3_01_free_roam_hints.png`: A Jump / X Attack / B Dodge / Y Command.
  - `docs/ui_screenshots/v3_01b_free_roam_hints_kb.png`: Space / LMB / Shift / Q Command.
  - `docs/ui_screenshots/v3_02_battle_banner_hints.png`: BATTLE banner (centred at x=959.5) + A Command / X Attack · Hold Heavy / Y Arcane Stance / B Dodge + lock-on target bar. The keyboard set was Q Command / LMB / R Arcane Stance / Shift.
  - `docs/ui_screenshots/v3_03_stance_on.png`: stance hints + ARCANE tag + aura ring.
  - `docs/ui_screenshots/v3_04_combo_pips_mid_string.png`: COMBO [L][H][ ] (tap then hold, real input).
  - `docs/ui_screenshots/v3_05_hhh_huge_blast.png`: HUGE BLAST + [H][H][H], blast ring, gold 60 damage number.
  - `docs/ui_screenshots/v3_06_battle_clear.png`: CLEAR banner, hints back to free roam.
  - `docs/ui_screenshots/v3_07_airborne_command_menu.png`: A jump then Y mid-air gives TacticalIdle at time scale 0.05, the hint stack is hidden, and the footer reads A Select · B Close. B returns to Idle after landing.
  - Also checked: pad with an NPC prompt shows Y Interact (not Command); keyboard shows Q Command + E Interact; pips fade after reset; Y exits the stance and the tag hides.
- **Boot + suites:** headless boot exit 0, no output.
  - Required: test_controls **208/208**, test_carry **76/76**, test_ui_style **128/128**, test_phase14 **67/67**.
  - Extra: test_battle 136/136, test_phase13 64/64, test_phase15 68/68, test_phase10 72/72, test_runner 35/35.
  - Known failures, none in U's files: test_phase6_runner 110/111 ("TacticalIdle has slot navigation", already OPEN S→T/V) and test_performance 64/65 ("Exactly 7 autoloads (got 8)", predates v3).
  - test_runner and test_performance also print "1 resources still in use at exit". `--verbose` names `res://src/effects/stance_aura_vfx.gd` (S's file; see the info request).

---

### Package V — Tests, Contract Proposal, Regression
Status: DONE — AWAITING REVIEW (Started 2026-11-12, Finished 2026-11-12)
Owned files: `tests/test_controls.gd`, **new** `tests/test_battle.gd` + `.tscn`, other `tests/*.gd` only for assertions v3 breaks

- [x] V1. Update `test_controls` to v3 bindings and routing (`tactical_mode` is Q only, `jump` is A, `interact` is Y, `dodge` is B, `unique_ability` is R, LB is unbound, `BINDINGS_VERSION` is 4).
- [x] V2. `test_battle.gd`:
  - Battle mode enters on engage and exits after 3s.
  - Routing per mode.
  - The combo finisher table (L-L-L / L-L-H / H-H-H radii and damage order).
  - Stagger triggers and applies the multiplier.
  - Stance toggle, orbs, fireball and cooldown.
  - The airborne command menu.
  - Time scale 0.05.
  - The carry drop on entering battle.
- [x] V3. Update test_phase7's tactical time-scale assertion to 0.05, as the user asked.
- [x] V4. Run all suites and report the known failures that predate this work separately from new ones.
- [x] V5. Draft the CLAUDE.md contract changes for Head to apply. Don't edit CLAUDE.md. The changes:
  - "Tactical mode slows to 5%".
  - "Jump is free-roam only; battle uses abilities for lift".
  - The v3 controller table.
  - "Jump attacks exist in free roam".

Handoff Notes:
- **Files (V only):** `tests/test_controls.gd`, `tests/test_carry.gd`, `tests/test_phase7.gd` (time-scale asserts only), **new** `tests/test_battle.gd` + `tests/test_battle.tscn`. No game code touched.
- **V1 `test_controls` (v3, 208 asserts):** bindings: tactical_mode has no joypad event (Q only), new unique_ability = R with no joypad event, jump = A only (not Y, one pad binding), interact = Y only (not A/B), dodge = B (not LB), LB/RB/LT unbound, L3 = sprint only, ui overlaps only A=jump+ui_accept / B=dodge+ui_cancel, BINDINGS_VERSION 4 (const + runtime), unique_ability rebindable. Source contracts: the routing helpers + in_battle getter exist; idle/run/lock-on states open the menu via `is_command_press()` (no raw tactical_mode, no try_interact, no `handle_contextual_command`); idle/run/fall jump via `is_jump_press()`, and no locomotion or airborne state checks the raw `jump`; Jump/Fall/Land use `is_command_press()`; tactical_idle has no "non-key tactical_mode = confirm" path (T3). Labels: pad tactical_mode/unique_ability `---`, jump A, interact Y, dodge B; kb unique R; prompt `[Y]`, carry `[Y] Put Down / Hold [Y] Throw`. Runtime (free roam): A next to a prompt jumps (no menu, no interact); Y with a prompt interacts (real input); Y with no prompt opens the menu and B closes it without dodging; Q opens the menu next to a prompt; Space jumps; Y never interacts outside PLAYING; B never interacts; Y/B inside the menu never interact; double jump on A (3 presses + from Fall); the no-target spell opens the menu with Y. The tactical stub player now stands on a real floor (T's request (1)). The A-jump test waits until the player has left the floor before it waits for the landing (T's request (2)).
- **test_carry (76 asserts):** put-down / throw-aim = tap or hold **Y**, jump while carrying = **A**, and the blocked list now covers dodge (B) and unique (R) as well as X, RT and Q. (A isn't blocked anymore, because it jumps while carrying.)
- **V3 test_phase7:** `TACTICAL_SCALE := 0.05`. The source check accepts a literal or a named const passed to `_push_time_scale("tactical", X)` and resolves the const's value; the runtime and double-enter asserts check 0.05.
- **V2 `test_battle.gd` (136 asserts, about 37s, 150s watchdog):** It uses real `Input.parse_input_event` and real-time waits. A far enemy with frozen AI drives the mode via `ai_state` plus `force_check(credit_ms)`. Covers:
  - Events and member data; Player nodes and HOLD_THRESHOLD_MS.
  - Enter on engage; exit after 3.0s; re-engaging cancels the exit; a DEAD enemy counts as disengaged; real-time exit measured at about 3.0–3.6s.
  - Per-mode routing truth tables plus runtime checks: free roam A jumps, Y + prompt interacts, Y with no prompt gives the menu, B dodges. In battle, A gives the menu and doesn't jump, Space doesn't jump, Y/R toggle the stance and never interact, sprint is ignored, B dodges.
  - Battle A open-press guard; A confirms; B goes back exactly one layer and then closes without dodging; time 0.05; `GameManager.TACTICAL_TIME_SCALE == 0.05`.
  - Airborne menu from Fall (Y free roam / A battle) and from Jump: frozen, time 0.05, returns to Fall on close. The Land-buffered command opens after the recovery.
  - T6b: lock on, A×3 to TARGET_SELECT, D-pad Right, B×3. The result is LockOnIdle with the lock still held.
  - Carry: battle enter gives `carry_ended(forced)`, and Y next to a crate in battle doesn't pick it up.
  - R: tap = light on release; hold = heavy at about 0.22s while still held; dodge cancels a light strike and resets the string; no MP/ATB is spent. Finishers: LLL 0m / LLH 2.5m / LHH 3.5m / HHH 5m. Damage HHH 100 > LHH 76 > LLH 56 > LLL 36. The HHH blast hits a 2nd enemy 3.5m away exactly once; LLH and LLL don't reach it.
  - Stagger: max 100, ×1.6 (10 → 16), `enemy_staggered`, still staggered at 3s, ends by about 4s. A heavy builds more than 1.5× the stagger of a light.
  - S: toggle/current_stance/stance_changed; a tap gives exactly 3 small orbs; a hold gives exactly 1 fireball (none at 0.25s) and no extra volley; the cooldown blocks a 2nd fireball; it's back after the cooldown; 0 MP; dodge keeps the stance; leaving battle exits the stance.
  - Untouched packages report `not implemented: still the Package Q stub` (via the stub marker) instead of crashing.
- **Pre-check (not the V4 run):** test_battle 136/136 (2 runs), test_controls 208/208, test_carry 76/76, test_phase7 23/23 against the current R/S/T tree. U's control_bar test (`test_control_bar_v2_order`) is still the v2 order. If U changes the bar, V updates that assert in V4.
- **test_ui_style (Head-approved, 6 pad-glyph asserts broken by Q's remap):** EXPECTED_LABELS v3: tactical_mode `---`/Q, new unique_ability `---`/R, jump A/Space, dodge B/Shift, interact Y/E. ButtonGlyph(interact, CONTROLLER) = Y. The AUTO device-switch glyph now uses `jump` (A ↔ Space), because tactical_mode has no pad label. Result 128/128.
- **Re-checked against the final R/S/T (after Head's DONE message):** test_battle 136/136, test_controls 208/208, test_carry 76/76, test_phase7 23/23, test_ui_style 128/128. R's tuning (light 0.35s/12 dmg, heavy 0.60s/20 dmg, window +300ms) and S's timing (fireball auto-fires at about 620ms, release consumed) match the test_battle timings.
- **After U (control bar):** `test_control_bar_v2_order` is replaced by `test_control_bar_v3_hints`. It checks the source and the `HINTS_FREE` / `BATTLE` / `STANCE` / `CARRY` order and content through the script constants. It also checks `routed_label`: pad Command is Y in free roam and A in battle, pad Unique is Y, and keyboard is Q / R. A new `test_control_bar_runtime` uses the real control bar and player:
  - Free roam pad: A Jump · X Attack · B Dodge · Y Command; with a prompt, Y reads Interact.
  - Free roam keyboard: Space … Q Command.
  - Battle pad: A Command · X Attack · Hold Heavy · Y Arcane Stance · B Dodge.
  - Stance pad: A Command · X Orbs · Hold Fireball · Y Exit Stance · B Dodge.
  - Battle keyboard: Q Command … R Arcane Stance.
  - No hint ever draws `---`.
  - Nothing else from U broke a test. test_controls is now 221/221.
- **V4 full run (2026-11-12, every `tests/*.tscn` with `--headless --verbose` and a 300s timeout each; boot `--quit-after 1` exit 0, no output):**

  | Suite | Result |
  |---|---|
  | test_battle | 136/136 |
  | test_carry | 76/76 |
  | test_controls | 221/221 |
  | test_performance | 64/65 (predating) |
  | test_phase6_runner | 110/111 (predating) |
  | test_phase7_runner | 23/23 |
  | test_phase8 | 64/65 (predating) |
  | test_phase9 | 56/56 |
  | test_phase10 | 72/72 |
  | test_phase11 | 63/63 |
  | test_phase12 | 64/65 (predating) |
  | test_phase13 | 64/64 |
  | test_phase14 | 67/67 |
  | test_phase15 | 68/68 |
  | test_runner | 35/35 |
  | test_ui_style | 128/128 |

  - **Failures that predate this work (4, none in v3 files):**
    - phase6 "TacticalIdle has slot navigation" (`_navigate_slot`).
    - phase8 "New Game loads test arena scene".
    - phase12 "Field and dungeon have return portals (no softlocks)".
    - performance "Exactly 7 autoloads registered (got 8)".
  - **New v3 failures: 0.**
  - **Exit warnings:**
    - test_runner and test_performance each print "1 resources still in use at exit". `--verbose` names **`res://src/effects/stance_aura_vfx.gd` (GDScript)** in both, plus leaked `GDScriptNativeClass` / `GDScript` instances from the same cause. That is S's aura script, which outlives the tree at quit.
    - test_carry prints "ObjectDB instances leaked at exit" for one `SceneTreeTimer`: its 120s watchdog timer is still pending when the suite quits. That's harness-only and not v3.
    - No other suite prints leak warnings.
- **Predating failure seen (not v3):** test_phase6 "TacticalIdle has slot navigation" (`_navigate_slot`). The name is missing at HEAD too, so this predates v3. V4 will list it under failures that predate this work.
- **V5 — CLAUDE.md contract draft (Head applies after user approval; V did not edit CLAUDE.md):**
  - CORE DESIGN CONTRACT:
    - `Tactical mode slows to 10%` → **`Tactical mode slows to 5%`**.
    - `Jump attacks exist from early development` → **`Jump attacks exist in free roam`**.
    - Add **`Jump is free-roam only; battle uses abilities for lift`**.
    - Add **`Game has two modes: Free Roam and Battle (Battle starts when any enemy engages, ends 3s after the last disengages)`**.
    - Add **`Basic attack X: tap = light, hold = heavy; 3-step mixable combos, step 3 is a finisher (blast scales with heavies)`**.
    - Add **`Each character has a unique ability on Y in battle (Amaro: Arcane Stance)`**.
    - Add **`Command Menu can open while airborne`**.
  - TACTICAL MODE RULES: `Slows game to 10% speed` → **`Slows game to 5% speed`**.
  - INPUT CONTRACT → Xbox Controller, replacing the list:
    - Move → Left Stick; Camera → Right Stick.
    - **Jump → A (Free Roam only)**; **Command Menu → A (Battle)**.
    - Attack → X (tap Light / hold Heavy).
    - **Dodge → B**.
    - **Interact → Y (Free Roam, prompt shown); with no prompt Y opens the Command Menu**.
    - **Unique Ability → Y (Battle)**.
    - Run → L3 (hold, Free Roam).
    - Lock-On → Right Trigger; Target switch → D-pad Left/Right; Character switch → D-pad Up/Down (gated).
    - Camera Reset → Right Stick Click; Pause → Start.
    - **LB, RB, LT unbound (reserved)**.
    - Menus: A confirm, B back one layer.
    - (This replaces the stale `Tactical Menu -> Left Trigger`, `Jump -> A`, `Dodge -> B` and `Interact -> Y` lines.)
  - INPUT CONTRACT → Keyboard / Mouse: keep WASD / Mouse / Left Mouse (hold = heavy) / Shift / E / Q / Middle Mouse / Escape; Jump → Space (Free Roam only); add **Run → Ctrl** and **Unique Ability → R (Battle)**; `Tactical Menu -> Q` (both modes).
  - Input Validation: add **`A never jumps in battle; Y never interacts in battle`** and **`B in every menu backs out one layer`**.

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`

- [from Q → to T] Replace the 4 `player.handle_contextual_command(event)` callers (idle, run, lock_on_idle, lock_on_strafe) with `player.is_command_press(event)`; after that the deprecated shim in player.gd can be deleted (Head/Q). — DONE (T: no callers remain; the shim can go)
- [from Q → to V] Update `test_controls` (29) and `test_carry` (13) binding/button assertions listed in Q Handoff Notes: jump=A, interact=Y, dodge=B, tactical_mode=Q only, unique_ability=R, LB unbound, BINDINGS_VERSION 4; carry tests should press Y (joy 3) for put-down/throw-aim. — DONE (V: test_controls 208/208, test_carry 76/76)
- [from Q → to U] `SettingsManager.get_action_label(&"tactical_mode"/&"unique_ability", true)` returns `"---"` by design (controller access is routed). Label pad Command/Unique from `player.in_battle` (A/Y), not from the InputMap. — DONE (U: control_bar routed_label() + label_override; no "---" on pad)
- [from T → to V] test_controls has 5 fails, all in the harness. (1) In `test_tactical_open_press_guard` the stub player never lands ("stub player stands on the floor" FAIL), so the 3 ground-close asserts get `Fall`, which is correct v3 T2 behaviour when airborne. Give the stub a CollisionShape3D, or expect `Fall` when `not is_on_floor()`. (2) In `test_free_roam_a_y_routing_runtime`, "Y with a prompt interacts" fails because `_wait_on_floor` returns on the take-off frame right after the A jump. `force_transition(Idle)` then drops to **Fall** (can_interact_now=false) before Y is pressed. Wait for the player to leave the floor first, or wait for Idle/Land. Please also cover these in test_battle: airborne menu -> Fall, the Land-buffered command, T6b lock restore after B x3, and the time scale via `GameManager.TACTICAL_TIME_SCALE`. — DONE (V: (1) stub stands on a real floor; (2) waits to leave the floor first; test_battle covers airborne → Fall, Land-buffered command, T6b lock restore after B×3, TACTICAL_TIME_SCALE)
- [from T → to Head] `player.gd`: `Land` is still in the TacticalIdle blocklist (test_phase7 asserts it). T honours it by buffering the press in Land until the recovery ends. To open instantly from Land instead, remove `&"Land"` there and update test_phase7. — DECIDED (Head): keep Land→TacticalIdle illegal (contract test). T's buffered open after the 0.1s recovery is acceptable. (decision)
- [from T → to Head] `src/ui/menus/settings_menu.gd`: Start (`pause`) while Settings is open closes the pause menu underneath and leaves Settings open over gameplay (runtime: settings=true pause=false). Quest log and save-load already treat `pause` like back. Suggest `ui_cancel or pause` -> `close_menu()` (not during rebinding). — DONE (Head): settings_menu treats `pause` (Start) as back, like the quest log and save/load.
- [from T → to S] TacticalIdle doesn't forward `attack` releases (the menu owns input), and its enter() resets only the combo. If a stance charge can be pending when the menu opens, cancel it on `Events.tactical_mode_entered` (or poll `Input.is_action_pressed(&"attack")`). — DONE (S: TacticalIdle / GameState not PLAYING cancels the charge and queued orbs and marks the hold spent, so no fireball comes after close without a release. Runtime-verified.)
- [from S → to T/V] `test_phase6_runner` "TacticalIdle has slot navigation" FAILS: it asserts `tactical_idle_state.gd` source contains `_navigate_slot`. Keep or restore that name (T), or update the assertion (V). — OPEN. (V: `_navigate_slot` is also missing at git HEAD, so this failure predates v3. V's rule allows only asserts v3 broke, so V left it alone and will list it under V4's "predating" failures. Head decides whether T restores the name or the assert is retired.)
- [from S → to U] Stance HUD hooks: `Events.stance_changed(member_id, stance)` (stance `&""` = off), `player.stance.is_active()`, `get_display_name()` = "ARCANE", and `player.stance.ability.get_charge_progress()` / `get_cooldown_remaining()` for an optional charge or cooldown pip. Hint text: tap X = Orbs, hold X = Fireball (auto-fires at about 0.62s), Y = Exit Stance. — DONE (U: ARCANE tag + stance hints)
- [from S → to V] For test_battle: `ArcaneOrb.ORB_DAMAGE` 6 / `ORB_STAGGER` 4 / `FIREBALL_DAMAGE` 25 / `FIREBALL_STAGGER` 20 / `FIREBALL_BURST_RADIUS` 2.5. Counters live on `stance.ability` (`volleys_fired`, `orbs_fired`, `fireballs_fired`). `toggle()` needs `player.in_battle` (use `battle_mode.force_check()` with an engaged enemy). Call `handle_attack_press/release()` directly and wait real ms. A working harness is in Package S's notes (S6). — OPEN (info)
- [from T → to U] Info: carry/throw read `interact` = Y in v3. The Command Menu now opens airborne (Jump/Fall), so an airborne Command hint is valid. — DONE (U: carry hints read Y; airborne menu verified in v3_07)
- [from R → to S] Info: `EnemyBase.add_stagger(amount)` and `take_damage(amount, source, hit_kind := &"")` are live. The third param is optional, and `&"blast"` colours the number gold. `src/effects/blast_vfx.gd` (preload it; it has no class_name) provides `BlastVFX.detonate(source, centre, radius, dmg, stagger)` and `BlastVFX.spawn(parent, pos, radius)`, which you can reuse for the fireball burst. — OPEN (info)
- [from R → to U] Info: for the L/H pips, use `Events.combo_step(step, kind)` (`&"light"`/`&"heavy"`) and `Events.combo_reset` (emitted on every string reset). `Events.combo_finisher(kind, radius)` uses the kinds `triple_slash`, `strong_slash`, `blast`, `big_blast` and `huge_blast`. To poll, use `player.combo.current_string()`. — DONE (U: pips from combo_step / combo_finisher / combo_reset)
- [from R → to V] Info: the finisher numbers and R6 results are in R's Handoff Notes. `ComboComponent.get_finisher("HHH")` is static, for table tests. — OPEN (info)
- [from U → to Head] Register `battle_banner.gd` (R-2). **`src/world/zone_base.gd`:** add `const BattleBannerScript := preload("res://src/ui/hud/battle_banner.gd")` after the `TacticalOverlayScript` const (line 13), and add `BattleBannerScript,` to the `hud_scripts` array in `_spawn_hud()` after `TacticalOverlayScript,` (line 98). **`scenes/test/test_arena.gd`:** add `const BattleBannerScript := preload("res://src/ui/hud/battle_banner.gd")` after the `TacticalOverlayScript` const (line 13), and after the `add_child(tactical_overlay)` line (line 70) add:
  ```gdscript
  	var battle_banner := CanvasLayer.new()
  	battle_banner.set_script(BattleBannerScript)
  	add_child(battle_banner)
  ```
  V may want to add `"res://src/ui/hud/battle_banner.gd"` to `test_ui_style.HUD_SCRIPTS` once it's registered. — OPEN
- [from U → to S/Head] Info: `test_runner` and `test_performance` end with "1 resources still in use at exit"; `--verbose` names `res://src/effects/stance_aura_vfx.gd` (GDScript). This is likely a `StanceAuraVfx`-typed member or a static-ref cycle in the aura. It isn't caused by U's files. — OPEN (info)

---

## Head Agent Review
Status: DONE except R-7/R-8 (waiting on the user's approval and controller test)
Reviewed: 2026-11-12

- [x] R-1. Events signals pre-added.
- [x] R-2. battle_banner registered in zone_base._spawn_hud and test_arena.
- [x] R-3. Diffs reviewed. Camera internals untouched (the H-H-H shake goes through Events.camera_shake_requested). Enemy spacing unchanged. Lunge stops before 1.4m.
  - Head edits: settings_menu (Start backs out); a stance aura self-reference leak fixed (attach() now takes the instance and the caller instantiates it).
  - Decided: keep Land→TacticalIdle illegal (contract test). T's buffered open after the 0.1s recovery is fine.
- [x] R-4. InputMap v3 verified by Q's runtime dump and test_controls 221/221.
- [x] R-5. Boot exit 0. Results: battle 136, controls 221, carry 76, ui_style 128, and phases 7, 9, 10, 11, 13, 14 and 15 all pass. The only failures are the 4 that predate this work (phase6 slot nav, phase8 New Game, phase12 portals, performance autoload count). The leak warning is gone after the head fix.
- [x] R-6. Verified player.tscn: BattleModeComponent, ComboComponent, StanceComponent, StateMachine/MeleeStrike. Signals: battle_mode_changed (banner, HUD, stance, combo), combo_step/finisher (HUD), stance_changed (HUD, hints), enemy_staggered.
  - Screenshots reviewed: v3_03 stance, v3_05 H-H-H blast.
  - Follow-up candidate: lock-on camera framing can put the target between the camera and Amaro, so the reticle draws over Amaro's head (seen in v3_03 and UI shots 12–16).
- [x] R-7. Applied V5's CLAUDE.md contract draft (user approved 2026-11-12).
- [ ] R-8. User controller test, then project_status.json and commit on approval.
