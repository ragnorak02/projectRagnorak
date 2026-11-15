## Controller layout tests, v3 (Battle System v3: Free Roam / Battle modes).
## Spec: docs/plans/battle_system_v3_plan.md -> "Approved Design" (v2 spec:
## docs/plans/controls_v2_carry_plan.md, v1: controller_remap_plan.md).
## v3 physical-role InputMap: jump = A + Space, interact = Y + E, dodge = B +
## Shift, attack = X + LMB, sprint = L3 + Ctrl, tactical_mode = Q only,
## unique_ability = R only. LB / RB / LT unbound. Controller Command access is
## routed by player.is_command_press(): A in battle, Y with no prompt in free roam.
## Covers: InputMap v3 bindings, menu / tactical source contracts, routing
## helpers, party-switch wiring, bindings versioning (5), v4 battle_toggle, control hints / prompt
## labels, and FREE-ROAM runtime checks: tactical menu, v8 context button (A
## interacts with a prompt, jumps without one; Y always opens the Command Menu),
## A never interacts outside PLAYING, B never interacts, double jump on A,
## sprint, no-target spell (v4: target step with Fire Forward only). Battle-mode routing lives in tests/test_battle.gd.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

## Joypad button indices (Godot JoyButton enum).
const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_BACK := 4
const JOY_START := 6
const JOY_L3 := 7
const JOY_R3 := 8
const JOY_LB := 9
const JOY_RB := 10
const JOY_DPAD_UP := 11
const JOY_DPAD_DOWN := 12
const JOY_DPAD_LEFT := 13
const JOY_DPAD_RIGHT := 14
const JOY_AXIS_LT := 4
const JOY_AXIS_RT := 5

## Documented joypad overlaps between a gameplay action and a ui_* action.
## Any other gameplay/ui_accept/ui_cancel overlap is a bug.
const ALLOWED_UI_OVERLAPS := {
	&"ui_accept": [&"jump"],   # A = Jump (free roam) / Command (battle, routed) / Confirm
	&"ui_cancel": [&"dodge"],  # B = Dodge / Back
}

## Menu scripts: must never use jump/dodge for confirm/back.
const MENU_SCRIPTS: Array[String] = [
	"res://src/ui/menus/pause_menu.gd",
	"res://src/ui/menus/quest_log.gd",
	"res://src/ui/menus/save_load_menu.gd",
	"res://src/ui/menus/settings_menu.gd",
	"res://scenes/menus/main_menu.gd",
	"res://src/ui/dialogue/dialogue_ui.gd",
]

## Free-locomotion states that open the Command Menu through the routing helper
## player.is_command_press() (Q either mode, A in battle, Y with no prompt).
const COMMAND_STATES: Array[String] = [
	"res://src/player/states/idle_state.gd",
	"res://src/player/states/run_state.gd",
	"res://src/player/states/lock_on_idle_state.gd",
	"res://src/player/states/lock_on_strafe_state.gd",
]

## v3 T2: the Command Menu also opens while airborne.
const AIRBORNE_COMMAND_STATES: Array[String] = [
	"res://src/player/states/jump_state.gd",
	"res://src/player/states/fall_state.gd",
	"res://src/player/states/land_state.gd",
]

const TACTICAL_STATE := "res://src/player/states/tactical_idle_state.gd"
const PLAYER_SCENE := "res://src/player/player.tscn"

## Shared test world (floor + camera) for runtime player tests.
var _world: Node3D = null


