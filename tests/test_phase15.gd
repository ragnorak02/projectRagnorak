## Phase 15 tests: Polish, QA, and Regression (items 366-400).
## Covers UX/Accessibility (373-378), settings system, and regression checks.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 15: Polish, QA & Regression Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 15 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: SettingsManager Core (item 373-376 infrastructure)
	_section("SETTINGS MANAGER CORE")
	test_settings_manager_script_exists()
	test_settings_manager_is_autoload()
	test_settings_manager_process_mode()
	test_settings_manager_has_save_load()
	test_settings_manager_has_apply()
	test_settings_manager_has_reset()
	test_settings_manager_settings_changed_signal()

	# Category 2: Camera Sensitivity Settings (item 373)
	_section("CAMERA SENSITIVITY (ITEM 373)")
	test_mouse_sensitivity_setting()
	test_controller_sensitivity_setting()
	test_camera_shake_setting()
	test_camera_rig_uses_sensitivity()
	test_input_manager_sensitivity_default()
	test_apply_updates_input_manager()

	# Category 3: Controller Rebinding (item 374)
	_section("CONTROLLER REBINDING (ITEM 374)")
	test_rebindable_actions_defined()
	test_rebind_action_method()
	test_get_action_keyboard_text()
	test_get_action_controller_text()
	test_joy_button_name_mapping()
	test_joy_axis_name_mapping()
	test_mouse_button_name_mapping()
	test_serialize_bindings()
	test_deserialize_event_key()
	test_deserialize_event_joy_button()
	test_deserialize_event_joy_axis()
	test_deserialize_event_mouse()

	# Category 4: Audio Volume Settings (item 375)
	_section("AUDIO VOLUME SETTINGS (ITEM 375)")
	test_music_volume_setting()
	test_sfx_volume_setting()
	test_apply_sets_audio_volumes()
	test_volume_range_valid()

	# Category 5: Gameplay Settings Hooks (item 376)
	_section("GAMEPLAY SETTINGS HOOKS (ITEM 376)")
	test_show_damage_numbers_setting()
	test_show_control_hints_setting()
	test_gameplay_settings_in_save()

	# Category 6: Settings Menu UI
	_section("SETTINGS MENU UI")
	test_settings_menu_script_exists()
	test_settings_menu_layer()
	test_settings_menu_has_open_close()
	test_settings_menu_row_types()
	test_settings_menu_sections()
	test_settings_menu_slider_rows()
	test_settings_menu_toggle_rows()
	test_settings_menu_keybind_rows()
	test_settings_menu_hint_bar()
	test_settings_menu_rebinding_mode()
	test_settings_menu_closed_signal()
	test_settings_menu_colors()

	# Category 7: Pause Menu Integration
	_section("PAUSE MENU — SETTINGS INTEGRATION")
	test_pause_menu_settings_available()
	test_pause_menu_settings_preload()
	test_pause_menu_open_settings_method()

	# Category 8: Main Menu Integration
	_section("MAIN MENU — OPTIONS INTEGRATION")
	test_main_menu_options_preload()
	test_main_menu_options_wired()

	# Category 9: Settings Persistence
	_section("SETTINGS PERSISTENCE")
	test_settings_save_path()
	test_settings_json_structure()
	test_settings_bindings_serialization()

	# Category 10: Text Readability (item 377)
	_section("TEXT READABILITY (ITEM 377)")
	test_settings_menu_font_sizes()
	test_pause_menu_font_sizes()
	test_combat_hud_font_sizes()
	test_hint_bar_readable()

	# Category 11: Menu Focus Clarity (item 378)
	_section("MENU FOCUS CLARITY (ITEM 378)")
	test_settings_highlight_color_visible()
	test_pause_menu_highlight_color_visible()
	test_section_headers_distinct()
	test_active_vs_dimmed_contrast()
	test_rebind_color_visible()

	# Category 12: Combat Polish Regression (items 366-372)
	_section("COMBAT POLISH REGRESSION (ITEMS 366-372)")
	test_combo_system_exists()
	test_dodge_state_exists()
	test_jump_attack_exists()
	test_lock_on_system_exists()
	test_tactical_menu_exists()
	test_camera_rig_exists()
	test_camera_collision_handling()


# ========== CATEGORY 1: SETTINGS MANAGER CORE ==========

func test_settings_manager_script_exists() -> void:
	var script = load("res://scripts/autoloads/settings_manager.gd")
	_assert(script != null, "SettingsManager script exists")


func test_settings_manager_is_autoload() -> void:
	var source := _get_project_godot()
	_assert(source.contains('SettingsManager="*res://scripts/autoloads/settings_manager.gd"'),
		"SettingsManager registered as autoload")


func test_settings_manager_process_mode() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("PROCESS_MODE_ALWAYS"),
		"SettingsManager runs even when paused")


