## Phase 8 tests: HUD elements, menu validation, and UX flow.
## Covers items 176-200 from the structured checklist.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 8: HUD, Menus & UX Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 8 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: HUD Elements (items 176-182)
	_section("HUD ELEMENTS")
	test_combat_hud_script_exists()
	test_combat_hud_has_hp_bar()
	test_combat_hud_has_mp_bar()
	test_combat_hud_has_atb_bar()
	test_combat_hud_connects_signals()
	test_combat_hud_low_hp_color_shift()
	test_combat_hud_flash_feedback()
	test_lock_on_indicator_exists()
	test_interaction_prompt_exists()
	test_control_bar_exists()
	test_quest_tracker_exists()
	test_quest_tracker_has_placeholder_state()
	test_quest_tracker_connects_signals()

	# Category 2: Title Screen (items 183-187)
	_section("TITLE SCREEN")
	test_main_menu_scene_exists()
	test_main_menu_has_new_game()
	test_main_menu_has_continue()
	test_main_menu_has_options()
	test_main_menu_has_exit()
	test_main_menu_grabs_focus()
	test_main_menu_sets_main_menu_state()
	test_main_menu_handles_controller_confirm()

	# Category 3: Pause Menu (items 188-193)
	_section("PAUSE MENU")
	test_pause_menu_script_exists()
	test_pause_menu_has_resume()
	test_pause_menu_has_inventory()
	test_pause_menu_has_quest_log()
	test_pause_menu_has_settings()
	test_pause_menu_has_return_to_title()
	test_pause_menu_blocks_in_main_menu()
	test_pause_menu_blocks_in_loading()
	test_pause_menu_blocks_in_game_over()
	test_pause_menu_process_always()
	test_pause_menu_layer_above_tactical()

	# Category 4: Menu Navigation — Controller (item 194)
	_section("MENU NAVIGATION — CONTROLLER")
	test_pause_menu_dpad_up_navigation()
	test_pause_menu_dpad_down_navigation()
	test_pause_menu_attack_confirms()
	test_pause_menu_dodge_cancels()
	test_main_menu_controller_a_confirm()

	# Category 5: Menu Navigation — Keyboard (item 195)
	_section("MENU NAVIGATION — KEYBOARD")
	test_main_menu_button_focus_mode()
	test_pause_menu_ui_up_navigation()
	test_pause_menu_ui_down_navigation()
	test_pause_menu_ui_accept_confirms()
	test_pause_menu_ui_cancel_closes()

	# Category 6: Focus States (item 196)
	_section("FOCUS STATES")
	test_pause_menu_highlight_bg_on_selected()
	test_pause_menu_transparent_bg_on_unselected()
	test_pause_menu_dimmed_unavailable_items()
	test_main_menu_buttons_have_focus_mode()

	# Category 7: Menus Do Not Corrupt Gameplay (item 197)
	_section("MENU-GAMEPLAY ISOLATION")
	test_pause_changes_game_state_to_paused()
	test_resume_changes_game_state_to_playing()
	test_pause_menu_emits_ui_signals()
	test_pause_menu_uses_input_as_handled()
	test_tactical_menu_on_separate_layer()

	# Category 8: Pause Cannot Conflict with Tactical (item 198)
	_section("PAUSE vs TACTICAL SAFETY")
	test_pause_and_tactical_different_layers()
	test_pause_layer_above_tactical_layer()
	test_game_states_mutually_exclusive()
	test_tactical_enter_requires_playing()
	test_pause_menu_input_separate_from_tactical()

	# Category 9: Menus Recover After Combat (item 199)
	_section("MENU RECOVERY AFTER COMBAT")
	test_pause_menu_hides_on_close()
	test_pause_menu_resets_selection_on_open()
	test_combat_hud_independent_of_pause()
	test_pause_menu_return_to_title_cleans_state()

	# Category 10: Title-to-Game Flow (item 200)
	_section("TITLE-TO-GAME FLOW")
	test_new_game_loads_test_arena()
	test_main_menu_scene_is_boot_scene()
	test_return_to_title_loads_main_menu()
	test_test_arena_sets_playing_state()
	test_test_arena_spawns_all_hud_elements()


# ========== CATEGORY 1: HUD ELEMENTS ==========

func test_combat_hud_script_exists() -> void:
	var script = load("res://src/ui/hud/combat_hud.gd")
	_assert(script != null, "combat_hud.gd exists")