func _ready() -> void:
	print("=== Controls v3 Tests (A Jump, Y Interact/Command, B Dodge, Q/R keyboard) ===")
	print("")
	# Watchdog: a hung/aborted runtime test must not hang the runner.
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within 120s (a test hung or aborted)")
		print("
=== Controls Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
		get_tree().quit(1))
	await _run_tests()
	print("\n=== Controls Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: InputMap bindings (J1)
	_section("INPUT MAP — XBOX LAYOUT v3")
	test_tactical_mode_binding()
	test_unique_ability_binding()
	test_jump_binding()
	test_interact_binding()
	test_dodge_binding()
	test_sprint_binding()
	test_target_switch_bindings()
	test_party_switch_binding()
	test_battle_toggle_binding()
	test_unchanged_bindings()
	test_reserved_buttons_unbound()
	test_ui_accept_cancel_defaults()
	test_no_duplicate_joy_buttons()
	test_ui_overlaps_documented_only()

	# Category 2: Source contracts
	_section("SOURCE CONTRACTS")
	test_menus_no_jump_confirm()
	test_menus_no_dodge_back()
	test_menus_use_ui_accept()
	test_dialogue_advance_actions()
	test_tactical_no_jump_confirm()
	test_tactical_no_dodge_back()
	test_tactical_mode_close_is_keyboard_only()
	test_tactical_pause_closes()
	test_player_interact_api()
	test_player_routing_api()
	test_states_no_contextual_rule()
	test_states_use_jump_routing()
	test_airborne_states_command_routing()
	test_double_jump_unlocked_source()
	test_sprint_source()
	test_party_system_handles_party_switch()
	test_party_system_switch_cooldown()
	test_settings_manager_bindings_version()
	test_settings_manager_action_label()
	test_settings_sprint_rebindable()
	test_control_bar_v3_hints()
	test_interaction_prompt_uses_label()

	# Category 3: Runtime labels / prompts
	_section("RUNTIME LABELS & PROMPTS")
	test_runtime_action_labels()
	await test_runtime_interaction_prompt()

	_world = _make_world()
	add_child(_world)
	await get_tree().physics_frame

	# Category 4: Runtime tactical menu
	_section("RUNTIME — TACTICAL MENU")
	await test_tactical_open_press_guard()

	# Category 5: Free roam: A jumps; Y interacts with a prompt, else Command Menu
	_section("RUNTIME — FREE ROAM: A JUMPS / Y INTERACT OR COMMAND")
	await test_free_roam_a_y_routing_runtime()
	await test_y_interact_guard_runtime()

	# Category 6: Locomotion (J2)
	_section("RUNTIME — DOUBLE JUMP (A)")
	await test_double_jump_runtime()

	_section("RUNTIME — SPRINT")
	await test_sprint_runtime()

	# Category 7: Spell with no target (J2)
	_section("RUNTIME — CONTROL BAR HINTS (v3)")
	await test_control_bar_runtime()

	_section("RUNTIME — SPELL WITH NO TARGET")
	await test_no_target_spell_runtime()

	_world.queue_free()
	_world = null
	await get_tree().process_frame

	# Category 8: Runtime party-switch gating
	_section("RUNTIME — PARTY SWITCH GATE")
	test_party_switch_gate_runtime()


# ========== CATEGORY 1: INPUT MAP ==========

func test_tactical_mode_binding() -> void:
	# v3: Q only. Controller Command access is routed (A in battle, Y with no
	# prompt in free roam) through player.is_command_press().
	_assert(InputMap.has_action(&"tactical_mode"), "tactical_mode action exists")
	_assert(_joy_events(&"tactical_mode").is_empty(), "tactical_mode has no joypad binding (Q only; controller is routed)",
		"got %d joypad events" % _joy_events(&"tactical_mode").size())
	_assert(not _has_joy_button(&"tactical_mode", JOY_A), "tactical_mode no longer bound to A (joy 0)")
	_assert(not _has_joy_axis(&"tactical_mode", JOY_AXIS_LT), "tactical_mode not bound to LT (axis 4)")
	_assert(_has_key(&"tactical_mode", KEY_Q), "tactical_mode keeps keyboard Q")


func test_unique_ability_binding() -> void:
	# v3: R only. Controller access is routed (Y in battle).
	_assert(InputMap.has_action(&"unique_ability"), "unique_ability action exists")
	_assert(_has_key(&"unique_ability", KEY_R), "unique_ability bound to keyboard R")
	_assert(_joy_events(&"unique_ability").is_empty(), "unique_ability has no joypad binding (Y in battle is routed)",
		"got %d joypad events" % _joy_events(&"unique_ability").size())


func test_jump_binding() -> void:
	# v3: A = jump (free roam). Keep it a single joypad binding.
	_assert(_has_joy_button(&"jump", JOY_A), "jump bound to A (joy 0)")
	_assert(not _has_joy_button(&"jump", JOY_Y), "jump no longer bound to Y (joy 3)")
	_assert(_joy_events(&"jump").size() == 1, "jump has exactly one joypad binding (easy to change)",
		"got %d" % _joy_events(&"jump").size())
	_assert(_has_key(&"jump", KEY_SPACE), "jump keeps keyboard Space")


func test_interact_binding() -> void:
	_assert(_has_joy_button(&"interact", JOY_Y), "interact bound to Y (joy 3)")
	_assert(_has_key(&"interact", KEY_E), "interact keeps keyboard E")
	_assert(not _has_joy_button(&"interact", JOY_A), "interact not on A (A is jump / battle command)")
	_assert(not _has_joy_button(&"interact", JOY_B), "interact no longer on B (B = dodge / back)")
	_assert(_joy_events(&"interact").size() == 1, "interact has exactly one joypad binding",
		"got %d" % _joy_events(&"interact").size())


func test_dodge_binding() -> void:
	_assert(_has_joy_button(&"dodge", JOY_B), "dodge bound to B (joy 1)")
	_assert(not _has_joy_button(&"dodge", JOY_LB), "dodge no longer bound to LB (joy 9)")
	_assert(_has_key(&"dodge", KEY_SHIFT), "dodge keeps keyboard Shift")


func test_sprint_binding() -> void:
	_assert(InputMap.has_action(&"sprint"), "sprint action exists")
	_assert(_has_joy_button(&"sprint", JOY_L3), "sprint bound to L3 (joy 7)")
	_assert(_has_key(&"sprint", KEY_CTRL), "sprint bound to Left Ctrl")


func test_target_switch_bindings() -> void:
	_assert(_has_joy_button(&"target_switch_left", JOY_DPAD_LEFT), "target_switch_left bound to D-pad Left (joy 13)")
	_assert(_has_joy_button(&"target_switch_right", JOY_DPAD_RIGHT), "target_switch_right bound to D-pad Right (joy 14)")
	_assert(not _has_joy_button(&"target_switch_left", JOY_DPAD_RIGHT), "target_switch_left not on joy 14 (old bug)")
	_assert(not _has_joy_button(&"target_switch_right", 15), "target_switch_right not on joy 15 / Share (old bug)")
	_assert(_has_key(&"target_switch_left", KEY_BRACKETLEFT), "target_switch_left keeps [ key")
	_assert(_has_key(&"target_switch_right", KEY_BRACKETRIGHT), "target_switch_right keeps ] key")


func test_party_switch_binding() -> void:
	_assert(_has_joy_button(&"party_switch", JOY_DPAD_UP), "party_switch bound to D-pad Up (joy 11)")
	_assert(_has_joy_button(&"party_switch", JOY_DPAD_DOWN), "party_switch bound to D-pad Down (joy 12)")
	_assert(_has_key(&"party_switch", KEY_TAB), "party_switch keeps Tab")


## v4 W: battle_toggle = View/Back (joy 4) + F; rebindable; the only joy-4 user.
func test_battle_toggle_binding() -> void:
	_assert(InputMap.has_action(&"battle_toggle"), "battle_toggle action exists (v4)")
	_assert(_has_joy_button(&"battle_toggle", JOY_BACK), "battle_toggle bound to View/Back (joy 4)")
	_assert(_has_key(&"battle_toggle", KEY_F), "battle_toggle bound to F")
	var back_users := _gameplay_actions_with_joy_button(JOY_BACK)
	_assert(back_users == ["battle_toggle"], "View/Back (joy 4) drives only battle_toggle", str(back_users))
	_assert(not _has_joy_axis(&"battle_toggle", JOY_AXIS_LT), "battle_toggle is not on LT (LT stays reserved)")
	_assert(&"battle_toggle" in SettingsManager.REBINDABLE_ACTIONS,
		"battle_toggle is in SettingsManager.REBINDABLE_ACTIONS")
	_assert(SettingsManager.get_action_label(&"battle_toggle", true) == "View",
		"Controller label for battle_toggle is View (v5 AA5)", SettingsManager.get_action_label(&"battle_toggle", true))
	_assert(SettingsManager.get_action_label(&"battle_toggle", false).contains("F"),
		"Keyboard label for battle_toggle contains F", SettingsManager.get_action_label(&"battle_toggle", false))
	var menu_src := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(menu_src.contains('"action": "battle_toggle"'), "Settings menu has a keybind row for battle_toggle")
	var player_src := _get_source("res://src/player/player.gd")
	_assert(player_src.contains("func is_battle_toggle_press(") and player_src.contains("func can_toggle_battle("),
		"Player exposes is_battle_toggle_press() / can_toggle_battle()")
	var bm_src := _get_source("res://src/combat/battle_mode_component.gd")
	_assert(bm_src.contains("func toggle_manual(") and bm_src.contains("var is_suppressed")
			and bm_src.contains("var is_manual_hold"),
		"BattleModeComponent exposes toggle_manual() / is_suppressed / is_manual_hold")


func test_unchanged_bindings() -> void:
	_assert(_has_joy_axis(&"lock_on", JOY_AXIS_RT), "lock_on bound to RT (axis 5)")
	_assert(_has_joy_button(&"attack", JOY_X), "attack bound to X (joy 2)")
	_assert(_has_joy_button(&"pause", JOY_START), "pause bound to Start (joy 6)")
	_assert(_has_joy_button(&"camera_reset", JOY_R3), "camera_reset bound to R3 (joy 8)")


func test_reserved_buttons_unbound() -> void:
	# v3: LB, RB and LT are all unbound (reserved: shortcuts, guard, ally commands).
	var lb_users := _gameplay_actions_with_joy_button(JOY_LB)
	_assert(lb_users.is_empty(), "LB (joy 9) unbound (reserved)", str(lb_users))
	var rb_users := _gameplay_actions_with_joy_button(JOY_RB)
	_assert(rb_users.is_empty(), "RB (joy 10) unbound (reserved)", str(rb_users))
	var lt_users: Array[String] = []
	for action in _gameplay_actions():
		if _has_joy_axis(action, JOY_AXIS_LT):
			lt_users.append(str(action))
	_assert(lt_users.is_empty(), "LT (axis 4) unbound on controller", str(lt_users))
	var l3_users := _gameplay_actions_with_joy_button(JOY_L3)
	_assert(l3_users.size() == 1 and l3_users[0] == "sprint", "L3 (joy 7) drives only sprint", str(l3_users))


func test_ui_accept_cancel_defaults() -> void:
	# Menus rely on ui_accept (A) / ui_cancel (B).
	_assert(_has_joy_button(&"ui_accept", JOY_A), "ui_accept includes A (joy 0)")
	_assert(_has_joy_button(&"ui_cancel", JOY_B), "ui_cancel includes B (joy 1)")


func test_no_duplicate_joy_buttons() -> void:
	# No joypad button may drive two gameplay actions.
	var owners: Dictionary = {}
	for action in _gameplay_actions():
		for ev in _joy_events(action):
			if ev is InputEventJoypadButton:
				var idx: int = ev.button_index
				if not owners.has(idx):
					owners[idx] = []
				if not owners[idx].has(str(action)):
					owners[idx].append(str(action))
	var dupes: Array[String] = []
	for idx in owners:
		if owners[idx].size() > 1:
			dupes.append("joy %d -> %s" % [idx, ", ".join(owners[idx])])
	_assert(dupes.is_empty(), "No joypad button bound to two gameplay actions", "; ".join(dupes))


func test_ui_overlaps_documented_only() -> void:
	# The only gameplay/menu overlaps allowed: A = jump + ui_accept,
	# B = dodge + ui_cancel.
	for ui_action: StringName in ALLOWED_UI_OVERLAPS:
		var overlapping: Array[StringName] = []
		for ev in _joy_events(ui_action):
			if not (ev is InputEventJoypadButton):
				continue
			for action in _gameplay_actions():
				if _has_joy_button(action, ev.button_index) and not overlapping.has(action):
					overlapping.append(action)
		var expected: Array = ALLOWED_UI_OVERLAPS[ui_action]
		var ok := overlapping.size() == expected.size()
		for a in expected:
			ok = ok and overlapping.has(a)
		_assert(ok, "%s overlaps only %s on joypad" % [ui_action, str(expected)], str(overlapping))


# ========== CATEGORY 2: SOURCE CONTRACTS ==========

func test_menus_no_jump_confirm() -> void:
	for path in MENU_SCRIPTS:
		var source := _get_source(path)
		_assert(source != "" and not _uses_action(source, "jump"),
			"%s does not listen to jump" % path.get_file())


func test_menus_no_dodge_back() -> void:
	for path in MENU_SCRIPTS:
		var source := _get_source(path)
		_assert(source != "" and not _uses_action(source, "dodge"),
			"%s does not listen to dodge" % path.get_file())


func test_menus_use_ui_accept() -> void:
	for path in MENU_SCRIPTS:
		var source := _get_source(path)
		_assert(_uses_action(source, "ui_accept"),
			"%s confirms with ui_accept" % path.get_file())


func test_dialogue_advance_actions() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(_uses_action(source, "ui_accept"),
		"DialogueUI advances on ui_accept (A/Enter)")
	_assert(source.contains("set_input_as_handled"),
		"DialogueUI consumes its input (no leak into gameplay interact)")


func test_tactical_no_jump_confirm() -> void:
	var source := _get_source(TACTICAL_STATE)
	_assert(source != "" and not _uses_action(source, "jump"),
		"tactical_idle_state.gd has no jump confirm")
	_assert(_uses_action(source, "ui_accept"),
		"tactical_idle_state.gd confirms with ui_accept")


func test_tactical_no_dodge_back() -> void:
	var source := _get_source(TACTICAL_STATE)
	_assert(_uses_action(source, "ui_cancel"),
		"tactical_idle_state.gd backs out with ui_cancel")
	_assert(source.contains("set_input_as_handled"),
		"tactical_idle_state.gd consumes back input (B = ui_cancel never also dodges)")


func test_tactical_mode_close_is_keyboard_only() -> void:
	# A = confirm inside the menu, so a tactical_mode press may only close it
	# when it comes from the keyboard (Q). v3: tactical_mode has no joypad
	# binding at all; the source either checks InputEventKey or relies on that.
	var source := _get_source(TACTICAL_STATE)
	var uses_tactical := _uses_action(source, "tactical_mode")
	_assert(not uses_tactical or source.contains("InputEventKey") or _joy_events(&"tactical_mode").is_empty(),
		"tactical_mode closes the menu only for keyboard events (Q; A never toggles it)")
	# T3: the v2 "non-key tactical_mode = confirm" path is gone; confirm is ui_accept only.
	_assert(not source.contains("not (event is InputEventKey)") and not source.contains("not event is InputEventKey"),
		"tactical_idle_state.gd has no non-key tactical_mode confirm path (T3)")


func test_tactical_pause_closes() -> void:
	var source := _get_source(TACTICAL_STATE)
	_assert(_uses_action(source, "pause"),
		"Start / Esc (pause) closes the tactical menu")


func test_player_interact_api() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("func has_interactable(") and source.contains("func try_interact("),
		"Player exposes has_interactable() and try_interact()")
	_assert(source.contains("func _unhandled_input(") and _uses_action(source, "interact"),
		"Player handles interact (Y / E) in _unhandled_input")
	_assert(source.contains("is_interact_press(event)") and source.contains("can_interact_now()"),
		"Player _unhandled_input interacts through is_interact_press() + can_interact_now()")
	_assert(source.contains("GameState.PLAYING"),
		"Player interact path is guarded on GameManager PLAYING")