func test_settings_manager_has_save_load() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func save_settings()") and source.contains("func load_settings()"),
		"SettingsManager has save/load methods")


func test_settings_manager_has_apply() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func apply_settings()"),
		"SettingsManager has apply_settings method")


func test_settings_manager_has_reset() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func reset_defaults()") and source.contains("load_from_project_settings"),
		"SettingsManager has reset_defaults with InputMap restore")


func test_settings_manager_settings_changed_signal() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("signal settings_changed()") and source.contains("settings_changed.emit()"),
		"SettingsManager emits settings_changed signal")


# ========== CATEGORY 2: CAMERA SENSITIVITY (ITEM 373) ==========

func test_mouse_sensitivity_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var mouse_sensitivity: float = 0.002"),
		"SettingsManager has mouse_sensitivity with default 0.002")


func test_controller_sensitivity_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var controller_sensitivity: float = 1.0"),
		"SettingsManager has controller_sensitivity with default 1.0 multiplier")


func test_camera_shake_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var camera_shake: bool = true"),
		"SettingsManager has camera_shake toggle")


func test_camera_rig_uses_sensitivity() -> void:
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(source.contains("controller_camera_sensitivity") and source.contains("sens"),
		"CameraRig applies controller sensitivity multiplier")


func test_input_manager_sensitivity_default() -> void:
	var source := _get_source("res://scripts/autoloads/input_manager.gd")
	_assert(source.contains("controller_camera_sensitivity: float = 1.0"),
		"InputManager controller_camera_sensitivity defaults to 1.0 (multiplier)")


func test_apply_updates_input_manager() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("InputManager.mouse_sensitivity = mouse_sensitivity") and
		source.contains("InputManager.controller_camera_sensitivity = controller_sensitivity"),
		"apply_settings updates InputManager sensitivity values")


# ========== CATEGORY 3: CONTROLLER REBINDING (ITEM 374) ==========

func test_rebindable_actions_defined() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("REBINDABLE_ACTIONS") and
		source.contains('"jump"') and source.contains('"attack"') and
		source.contains('"dodge"') and source.contains('"interact"'),
		"Rebindable actions defined (jump, attack, dodge, interact)")


func test_rebind_action_method() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("func rebind_action(action: StringName, new_event: InputEvent)") and
		source.contains("action_erase_event") and source.contains("action_add_event"),
		"rebind_action replaces old event and adds new one")


func test_get_action_keyboard_text() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func get_action_keyboard_text(action: StringName) -> String"),
		"get_action_keyboard_text method exists")


func test_get_action_controller_text() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("func get_action_controller_text(action: StringName) -> String"),
		"get_action_controller_text method exists")


func test_joy_button_name_mapping() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('0: return "A"') and
		source.contains('1: return "B"') and
		source.contains('2: return "X"') and
		source.contains('3: return "Y"') and
		source.contains('9: return "LB"') and
		source.contains('10: return "RB"'),
		"Joy button names map correctly (A, B, X, Y, LB, RB)")


func test_joy_axis_name_mapping() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('4: return "LT"') and source.contains('5: return "RT"'),
		"Joy axis names map LT/RT correctly")


func test_mouse_button_name_mapping() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('1: return "LMB"') and
		source.contains('2: return "RMB"') and
		source.contains('3: return "MMB"'),
		"Mouse button names map correctly (LMB, RMB, MMB)")


func test_serialize_bindings() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("_serialize_bindings") and
		source.contains("_serialize_action_events") and
		source.contains('"type": "key"') and
		source.contains('"type": "joy_button"'),
		"Binding serialization supports key and joy_button types")


func test_deserialize_event_key() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"key":') and source.contains("InputEventKey.new()") and
		source.contains("event.keycode"),
		"Deserializes key events with keycode")


func test_deserialize_event_joy_button() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"joy_button":') and source.contains("InputEventJoypadButton.new()"),
		"Deserializes joypad button events")


func test_deserialize_event_joy_axis() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"joy_axis":') and source.contains("InputEventJoypadMotion.new()"),
		"Deserializes joypad axis events")


func test_deserialize_event_mouse() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"mouse":') and source.contains("InputEventMouseButton.new()"),
		"Deserializes mouse button events")


# ========== CATEGORY 4: AUDIO VOLUME SETTINGS (ITEM 375) ==========

func test_music_volume_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var music_volume: float = 1.0"),
		"SettingsManager has music_volume default 1.0")


func test_sfx_volume_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var sfx_volume: float = 1.0"),
		"SettingsManager has sfx_volume default 1.0")


func test_apply_sets_audio_volumes() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("AudioManager.set_music_volume(music_volume)") and
		source.contains("AudioManager.set_sfx_volume(sfx_volume)"),
		"apply_settings updates AudioManager volumes")