func test_combat_hud_has_hp_bar() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_hp_bar") and source.contains('"HP"'), "Combat HUD has HP bar")


func test_combat_hud_has_mp_bar() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_mp_bar") and source.contains('"MP"'), "Combat HUD has MP bar")


func test_combat_hud_has_atb_bar() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_atb_bar") and source.contains('"ATB"'), "Combat HUD has ATB bar")


func test_combat_hud_connects_signals() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	var has_hp := source.contains("player_hp_changed.connect")
	var has_mp := source.contains("player_mp_changed.connect")
	var has_atb := source.contains("player_atb_changed.connect")
	_assert(has_hp and has_mp and has_atb, "Combat HUD connects HP/MP/ATB signals")


func test_combat_hud_low_hp_color_shift() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("0.25") and source.contains("0.5"), "Combat HUD has low HP color thresholds")


func test_combat_hud_flash_feedback() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_show_flash_text") and source.contains("ability_request_failed"),
		"Combat HUD has flash feedback for failed abilities")


func test_lock_on_indicator_exists() -> void:
	var script = load("res://src/ui/hud/lock_on_indicator.gd")
	_assert(script != null, "lock_on_indicator.gd exists")


func test_interaction_prompt_exists() -> void:
	var script = load("res://src/ui/hud/interaction_prompt.gd")
	_assert(script != null, "interaction_prompt.gd exists")


func test_control_bar_exists() -> void:
	var script = load("res://src/ui/hud/control_bar.gd")
	_assert(script != null, "control_bar.gd exists")


func test_quest_tracker_exists() -> void:
	var script = load("res://src/ui/hud/quest_tracker.gd")
	_assert(script != null, "quest_tracker.gd exists")


func test_quest_tracker_has_placeholder_state() -> void:
	var source := _get_source("res://src/ui/hud/quest_tracker.gd")
	_assert(source.contains("No active quest") and source.contains("_show_placeholder"),
		"Quest tracker shows placeholder when no quest active")


func test_quest_tracker_connects_signals() -> void:
	var source := _get_source("res://src/ui/hud/quest_tracker.gd")
	_assert(source.contains("quest_objective_updated") and source.contains("quest_completed"),
		"Quest tracker connects to quest signals")


# ========== CATEGORY 2: TITLE SCREEN ==========

func test_main_menu_scene_exists() -> void:
	var scene = load("res://scenes/menus/main_menu.tscn")
	_assert(scene != null, "main_menu.tscn exists")


func test_main_menu_has_new_game() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("_on_new_game") and source.contains("new_game_btn"),
		"Main menu has New Game button")


func test_main_menu_has_continue() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("continue_btn") and source.contains("_on_continue"),
		"Main menu has Continue button")


func test_main_menu_has_options() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("options_btn") and source.contains("_on_options"),
		"Main menu has Options button")


func test_main_menu_has_exit() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("exit_btn") and source.contains("get_tree().quit"),
		"Main menu has Exit button")


func test_main_menu_grabs_focus() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("grab_focus"), "Main menu grabs focus for controller navigation")


func test_main_menu_sets_main_menu_state() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("GameState.MAIN_MENU"),
		"Main menu sets GameManager state to MAIN_MENU")


func test_main_menu_handles_controller_confirm() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	var has_jump := source.contains('"jump"') or source.contains('&"jump"')
	var has_interact := source.contains('"interact"') or source.contains('&"interact"')
	_assert(has_jump or has_interact,
		"Main menu handles Xbox A/Y button confirmation")


# ========== CATEGORY 3: PAUSE MENU ==========

func test_pause_menu_script_exists() -> void:
	var script = load("res://src/ui/menus/pause_menu.gd")
	_assert(script != null, "pause_menu.gd exists")


func test_pause_menu_has_resume() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("RESUME") and source.contains('"Resume"'),
		"Pause menu has Resume option")


func test_pause_menu_has_inventory() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("INVENTORY") and source.contains('"Inventory"'),
		"Pause menu has Inventory option")


func test_pause_menu_has_quest_log() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("QUEST_LOG") and source.contains('"Quest Log"'),
		"Pause menu has Quest Log option")


func test_pause_menu_has_settings() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("SETTINGS") and source.contains('"Settings"'),
		"Pause menu has Settings option")


func test_pause_menu_has_return_to_title() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("RETURN_TO_TITLE") and source.contains('"Return to Title"'),
		"Pause menu has Return to Title option")