func test_player_routing_api() -> void:
	# v3 routing helpers (Package Q): every state uses these, none hardcodes modes.
	var source := _get_source("res://src/player/player.gd")
	for fn in ["is_command_press", "is_jump_press", "is_interact_press", "is_unique_press",
			"request_transition", "get_member_data"]:
		_assert(source.contains("func %s(" % fn), "Player exposes %s()" % fn)
	_assert(source.contains("var in_battle: bool:") and source.contains("battle_mode.in_battle"),
		"player.in_battle is a read-only getter backed by BattleModeComponent")


func test_states_no_contextual_rule() -> void:
	# v3: locomotion states open the Command Menu only through the routing helper
	# (no raw tactical_mode check, no direct interacting, no deprecated v2 shim).
	for path in COMMAND_STATES:
		var source := _get_source(path)
		_assert(source.contains("is_command_press(") and not source.contains("try_interact")
				and not source.contains("has_interactable"),
			"%s opens the Command Menu via player.is_command_press() without interacting" % path.get_file())
		_assert(not source.contains("handle_contextual_command"),
			"%s no longer calls the deprecated handle_contextual_command()" % path.get_file())
		_assert(not _uses_action(source, "tactical_mode"),
			"%s does not hardcode tactical_mode (routing helper owns it)" % path.get_file())


func test_states_use_jump_routing() -> void:
	# v3: A = jump in free roam only. A state that checks the raw `jump` action
	# would jump in battle, so jumping goes through player.is_jump_press().
	var paths: Array[String] = []
	paths.append_array(COMMAND_STATES)
	paths.append_array(AIRBORNE_COMMAND_STATES)
	for path in paths:
		var source := _get_source(path)
		_assert(source != "" and not _uses_action(source, "jump"),
			"%s does not check the raw jump action (uses is_jump_press)" % path.get_file())
	for path in ["res://src/player/states/idle_state.gd", "res://src/player/states/run_state.gd",
			"res://src/player/states/fall_state.gd"]:
		_assert(_get_source(path).contains("is_jump_press("),
			"%s jumps via player.is_jump_press()" % path.get_file())


func test_airborne_states_command_routing() -> void:
	# v3 T2: the Command Menu opens from Jump, Fall and Land.
	for path in AIRBORNE_COMMAND_STATES:
		var source := _get_source(path)
		_assert(source.contains("is_command_press(") and source.contains("TacticalIdle"),
			"%s opens the Command Menu (airborne) via is_command_press()" % path.get_file())


func test_double_jump_unlocked_source() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("var has_double_jump: bool = true") or source.contains("var has_double_jump := true"),
		"player.has_double_jump defaults to true (unlocked for now, item 481)")


func test_sprint_source() -> void:
	var run_src := _get_source("res://src/player/states/run_state.gd")
	_assert(run_src.contains("sprint_multiplier") and run_src.contains("sprint"),
		"run_state.gd applies sprint_multiplier while sprint is held")
	var strafe_src := _get_source("res://src/player/states/lock_on_strafe_state.gd")
	_assert(strafe_src != "" and not strafe_src.contains("sprint"),
		"lock_on_strafe_state.gd does not sprint (free locomotion only)")
	var tactical_src := _get_source(TACTICAL_STATE)
	_assert(not tactical_src.contains("sprint"),
		"tactical_idle_state.gd does not sprint")
	var player_src := _get_source("res://src/player/player.gd")
	_assert(player_src.contains("is_sprinting"),
		"Player exposes is_sprinting")


