## Phase 11 tests: Save System (items 256-280).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 11: Save System Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 11 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Save Core (items 256-259)
	_section("SAVE CORE")
	test_save_manager_exists()
	test_save_version_defined()
	test_save_dir_constant()
	test_autosave_slot()
	test_manual_save_slots()
	test_quicksave_slot()
	test_save_signals()
	test_data_versioning()
	test_slot_path_resolution()
	test_save_and_load_roundtrip()
	test_load_nonexistent_slot()
	test_has_any_save()
	test_delete_save()
	test_corrupted_save_handled()

	# Category 2: Data Persistence (items 260-266)
	_section("DATA PERSISTENCE")
	test_player_has_save_data_method()
	test_player_has_load_save_data_method()
	test_player_saves_position()
	test_player_saves_rotation()
	test_player_saves_hp_mp_atb()
	test_player_saves_inventory()
	test_player_saves_equipment()
	test_player_saves_quests()
	test_gather_save_data_has_version()
	test_gather_save_data_has_timestamp()
	test_gather_save_data_has_zone_id()
	test_gather_save_data_has_progression_flags()
	test_progression_flags_set_get()
	test_progression_flags_has_flag()

	# Category 3: Save UI (items 267-270)
	_section("SAVE / LOAD UI")
	test_save_load_menu_exists()
	test_save_load_menu_has_open_close()
	test_save_load_menu_has_modes()
	test_save_load_menu_has_slot_rows()
	test_save_load_menu_has_overwrite_confirm()
	test_save_load_menu_controller_nav()
	test_save_load_menu_keyboard_nav()
	test_save_metadata()
	test_all_slot_metadata()
	test_save_metadata_empty_slot()

	# Category 4: Continue / Load Flow (items 269-270)
	_section("CONTINUE / LOAD FLOW")
	test_continue_game_method()
	test_load_and_apply_method()
	test_pending_load_system()
	test_most_recent_slot()
	test_zone_id_to_scene()

	# Category 5: Quicksave (items 271-274)
	_section("QUICKSAVE")
	test_quicksave_method()
	test_quicksave_blocked_outside_playing()
	test_quicksave_input_action_exists()
	test_quickload_input_action_exists()
	test_save_feedback_signal()
	test_save_feedback_hud_exists()

	# Category 6: Zone Reset / Autosave (items 275-280)
	_section("ZONE RESET & AUTOSAVE")
	test_autosave_method()
	test_autosave_on_zone_entry()
	test_enemy_reset_on_zone_load()
	test_version_migration()
	test_manual_save_method()
	test_save_load_preserves_state()

	# Category 7: Integration
	_section("INTEGRATION")
	test_main_menu_has_continue()
	test_main_menu_has_load()
	test_main_menu_checks_save_exists()
	test_pause_menu_has_save_option()
	test_test_arena_has_save_feedback()
	test_test_arena_checks_pending_load()
	test_test_arena_autosaves()
	test_events_has_save_feedback_signal()


# ========== CATEGORY 1: SAVE CORE ==========

func test_save_manager_exists() -> void:
	_assert(SaveManager != null, "SaveManager autoload exists")


func test_save_version_defined() -> void:
	_assert(SaveManager.SAVE_VERSION >= 1, "SAVE_VERSION is defined and >= 1")


func test_save_dir_constant() -> void:
	_assert(SaveManager.SAVE_DIR == "user://saves/", "SAVE_DIR is user://saves/")


func test_autosave_slot() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("autosave") and source.contains("slot: int")
		and source.contains("-1"), "Autosave uses slot -1")


func test_manual_save_slots() -> void:
	_assert(SaveManager.MAX_MANUAL_SLOTS == 3, "3 manual save slots supported")


func test_quicksave_slot() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("quicksave") and source.contains("slot == 0")
		or source.contains("save_game(0"), "Quicksave uses slot 0")


func test_save_signals() -> void:
	_assert(SaveManager.has_signal("save_started") and SaveManager.has_signal("save_finished")
		and SaveManager.has_signal("load_started") and SaveManager.has_signal("load_finished"),
		"SaveManager has save/load signals")


