# Controls v2 + Carry/Throw Plan

Created: 2026-11-12
Owner: Head Agent (reviews and verifies all work)
Status: IMPLEMENTED — AWAITING USER CONTROLLER TEST
Previous plan: `docs/plans/controller_remap_plan.md` (v1, implemented)

---

## How to use this file (ALL AGENTS READ FIRST)

The protocol is the same as v1:
1. Do only your package's tasks.
2. Edit only your **Owned files**. Put any change needed in another agent's file under **Cross-Agent Requests**.
3. Status lifecycle: `IN PROGRESS` (with Started time) → `DONE — AWAITING REVIEW` (with Finished time and Handoff Notes). Tick tasks as you go, never delete tasks, and mark unnecessary ones `N/A` with a reason.
4. Before DONE, run a headless boot and paste the result: `Z:/godot/godot.exe --path . --headless --quit-after 1`.
5. The plan file is edited concurrently. Re-read it before each edit and use small, exact edits inside your own section only.
6. Don't commit. Don't edit `project_status.json` or `CLAUDE.md`; the head agent owns them.
7. Godot is `Z:/godot/godot.exe`. If you add a `class_name`, run `--headless --import`.

Working directory: `Z:/Development/lumina/games/projectRagnorak`

---

## User feedback that triggered v2 (2026-11-12)

1. **BUG:** an offensive spell can't be confirmed when there are no enemies. Root cause: `tactical_idle_state.gd` `_confirm_ability()` silently returns when `_target_candidates` is empty.
2. **BUG:** double jump doesn't work. Root cause: `player.has_double_jump` defaults to `false` and nothing ever sets it to true.
3. **BUG:** you can't stand on crates or chests. Root cause: `TownBuilder.place()` adds visual-only GLTF props with no collision, and the chest's only collision is its interaction Area3D.
4. **NEW:** pick up, carry, put down and throw crates.
5. **NEW:** Dodge moves to LB, B becomes interact, and a Run (sprint) button is added.

---

## Approved Design (user-approved 2026-11-12)

### Xbox layout v2

| Button | Gameplay | In menus |
|---|---|---|
| A (joy 0) | Command Menu (`tactical_mode`). **No longer contextual.** | Confirm (`ui_accept`) |
| **B (joy 1)** | **Interact / pick up / carry actions (`interact`)** | Back (`ui_cancel`) |
| X (joy 2) | Attack. Throws while aiming. | — |
| Y (joy 3) | Jump (double jump unlocked) | — |
| **LB (joy 9)** | **Dodge** | — |
| **L3 (joy 7)** | **Run / sprint (hold)** | — |
| RT (axis 5) | Lock-on | — |
| D-pad L/R (13/14) | Target switch | navigate |
| D-pad U/D (11/12) | Party switch (still gated OFF) | navigate |
| R3 (joy 8) | Camera reset | — |
| Start (joy 6) | Pause | close |
| RB, LT | unbound (reserved) | — |

Keyboard: the same as v1, plus **Run = Left Ctrl (hold)**. Dodge stays Shift and Interact stays E.

Note: Jump on Y is still on trial. The user is evaluating it, so keep it a single binding that is easy to change.

### Carry / throw rules

- **Pick up:** press B near a liftable crate. It snaps above Amaro's head.
- **While carrying:** Amaro can walk, run (sprint) and jump (including double jump). Attack, dodge, the Command Menu and lock-on are blocked. Taking damage drops the crate.
- **Tap B** (released in under 0.25s): put the crate down gently in front of Amaro, snapped to the ground. If there's no room, cancel and keep carrying.
- **Hold B** (0.25s or longer): enter **ThrowAim**. Amaro is rooted and the camera/right stick aims. A throw arc preview shows the landing point.
  - **X:** throw along the arc.
  - **Release B without pressing X:** cancel back to carrying.
- **Thrown crate:** it's a physics body. On hitting an enemy it deals small damage plus stagger build-up, then breaks. On hitting the world it lands and stays liftable. If it falls far, it breaks.
- Only **single, ground-level** crates are liftable. Stacked or decorative crates are solid but not liftable. **Chests** are solid, standable and not liftable.

### Spell with no target
If an offensive spell has no target candidates, confirming casts it immediately, untargeted, in the direction Amaro is facing (camera forward when on controller). The normal ATB, MP and cooldown checks still apply.

### Run
Holding Run multiplies ground speed by about 1.6. It works only in free locomotion, not in lock-on strafe or tactical mode. Air control is unchanged.

### Out of scope
Climbing on carried crates mid-throw, stacking crates, crate puzzles or pressure plates, carrying enemies, any LT/RB features.

---

## Work Packages

Wave 1 (parallel): **F, G, H**. Wave 2 (after H publishes the crate API): **I**. **J** writes its tests alongside and runs them last. Wave 3: head review.

---

### Package F — Input Map v2 & Hints
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `project.godot` (`[input]` only), `scripts/autoloads/settings_manager.gd`, `src/ui/hud/control_bar.gd`, `src/ui/hud/interaction_prompt.gd`, `src/ui/hud/tactical_menu.gd` (hint text only)