func test_volume_range_valid() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains('"min": 0.0, "max": 1.0, "step": 0.1'),
		"Volume sliders range 0.0 to 1.0 with 0.1 steps")


# ========== CATEGORY 5: GAMEPLAY SETTINGS HOOKS (ITEM 376) ==========

func test_show_damage_numbers_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var show_damage_numbers: bool = true"),
		"SettingsManager has show_damage_numbers toggle")


func test_show_control_hints_setting() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains("var show_control_hints: bool = true"),
		"SettingsManager has show_control_hints toggle")


func test_gameplay_settings_in_save() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"gameplay"') and
		source.contains('"show_damage_numbers"') and
		source.contains('"show_control_hints"'),
		"Gameplay settings included in save data")


# ========== CATEGORY 6: SETTINGS MENU UI ==========

func test_settings_menu_script_exists() -> void:
	var script = load("res://src/ui/menus/settings_menu.gd")
	_assert(script != null, "SettingsMenu script exists")


func test_settings_menu_layer() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(source.contains("layer = 17"),
		"SettingsMenu at layer 17 (above pause menu)")


func test_settings_menu_has_open_close() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("func open_menu()") and source.contains("func close_menu()"),
		"SettingsMenu has open_menu and close_menu methods")


func test_settings_menu_row_types() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("RowType.SECTION") and
		source.contains("RowType.SLIDER") and
		source.contains("RowType.TOGGLE") and
		source.contains("RowType.KEYBIND"),
		"SettingsMenu supports SECTION, SLIDER, TOGGLE, KEYBIND row types")


func test_settings_menu_sections() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains('"CAMERA"') and
		source.contains('"AUDIO"') and
		source.contains('"CONTROLS"') and
		source.contains('"GAMEPLAY"'),
		"SettingsMenu has Camera, Audio, Controls, Gameplay sections")


func test_settings_menu_slider_rows() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains('"Mouse Sensitivity"') and
		source.contains('"Controller Camera"') and
		source.contains('"Music Volume"') and
		source.contains('"SFX Volume"'),
		"SettingsMenu has all slider rows")


func test_settings_menu_toggle_rows() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains('"Camera Shake"') and
		source.contains('"Damage Numbers"') and
		source.contains('"Control Hints"'),
		"SettingsMenu has toggle rows for gameplay options")


func test_settings_menu_keybind_rows() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains('"Jump"') and source.contains('"action": "jump"') and
		source.contains('"Attack"') and source.contains('"action": "attack"') and
		source.contains('"Dodge"') and source.contains('"action": "dodge"') and
		source.contains('"Party Switch"') and source.contains('"action": "party_switch"'),
		"SettingsMenu has keybind rows for all rebindable actions")


func test_settings_menu_hint_bar() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("_hint_label") and
		source.contains("Adjust") and source.contains("Defaults") and source.contains("Back"),
		"SettingsMenu has context-sensitive hint bar")


func test_settings_menu_rebinding_mode() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("_rebinding") and
		source.contains("_handle_rebind_input") and
		source.contains("Press key/button...") and
		source.contains("_cancel_rebind"),
		"SettingsMenu has rebinding mode with prompt and cancel")


func test_settings_menu_closed_signal() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(source.contains("signal closed()") and source.contains("closed.emit()"),
		"SettingsMenu emits closed signal")


func test_settings_menu_colors() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("PANEL_BG") and
		source.contains("HIGHLIGHT_BG") and
		source.contains("SECTION_COLOR") and
		source.contains("BAR_FILL"),
		"SettingsMenu uses themed colors (panel, highlight, section, bar)")


# ========== CATEGORY 7: PAUSE MENU INTEGRATION ==========

func test_pause_menu_settings_available() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(
		source.contains('"Settings"') and
		source.contains('"available": true') and
		not source.contains('{ "id": MenuItem.SETTINGS, "label": "Settings", "available": false }'),
		"Pause menu Settings item is available (not placeholder)")


func test_pause_menu_settings_preload() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("SettingsMenuScript") and source.contains("settings_menu.gd"),
		"Pause menu preloads SettingsMenuScript")


func test_pause_menu_open_settings_method() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(
		source.contains("func _open_settings()") and
		source.contains("MenuItem.SETTINGS") and
		source.contains("_open_settings()"),
		"Pause menu has _open_settings method wired to SETTINGS item")


# ========== CATEGORY 8: MAIN MENU INTEGRATION ==========

func test_main_menu_options_preload() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("SettingsMenuScript") and source.contains("settings_menu.gd"),
		"Main menu preloads SettingsMenuScript")


func test_main_menu_options_wired() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(
		source.contains("_on_options") and
		source.contains("open_menu") and
		not source.contains("func _on_options() -> void:\n\tpass"),
		"Main menu Options button wired to open settings (not placeholder)")


