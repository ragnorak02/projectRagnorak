# Battle v4 Polish Plan — Manual Battle Toggle, Always-Ask Targeting, Minimap

Status: PLANNED — WAITING FOR "launch the agents"
Created: 2026-11-12
Head agent: main session (proofs every package; owns `scripts/autoloads/events.gd`, `src/world/zone_base.gd`, `scenes/test/test_arena.gd`, CLAUDE.md)

## Source (user playtest of v3, 2026-11-12)
1. "There needs to be a better way to go in and out of battle mode … maybe left trigger … or the select button … I need to be able to just alternate on the fly."
2. "When I select the command and select the spell it shouldn't just shoot forward. It should ask for a target … cycle through targets … hit a button to accept, or hit a fire-anyway button to just fire forward. It shouldn't just directly do it."
3. "In the top right there should be a little minimap, like FF7 Rebirth." (Our own Lumina Frost look; borrow only the genre convention of a top-right rotating minimap.)
4. Done by Head already (not agent work): the hint panel moved to the bottom-left; the stale "Y Pick Up" prompt is fixed (see Head Pre-Work).

## Head Pre-Work (DONE before launch)
- [x] H-1. `interaction_prompt.gd`: clear the remembered crate on `interaction_cleared`, and when a non-crate interactable takes focus. Before this, "Pick Up" stayed on screen after walking away, so Y opened the Command Menu instead (runtime repro in town_hub: before = prompt visible + carryable kept, after = hidden + null).
- [x] H-2. `control_bar.gd`: hint panel anchored bottom-left (anchor 1.0, grows upward, `BOTTOM_MARGIN` 28). Verified in `docs/ui_screenshots/02_town_free_roam.png`.
- [x] H-3. `Events.battle_mode_manual_toggled(in_battle: bool)` added.
- [x] H-4. CLAUDE.md v3 contract applied (user approved).
- [x] H-5. Mode chip (user request 2026-11-13). `quest_tracker.gd` shows a chip above the quest panel: blue FREE ROAM / red BATTLE, blinking 4× on every `battle_mode_changed` (unscaled time). The quest panel moved to y=72. API: `is_showing_battle()`, `get_mode_text()`. Verified at runtime (text/flag flip, blink then alpha settles at 1.0) and in screenshots 02 (FREE ROAM) and 12 (BATTLE). W's manual toggle needs no chip work: it emits `battle_mode_changed`.

## Global Rules for Every Agent
- Edit only your **Owned Files**. Need something elsewhere? Add a **Cross-Agent Request**.
- Godot: `Z:/godot/godot.exe` only. Run `--headless --import` after adding a `class_name`.
- Controller-first. Every new action must work on pad and keyboard. Debug flags stay false.
- Time: UI and input timing use unscaled time (menu runs at 0.05 scale).
- UI uses `UIStyle` + widgets only (no hard-coded colours). No typed arrays of widget classes as members (4.6 leak).
- Don't touch camera internals; use the existing APIs/signals.
- Update your section: Status `NOT STARTED → IN PROGRESS → DONE`, tick tasks, write Handoff Notes (files changed, how verified, test counts).
- Don't commit. Don't edit CLAUDE.md (put contract changes in your Handoff Notes).

---

## Package W — Manual Battle Toggle
Owned files: `project.godot` ([input] only), `scripts/autoloads/settings_manager.gd`, `src/combat/battle_mode_component.gd`, `src/player/player.gd` (routing helper only), `src/ui/menus/settings_menu.gd` (one row), `src/ui/hud/control_bar.gd` (one hint).
Status: DONE

Rules:
- New action `battle_toggle`: pad **View/Back (joy 4)**, keyboard **F**. LT stays reserved (shortcut slot later). Rebindable; bump `BINDINGS_VERSION` to 5.
- **Free roam → press:** enter Battle at once (banner, battle hints, A = Command, Y = unique). Allowed with no enemies ("weapon drawn").
- **Battle → press:** return to Free Roam at once, even with enemies engaged. A manual "stand down" suppresses auto-entry until one of these happens: the player deals damage, the player takes damage, or an enemy that wasn't engaged at toggle time engages. Then auto Battle resumes as in v3.
- Manual Battle with no engaged enemies does **not** time out on the 3 s timer. It ends on the next press, or (after a fight) 3 s after the last enemy disengages, as in v3.
- Blocked while: a menu or dialogue is open, carrying (drop rules from v3 still apply if battle is forced on), dead, cutscene.
- Emit `Events.battle_mode_manual_toggled(in_battle)` as well as the normal `battle_mode_changed`.
- Tasks:
  - [x] W1. InputMap and SettingsManager (`REBINDABLE_ACTIONS`, label, version bump).
  - [x] W2. `BattleModeComponent`: `toggle_manual()`, suppression flag, and resume triggers (Events.enemy_damaged / player_hurt / new engagement).
  - [x] W3. `player.is_battle_toggle_press(event)` + handling in `player._unhandled_input`, honouring the blocked states.
  - [x] W4. Settings row "Battle Mode", and a control-bar hint (free roam: `View  Battle`; battle: `View  Free Roam`).
  - [x] W5. Runtime-verify in town_hub (no enemies) and field_zone (enemies engaged): on → off → hit enemy → auto on.