- [x] F1. `dodge`: change joy 1 → joy 9 (LB). Keep Shift.
- [x] F2. `interact`: add joy 1 (B). Keep E.
- [x] F3. New action `sprint`: joy 7 (L3) plus Left Ctrl. Add it to `REBINDABLE_ACTIONS` and the settings keybind list if that is in your files. Otherwise file a Cross-Agent Request.
- [x] F4. Leave `ui_cancel` = Esc + joy 1. Joy 1 is now shared by `interact` and `ui_cancel`, by design. Verify no other gameplay action shares a button.
- [x] F5. Bump `BINDINGS_VERSION` to 3 so stale saved binds are discarded.
- [x] F6. `control_bar.gd`, controller order: MOVE, ATTACK (X), DODGE (LB), JUMP (Y), COMMAND (A), INTERACT (B), RUN (L3), LOCK-ON (RT), PAUSE. Show INTERACT on controller again.
- [x] F7. `interaction_prompt.gd`: controller hint becomes `"[B]"`. Use `SettingsManager.get_action_label(&"interact", true)` rather than hardcoding it.
- [x] F8. Add carry prompts to `interaction_prompt.gd`: show "[B] Pick Up" near a liftable crate, and "[B] Put Down / Hold [B] Throw" while carrying. Drive these from signals that Package I emits (`Events.carry_started` / `carry_ended`). Coordinate with H/I via Cross-Agent Requests; the head agent adds the signals to `events.gd` (see H0).
- [x] F9. Headless boot passes.

Handoff Notes:
- **Final bindings** (runtime InputMap dump, joy owners): jump Y(3)/Space; attack X(2)/LMB; dodge **LB(9)**/Shift; interact **B(1)**/E; **sprint L3(7)/Ctrl (new action)**; tactical_mode A(0)/Q; lock_on RT(axis5)/MMB; camera_reset R3(8); pause Start(6)/Esc; target_switch D-Left(13)/[ and D-Right(14)/]; party_switch D-Up(11)/D-Down(12)/Tab; ui_accept A(0)/Enter; ui_cancel B(1)/Esc.
- F4: the only shared joy buttons are joy0 = tactical_mode+ui_accept and joy1 = interact+ui_cancel, both by design. No other gameplay action shares a button. joy4/5/10 (Back/Guide/RB) and LT are unbound.
- `project.godot`: `dodge` (L72-75) joy 1→9; `interact` (L76-79) adds the joy 1 event; new `sprint={}` block (L80-83). Events were copied from existing lines (same serialization).
- `settings_manager.gd`: `BINDINGS_VERSION := 3` (L11, boot logs "discarding saved bindings (version 2 < 3)" once); `&"sprint"` added to `REBINDABLE_ACTIONS` (L34); `_joy_button_name` 7/8 now return **"L3"/"R3"** (L228-229), previously "LS"/"RS", which clashed with the stick-axis label. **J: assert "L3" for sprint, not "LS".**
- `control_bar.gd` `CONTROLS` (L12): MOVE, ATTACK, DODGE, JUMP, COMMAND, INTERACT, RUN(`sprint`), LOCK-ON, PAUSE, all `pad_visible=true`, with labels from SettingsManager.
- `interaction_prompt.gd`: the hint is `get_key_hint()` (L173), i.e. `"[" + SettingsManager.get_action_label(&"interact", is_using_controller()) + "]"`, giving [B] on pad and [E] on keyboard. There's a new public `get_prompt_text()` (L178) for tests.
- **F8 carry prompt contract (for I):** connects defensively (`Events.has_signal`) to:
  - `carryable_in_range(obj)`: obj non-null shows "[B] Pick Up"; **emit `carryable_in_range(null)` to clear it.**
  - `carry_started(obj)`: shows "[B] Put Down / Hold [B] Throw" and overrides every other prompt (`interaction_cleared` does not hide it) until `carry_ended`.
  - `carry_ended(obj, reason)`: hides the carry prompt and restores the last interactable prompt if it is still valid.
  - Priority is carrying > interactable > carryable. A crate whose interactable `get_prompt_text()` returns "Pick Up" (H3) also shows "[B] Pick Up" through the normal interaction_available path, so I needs no extra emit for that case.
  - Headless check: in range → "[E] Pick Up"; carry_started → "[E] Put Down / Hold [E] Throw"; still shown after interaction_cleared; carry_ended + in_range(null) → hidden.
- `tactical_menu.gd`: N/A, no change needed. Its hints are "[A] Select / [B] Back/Close", which are ui_accept/ui_cancel and unchanged in v2.
- For G: `src/ui/dialogue/dialogue_ui.gd:17` and `src/player/player.gd:45` still have comments about "contextual A" (not my files).
- Boot: `Z:/godot/godot.exe --path . --headless --quit-after 1` → exit 0. The only output is the expected one-time warning "SettingsManager: discarding saved bindings (version 2 < 3)".

---

### Package G — Player Locomotion: Run, Double Jump, Spell Fix, Remove Contextual A
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `src/player/player.gd`, `src/player/states/idle_state.gd`, `run_state.gd`, `jump_state.gd`, `fall_state.gd`, `lock_on_idle_state.gd`, `lock_on_strafe_state.gd`, `tactical_idle_state.gd`, `ability_state.gd` (all under `src/player/states/`)