func test_party_system_handles_party_switch() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func _unhandled_input(") and _uses_action(source, "party_switch"),
		"PartySystem handles party_switch input in _unhandled_input")
	_assert(source.contains("switch_member_battle()"),
		"party_switch handler routes to switch_member_battle()")
	_assert(source.contains("const INPUT_SWITCH_ENABLED := true"),
		"Party switch input enabled (INPUT_SWITCH_ENABLED = true, v5 CC1 D-pad Up/Down)")
	# First statement of _unhandled_input must be the INPUT_SWITCH_ENABLED gate.
	var gated := false
	var lines := source.split("\n")
	for k in lines.size():
		if lines[k].begins_with("func _unhandled_input(") and k + 2 < lines.size():
			gated = lines[k + 1].strip_edges() == "if not INPUT_SWITCH_ENABLED:" \
				and lines[k + 2].strip_edges() == "return"
	_assert(gated,
		"_unhandled_input keeps the INPUT_SWITCH_ENABLED gate as its first statement")


func test_party_system_switch_cooldown() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("SWITCH_COOLDOWN"),
		"PartySystem has placeholder SWITCH_COOLDOWN anti-spam guard")


func test_settings_manager_bindings_version() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("BINDINGS_VERSION"), "SettingsManager defines BINDINGS_VERSION")
	_assert(source.contains("const BINDINGS_VERSION := 5") or source.contains("const BINDINGS_VERSION: int = 5"),
		"BINDINGS_VERSION is 5 (v4 battle_toggle resets saved v3 bindings)")
	_assert(SettingsManager.BINDINGS_VERSION == 5,
		"Runtime SettingsManager.BINDINGS_VERSION == 5")


func test_settings_manager_action_label() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func get_action_label("),
		"SettingsManager exposes get_action_label(action, controller)")


func test_settings_sprint_rebindable() -> void:
	_assert(&"sprint" in SettingsManager.REBINDABLE_ACTIONS,
		"sprint is in SettingsManager.REBINDABLE_ACTIONS")
	var menu_src := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(menu_src.contains('"action": "sprint"'),
		"Settings menu has a keybind row for sprint (Run)")
	_assert(&"unique_ability" in SettingsManager.REBINDABLE_ACTIONS,
		"unique_ability is in SettingsManager.REBINDABLE_ACTIONS (v3)")


func test_control_bar_v3_hints() -> void:
	# v3 (Package U): the context hint stack is mode-aware. Order per context:
	#   Free  : Jump, Attack, Dodge, Command (pad Y = Interact while a prompt shows)
	#   Battle: Command, Attack · Hold Heavy, <Unique>, Dodge
	#   Stance: Command, Orbs · Hold Fireball, Exit Stance, Dodge
	# Command / Unique are routed roles (pad glyph from the mode, never "---").
	var source := _get_source("res://src/ui/hud/control_bar.gd")
	_assert(source.contains("get_action_label") or source.contains("ButtonGlyph"),
		"Control bar labels come from the InputMap (SettingsManager / ButtonGlyph)")
	_assert(not source.contains('"TACTICAL"'), "Control bar no longer shows TACTICAL entry")
	_assert(not source.contains('"LT"'), "Control bar has no hardcoded LT label")
	_assert(source.contains("func get_hint_entries(") and source.contains("static func routed_label("),
		"Control bar exposes get_hint_entries() and routed_label()")
	var consts: Dictionary = load("res://src/ui/hud/control_bar.gd").get_script_constant_map()
	var expect_sets := {
		"HINTS_FREE": [["jump", "Jump"], ["attack", "Attack"], ["dodge", "Dodge"], ["tactical_mode", "Command"]],
		"HINTS_BATTLE": [["tactical_mode", "Command"], ["attack", "Attack · Hold Heavy"], ["unique_ability", "%s"], ["dodge", "Dodge"]],
		"HINTS_STANCE": [["tactical_mode", "Command"], ["attack", "Orbs · Hold Fireball"], ["unique_ability", "Exit Stance"], ["dodge", "Dodge"]],
		"HINTS_CARRY": [["interact", "Put Down"], ["interact", "Hold to Throw"], ["jump", "Jump"]],
	}
	for set_name in expect_sets:
		var got: Array = []
		for e in consts.get(set_name, []):
			got.append([str(e[0]), str(e[1])])
		_assert(got == expect_sets[set_name], "Control bar %s order/content is v3" % set_name, str(got))
	_assert(consts.get("HINT_TO_BATTLE", []) == [&"battle_toggle", "Battle"],
		"Control bar HINT_TO_BATTLE is [battle_toggle, Battle] (v4)", str(consts.get("HINT_TO_BATTLE")))
	_assert(consts.get("HINT_TO_FREE_ROAM", []) == [&"battle_toggle", "Free Roam"],
		"Control bar HINT_TO_FREE_ROAM is [battle_toggle, Free Roam] (v4)", str(consts.get("HINT_TO_FREE_ROAM")))
	# Routed glyphs (static, pure).
	var cb = load("res://src/ui/hud/control_bar.gd")
	_assert(cb.routed_label(&"command", false, true) == "Y", "Routed Command glyph is Y on pad in free roam",
		cb.routed_label(&"command", false, true))
	_assert(cb.routed_label(&"command", true, true) == "A", "Routed Command glyph is A on pad in battle",
		cb.routed_label(&"command", true, true))
	_assert(cb.routed_label(&"unique", true, true) == "Y", "Routed Unique glyph is Y on pad",
		cb.routed_label(&"unique", true, true))
	_assert(cb.routed_label(&"command", true, false).contains("Q") and cb.routed_label(&"unique", true, false).contains("R"),
		"Routed keyboard glyphs are Q (Command) / R (Unique)")


## Runtime: the real control bar + real player, per mode and device.
func test_control_bar_runtime() -> void:
	var script = load("res://src/ui/hud/control_bar.gd")
	var enemy_scene = load("res://src/enemies/enemy.tscn") as PackedScene
	if script == null or enemy_scene == null:
		_fail("Control bar runtime harness", "control_bar.gd or enemy.tscn failed to load")
		return
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	await _wait_on_floor(player)
	player.state_machine.force_transition(&"Idle")
	GameManager.change_state(GameManager.GameState.PLAYING)
	var hints_before: bool = SettingsManager.show_control_hints
	SettingsManager.show_control_hints = true
	var original_device = InputManager.active_device
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	var bar: CanvasLayer = CanvasLayer.new()
	bar.set_script(script)
	add_child(bar)
	await _frames(3)

	_assert(bar.get_hint_entries() == [["A", "Jump"], ["X", "Attack"], ["B", "Dodge"], ["Y", "Command"], ["View", "Battle"]],
		"Free roam pad hints: A Jump · X Attack · B Dodge · Y Command · View Battle", str(bar.get_hint_entries()))
	var dummy := _make_stub_interactable()
	_world.add_child(dummy)
	Events.interaction_available.emit(dummy)
	await _frames(2)
	_assert(bar.get_hint_entries() == [["A", "Interact"], ["X", "Attack"], ["B", "Dodge"], ["Y", "Command"], ["View", "Battle"]],
		"Free roam pad hints with a prompt (v8): A reads Interact, Y stays Command (View Battle last)", str(bar.get_hint_entries()))
	Events.interaction_cleared.emit()
	await _frames(2)
	InputManager.active_device = InputManager.DeviceType.KEYBOARD_MOUSE
	await _frames(2)
	var kb: Array = bar.get_hint_entries()
	_assert(kb.size() == 5 and kb[0][0] == "Space" and kb[3][0].contains("Q") and kb[3][1] == "Command"
			and kb[4] == ["F", "Battle"],
		"Free roam keyboard hints: Space Jump ... Q Command · F Battle", str(kb))

	# Battle: a frozen engaged enemy.
	var enemy: Node = enemy_scene.instantiate()
	_world.add_child(enemy)
	enemy.global_position = Vector3(60, 0, 60)
	await _physics_frames(2)
	enemy.set_physics_process(false)
	enemy.ai_state = EnemyBase.AIState.CHASE
	player.battle_mode.force_check(0)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	await _frames(3)
	_assert(player.in_battle and bar.get_hint_entries() == [["A", "Command"], ["X", "Attack · Hold Heavy"],
			["Y", "Arcane Stance"], ["B", "Dodge"], ["View", "Free Roam"]],
		"Battle pad hints: A Command · X Attack · Hold Heavy · Y Arcane Stance · B Dodge · View Free Roam",
		str(bar.get_hint_entries()))
	player.stance.toggle()
	await _frames(3)
	_assert(bar.get_hint_entries() == [["A", "Command"], ["X", "Orbs · Hold Fireball"], ["Y", "Exit Stance"], ["B", "Dodge"],
			["View", "Free Roam"]],
		"Stance pad hints: A Command · X Orbs · Hold Fireball · Y Exit Stance · B Dodge · View Free Roam",
		str(bar.get_hint_entries()))
	player.stance.exit_stance(&"manual")
	InputManager.active_device = InputManager.DeviceType.KEYBOARD_MOUSE
	await _frames(3)
	var bkb: Array = bar.get_hint_entries()
	_assert(bkb.size() == 5 and bkb[0][0].contains("Q") and bkb[2][0].contains("R") and bkb[2][1] == "Arcane Stance"
			and bkb[4] == ["F", "Free Roam"],
		"Battle keyboard hints: Q Command ... R Arcane Stance · F Free Roam", str(bkb))
	var no_dash := true
	for e in bkb + bar.get_hint_entries():
		if e[0] == "---":
			no_dash = false
	_assert(no_dash, "No hint ever draws '---'")

	enemy.ai_state = EnemyBase.AIState.IDLE
	player.battle_mode.force_exit()
	InputManager.active_device = original_device
	SettingsManager.show_control_hints = hints_before
	bar.queue_free()
	dummy.queue_free()
	enemy.queue_free()
	await _despawn(player)


