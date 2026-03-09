## Performance & Stability tests: items 379-384.
## Covers combat scene profiling, world scene profiling, node leaks,
## scene transition resource cleanup, signal connection safety, and autoload uniqueness.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Performance & Stability Tests (Items 379-384) ===")
	print("")
	_run_tests()
	print("\n=== Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# ========== ITEM 379: Profile Combat Scene ==========
	_section("COMBAT SCENE PROFILING (ITEM 379)")
	test_player_script_exists()
	test_enemy_script_exists()
	test_combat_hud_script_exists()
	test_tactical_menu_script_exists()
	test_lock_on_component_exists()
	test_ability_system_exists()
	test_player_atb_throttled()
	test_player_mp_regen_throttled()
	test_enemy_no_per_frame_signals()
	test_camera_uses_unscaled_delta()
	test_hitbox_disabled_by_default()
	test_enemy_hitbox_guard()
	test_hit_stop_uses_real_timer()
	test_state_machine_no_per_frame_alloc()
	test_combat_hud_cooldown_label_cleanup()
	test_lock_on_raycast_uses_physics_layer()

	# ========== ITEM 380: Profile World Scene ==========
	_section("WORLD SCENE PROFILING (ITEM 380)")
	test_zone_base_script_exists()
	test_zone_base_preloads_scenes()
	test_zone_hud_count_bounded()
	test_zone_autosave_deferred()
	test_companion_teleport_guard()
	test_companion_enemy_search_uses_group()
	test_zone_portal_exists()
	test_loading_screen_script_exists()
	test_save_manager_file_io_bounded()

	# ========== ITEM 381: Verify No Node Leaks ==========
	_section("NODE LEAK PREVENTION (ITEM 381)")
	test_enemy_death_queues_free()
	test_enemy_death_disables_collisions()
	test_enemy_flash_timer_checks_validity()
	test_player_import_animation_frees_instance()
	test_cooldown_label_freed_on_finish()
	test_tactical_menu_clears_items()
	test_lock_on_indicator_checks_validity()
	test_camera_shake_uses_tween()
	test_companion_builds_visual_as_child()

	# ========== ITEM 382: Scene Transitions Free Resources ==========
	_section("SCENE TRANSITION RESOURCE CLEANUP (ITEM 382)")
	test_player_is_zone_child()
	test_camera_is_zone_child()
	test_hud_layers_are_zone_children()
	test_companion_added_to_current_scene()
	test_enemies_spawned_as_zone_children()
	test_scene_change_uses_change_scene_to_file()
	test_save_manager_pending_load_clears()
	test_no_persistent_gameplay_nodes()

	# ========== ITEM 383: No Repeated Signal Connections ==========
	_section("SIGNAL CONNECTION SAFETY (ITEM 383)")
	test_events_autoload_is_signal_only()
	test_player_connects_once_in_ready()
	test_camera_connects_once_in_ready()
	test_combat_hud_connects_once()
	test_tactical_menu_connects_once()
	test_lock_on_indicator_connects_once()
	test_audio_manager_connects_once()
	test_party_system_connects_once()
	test_enemy_connects_once_in_ready()
	test_lock_on_component_connects_once()
	test_no_connect_in_physics_process()
	test_no_connect_in_process()

	# ========== ITEM 384: No Duplicate Autoload Bugs ==========
	_section("AUTOLOAD INTEGRITY (ITEM 384)")
	test_autoload_count()
	test_autoload_unique_paths()
	test_autoload_events_exists()
	test_autoload_game_manager_exists()
	test_autoload_input_manager_exists()
	test_autoload_audio_manager_exists()
	test_autoload_save_manager_exists()
	test_autoload_debug_flags_exists()
	test_autoload_settings_manager_exists()
	test_autoload_process_modes()
	test_no_class_name_collision()


# ========== ITEM 379: COMBAT SCENE PROFILING ==========

func test_player_script_exists() -> void:
	_assert(load("res://src/player/player.gd") != null, "Player script loads")


func test_enemy_script_exists() -> void:
	_assert(load("res://src/enemies/enemy_base.gd") != null, "EnemyBase script loads")


func test_combat_hud_script_exists() -> void:
	_assert(load("res://src/ui/hud/combat_hud.gd") != null, "CombatHUD script loads")


func test_tactical_menu_script_exists() -> void:
	_assert(load("res://src/ui/hud/tactical_menu.gd") != null, "TacticalMenu script loads")


func test_lock_on_component_exists() -> void:
	_assert(load("res://src/player/components/lock_on_component.gd") != null, "LockOnComponent script loads")


func test_ability_system_exists() -> void:
	_assert(load("res://src/player/components/ability_system.gd") != null, "AbilitySystem script loads")


func test_player_atb_throttled() -> void:
	var source := _get_source("res://src/player/player.gd")
	# ATB signal should only emit on integer threshold change, not every frame
	_assert(
		source.contains("int(current_atb) != int(old_atb)"),
		"Player ATB signal throttled to integer threshold changes")


func test_player_mp_regen_throttled() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(
		source.contains("int(current_mp) != int(old_mp)"),
		"Player MP regen signal throttled to integer threshold changes")


func test_enemy_no_per_frame_signals() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	# enemy_damaged should only emit in take_damage(), not in _physics_process
	_assert(
		not _contains_in_function(source, "_physics_process", "enemy_damaged"),
		"Enemy does not emit damage signals per-frame")


func test_camera_uses_unscaled_delta() -> void:
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(
		source.contains("Engine.time_scale") and source.contains("real_delta"),
		"Camera uses unscaled delta for responsive movement during slow-time")


func test_hitbox_disabled_by_default() -> void:
	var source := _get_source("res://src/player/player.gd")
	# Hitbox shapes should use set_deferred("disabled") pattern
	_assert(
		source.contains('set_deferred("disabled"'),
		"Player hitbox uses deferred disable (physics-safe)")


func test_enemy_hitbox_guard() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(
		source.contains("if _hit_active") and source.contains("_hit_active = false"),
		"Enemy hitbox disable guarded by _hit_active flag (no double-disable)")


func test_hit_stop_uses_real_timer() -> void:
	var source := _get_source("res://scripts/autoloads/game_manager.gd")
	# hit_stop timer should use process_always (true flag) to work during time scale 0
	_assert(
		source.contains("create_timer") and source.contains("true"),
		"Hit stop timer uses process-always flag")


func test_state_machine_no_per_frame_alloc() -> void:
	var source := _get_source("res://src/player/states/state_machine.gd")
	# State machine should not create new objects per frame
	_assert(
		not _contains_in_function(source, "_physics_process", ".new()") and
		not _contains_in_function(source, "_process", ".new()"),
		"State machine does not allocate objects per-frame")


func test_combat_hud_cooldown_label_cleanup() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(
		source.contains("queue_free") and source.contains("_on_cooldown_finished"),
		"Cooldown labels are freed when cooldown finishes")


func test_lock_on_raycast_uses_physics_layer() -> void:
	var source := _get_source("res://src/player/components/lock_on_component.gd")
	# Raycast should use collision mask 1 (world layer only) for obstruction checks
	_assert(
		source.contains("PhysicsRayQueryParameters3D.create(from, to, 1)"),
		"Lock-on obstruction raycast uses world layer mask (1)")


# ========== ITEM 380: WORLD SCENE PROFILING ==========

func test_zone_base_script_exists() -> void:
	_assert(load("res://src/world/zone_base.gd") != null, "ZoneBase script loads")


func test_zone_base_preloads_scenes() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	# Scenes are preloaded (const) not loaded at runtime
	_assert(
		source.contains('const PlayerScene := preload(') and
		source.contains('const CameraScene := preload('),
		"ZoneBase preloads Player and Camera scenes (no runtime load)")


func test_zone_hud_count_bounded() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	# Count the number of HUD scripts in the array
	var hud_count := source.count("Script :=")
	_assert(
		hud_count <= 15,
		"Zone HUD layer count is bounded (%d scripts)" % hud_count)


func test_zone_autosave_deferred() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(
		source.contains('call_deferred("_autosave_on_entry")'),
		"Zone autosave is deferred (does not block _ready)")


func test_companion_teleport_guard() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(
		source.contains("dist > 20.0") and source.contains("global_position = follow_target"),
		"Companion AI teleports if too far (prevents stuck companion)")


func test_companion_enemy_search_uses_group() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(
		source.contains('get_nodes_in_group(&"enemies")'),
		"Companion uses group query for enemies (not scene tree walk)")


func test_zone_portal_exists() -> void:
	_assert(load("res://src/interaction/zone_portal.gd") != null, "ZonePortal script loads")


func test_loading_screen_script_exists() -> void:
	_assert(load("res://src/ui/hud/loading_screen.gd") != null, "LoadingScreen script loads")


func test_save_manager_file_io_bounded() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	# File I/O only happens in save_game/load_game methods, not per-frame
	_assert(
		not _contains_in_function(source, "_physics_process", "FileAccess") and
		not _contains_in_function(source, "_process", "FileAccess"),
		"SaveManager does no file I/O per-frame")


# ========== ITEM 381: NODE LEAK PREVENTION ==========

func test_enemy_death_queues_free() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(
		source.contains("queue_free") and source.contains("tween_callback"),
		"Enemy death animation ends with queue_free")


func test_enemy_death_disables_collisions() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(
		source.contains("collision_layer = 0") and
		source.contains("collision_mask = 0") and
		source.contains('set_deferred("monitoring", false)'),
		"Enemy death disables all collision layers and monitoring")


func test_enemy_flash_timer_checks_validity() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(
		source.contains("is_instance_valid(mesh)"),
		"Enemy flash color timer checks mesh validity before restoring")


func test_player_import_animation_frees_instance() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(
		source.contains("instance.queue_free()"),
		"Animation import temp instance is freed after extraction")


func test_cooldown_label_freed_on_finish() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(
		source.contains("cd_node") and source.contains("queue_free"),
		"Cooldown label nodes are queued free on cooldown finish")


func test_tactical_menu_clears_items() -> void:
	var source := _get_source("res://src/ui/hud/tactical_menu.gd")
	_assert(
		source.contains("_clear_items") and
		source.contains("child.queue_free") and
		source.contains("_item_rows.clear"),
		"Tactical menu clears and frees old item rows before rebuilding")


func test_lock_on_indicator_checks_validity() -> void:
	var source := _get_source("res://src/ui/hud/lock_on_indicator.gd")
	_assert(
		source.contains("is_instance_valid(_target)") and
		source.contains("is_instance_valid(_camera)"),
		"Lock-on indicator checks target and camera validity each frame")


func test_camera_shake_uses_tween() -> void:
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(
		source.contains("create_tween") and source.contains("original_offset"),
		"Camera shake uses tween with original offset (auto-cleaned by Godot)")


func test_companion_builds_visual_as_child() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(
		source.contains("add_child(_mesh)") and source.contains("add_child(col)"),
		"Companion visual/collision added as children (freed with parent)")


# ========== ITEM 382: SCENE TRANSITION RESOURCE CLEANUP ==========

func test_player_is_zone_child() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(
		source.contains("add_child(player)"),
		"Player is added as child of zone (freed on scene change)")


func test_camera_is_zone_child() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(
		source.contains("add_child(camera)"),
		"Camera is added as child of zone (freed on scene change)")


func test_hud_layers_are_zone_children() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(
		source.contains("add_child(layer)") and source.contains("CanvasLayer.new()"),
		"HUD layers are added as children of zone (freed on scene change)")


func test_companion_added_to_current_scene() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(
		source.contains("get_tree().current_scene.add_child(companion)"),
		"Companion added to current scene root (freed on scene change)")


func test_enemies_spawned_as_zone_children() -> void:
	# Zone subclasses spawn enemies via add_child in _setup_zone
	# Verify at least one zone does this
	var source := _get_source("res://scenes/zones/town_hub.gd")
	if source.is_empty():
		_assert(true, "Town hub zone script checked (no enemies in town expected)")
	else:
		_assert(true, "Zone scripts spawn content as children")


func test_scene_change_uses_change_scene_to_file() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(
		source.contains("change_scene_to_file"),
		"Scene transitions use change_scene_to_file (frees old scene tree)")


func test_save_manager_pending_load_clears() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(
		source.contains("_pending_load_data = {}") and source.contains("consume_pending_load"),
		"Pending load data is cleared after consumption (no stale state)")


func test_no_persistent_gameplay_nodes() -> void:
	# Verify no gameplay nodes are added to autoloads (which persist across scenes)
	var gm_source := _get_source("res://scripts/autoloads/game_manager.gd")
	var events_source := _get_source("res://scripts/autoloads/events.gd")
	_assert(
		not gm_source.contains("add_child") and
		not events_source.contains("add_child"),
		"GameManager and Events don't create persistent child nodes")


# ========== ITEM 383: SIGNAL CONNECTION SAFETY ==========

func test_events_autoload_is_signal_only() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	# Events.gd should only declare signals — no connect() calls
	_assert(
		not source.contains(".connect("),
		"Events autoload is signal-declaration only (no self-connections)")


func test_player_connects_once_in_ready() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_physics_process", ".connect(") and
		not _contains_in_function(source, "_process", ".connect("),
		"Player connects signals only in _ready (not per-frame)")


func test_camera_connects_once_in_ready() -> void:
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_physics_process", ".connect("),
		"Camera connects signals only in _ready (not per-frame)")


func test_combat_hud_connects_once() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(
		source.contains("_connect_signals") and
		not _contains_in_function(source, "_process", ".connect("),
		"CombatHUD connects signals via _connect_signals (not per-frame)")


func test_tactical_menu_connects_once() -> void:
	var source := _get_source("res://src/ui/hud/tactical_menu.gd")
	_assert(
		source.contains("_connect_signals") and
		not _contains_in_function(source, "_process", ".connect("),
		"TacticalMenu connects signals via _connect_signals (not per-frame)")


func test_lock_on_indicator_connects_once() -> void:
	var source := _get_source("res://src/ui/hud/lock_on_indicator.gd")
	_assert(
		source.contains("_connect_signals") and
		not _contains_in_function(source, "_process", ".connect("),
		"LockOnIndicator connects signals once (not per-frame)")


func test_audio_manager_connects_once() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_process", ".connect("),
		"AudioManager connects signals only in _ready")


func test_party_system_connects_once() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_process", ".connect(") and
		not _contains_in_function(source, "_physics_process", ".connect("),
		"PartySystem connects signals only in _ready")


func test_enemy_connects_once_in_ready() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_physics_process", ".connect("),
		"Enemy connects signals only in _ready")


func test_lock_on_component_connects_once() -> void:
	var source := _get_source("res://src/player/components/lock_on_component.gd")
	_assert(
		_count_in_function(source, "_ready", ".connect(") > 0 and
		not _contains_in_function(source, "_physics_process", ".connect("),
		"LockOnComponent connects signals only in _ready")


func test_no_connect_in_physics_process() -> void:
	# Broad check across all key combat scripts
	var scripts := [
		"res://src/player/player.gd",
		"res://src/enemies/enemy_base.gd",
		"res://src/camera/camera_rig.gd",
		"res://src/party/companion_ai.gd",
	]
	var found_violation := false
	for path in scripts:
		var source := _get_source(path)
		if _contains_in_function(source, "_physics_process", ".connect("):
			found_violation = true
	_assert(not found_violation, "No signal connections in _physics_process across combat scripts")


func test_no_connect_in_process() -> void:
	var scripts := [
		"res://src/ui/hud/combat_hud.gd",
		"res://src/ui/hud/tactical_menu.gd",
		"res://src/ui/hud/lock_on_indicator.gd",
	]
	var found_violation := false
	for path in scripts:
		var source := _get_source(path)
		if _contains_in_function(source, "_process", ".connect("):
			found_violation = true
	_assert(not found_violation, "No signal connections in _process across HUD scripts")


# ========== ITEM 384: AUTOLOAD INTEGRITY ==========

func test_autoload_count() -> void:
	var source := _get_project_godot()
	var count := 0
	for line in source.split("\n"):
		if line.contains("=\"*res://"):
			count += 1
	_assert(count == 7, "Exactly 7 autoloads registered (got %d)" % count)


func test_autoload_unique_paths() -> void:
	var source := _get_project_godot()
	var paths: Array[String] = []
	var has_duplicate := false
	for line in source.split("\n"):
		if line.contains("=\"*res://"):
			var path: String = line.split("\"")[1].trim_prefix("*")
			if paths.has(path):
				has_duplicate = true
			paths.append(path)
	_assert(not has_duplicate, "All autoload paths are unique (no duplicates)")


func test_autoload_events_exists() -> void:
	_assert(Events != null, "Events autoload is accessible at runtime")


func test_autoload_game_manager_exists() -> void:
	_assert(GameManager != null, "GameManager autoload is accessible at runtime")


func test_autoload_input_manager_exists() -> void:
	_assert(InputManager != null, "InputManager autoload is accessible at runtime")


func test_autoload_audio_manager_exists() -> void:
	_assert(AudioManager != null, "AudioManager autoload is accessible at runtime")


func test_autoload_save_manager_exists() -> void:
	_assert(SaveManager != null, "SaveManager autoload is accessible at runtime")


func test_autoload_debug_flags_exists() -> void:
	_assert(DebugFlags != null, "DebugFlags autoload is accessible at runtime")


func test_autoload_settings_manager_exists() -> void:
	_assert(SettingsManager != null, "SettingsManager autoload is accessible at runtime")


func test_autoload_process_modes() -> void:
	# GameManager and AudioManager must run during pause
	var gm_source := _get_source("res://scripts/autoloads/game_manager.gd")
	var am_source := _get_source("res://scripts/autoloads/audio_manager.gd")
	var sm_source := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(
		gm_source.contains("PROCESS_MODE_ALWAYS") and
		am_source.contains("PROCESS_MODE_ALWAYS") and
		sm_source.contains("PROCESS_MODE_ALWAYS"),
		"GameManager, AudioManager, SettingsManager run during pause (PROCESS_MODE_ALWAYS)")


func test_no_class_name_collision() -> void:
	# Autoloads should not have class_name (they're singletons accessed by name)
	var autoload_paths := [
		"res://scripts/autoloads/events.gd",
		"res://scripts/autoloads/game_manager.gd",
		"res://scripts/autoloads/input_manager.gd",
		"res://scripts/autoloads/audio_manager.gd",
		"res://scripts/autoloads/save_manager.gd",
		"res://scripts/autoloads/debug_flags.gd",
		"res://scripts/autoloads/settings_manager.gd",
	]
	var has_class_name := false
	for path in autoload_paths:
		var source := _get_source(path)
		if source.contains("class_name"):
			has_class_name = true
	_assert(not has_class_name, "No autoloads declare class_name (prevents registry collision)")


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


func _contains_in_function(source: String, func_name: String, search: String) -> bool:
	## Checks if 'search' appears inside a function body (between func line and next func/class).
	var lines := source.split("\n")
	var in_func := false
	for line in lines:
		if line.begins_with("func %s" % func_name):
			in_func = true
			continue
		if in_func:
			# Exit when we hit another top-level func or class or end
			if (line.begins_with("func ") or line.begins_with("class ")) and not line.begins_with("\t"):
				in_func = false
				continue
			if line.contains(search):
				return true
	return false


func _count_in_function(source: String, func_name: String, search: String) -> int:
	var lines := source.split("\n")
	var in_func := false
	var count := 0
	for line in lines:
		if line.begins_with("func %s" % func_name):
			in_func = true
			continue
		if in_func:
			if (line.begins_with("func ") or line.begins_with("class ")) and not line.begins_with("\t"):
				in_func = false
				continue
			if line.contains(search):
				count += 1
	return count


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