- Handoff Notes:
  - **Files changed**
    - `project.godot` [input]: new `battle_toggle` = Key F (keycode 70) + JoypadButton 4 (Back/View).
    - `scripts/autoloads/settings_manager.gd`: `BINDINGS_VERSION := 5` (v5 comment); `&"battle_toggle"` added to `REBINDABLE_ACTIONS`. Label comes from the existing `get_action_label` → pad "Back", kb "F".
    - `src/combat/battle_mode_component.gd`: `toggle_manual() -> bool`; read-only `is_suppressed`, `is_manual_hold`. Manual on sets a hold (no 3 s timeout while nothing is engaged; the hold drops on the first engaged poll, so after a fight the v3 3 s rule applies). Manual off sets suppression and snapshots the engaged enemy ids. Suppression lifts on `Events.enemy_damaged` (not attributed to a companion, see below), on `Events.player_hurt`, or when a poll sees an engaged enemy that wasn't in the snapshot (stand-down enemies that disengage are dropped from it, so a later re-engage counts as new). On lift it re-checks at once (`force_check(0)`). `force_exit()`/zone exit clear the hold and the suppression. Emits `Events.battle_mode_manual_toggled(in_battle)` after the normal `changed` / `battle_mode_changed`.
    - `src/player/player.gd`: `is_battle_toggle_press(event)` (false during dialogue) and `can_toggle_battle()` (needs GameState PLAYING, so pause/menus, tactical, cutscene and game over are blocked; also blocked with no dialogue, hp > 0, not carrying, not in the Carry/ThrowAim states). `_unhandled_input` calls `battle_mode.toggle_manual()` and marks the press handled, also when blocked.
    - `src/ui/menus/settings_menu.gd`: KEYBIND row "Battle Mode" → `battle_toggle` (after Lock-On).
    - `src/ui/hud/control_bar.gd`: `HINT_TO_BATTLE` ("Battle") goes last in Free; `HINT_TO_FREE_ROAM` ("Free Roam") goes last in Battle and Stance. The `HINTS_*` constants are unchanged.
  - **Design note: companion hits.** `Events.enemy_damaged` has no source. In field_zone, Taighe's companion AI kept hitting the engaged enemy and cancelled the stand-down within 1 s (verified at runtime: enemy went to HURT with 0 player_hurt). As a stopgap, a hit counts as the companion's when a `party_members` node is in ATTACK (1) with `_target_enemy == enemy`, and it doesn't lift suppression. Limitation: while the companion attacks the same enemy, the player's own hits on that enemy are ignored too. Taking damage or a new engagement still resumes. Proper fix: see the Cross-Agent Request to Head (source-carrying hit signal).
  - **Glyph text:** the pad hint draws "Back" (the existing `_joy_button_name(4)` and `ButtonGlyph` pill), not "View". I didn't rename it, because `ButtonGlyph`'s pill list only knows "Back". Optional follow-up: rename it to "View" in both places at once.
  - **Runtime verification** (temp SceneTree script in `tests/_tmp_w/`, now deleted), 28/28:
    - town_hub (0 engaged): free hints pad `[A Jump, X Attack, B Dodge, Y Command, Back Battle]`. Pad Back → Battle, with `battle_mode_changed`=[true] and `manual_toggled`=[true]; hold active; hints end `Back Free Roam` (kb `F Free Roam`); mode chip reads BATTLE. Still Battle after 4 s real time (no timeout). Kb F → Free Roam, `manual_toggled`=[true,false], chip FREE ROAM. Blocked under GameState PAUSED and CUTSCENE, and with hp 0. Allowed again in PLAYING.
    - field_zone: walked into aggro → enemy engaged → auto Battle. Back → Free Roam with 2 enemies engaged, suppressed, stays Free Roam for 1 s. Then a real X attack dealt damage → suppression lifted → auto Battle. Stand-down again, then `player_hurt` → auto Battle. Stand-down again, then a new enemy engages (CHASE) → auto Battle. `battle_mode_changed` log `[t,f,t,f,t,f,t]`, manual log `[f,f,f]`.
  - **Boot:** `--headless --quit-after 1` is clean (only the expected one-time "discarding saved bindings (version 4 < 5)" warning).
  - **Tests:** test_battle 136/136, test_carry 78/78. test_controls 209/221. Of the 12 failures, 8 are from W and are expected (Cross-Agent Request to Z below):
    1. `BINDINGS_VERSION is 4 …` (source check) and 2. `Runtime SettingsManager.BINDINGS_VERSION == 4` → now 5.
    3–5. Free roam pad / pad-with-prompt / keyboard hints now have a 5th entry `["Back","Battle"]` / `["F","Battle"]` (the kb check fails on `kb.size() == 4`).
    6–8. Battle pad / Stance pad / Battle keyboard hints now end with `["Back","Free Roam"]` / `["F","Free Roam"]` (the kb check fails on `bkb.size() == 4`).
    The other 4 (`Confirming an offensive spell with no enemies…`, `With ATB/MP available, the untargeted spell is cast`, `Command Menu closes when the untargeted spell is cast`, `Untargeted spell effect spawns…`) are X's target-step change, already filed X → Z.
  - **CLAUDE.md contract suggestion** (INPUT CONTRACT): `- [ ] Battle / Free Roam toggle -> View/Back (pad) / F (kb); manual stand-down suppresses auto-battle until damage dealt/taken or a new enemy engages` and, under Keyboard/Mouse, `- [ ] Battle toggle -> F`.

## Package X — Always-Ask Target Step (Command Menu)
Owned files: `src/player/states/tactical_idle_state.gd`, `src/ui/hud/tactical_menu.gd`, `src/player/states/ability_state.gd` (only if forward-aim needs it).
Status: DONE