func test_interaction_prompt_uses_label() -> void:
	var source := _get_source("res://src/ui/hud/interaction_prompt.gd")
	_assert(source.contains("get_action_label") and source.contains("interact"),
		"Interaction prompt hint comes from SettingsManager.get_action_label(interact)")
	_assert(not source.contains('"[A]"') and not source.contains('"[Y]"'),
		"Interaction prompt has no hardcoded [A] / [Y] hint")
	_assert(source.contains("carry_started") and source.contains("carry_ended"),
		"Interaction prompt listens to carry_started / carry_ended")


# ========== CATEGORY 3: RUNTIME LABELS & PROMPTS ==========

func test_runtime_action_labels() -> void:
	if not SettingsManager.has_method("get_action_label"):
		_fail("SettingsManager.get_action_label callable at runtime", "method missing")
		return
	# v3: tactical_mode / unique_ability have no joypad binding ("---" by design;
	# the HUD labels pad Command / Unique from player.in_battle as A / Y).
	var expect_pad := {
		&"tactical_mode": "---", &"unique_ability": "---", &"jump": "A", &"attack": "X",
		&"interact": "Y", &"dodge": "B", &"sprint": "L3", &"lock_on": "RT",
	}
	for action: StringName in expect_pad:
		var got: String = SettingsManager.get_action_label(action, true)
		_assert(got == expect_pad[action], "Controller label for %s is %s" % [action, expect_pad[action]],
			"got '%s'" % got)
	var kb_tac: String = SettingsManager.get_action_label(&"tactical_mode", false)
	_assert(kb_tac.contains("Q"), "Keyboard label for tactical_mode contains Q", "got '%s'" % kb_tac)
	var kb_sprint: String = SettingsManager.get_action_label(&"sprint", false)
	_assert(kb_sprint.contains("Ctrl"), "Keyboard label for sprint contains Ctrl", "got '%s'" % kb_sprint)
	var kb_interact: String = SettingsManager.get_action_label(&"interact", false)
	_assert(kb_interact.contains("E"), "Keyboard label for interact contains E", "got '%s'" % kb_interact)
	var kb_unique: String = SettingsManager.get_action_label(&"unique_ability", false)
	_assert(kb_unique.contains("R"), "Keyboard label for unique_ability contains R", "got '%s'" % kb_unique)


func test_runtime_interaction_prompt() -> void:
	var script = load("res://src/ui/hud/interaction_prompt.gd")
	if script == null:
		_fail("InteractionPrompt runtime harness", "script failed to load")
		return
	var prompt := CanvasLayer.new()
	prompt.set_script(script)
	add_child(prompt)
	await get_tree().process_frame
	if not prompt.has_method("get_key_hint") or not prompt.has_method("get_prompt_text"):
		_fail("InteractionPrompt exposes get_key_hint() / get_prompt_text()", "not implemented")
		prompt.queue_free()
		return

	var original_device = InputManager.active_device
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	_assert(prompt.get_key_hint() == "[Y]", "Controller interaction hint is [Y]",
		"got '%s'" % prompt.get_key_hint())
	InputManager.active_device = InputManager.DeviceType.KEYBOARD_MOUSE
	_assert(prompt.get_key_hint() == "[E]", "Keyboard interaction hint is [E]",
		"got '%s'" % prompt.get_key_hint())

	# Carry prompts (F8)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	var dummy := Node3D.new()
	add_child(dummy)
	Events.carry_started.emit(dummy)
	var text: String = prompt.get_prompt_text()
	_assert(text.contains("[Y] Put Down") and text.contains("Hold [Y] Throw"),
		"While carrying, prompt shows '[Y] Put Down / Hold [Y] Throw'", "got '%s'" % text)
	Events.interaction_cleared.emit()
	_assert(prompt.get_prompt_text().contains("Put Down"),
		"Carry prompt survives interaction_cleared while carrying")
	Events.carry_ended.emit(dummy, &"put_down")
	Events.carryable_in_range.emit(null)
	_assert(prompt.get_prompt_text() == "", "Carry prompt cleared after carry_ended",
		"got '%s'" % prompt.get_prompt_text())
	InputManager.active_device = original_device

	dummy.queue_free()
	prompt.queue_free()
	await get_tree().process_frame


# ========== CATEGORY 4: RUNTIME TACTICAL MENU ==========

func test_tactical_open_press_guard() -> void:
	var script = load(TACTICAL_STATE)
	if script == null:
		_fail("TacticalIdle runtime harness", "script failed to load")
		return

	var stub_player := _make_stub_player()
	_world.add_child(stub_player)
	# v3 T2: closing returns to Fall if the menu opened airborne, so the stub
	# must really stand on the test floor for the ground-close checks below.
	stub_player.global_position = Vector3(10, 0.05, 0)
	for i in 30:
		await get_tree().physics_frame
		stub_player.velocity = Vector3(0, -5, 0)
		stub_player.move_and_slide()
		if stub_player.is_on_floor():
			break
	_assert(stub_player.is_on_floor(), "Tactical harness: stub player stands on the floor")
	stub_player.velocity = Vector3.ZERO
	var state: Node = script.new()
	state.name = "TacticalIdle"
	add_child(state)
	state.initialize(stub_player)

	var original_state = GameManager.current_state
	GameManager.change_state(GameManager.GameState.PLAYING)
	var time_scale_before: float = Engine.time_scale
	stub_player.is_locked_on = true

	# 1) The A press that opened the menu arrives on the opening frame.
	state.enter()
	var next: StringName = state.process_input(_joy_press(JOY_A))
	_assert(int(state._phase) == 0 and next == &"",
		"Opening-frame A press does not confirm first category (stays CATEGORY_SELECT)",
		"phase=%d next=%s" % [int(state._phase), next])
	_assert(GameManager.current_state == GameManager.GameState.TACTICAL_MODE,
		"Tactical mode active after enter()")

	# 2) After release and a couple of physics frames, A confirms.
	state.process_input(_joy_release(JOY_A))
	await _tick(state)
	next = state.process_input(_joy_press(JOY_A))
	_assert(int(state._phase) == 1 and next == &"",
		"A confirms category after release (ABILITY_SELECT)",
		"phase=%d next=%s" % [int(state._phase), next])

	# 3) A inside ability phase must not close the menu (A = confirm, not toggle).
	state.process_input(_joy_release(JOY_A))
	next = state.process_input(_joy_press(JOY_A))
	_assert(next == &"" and int(state._phase) == 1,
		"A in ABILITY_SELECT does not close the menu",
		"phase=%d next=%s" % [int(state._phase), next])
	state.process_input(_joy_release(JOY_A))

	# 4) B (ui_cancel) backs out one level.
	next = state.process_input(_joy_press(JOY_B))
	_assert(int(state._phase) == 0 and next == &"",
		"B in ABILITY_SELECT returns to CATEGORY_SELECT",
		"phase=%d next=%s" % [int(state._phase), next])
	state.process_input(_joy_release(JOY_B))

	# 5) B in category phase closes and preserves lock-on.
	next = state.process_input(_joy_press(JOY_B))
	_assert(next == &"LockOnIdle", "B in CATEGORY_SELECT closes to LockOnIdle (lock-on preserved)",
		"next=%s" % next)
	state.exit()
	_assert(is_equal_approx(Engine.time_scale, time_scale_before),
		"Time scale restored after close", "%f vs %f" % [Engine.time_scale, time_scale_before])
	_assert(stub_player.is_locked_on, "Lock-on flag untouched by tactical open/close")

	# 6) Start closes from any phase.
	stub_player.is_locked_on = false
	state.enter()
	state.process_input(_joy_release(JOY_A))
	await _tick(state)
	next = state.process_input(_joy_press(JOY_START))
	_assert(next == &"Idle", "Start closes the tactical menu", "next=%s" % next)
	state.exit()

	# 7) Keyboard Q still toggles the menu closed.
	state.enter()
	state.process_input(_key_release(KEY_Q))
	await _tick(state)
	next = state.process_input(_key_press(KEY_Q))
	_assert(next == &"Idle", "Keyboard Q closes the tactical menu", "next=%s" % next)
	state.exit()

	_assert(GameManager.current_state == GameManager.GameState.PLAYING,
		"GameManager back to PLAYING after all closes")
	GameManager.change_state(original_state)

	state.queue_free()
	stub_player.queue_free()