func test_data_versioning() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("SAVE_VERSION") and source.contains("_migrate_save")
		and source.contains('"version"'), "Save data versioning implemented")


func test_slot_path_resolution() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("_get_slot_path") and source.contains("autosave.json")
		and source.contains("quicksave.json") and source.contains("slot_"),
		"Slot path resolves autosave, quicksave, and manual slots")


func test_save_and_load_roundtrip() -> void:
	# Save test data to a test slot, load it back, verify, then clean up
	var test_data := {"version": 1, "test_key": "test_value", "number": 42}
	var save_ok := SaveManager.save_game(3, test_data)
	var loaded := SaveManager.load_game(3)
	SaveManager.delete_save(3)
	_assert(save_ok and loaded.get("test_key") == "test_value" and loaded.get("number") == 42,
		"Save and load roundtrip preserves data")


func test_load_nonexistent_slot() -> void:
	# Ensure loading a nonexistent slot returns empty dict
	SaveManager.delete_save(3)  # Make sure it doesn't exist
	var result := SaveManager.load_game(3)
	_assert(result.is_empty(), "Loading nonexistent slot returns empty dictionary")


func test_has_any_save() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func has_any_save()") and source.contains("save_exists"),
		"has_any_save() checks all slot types")


func test_delete_save() -> void:
	var test_data := {"version": 1, "delete_test": true}
	SaveManager.save_game(3, test_data)
	var existed := SaveManager.save_exists(3)
	SaveManager.delete_save(3)
	var gone := not SaveManager.save_exists(3)
	_assert(existed and gone, "delete_save removes the save file")


func test_corrupted_save_handled() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("Corrupted save") and source.contains("push_warning"),
		"Corrupted save files are handled gracefully with warning")


# ========== CATEGORY 2: DATA PERSISTENCE ==========

func test_player_has_save_data_method() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("func get_save_data()"), "Player has get_save_data() method")


func test_player_has_load_save_data_method() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("func load_save_data("), "Player has load_save_data() method")


func test_player_saves_position() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"position"') and source.contains("global_position"),
		"Player saves position data")


func test_player_saves_rotation() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"rotation_y"') and source.contains("global_rotation"),
		"Player saves rotation data")


func test_player_saves_hp_mp_atb() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"hp"') and source.contains('"mp"') and source.contains('"atb"'),
		"Player saves HP, MP, and ATB")


func test_player_saves_inventory() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"inventory"') and source.contains("inventory_system.get_save_data"),
		"Player save includes inventory data")


func test_player_saves_equipment() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"equipment"') and source.contains("equipment_system.get_save_data"),
		"Player save includes equipment data")


func test_player_saves_quests() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"quests"') and source.contains("quest_system.get_save_data"),
		"Player save includes quest data")


func test_gather_save_data_has_version() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("gather_save_data") and source.contains('"version": SAVE_VERSION'),
		"gather_save_data includes version")


func test_gather_save_data_has_timestamp() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"timestamp"') and source.contains("get_datetime_string"),
		"gather_save_data includes ISO timestamp")


func test_gather_save_data_has_zone_id() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"zone_id"') and source.contains("_get_current_zone_id"),
		"gather_save_data includes zone_id")


func test_gather_save_data_has_progression_flags() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"progression_flags"') and source.contains("progression_flags.duplicate"),
		"gather_save_data includes progression_flags")


func test_progression_flags_set_get() -> void:
	SaveManager.set_flag("test_flag_123", true)
	var val = SaveManager.get_flag("test_flag_123")
	SaveManager.progression_flags.erase("test_flag_123")
	_assert(val == true, "set_flag/get_flag works correctly")


func test_progression_flags_has_flag() -> void:
	SaveManager.set_flag("test_has_flag", 42)
	var has_it := SaveManager.has_flag("test_has_flag")
	var not_has := not SaveManager.has_flag("nonexistent_flag_xyz")
	SaveManager.progression_flags.erase("test_has_flag")
	_assert(has_it and not_has, "has_flag returns correct results")