- [x] G1. `player.gd`: set `has_double_jump` default to `true`, with a comment ("unlocked by default for now; tie to progression later, item 481"). Verify that Y in Jump and Fall performs the double jump, and that `_double_jump_used` resets on landing but NOT on the takeoff frame. Check the order of the `is_on_floor()` reset against the jump impulse; that ordering is a likely second cause of "not registering".
- [x] G2. Remove the contextual-A rule. A (`tactical_mode`) always opens the Command Menu, still blocked while dialogue is open. Simplify `handle_contextual_command()` to a dialogue check only, or remove it and update the 4 locomotion states. Interact is now `interact` (B/E) only, through `player._unhandled_input`.
- [x] G3. `player.gd` interact path: make sure a B press used as `ui_cancel` inside menus (tactical, pause, dialogue) never also triggers interact. The tactical back handler must `set_input_as_handled()`. Add a guard so interact is ignored while `GameManager.current_state != PLAYING`.
- [x] G4. Run: in `run_state.gd`, apply a `sprint_multiplier` (export, default 1.6) while `sprint` is held. Not in lock-on strafe. Expose `player.is_sprinting` (read-only) for animation and the carry state.
- [x] G5. Spell with no target (`tactical_idle_state.gd` `_confirm_ability`): if the ability is offensive and has no candidates, close the menu and call `player.ability_system.request_ability(ability)` (untargeted). If the request fails, show the existing `ability_request_failed` feedback, and don't fail silently.
- [x] G6. `ability_state.gd`: when no target is set and not locked on, aim the spell along the player's facing, or the camera's flat forward on controller. Verify the projectile/effect still spawns and travels.
- [x] G7. Silent-fail audit in `_confirm_ability`: when blocked by ATB, MP or cooldown, emit `Events.ability_request_failed` so the HUD flashes the reason (the user thought A was broken).
- [x] G8. Headless boot passes.

Handoff Notes:
- **G1 root causes (3):** (a) `has_double_jump` defaulted false (now true, player.gd:73). (b) **Main feel bug:** JumpState's air jump set `velocity.y = jump_force*0.85 = 10.2`, which is *below* the rising speed after takeoff (12 → ~8.5), so a quick Y-Y added ~+1.7 or even slowed you. It now uses `player.double_jump_force = 12.0`, and FallState's air jump (it used 10 and was then overwritten to 12 by Jump.enter) goes through the same path. (c) The landing reset ran *before* `move_and_slide()` using last frame's stale `is_on_floor()`, so it also fired on the takeoff frame. It now runs after `move_and_slide()` and only when `velocity.y <= 0` (player.gd:~175).
- New API (player.gd): `jump_force`, `double_jump_force`, `air_control`, `air_move_speed`, `sprint_multiplier` exports (moved off JumpState/FallState, so Carry can reuse them); `can_double_jump()`, `try_double_jump()`, `consume_air_jump_pending()` (JumpState.enter skips the ground impulse after an air jump); `wants_sprint()`, `set_sprinting(v)`, read-only `is_sprinting`. **For Agent I (Carry):** call `player.try_double_jump()` in the air; for speed use `player.wants_sprint()` and `player.sprint_multiplier`, then `set_sprinting(true/false)`, and clear it in exit().
- LockOnIdle/LockOnStrafe jump now requires `is_on_floor()`. It used to allow a free air jump.
- G2: `handle_contextual_command()` is now only a dialogue check (player.gd:448). `is_in_combat` is kept (informational).
- G3: `can_interact_now()` (player.gd:454) requires GameManager PLAYING, no dialogue, and the current state in `INTERACT_STATES` (Idle/Run/LockOnIdle/LockOnStrafe). Carry/ThrowAim therefore own B themselves. TacticalIdle marks ui_accept/ui_cancel/tactical_mode/pause/interact/dodge presses handled (tactical_idle_state.gd:90). `dodge` counts as a menu back on keyboard only (Shift); LB no longer backs out.
- G4: Run uses `move_speed * sprint_multiplier` while `sprint` is held, with `sprint_acceleration` 28 (run_state.gd:37). Not applied in lock-on, tactical or air.
- G5/G7: `_confirm_ability` (tactical_idle_state.gd:228). Offensive with no candidates → `request_ability(ability)` untargeted; on success it force-transitions to Ability, and exit() restores time scale. All blocked paths emit `ability_request_failed` with "atb"/"mp"/"cooldown", "empty_slot", "unavailable" (Items) or "no_target". A failed target confirm returns to ability select instead of an empty target phase.
- G6 (second bug found): `_spawn_effect` set the projectile basis *after* `add_child`, but projectiles read `_direction` from `global_basis` in `_ready()`, so untargeted spells always flew world −Z. The transform is now built before add_child (ability_state.gd:152). Untargeted cast on controller faces the camera's flat forward (ability_state.gd:46).
- **Runtime evidence** (scratch harness spawning player.tscn on a floor, real input via `Input.parse_input_event`): 22/22 PASS. Baseline before the fix: Y-Y rising 8.50→8.00 (no double jump), falling −2.0→−2.5; no-target Fire Bolt: menu stayed open, nothing emitted, time scale stuck at 0.1. After the fix: rising 8.50→11.50, falling −2.00→11.50, third press no-op, reset on landing; sprint 12.80 vs 8.00; no-target cast → Ability, projectile travels (−3.33,0,0) with facing (−1,0,0), time scale 1.0; ATB-blocked emits "atb"; A next to interactable opens the menu (0 interacts); B closes the menu without interacting; B in gameplay interacts; B while PAUSED is ignored.
- Suites: smoke 35/35; phase13 64/64; phase7 23/23; phase15 68/68; phase6 110/111 and phase12 64/65 (only the known pre-existing `_navigate_slot` and portals failures). test_controls currently hangs on a parse error in J's file (see Cross-Agent Requests).
- Boot: `Z:/godot/godot.exe --path . --headless --quit-after 1` → exit 0, no errors.