# ========== CATEGORY 5: NO CONTEXTUAL A / B INTERACT GUARD ==========

func test_free_roam_a_y_routing_runtime() -> void:
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	var target := _make_stub_interactable()
	_world.add_child(target)
	GameManager.change_state(GameManager.GameState.PLAYING)
	Events.combat_ended.emit()
	_assert(not player.in_battle, "Fresh player with no enemies is in Free Roam (in_battle false)")
	if not await _wait_on_floor(player):
		_fail("Free-roam routing harness", "player never landed on test floor")
		await _despawn(player)
		target.queue_free()
		return

	# --- v8: A next to an interactable is the context button: interacts, no jump, no menu. ---
	player._current_interactable = target
	player.state_machine.force_transition(&"Idle")
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	_assert(player.state_machine.current_state.name == &"Idle",
		"Free roam: A next to an interactable does not jump (v8 context button)",
		"state=%s" % player.state_machine.current_state.name)
	_assert(target.calls == 1, "Free roam: A next to an interactable interacts (v8)", "calls=%d" % target.calls)
	_assert(GameManager.current_state == GameManager.GameState.PLAYING,
		"Free roam: A does not open the Command Menu (GameManager still PLAYING)")
	player.state_machine.force_transition(&"Idle")
	await _physics_frames(2)

	# --- v8: Y with a prompt opens the Command Menu (real input path), never interacts. ---
	player._current_interactable = target
	Input.parse_input_event(_joy_press(JOY_Y))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_Y))
	await _physics_frames(2)
	_assert(target.calls == 1, "Free roam: Y with a prompt does not interact (v8)", "calls=%d" % target.calls)
	_assert(player.state_machine.current_state.name == &"TacticalIdle",
		"Free roam: Y with a prompt opens the Command Menu (v8)",
		"state=%s" % player.state_machine.current_state.name)
	player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	Engine.time_scale = 1.0
	await _physics_frames(2)

	# --- Y with no prompt: opens the Command Menu (real input path). ---
	player._current_interactable = null
	var calls_before: int = target.calls
	Input.parse_input_event(_joy_press(JOY_Y))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_Y))
	await _physics_frames(3)
	_assert(player.state_machine.current_state.name == &"TacticalIdle",
		"Free roam: Y with no prompt opens the Command Menu",
		"state=%s" % player.state_machine.current_state.name)
	_assert(GameManager.current_state == GameManager.GameState.TACTICAL_MODE,
		"Free roam: Y-opened Command Menu puts GameManager in TACTICAL_MODE")
	# B backs out of the top layer: closes the menu and does NOT also dodge.
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_B))
	await _physics_frames(2)
	var after_b: StringName = player.state_machine.current_state.name
	_assert(after_b != &"TacticalIdle" and after_b != &"Dodge",
		"B at the Command Menu top layer closes it without dodging", "state=%s" % after_b)
	_assert(target.calls == calls_before, "Y/B Command Menu round-trip never interacts",
		"calls=%d" % target.calls)
	player.state_machine.force_transition(&"Idle")

	# --- Keyboard Q opens the Command Menu even next to an interactable. ---
	player._current_interactable = target
	player.state_machine._unhandled_input(_key_press(KEY_Q))
	_assert(player.state_machine.current_state.name == &"TacticalIdle" and target.calls == calls_before,
		"Keyboard Q opens the Command Menu without interacting",
		"state=%s calls=%d" % [player.state_machine.current_state.name, target.calls])
	player.state_machine.force_transition(&"Idle")
	_assert(GameManager.current_state == GameManager.GameState.PLAYING,
		"GameManager back to PLAYING after closing the menu")

	# --- Keyboard Space jumps in free roam. ---
	await _physics_frames(2)
	player.state_machine._unhandled_input(_key_press(KEY_SPACE))
	player.state_machine._unhandled_input(_key_release(KEY_SPACE))
	_assert(player.state_machine.current_state.name == &"Jump",
		"Free roam: keyboard Space jumps", "state=%s" % player.state_machine.current_state.name)
	await _physics_frames(5)
	await _wait_on_floor(player, 240)

	await _despawn(player)
	target.queue_free()


func test_y_interact_guard_runtime() -> void:
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	var target := _make_stub_interactable()
	_world.add_child(target)
	player._current_interactable = target
	var original_state = GameManager.current_state
	await _wait_on_floor(player)
	player.state_machine.force_transition(&"Idle")

	# PLAYING: pad A (v8 context button) interacts.
	GameManager.change_state(GameManager.GameState.PLAYING)
	player._unhandled_input(_joy_press(JOY_A))
	_assert(target.calls == 1, "pad A interacts with the current interactable in PLAYING (v8)",
		"calls=%d" % target.calls)
	player._unhandled_input(_key_press(KEY_E))
	_assert(target.calls == 2, "Keyboard E interacts in PLAYING", "calls=%d" % target.calls)
	# B is dodge / back now: it never interacts.
	player._unhandled_input(_joy_press(JOY_B))
	_assert(target.calls == 2, "B never interacts (B = dodge / back in v3)", "calls=%d" % target.calls)

	# Not PLAYING: A must not interact.
	for st in [GameManager.GameState.TACTICAL_MODE, GameManager.GameState.PAUSED,
			GameManager.GameState.CUTSCENE]:
		GameManager.change_state(st)
		var before: int = target.calls
		player._unhandled_input(_joy_press(JOY_A))
		_assert(target.calls == before,
			"A does not interact while %s" % GameManager.GameState.keys()[st],
			"calls=%d" % target.calls)
		GameManager.change_state(GameManager.GameState.PLAYING)

	# Real routing: open the menu with Y (no prompt), then a prompt appears.
	# Y and B inside the Command Menu must never interact; B backs out.
	player.state_machine.force_transition(&"Idle")
	player._current_interactable = null
	player.state_machine._unhandled_input(_joy_press(JOY_Y))
	player.state_machine._unhandled_input(_joy_release(JOY_Y))
	if player.state_machine.current_state.name == &"TacticalIdle":
		player._current_interactable = target
		await _physics_frames(3)
		var before: int = target.calls
		Input.parse_input_event(_joy_press(JOY_Y))
		await _physics_frames(2)
		Input.parse_input_event(_joy_release(JOY_Y))
		await _physics_frames(2)
		_assert(target.calls == before, "Y inside the Command Menu does not interact",
			"calls=%d" % target.calls)
		Input.parse_input_event(_joy_press(JOY_B))
		await _physics_frames(3)
		Input.parse_input_event(_joy_release(JOY_B))
		await _physics_frames(2)
		_assert(target.calls == before, "B inside the Command Menu does not interact",
			"calls=%d" % target.calls)
		_assert(player.state_machine.current_state.name != &"TacticalIdle",
			"B inside the Command Menu (category level) closes it",
			"state=%s" % player.state_machine.current_state.name)
	else:
		_fail("Y / B inside the Command Menu do not interact", "menu did not open on Y (no prompt)")
	player.state_machine.force_transition(&"Idle")
	GameManager.change_state(original_state)
	GameManager.change_state(GameManager.GameState.PLAYING)

	await _despawn(player)
	target.queue_free()