Rules:
- Picking an offensive spell or ability **always** opens the target step. It never casts straight from the list.
- Target list = valid enemies nearest-first, then a final row **"Fire Forward"** (camera-forward aim, the existing untargeted cast path).
  - No enemies: the list holds only "Fire Forward", pre-selected, so the player still confirms.
  - Self/ally spells (heals etc.) keep their existing ally list with no Fire Forward row.
- Controls in the target step:
  - D-pad / left stick up-down and D-pad left/right cycle (wrapping).
  - **A** confirms the highlighted row.
  - **Y** = Fire Forward shortcut from any row.
  - **B** goes back one layer to the spell list.
  - Keyboard: Enter/Space confirm, E = Fire Forward, Esc back.
- The highlighted enemy keeps the in-world TARGET reticle and target bar (existing T6b highlight path). On the Fire Forward row, show a forward-aim marker or none, and clear the enemy highlight while that row is selected.
- The footer hint reads `Switch · A Confirm · Y Fire Forward · B Back`.
- The ATB/MP check happens on confirm. A failed check keeps the menu open and shows the existing fail toast.
- Keep `_navigate_slot` (restores the test_phase6 name check, which predates v3) if it fits naturally; otherwise note it in Handoff.
- Tasks:
  - [x] X1. Target step always shown; Fire Forward row and Y/E shortcut.
  - [x] X2. Menu list row and footer glyphs (UIStyle), with an empty-enemy layout.
  - [x] X3. Lock-on restore after cast or back-out still works (T6b).
  - [x] X4. Runtime-verify: town (no enemies → Fire Forward only), field (3 enemies → cycle, A on B-sentry hits B, Y fires forward).