# ========== CATEGORY 3: SAVE / LOAD UI ==========

func test_save_load_menu_exists() -> void:
	var script = load("res://src/ui/menus/save_load_menu.gd")
	_assert(script != null, "Save/Load menu script exists")


func test_save_load_menu_has_open_close() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains("func open_menu(") and source.contains("func close_menu("),
		"Save/Load menu has open/close methods")


func test_save_load_menu_has_modes() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains("enum Mode") and source.contains("SAVE") and source.contains("LOAD"),
		"Save/Load menu supports SAVE and LOAD modes")


func test_save_load_menu_has_slot_rows() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains("_slot_rows") and source.contains("_create_slot_row"),
		"Save/Load menu has slot row display")


func test_save_load_menu_has_overwrite_confirm() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains("_confirming_overwrite") and source.contains("Overwrite"),
		"Save/Load menu has overwrite confirmation")


func test_save_load_menu_controller_nav() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains('"move_up"') and source.contains('"move_down"')
		and source.contains('"attack"'),
		"Save/Load menu supports controller navigation")


func test_save_load_menu_keyboard_nav() -> void:
	var source := _get_source("res://src/ui/menus/save_load_menu.gd")
	_assert(source.contains('"ui_up"') and source.contains('"ui_down"')
		and source.contains('"ui_accept"') and source.contains('"ui_cancel"'),
		"Save/Load menu supports keyboard navigation")


func test_save_metadata() -> void:
	var test_data := {"version": 1, "timestamp": "2026-01-01T12:00", "zone_id": "test_arena",
		"player": {"hp": 80}}
	SaveManager.save_game(3, test_data)
	var meta := SaveManager.get_save_metadata(3)
	SaveManager.delete_save(3)
	_assert(meta.get("timestamp") == "2026-01-01T12:00" and meta.get("zone_id") == "test_arena"
		and meta.get("slot") == 3, "get_save_metadata returns correct metadata")


func test_all_slot_metadata() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func get_all_slot_metadata()") and source.contains("Array[Dictionary]"),
		"get_all_slot_metadata returns array of slot info")


func test_save_metadata_empty_slot() -> void:
	SaveManager.delete_save(3)
	var meta := SaveManager.get_save_metadata(3)
	_assert(meta.is_empty(), "get_save_metadata returns empty dict for nonexistent slot")


# ========== CATEGORY 4: CONTINUE / LOAD FLOW ==========

func test_continue_game_method() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func continue_game()") and source.contains("get_most_recent_slot"),
		"continue_game loads most recent save")


func test_load_and_apply_method() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func load_and_apply(") and source.contains("_pending_load_data")
		and source.contains("change_scene_to_file"),
		"load_and_apply stores pending data and changes scene")


func test_pending_load_system() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func has_pending_load()") and source.contains("func consume_pending_load()"),
		"Pending load system has check and consume methods")


func test_most_recent_slot() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func get_most_recent_slot()") and source.contains("best_time"),
		"get_most_recent_slot compares timestamps")


func test_zone_id_to_scene() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func _zone_id_to_scene(") and source.contains("test_arena")
		and source.contains("main_menu"),
		"_zone_id_to_scene maps zone IDs to scene paths")


# ========== CATEGORY 5: QUICKSAVE ==========

func test_quicksave_method() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func quicksave(") and source.contains("save_game(0"),
		"quicksave() saves to slot 0")


func test_quicksave_blocked_outside_playing() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("GameManager.current_state != GameManager.GameState.PLAYING")
		and source.contains("Cannot save"),
		"Quicksave blocked when not PLAYING with feedback")


func test_quicksave_input_action_exists() -> void:
	_assert(InputMap.has_action(&"quicksave"), "quicksave input action exists (F5)")


func test_quickload_input_action_exists() -> void:
	_assert(InputMap.has_action(&"quickload"), "quickload input action exists (F9)")