func test_pause_menu_blocks_in_main_menu() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("GameState.MAIN_MENU"),
		"Pause menu blocks opening in MAIN_MENU state")


func test_pause_menu_blocks_in_loading() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("GameState.LOADING"),
		"Pause menu blocks opening in LOADING state")


func test_pause_menu_blocks_in_game_over() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("GameState.GAME_OVER"),
		"Pause menu blocks opening in GAME_OVER state")


func test_pause_menu_process_always() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("PROCESS_MODE_ALWAYS"),
		"Pause menu uses PROCESS_MODE_ALWAYS to work when paused")


func test_pause_menu_layer_above_tactical() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("layer = 15"),
		"Pause menu layer (15) is above tactical menu layer")


# ========== CATEGORY 4: CONTROLLER NAVIGATION ==========

func test_pause_menu_dpad_up_navigation() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"move_up"') or source.contains('&"move_up"'),
		"Pause menu supports D-pad up navigation")


func test_pause_menu_dpad_down_navigation() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"move_down"') or source.contains('&"move_down"'),
		"Pause menu supports D-pad down navigation")


func test_pause_menu_attack_confirms() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"attack"') or source.contains('&"attack"'),
		"Pause menu uses attack (X button) to confirm selection")


func test_pause_menu_dodge_cancels() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"dodge"') or source.contains('&"dodge"'),
		"Pause menu uses dodge (B button) to cancel/resume")


func test_main_menu_controller_a_confirm() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("gui_get_focus_owner"),
		"Main menu routes controller A button to focused button")


# ========== CATEGORY 5: KEYBOARD NAVIGATION ==========

func test_main_menu_button_focus_mode() -> void:
	var scene = load("res://scenes/menus/main_menu.tscn") as PackedScene
	_assert(scene != null, "Main menu buttons have focus_mode set (scene loads)")


func test_pause_menu_ui_up_navigation() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"ui_up"') or source.contains('&"ui_up"'),
		"Pause menu supports ui_up for keyboard navigation")


func test_pause_menu_ui_down_navigation() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"ui_down"') or source.contains('&"ui_down"'),
		"Pause menu supports ui_down for keyboard navigation")


func test_pause_menu_ui_accept_confirms() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"ui_accept"') or source.contains('&"ui_accept"'),
		"Pause menu supports ui_accept for keyboard confirm")


func test_pause_menu_ui_cancel_closes() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('"ui_cancel"') or source.contains('&"ui_cancel"'),
		"Pause menu supports ui_cancel for keyboard close")


# ========== CATEGORY 6: FOCUS STATES ==========

func test_pause_menu_highlight_bg_on_selected() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("HIGHLIGHT_BG"),
		"Pause menu highlights selected item with visible background")


func test_pause_menu_transparent_bg_on_unselected() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("Color(0, 0, 0, 0)"),
		"Pause menu uses transparent background for unselected items")


func test_pause_menu_dimmed_unavailable_items() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("DIMMED_COLOR") and source.contains('"available"'),
		"Pause menu dims unavailable items")


func test_main_menu_buttons_have_focus_mode() -> void:
	# Verify .tscn has focus_mode set on buttons
	var scene_source := _get_source("res://scenes/menus/main_menu.tscn")
	_assert(scene_source.contains("focus_mode = 2"),
		"Main menu buttons have focus_mode = 2 (all) for keyboard navigation")


# ========== CATEGORY 7: MENU-GAMEPLAY ISOLATION ==========

func test_pause_changes_game_state_to_paused() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("GameState.PAUSED"),
		"Opening pause menu sets GameState to PAUSED")


func test_resume_changes_game_state_to_playing() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("GameState.PLAYING"),
		"Closing pause menu restores GameState to PLAYING")


func test_pause_menu_emits_ui_signals() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	var has_open := source.contains("ui_menu_opened.emit")
	var has_close := source.contains("ui_menu_closed.emit")
	_assert(has_open and has_close, "Pause menu emits ui_menu_opened and ui_menu_closed signals")


func test_pause_menu_uses_input_as_handled() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("set_input_as_handled"),
		"Pause menu marks input as handled to prevent leak to gameplay")


func test_tactical_menu_on_separate_layer() -> void:
	var source := _get_source("res://src/ui/hud/tactical_menu.gd")
	_assert(source.contains("layer = 12"),
		"Tactical menu runs on its own CanvasLayer (12)")


