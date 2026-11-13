# Controller Remap Plan — FF7 Rebirth-Style Command Menu on A

Created: 2026-11-12
Owner: Head Agent (reviews and verifies all work)
Status: IMPLEMENTED — AWAITING USER CONTROLLER TEST

---

## How to use this file (ALL AGENTS READ FIRST)

1. Find your section under **Work Packages**. Do only the tasks listed there.
2. **Only edit files listed in your "Owned files".** If you need a change in another agent's file, write it under **Cross-Agent Requests** below. Do not make the change yourself.
3. When you start, set your package `Status: IN PROGRESS` and fill in `Started:`.
4. Tick each task checkbox as you finish it. Never delete a task. If a task turns out to be unnecessary, mark it `N/A` and give the reason.
5. When you finish, set `Status: DONE — AWAITING REVIEW` and fill in `Finished:`. Also fill in the **Handoff Notes**: what changed, file:line refs, anything risky, and anything you could not finish.
6. Before marking DONE, run the headless boot and paste the result (pass/fail plus any errors) into your Handoff Notes:
   `Z:/godot/godot.exe --path . --headless --quit-after 1`
7. Do NOT edit `project_status.json` or the checklist in `CLAUDE.md`. The head agent owns those. (Agent E is the one exception: it edits the INPUT CONTRACT section of CLAUDE.md.)
8. Do NOT commit. The head agent commits after review.
9. Timestamps use ISO8601 minute precision (e.g. `2026-11-12T14:05`).

Working directory: `Z:/Development/lumina/games/projectRagnorak`
Godot: `Z:/godot/godot.exe` only.

---

## Approved Design (user-approved 2026-11-12)

### Xbox controller layout

| Button | Action(s) | Notes |
|---|---|---|
| **A** (joy 0) | `tactical_mode` (Command Menu) + menu confirm (`ui_accept`) | Outside combat with an interact prompt showing, A interacts instead (contextual) |
| X (joy 2) | `attack` | unchanged |
| B (joy 1) | `dodge` + menu back (`ui_cancel`) | unchanged |
| **Y** (joy 3) | `jump` | was Interact |
| RB (joy 10) | unbound | reserved for future Guard. Do not implement now |
| LB (joy 9) | unbound | reserved for future Shortcuts. Do not implement now |
| LT (axis 4) | unbound on controller | was tactical_mode. Keyboard Q stays |
| RT (axis 5) | `lock_on` | unchanged |
| D-pad Left (joy 13) | `target_switch_left` | was joy 14 (bug) |
| D-pad Right (joy 14) | `target_switch_right` | was joy 15 / Share (bug) |
| D-pad Up (joy 11) / Down (joy 12) | `party_switch` | Down is new. Input was never wired (bug) |
| R3 (joy 8) | `camera_reset` | unchanged |
| Start (joy 6) | `pause` | unchanged |

### Keyboard / mouse: unchanged
WASD move, Mouse camera, Space jump, LMB attack, Shift dodge, E interact, Q tactical, MMB lock-on, Esc pause, `[` / `]` target switch, Tab party switch, F7/F11 quicksave/quickload.

### Interaction rules (contract for every agent)
- **Menus never listen to `jump` or `dodge` for confirm/back.** They use `ui_accept` / `ui_cancel` (Godot defaults: A/Enter/Space and B/Esc). Moving Jump must not break any menu.
- `interact` action = keyboard E only. Controller interact happens through the contextual-A rule.
- **Contextual A:** in gameplay states, when `tactical_mode` is pressed:
  - If NOT in combat AND the player has a current interactable, interact instead of opening the menu.
  - Otherwise open the Command Menu.
  - Keyboard Q always opens the menu. E always interacts.
- **Tactical menu:** the A press that opens the menu must NOT also confirm the first category. Inside the menu, A = confirm, B = back/close, Start = close. Pressing `tactical_mode` inside the menu must not close it, because that press is A = confirm.
- Lock-on, combo state and time scale must be preserved exactly as they are now on open and close.

### Out of scope (expansion-gated, do NOT build)
Guard/parry, unique ability (Y in Rebirth), LB shortcuts, synergy skills, ally commands on triggers, map, full party-switch cooldown system (item 456).

---

## Work Packages

Wave 1: A, B, C and D run in parallel because their files do not overlap.
Wave 2: E starts its tests in parallel, but runs them only after A–D are DONE.
Wave 3: Head agent review.

---

### Package A — Input Map, Settings and Control Hints
Status: DONE — AWAITING REVIEW
Started: 2026-11-12T16:45
Finished: 2026-11-12T16:49

Owned files:
- `project.godot` (the `[input]` section only)
- `scripts/autoloads/settings_manager.gd`
- `src/ui/hud/control_bar.gd`