- Handoff Notes:
  - **Files changed:**
    - `tactical_idle_state.gd`: the old "No targets, casting untargeted" path is removed. Offensive abilities always enter TARGET_SELECT. `_build_target_list()` sorts live, in-tree enemies nearest-first (ties are broken by instance id). `_has_forward_row` adds a final "Fire Forward" row at index `_target_candidates.size()`; with no enemies it is the only row, at index 0, pre-selected. `_get_target_names()` appends `"Fire Forward"` (const `FIRE_FORWARD_LABEL`). In TARGET_SELECT, `interact` (Y/E) calls `_fire_forward()` from any row, gated by the open-press guard. A on the last row does the same. On the Fire Forward row, `_highlight_current_target()` emits `lock_on_target_lost`, which clears the reticle and target bar, and faces camera-forward. The LockOnComponent is never touched, so `_restore_lock_on()` (T6b) restores the real lock on cast or back-out. ATB/MP/cooldown are checked again on confirm. On failure the existing `ability_request_failed` toast shows and the target step **stays open**; before, it dropped back to the ability list. If the highlighted enemy has died, confirming rebuilds the list in place. The ability-list pre-check (greyed rows plus a toast on A) is unchanged. `_navigate_slot(direction)` is back as the ability-cursor helper, so the test_phase6 name check passes again. `_find_nearest_enemy_index` was removed because the sort replaces it.
    - `ability_state.gd`: new `aim_forward()`, called by TacticalIdle right after a successful `request_ability()` (the transition is synchronous). It sets `_forward_aim`, which makes `_get_aim_target()` return null, so lock-on is ignored for this cast. It also faces camera-forward on both pad and keyboard. It is reset in enter/exit.
    - `tactical_menu.gd`: `_show_target_list` strips the trailing "Fire Forward" name and adds a `MenuRow` with "Fire Forward", right text "Camera aim", and a description. With no enemies, a dim "No targets in range" line appears above the single row. The footer uses `_target_hints(with_forward)`: `[ ] Switch · A Confirm · Y Fire Forward · B Back`; ally lists have no Fire Forward. `_resolve_target_nodes` mirrors the nearest-first sort. Enemy rows use `target_bar.gd`'s `disambiguated_name()` (preloaded as `TargetBarScript`), so "Reactor Sentry B" in the list always matches the in-world target bar, even though rows are sorted by distance. UIStyle/widgets only; no new colours.
  - **Runtime verification** (temporary headless `tests/_tmp_x/verify_x.gd`, now deleted): **38/38 PASS**.
    - Town: the target step opens with no instant cast. Rows are `["Fire Forward"]`, pre-selected, footer Switch/Confirm/Fire Forward/Back. Cycling a single row stays put. B goes to the ability list and A re-enters. Confirm with ATB 0 shows the "atb" toast and the step stays open. A on Fire Forward casts to the Ability state. The projectile's dot product with camera forward is above 0.95. GameManager leaves TACTICAL_MODE and time scale returns to 1.0.
    - Field (3 sentries placed side/side/behind the camera): the list ends with Fire Forward, nearest-first, and the nearest is highlighted (`player.lock_on_target`). Down, D-pad right and up all cycle with wrapping, and the highlight follows. On the Fire Forward row the highlight is cleared (`is_locked_on` false, `lock_on_target` null). B goes target to ability to category. A on the "Reactor Sentry B" row (label equal to the target bar's) hits **B** (Fire Bolt damage 25 on B only). With a real lock on sentry A, Y on another row fires along camera forward (dot above 0.95, no Fire Bolt hit on any sentry), and the lock on A is restored after the cast (T6b). B from the Fire Forward row restores the lock, and B×2 more closes to LockOnIdle.
    - Windowed 1920×1080 layout screenshots (not committed): `C:\Users\nick\AppData\Local\Temp\claude\de72464e2d5e7768\cf7379d0-116f-4d51-bd3b-06276e1787df\scratchpad\x_town_fire_forward_only.png`, `...\x_field_target_step.png`, `...\x_field_fire_forward_row.png`. The footer fits inside the 470 px panel with the keyboard glyphs (the widest set).
  - **Boot:** exit 0.
  - **Tests:**
    - test_phase7: 23/0.
    - test_battle: 136/0, including "Lock restore: reached TARGET_SELECT with A, A, A" and the B×3 lock-hold check.
    - test_phase6_runner: **111/0**. The `_navigate_slot` check passes again.
    - test_controls: 209/12. **4 failures are expected from X**, all in `test_no_target_spell_runtime` (Cross-Agent Request below):
      - "Confirming an offensive spell with no enemies casts it or reports a failure (never silent)"
      - "With ATB/MP available, the untargeted spell is cast"
      - "Command Menu closes when the untargeted spell is cast"
      - "Untargeted spell effect spawns (projectile fires along facing)"
    - The other 8 test_controls failures come from W's in-progress work: BINDINGS_VERSION 4 vs 5 (×2), and 6 hint-bar rows that now include `Back/F Battle`. They are not caused by X.
  - **Notes for Head/Z:**
    - The target list still includes **every** live enemy in the zone (8 in field_zone). This predates X; nearest-first sorting keeps the useful ones at the top. A range limit (for example LockOnComponent.detection_range) would be a small follow-up if wanted.
    - Fire Forward drops the lock-on only for that cast, then restores it.
    - Contract draft line for Z4: "Offensive commands always open the target step (enemies nearest-first + Fire Forward); A confirm, Y/E Fire Forward, B/Esc back."

## Package Y — Minimap (top-right)
Owned files: new `src/ui/hud/minimap.gd` (+ an optional `src/ui/theme/widgets/minimap_*.gd`).
Status: DONE

Rules:
- Top-right corner, about 220 px at 1080p, with a 24 px margin. Rounded-square frame, Lumina Frost (`UIStyle` tokens): frost-cyan rim, dark translucent fill, and a small "N"/heading tick.
- Terrain: a `SubViewport` (256×256) with an orthographic top-down `Camera3D` that follows the player at a fixed height and size of about 40 m. Shadows/effects off, rendered at a reduced rate (every 2nd–3rd frame). The cull mask excludes the player model if possible.
- Rotation: the map rotates with the camera yaw (up = camera forward). The player arrow sits fixed at the centre.
- Icons drawn on top in 2D, clamped to the rim when off-range:
  - enemies (`enemies` group): red dot, larger while engaged
  - NPCs: white dot
  - chests/interactables: gold
  - zone exits/portals: cyan diamond
  - active quest objective: gold star (if QuestManager exposes a position; otherwise skip and note it)
  - Classify by script or class name. Don't add groups to other packages' files without a Cross-Agent Request.
- Hidden while a full-screen menu or dialogue is open. It stays visible in Battle and in the Command Menu. It must never steal input (`mouse_filter` ignore).
- Performance: test_performance must stay green. Report the frame cost.
- Head registers the script in `zone_base._spawn_hud` and `test_arena.gd` (Cross-Agent Request with the exact lines).
- Tasks:
  - [x] Y1. Minimap HUD script (frame, viewport, icon layer).
  - [x] Y2. Rotation and icon classification, with rim clamping.
  - [x] Y3. Visibility rules and a registration request to Head.
  - [x] Y4. Screenshot in town and in field (battle) via `tools/ui_screenshots.gd`. Request a new shot from Z if needed.
- Handoff Notes:
  - Files: NEW `src/ui/hud/minimap.gd` only (no class_name, no widget file; the icon layer is an inner class `MinimapIconLayer`). Nothing else edited.
  - Build: CanvasLayer (layer 9, PROCESS_MODE_ALWAYS) -> MinimapRoot -> MinimapFrame (anchored top-right, 220x220, 24 px margin) -> MinimapTerrain (TextureRect of the SubViewport texture, frost-tint + rounded-square mask shader, colours from UIStyle tokens) + MinimapIcons (rim, glow, range ring, icons, player arrow, N badge, heading tick). MinimapViewport (SubViewport 256x256, shares the zone World3D, MSAA/AA/TAA off, positional shadow atlas 0, `debug_draw = UNSHADED` so no lights/shadows, own flat Environment: no fog/glow/SSAO/SDFGI) -> MinimapCamera (orthographic, size 40 m, 40 m above the player, near/far cut geometry more than 8 m above / 40 m below the player so roofs over interiors and ceilings don't block it).
  - Rotation: the map camera's up axis = the gameplay camera's flattened forward, read from `get_viewport().get_camera_3d()` (read-only; the rig is never touched). Icons use the same right/forward frame. The player arrow is fixed at the centre and turns with the player's facing relative to the camera. The N badge sits on the rim in world -Z.
  - Icons: `enemies` red (larger with a halo while `ai_state` is not IDLE; DEAD skipped); `interactable` classified by script properties: `target_zone_id` = portal (cyan diamond), `interactable_type` NPC = white, everything else (chests, levers) = gold (opened chests dimmed); crate pick-up areas (`carryable`) are skipped. Quest star: the tracked quest's current objective `marker_position` via player/QuestSystem `get_tracked_quest()` (Vector3.ZERO = no marker). Note: the marker has no zone id, so a marker for another zone would still show (clamped to the rim). Off-range icons clamp to the rim (smaller, 75% alpha); beyond 60 m only portals and the quest star stay on the rim.
  - Refresh: terrain render + icon redraw every 2nd frame (`UPDATE_ONCE`); group scan every 500 ms (unscaled, `Time.get_ticks_msec`). No per-frame group queries. No typed arrays of widget classes (packed arrays only).
  - Visibility: hidden while any `Events.ui_menu_opened` menu is open except `target_selection`/`tactical_menu`, during `dialogue_started`..`dialogue_ended`, when the tree is paused, and when GameManager state is not PLAYING or TACTICAL_MODE. Visible in Battle and the Command Menu. Every Control has `mouse_filter = IGNORE`; the SubViewport has `gui_disable_input`; there is no input handler.
  - Test API (for Z1): `get_frame_rect()`, `is_map_visible()`, `should_show()`, `get_icon_counts()` (keys = Icon enum: 0 ENEMY, 1 ENEMY_ENGAGED, 2 NPC, 3 CHEST, 4 PORTAL, 5 QUEST), `get_map_viewport()`. To find it in a HUD: script path ends with `minimap.gd`.
  - Verified (windowed 1920x1080, temp scene script in tests/_tmp_y/, now deleted; minimap added manually to town_hub and field_zone): tree printed (above); frame rect = (1676,24) 220x220; all Controls IGNORE; town icons {NPC 6, portal 2}; field icons {enemy 3, engaged 1, NPC 3, chest 1, portal 2}; hidden in pause menu (real `pause` tap) and back after; hidden in dialogue and back; visible in the Command Menu (state TACTICAL_MODE) and the target step. 13/13 checks passed.
  - Frame cost (windowed, vsync off, same scene, minimap shown vs hidden over 120 frames): town 0.928 vs 0.748 ms (+0.18 ms), field 0.944 vs 0.733 ms (+0.21 ms). Script `_scan()+_refresh()` 12 us (town) / 19 us (field). (Per-viewport GPU timing reads 0 for UPDATE_ONCE viewports, so the whole-frame delta is the number to use.)
  - Screenshots: `docs/ui_screenshots/v4_minimap_town.png`, `v4_minimap_town_rotated.png` (camera yaw 90°, map rotated), `v4_minimap_field_battle.png`, `v4_minimap_field_command.png` (target step open). Z may add a minimap shot to `tools/ui_screenshots.gd` once Head registers it.
  - Tests: boot exit 0. test_ui_style 128/128. test_performance 64/65: the one failure is `Exactly 7 autoloads registered (got 8)`, caused by the `AssetRegistry` autoload already in the uncommitted `project.godot` before this package (it isn't in HEAD). Not related to the minimap. After registration zone_base will have 15 `Script :=` preloads, which still passes `test_zone_hud_count_bounded` (<= 15) but leaves no headroom.
  - Not done: the player model is not excluded from the map camera's cull mask (that would mean changing visual layers in player.tscn, which is W's file). At 40 m across, the model is about 3 px under the arrow, so it can't be seen.
  - Contract line for Z4: "Minimap top-right (rotates with camera; enemies red, NPCs white, chests gold, exits cyan; hidden in full-screen menus/dialogue)".

## Package Z — QA, Tests, Screenshots, Contract Draft
Owned files: `tests/test_battle.gd`, `tests/test_controls.gd`, `tests/test_ui_style.gd`, `tools/ui_screenshots.gd`, `tests/test_phase6.gd` (only to retire the predating assert, if Head agrees).
Status: DONE

- [x] Z1. Tests:
  - `battle_toggle` binding (joy 4 / F, version 5)
  - manual on/off, suppression, and the resume triggers
  - the target step is always shown, including "Fire Forward"-only with no enemies
  - Y fires forward, B backs out one layer
  - a minimap exists in the HUD, at the top-right, hidden in the pause menu
  - the mode chip reads FREE ROAM/BATTLE and follows the manual toggle (H-5)
  - an interaction-prompt regression test: the prompt clears after walking away from a crate (Head's H-1)
- [x] Z2. Full suite run. Report per-suite counts. Only the 4 failures that predate v3 may remain. (Result: 3 remain, all allowed; see below.)
- [x] Z3. Screenshots: free roam (hints bottom-left + minimap), manual battle, target step with Fire Forward, target step with 3 enemies.
- [x] Z4. CLAUDE.md contract draft:
  - `Battle toggle -> View (pad) / F (kb)`
  - "Offensive commands always confirm a target; Fire Forward available"
  - "Minimap top-right"
- Handoff Notes:
  - **Files changed**
    - `tests/test_controls.gd`:
      - Applied the W and X requests. BINDINGS_VERSION is 5 (source and runtime). The six hint-bar rows now end with `Back`/`F` + `Battle` or `Free Roam`, and the keyboard rows have size 5.
      - `test_no_target_spell_runtime`: the first A now expects the target step (`_phase == 2`, `_get_target_names() == ["Fire Forward"]`, index 0, nothing cast yet). The second A casts. The "Blocked spell (ATB 0)" part is unchanged.
      - New `test_battle_toggle_binding`:
        - the action exists, with joy 4 and F
        - only battle_toggle uses joy 4, and it isn't on LT
        - it is in REBINDABLE_ACTIONS
        - labels are Back (pad) and F (keyboard)
        - the settings row exists
        - the player and BattleModeComponent APIs exist
      - New `HINT_TO_BATTLE` / `HINT_TO_FREE_ROAM` asserts.
    - NEW `tests/test_v4.gd` + `tests/test_v4.tscn`, 96 checks. Input goes through `Input.parse_input_event` (the real `_unhandled_input` path) with real-time waits.
      - **Contract:** the Events signals, the BattleModeComponent API, `FIRE_FORWARD_LABEL`, `AbilityState.aim_forward()`, and no input callbacks in the minimap.
      - **Manual toggle:**
        - Pad Back enters Battle with nothing engaged: the hold is set, `changed` = [true], `manual` = [true]. There is no timeout with 7 s credited, or with real polling.
        - F returns to Free Roam with suppression on. Toggling on again clears it.
        - After a fight the v3 timer applies: still Battle at 2.8 s, Free Roam at 3.1 s.
      - **Resume triggers** (stand-down with an enemy engaged; that enemy alone never re-enters Battle):
        - A player hit (source HitboxAnchor) lifts the suppression at once.
        - A companion hit (source is the `party_members` node or a child of it) does **not** lift it.
        - A hit with no source lifts it.
        - A real `player.take_damage` (player_hurt) lifts it.
        - A stand-down enemy disengaging keeps it.
        - A different enemy engaging lifts it.
      - **Blocked states**, pressed for real:
        - PAUSED and CUTSCENE
        - the real Command Menu
        - dialogue (a stub `dialogue_ui`; `is_battle_toggle_press` is false)
        - hp 0
        - carrying a real crate

        No `manual_toggled` fires in any of them, and toggling is allowed again afterwards.
      - **Target step with no enemies:**
        - The only row is Fire Forward, pre-selected, and nothing casts before confirm.
        - Cycling stays on that row.
        - B goes back to the ability list, and A re-enters.
        - Y casts: the projectile `_direction` · camera forward is above 0.95, there is no homing target, and the menu closes.
      - **Target step with 3+ enemies** (frozen dummies to the left, right and behind the camera, plus the far battle driver):
        - The list is nearest-first with Fire Forward last. The nearest is pre-selected and highlighted.
        - D-pad down moves to the next enemy. D-pad right reaches Fire Forward, which clears the highlight, then wraps to the first enemy.
        - With ATB 0, confirm shows the fail toast and the step stays open.
        - A on enemy B damages B and nothing else.
        - Y from an enemy row fires along camera forward and hits no enemy.
      - **town_hub with the real zone_base HUD** (the entry autosave is blocked the way test_ui_style does it):
        - The minimap is in the HUD at (vp.x−244, 24), 220×220. It is visible in free roam and shows NPC and portal icons.
        - It hides on a real `pause` action and comes back on close.
        - It stays visible in the Command Menu, in both the target step and the ability list.
        - Town target step rows = ["Fire Forward"]. The footer contains Switch, Confirm, Fire Forward and Back.
        - Mode chip: FREE ROAM, then BATTLE after pad Back, then FREE ROAM after F. It also follows a direct `battle_mode_changed` emit.
        - Crate prompt regression: next to the crate the Pick Up prompt shows, and `carryable_in_range` remembers the crate. Walking 12 m away hides the prompt and empties `_carryable` and the text. Y then opens the Command Menu.
    - `tests/test_ui_style.gd`:
      - `battle_banner.gd` and `minimap.gd` added to `HUD_SCRIPTS` (exactly one each in field_zone).
      - The `battle_toggle` glyph is Back / F.
      - The minimap is registered in zone_base `_spawn_hud` and test_arena.
      - Source check: every `Color(` in minimap.gd wraps a UIStyle token.
      - Field HUD minimap:
        - anchored top-right, 220 px
        - every Control is mouse-IGNORE
        - the SubViewport is 256² with GUI input disabled
        - enemy and portal icons are drawn
        - the layer is below the Command Menu
    - `tools/ui_screenshots.gd`: new `_v4_town()` runs after shot 02, plus the field shot `v4_04`. ATB is filled before each Command Menu, and `UI_NOTE` lines log each step.
    - Unchanged:
      - `tests/test_battle.gd`: the v4 runtime coverage lives in test_v4.
      - `tests/test_phase6.gd`: it passes again since X restored `_navigate_slot`.
    - `tests/run-tests.bat` only runs `test_runner.tscn` (smoke) and has no suite list, so it needs nothing for test_v4.
  - **Z2: full suite** (`--headless --scene res://tests/<scene>.tscn`, 2026-11-13):

    | Suite | Passed | Failed |
    |---|---|---|
    | test_runner (smoke) | 35 | 0 |
    | test_phase6_runner | 111 | 0 |
    | test_phase7_runner | 23 | 0 |
    | test_phase8 | 64 | 1 |
    | test_phase9 | 56 | 0 |
    | test_phase10 | 72 | 0 |
    | test_phase11 | 63 | 0 |
    | test_phase12 | 64 | 1 |
    | test_phase13 | 64 | 0 |
    | test_phase14 | 67 | 0 |
    | test_phase15 | 68 | 0 |
    | test_battle | 136 | 0 |
    | test_carry | 76 | 0 (see note) |
    | test_controls | 236 | 0 |
    | test_ui_style | 141 | 0 |
    | test_performance | 64 | 1 |
    | test_v4 (new) | 96 | 0 |

    Boot (`--headless --quit-after 1`): exit 0, with no warnings or errors.

    The only failures are the 3 allowed ones that predate v4:
    - phase8 "New Game loads test arena scene"
    - phase12 "Field and dungeon have return portals (no softlocks)"
    - performance "Exactly 7 autoloads registered (got 8)" (AssetRegistry)
  - **test_carry is 76, not W's 78. This is a silent skip in the suite, not a v4 regression.**
    - Its own `_pick_up_fresh()` returns false without recording a failure.
    - A diagnostic in a temp copy (now deleted) showed the state before pick-up: `floor=false state=Fall can_pick_up_now=false`.
    - Each pick-up spawns a crate 1.6 m in front of the player, and earlier crates stay in the world at that spot. The new crate overlaps them and knocks the player into Fall.
    - As a result, "Forced transition out of Carry drops the crate" or the two "save data never holds a crate" checks are skipped some of the time. Over 3 runs this varied between the two sections.
    - Cross-Agent Request to Head below.
  - **Z3 screenshots** (windowed 1920×1080, `tools/ui_screenshots.gd`, 22 shots, exit 0). I opened and checked each new one:
    - `docs/ui_screenshots/v4_01_town_free_roam_minimap.png`:
      - Blue FREE ROAM chip above the quest panel.
      - Minimap top-right at (1676,24), 220²: N badge, white NPC dots, a cyan exit diamond on the rim, the gold quest star.
      - Hints bottom-left: `A Jump · X Attack · B Dodge · Y Command · Back Battle`.
    - `docs/ui_screenshots/v4_02_town_manual_battle.png`:
      - Taken after the `battle_toggle` action: red BATTLE chip and the BATTLE banner.
      - Hints: `A Command · X Attack · Hold Heavy · Y Arcane Stance · B Dodge · Back Free Roam`.
      - A second toggle returned to FREE ROAM (logged).
    - `docs/ui_screenshots/v4_03_town_target_fire_forward.png`:
      - "No targets in range" above a single "Fire Forward / Camera aim" row.
      - Footer: `Switch · A Confirm · Y Fire Forward · B Back`.
      - Description: "Fire Bolt › Fire forward along the camera (no target)".
      - The minimap stays visible.
    - `docs/ui_screenshots/v4_04_field_target_step_enemies.png`:
      - 9 rows, "1 / 9": Reactor Sentry A–H (disambiguated), then Fire Forward. The list scrolls.
      - A is highlighted, with the target bar. BATTLE chip. The minimap shows engaged and idle enemies.
      - Framing: sentry A stands straight in front of the player on the camera line, so its TARGET reticle draws over Amaro's head. That comes from the shot's camera placement, not a bug.
      - This also shows X's open note: every enemy in the zone is listed. A range limit would shorten the list.
    - Shots 01–18 were regenerated with the pad set and are unchanged in content.
  - **Finding (low, no visible effect):**
    - H-1's comment in `interaction_prompt._on_interaction_available` says "The crate's own InteractArea re-emits carryable_in_range right after this". In zones the order is reversed.
    - The crate's `CrateInteractArea` connects to `interaction_available` in its `_ready`. That runs in `_setup_zone()`, before `_spawn_hud()`, so the crate's handler fires first and the prompt's handler then sets `_carryable = null`.
    - Next to a crate the prompt still reads "[Y] Pick Up" through the interactable path, and it hides correctly on exit (tested). Only the comment is wrong, and `_carryable` is null while in range.
  - **Z4: CLAUDE.md contract draft** (Head applies after user approval):
    - INPUT CONTRACT → Xbox Controller:
      - `- [ ] Battle / Free Roam toggle -> View/Back (manual stand-down suppresses auto-battle until damage dealt/taken or a new enemy engages)`
      - `- [ ] Manual Battle allowed with no enemies (no timeout); toggle blocked in menus, dialogue, cutscene, while carrying or dead`
    - INPUT CONTRACT → Keyboard / Mouse: `- [ ] Battle toggle -> F`
    - TACTICAL MODE RULES:
      - `- [ ] Offensive commands always open the target step (enemies nearest-first + "Fire Forward"); never cast straight from the list`
      - `- [ ] Target step: D-pad/stick cycles (wraps), A confirm, Y/E Fire Forward (camera aim) from any row, B/Esc back one layer`
      - `- [ ] With no enemies the target step shows only "Fire Forward", pre-selected (still needs a confirm)`
      - `- [ ] ATB/MP checked on confirm; a failed confirm shows the toast and keeps the target step open`
    - HUD (new lines):
      - `- [ ] Minimap top-right (220 px, 24 px margin), rotates with camera; enemies red (larger when engaged), NPCs white, chests gold, exits cyan, quest star gold; hidden in full-screen menus/dialogue/pause, visible in Battle and the Command Menu; never takes input`
      - `- [ ] Mode chip above the quest panel: FREE ROAM (blue) / BATTLE (red), blinks on every switch`
      - `- [ ] Control hints bottom-left; the last hint is the Battle / Free Roam toggle`
    - Launcher contract / tests: add `Z:/godot/godot.exe --path . --headless --scene res://tests/test_v4.tscn`

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`

- [from X → to Z] `tests/test_controls.gd` `test_no_target_spell_runtime` (~L1083-1110) still expects one A on Fire Bolt with no enemies to cast at once. In v4 that A opens the target step with only "Fire Forward" pre-selected. Please add a second `await _confirm(player)` (or an `interact`/Y press) before the "cast" asserts, assert `int(state._phase) == 2` plus `state._get_target_names() == ["Fire Forward"]` after the first confirm, and keep the "Blocked spell (ATB 0)" part as it is (it still fails at the ability list). — DONE (Z): applied in test_controls; 236/0
- [from W → to Z] `tests/test_controls.gd` for v4 bindings/hints — DONE (Z): all items applied, plus test_battle_toggle_binding and HINT_TO_* asserts; 236/0
  - `test_settings_manager_bindings_version`: expect `const BINDINGS_VERSION := 5` and runtime `== 5`.
  - `test_control_bar_runtime`: add the trailing toggle hint. Free pad `… ["Y","Command"], ["Back","Battle"]`; free pad with prompt `… ["Y","Interact"], ["Back","Battle"]`; free kb `kb.size() == 5`, `kb[4] == ["F","Battle"]`; battle pad `… ["B","Dodge"], ["Back","Free Roam"]`; stance pad `… ["B","Dodge"], ["Back","Free Roam"]`; battle kb `bkb.size() == 5`, `bkb[4] == ["F","Free Roam"]`.
  - `test_control_bar_v3_hints` needs no change (`HINTS_*` are untouched). Optionally assert `HINT_TO_BATTLE == [&"battle_toggle","Battle"]` and `HINT_TO_FREE_ROAM == [&"battle_toggle","Free Roam"]`.
  - New (Z1): `&"battle_toggle" in SettingsManager.REBINDABLE_ACTIONS`; InputMap has Key F + JoypadButton 4; `battle_mode.toggle_manual()`, `is_suppressed`, `is_manual_hold`; `player.can_toggle_battle()`.
- [from W → to Head] Optional, recommended: `Events.enemy_damaged` has no source, so BattleModeComponent can't tell player hits from companion hits (interim heuristic in W Handoff). Suggest a new signal `Events.enemy_hit(enemy: Node3D, amount: float, source: Node)`, emitted in `enemy_base.take_damage` next to `enemy_damaged`. W would then lift suppression only when `source` is the player or a node it owns (player, HitboxAnchor, its orbs/blasts/thrown crate). — OPEN — DONE (Head): added `Events.enemy_hit(enemy, amount, source)`, emitted in `EnemyBase.take_damage`. BattleModeComponent now listens to it: a hit whose source is, or sits under, a non-player `party_members` node is the companion's; anything else is the player's. The ATTACK-state heuristic and `COMPANION_ATTACK_STATE` are removed. Runtime check: a companion hit keeps the suppression, a player hit lifts it.
- [from Y → to Head] Register the minimap HUD — DONE (Head): registered in zone_base._spawn_hud and test_arena.gd; boot exit 0
  - `src/world/zone_base.gd`: add `const MinimapScript := preload("res://src/ui/hud/minimap.gd")` next to the other HUD preloads, and add `MinimapScript` to the `hud_scripts` array in `_spawn_hud` (for example after `QuestTrackerScript`).
  - `scenes/test/test_arena.gd`: add `const MinimapScript := preload("res://src/ui/hud/minimap.gd")` and, next to the quest tracker block:
    ```
    	# Add minimap (top-right)
    	var minimap := CanvasLayer.new()
    	minimap.set_script(MinimapScript)
    	add_child(minimap)
    ```

- [from Z → to Head] `tests/test_carry.gd` silently skips 1–3 checks — OPEN
  - Symptom: `_pick_up_fresh()` returns false without calling `_fail`.
  - Repro: run `Z:/godot/godot.exe --path . --headless --scene res://tests/test_carry.tscn` a few times. The total is 76 instead of 78–79, and either the "SAVE DATA NEVER HOLDS A CRATE" section or the "Forced transition out of Carry…" check prints nothing.
  - Cause: each pick-up spawns a crate 1.6 m in front of the player while earlier tests' crates still lie there. The overlap knocks the player into Fall, so `can_pick_up_now` is false (`floor=false state=Fall`).
  - Suggested test-only fix: free leftover crates in `_ground_player()`, or spawn at a fresh offset; and `_fail(...)` when `_pick_up_fresh()` returns false.
  - Not a game bug.
- [from Z → to Head] Optional: add `tests/test_v4.tscn` wherever Head tracks the suite list. `run-tests.bat` only runs the smoke runner, so it needs no change. — OPEN

---

## Head Agent Review
Status: DONE except R-6 (waiting on the user's CLAUDE.md approval, controller test and commit approval)
Head re-run 2026-11-13: test_v4 96/96, test_controls 236/236, test_battle 136/136, test_ui_style 141/141, boot exit 0. Screenshot v4_01 reviewed (minimap, chip, bottom-left hints).
Head edits: Events.enemy_hit plus source attribution in BattleModeComponent; minimap registration; interaction_prompt comment fix.
Follow-ups moved to the next plan: test_carry silently skips checks (test-only), Back→View glyph, target range limit, lock-on framing.
- [x] R-1. Minimap registered in `zone_base._spawn_hud` and `test_arena.gd`.
- [x] R-2. Review diffs: no camera-internal edits, no ownership violations, UIStyle only.
- [x] R-3. Boot exit 0 and the full suite (Z2) reproduced by Head.
- [x] R-4. Scene/HUD tree printed. Signals verified: `battle_mode_manual_toggled`, `battle_mode_changed`, `tactical_target_info`.
- [x] R-5. Screenshots reviewed.
- [x] R-6a. Z4 CLAUDE.md draft applied (user approved 2026-11-13).
- [ ] R-6. (remaining) Apply Z4's CLAUDE.md draft after user approval. Then the controller test, `project_status.json`, and a commit on approval.