# ========== CATEGORY 9: SETTINGS PERSISTENCE ==========

func test_settings_save_path() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(source.contains('SETTINGS_PATH := "user://settings.json"'),
		"Settings save to user://settings.json")


func test_settings_json_structure() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains('"camera"') and
		source.contains('"audio"') and
		source.contains('"gameplay"') and
		source.contains('"bindings"'),
		"Settings JSON has camera, audio, gameplay, bindings sections")


func test_settings_bindings_serialization() -> void:
	var source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		source.contains("_deserialize_bindings") and
		source.contains("action_erase_events") and
		source.contains("action_add_event"),
		"Bindings deserialization rebuilds InputMap")


# ========== CATEGORY 10: TEXT READABILITY (ITEM 377) ==========

func test_settings_menu_font_sizes() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	# Title: 24, section: 14, items: 16, values: 14, hints: 12
	_assert(
		source.contains('"font_size", 24') and  # title
		source.contains('"font_size", 16') and  # item labels
		source.contains('"font_size", 14') and  # section headers, values
		source.contains('"font_size", 12'),      # hint bar
		"Settings menu uses readable font sizes (12-24px)")


func test_pause_menu_font_sizes() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(
		source.contains('"font_size", 24') and  # title
		source.contains('"font_size", 18') and  # items
		source.contains('"font_size", 11'),      # hints (minimum)
		"Pause menu uses readable font sizes (11-24px)")


func test_combat_hud_font_sizes() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	# Just check that font sizes exist and are reasonable
	_assert(source.contains("font_size"),
		"Combat HUD sets explicit font sizes")


func test_hint_bar_readable() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	# Hint text at 12px is the minimum readable size
	_assert(
		source.contains('"font_size", 12') and
		source.contains("DIMMED_COLOR"),
		"Hint bar uses minimum readable size (12px) with distinct color")


# ========== CATEGORY 11: MENU FOCUS CLARITY (ITEM 378) ==========

func test_settings_highlight_color_visible() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	# HIGHLIGHT_BG should have visible alpha and distinct from transparent
	_assert(
		source.contains("HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)"),
		"Settings highlight uses visible blue with 0.9 alpha")


func test_pause_menu_highlight_color_visible() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(
		source.contains("HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)"),
		"Pause menu highlight uses visible blue with 0.9 alpha")


func test_section_headers_distinct() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("SECTION_COLOR := Color(0.9, 0.7, 0.1)"),
		"Section headers use distinct ember/gold color")


func test_active_vs_dimmed_contrast() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	# TEXT_COLOR should be bright, DIMMED_COLOR should be notably darker
	_assert(
		source.contains("TEXT_COLOR := Color(0.85, 0.9, 1.0)") and
		source.contains("DIMMED_COLOR := Color(0.4, 0.4, 0.5)"),
		"Active text (0.85+) vs dimmed (0.4) has sufficient contrast")


func test_rebind_color_visible() -> void:
	var source := _get_source("res://src/ui/menus/settings_menu.gd")
	_assert(
		source.contains("REBIND_COLOR := Color(1.0, 0.8, 0.2)"),
		"Rebind prompt uses bright gold color for visibility")


# ========== CATEGORY 12: COMBAT POLISH REGRESSION (ITEMS 366-372) ==========

func test_combo_system_exists() -> void:
	var script = load("res://src/player/states/attack_1_state.gd")
	_assert(script != null, "Attack combo states exist (combo polish)")


func test_dodge_state_exists() -> void:
	var script = load("res://src/player/states/dodge_state.gd")
	_assert(script != null, "DodgeState script exists (dodge polish)")


func test_jump_attack_exists() -> void:
	var script = load("res://src/player/states/jump_attack_state.gd")
	_assert(script != null, "JumpAttackState script exists (jump attack polish)")


func test_lock_on_system_exists() -> void:
	var script = load("res://src/player/components/lock_on_component.gd")
	_assert(script != null, "LockOnComponent script exists (lock-on polish)")


func test_tactical_menu_exists() -> void:
	var script = load("res://src/ui/hud/tactical_menu.gd")
	_assert(script != null, "TacticalMenu script exists (tactical polish)")


func test_camera_rig_exists() -> void:
	var script = load("res://src/camera/camera_rig.gd")
	_assert(script != null, "CameraRig script exists (camera polish)")


func test_camera_collision_handling() -> void:
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(
		source.contains("SpringArm3D") and source.contains("margin"),
		"CameraRig uses SpringArm3D with margin for collision smoothing")


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


func _get_project_godot() -> String:
	if FileAccess.file_exists("res://project.godot"):
		var f := FileAccess.open("res://project.godot", FileAccess.READ)
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