# ========== CATEGORY 6: DOUBLE JUMP / SPRINT ==========

func test_double_jump_runtime() -> void:
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	GameManager.change_state(GameManager.GameState.PLAYING)
	_assert(player.has_double_jump, "Fresh player has double jump unlocked")
	if not await _wait_on_floor(player):
		_fail("Double jump harness", "player never landed on test floor")
		await _despawn(player)
		return
	player.state_machine.force_transition(&"Idle")

	# First A press from the floor: Jump.
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	_assert(player.state_machine.current_state.name == &"Jump", "A on the floor enters Jump (free roam)",
		"state=%s" % player.state_machine.current_state.name)

	# Rise until near the apex (velocity drops under 3) or Fall.
	var frames := 0
	while frames < 90 and player.velocity.y > 3.0:
		await get_tree().physics_frame
		frames += 1
	_assert(not player.is_on_floor(), "Player airborne before the second A press")
	var vy_before: float = player.velocity.y
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	var vy_after: float = player.velocity.y
	_assert(vy_after > vy_before + 3.0, "Second A in the air adds upward velocity (double jump)",
		"vy %.2f -> %.2f (state=%s)" % [vy_before, vy_after, player.state_machine.current_state.name])

	# Third press: no triple jump.
	await _physics_frames(2)
	var vy_third_before: float = player.velocity.y
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	_assert(player.velocity.y <= vy_third_before + 0.01, "Third A in the air does nothing (one double jump)",
		"vy %.2f -> %.2f" % [vy_third_before, player.velocity.y])

	# Land: double jump resets.
	if await _wait_on_floor(player, 240):
		await _physics_frames(2)
		_assert(not player._double_jump_used, "Double jump resets on landing")
	else:
		_fail("Double jump resets on landing", "player never landed")

	# Double jump from Fall (walked off / fell): second jump still available.
	player.global_position = Vector3(0, 4, 0)
	player.velocity = Vector3.ZERO
	player.state_machine.force_transition(&"Fall")
	await _physics_frames(3)
	var vy_fall: float = player.velocity.y
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	_assert(player.velocity.y > 0.0 and player.velocity.y > vy_fall,
		"A while falling performs the double jump",
		"vy %.2f -> %.2f" % [vy_fall, player.velocity.y])

	await _wait_on_floor(player, 240)
	await _despawn(player)


func test_sprint_runtime() -> void:
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	GameManager.change_state(GameManager.GameState.PLAYING)
	if not await _wait_on_floor(player):
		_fail("Sprint harness", "player never landed on test floor")
		await _despawn(player)
		return
	player.state_machine.force_transition(&"Idle")

	Input.action_press(&"move_up")
	await _physics_frames(60)
	var base_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_assert(player.state_machine.current_state.name == &"Run" and base_speed > 1.0,
		"Holding move runs (Run state)", "state=%s speed=%.2f" % [
			player.state_machine.current_state.name, base_speed])
	_assert(not ("is_sprinting" in player) or not player.is_sprinting,
		"is_sprinting false without the sprint button")

	Input.action_press(&"sprint")
	await _physics_frames(60)
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_assert(sprint_speed > base_speed * 1.3,
		"Run speed with sprint held is greater than base run speed (~1.6x)",
		"base=%.2f sprint=%.2f" % [base_speed, sprint_speed])
	if "is_sprinting" in player:
		_assert(player.is_sprinting, "player.is_sprinting true while sprinting")
	else:
		_fail("player.is_sprinting true while sprinting", "not implemented (Package G4)")

	Input.action_release(&"sprint")
	Input.action_release(&"move_up")
	await _physics_frames(30)
	await _despawn(player)


# ========== CATEGORY 7: SPELL WITH NO TARGET ==========

func test_no_target_spell_runtime() -> void:
	var player := await _spawn_player(Vector3(0, 0.1, 0))
	if player == null:
		return
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _wait_on_floor(player)
	_assert(get_tree().get_nodes_in_group(&"enemies").is_empty(), "No enemies in the test world")

	var fire_bolt: AbilityData = player.ability_system.get_equipped_ability(0)
	_assert(fire_bolt != null and fire_bolt.ability_type == AbilityData.AbilityType.PROJECTILE,
		"Slot 0 holds an offensive spell (Fire Bolt)")

	var rec := {"started": 0, "failed": 0, "reason": "", "effects": 0}
	var on_started := func(_a): rec.started += 1
	var on_failed := func(reason, _a):
		rec.failed += 1
		rec.reason = str(reason)
	var on_effect := func(_e, _a): rec.effects += 1
	Events.ability_cast_started.connect(on_started)
	Events.ability_request_failed.connect(on_failed)
	Events.ability_effect_spawned.connect(on_effect)

	# --- Resources available: v4 X, the first confirm opens the target step
	# with only "Fire Forward" (pre-selected); a second confirm casts it. ---
	player.current_atb = player.max_atb
	player.current_mp = player.max_mp
	var atb_before: float = player.current_atb
	await _open_menu_to_slot0(player)
	await _confirm(player)
	var tac: Node = player.state_machine.current_state
	var in_step: bool = tac.name == &"TacticalIdle" and int(tac._phase) == 2
	_assert(in_step and rec.started == 0,
		"v4: confirming an offensive spell with no enemies opens the target step (no instant cast)",
		"state=%s phase=%s started=%d" % [tac.name, str(tac.get(&"_phase")), rec.started])
	if in_step:
		_assert(tac._get_target_names() == PackedStringArray(["Fire Forward"]) and tac._target_index == 0,
			"v4: with no enemies the target step lists only \"Fire Forward\", pre-selected",
			str(tac._get_target_names()))
	await _confirm(player)
	var cast: bool = rec.started > 0 or player.state_machine.current_state.name == &"Ability" \
		or player.current_atb < atb_before - 1.0
	_assert(cast or rec.failed > 0,
		"Confirming Fire Forward with no enemies casts it or reports a failure (never silent)",
		"started=%d failed=%d state=%s" % [rec.started, rec.failed, player.state_machine.current_state.name])
	_assert(cast, "With ATB/MP available, the untargeted spell is cast",
		"state=%s failed_reason=%s" % [player.state_machine.current_state.name, rec.reason])
	_assert(player.state_machine.current_state.name != &"TacticalIdle"
			and GameManager.current_state == GameManager.GameState.PLAYING,
		"Command Menu closes when the untargeted spell is cast",
		"state=%s gm=%s" % [player.state_machine.current_state.name,
			GameManager.GameState.keys()[GameManager.current_state]])

	# The projectile still spawns (G6), aimed along facing.
	var waited := 0
	while waited < 120 and rec.effects == 0:
		await get_tree().physics_frame
		waited += 1
	_assert(rec.effects > 0, "Untargeted spell effect spawns (projectile fires along facing)",
		"no ability_effect_spawned after %d frames" % waited)
	waited = 0
	while waited < 120 and player.state_machine.current_state.name == &"Ability":
		await get_tree().physics_frame
		waited += 1

	# --- No ATB: confirming reports the failure (G7). ---
	rec.started = 0
	rec.failed = 0
	player.state_machine.force_transition(&"Idle")
	await _open_menu_to_slot0(player)
	player.current_atb = 0.0
	await _confirm(player)
	_assert(rec.failed > 0 and rec.started == 0,
		"Blocked spell (no ATB / cooldown) emits ability_request_failed instead of failing silently",
		"started=%d failed=%d" % [rec.started, rec.failed])

	player.state_machine.force_transition(&"Idle")
	Events.ability_cast_started.disconnect(on_started)
	Events.ability_request_failed.disconnect(on_failed)
	Events.ability_effect_spawned.disconnect(on_effect)
	# Free any projectile that landed in the test root.
	for child in get_children():
		if child != _world and child is Node3D:
			child.queue_free()
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _despawn(player)