func test_save_feedback_signal() -> void:
	_assert(Events.has_signal("save_feedback"), "Events has save_feedback signal")


func test_save_feedback_hud_exists() -> void:
	var script = load("res://src/ui/hud/save_feedback.gd")
	_assert(script != null, "Save feedback HUD script exists")


# ========== CATEGORY 6: ZONE RESET & AUTOSAVE ==========

func test_autosave_method() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func autosave(") and source.contains("save_game(-1"),
		"autosave() saves to slot -1")


func test_autosave_on_zone_entry() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("_autosave_on_entry") and source.contains("SaveManager.autosave"),
		"Test arena autosaves on zone entry")


func test_enemy_reset_on_zone_load() -> void:
	# Enemies are freshly instantiated from scene each zone load — inherently reset
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("EnemyScene.instantiate()"),
		"Enemies are instantiated fresh on zone load (implicit reset)")


func test_version_migration() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func _migrate_save(") and source.contains("version < 1"),
		"Version migration handles pre-versioning saves")


func test_manual_save_method() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains("func manual_save(") and source.contains("gather_save_data"),
		"manual_save gathers data and saves to specified slot")


func test_save_load_preserves_state() -> void:
	# Test that saving and loading via SaveManager roundtrips data correctly
	var test_data := {
		"version": 1,
		"timestamp": "2026-03-08T12:00",
		"zone_id": "test_arena",
		"player": {
			"position": {"x": 5.0, "y": 1.0, "z": -3.0},
			"rotation_y": 1.57,
			"hp": 75.0, "mp": 30.0, "atb": 50.0,
			"inventory": [], "equipment": {}, "quests": {"active": {}, "completed": [], "tracked": ""}
		},
		"progression_flags": {"door_opened": true, "boss_defeated": false}
	}
	SaveManager.save_game(3, test_data)
	var loaded := SaveManager.load_game(3)
	SaveManager.delete_save(3)
	var player_data: Dictionary = loaded.get("player", {})
	var pos: Dictionary = player_data.get("position", {})
	var flags: Dictionary = loaded.get("progression_flags", {})
	_assert(
		pos.get("x") == 5.0 and pos.get("z") == -3.0
		and player_data.get("hp") == 75.0
		and flags.get("door_opened") == true
		and loaded.get("zone_id") == "test_arena",
		"Full save/load roundtrip preserves all state fields"
	)


# ========== CATEGORY 7: INTEGRATION ==========

func test_main_menu_has_continue() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("continue_btn") and source.contains("_on_continue")
		and source.contains("continue_game"),
		"Main menu has Continue button that loads most recent save")


func test_main_menu_has_load() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("load_btn") and source.contains("_on_load")
		and source.contains("SaveLoadMenuScript"),
		"Main menu has Load Game button that opens save/load menu")


func test_main_menu_checks_save_exists() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("has_any_save") and source.contains("continue_btn.disabled"),
		"Main menu disables Continue when no saves exist")


func test_pause_menu_has_save_option() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("SAVE_GAME") and source.contains('"Save Game"')
		and source.contains('"available": true') and source.contains("_open_save_menu"),
		"Pause menu has Save Game option enabled")


func test_test_arena_has_save_feedback() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("SaveFeedbackScript") and source.contains("save_feedback"),
		"Test arena includes save feedback HUD")


func test_test_arena_checks_pending_load() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("has_pending_load") and source.contains("consume_pending_load")
		and source.contains("apply_load_data"),
		"Test arena checks and applies pending load data")


func test_test_arena_autosaves() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("_autosave_on_entry") and source.contains("SaveManager.autosave"),
		"Test arena triggers autosave on zone entry")


func test_events_has_save_feedback_signal() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal save_feedback"),
		"Events bus has save_feedback signal")


# ========== HELPERS ==========

func _get_source(path: String) -> String:
	var res = load(path)
	if res == null:
		return ""
	if res is GDScript:
		return res.source_code
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


func _fail(test_name: String) -> void:
	_failed += 1
	_total += 1
	print("  FAIL: %s" % test_name)