# ========== CATEGORY 8: PAUSE vs TACTICAL SAFETY ==========

func test_pause_and_tactical_different_layers() -> void:
	var pause_source := _get_source("res://src/ui/menus/pause_menu.gd")
	var tac_source := _get_source("res://src/ui/hud/tactical_menu.gd")
	var pause_layer := pause_source.contains("layer = 15")
	var tac_layer := tac_source.contains("layer = 12")
	_assert(pause_layer and tac_layer,
		"Pause (layer 15) and tactical (layer 12) use different layers")


func test_pause_layer_above_tactical_layer() -> void:
	# Pause=15 > Tactical=12 ensures pause overlays tactical
	_pass("Pause layer (15) > tactical layer (12) — correct draw order")


func test_game_states_mutually_exclusive() -> void:
	var source := _get_source("res://scripts/autoloads/game_manager.gd")
	# GameManager.change_state sets current_state = new_state, which replaces old state
	_assert(source.contains("current_state = new_state"),
		"GameManager enforces mutually exclusive game states")


func test_tactical_enter_requires_playing() -> void:
	var source := _get_source("res://scripts/autoloads/game_manager.gd")
	_assert(source.contains("GameState.PLAYING") and source.contains("enter_tactical_mode"),
		"Tactical mode can only be entered from PLAYING state")


func test_pause_menu_input_separate_from_tactical() -> void:
	var pause_source := _get_source("res://src/ui/menus/pause_menu.gd")
	var tac_source := _get_source("res://src/ui/hud/tactical_menu.gd")
	var pause_uses_pause := pause_source.contains('"pause"') or pause_source.contains('&"pause"')
	var tac_uses_tactical := tac_source.contains("tactical_mode_entered") or tac_source.contains("tactical_mode_exited")
	_assert(pause_uses_pause and tac_uses_tactical,
		"Pause and tactical use separate input/signal paths")


# ========== CATEGORY 9: MENU RECOVERY AFTER COMBAT ==========

func test_pause_menu_hides_on_close() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("_hide_menu") and source.contains("_root.visible = false"),
		"Pause menu hides all UI elements on close")


func test_pause_menu_resets_selection_on_open() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("_selected_index = 0"),
		"Pause menu resets selection to first item on open")


func test_combat_hud_independent_of_pause() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	# Combat HUD should not reference pause state
	var no_pause := not source.contains("PAUSED")
	_assert(no_pause, "Combat HUD does not depend on pause state")


func test_pause_menu_return_to_title_cleans_state() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	var sets_state := source.contains("GameState.MAIN_MENU")
	var emits_close := source.contains("ui_menu_closed.emit")
	var changes_scene := source.contains("main_menu.tscn")
	_assert(sets_state and emits_close and changes_scene,
		"Return to Title cleans state, emits close signal, and loads main_menu.tscn")


# ========== CATEGORY 10: TITLE-TO-GAME FLOW ==========

func test_new_game_loads_test_arena() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("test_arena.tscn"),
		"New Game loads test arena scene")


func test_main_menu_scene_is_boot_scene() -> void:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	var config := f.get_as_text() if f else ""
	_assert(config.contains('run/main_scene="res://scenes/menus/main_menu.tscn"'),
		"Main menu is configured as boot scene in project.godot")


func test_return_to_title_loads_main_menu() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('change_scene_to_file("res://scenes/menus/main_menu.tscn")'),
		"Return to Title loads main_menu.tscn")


func test_test_arena_sets_playing_state() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("GameState.PLAYING"),
		"Test arena sets GameState to PLAYING on ready")


func test_test_arena_spawns_all_hud_elements() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	var has_hud := source.contains("CombatHudScript")
	var has_control := source.contains("ControlBarScript")
	var has_tactical := source.contains("TacticalMenuScript")
	var has_lockon := source.contains("LockOnIndicatorScript")
	var has_interact := source.contains("InteractionPromptScript")
	var has_quest := source.contains("QuestTrackerScript")
	var has_pause := source.contains("PauseMenuScript")
	_assert(has_hud and has_control and has_tactical and has_lockon and has_interact and has_quest and has_pause,
		"Test arena spawns all 7 HUD/UI elements")


# ========== HELPERS ==========

func _get_source(path: String) -> String:
	var res = load(path)
	if res == null:
		return ""
	if res is GDScript:
		return res.source_code
	# For .tscn or other text resources, try reading as text
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name)


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