---

### Package H — Solid Props + Liftable Crate Object
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12
API PUBLISHED: yes (2026-11-12, before H1/H2/H4/H5)

Owned files: `src/world/town_builder.gd`, `scenes/zones/field_zone.gd`, `scenes/zones/town_hub.gd`, `scenes/zones/dungeon_zone.gd`, `src/interaction/chest_interactable.gd`, **new** `src/interaction/carryable_crate.gd` + `.tscn`

- [x] H0. (Done by head agent, H-1.) Ask the head agent (Cross-Agent Request) to add the following to `scripts/autoloads/events.gd`: `carry_started(obj)`, `carry_ended(obj, reason: StringName)` and `carryable_in_range(obj)`.
- [x] H1. `TownBuilder.place()`: add an optional `solid := false` parameter. When true, add a StaticBody3D with a BoxShape3D fitted to the merged mesh AABB. Every `Prop_Crate`, barrel and similar solid prop placement must pass `solid = true`. List which asset names you made solid.
- [x] H2. Chests: add a solid StaticBody3D so the player can stand on them. Keep the interaction Area3D. Verify that opening still works.
- [x] H3. New `carryable_crate.tscn`: a RigidBody3D using the Prop_Crate mesh, a BoxShape3D, sensible mass, and an interaction Area3D that extends `interactable.gd` with type CARRY and prompt "Pick Up".
  - Public API: `can_pick_up() -> bool`, `pick_up(holder: Node3D)` (freezes the body and reparents it to the holder's `CarryAnchor`), `put_down(world_pos: Vector3)`, `throw(impulse: Vector3)`, `signal impacted(body)`.
  - While held: freeze the body, disable its collision with the holder, and set `is_held`.
- [x] H4. Crate impact: on hitting an `EnemyBase`, call the existing public damage and stagger APIs (find them in `enemy_base.gd`; don't add new enemy internals; aim for about 10 damage), then break the crate (despawn plus a small VFX if an existing helper is available). On hitting the world, settle, and keep it liftable. Breaking from a fall above about 6m is optional.
- [x] H5. In the zones, replace about 2–3 **single ground-level** `Prop_Crate` placements per zone with `carryable_crate.tscn`, including at least one near the field spawn for testing. Stacked crates (y > 0) stay static and solid.
- [x] H6. Publish the final API (method signatures and how `interact()` hands off to the holder) in Handoff Notes **as early as possible**, because Package I depends on it. Contract: `interact(player)` calls `player.get_node("CarryComponent").request_pick_up(self)`.
- [x] H7. Headless boot passes. Load `field_zone` headless for about 60 frames with no errors.

Handoff Notes:
- **CRATE API (for Package I)**. Script `res://src/interaction/carryable_crate.gd`, `class_name CarryableCrate` (registered with --import). Scene `res://src/interaction/carryable_crate.tscn`.
  - Tree: `CarryableCrate` (RigidBody3D, mass 8, origin at bottom centre) → `VisualRoot` (Prop_Crate.gltf), `CollisionShape3D` (Box 1.08×1.06×1.08 at y 0.53), and `InteractArea` (Area3D created in `_ready`, inner class `CrateInteractArea extends interactable.gd`, layer 9, prompt "Pick Up", priority 3, groups `interactable` + `carryable`).
  - `signal impacted(body: Node)`: any contact while flying. `signal broken`: the crate is breaking and will `queue_free` after 0.2s.
  - `var is_held: bool`, `var is_flying: bool`, `var holder: Node3D` (read-only by convention).
  - `func interact(player: Node) -> void`: **handoff**. If `can_pick_up()` and `player.has_node("CarryComponent")`, calls `player.get_node("CarryComponent").request_pick_up(self)`. The crate never picks itself up; I decides.
  - `func can_pick_up() -> bool`: false if held, flying, broken or not in the tree.
  - `func pick_up(new_holder: Node3D) -> void`: freezes (KINEMATIC), sets collision_layer/mask to 0 (so no collision with the holder), deactivates InteractArea, and reparents to `new_holder/CarryAnchor` at local (0,0,0) with zero rotation (the crate bottom sits on the anchor). If there's no CarryAnchor it falls back to the holder at local y 1.9. Sets `is_held`.
  - `func put_down(world_pos: Vector3) -> bool`: ground-snaps world_pos (raycast down on World), checks room with `can_place_at`, and returns **false and stays held** if blocked. On success it reparents to the original world parent, faces the holder's yaw, unfreezes, and becomes solid (layer World) and liftable again. Pass the bottom-centre spot, e.g. `player.global_position - player.basis.z * 1.3`.
  - `func throw(impulse: Vector3) -> void`: detaches to the world (keeping its global transform), unfreezes, ghosts to the player while flying (layer 0, mask World|EnemyBody, collision exception with the last holder), and calls `apply_central_impulse(impulse)`. Velocity = impulse / mass (8), so pass `dir * speed * crate.mass`.
  - `func release(extra_velocity := Vector3.ZERO) -> void`: for drop(&"hit") or drop(&"forced"). Detaches, nudges 1m in front of the holder, and falls with physics (same flight rules as a throw). Use this, not put_down, for forced drops because it can't fail.
  - `func snap_to_ground(world_pos) -> Vector3`, `func can_place_at(world_pos) -> bool`: helpers for previews or put-down checks.
  - `func break_crate() -> void`, `func is_broken() -> bool`.
  - Flight → settle: after 0.25s, below 0.4 m/s, and not overlapping a player or enemy body, it turns solid and liftable again. Contact with a group `enemies` body that has `take_damage` calls `take_damage(10.0, crate)`, then breaks. EnemyBase has no separate stagger API; `take_damage` enters HURT, which is its stagger. Landing more than 6m below the flight's peak breaks the crate.
  - I must emit `Events.carry_started` / `carry_ended`; the crate doesn't. The crate's InteractArea emits `Events.carryable_in_range(crate)` when the player's `interaction_available` selects it.
  - Note: `can_place_at` excludes only the crate itself, so a spot overlapping the holder or a companion returns false. Pass a point about 1.3m in front.
- **H1 solid props.** `TownBuilder.place(parent, asset, pos, rot_y := 0.0, solid := false)`. Solid adds a `SolidCollision` StaticBody3D (layer World) with one BoxShape3D from the merged mesh AABB, cached per asset name in `_aabb_cache`. The helper `TownBuilder.merged_mesh_aabb(root)` is public and also used by chests. Assets made solid: **`Prop_Crate`** (every static placement, stacked ones included) and **`Prop_Wagon`**. That's 27 bodies in the field and 4 in town. Not made solid, deliberately: walls and floors (buildings already have box collision), fences, metal fences, ExteriorBorder, bricks/rubble, vines, supports and roofs. They're decals, clutter or would block paths. No barrels exist in these zones.
- **H2 chests.** `chest_interactable.gd` `_ready` adds a `SolidBody` StaticBody3D fitted to the chest's mesh AABB (fallback 0.8×0.6×0.6). The interaction Area3D is unchanged. The body's layer follows `is_visible_in_tree()`, so the hidden dungeon reward chest isn't an invisible wall before the puzzle is solved. Opening logic is untouched; the interaction area and priority are the same.
- **H5 placements.** Field: (2,0,4) near spawn, plus (3,0,-42) crossroads and (12,0,-25) supply drop, which replaced static singles. Town: (2,0,3) near spawn and (1.5,0,-14) square, both new; the square's 3-crate stack stays static and solid. Dungeon: (2,0,6) entrance and (-2,0,-4) near the enemies, both new. Each zone has a `_add_carryable_crate(pos, rot_y)` helper.
- **Pre-existing dungeon bugs fixed (owned file).** `_create_chest` did `chest.contents = []` and the puzzle did `puzzle.levers = [...]`. Both are untyped literals assigned to typed `Array[...]` exports, which raised runtime SCRIPT ERRORs, so the reward chest was never created and the puzzle aborted. Fixed with typed arrays and the default.
- **Verification.** Headless boot `--quit-after 1`: clean, exit 0. Headless zone harness (scratchpad, 120 physics frames per zone, current_scene set): field = 27 SolidCollision, 4 chest SolidBody, 3 crates, no errors. Town = 4 solid, 2 crates. Dungeon = reward chest SolidBody present, 2 crates. API runtime checks: `pick_up` reparents to the player (`held=true parent=Player`); `put_down` at the player's own position → **false** (stays held); `put_down` 3m away → true and liftable; throw (4,3,0) m/s → flies, lands, settles at ground y≈0, layer World, liftable again; throw into a dungeon enemy → **enemy HP 50 → 40**, then the crate breaks and frees.
- Remaining log noise, not caused by H: `enemy_base.gd:386` `_spawn_damage_number` sets `label.global_position` before `add_child` (a "!is_inside_tree" error on every hit; it's pre-existing). Also `party_system.gd:285` `get_save_data` hits a freed companion when my harness swaps zones, which is a harness-only artifact.

---

### Package I — Carry / ThrowAim Player System
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: **new** `src/player/components/carry_component.gd`, **new** `src/player/states/carry_state.gd`, **new** `src/player/states/throw_aim_state.gd`, **new** `src/ui/hud/throw_arc.gd` (optional), `src/player/player.tscn` (add nodes only)

- [x] I1. `player.tscn`: add a `CarryAnchor` (Marker3D, about 1.9m above the root), a `CarryComponent` node, and `StateMachine/Carry` and `StateMachine/ThrowAim` nodes. Print the resulting scene tree in Handoff Notes.
- [x] I2. `carry_component.gd`:
  - `request_pick_up(obj)` accepts only in free locomotion: not in combat-locked states, not while already carrying, not airborne. Calls `obj.pick_up(owner)`, then `state_machine.force_transition(&"Carry")`, then `Events.carry_started`.
  - Also provides `put_down()`, `throw(dir)`, `drop(reason)`, and `is_carrying` / `held_object` getters.
  - On damage to the player (`Events.player_hp_changed` decrease, or the hurt signal), call `drop(&"hit")`.
- [x] I3. `carry_state.gd`: ground and air locomotion while carrying.
  - Walk and run (uses `sprint`), jump and double jump using the player's jump parameters, and gravity.
  - Blocks `attack`, `dodge`, `tactical_mode` and `lock_on`.
  - B tap/hold detection: on `interact` press, start a timer. On release before 0.25s, put down and return to Idle/Run. If held 0.25s or longer, go to ThrowAim. Use real time so hit-stop or time scale can't break it.
- [x] I4. `throw_aim_state.gd`:
  - Rooted (velocity xz = 0). Right stick or mouse rotates the aim yaw via the camera; don't mutate camera internals, read its forward.
  - Draw the arc preview (ImmediateMesh or dotted MeshInstances, debug-safe).
  - `attack` (X) throws with the impulse computed from a fixed launch speed and angle, and returns to Idle.
  - Releasing `interact` (B) without throwing returns to Carry.
- [x] I5. Make sure `exit()` of Carry or ThrowAim never leaves an orphaned held crate. Any forced transition (Flinch, death, zone unload, pause → quit to title) calls `drop(&"forced")`.
- [x] I6. Save/load must never persist a held state. Don't add carry to save data; a held crate on save is simply dropped.
- [x] I7. Headless boot passes. Do a headless runtime check: spawn the player plus a crate, call `request_pick_up`, and assert the state is Carry. Simulate a tap, then a hold followed by attack, and assert the crate is released with velocity.

Handoff Notes:
- **Files (all new except player.tscn):** `src/player/components/carry_component.gd` (`class_name CarryComponent`, registered with --import), `src/player/states/carry_state.gd`, `src/player/states/throw_aim_state.gd`, `src/ui/hud/throw_arc.gd`. `player.tscn`: 4 ext_resources (ids 27-30) and 5 nodes appended; no existing node edited.
- **I1 scene tree additions:**
  ```
  Player (CharacterBody3D)
  ├─ ... (unchanged)
  ├─ StateMachine
  │  ├─ ... Idle … ClimbUp (unchanged)
  │  ├─ Carry      (Node, carry_state.gd)
  │  └─ ThrowAim   (Node, throw_aim_state.gd)
  ├─ LedgeDetector (unchanged)
  ├─ CarryAnchor   (Marker3D, y = 1.9)
  ├─ CarryComponent (Node, carry_component.gd)
  └─ ThrowArc      (MeshInstance3D, throw_arc.gd, visible=false, top_level at runtime)
  ```
- **CarryComponent API:** `request_pick_up(obj) -> bool` (accepted only in Idle/Run/Land, on floor, `GameManager` PLAYING, not already carrying, `obj.can_pick_up()`); `can_pick_up_now(obj)`; `put_down() -> bool` (spot = 1.3m in front; false = stays carrying); `throw(dir) -> bool` (impulse = launch_velocity × crate.mass; launch 11 m/s at 28°); `drop(reason)` (uses `crate.release()`, can't fail); `get_launch_velocity(dir)`, `get_held_gravity()`; `is_carrying`, `held_object`. Emits `carryable_in_range(null)` + `carry_started(obj)` on pick-up and `carry_ended(obj, reason)` with put_down / thrown / hit / forced.
- **Drop sources:** `Events.player_hurt` → `drop(&"hit")` (fires before take_damage's Flinch force_transition, so Flinch exit finds nothing held). `player_died`, `zone_exiting`, `load_completed` → `drop(&"forced")`. Carry/ThrowAim `exit()` → `drop(&"forced")` for any exit other than their own handoff (`mark_handoff()/consume_handoff()`), e.g. Ability or Flinch force_transition. Pause → quit to title frees the player and its child crate together (no orphan). I6: nothing carry-related is in save data.
- **State flow:** Idle/Run --B near crate (player.try_interact → crate.interact → request_pick_up)--> **Carry**. Carry: walk/run (`sprint`, ×player.sprint_multiplier, base 7.0), jump (`player.jump_force`), double jump (`player.try_double_jump()` + `consume_air_jump_pending()`), jump buffer; attack/dodge/tactical_mode/lock_on ignored. B press → timer (`Time.get_ticks_msec`): release <250ms on floor → put_down → Idle (blocked → stay Carry); held ≥250ms on floor → **ThrowAim** (in air it waits to land; an air tap is ignored). ThrowAim: rooted (xz vel = 0), faces camera flat forward (camera only read), arc redrawn each physics frame; X → throw → Idle; B released (event or poll) → Carry.
- **I7 evidence** (scratchpad harness `i7_carry_check.gd`: flat StaticBody ground, Camera3D, player.tscn + carryable_crate.tscn, real `Input.parse_input_event` actions, GameManager set to PLAYING): **36 passed, 0 failed**, no errors/warnings in log. Pick-up → state Carry, crate on CarryAnchor, carry_started + carryable_in_range(null); attack/dodge/tactical_mode/lock_on stay in Carry; jump vy=10.5 and double jump while carrying; tap → put_down at d=1.30 on ground, Idle; hold 0.35s → ThrowAim, arc landing (0,0,-13.36), rooted; release → Carry; hold + X → crate flying with v=(0, 4.82, -9.68) |v|=10.81, reason thrown, Idle; settles liftable at z≈-12.1; take_damage → reason hit, Flinch; force_transition(Flinch) from Carry → reason forced, crate back in world. Field zone headless load (60 frames): player has Carry/ThrowAim/CarryAnchor, no errors. Headless boot `--quit-after 1`: exit 0, clean.
- **For J:** a harness must set `GameManager.current_state = PLAYING` (zones do) or `request_pick_up` is rejected. Hold detection polls `Input.is_action_pressed(&"interact")`, so drive it with `Input.parse_input_event` / `Input.action_press`, not by calling `process_input` directly. `player.state_machine.current_state.name` gives `Carry` / `ThrowAim`.
- **Not done (by design):** locked-on players can't pick up (Carry blocks lock-on; unlock first). No ledge grab while carrying.

---

### Package J — Tests & Contract
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `tests/test_controls.gd`, **new** `tests/test_carry.gd` + `.tscn`, and other `tests/*.gd` only for assertions broken by v2

- [x] J1. Update `test_controls.gd` to the v2 layout:
  - dodge = joy 9 + Shift; interact = joy 1 + E; sprint = joy 7 + Left Ctrl.
  - No contextual A: A opens the menu even next to an interactable.
  - Prompt shows `[B]`; `BINDINGS_VERSION` is 3.
  - The no-duplicate check allows only the documented overlaps: A with `ui_accept`, and B with `ui_cancel`.
- [x] J2. Add runtime tests:
  - Double jump: a second Y press in the air adds upward velocity.
  - No-target spell: confirming an offensive spell with no enemies casts it, or emits `ability_request_failed`, and never silently does nothing.
  - Sprint: run speed while sprint is held is greater than base speed.
- [x] J3. `test_carry.gd`: pick up → Carry; tap → put down; hold → ThrowAim; X → thrown with velocity; release without X → back to Carry; hit while carrying → dropped; blocked actions while carrying; a crate hitting an enemy reduces enemy HP.
- [x] J4. Solid props: assert that the static crate and chest placements have a StaticBody3D/CollisionShape3D (load `field_zone` headless and inspect).
- [x] J5. When F–I are DONE: run all suites and report counts. Separate the 5 failures known from v1 that predate this work (phase6 `_navigate_slot`, phase8 New Game, phase9 ITEMS, phase12 portals, performance autoload count) from new failures.

Handoff Notes:
- **test_controls.gd (v2), 157/157.** Covers: the v2 InputMap (dodge LB+Shift, interact B+E, sprint L3+Ctrl, jump has a single joy binding, LB only dodge, L3 only sprint, RB/LT unbound); no gameplay joy duplicates; ui_accept overlaps only tactical_mode and ui_cancel only interact. Source contracts: no contextual A in the 4 locomotion states, the interact guard on PLAYING, tactical consumes back input, has_double_jump = true, sprint_multiplier in run only (not strafe/tactical), BINDINGS_VERSION 3 (source + runtime), sprint in REBINDABLE_ACTIONS + settings row, control bar v2 order with INTERACT pad-visible, prompt via get_action_label. Runtime: labels A/Y/X/B/LB/L3/RT and Q/Ctrl/E; prompt [B]/[E]; carry prompt "[B] Put Down / Hold [B] Throw" survives interaction_cleared and clears on carry_ended. Tactical open-press guard (v1 harness kept). A next to an interactable opens the menu with 0 interacts (Q too); B/E interact in PLAYING but not in TACTICAL_MODE/PAUSED/CUTSCENE; B inside the menu (real Input routing) closes it with no interact. Double jump: Y-Y adds >3 vy, a third press is a no-op, it resets on landing, works from Fall. Sprint: speed >1.3x base, is_sprinting. No-target Fire Bolt: casts, the menu closes, the projectile spawns; with ATB 0 it emits ability_request_failed. 120s watchdog.
- **test_carry.gd/.tscn (new), 75/76.** Covers: Events signals; the crate contract (RigidBody3D, API, impacted, is_held, shape, "Pick Up" area); player nodes (CarryAnchor about 1.9m, CarryComponent API, Carry/ThrowAim states). Runtime (real `Input.parse_input_event`, GameManager PLAYING): pick-up rejected airborne or when already carrying; `crate.interact(player)` → Carry, frozen, on CarryAnchor, above the head, carry_started; X/LB/A/RT/Q blocked while carrying; walk and jump while carrying; tap B → put down in front and on the ground, Idle, liftable, reason put_down; hold B → ThrowAim, rooted, release → Carry; hold + X → thrown, unfrozen, |v| > 1, reason thrown, settles liftable; take_damage → dropped, reason hit, not orphaned; force_transition(Flinch) drops; save data has no carry/held. Thrown crate (H API with a stub holder) → enemy HP drops by 0–20 and the crate breaks. **J4:** field_zone has 20 static Prop_Crate, every one with a StaticBody3D + shape; 4 chests, all solid and still interactable; down-rays hit a crate and a chest (standable); 3 carryables, one within 20m of spawn, none stacked. 120s watchdog.
- **The 1 carry failure is a real bug:** "No non-finite (NaN) transforms after a hit-drop". Hit-stop sets time_scale 0, which NaNs awake crates; see the Cross-Agent Request to Head/H.
- **Other test edits (assertions v2 broke):** test_phase14 `test_controller_prompts_readable` now expects get_action_label rather than "[A]". In test_phase12, only the portal-nav comment/label text changed ("contextual A" → "E / B").
- **J5 suite counts (all with a timeout):** smoke 35/35, phase6 110/111, phase7 23/23, phase8 64/65, phase9 55/56, phase10 72/72, phase11 63/63, phase12 64/65, phase13 64/64, phase14 67/67, phase15 68/68, performance 64/65, controls 157/157, carry 75/76. **Pre-existing (the 5 known from v1):** phase6 "TacticalIdle has slot navigation", phase8 "New Game loads test arena scene", phase9 "Tactical menu has Items category", phase12 "Field and dungeon have return portals", performance "Exactly 7 autoloads (got 8)". **New failures: 1** (carry NaN, a real bug). Headless boot exit 0.

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`

- [from G → to J] `tests/test_controls.gd:828` parse error ("Cannot infer the type of \"cast\"") makes the scene never quit (hangs until timeout). Also note for J2: `ability_request_failed` reasons now include "empty_slot", "unavailable", "no_target"; `player.try_double_jump()`/`double_jump_force` exist; jump/air params moved from JumpState/FallState exports to player.gd (phase12 source asserts still pass). — DONE (J): `var cast: bool` typed; test_controls now 157/157 and also has a 120s watchdog so it can't hang. The no-target test accepts any ability_request_failed reason.
- [from G → to Head/HUD owner] `src/ui/hud/combat_hud.gd` `_on_ability_request_failed` only shows mp/atb/cooldown. Add a default branch so "empty_slot"/"unavailable"/"no_target" flash text (e.g. "Not available"); otherwise those paths emit but show nothing. — DONE (Head): added empty_slot / no_target / unavailable messages, plus a default branch.
- [from H → to Head] Optional: add `CARRY` to `InteractableType` in `src/interaction/interactable.gd` (not an H file). The crate currently uses GENERIC plus group `carryable` (`is_in_group(&"carryable")` identifies it). — REJECTED (Head): the `carryable` group is enough; this avoids changing a shared enum that scenes serialize.
- [from H → to Head/enemy owner] `src/enemies/enemy_base.gd` `_spawn_damage_number`: move `label.global_position = ...` after `get_tree().current_scene.add_child(label)`. It logs a "!is_inside_tree" error on every damage instance, which is pre-existing. — DONE (Head): add_child happens first, then global_position, with an is_inside_tree guard.
- [from F → to Head] `src/ui/menus/settings_menu.gd`: add a keybind row `{"type": RowType.KEYBIND, "label": "Run", "action": "sprint"}` after Interact (L75). Also update the stale comment at L435 ("`interact` action is keyboard-only since the controller remap"), because interact now has joy B. The `is_kb_reset` check there is `InputEventKey`-only, so it is still correct. `sprint` is already in `REBINDABLE_ACTIONS`. — DONE (Head): Run row added after Interact; "Tactical Menu" relabelled "Command Menu"; comment updated.
- [from I → to G] FYI, no change needed: Carry/ThrowAim depend on these `player.gd` members. Please keep them stable: `jump_force`, `air_move_speed`, `air_control`, `sprint_multiplier`, `wants_sprint()`, `set_sprinting()`, `try_double_jump()`, `consume_air_jump_pending()`, `buffer_jump()`/`has_buffered_jump()`/`consume_jump_buffer()`, `take_damage()` emitting `Events.player_hurt` before `force_transition(&"Flinch")`, and `Carry`/`ThrowAim` staying OUT of `INTERACT_STATES` (otherwise B in Carry would also fire try_interact). — ACKNOWLEDGED (Head) (informational)
- [from J → to Head/H] **BUG: carryable crates go NaN during hit-stop.** `GameManager.hit_stop()` pushes `Engine.time_scale = 0.0`, so physics steps with dt = 0, and an *awake* RigidBody3D in contact (a dropped, put-down or settling crate) gets a NaN transform permanently. You see "axis Vector3 (nan,nan,nan)" plus a flood of `!v.is_finite()` errors. Repro: scratchpad `nan_probe.gd` (a resting awake crate with time_scale 0 for 5 physics frames gives pos=(nan,nan,nan)). It triggers in game whenever the player is hit while carrying (the drop happens inside the hit-stop), and potentially whenever any hit-stop fires near a moving crate. Suggested fix options: (a) `hit_stop` uses a tiny scale such as 0.01 instead of 0.0 (game_manager.gd:49), or (b) the crate sets `freeze = true` while `Engine.time_scale == 0` and restores it afterwards. (a) is simplest and covers every RigidBody. test_carry asserts "No non-finite (NaN) transforms after a hit-drop" and currently FAILS on this. — DONE (Head): hit_stop now uses HIT_STOP_SCALE 0.01; test_carry 76/76 including the NaN check.
-

---

## Head Agent Review (Wave 3)
Status: DONE except H-7/H-8 (waiting on the user's controller test)
Reviewed: 2026-11-12

- [x] H-1. Carry signals added to events.gd.
- [x] H-2. Diffs reviewed. Head edits outside packages:
  - events.gd: carry signals.
  - settings_menu.gd: Run row; "Command Menu" label.
  - enemy_base.gd: damage number now uses add_child before global_position.
  - combat_hud.gd: new fail reasons plus a default branch.
  - game_manager.gd: hit-stop scale changed from 0 to 0.01 (HIT_STOP_SCALE). This fixes NaN on rigid bodies, found by J.
- [x] H-3. The InputMap matches v2: dodge joy9/Shift, interact joy1/E, sprint joy7/Ctrl, jump joy3, tactical joy0/Q.
- [x] H-4. Boot exit 0. Suite results:
  - All pass: smoke 35/35, controls 157/157, carry 76/76, and phases 7, 10, 11, 13, 14 and 15.
  - Five failures that predate this work: phase6 slot navigation, phase8 New Game, phase9 ITEMS, phase12 portals, performance autoload count.
- [x] H-5. Verified:
  - player.tscn has StateMachine/Carry and StateMachine/ThrowAim (each with a script), CarryAnchor, CarryComponent and ThrowArc.
  - The crate scene is a RigidBody3D with VisualRoot and CollisionShape3D.
  - Signals: carry_started/carry_ended are emitted by CarryComponent, and carryable_in_range by the crate and the component. CarryComponent listens to player_hurt and zone_exiting.
- [x] H-6. CLAUDE.md INPUT CONTRACT updated to v2. No boxes ticked.
- [ ] H-7. User controller test.
- [ ] H-8. project_status.json and commit, on approval.
