# v5 Plan — Options, Menu Feel, Spell Ranges, New Abilities, Party Switch, Air Combat, Rigless Models

Status: PLANNED — WAITING FOR "launch the agents"
Created: 2026-11-13
Head agent: main session. Owns `scripts/autoloads/events.gd`, `src/world/zone_base.gd`, `scenes/test/test_arena.gd`, CLAUDE.md, `project_status.json`. Proofs every package.

## User request list (approved 2026-11-13), in priority order
**Priority 1 — open work**
1. v4 wrap-up. CLAUDE.md applied ✔. Controller test, project_status.json and commit: waiting on the user.
2. Battle-toggle glyph reads "View" instead of "Back".
3. Per-spell range (user rule, 2026-11-13). Lock-on and the target list include every enemy within the **active member's maximum ability range**: the longest `range` across their spells and abilities. Enemies beyond the **selected** spell's range are still listed and lockable, but **darkened** (dimmed row, dimmed reticle/target bar) and can't be confirmed for that spell. You can always tell what you can reach. No Options toggle.
4. Lock-on camera framing: the target must not sit between the camera and the player (reticle over Amaro's head).
5. Menu stick sensitivity: one push = one step, hold = steady repeat. Applies to every menu, tab and target list.
6. **NEW: Options page in Settings**:
   - Minimap On/Off
   - Minimap Rotating/Static (north-up)
   - Control Hints Show/Hide
   - Damage Numbers
**Priority 2 — combat and party**
7. Party switch to Taighe on D-pad Up/Down (Rebirth-style), with a cooldown. Camera and HUD follow; the other member goes to AI.
8. Amaro: **Sword Slash**, 0 MP (ATB only), a wide energy slash at the target.
9. Taighe spells, both spawning **at the target** (no projectile):
   - **Water Geyser**: erupts from beneath, launches the enemy.
   - **Wind Crescent**: crescent air slashes appear over the enemy.
10. Taighe unique (Y in battle): **Super Jump**, about 5× normal jump height.
11. **Aerial command list**: opening the Command Menu while airborne shows air-only abilities (a first small set per character).
12. Free-roam **air combos**: attacking airborne keeps the current height and combos with forward drift (no snap to the ground), then falls.
13. **Air dodge**: dodge in the stick direction while airborne. Stick-back gives a backflip-style dodge with backward arc, then fall. Movement only; animation hooks named for later.
**Priority 3 — tools and content**
14. **Rigless model support**: an unrigged mesh "floats" (glide, turn, bob, lean, squash/stretch) while gameplay drives it, so any model can become a character, NPC or enemy. The user is choosing which Hunyuan models to approve. Until then, build and test with the existing capsule/red-knight fallbacks only.
15. **Dev quick-start**: `tools/launch_town.bat` boots straight into town_hub, skipping the main menu (default `run/main_scene` unchanged).

## Head Pre-Work (before launch)
- [x] H-1. v4 CLAUDE.md lines applied.
- [ ] H-2. Pre-add Events signals requested at launch time (agents put signal requests in Cross-Agent Requests; Head adds them same-day).

## Global Rules for Every Agent
- Edit only your **Owned Files**. Anything else goes through a **Cross-Agent Request**.
- `Z:/godot/godot.exe` only. Run `--headless --import` after a new `class_name`. Debug flags default false.
- Controller-first. Every feature works on pad and keyboard. Menus use unscaled time (Command Menu runs at 0.05).
- UI uses `UIStyle` + widgets only. No typed arrays of widget classes as members (4.6 leak). A script must not reference its own `class_name` in a static func (exit leak).
- Camera: only package DD edits `camera_rig.gd`. Everyone else uses its public API/signals.
- Mark Status `NOT STARTED → IN PROGRESS → DONE`, tick tasks, and write Handoff Notes (files, verification, test counts, a CLAUDE.md line suggestion).
- Runtime-verify with temp headless scripts in `tests/_tmp_<pkg>/`, then delete them. Don't commit. Don't edit CLAUDE.md.
- Shared contract: no file is owned by two packages. If you need a file you don't own, write a request with the exact lines.

---

## Package AA — Menu Feel, Options Page, Glyph, Quick-Start
Owned files:
- new `src/ui/menu_nav.gd`
- `src/ui/menus/pause_menu.gd`, `quest_log.gd`, `save_load_menu.gd`, `settings_menu.gd`
- `scenes/menus/main_menu.gd`
- `scripts/autoloads/settings_manager.gd`
- `src/ui/theme/widgets/button_glyph.gd`
- `src/ui/hud/minimap.gd`
- `src/ui/hud/control_bar.gd`
- new `tools/launch_town.bat` (+ a tiny boot script if needed)

Status: DONE
- Root cause of the twitch: menus react to `is_action_pressed` on joypad-motion events. Stick noise around the deadzone fires repeated presses.
- [x] AA1. `MenuNav` (static helper or small RefCounted per menu):
  - stick with hysteresis (engage 0.6, release 0.35, dominant axis only)
  - first repeat after 0.35 s, then every 0.11 s
  - unscaled time
  - D-pad and keys still one press = one step
  - API: e.g. `nav.poll(delta_real) -> Vector2i` plus `nav.consume_event(event) -> bool` to swallow raw motion events
  - Publish the API in Handoff **first** (set a note "MenuNav API READY"), because BB integrates it in the Command Menu.
- [x] AA2. Integrate MenuNav in pause, quest log, save/load, settings and main menu.
- [x] AA3. Settings → **Options** sub-page (a row "Options ›" opens it; B returns one layer):
  - Minimap (On/Off)
  - Minimap Mode (Rotating / Static North-Up)
  - Control Hints (Show/Hide)
  - Damage Numbers (On/Off)
  New SettingsManager keys `show_minimap`, `minimap_rotate`, persisted and with defaults.
- [x] AA4. `minimap.gd` honours `show_minimap` / `minimap_rotate` live (static = north-up, the player arrow rotates instead). `control_bar` honours `show_control_hints` live (verify the existing wiring).
- [x] AA5. Glyph for joy 4 reads "View" (Xbox naming). Keep the keyboard label. Update any label tests through a request to FF.
- [x] AA6. `tools/launch_town.bat`: runs `Z:/godot/godot.exe --path <project> res://scenes/zones/town_hub.tscn` (or a boot script that sets state like New Game does). Main menu stays the default.
- Handoff Notes:
  - **MenuNav API READY** (2026-11-13). `src/ui/menu_nav.gd`, `class_name MenuNav extends RefCounted` (already imported). Unit-verified headless: noise around 0.5 gives 0 steps; a noisy push (0.4–0.8) gives exactly 1 step; a 1 s hold gives steps at 0, 0.35, 0.46, 0.57, 0.68, 0.79, 0.90 s; D-pad/keys give 1 step per press, and echoes are ignored.
    ```gdscript
    var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"],
                            [&"move_left", &"ui_left"], [&"move_right", &"ui_right"])  # all args optional (default ui_*)
    _nav.horizontal = false          # optional: vertical-only list (horizontal stick ignored, still swallowed)
    _nav.reset()                     # on open / when a list gains focus; a stick already deflected must return to neutral first
    # _unhandled_input (or _input):
    if _nav.consume_event(event):    # true for raw stick motion (axes 0-3); triggers 4/5 are NOT swallowed
        get_viewport().set_input_as_handled(); return
    var s: Vector2i = _nav.event_step(event)   # D-pad / keys: one press = one step, no echo. x: -1 L / +1 R, y: -1 up / +1 down
    # _process (any delta, every frame):
    var p: Vector2i = _nav.poll()    # stick steps: first on engage, repeat after 0.35 s then every 0.11 s. Unscaled time (Time.get_ticks_usec); poll(delta) for tests
    _nav.is_engaged() -> bool; _nav.get_stick() -> Vector2
    ```
    Constants are `ENGAGE 0.6`, `RELEASE 0.35`, `REPEAT_DELAY 0.35` and `REPEAT_RATE 0.11`. The stick uses the dominant axis with hysteresis. Never use `is_action_pressed` on `InputEventJoypadMotion` for navigation; let `consume_event` swallow it first. `ui_accept`/`ui_cancel` are still checked with `is_action_pressed` as before.
  - **Files.** All are AA-owned; I edited nothing else.
    - new `src/ui/menu_nav.gd`.
    - `pause_menu.gd`, `quest_log.gd`, `save_load_menu.gd`, `settings_menu.gd`: MenuNav is a member. Each menu calls `consume_event` and `event_step` in `_unhandled_input` and `poll()` in `_process`. The source still contains the `move_up`/`ui_up`/`move_down`/`ui_down` literals for the source tests.
      - Pause skips polling while a sub-menu is open and resets the nav on every layer change.
      - Save/load tracks the stick during the overwrite prompt but never steps.
      - Settings doesn't step while capturing a rebind and resets after a rebind or cancel.
    - `scenes/menus/main_menu.gd`: `_input` swallows stick motion before Godot's focus system sees it. It does this only while no sub-menu is open. `_process` turns the stick into `_step_focus()`, which wraps over the enabled buttons. D-pad and keys still use the normal focus navigation.
    - `scripts/autoloads/settings_manager.gd`:
      - new `show_minimap` / `minimap_rotate` (default true), saved under `"gameplay"`, loaded, and reset by `reset_defaults()`.
      - `rebind_action()` now emits `settings_changed`, so glyphs and the control bar update live.
      - joy 4 now reads `"View"`.
    - `button_glyph.gd`: "View" is drawn as a pill.
    - `minimap.gd`:
      - `should_show()` also requires `show_minimap`.
      - Static mode sets map up = world -Z (north). The player arrow then follows the player's world facing, and the N badge stays at the top.
      - It listens to `settings_changed`, and `_process` rechecks every frame anyway.
      - New read-only API for tests: `is_enabled()`, `is_rotating()`, `get_map_up()`, `get_player_arrow_angle()`.
    - `control_bar.gd`: the `show_control_hints` wiring already existed (it's polled per frame) and is verified. I also fixed a crash: `bool(p.get(&"in_battle"))` and `bool(carry.get(...))` threw "Nonexistent bool constructor" when the property is missing, so they are now `== true`.
    - new `tools/launch_town.bat`: runs `Z:\godot\godot.exe --path "<project>" res://scenes/zones/town_hub.tscn` and passes extra args through. This is what New Game does (it only calls `change_scene_to_file(town_hub)`), and `zone_base` sets PLAYING. `run/main_scene` is unchanged.
  - **Settings Options page.** The GAMEPLAY section on the main page is now a single row, "Options ›" (detail text: Minimap · Control Hints · Damage Numbers). Damage Numbers and Control Hints moved to the sub-page.
    - Sub-page sections:
      - MINIMAP: Minimap ON/OFF; Minimap Mode ROTATING/NORTH-UP.
      - HUD: Control Hints SHOW/HIDE; Damage Numbers ON/OFF.
    - Opening it: A, or right on the row. B or Esc goes back one layer (to the main page, with the cursor back on Options); B on the main page closes. Start closes Settings outright.
    - The header switches to "Options". Reopening Settings always starts on the main page.
    - Rows are rebuilt per page by `_build_rows()`/`_set_page()`. New public methods: `get_page()`, `is_open()`, `go_back()`.
  - **Verification** (temp scripts in `tests/_tmp_aa/`, now deleted):
    - Headless boot (`--quit-after 1`) is clean, and `--import` is clean. The launch_town command boots town_hub headless with no script errors.
    - MenuNav unit test: 6/6 pass, with the step times given above.
    - Runtime scene (real `Input.parse_input_event` joypad events): **51/51 pass**.
      - Noise around 0.5 (+-0.08, 90 frames) gives **0 steps**, and a noisy push (0.42-0.82) gives **exactly 1 step**. Both hold in settings, pause, save/load, quest log and the main menu.
      - Holding for 1.0 s at `Engine.time_scale = 0.05` gives about 7 steps, so the timing is unscaled. A 0.6 s hold in pause gives about 4 steps.
      - D-pad gives 1 step per press, and a horizontal stick push adjusts a slider by exactly one step.
      - Options page: enters on A; the 4 rows toggle `SettingsManager`; labels read NORTH-UP and HIDE; B returns one layer and restores the cursor; B again closes. Values persist to `user://settings.json` and reload (the user's file was backed up and restored).
      - Minimap: rotating mode gives map up = camera forward; static gives (0,0,-1). The arrow is 0 rad facing north and pi/2 facing east. Hiding and showing works live.
      - `control_bar` hides and shows live with `show_control_hints`.
      - The `battle_toggle` pad label is "View" and the keyboard label still has F. `rebind_action` emits `settings_changed` once.
    - Suites:
      - test_phase15 68/68, test_phase10 72/72, test_phase11 63/63, test_v4 96/96.
      - test_phase8 64/65: New Game->test_arena, an allowed failure.
      - test_controls 230/236. Five failures are AA's intended label change (see the FF request below). The sixth, "INPUT_SWITCH_ENABLED = false", comes from CC's intended change.
      - test_ui_style 140/141: the intended View label.
  - **Exit leak "N resources still in use"** (ui_style, button_glyph, glyph_hint, header_tab, menu_row, slant_panel, and town_builder in zones). **It does not come from AA.** I bisected it in test_arena. The leak stays the same with every AA runtime hook disabled: pause MenuNav reverted, the minimap `settings_changed` hookup removed, and "View" changed back to "Back". When instantiated alone (probe scene), pause_menu, settings_menu, quest_log, save_load_menu, minimap and control_bar each exit with no leak. It appears only in full zone and test scenes, so the likely cause is a static cache or ref cycle elsewhere (for example `TownBuilder` `static var _aabb_cache`, or a HUD script that holds widgets). Head may want to assign it.
  - **CLAUDE.md line suggestion:** "Menus navigate through `MenuNav` (`src/ui/menu_nav.gd`): raw stick motion is swallowed, the stick has hysteresis (0.6 to engage, 0.35 to release) and repeats on hold (0.35 s, then every 0.11 s, unscaled); D-pad and keys give one press = one step. Settings > Options holds Minimap (On/Off, Rotating/North-Up), Control Hints and Damage Numbers (`show_minimap`, `minimap_rotate`, `show_control_hints`, `show_damage_numbers` in SettingsManager). Joy 4 is labelled View. `tools/launch_town.bat` boots straight into town_hub."

## Package BB — Command Menu, Spell Ranges, New Abilities, Aerial List
Owned files:
- `src/player/states/tactical_idle_state.gd`, `src/ui/hud/tactical_menu.gd`, `src/player/states/ability_state.gd`
- `src/player/components/ability_system.gd`
- `resources/abilities/*` (`ability_data.gd` + new `.tres`)
- new `src/effects/abilities/*.gd`
- `resources/characters/hero.tres`, `companion.tres` (ability lists only; CC owns the other fields, so request edits in sequence)

Status: DONE (2026-11-13). Two items wait on others: the reticle/target-bar dim needs the Head signal + HUD lines, and the lock-on range needs DD. Both are in Cross-Agent Requests.
- [x] BB1. `AbilityData` gets:
  - `range` (m, default = lock-on range constant)
  - `targeting` (`PROJECTILE` / `AT_TARGET` / `SELF_ALLY`)
  - `aerial_only` / `ground_only` flags
  - `owner_member` (who can use it)

  Range rule (item 3):
  - Candidates = enemies within the active member's **max** ability range (expose `ability_system.get_max_range()`), nearest-first, then Fire Forward last.
  - Rows beyond the *selected* ability's range are darkened (`UIStyle.TEXT_DISABLED` + "Out of range" tag). They can be highlighted but not confirmed: A shows an "Out of range" toast, and Y Fire Forward still works.
  - The in-world highlight reticle and target bar dim for out-of-range highlights. *(BB emits `Events.tactical_target_reach` once Head adds it. The dimming itself is in the request to the HUD owner. OPEN.)*
  - Lock-on (RT, owned by the targeting/lock-on component) acquires only enemies within `ability_system.get_max_range()`. BB files the exact request to whoever owns `lock_on_component.gd` (Head assigns it to DD at launch). *(Request filed to DD — DONE by DD.)*
- [x] BB2. Integrate AA's `MenuNav` in the Command Menu (category tabs, ability list, target list).
- [x] BB3. **Sword Slash** (Amaro): 0 MP, 1 ATB segment.
  - Wide frontal energy crescent toward the target, ~3.5 m reach.
  - Moderate damage and good stagger.
  - VFX reuses the `attack_vfx` style.
- [x] BB4. **Water Geyser** (Taighe, AT_TARGET): ring telegraph under the target (~0.35 s), then a water column, damage and vertical launch (use enemy public API; request an `EnemyBase.launch(vel)` from Head if missing).
- [x] BB5. **Wind Crescent** (Taighe, AT_TARGET): 3 crescent air blades appear above or around the target and slash in sequence. Multi-hit, light stagger.
- [x] BB6. **Aerial command list**. When the menu opens airborne, show only abilities valid in the air:
  - Amaro: *Plunge Strike* (dive down, small AoE on landing).
  - Taighe: *Air Burst* (radial wind pulse around her).
  - Ground spells hide or grey out with the note "Grounded only". Menu-close behaviour returns to Fall (as v3).
- [x] BB7. Runtime-verify:
  - max-range candidate set, darkened out-of-range rows that can't be confirmed but still allow Fire Forward
  - each new ability hits the right target
  - the aerial list appears only airborne
  - MenuNav single-step under a noisy stick (simulate motion events)
- Handoff Notes:
  - **Files**
    - Edited: `resources/abilities/ability_data.gd`, `fire_bolt.tres`, `ice_freeze.tres`, `heal.tres` (range/targeting added), `src/player/components/ability_system.gd`, `src/player/states/tactical_idle_state.gd`, `src/player/states/ability_state.gd`, `src/ui/hud/tactical_menu.gd`. In `hero.tres` / `companion.tres` only `default_abilities` and its ext_resources changed; CC's fields are untouched.
    - New: `resources/abilities/sword_slash.tres`, `plunge_strike.tres`, `water_geyser.tres`, `wind_crescent.tres`, `air_burst.tres`, and `src/effects/abilities/ability_fx.gd` (shared static helpers, no class_name), `sword_slash.gd`, `water_geyser.gd`, `wind_crescent.gd`, `plunge_impact.gd`, `air_burst.gd`. No `.tscn` changed, so there is no scene tree to print.
  - **AbilityData (BB1)**
    - New fields: `range` (m, default `DEFAULT_RANGE` 20 = the lock-on default), `targeting` (PROJECTILE / AT_TARGET / SELF_ALLY), `aerial_only`, `ground_only`, `owner_member: Array[StringName]`, `stagger`, `effect_script` and `caster_motion` (NONE / PLUNGE).
    - New helpers: `is_offensive()` (SELF_ALLY is never offensive) and `usable_by(id)`.
    - Ranges: Fire Bolt 20, Ice Freeze 18, Heal 15 (ally), Sword Slash 3.5, Plunge Strike 14, Water Geyser 16, Wind Crescent 14, Air Burst 5.
  - **AbilitySystem API**
    - `get_max_range()`: the longest range over the equipped *offensive* abilities. Amaro 20, Taighe 18.
    - `is_in_range(ability, target)` and `static range_of(ability)`.
    - `get_enemy_candidates()`: living enemies within the max range, nearest-first. This is the single source of truth for the state and the HUD.
    - `get_menu_slots(airborne)` and `get_air_block_reason(ability, airborne)` ("grounded_only" / "airborne_only").
    - Context vars `menu_airborne` and `menu_ability`, written by TacticalIdle and read by the HUD.
    - `request_ability_with_target` now refuses an out-of-range enemy with `ability_request_failed("out_of_range")`.
  - **Command Menu**
    - Rows map to slots through `_menu_slots`. `_navigate_slot` is kept and wraps over the visible rows. `_restore_lock_on` (T6b) is unchanged.
    - A on a darkened row emits `"out_of_range"` and the step stays open. Y Fire Forward still works from any row.
    - The HUD darkens those rows (`MenuRow.unavailable`, right tag "Out of range", red description line).
    - Airborne: the caption reads "AERIAL · ABILITIES", the aerial_only abilities come first, and ground_only rows (Sword Slash) grey out as "Grounded only" and are refused with `"grounded_only"`. Grounded, aerial_only abilities are hidden.
    - Cast end while airborne → Fall. Menu close while airborne → Fall (v3 behaviour, unchanged).
  - **MenuNav (BB2)**
    - One `MenuNav` per TacticalIdle. `consume_event` runs first, and only left-stick motion is marked handled, so the camera stick passes through.
    - D-pad and keys go through `event_step`, and those events are marked handled so D-pad Up/Down never also fires CC's party_switch while the menu is open.
    - Stick steps come from `process_frame` via `poll()`. The target list steps on both axes (`horizontal` is on only in TARGET_SELECT).
  - **Abilities**
    - The effect contract is `setup(caster, target, ability, aim_dir)`. AbilityState spawns `effect_script` at release.
    - PLUNGE dives at 28 m/s, with horizontal carry toward the target (max 14 m/s). The impact spawns on landing or after a 1.5 s timeout.
    - Damage goes only through `take_damage(amount, source, kind)` and `add_stagger`.
    - Geyser launch uses `EnemyBase.launch()` when present, otherwise `velocity.y`.
  - **Lists**
    - Amaro: Fire Bolt, Ice Freeze, Heal, Sword Slash, Plunge Strike (air).
    - Taighe: Water Geyser, Wind Crescent, Ice Freeze, Heal, Air Burst (air).
  - **CC4 coordination.** The aerial list is chosen by `not player.is_on_floor()` at menu open, so a Super Jump apex shows Air Burst first with no extra API. Party switch → CC's `_equip_ability_list(get_starting_abilities())` loads Taighe's list, which the zone runs confirmed with a real `switch_member()`.
  - **Verification**
    - Boot `--headless --quit-after 1` is clean, and `--import` is clean.
    - Temp suite `tests/_tmp_bb/` (now deleted): **56/56 pass**.
      - Flat world, contract: both lists, Sword Slash costs.
      - Flat world, range: max range 20, candidates 2.5/10/19 m listed and 25 m excluded, Sword Slash rows 1–2 darkened in the HUD, highlight allowed, A refused with `out_of_range`, Y Fire Forward casts, A on the in-range row hits only that enemy.
      - Flat world, MenuNav: a noisy stick at 0.4–0.8 gives exactly 1 step in the ability list and in the target list. Held 0.62 s at time scale 0.05 gives 4 steps.
      - Flat world, aerial: the grounded list hides Plunge. Airborne, the menu opens with Plunge first, Sword Slash is greyed "Grounded only" and refused, and Plunge dives, carries toward the target (<2.5 m flat) and its shockwave hits. B closes the menu into Fall.
      - **field_zone + town_hub** (real `party_system.switch_member()` to Taighe and back):
        - Sword Slash hits.
        - Taighe's list loads, max range 18.
        - Water Geyser hits and launches +2.29 m.
        - Wind Crescent lands 3 hits on the target and none on a bystander 7 m away.
        - Air Burst hits from mid-air and ends in Fall.
        - Plunge Strike hits.
    - Regressions: phase6 111/111, phase7 23/23, v4 96/96, battle 135/136, controls 230/236. All 7 failures come from AA/CC's intended changes, not BB:
      - test_battle: "companion.tres unique_ability_id is empty" (CC set `super_jump`).
      - test_controls: 6 "Back"→"View" glyph labels and the `INPUT_SWITCH_ENABLED` check.
    - Headless note: the standalone tactical_menu in a bare test world logs `Parameter "fd" is null` from text shaping in `menu_row.gd`. This is a headless font artifact and doesn't happen in the zone HUD.
  - **For FF**
    - test_v4 still passes as is, because Abilities slot 0 is still Fire Bolt.
    - Suggested test_v5 coverage: the checks above. Use `ability_system.get_enemy_candidates()`, `tac._is_row_in_range(i)`, the menu's `_item_rows[i].unavailable` / `right_text == "Out of range"`, `tac._ability_at_cursor()` and `AbilityState.last_effect` (its `hit_targets` / `hit_count` / `hit_log`).
    - Update test_battle "companion unique empty" → expects `&"super_jump"` (CC's change).
  - **CLAUDE.md line suggestion.** "Per-spell range (v5): every AbilityData has `range`. The target list and lock-on cover enemies within the active member's max offensive range (`AbilitySystem.get_max_range()`). Enemies beyond the selected ability's range are listed but darkened ('Out of range') and can't be confirmed; Y Fire Forward always works. Opening the Command Menu airborne shows the aerial list (aerial_only abilities first, ground_only greyed 'Grounded only'). Command Menu navigation uses MenuNav."

## Package CC — Party Switch + Taighe Unique
Owned files:
- `src/party/party_system.gd`, `src/party/companion_ai.gd`
- `src/player/player.gd`, `src/player/player.tscn`
- `src/combat/stance_component.gd`
- new `src/combat/unique_abilities/super_jump.gd`
- `resources/characters/party_member_data.gd`, `hero.tres` / `companion.tres` (non-ability fields)
- `src/ui/hud/combat_hud.gd`
- `project.godot` ([input] only)

Status: DONE
- Approach (recommended, deterministic): **swap identities, not bodies**. The controlled `Player` node stays the input body. Switching swaps member data on both bodies and exchanges their positions/facing with a short cross-fade VFX. The data includes:
  - stats, HP/MP/ATB
  - visual model
  - ability list
  - unique ability
  - camera stays on the Player node
  This avoids rewriting camera/state ownership. Document the choice in Handoff. If another approach is chosen, explain why.
- [x] CC1. `party_switch` = D-pad Up/Down (joy 11/12) in Free Roam and Battle. Remove the conflict with any D-pad Up/Down menu use (menus own input while open). Turn `INPUT_SWITCH_ENABLED` on. Cooldown 1.0 s. Blocked in illegal states (dead, carrying, dodge, cast, menu, dialogue).
- [x] CC2. Per-member state persists across switches (HP/MP/ATB, stance off on switch). AI takes over the other member using `companion_ai`. It must work with Amaro under AI too.
- [x] CC3. HUD: the active member's panel is the large one, and they swap on switch. Toast "Taighe". Emit `Events.party_member_switched`.
- [x] CC4. **Super Jump** (Taighe unique, Y in battle):
  - ~5× normal jump height, slight forward carry.
  - Lands into Fall. Lock-on kept.
  - At the apex the Command Menu shows BB's aerial list (works via the airborne rule).
  - Cooldown ~3 s.
  - Taighe's unique ID goes on `companion.tres`.
- [x] CC5. Runtime-verify:
  - switch in town and field
  - the cooldown
  - blocked states
  - stats preserved
  - Super Jump height measured
  - the menu at the apex shows the aerial list (needs BB6, so coordinate)
- Handoff Notes:
  - **Approach: swap identities, not bodies** (as recommended). `Player` stays the input/camera/lock-on/battle-mode body; `CompanionAI` stays the AI body. `PartySystem._swap_identities()` exchanges member data, HP/MP/ATB (+ max values and fill/regen rates), the command list, the visual model (the children of each body's `VisualRoot` are swapped, so the red knight + its AnimationPlayer travel with Amaro) and positions/facing (flash ring at both spots, `party_switch` SFX). `members[i]["node"]` always points at the body embodying member i, so `members[active_index].node == Player` and `player.get_member_data()` returns the controlled member. Nothing in `camera_rig.gd`, lock-on or the state machine had to change: the camera keeps following `player.camera_anchor`, and lock-on is kept across the switch.
  - Files: `src/party/party_system.gd` (`INPUT_SWITCH_ENABLED := true`, `get_switch_cooldown_remaining()`, `switch_member*()` now return bool, `_swap_identities`, `_swap_visuals`, save `active_id` + silent restore on load), `src/party/companion_ai.gd` (`VisualRoot` wrapper, `export_member_state` / `import_member_state` / `refresh_visual`, MP regen, `heal()`, walk/idle anim when the embodied model has them, per-member `abilities`), `src/player/player.gd` (`SWITCH_STATES` + `can_party_switch()`, `export_member_state` / `import_member_state` / `refresh_visual`, `launch_jump(vy, forward_carry)`, starting command list from member data, load order party-first, EE hooks `_apply_member_visual` / `_rigless_cue`), `src/player/player.tscn` (AirDodge node for DD), `src/combat/stance_component.gd` (registry `super_jump`; instant abilities: `is_instant` + `activate()`, `toggle()` returns false, no aura/stance tag), new `src/combat/unique_abilities/super_jump.gd`, `resources/characters/party_member_data.gd` (`get_starting_abilities()`, EE model fields + `make_rigless_visual()`), `companion.tres` (`unique_ability_id = &"super_jump"`), `src/ui/hud/combat_hud.gd` (immediate row rebuild + cyan toast with the member's name, `last_switch_toast`; BB request: "Out of range!" / "Grounded only!" / "Airborne only!" toasts). `project.godot` unchanged: `party_switch` already = joy 11/12 + Tab, `target_switch_*` stays on joy 13/14.
  - Rules: switch on `party_switch` press in Free Roam and Battle; 1.0 s real-time cooldown; allowed only from Idle/Run/Jump/Fall/Land/LockOnIdle/LockOnStrafe while GameState is PLAYING and the tree is not paused. So it is blocked in Dodge/AirDodge, Ability (cast), MeleeStrike/attacks, Flinch, Ledge/Climb, Carry/ThrowAim, the Command Menu (TACTICAL_MODE), pause, dialogue, while dead, while carrying, and toward a downed partner. Menus keep the D-pad. Stance exits (`&"party_switch"`), the combo resets, and the body drops to Idle/LockOnIdle.
  - Super Jump: launch v = jump_force x sqrt(5) = 26.8 m/s, +2.5 m/s forward carry, 3 s cooldown, only from grounded Idle/Run/Land/LockOnIdle/LockOnStrafe. It enters Jump via `player.launch_jump()` (so Jump -> Fall -> Land), and lock-on is kept.
  - Verification (temp headless scripts in `tests/_tmp_cc/`, deleted): **60/60 pass**. Town and field: D-pad Up switches to Taighe; HP/MP/ATB/max values exchanged exactly (50/80, 30, 77 vs 63/100, 21, 40); positions and visuals exchanged; unique ability is super_jump; the command lists travel with each member; signal (hero, companion); the HUD's large row is Taighe and the toast reads "Taighe". A second press at 0.1 s and at 0.6 s is ignored; after 1.1 s D-pad Down switches back and the round trip preserves HP, lists and the red knight AnimationPlayer. Switching is blocked in Dodge, Ability, Flinch, MeleeStrike and Carry, in TACTICAL_MODE, while paused, dead, carrying or in dialogue, and toward a downed partner. Amaro under AI follows (10.4 -> 2.4 m), plays the red knight walk, attacks an enemy for 15 (hero attack_damage). Save/load restores Taighe as the controlled member with both HP values. Super Jump measured **12.23 m vs a 2.50 m normal jump (4.89x)**, Jump -> Fall -> Land, 4.9 m forward carry, lock-on kept, a 2nd press is on cooldown. The Command Menu opens at the apex (y = 12.2) and its list leads with BB's aerial ability: `Air Burst (air), Water Geyser, Wind Crescent, Ice Freeze, Heal`. EE dormant check: `make_rigless_visual()` returns null by default and a RiglessVisual (yaw 180) when rigless + model_scene are set.
  - Boot: clean (`--headless --quit-after 1`, no errors). Suites: runner 35/35, phase6 111/111, phase7 23/23, phase8 64/65 (allowed), phase9 56/56, phase10 72/72, phase11 63/63, phase12 64/65 (allowed), phase13 64/64, phase14 67/67, phase15 68/68, carry 78/78, v4 96/96, performance 64/65 (allowed), battle 135/136, controls 230/236, ui_style 140/141.
  - **FF: intended breaks from CC** (update, don't revert):
    - `tests/test_battle.gd`: "companion.tres unique_ability_id is empty (Taighe placeholder)". It is now `&"super_jump"`.
    - `tests/test_controls.gd` `test_party_system_handles_party_switch`: "Party switch input gated off (INPUT_SWITCH_ENABLED = false)…". It is now `true`. The check that the first statement of `_unhandled_input` is the `if not INPUT_SWITCH_ENABLED:` gate still holds.
    - The other 5 test_controls failures and the test_ui_style failure are AA's View-glyph change (not CC).
  - Exit leak "7 resources still in use" (ui_style.gd, slant_panel, button_glyph, glyph_hint, header_tab, menu_row, town_builder) shows up identically with and without a switch, so it is not from CC (UI widget scripts, AA/Head).
  - Known limits: Taighe controlled uses the shared melee combo (no mage basic attack yet). Enemies still target only the `player` group, so the AI member isn't attacked. The control bar's Y label doesn't refresh on a switch inside the same context (request to AA below).
  - CLAUDE.md line suggestion: "Party switch: D-pad Up/Down (Tab) in Free Roam and Battle, 1.0 s cooldown, swaps identities (member data, HP/MP/ATB, command list, model, position) between the Player body and the AI body. The camera and lock-on stay on the Player node. Blocked in dodge/cast/attack/flinch/carry/menus/dialogue/dead. Taighe's unique (Y in battle) = Super Jump (~5x jump height, 3 s cooldown, aerial Command Menu at the apex)."

## Package DD — Air Combos, Air Dodge, Lock-On Framing
Owned files:
- `src/player/states/melee_strike_state.gd`, `jump_attack_state.gd`, `dodge_state.gd`, `jump_state.gd`, `fall_state.gd`
- `src/combat/combo_component.gd`
- `src/camera/camera_rig.gd` (+ `.tscn`)
- `src/player/components/lock_on_component.gd` (lock-on acquisition range = `ability_system.get_max_range()`, per BB's API)
- new `src/player/states/air_dodge_state.gd`
- Adding new state nodes to `player.tscn` goes through a request to CC.

Status: DONE (2026-11-13)
- [x] DD1. **Air combo (free roam and battle)**:
  - Attacking airborne holds altitude (gravity ~0 during each strike plus a tiny lift).
  - Forward drift ~2 m/s along the stick or facing.
  - L/H mixable like the ground combo, max 3 hits.
  - Then gravity resumes, and you can't re-hover until you land.
  - No snap to the ground at any point.
- [x] DD2. **Air dodge**. One per airtime, direction from the stick relative to the camera.
  - Stick-back (or no stick while locked on) = **backflip**: up-and-back arc (~+1.5 m up, ~4 m back), then Fall.
  - Other directions give a short air dash.
  - Animation hook names: `air_dodge_back`, `air_dash`.
- [x] DD3. **Lock-on framing**. When the target is near the camera→player line (or closer to the camera than the player), the rig shifts its yaw/offset so the player stays foreground and the target stays in view. No reticle over the player's head. Smooth, no jitter, recovers on target switch.
- [x] DD4. Runtime-verify:
  - altitude held across 3 air hits (±0.2 m)
  - drift distance
  - backflip arc measured
  - one air dodge per jump
  - the framing case from the v4_04 shot no longer overlaps
- Handoff Notes:
  - **Files**: `src/combat/combo_component.gd`, `src/player/states/melee_strike_state.gd`, `jump_state.gd`, `fall_state.gd`, `dodge_state.gd` (EE cue only), `jump_attack_state.gd` (header + EE cue), new `src/player/states/air_dodge_state.gd`, `src/camera/camera_rig.gd` (`.tscn` unchanged), `src/player/components/lock_on_component.gd`. The AirDodge node and the `AirDodge -> TacticalIdle` block were added by CC on request.
  - **Air combo (DD1)**: Jump and Fall are now ComboComponent strike entry states, so an airborne press is timed like a ground one (220 ms tap/hold, L/H mixable, max 3, same finishers).
    - An air string's MeleeStrike runs in **air mode** (`airborne`). It holds `combo.air_anchor_y + 0.08 m` through `combo.air_hold_velocity(delta)`, which cancels Player's gravity step and adds a clamped correction. It drifts at `AIR_DRIFT_SPEED` 2 m/s along the stick (camera-relative) or along facing / the lock target. The drift stops if an enemy is closer than 1.4 m ahead.
    - Fall keeps the hover only while the air string is alive (`air_hover_active()`: press being timed, or the 300 ms chain-grace window).
    - Any end of an air string (finisher, timeout, dodge, hit, menu) **spends** the air combo. Airborne presses are then ignored until a real landing, which refreshes the budget in `ComboComponent._physics_process`. An unfinished air string never carries over to the ground, and vice versa.
    - JumpAttack (the dive) is now only the fallback for a player without a ComboComponent. Animation hooks: `air_strike_light` / `air_strike_heavy`, played only if present.
  - **Air dodge (DD2)**: `AirDodge` state, one per airtime (`combo.air_dodge_available()` / `consume_air_dodge()`). Jump/Fall route `dodge` there, and so does an air strike (dodge-cancel).
    - Stick back (camera space, `input.y >= 0.7`), or no stick while locked on, gives the **backflip**: v0 = sqrt(2 g 1.5), 4 m back over 0.45 s, facing kept, then Fall.
    - Otherwise it's an **air dash**: 16 m/s decaying (1-p²) over 0.28 s, altitude held. No i-frames. Hooks/cues: `air_dodge_back`, `air_dash`.
    - Public fields `mode` (`&"backflip"` / `&"dash"`) and `direction`.
  - **Framing (DD3)**: `camera_rig.gd` keeps a horizontal separation of at least `FRAME_MIN_SEPARATION_DEG` 18° between player and target, seen from the camera.
    - θ_req = a + asin(min(1, L·sin a / d)), capped at 60°.
    - Locked on: yaw = target yaw + side·θ_req. The side is picked from the current camera on acquire/switch and stays sticky, so there is no flip jitter.
    - Tactical (free orbit with a highlighted/locked target): the orbit stays free but is pushed out of the overlap cone and pulled back into view if |θ| > 55° (e.g. target between camera and player). Uses unscaled time.
    - Read-only helpers: `get_framed_yaw()`, `get_frame_angle()`, `get_required_offset()`, `frame_side`.
  - **Lock-on range (BB request)**: `LockOnComponent.get_acquire_range()` = `ability_system.get_max_range()`, falling back to `detection_range`. It's used in acquire, switch and the lose check (× 1.5).
  - **EE cues served**: melee `attack` / `attack_heavy`, jump attack `attack`, dodge `dodge`, air dodge `air_dodge_back` / `air_dash`. All go through `player._rigless_cue` when present.
  - **Runtime verification** (temp `tests/_tmp_dd/`, deleted): 27/27 passed.
    - Altitude across L-H-L air hits: anchor 2.501, min 2.501, max 2.581 (within ±0.2 m).
    - Drift: 2.27 m over 1.15 s (1.97 m/s). Gravity resumes afterwards (vy -4.5), with no re-hover until landing. Landing refreshes the budget, and the ground strike is unaffected.
    - Backflip: rise 1.54 m, back 4.00 m toward the camera, ends in Fall.
    - A second air dodge in the same airtime is refused (still airborne, cooldown bypassed). The air dodge is available again after landing.
    - Air dash: 3.12 m at Δy 0.03 m. The ground Dodge is unchanged.
    - Framing at 1920×1080: the baseline target sits on the player's screen column. Locked: 194 px clear of the player box, θ 29.1°, no jitter (0.000°/frame). After a target switch: 197 px. A target that started between camera and player ends up beyond and beside him (179 px). Tactical free orbit is pushed out (193 px).
  - **Tests**: boot clean. test_battle 135/136, test_controls 230/236, test_phase7 23/23, test_phase14 67/67, test_phase15 68/68, test_v4 96/96, test_performance 64/65. None of the failures are DD's:
    - battle: companion `unique_ability_id` placeholder test (FF: CC set `super_jump`)
    - controls: 5× "Back" → "View" label (AA5, FF update), plus "INPUT_SWITCH_ENABLED = false" (CC1, FF update)
    - performance: the known autoload count
  - **FF test suggestions**: test_v5 should cover the air string hold/drift/spent budget, AirDodge modes and the one-per-airtime rule, `LockOnComponent.get_acquire_range() == ability_system.get_max_range()`, and camera `get_frame_angle()` ≥ `get_required_offset()` once locked.
  - **Screenshots**: `docs/ui_screenshots/v5_dd_lockon_framing.png`, `v5_dd_air_combo.png`, `v5_dd_air_backflip.png`.
  - **CLAUDE.md line suggestion**: "Air combo: airborne X/hold-X runs up to 3 L/H strikes that hold altitude with ~2 m/s forward drift, once per airtime. Air dodge: one per airtime; stick-back (or no stick while locked on) = backflip, else air dash. Lock-on camera keeps the target ≥18° beside the player (never on the camera→player line). Lock-on range = the active member's max ability range."

## Package EE — Rigless Model Support
Owned files:
- new `src/characters/rigless_visual.gd` (+ optional `.tscn`)
- new `docs/rigless_models.md`
- NPC/enemy visual hookup **only** through requests (enemy_base / NPC scripts aren't owned by EE)

Status: DONE (EE1 + EE3 verified; EE2 hookup = OPEN requests to CC / Head, see Cross-Agent Requests)
- [x] EE1. `RiglessVisual` (Node3D) wraps any mesh scene and adds procedural motion from the parent body's velocity/state:
  - idle bob
  - move lean + bob frequency by speed
  - smooth yaw turn
  - jump stretch / land squash
  - attack lunge-twist
  - dodge spin (backflip rotation for `air_dodge_back`)
  - hit flinch shake

  It reads public state only. An API like `play_cue(&"attack")` lets states trigger cues without animation players.
- [ ] EE2. Data hookup: `PartyMemberData.model_scene` / `model_scale` / `rigless: bool` (request the fields from CC). Enemy/NPC equivalents go through a Head request. — requests filed (OPEN); EE side ready (`set_model()`, reparent-safe).
- [x] EE3. Demo and verify on the capsule fallback plus one **already-in-project** mesh, with no new imports until the user approves models. Doc: how to drop a GLB in and point a character at it.
- Handoff Notes:
  - **Files**:
    - new `src/characters/rigless_visual.gd` (`class_name RiglessVisual`, registered via `--headless --import`) + `.uid`
    - new `docs/rigless_models.md`: API, cue table, time rules, and the step-by-step GLB drop-in (import settings, `fit_height` scale, -Z facing / `model_yaw_offset_deg = 180`, pointing hero/companion/enemy/NPC at it)
    - screenshots `docs/ui_screenshots/v5_ee_1_idle … v5_ee_7_air_backflip.png`
    - No `.tscn`. Nothing outside EE's files was touched. No Hunyuan model was imported or copied.
  - **Design**: a Node3D placed under a body's `VisualRoot`. It builds `_Yaw → _Lean → _Squash → _Spin → _Facing → _Fit → model`.
    - Lean and squash pivot at the feet. Spin and flip pivot at half height.
    - `fit_height` (1.8) auto-scales, grounds and centres any mesh.
    - With no `model_scene`, it wraps its existing children; with no children, it builds a capsule with a nose box.
    - Reads only `velocity`, `is_on_floor()` and the parent's global yaw. Writes only its own children.
    - Re-resolves its body on `_enter_tree`, so CC's visual_root child exchange between Player and companion works.
    - Jump stretch and land squash are auto-detected from floor transitions.
    - Cues: `attack`, `attack_heavy`, `cast`, `dodge`, `air_dash`, `air_dodge_back` (+X backflip), `hit`, `jump`, `land`. Unknown names return false with a warning.
    - Yaw modes: `FOLLOW_PARENT` (lags the body's own rotation) / `FACE_VELOCITY` (for movers that never rotate) / `NONE`.
  - **Time**: real frame time × a factor.
    - Ambient motion runs at `max(time_scale, 0.3)`: it keeps breathing in the 0.05 menu and freezes in the 0.01 hit-stop.
    - Cues follow `time_scale`, except `hit`, which runs unscaled so the shake reads during hit-stop.
    - Tree pause freezes everything.
  - **Verification**: temp headless `tests/_tmp_ee/` ran **44/44 PASS**. Each check below ran on two bodies: the capsule fallback and `Prop_Crate.gltf` fitted to 1.8 m.
    - idle bob range 0.035 m
    - the visual never mutates the body's transform or velocity
    - forward lean -14.0° at 8 m/s, -3.5° at 2 m/s
    - side lean -8°
    - bob frequency 3.46 → 19.5 rad/s idle→run
    - smooth yaw: a 90° snap lags 74° and settles to 0 within 1 s
    - jump stretch +0.21 (scale_y 1.21), land squash -0.21, settles to 0
    - attack lunge 0.20 m with a 18° twist, cue ends
    - dodge spin 171° at mid, ends at 0
    - backflip 172° at mid, ends at 0
    - hit-stop: bob phase frozen while the shake reaches 0.065 m
    - menu 0.05: bob at 1.04 vs 3.46 rad/s, attack cue slowed
    - unknown cue rejected

    One-off checks:
    - FACE_VELOCITY: +X movement gives yaw -90°
    - `set_model()` swap frees the old model and refits to 1.8
    - reparent to another body: new body picked up, yaw reset to 0, lean resets from the new body's velocity

    Windowed capture of capsule (moved-children path) + crate + red_knight.fbx (`model_yaw_offset_deg = 180`). I looked at the frames: lean, squash, spin and flip are all clearly visible. Headless boot: 0 errors. `tests/_tmp_ee/` deleted.
  - **CLAUDE.md line suggestion**: "Rigless models: un-rigged meshes become characters via `RiglessVisual` (`src/characters/rigless_visual.gd`) under `VisualRoot`. It is procedural only (bob/lean/yaw/squash + `play_cue`) and reads body state without mutating it. Models face -Z (use `model_yaw_offset_deg`), and `fit_height` sets size. See docs/rigless_models.md. New Hunyuan models are imported only after user approval."

## Package FF — QA, Tests, Screenshots, Contract Draft (starts when AA–EE are DONE)
Owned files: `tests/*.gd` / `*.tscn` (new `tests/test_v5.gd`), `tools/ui_screenshots.gd`.
Status: DONE (2026-11-13). One game bug filed to Head (ability_fx `is_alive` on a freed target, see Cross-Agent Requests).
- [x] FF1. Fix test_carry's silent skips (`_pick_up_fresh` must fail loudly; clear leftover crates between tests).
- [x] FF2. test_v5 coverage for items 2–15, and update existing suites for the intended changes (View label, D-pad Up/Down = party switch, bindings version if bumped).
- [x] FF3. Full suite run with per-suite counts. Allowed remaining failures: phase8 New Game→test_arena, phase12 return portals, performance autoload count.
- [x] FF4. Screenshots:
  - the Options page
  - the static minimap
  - the target list with darkened out-of-range rows
  - Sword Slash, Water Geyser and Wind Crescent
  - Taighe active, and the Super Jump apex with the aerial list
  - an air combo mid-air
  - lock-on framing
- [x] FF5. CLAUDE.md draft lines (party switch D-pad Up/Down; per-spell range; aerial list; air combo/dodge; Options page).
- Handoff Notes:
  - **Files** (all FF-owned; no game code touched):
    - `tests/test_carry.gd` (FF1)
    - `tests/test_controls.gd`, `tests/test_ui_style.gd`, `tests/test_battle.gd` (FF2 intended-change updates)
    - new `tests/test_v5.gd` + `tests/test_v5.tscn`
    - `tools/ui_screenshots.gd` (FF4)
    - Temp `tests/_tmp_ff/` deleted.
  - **FF1 test_carry.**
    - `_pick_up_fresh(context)` now records a FAIL naming the dependent test, with state/carrying/held, instead of returning false silently. The forced-transition check in `test_hit_drops` and `test_save_never_persists_carry` go through it. The save test fails its second dependent assert explicitly, so the total stays the same when the pick-up fails.
    - Every pick-up first drops and frees all loose crates (`_clear_loose_crates()`). The pick-up must hold *that* crate (`_held() == crate`).
    - A new harness check, "Leftover crates cleared between tests", runs after the runtime block.
    - The count is now a stable **80/80**. CC reported 78, which included a silently skipped branch.
  - **FF2 intended-change updates.**
    - test_controls:
      - `battle_toggle` label → `"View"`.
      - The 4 hint arrays `["Back", …]` → `["View", …]`, with their messages.
      - `INPUT_SWITCH_ENABLED := true`. The gate check stays: the first statement of `_unhandled_input` is still the gate.
    - test_ui_style: `battle_toggle: ["View", "F"]`.
    - test_battle: companion unique = `&"super_jump"`.
    - `BINDINGS_VERSION` is still 5 and `SAVE_VERSION` is still 1 (no bump), so nothing changed there.
  - **test_v5** (160 checks). Part 1 is unit/bare-world; part 2 is town_hub with frozen `enemy.tscn` dummies on the main road (x=0, z=-2…-27). All input goes through real `Input.parse_input_event` joypad events: A/B/X/Y, D-pad 11/12/14, lock_on.
    - Contract:
      - signals: `tactical_target_reach`, `party_member_switched`, `settings_changed`
      - View glyph
      - `INPUT_SWITCH_ENABLED`, 1.0 s cooldown, `party_switch` on D-pad Up+Down
      - `super_jump` unique, `EnemyBase.launch`, `is_out_of_range()` on the indicator and target bar
      - all 7 ability ranges, Sword Slash costs
      - `launch_town.bat` (`Z:\godot\godot.exe` + `town_hub.tscn`); `main_scene` unchanged
      - rigless script + doc
    - MenuNav:
      - noise 0.5±0.08 → 0 steps
      - noisy push 0.4–0.8 → exactly 1 step
      - hold → steps at 0 / 0.35 / then every 0.11 (7 in 1 s)
      - a stick already deflected must return to neutral first
      - vertical-only lists ignore horizontal pushes; RT isn't swallowed and the right stick is
      - D-pad: one step per press; echoes are ignored
      - unscaled: a 1 s real hold at time_scale 0.05 gives ~7 steps
    - Options page (standalone `settings_menu.gd`, real events):
      - noise moves 0 rows and a noisy push moves 1
      - the D-pad reaches "Options ›", A opens it, and its 4 keys are in order
      - A toggles each one; pills read OFF/NORTH-UP/HIDE/OFF
      - B returns to the main page with the cursor on Options; B again closes
      - values persist to `user://settings.json` and reload
      - reopening starts on the main page; `reset_defaults()` works
      - The user's `settings.json` and in-memory values are backed up and restored, including on the watchdog path.
    - Minimap (town):
      - rotating: map up = camera forward
      - static: map up = (0,0,-1), and the arrow reads 0 facing north and π/2 facing east
      - Off hides it live and On shows it again
      - Control Hints Hide/Show toggles the bar live
    - Range rule (Amaro):
      - max range 20; candidates are 2.5/10/19 m and 25 m is excluded
      - Sword Slash rows 1–2 are `unavailable` with "Out of range"
      - row-1 highlight dims the reticle + target bar ("OUT OF RANGE"); A is refused with `out_of_range` and does no damage
      - moving back to row 0 restores them
      - Y Fire Forward casts from a darkened row; the dim clears after the cast
      - Fire Bolt: all 3 rows are in range
    - Sword Slash at 0 MP hits the 2.5 m target, not the 10 m one, and spends no MP.
    - Aerial list:
      - grounded: Plunge hidden
      - airborne (Y mid-jump): Plunge first, Sword Slash row "Grounded only"
      - `get_air_block_reason` returns both reasons
      - closing the menu → Fall
    - Air combo:
      - 3 light X taps after `launch_jump(18)` hold within ±0.2 m of `air_anchor_y`, with no ground snap
      - drift 0.6–5 m
      - spent afterwards; X again doesn't re-hover and gravity resumes
      - landing refreshes it
    - Air dodge:
      - stick-back + B → `backflip`, rise ≥1.0 m and ≥2.8 m back toward the camera, ending in Fall
      - a second B in the same airtime is refused; landing refreshes it
      - neutral stick → `dash` holding altitude
    - Lock-on range = `get_max_range()`:
      - Amaro: 20 m; 21 m is not acquired, 19 m is
      - Taighe: 18 m; 19 m is not acquired, 17 m is
    - Framing (projected through `CameraRig.camera.unproject_position`):
      - baseline target on the player's column (dx < 40 px)
      - after lock-on: dx ≥ 6% of the viewport width and not behind the camera
      - `|get_frame_angle| ≥ get_required_offset()`, steady (<0.5°/0.3 s)
      - a target that starts between the camera and the player ends up in view, beside him
    - Party switch:
      - D-pad Up → Taighe; signal (hero, companion)
      - HP/max HP/MP/ATB exchanged (set just before the press); the command lists travel with the members; unique = Super Jump
      - HUD: the large active row is `companion` and the toast reads "Taighe"
      - Y label Arcane Stance → Super Jump
      - a second press inside 1 s is ignored and the cooldown clears after 1 s
      - blocked in Dodge / Command Menu / Paused / Dead (each measured as a delta on the switch log)
      - D-pad Down round trip: HP preserved, Y label and Amaro's list restored
    - Taighe:
      - Water Geyser: the 10 m target is in range, takes damage and is launched (vy ≥ 5, rise ≥ 1 m with physics unfrozen); the effect is at the target
      - Wind Crescent: 3 hits, all on the target; a bystander 7 m away is untouched
    - Super Jump:
      - Y in battle → Jump. The ratio to a normal A jump is checked in [4.3, 5.7].
      - A at the apex opens the aerial list, Air Burst first
      - a second Y right after landing is on cooldown
    - RiglessVisual:
      - unit, through `step()`: lean at 8 m/s; attack lunge; `air_dodge_back` X-flip; hit survives hit-stop; unknown cue rejected; cues end; the body's transform and velocity are never changed
      - through the player, with a RiglessVisual dropped under `VisualRoot`: hit / X attack / B dodge each raise their cue
  - **FF3 full suite** (every `tests/*.tscn`, headless) — **1600 passed / 3 failed / 1603**. Only the 3 allowed failures remain:
    - battle 136/136, carry 80/80, controls 236/236, phase6 111/111, phase7 23/23
    - phase8 64/65 (allowed: New Game→test_arena)
    - phase9 56/56, phase10 72/72, phase11 63/63
    - phase12 64/65 (allowed: return portals)
    - phase13 64/64, phase14 67/67, phase15 68/68
    - performance 64/65 (allowed: 8 autoloads)
    - runner 35/35, ui_style 141/141, v4 96/96, **v5 160/160**
    - Boot (`--headless --quit-after 1`): exit 0, no errors or warnings.
  - **Exit warnings:**
    - "resources still in use at exit": **test_ui_style** (7, plus "ObjectDB instances leaked"; the process then **segfaults on exit, code 139**, also in the baseline before FF's edits), **test_controls** (3, plus ObjectDB leaked), and the **windowed ui_screenshots run** (7, then a segfault on exit, code 139).
    - test_carry prints "ObjectDB instances leaked" only.
    - v4/v5 (town_hub) and every other suite exit clean in this run.
    - Results are printed before the crash, so counts are unaffected.
  - **FF4 screenshots** (`docs/ui_screenshots/v5_01…v5_10`, 1920×1080, pad glyphs). Run: `Z:/godot/godot.exe --path . --resolution 1920x1080 --script res://tools/ui_screenshots.gd -- v5` (without `v5` it runs the old set and then v5).
    - Shots: `v5_01_options_page`, `v5_02_minimap_static`, `v5_03_target_list_out_of_range`, `v5_04_sword_slash`, `v5_05_water_geyser`, `v5_06_wind_crescent`, `v5_07_taighe_active_hud`, `v5_08_super_jump_apex_aerial_list`, `v5_09_air_combo`, `v5_10_lockon_framing`.
    - Tool fixes:
      - `_place()` wrote **degrees into `CameraRig._yaw`** (radians), so the older 11/12 field shots had the wrong camera heading. It now converts.
      - Zone loads now block the zone-entry autosave, so a screenshot run no longer overwrites the user's autosave.
      - `_place()` parks the AI member 2–3 m behind the player, so teleports don't stack both bodies on one spot.
    - Every shot reviewed. What looks wrong or worth a look:
      1. **Pre-existing, not v5:** the red knight T-poses whenever it's idle or AI-controlled (v4_01 shows the same). Only movement/attack/air poses animate.
      2. v5_03: the dimmed target bar (top centre, `TEXT_DISABLED` α0.55) is hard to read over bright roofs. The reticle's "OUT OF RANGE" label is tiny at 10 m. The functional state is correct.
      3. v5_04 Sword Slash: a large opaque yellow vertical ring at Amaro's chest dominates the frame and hides the target. The cyan crescent arc is the readable part. Worth a VFX pass.
      4. v5_06 Wind Crescent: at 8 m the blades are small and faint (one hit landed at the 0.38 s capture). Readability is low at range.
      5. v5_05: the "BATTLE" banner fades over the geyser column. The dummy's physics was unfrozen to show the launch, and it aggroed. This is a capture-timing artifact, not a bug.
      6. Correct: Options page; static minimap (N up, arrow east); "AERIAL · ABILITIES" with Air Burst first at the 12.2 m apex; Taighe large panel, Y "Super Jump"; air combo pips L L mid-air; framing dx = 307 px with LOCKED ON.
      7. **Game bug found (filed to Head):** 32 `SCRIPT ERROR: Invalid type in function 'is_alive'… previously freed` during the capture, after a Wind Crescent target was freed while the effect was alive.
  - **FF5 CLAUDE.md draft lines** (for Head; I did not edit CLAUDE.md):
    - "Menus navigate through `MenuNav` (`src/ui/menu_nav.gd`): raw stick motion is swallowed; the stick has hysteresis (engage 0.6 / release 0.35) and repeats on hold (0.35 s, then every 0.11 s, unscaled); D-pad and keys give one press = one step. Never step a menu on `is_action_pressed` of a joypad-motion event."
    - "Settings › Options page: Minimap On/Off, Minimap Mode Rotating/North-Up, Control Hints Show/Hide, Damage Numbers On/Off (`show_minimap`, `minimap_rotate`, `show_control_hints`, `show_damage_numbers`, saved in user://settings.json). B goes back one layer. Joy 4 (battle_toggle) is labelled View."
    - "Party switch: D-pad Up/Down (Tab), Free Roam and Battle, 1.0 s real-time cooldown. It swaps identities, not bodies: member data, HP/MP/ATB, command list, model and position move between the Player body and the AI body. The camera, lock-on and state machine stay on the Player node. Blocked in dodge/cast/attack/flinch/carry/Command Menu/pause/dialogue/dead. The active member's HUD panel is the large one; the control-bar Y label follows the member."
    - "Per-spell range: every AbilityData has `range`. The target list and lock-on reach = the active member's max offensive range (`AbilitySystem.get_max_range()`: Amaro 20, Taighe 18). Rows beyond the selected ability's range are listed but darkened 'Out of range' (reticle + target bar dim via `Events.tactical_target_reach`) and can't be confirmed; Y Fire Forward always works."
    - "Abilities v5: Sword Slash (Amaro, 0 MP / 1 ATB, 3.5 m, ground_only), Water Geyser (Taighe, at the target, launches via `EnemyBase.launch`), Wind Crescent (Taighe, at the target, 3 hits). Taighe's unique (Y in battle) = Super Jump (~5x jump height, 3 s cooldown)."
    - "Aerial Command Menu: opening it airborne shows aerial_only abilities first (Plunge Strike / Air Burst); ground_only rows grey 'Grounded only'; closing it airborne → Fall."
    - "Air combo: airborne X / hold-X runs up to 3 L/H strikes holding altitude (±0.2 m) with ~2 m/s drift, once per airtime (landing refreshes). Air dodge: one per airtime; stick-back (or no stick while locked on) = backflip (~1.5 m up, ~4 m back), otherwise air dash. Lock-on camera keeps the target ≥18° beside the player."
    - "Rigless models: `RiglessVisual` under `VisualRoot` gives procedural motion (bob/lean/yaw/squash + `play_cue`) and never mutates the body. See docs/rigless_models.md. New Hunyuan models only after user approval."
    - "Dev quick-start: `tools/launch_town.bat` boots town_hub directly (main_scene unchanged). QA: `tests/test_v5.tscn` covers v5; `tools/ui_screenshots.gd -- v5` captures the v5 shots."

## Launch order
AA, BB, CC, DD and EE launch together. BB waits for AA's "MenuNav API READY" note before BB2. CC4's final verification needs BB6. FF launches after all are DONE.

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`
- [from DD → to CC] `player.tscn`: add the state node `AirDodge` (type Node) under `StateMachine`, script `res://src/player/states/air_dodge_state.gd` (new ext_resource). Place it after `MeleeStrike`. — DONE (CC: ext_resource id 35, node after MeleeStrike, load_steps 36)
- [from DD → to CC] `player.gd` `_ready()`: add `&"AirDodge"` to the "Block tactical mode from forced/locked states" list (the `for blocked_state in [...]` loop), so `AirDodge -> TacticalIdle` is illegal like `Dodge -> TacticalIdle`. Until both lines land, Jump/Fall route a dodge press to the ground `Dodge` (fallback), so nothing breaks. — DONE (CC)
- [from EE → to CC] `resources/characters/party_member_data.gd`: add these fields, appended after `capsule_color`. Defaults keep the red knight / capsule unchanged. — DONE (CC: all 4 fields, after `unique_ability_id`; plus `make_rigless_visual()` on the resource)
  ```gdscript
  ## v5 EE — rigless model support (docs/rigless_models.md). Null/false = current model.
  @export var model_scene: PackedScene
  @export var model_scale: float = 1.0
  ## true = wrap model_scene in a RiglessVisual (procedural bob/lean/squash/cues, no animation).
  @export var rigless: bool = false
  ## Facing fix for meshes that don't face -Z (most glTF/Hunyuan exports need 180).
  @export var model_yaw_offset_deg: float = 180.0
  ```
- [from EE → to CC] `player.gd` (and `companion_ai.gd`, since both embody members): where the member model is set up (`_setup_model()` / `import_member_state()` / `refresh_visual()`), when `data.rigless and data.model_scene`, build the visual like this. Before user approval, no `.tres` sets `rigless`, so this is dormant. — DONE (CC: `PartyMemberData.make_rigless_visual()`, used by `player._apply_member_visual()` in `_ready` and `companion_ai.initialize()`; the visual then travels via the VisualRoot swap. `player._rigless_cue(cue)` added; `take_damage()` cues `&"hit"`.)
  ```gdscript
  const RiglessVisualScript := preload("res://src/characters/rigless_visual.gd")
  func _make_rigless_visual(data: Resource) -> Node3D:
  	var rv := RiglessVisualScript.new()
  	rv.name = "RiglessVisual"
  	rv.model_scene = data.model_scene
  	rv.model_scale = data.model_scale
  	rv.model_yaw_offset_deg = data.model_yaw_offset_deg
  	return rv  # add as the single child of visual_root in place of the red knight / capsule
  ```
  The RiglessVisual re-resolves its body on `_enter_tree`, so the visual_root child exchange in `party_system.gd` works unchanged. `play_animation()` is already a no-op without an AnimationPlayer. Add the cue helper below on `player.gd`, and optionally call `_rigless_cue(&"hit")` from `take_damage()`:
  ```gdscript
  func _rigless_cue(cue: StringName) -> void:
  	var rv := visual_root.get_node_or_null("RiglessVisual") if visual_root else null
  	if rv and rv.has_method("play_cue"):
  		rv.play_cue(cue)
  ```
- [from EE → to DD] State cues are cosmetic and no-ops when there's no RiglessVisual. Add one line in `enter()`, using `player._rigless_cue(...)`, or the same 3-line duck-typed lookup via `player.visual_root` until CC adds the helper. — DONE (DD: all four states call `player._rigless_cue` when present; air strikes send `attack`/`attack_heavy`, not the anim-hook names)
  - `melee_strike_state.gd`: `&"attack_heavy"` for heavy, `&"attack"` for light
  - `jump_attack_state.gd`: `&"attack"`
  - `dodge_state.gd`: `&"dodge"`
  - `air_dodge_state.gd`: `&"air_dodge_back"` for the backflip, `&"air_dash"` otherwise
- [from EE → to BB] `ability_state.gd` `enter()`: `player._rigless_cue(&"cast")`, the same duck-typed rule. — DONE (BB: `if player.has_method(&"_rigless_cue"): player._rigless_cue(&"cast")` after `ability_cast_started`)
- [from BB → to DD] `lock_on_component.gd`: acquisition range = the active member's max ability range (user rule, item 3). — DONE (DD)
  ```gdscript
  ## v5 BB1: lock-on reaches as far as the active member's longest offensive ability.
  func get_acquire_range() -> float:
  	var abil = _player.get(&"ability_system") if _player else null
  	if abil and abil.has_method(&"get_max_range"):
  		return abil.get_max_range()
  	return detection_range
  ```
  — DONE (DD: `get_acquire_range()` added, with a `> 0` guard; used in acquire/switch/lose. Verified 20 m = `get_max_range()`.)
  Use `get_acquire_range()` instead of `detection_range` in `acquire_target()` (`var closest_dist: float = get_acquire_range()`), in `switch_target()` (`if dist > get_acquire_range(): continue`) and in the `_physics_process` lose check (`get_acquire_range() * lose_range_multiplier`). Values today: Amaro 20 m (Fire Bolt), Taighe 18 m (Ice Freeze); the API is live in `ability_system.gd`.
- [from BB → to Head] `events.gd`: add `signal tactical_target_reach(target: Node3D, in_range: bool)` (v5 BB1: dim the reticle/target bar for an out-of-range highlight). TacticalIdleState already emits it through `Events.has_signal` (null + true = reset), so it goes live as soon as the line exists. — DONE (Head)
- [from BB → to Head] (owner of `src/ui/hud/lock_on_indicator.gd` and `src/ui/hud/target_bar.gd`) connect `Events.tactical_target_reach`. When `in_range == false` and target == the shown target, dim it: `modulate = Color(UIStyle.TEXT_DISABLED, 0.55)`, and set the reticle label to "OUT OF RANGE" (indicator). Restore `Color.WHITE` on `in_range == true`, `lock_on_target_lost`, or `tactical_mode_exited`. — DONE (Head): indicator + target bar dim on reach=false, reset on reach=true / lock lost / tactical exit. Runtime-verified (OUT OF RANGE label, TARGET restored, LOCKED ON after exit).
- [from BB → to CC] `combat_hud.gd` `_on_ability_request_failed`: add toasts `"out_of_range"` → "Out of range!", `"grounded_only"` → "Grounded only!", `"airborne_only"` → "Airborne only!". Today they fall through to "Can't use that now!". — DONE (CC)
- [from BB → to Head] optional `EnemyBase.launch(vel: Vector3)` (sets `velocity = vel`, leaves gravity on). Water Geyser calls it when present, else writes `velocity.y` directly, since EnemyBase only changes `velocity.y` through gravity. Verified launch +2.3 m in field/town either way. — DONE (Head): `launch(vel)` added (ignored when dead).
- [from CC → to AA] `src/ui/hud/control_bar.gd` `_ready()`: also refresh on a party switch so the Y label follows the controlled member ("Arcane Stance" -> "Super Jump"): `Events.party_member_switched.connect(func(_o: StringName, _n: StringName) -> void: _update_context(true))`. — DONE (Head, after AA finished)
- [from EE → to Head] Enemy/NPC hookup. — DEFERRED (Head): wait until the user approves models; no dormant code yet
  - `src/enemies/enemy_base.gd`: add `@export var rigless_model: PackedScene` and `@export var rigless_yaw_offset_deg: float = 180.0`.
    - In `_ready()`, if `rigless_model` is set, hide the existing children of `visual_root`, then add a RiglessVisual (`model_scene = rigless_model`, `fit_height` = current capsule height, `yaw_mode = FOLLOW_PARENT`) under `visual_root`.
    - In `take_damage()`, call `play_cue(&"hit")` on it. In the attack-active phase, call `play_cue(&"attack")`.
    - Don't touch `visual_root.rotation.x` while rigless: the stagger tilt is fine, because the RiglessVisual sits below `visual_root`.
  - NPCs (`src/interaction/npc_interactable.gd` / NPC scenes): the same export. Use `yaw_mode = FACE_VELOCITY` only if the NPC moves without rotating its body.
  - Keep all of this dormant until the user approves models.

- [from AA → to FF] The intended "View" label (item 2) breaks these exact assertions. Please update them; AA hasn't edited any tests.
  - `tests/test_controls.gd:257-258`: `get_action_label(&"battle_toggle", true) == "Back"` should be `"View"` (message "...is View").
  - `tests/test_controls.gd:596,602`: `["Back", "Battle"]` should be `["View", "Battle"]`. Update the messages on lines 597/603 too.
  - `tests/test_controls.gd:624,630`: `["Back", "Free Roam"]` should be `["View", "Free Roam"]`.
  - `tests/test_ui_style.gd:51`: `&"battle_toggle": ["Back", "F"]` should be `["View", "F"]`.
  - Optional new coverage for test_v5:
    - `MenuNav` noise/push/hold, using `poll(delta)` with synthetic `InputEventJoypadMotion`.
    - The Settings Options page: `get_page()`, the 4 rows, and B returning one layer.
    - Minimap `get_map_up()` in static mode.
    - The `SettingsManager.show_minimap` / `minimap_rotate` defaults and their persistence.
  - — DONE (FF: all 4 assertions updated; the optional coverage is in test_v5)
- [from FF → to Head] Game bug: `src/effects/abilities/ability_fx.gd:47` `static func is_alive(enemy: Node)`. The typed `Node` parameter raises a SCRIPT ERROR when it receives a freed object, before the `is_instance_valid` check runs: "Invalid type in function 'is_alive' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class."
  - Two call sites pass a cached target:
    - `wind_crescent.gd` `_process()` (line 67) calls `FX.is_alive(_target)` every frame.
    - `water_geyser.gd:97` calls it at the eruption.
  - When the target is freed while the effect is still alive, this repeats every frame. Wind Crescent lives about 0.9 s, and `EnemyBase.die()` frees 0.5 s after death, so a Wind Crescent blade that kills an enemy hits this in normal play.
  - **Repro:** `Z:/godot/godot.exe --path . --resolution 1920x1080 --script res://tools/ui_screenshots.gd -- v5`. Wind Crescent is cast on a dummy, and the dummy is `queue_free`d about 0.6 s later, so the log shows 17–32× this error.
  - **Fix (exact lines):** make the parameter untyped, in `ability_fx.gd`:
    - `static func is_alive(enemy) -> bool:`
    - the same for `static func hit(enemy, amount: float, …)` and `static func launch(enemy, up_speed: float)`.
    - The bodies already check `is_instance_valid` first.
  - No test change is needed. test_v5 doesn't free targets mid-effect, so it stays green either way. — OPEN

---

## Head Agent Review
Status: DONE except R-6 (waiting on the user)
Head 2026-11-13:
- Added Events.tactical_target_reach, the out-of-range dimming (indicator and target bar), EnemyBase.launch, and the control-bar refresh on party switch.
- Fixed FF's freed-enemy bug: the enemy parameters in ability_fx are now untyped.
- Re-ran test_v5 160/160; boot exit 0. Reviewed shots v5_01, v5_03 and v5_08.
- Follow-ups:
  - The exit leak warning (7 UI/town_builder scripts) and the test_ui_style segfault at exit, which predates FF's edits.
  - The red knight T-poses at idle and under AI (predates v5).
  - VFX readability: the Sword Slash ring is too opaque; Wind Crescent is faint at range; the OUT OF RANGE label is small.
  - The EE enemy/NPC hookup waits on the user approving models.
- [x] R-1. Signals/registrations requested by agents added.
- [x] R-2. Diffs reviewed (ownership, no camera mutation outside DD, UIStyle only, no leaks at exit).
- [x] R-3. Boot + full suite reproduced by Head.
- [x] R-4. Scene trees printed (player.tscn, HUD), signals verified.
- [x] R-5. Screenshots reviewed.
- [x] R-6a. CLAUDE.md v5 lines applied (user approved 2026-11-13).
- [x] R-6. CLAUDE.md lines after user approval. Then the controller test, `project_status.json`, and a commit on approval.