Tasks:
- [x] A1. `project.godot`: change the `tactical_mode` joypad event from axis 4 (LT) to JoypadButton 0 (A). Keep key Q.
- [x] A2. `project.godot`: change the `jump` joypad event from button 0 to button 3 (Y). Keep Space.
- [x] A3. `project.godot`: remove the joypad button 3 event from `interact`. Keep key E.
- [x] A4. `project.godot`: set `target_switch_left` to joy 13 and `target_switch_right` to joy 14. Keep the `[` / `]` keys.
- [x] A5. `project.godot`: add joy 12 (D-pad Down) to `party_switch`. Keep joy 11 and Tab.
- [x] A6. Confirm no other action uses joy 0, 3, 13 or 14. List every action's final events in the Handoff Notes.
- [x] A7. `settings_manager.gd`: add `const BINDINGS_VERSION := 2`, save it in settings.json, and discard saved `bindings` whose version is missing or lower, so stale remaps can't override the new defaults. Other settings must survive this.
- [x] A8. `settings_manager.gd`: make sure the public display-name helper (the one that already maps joy index to "A"/"LB" etc.) can return a binding label for a given action and device. Add `get_action_label(action, controller: bool) -> String` if it is missing.
- [x] A9. `control_bar.gd`: stop hardcoding `"pad"`/`"kb"` strings. Pull labels from `SettingsManager.get_action_label(...)` so hints follow the real bindings. Rename the TACTICAL entry to "COMMAND". Order: MOVE, ATTACK, DODGE, COMMAND, JUMP, LOCK-ON, PAUSE. Drop the INTERACT entry from the controller view (it's contextual) but keep it for keyboard.
- [x] A10. Headless boot passes.

Handoff Notes:
- **project.godot [input]** (A1–A5): `jump` :64 joy 0→3, `interact` :76 joy 3 removed, `tactical_mode` :80 axis 4→JoypadButton 0, `target_switch_left` :96 joy 14→13, `target_switch_right` :100 joy 15→14, `party_switch` :108 added joy 12. Serialization copied from existing JoypadButton lines. No other section touched.
- **A6 final events (all actions):** move_up W/axis1-, move_down S/axis1+, move_left A/axis0-, move_right D/axis0+, camera_up/down axis3∓, camera_left/right axis2∓, jump Space/joy3, attack LMB/joy2, dodge Shift/joy1, interact E only, tactical_mode Q/joy0, lock_on MMB/axis5, camera_reset joy8, pause Esc/joy6, target_switch_left joy13/`[`, target_switch_right joy14/`]`, quicksave F7, party_switch Tab/joy11/joy12, quickload F11. Each joypad button (0,1,2,3,6,8,11,12,13,14) is used by exactly one action. LT (axis 4), LB (9) and RB (10) are now unbound.
- **settings_manager.gd** (A7/A8): `const BINDINGS_VERSION := 2` :10. `"bindings_version"` saved :61. Load gate :92–99: if the saved version is missing or lower, it clears `_custom_bindings`, keeps the InputMap defaults, and re-saves only if a `bindings` key existed. Camera, audio and gameplay values are parsed before the gate, so they survive. Confirmed for real: the boot migrated the user's existing `%APPDATA%/Godot/app_userdata/Project Ragnorak/settings.json` to `bindings_version: 2` and kept its other values. New `get_action_label(action, controller) -> String` :172 joins multiple events with "/" (party_switch → "D-Up/D-Down"). `_short_key_name` makes Escape→Esc and BracketLeft/Right→`[`/`]` in that helper only. `_joy_axis_name` now maps axes 0/1→"LS" and 2/3→"RS". The existing `get_action_keyboard_text`/`get_action_controller_text` are unchanged, which keeps the test_phase15 source asserts valid. REBINDABLE_ACTIONS is unchanged.
- **control_bar.gd** (A9): CONTROLS :9 has no kb/pad strings any more. It now has a `pad_visible` flag. Order: MOVE, ATTACK, DODGE, COMMAND, JUMP, LOCK-ON, INTERACT (keyboard only), PAUSE. Labels come from `refresh_labels()` :51, which runs on `_ready`, on `InputManager.device_changed` and on `SettingsManager.settings_changed`. Labels now show the active device only (previously "[kb/pad]"). The keyboard MOVE label is built from the first key of move_up/left/down/right ("WASD"). Runtime check: KB view `[WASD][LMB][Shift][Q][Space][MMB][E][Esc]`. Pad view `[LS][X][B][A][Y][RT]` + `[Start]`, with INTERACT hidden.
- Risk: `rebind_action` erases only the first controller event of an action, so rebinding party_switch on pad replaces joy 11 and keeps joy 12. This was existing behavior and I left it.
- **Boot (A10):** `Z:/godot/godot.exe --path . --headless --quit-after 1` → exit 0, no errors or warnings (16:48, while other agents were working).
- **Follow-up (B's blocker, 16:52):** added `ui_accept` override (project.godot:116: Enter/Kp Enter/Space/joy 0) and `ui_cancel` override (:120: Escape/joy 1) at the end of [input]. Runtime dump confirms both. ui_up/down/left/right were not overridden because the defaults already include D-pad 11–14 and left-stick axes. Intended overlaps: joy 0 is `tactical_mode` + `ui_accept`, and joy 1 is `dodge` + `ui_cancel`. Re-ran the boot: exit 0, no errors.

---

### Package B — Menus use ui_accept / ui_cancel
Status: DONE — AWAITING REVIEW
Started: 2026-11-12T16:44
Finished: 2026-11-12T16:51

Owned files:
- `src/ui/menus/pause_menu.gd`
- `src/ui/menus/quest_log.gd`
- `src/ui/menus/save_load_menu.gd`
- `src/ui/menus/settings_menu.gd`
- `scenes/menus/main_menu.gd`
- `src/ui/dialogue/dialogue_ui.gd`

Tasks:
- [x] B1. In every owned file, replace `is_action_pressed(&"jump")` used as confirm with `ui_accept` only. Keep any existing `ui_accept` check, and don't double-fire.
- [x] B2. In every owned file, replace `is_action_pressed(&"dodge")` used as back with `ui_cancel` only. Keep `pause` where it closes a menu.
- [x] B3. `settings_menu.gd`: check the rebind flow (`_handle_rebind_input`). Pressing A/B while waiting for a rebind must capture the button and must not confirm or cancel the menu. Its `interact` usage (around line 433) should become a non-gameplay action, or a documented ui_* fallback.
- [x] B4. `main_menu.gd`: confirm with `ui_accept` (A / Enter / Space). Remove the `jump`/`interact` checks.
- [x] B5. `dialogue_ui.gd`: advance on `ui_accept` OR `interact` (E). Hint text stays "[A] Continue". Make sure the A press that opened the dialogue (contextual A, Package C) does not also advance page 1. Use `get_viewport().set_input_as_handled()` and/or ignore input for the first frame after open.
- [x] B6. Every confirm/back handler calls `get_viewport().set_input_as_handled()`, so an A press in a menu never leaks into gameplay (opening the Command Menu behind the pause menu).
- [x] B7. Check that existing tests in `tests/test_phase8.gd`, `test_phase10.gd` and `test_phase11.gd` that grep for `"ui_accept"`/`"ui_cancel"`/`"jump"` still pass. Note any that need updating under Cross-Agent Requests for Agent E. Do not edit tests yourself.
- [x] B8. Headless boot passes.

Handoff Notes:
- **BLOCKER (see Cross-Agent Requests B→A):** in Godot 4.6, `ui_accept` = Enter/Kp Enter/Space and `ui_cancel` = Escape only, with no joypad events (runtime InputMap dump). project.godot doesn't override them. Until Agent A adds joy 0 to `ui_accept` and joy 1 to `ui_cancel`, controller A/B won't confirm or back out in any Package B menu, or in Package C's tactical menu. I didn't add raw joypad checks to the menus, since the contract says ui_* only and the fix belongs in the InputMap.
- B1/B2: `jump`→`ui_accept` and `dodge`→`ui_cancel`. `pause` still closes the menus that had it. pause_menu.gd:216, :222. quest_log.gd:365, :371. save_load_menu.gd:75, :81 (overwrite confirm), :96, :99. settings_menu.gd:401, :427. Each is a single branch, so a press can't fire twice. Keyboard Shift no longer backs out of menus (by design: dodge isn't back).
- B3: settings_menu.gd:390–397. The rebind branch runs first, captures every pressed key, mouse or joypad event (A and B included), and marks it handled, so menu confirm/cancel never fires. Only the Escape key cancels a rebind (unchanged). The A press that starts a rebind is handled; its release is ignored because only pressed events are captured. Reset defaults (settings_menu.gd:432–439) now uses `ui_select` restricted to `InputEventJoypadButton` (pad Y; Space is already taken by ui_accept), plus `interact` restricted to `InputEventKey` (E) as a documented keyboard fallback. Hint text updated to "[Y/E] Defaults" (:655/:657/:659).
- B4: main_menu.gd:35–44. Removed `jump`/`interact`. A focused Button already handles ui_accept in its own `_gui_input`. The `_unhandled_input` fallback presses the focused button, or re-grabs New Game if nothing has focus. **New fix:** `_on_load`/`_on_options` now call `gui_release_focus()` before opening a sub-menu, and `_restore_focus()` (:84) refocuses the originating button on `menu_closed`/`closed`. Without this, once A is ui_accept, A or Enter in Settings/Load would re-press the still-focused main-menu button instead of reaching the sub-menu.
- B5: dialogue_ui.gd:19, :103, :141–148. Advances on `ui_accept` or `interact`. It ignores events on the process frame where `start_dialogue` ran (`Engine.get_process_frames()`) and ignores echoes, but still marks those events handled. Hint text is unchanged ("[A] Continue" / "[E / Enter] Continue"). This also fixes an existing case where the E press that started a dialogue could skip page 1 if dialogue_ui saw the event after the player.
- B6: every confirm/back branch in all six files calls `get_viewport().set_input_as_handled()`. Verified by reading each handler.
- B7: tests run read-only (not edited). Phase 8: 61/65. Two failures are new from B (main menu jump/interact grep, pause dodge grep). Two failed before B ("attack" confirm, New Game→test arena). Phase 10: 71/72; the one failure (quest log "attack") predates B. Phase 11: 62/63; the one failure (save/load "attack") predates B. Phase 15: 68/68. test_runner: 35/35. Details are in B→E.
- B8: `Z:/godot/godot.exe --path . --headless --quit-after 1` → exit 0, no errors or warnings (16:50). The test scenes above load all six scripts with no compile errors.
- Risk: the pause menu is the parent of the save/quest/settings sub-menus. Children get `_unhandled_input` first and consume ui_accept/ui_cancel, so the pause menu never double-handles. Esc or Start inside a sub-menu still reaches pause_menu's `pause` toggle only in sub-menus that don't handle `pause` (settings_menu), which is unchanged from before.

---

### Package C — Player States: Command Menu on A + Contextual Interact
Status: DONE — AWAITING REVIEW
Started: 2026-11-12T00:00
Finished: 2026-11-12T00:45

Owned files:
- `src/player/player.gd`
- `src/player/states/tactical_idle_state.gd`
- `src/player/states/idle_state.gd`
- `src/player/states/run_state.gd`
- `src/player/states/lock_on_idle_state.gd`
- `src/player/states/lock_on_strafe_state.gd`
- `src/ui/hud/tactical_menu.gd` (hint text only)

Tasks:
- [x] C1. `player.gd`: add `is_in_combat: bool`, driven by `Events.combat_started` / `Events.combat_ended`. Add `has_interactable() -> bool` and `try_interact() -> bool` that wrap the existing `_current_interactable` logic.
- [x] C2. `player.gd` `_unhandled_input`: keep `interact` (E) working as it does now.
- [x] C3. In `idle_state`, `run_state`, `lock_on_idle_state` and `lock_on_strafe_state`, handle `tactical_mode` press with this rule: if `not player.is_in_combat and player.has_interactable()`, call `player.try_interact()` and do not transition. Otherwise transition to tactical as now. Keyboard Q (key event) always opens the menu. Detect device with `event is InputEventKey`.
- [x] C4. `tactical_idle_state.gd`: add an open-press guard. Ignore `ui_accept`/`tactical_mode` until that action has been released at least once after `enter()`, or for one physics frame after enter. Pick one and document it.
- [x] C5. `tactical_idle_state.gd`: replace every confirm check `jump or ui_accept` with `ui_accept`, and every back check `dodge or ui_cancel` with `ui_cancel` (B). Keep `dodge` as back only if it doesn't double-fire with `ui_cancel` on B.
- [x] C6. `tactical_idle_state.gd`: in all three phases, remove `tactical_mode` as a close trigger on controller, since A = confirm now. Keyboard Q still toggles the menu closed (key event check). `pause` (Start / Esc) closes from any phase.
- [x] C7. `tactical_idle_state.gd`: target-phase left/right still uses `target_switch_left/right` and the stick. Verify it works with the new D-pad 13/14 bindings.
- [x] C8. Confirm that open/close keeps the time scale (GameManager stack), lock-on target and combo state unchanged. No edits should be needed beyond the input checks; report if any were.
- [x] C9. `tactical_menu.gd`: hint text stays "[A] Select [B] Close/Back". Update only if wording changed.
- [x] C10. `jump` handling in locomotion states needs no code change (it's action-based). Confirm that Y now jumps in idle, run, fall (double jump), ledge grab and lock-on.
- [x] C11. Headless boot passes.

Handoff Notes:
- **player.gd**
  - `is_in_combat` var at :47. Connected to `Events.combat_started`/`combat_ended` at :76-77. Handlers at :327/:331.
  - `has_interactable()` at :336 checks valid, active and has `interact()`. `try_interact()` at :345.
  - `is_dialogue_active()` at :353 uses the public `DialogueUI.is_dialogue_active()` through the `dialogue_ui` group, the same way party_system does.
  - `handle_contextual_command(event) -> bool` at :368 holds the contextual-A rule in one place:
    - Dialogue open: the press is consumed (no menu, no re-interact).
    - Key event (Q): returns false, so the menu opens.
    - Not in combat and an interactable present: `set_input_as_handled()`, then `try_interact()`, returns true.
    - Otherwise: returns false, so the menu opens.
  - `_unhandled_input` at :380: E still interacts through `try_interact()`. It now skips while a dialogue is open (so E can't restart the dialogue) and marks the event handled after interacting.
- **States**: idle_state.gd:35, run_state.gd:49, lock_on_idle_state.gd:43 and lock_on_strafe_state.gd:53 each do `if player.handle_contextual_command(event): return &""` before `return &"TacticalIdle"`.
- **Double-handling analysis**
  - StateMachine is a child of Player, so its `_unhandled_input` runs before `Player._unhandled_input` for the same event. An A press goes to the state only: A is not in `interact` any more, so the player's E path doesn't fire.
  - When contextual A interacts, the event is marked handled before `interact()`, so a DialogueUI later in the tree won't advance page 1 on the same press.
  - When dialogue is already open and the player sees A first, the player consumes the press without marking it handled, so DialogueUI still gets it and advances.
- **C4 open-press guard (chosen: both conditions)**
  - `_confirm_armed` at tactical_idle_state.gd:26 is set false in `enter()` (:37).
  - It is armed only in `process_physics()` (:65-69), on a physics tick where neither `ui_accept` nor `tactical_mode` is held. So it needs at least one physics frame after enter AND the opening press released.
  - Physics ticks keep running at 0.1x and hit-stop 0.0x time scale, because Godot scales delta, not the tick count.
  - Every confirm goes through `_is_confirm_event()` (:195).
  - Note for E3: a synthetic `ui_accept` right after `enter()` is ignored. To test a real confirm, call `process_physics(0.0)` first with no input held.
- **C5**: confirm = `_is_confirm_event()` (:195) = armed AND (`ui_accept` OR a non-key `tactical_mode` press). There is no `jump` anywhere in the file. The joypad-`tactical_mode` branch makes A confirm even if `ui_accept` has no joypad event (see B's BLOCKER). It is a single condition on one event, so it can't double-fire. Q (a key event) is excluded because Q closes the menu. Back = `_is_back_event()` (:190) = `ui_cancel or dodge`. I kept `dodge` as keyboard back (Shift). On controller, dodge and ui_cancel are the same B event checked in one condition, so it can't double-fire.
- **C6**: `_is_close_event()` (:181) = `pause` (Start/Esc) from any phase, or `tactical_mode` only when `event is InputEventKey` (Q). A joypad A press inside the menu never closes it.
- **C7**: no change needed. The target phase already checks `move_left/right`, `ui_left/right` and `target_switch_left/right` in one if/elif chain. D-pad 13/14 matches both `ui_left/right` (defaults) and `target_switch_*` on the same event, so it cycles once.
- **C8**: no edits. `enter()`/`exit()` still call `GameManager.enter/exit_tactical_mode()` (push/pop of "tactical" 0.1). `_exit_to_idle()` still returns LockOnIdle when locked on. The combo code is untouched, and the illegal transitions from attack states still block TacticalIdle.
- **C9**: tactical_menu.gd hints are already "[A] Select [B] Close", "[A] Select [B] Back" and "[Left/Right] Switch [A] Confirm [B] Back". No edit made.
- **C10**: every jump check is action-based (`is_action_pressed(&"jump")`) and none hardcode a button: idle:27, run:41, jump (double jump):42, fall:36, ledge_grab:23, lock_on_idle:41, lock_on_strafe:51. Agent A's project.godot now has jump on joy 3 plus Space.
- **RISK / GAP: `Events.combat_started` and `combat_ended` are never emitted anywhere in src/, scenes/ or scripts/. Only AudioManager listens.** So `is_in_combat` is always false today, and A near any interactable (a chest or lever in an arena, for example) interacts instead of opening the menu, even mid-fight. I did not add an emitter because that code is outside my files (see the Cross-Agent Request).
- Small addition beyond the spec: menu opening (Q included) is blocked while a dialogue is open. This follows the "Cutscene blocks TacticalMode" design contract and prevents A opening the menu behind the dialogue box.
- Pre-existing test issue, not caused by this package: test_phase6.gd:377 asserts `_navigate_slot` in tactical_idle_state.gd. HEAD doesn't have it either.
- **Boot**: `Z:/godot/godot.exe --path . --headless --quit-after 1` PASS, exit 0, no errors. I also instanced `res://scenes/test/test_arena.tscn` headless for 30 frames, which loads the player and all states. No script errors, only the usual "ObjectDB instances leaked at exit" warning.

---

### Package D — Party Switch Input Wiring
Status: DONE — AWAITING REVIEW
Started: 2026-11-12T00:00
Finished: 2026-11-12T00:30

Owned files:
- `src/party/party_system.gd`

Tasks:
- [x] D1. Add `_unhandled_input` in `party_system.gd` that calls `switch_member_battle()` on `party_switch` press.
- [x] D2. Block the switch when: game paused, tactical mode active (`GameManager` tactical flag), cutscene/dialogue active, or the active member is dead or downed. Use existing GameManager / state APIs only. Do not reach into player state internals; read only public flags or signals.
- [x] D3. Add a minimal anti-spam guard (`const SWITCH_COOLDOWN := 1.0`, timestamp check). Note in the Handoff Notes that this is a placeholder, not item 456.
- [x] D4. Verify the camera follows the new member through the existing `party_member_switched` signal. If switching is visually a no-op because control transfer is still a stub (see the comment at party_system.gd:~128), report that clearly and do NOT rewrite the party system. — **RESULT: STUB. Nothing follows.** See notes.
- [x] D5. Headless boot passes.

Handoff Notes:
- **Changes (only `src/party/party_system.gd`):**
  - :19-24 `SWITCH_COOLDOWN := 1.0`, `_last_switch_msec`, `_active_player_dead`.
  - :29-31 `_ready` also connects `Events.player_died`, `Events.player_respawned`, `Events.player_hp_changed` (dead tracking, signals only).
  - :34-44 `_unhandled_input`: on `party_switch` press (non-echo), checks `can_switch_from_input()`, the cooldown, calls `set_input_as_handled()`, then `switch_member_battle()`.
  - :47-61 `can_switch_from_input()` (public): blocks if not initialized or <2 members, `get_tree().paused`, `GameManager.current_state != PLAYING` (covers PAUSED, TACTICAL_MODE, CUTSCENE, LOADING, MAIN_MENU, GAME_OVER), dialogue active, or active member incapacitated.
  - :64-68 dialogue check uses the public `is_dialogue_active()` on nodes in group `dialogue_ui`. (`Events.dialogue_started/ended` exist but nothing emits them, so I could not rely on them.)
  - :71-81 incapacitated = active node invalid, or `is_downed()` true (companion API), or hero and `_active_player_dead`.
  - :84-93 signal handlers. Dead clears when `player_hp_changed` reports hp > 0, or on `player_respawned` (nothing emits it yet).
  - (Line refs after edit: `switch_member()` is :170-203, stub comment :200-202, emit :203.)
- **Cooldown:** `SWITCH_COOLDOWN` is a PLACEHOLDER anti-spam guard (real-time `Time.get_ticks_msec`, so 10% tactical time scale doesn't affect it). It is NOT item 456 (switch cooldown system). It has no UI.
- **D4, control transfer is a STUB. Switching does nothing you can see.** `switch_member()` (:170-203) only flips the `is_active` flags and `active_index`, then emits `Events.party_member_switched`. No runtime script connects to `party_member_switched`; the only reference outside the emitter is `tests/test_phase13.gd`. Camera, player input and companion AI never change. The comment at :200-202 says "For now, camera switches via signal", but no camera code listens. Pressing D-pad Up/Down/Tab updates the internal flags, and that's all. I did not rewrite it, per instructions.
- **Risks introduced by real input now reaching the stub (please review):**
  1. After one switch, `active_index` = companion. `get_companion()` returns the first non-active member, which is now the **hero**. `tactical_idle_state.gd:232` uses `get_companion()` for ally targeting, so ally commands could target the player node.
  2. `get_save_data()` only writes `companion_data` for non-active members. A save made after a switch would skip the companion's state and save the hero's flags inverted.
  3. After a switch, the dead/downed check looks at the companion's `is_downed()`. The hero's death flag only blocks when `id == &"hero"` is active.
  The head agent should decide: keep input wired (cheap, matches design) or gate it until real control transfer lands. I can add a `const INPUT_SWITCH_ENABLED := true` toggle on request.
- Pre-existing unused locals `old_node`/`new_node` in `switch_member()` were left untouched.
- **Boot:** `Z:/godot/godot.exe --path . --headless --quit-after 1` → PASS. No errors. One expected WARNING from Package A: `SettingsManager: discarding saved bindings (version 0 < 2)`.
- **Extra check:** `--quit-after 120 res://scenes/test/test_arena.tscn` loads party_system.gd with no compile errors and spawns the companion. One unrelated runtime error I didn't fix (not my file): `get_global_transform: !is_inside_tree()` at `enemy_base.gd:386 _spawn_damage_number`, called from `companion_ai.gd:162 _do_attack`.
- I did not inject a runtime input simulation, because I couldn't add a temp scene without touching files I don't own. Agent E can cover it (see Cross-Agent Requests).

---

### Package E — Tests and Input Contract Docs
Status: DONE — AWAITING REVIEW
Started: 2026-11-12T00:00
Finished: 2026-11-12T17:30

Owned files:
- `tests/test_controls.gd` (new) and `tests/test_controls.tscn` (new)
- any existing `tests/*.gd` that needs updating because of A–D (only after reading Cross-Agent Requests)
- `CLAUDE.md`: **INPUT CONTRACT section only**

Tasks:
- [x] E1. Write `tests/test_controls.gd`, following the pattern of `tests/test_phase15.gd`. It should assert against InputMap at runtime:
  - `tactical_mode` has joy button 0 and no axis-4 event, and has key Q.
  - `jump` has joy 3 and Space, and no joy 0.
  - `interact` has key E and no joypad events.
  - `target_switch_left` has joy 13, `target_switch_right` has joy 14.
  - `party_switch` has joy 11 and 12.
  - `lock_on` has axis 5. `attack` has joy 2. `dodge` has joy 1. `pause` has joy 6. `camera_reset` has joy 8.
  - No joypad button is bound to two gameplay actions (except the documented A overlap with `ui_accept`).
- [x] E2. Source-level assertions:
  - The menu scripts from Package B contain no `is_action_pressed(&"jump")`.
  - `tactical_idle_state.gd` has no `jump` confirm.
  - `party_system.gd` handles `party_switch`.
  - `settings_manager.gd` has `BINDINGS_VERSION`.
- [x] E3. Runtime test (if feasible headless): instance the player in tactical mode and simulate an `ui_accept` press on the opening frame. Assert the phase is still CATEGORY_SELECT. Mark N/A with the reason if headless instancing isn't feasible.
- [x] E4. Find out how `tests/test_runner.tscn` / `test_smoke.gd` aggregates suites, and register `test_controls` the same way.
- [x] E5. Update existing tests broken by A–D. Only change assertions about bindings or source; never weaken an unrelated test.
- [x] E6. `CLAUDE.md` INPUT CONTRACT → Xbox Controller:
  - Change "Jump -> A" to "Jump -> Y".
  - Change "Interact -> Y" to "Interact -> A (contextual, outside combat)".
  - Change "Tactical Menu -> Left Trigger" to "Tactical/Command Menu -> A".
  - Add "Menu confirm -> A / Menu back -> B", "Target switch -> D-pad Left/Right", "Character switch -> D-pad Up/Down", and "RB/LB reserved (Guard / Shortcuts)".
  - Do NOT tick checkboxes. Head agent does that after verification.
- [x] E7. When A–D are all DONE, run the full suite: `Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn` plus `tests/test_controls.tscn`. Paste the pass/fail counts into the Handoff Notes.

Handoff Notes:
- **New files:** `tests/test_controls.gd` and `tests/test_controls.tscn`. Same pattern as test_phase15: a standalone scene whose root Node runs the suite, prints `=== Controls Results: P passed, F failed, T total ===`, and quits 1 on any failure. No class_name, so no import was needed.
- **E4 registration:** `test_runner.tscn` runs only `test_smoke.gd` (script-load smoke checks). It does not aggregate the phase suites. Each phase is its own `tests/test_phaseN.tscn`, and `run-tests.bat` runs only test_runner. test_controls is registered the same way as the phase suites: run it with `Z:/godot/godot.exe --path . --headless --scene res://tests/test_controls.tscn`. test_smoke.gd and run-tests.bat were not changed.
- **test_controls coverage (102 assertions):**
  - InputMap at runtime: tactical_mode = joy0 + Q, no axis 4. jump = joy3 + Space, no joy0. interact = E only, no joypad events. target_switch = joy13/14 plus `[`/`]`, without the old 14/15 bug. party_switch = joy11/12 + Tab. lock_on = axis5, attack = joy2, dodge = joy1, pause = joy6, camera_reset = joy8. LB/RB/LT unbound. ui_accept has joy0 and ui_cancel has joy1. No joypad button is shared by two non-`ui_*` actions.
  - Source: all 6 Package B menus have no jump/dodge `is_action*` checks and do use ui_accept. Dialogue uses ui_accept + interact + set_input_as_handled. tactical_idle has no jump, uses ui_accept, ui_cancel and pause, and tactical_mode closes only with InputEventKey. player.gd has the `is_in_combat` computed getter, combat signal hookups, has_interactable/try_interact, and E interact. The 4 locomotion states apply contextual A. party_system has `_unhandled_input` + party_switch + switch_member_battle, `const INPUT_SWITCH_ENABLED := false` as the first statement of `_unhandled_input`, and SWITCH_COOLDOWN. settings_manager has `BINDINGS_VERSION := 2` and get_action_label. control_bar has get_action_label and COMMAND, with no TACTICAL and no "LT". interaction_prompt has no "[Y]".
  - Runtime labels: get_action_label(tactical_mode, pad) = "A", (jump, pad) = "Y", and the keyboard tactical label contains Q.
  - Runtime tactical (E3, done with the real tactical_idle_state.gd on a stub CharacterBody3D, so the full player is not needed): an opening-frame A leaves CATEGORY_SELECT. After release + process_physics, A goes to ABILITY_SELECT. A in ABILITY_SELECT does not close. B backs out exactly one level, with no dodge/ui_cancel double-fire. B at top closes to LockOnIdle (lock-on kept). Time scale is restored. Start closes. Key Q closes. GameManager is back to PLAYING.
  - Runtime contextual A (real player.tscn instance + stub interactable): out of combat, A interacts and is consumed. Key Q never interacts. Events.combat_started makes A open the menu. combat_ended clears it. With no interactable, A opens the menu. is_in_combat is never assigned (read-only).
  - Runtime party gate (D's request): can_switch_from_input() is true in PLAYING with 2 members, and false in TACTICAL_MODE, PAUSED and CUTSCENE. GameManager state is restored afterwards.
- **E5, existing tests changed (assertions only):**
  - test_phase8 `test_main_menu_handles_controller_confirm`: now requires ui_accept and no jump press (B4).
  - test_phase8 `test_pause_menu_dodge_cancels`: now requires ui_cancel and no dodge press (B2).
  - test_phase8 `test_pause_menu_attack_confirms`, test_phase10 `test_quest_log_controller_nav` and test_phase11 `test_save_load_menu_controller_nav`: `"attack"` changed to `"ui_accept"`, per B's request. These were already failing at HEAD, because no menu ever used attack.
  - test_phase10 `test_dialogue_supports_controller_advance`: tightened to ui_accept, with no jump press.
  - test_phase12 `test_world_nav_controller`: label text only (Y changed to contextual A).
  - test_phase14 `test_controller_prompts_readable`: now expects `[A]` and no `"[Y]"`. **This fails until interaction_prompt.gd is fixed (see Cross-Agent Requests).**
- **E6:** CLAUDE.md INPUT CONTRACT → Xbox Controller updated as specified. No checkboxes were ticked.
- **E7 results (2026-11-12T17:30, after A–D DONE and the head agent's review edits):** headless boot exit 0.

  | Suite | Pass | Fail | Total | Failures |
  |---|---|---|---|---|
  | test_runner (smoke) | 35 | 0 | 35 | |
  | **test_controls** | 101 | 1 | 102 | NEW: interaction prompt still `[Y]` |
  | test_phase6 | 110 | 1 | 111 | PRE-EXISTING: `_navigate_slot` (test_phase6.gd:377) |
  | test_phase7 | 23 | 0 | 23 | |
  | test_phase8 | 64 | 1 | 65 | PRE-EXISTING: New Game loads test arena |
  | test_phase9 | 55 | 1 | 56 | PRE-EXISTING: tactical_menu.gd has no `Category.ITEMS` (also absent at HEAD) |
  | test_phase10 | 72 | 0 | 72 | |
  | test_phase11 | 63 | 0 | 63 | |
  | test_phase12 | 64 | 1 | 65 | PRE-EXISTING: field/dungeon return portals |
  | test_phase13 | 64 | 0 | 64 | |
  | test_phase14 | 66 | 1 | 67 | NEW: interaction prompt still `[Y]` (same root cause) |
  | test_phase15 | 68 | 0 | 68 | |
  | test_performance | 64 | 1 | 65 | PRE-EXISTING: 8 autoloads vs expected 7 |

  The test_controls numbers are from the final re-run after the review-edit test updates. The only new failure is the `[Y]` interaction prompt, and it has one root cause in an unowned file.

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`

-
- [from D → to E] No existing tests break from Package D. `test_phase13.gd` `test_party_system_switch_member`, `test_party_switch_emits_signal` and `test_party_switch_input_defined` still match. For E2, `party_system.gd` contains `_unhandled_input`, `is_action_pressed(&"party_switch")`, `SWITCH_COOLDOWN` and the public `can_switch_from_input()`. Optional runtime test: in a scene with the party initialized (2 members) and `GameManager.current_state = PLAYING`, `can_switch_from_input()` should be true. Set the state to `TACTICAL_MODE` / `PAUSED` / `CUTSCENE` and it should be false. — DONE (E): source + runtime gate tests are in test_controls. Per the head agent's review, the suite also asserts that `INPUT_SWITCH_ENABLED := false` gates `_unhandled_input`, and it does not assert that a press switches members.
- **[from B → to A / Head] BLOCKER: Godot 4.6's built-in `ui_accept` / `ui_cancel` have NO joypad events.** The plan assumed they include A/B. Runtime InputMap dump in this project (no `ui_*` overrides in project.godot): `ui_accept` = Enter, Kp Enter, Space. `ui_cancel` = Escape. `ui_select` = joy3, Space. Without a fix, controller A/B do nothing in any menu, and the same goes for tactical confirm/back in Package C. Request: add `ui_accept` and `ui_cancel` overrides to the `[input]` section of project.godot. A project override REPLACES the defaults, so the keys must be listed again. `ui_accept`: Enter, Kp Enter, Space and JoypadButton 0. `ui_cancel`: Escape and JoypadButton 1. Joy 0 then overlaps `tactical_mode` (documented in the design), and joy 1 overlaps `dodge`, as intended. — DONE (A, 2026-11-12T16:52): added `ui_accept` (project.godot:116) = Enter, Kp Enter, Space, joy 0, and `ui_cancel` (:120) = Escape, joy 1, both with deadzone 0.5. Verified with a runtime dump. ui_up/down/left/right already had arrows, D-pad 11/12/13/14 and left-stick axis 1∓/0∓ by default, so they were not overridden. `ui_select` (joy 3/Space) was left at the default.
- [from B → to E] Package B causes 2 test_phase8 failures, both from source greps that look for the removed actions. (1) `test_main_menu_handles_controller_confirm` (test_phase8.gd:235) requires `"jump"` or `"interact"` in main_menu.gd. It should assert `"ui_accept"` and that `"jump"` is absent. (2) `test_pause_menu_dodge_cancels` (test_phase8.gd:~330) requires `"dodge"`. It should assert `"ui_cancel"` and that `"dodge"` is absent. Already failing at HEAD before Package B, each requiring `"attack"`, which no menu has ever used: `test_pause_menu_attack_confirms` (test_phase8), `test_quest_log_controller_nav` (test_phase10.gd:506) and `test_save_load_menu_controller_nav` (test_phase11.gd:~314). Suggest changing them to `"ui_accept"`. Also failing at HEAD and unrelated: test_phase8 "New Game loads test arena scene" (main_menu goes to town_hub). test_phase10 dialogue tests still pass. — DONE (E): all five changed as suggested (phase8 x3, phase10 quest log, phase11 save/load). "New Game loads test arena" was left alone because it is unrelated to the remap.
- [from B → to C] (FYI) dialogue_ui marks every `ui_accept`/`interact` event as handled while dialogue is active. That only shields gameplay when dialogue_ui's `_unhandled_input` runs before the player's. Please make the contextual-A / `tactical_mode` handler in the locomotion states ignore input while `get_tree().get_first_node_in_group(&"dialogue_ui")` reports `is_dialogue_active()`, or the GameManager state is not PLAYING. Otherwise A during dialogue could open the Command Menu. dialogue_ui already ignores advance input on the frame it opened, so the opening press can't skip page 1 regardless of dispatch order. — DONE (C): `player.handle_contextual_command()` (player.gd:368) consumes every `tactical_mode` press, Q included, while any `dialogue_ui` reports `is_dialogue_active()`. It doesn't mark the event handled, so DialogueUI still advances. `Player._unhandled_input` E also skips while dialogue is active. A PAUSED state pauses the tree, so the states get no input then. TACTICAL_MODE means the player is already in TacticalIdle.
- [from C → to Head / owner of enemy or encounter code] `Events.combat_started` / `Events.combat_ended` are declared but never emitted anywhere. `player.is_in_combat` (player.gd:47) is wired to them but stays false, so contextual A always interacts when an interactable is in range, even mid-fight. Request: emit these from an encounter/aggro owner (for example on the first `enemy_aggro_triggered` and when the last aggro'd enemy dies or de-aggros). This is outside Package C's files. — DONE (Head): `is_in_combat` is now a computed property: signal flag OR any EnemyBase in group `enemies` with ai_state not IDLE/DEAD. Covered by test_controls (4 new asserts).
- [from C → to E] No existing test breaks from Package C. test_phase10.gd:236 (`is_action_pressed(&"interact")` + `.interact(self)` in player.gd) and test_phase7.gd:168/180 (`tactical_mode` + `return &"TacticalIdle"`) still match. test_phase6.gd:377 (`_navigate_slot`) already fails at HEAD and is unrelated. For E2: tactical_idle_state.gd has no `"jump"`. It has `_confirm_armed`, `_is_confirm_event`, `_is_close_event` (with `event is InputEventKey`) and `_is_back_event`. The states contain `handle_contextual_command`. For E3: after `enter()`, a synthetic `ui_accept` (or a joypad `tactical_mode`) press must leave `_phase == Phase.CATEGORY_SELECT` (0). Call `process_physics(0.0)` with no actions held, and the next `ui_accept` press should move to ABILITY_SELECT (1). A joypad `tactical_mode` press in the menu must not return `&"Idle"`. A key-Q press must return `&"Idle"`/`&"LockOnIdle"`. — DONE (E): all of these are covered in test_controls `test_tactical_open_press_guard`.
- [from E → to Head] `src/ui/hud/interaction_prompt.gd:93` still shows `"[Y]"` on controller. Y is now Jump, and controller interact is contextual A. No package owns this file. Request: change it to `"[A]"`. test_phase14 `test_controller_prompts_readable` and test_controls `test_interaction_prompt_not_y` both fail until this is fixed. — DONE (Head): changed to `"[A]"` (interaction_prompt.gd:93).

---

## Head Agent Review (Wave 3)
Status: DONE except H8–H10 (waiting on the user's controller test)
Reviewed: 2026-11-12

- [x] H1. All packages DONE; all Cross-Agent Requests resolved.
- [x] H2. Diffs reviewed. Agents stayed inside their owned files. Head edits: player.gd (combat flag), party_system.gd (INPUT_SWITCH_ENABLED gate), interaction_prompt.gd ([A] hint), test_controls.gd (enemy combat test).
- [x] H3. Runtime InputMap dump matches the Approved Design: tactical_mode Q/joy0, jump Space/joy3, interact E, attack LMB/joy2, dodge Shift/joy1, lock_on MMB/axis5, target_switch joy13/joy14 + [/], party_switch Tab/joy11/joy12, camera_reset joy8, pause Esc/joy6, ui_accept Enter/KpEnter/Space/joy0, ui_cancel Esc/joy1.
- [x] H4. No menu or tactical code uses jump/dodge as confirm (tactical keeps dodge only as a keyboard Shift back). Control bar is label-driven.
- [x] H5. Headless boot exit 0.
- [x] H6. test_runner 35/35, test_controls 106/106, phase7/10/11/13/14/15 all pass. Five failures that predate this work were checked against HEAD: phase6 `_navigate_slot`, phase8 New Game→test_arena (main menu loads town_hub at HEAD), phase9 `Category.ITEMS`, phase12 return portals, performance autoload count 7 vs 8.
- [x] H7. Verification: player.tscn scene tree, state scripts and signal connections checked (see the head agent's report).
- [ ] H8. User controller test (checklist below).
- [ ] H9. Tick INPUT CONTRACT boxes + update project_status.json, after H8 passes.
- [ ] H10. Commit, when the user approves.

Review Notes:
- Party switch input is wired but gated OFF (`INPUT_SWITCH_ENABLED := false`) because switch_member() is a flag-only stub. Enabling it now would mis-target ally commands and corrupt save data. Re-enable once control transfer exists (Phase 18, items 456–460).
- Open-press guard is armed on a physics tick. At 0.1x time scale the arming delay is about 1–2 frames of real input. If hit-stop sets time_scale to 0 while the menu is open, confirm waits until hit-stop ends.
- Agent A's boot already migrated the user's settings.json (bindings_version 2; other settings preserved).