## Open the Command Menu from Idle and move to ABILITY_SELECT (slot 0).
## v3 free roam: Y with no prompt opens the menu (A would jump); A confirms.
func _open_menu_to_slot0(player: Node) -> void:
	player.state_machine.force_transition(&"Idle")
	player._current_interactable = null
	player.state_machine._unhandled_input(_joy_press(JOY_Y))
	player.state_machine._unhandled_input(_joy_release(JOY_Y))
	await _physics_frames(3)  # arms the open-press guard
	player.state_machine._unhandled_input(_joy_press(JOY_A))  # category -> abilities
	player.state_machine._unhandled_input(_joy_release(JOY_A))


func _confirm(player: Node) -> void:
	player.state_machine._unhandled_input(_joy_press(JOY_A))
	player.state_machine._unhandled_input(_joy_release(JOY_A))
	await _physics_frames(2)


# ========== CATEGORY 8: RUNTIME PARTY SWITCH GATE ==========

func test_party_switch_gate_runtime() -> void:
	var script = load("res://src/party/party_system.gd")
	var companion_data = load("res://resources/characters/companion.tres")
	if script == null or companion_data == null:
		_fail("PartySystem runtime harness", "party_system.gd or companion.tres failed to load")
		return
	var ps := Node.new()
	ps.set_script(script)
	add_child(ps)
	if not ps.has_method("can_switch_from_input"):
		_fail("PartySystem exposes can_switch_from_input()", "method missing")
		ps.queue_free()
		return
	var mock_player := Node3D.new()
	add_child(mock_player)
	ps.initialize(mock_player, companion_data)

	var original_state = GameManager.current_state
	GameManager.change_state(GameManager.GameState.PLAYING)
	_assert(ps.can_switch_from_input(), "Party switch allowed in PLAYING with 2 members")
	for st in [GameManager.GameState.TACTICAL_MODE, GameManager.GameState.PAUSED, GameManager.GameState.CUTSCENE]:
		GameManager.change_state(st)
		_assert(not ps.can_switch_from_input(),
			"Party switch blocked in %s" % GameManager.GameState.keys()[st])
		# Return via PLAYING so GameManager pops tactical time scale / unpauses.
		GameManager.change_state(GameManager.GameState.PLAYING)
	_assert(is_equal_approx(Engine.time_scale, 1.0) and not get_tree().paused,
		"GameManager state restored after party gate checks")
	GameManager.change_state(original_state)

	ps.queue_free()
	mock_player.queue_free()


# ========== HELPERS ==========

## Advance two physics frames, driving the state's process_physics like the
## StateMachine would (the open-press guard may arm there).
func _tick(state: Node) -> void:
	for i in 2:
		await get_tree().physics_frame
		state.process_physics(1.0 / 60.0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Floor (World layer) + current camera looking down -Z.
func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "TestWorld"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	world.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 6)
	world.add_child(cam)
	cam.current = true
	return world


func _spawn_player(pos: Vector3) -> Node:
	var scene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		_fail("Player runtime harness", "player.tscn failed to load")
		return null
	var player: Node = scene.instantiate()
	_world.add_child(player)
	player.global_position = pos
	await get_tree().physics_frame
	return player


func _despawn(player: Node) -> void:
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().process_frame


func _wait_on_floor(player: Node, max_frames: int = 120) -> bool:
	for i in max_frames:
		if player.is_on_floor():
			return true
		await get_tree().physics_frame
	return player.is_on_floor()


func _make_stub_player() -> CharacterBody3D:
	var abil := GDScript.new()
	abil.source_code = "extends RefCounted\nvar equipped_abilities: Array = []\nfunc get_equipped_ability(_i: int): return null\nfunc can_use_ability(_a) -> bool: return false\nfunc get_fail_reason(_a) -> String: return \"\"\nfunc request_ability(_a) -> bool: return false\n"
	abil.reload()
	var gd := GDScript.new()
	gd.source_code = "extends CharacterBody3D\nvar is_locked_on: bool = false\nvar is_in_combat: bool = true\nvar in_battle: bool = false\nvar ability_system = null\nvar party_system = null\nvar combo = null\nvar stance = null\nfunc has_interactable() -> bool: return false\nfunc try_interact() -> bool: return false\nfunc is_command_press(_e) -> bool: return false\nfunc is_jump_press(_e) -> bool: return false\nfunc is_interact_press(_e) -> bool: return false\nfunc is_unique_press(_e) -> bool: return false\n"
	gd.reload()
	var p := CharacterBody3D.new()
	p.set_script(gd)
	p.ability_system = abil.new()
	p.collision_layer = 0
	p.collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.0
	col.shape = cap
	col.position = Vector3(0, 0.5, 0)
	p.add_child(col)
	return p


func _make_stub_interactable() -> Area3D:
	var gd := GDScript.new()
	gd.source_code = "extends Area3D\nvar calls: int = 0\nvar interact_priority: int = 0\nfunc is_active() -> bool: return true\nfunc interact(_p) -> void: calls += 1\n"
	gd.reload()
	var a := Area3D.new()
	a.set_script(gd)
	# Assigned to player._current_interactable by hand; keep it out of the
	# player's InteractionDetector so enter/exit can't reassign the target.
	a.collision_layer = 0
	a.collision_mask = 0
	a.monitorable = false
	return a


func _joy_press(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = true
	return ev


func _joy_release(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = false
	return ev


func _key_press(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _key_release(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	return ev


func _gameplay_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for action in InputMap.get_actions():
		if not str(action).begins_with("ui_"):
			out.append(action)
	return out


func _gameplay_actions_with_joy_button(idx: int) -> Array[String]:
	var out: Array[String] = []
	for action in _gameplay_actions():
		if _has_joy_button(action, idx):
			out.append(str(action))
	return out


func _joy_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			out.append(ev)
	return out


func _has_joy_button(action: StringName, idx: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == idx:
			return true
	return false


func _has_joy_axis(action: StringName, axis: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axis:
			return true
	return false


func _has_key(action: StringName, code: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev.keycode == code or ev.physical_keycode == code):
			return true
	return false


## True if source checks the action via is_action_pressed / is_action_just_pressed
## / is_action_released / is_action (StringName or String literal).
func _uses_action(source: String, action: String) -> bool:
	var re := RegEx.new()
	re.compile("is_action(_just)?(_pressed|_released)?\\(\\s*&?\"%s\"" % action)
	return re.search(source) != null


func _get_source(path: String) -> String:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String, reason: String = "") -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name, reason)


func _section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


func _pass(test_name: String) -> void:
	_passed += 1
	_total += 1
	print("  PASS: %s" % test_name)


func _fail(test_name: String, reason: String = "") -> void:
	_failed += 1
	_total += 1
	var msg := "  FAIL: %s" % test_name
	if reason != "":
		msg += " — %s" % reason
	print(msg)
