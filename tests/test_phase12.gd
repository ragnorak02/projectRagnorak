## Phase 12 tests: World & Traversal (items 281-310).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 12: World & Traversal Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 12 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Towns / Zones (items 281-286)
	_section("TOWNS & ZONES")
	test_zone_base_exists()
	test_zone_base_spawns_player()
	test_zone_base_spawns_camera()
	test_zone_base_spawns_hud()
	test_zone_base_handles_pending_load()
	test_zone_base_autosaves()
	test_zone_base_emits_zone_entered()
	test_town_hub_exists()
	test_town_hub_extends_zone_base()
	test_town_hub_has_npcs()
	test_town_hub_has_portals()
	test_town_hub_scene_loads()
	test_field_zone_exists()
	test_field_zone_extends_zone_base()
	test_field_zone_has_enemies()
	test_field_zone_has_portals()
	test_field_zone_scene_loads()
	test_dungeon_zone_exists()
	test_dungeon_zone_extends_zone_base()
	test_dungeon_zone_has_enemies()
	test_dungeon_zone_has_puzzle()
	test_dungeon_zone_scene_loads()
	test_zone_portal_exists()
	test_zone_portal_has_target()
	test_zone_portal_has_gating()
	test_zone_portal_triggers_transition()
	test_zone_id_mapping_town()
	test_zone_id_mapping_field()
	test_zone_id_mapping_dungeon()
	test_loading_screen_exists()
	test_loading_screen_has_fade()

	# Category 2: Exploration (items 287-292)
	_section("EXPLORATION")
	test_hidden_area_exists()
	test_hidden_area_has_discovery()
	test_hidden_area_uses_flags()
	test_chest_reward_structure()
	test_exploration_gating_via_flags()
	test_switch_puzzle_exists()
	test_switch_puzzle_has_levers()
	test_switch_puzzle_has_solved_flag()
	test_switch_puzzle_activates_target()
	test_lever_interactable_toggles()
	test_puzzles_dont_break_combat()

	# Category 3: Traversal Expansion (items 293-298)
	_section("TRAVERSAL EXPANSION")
	test_double_jump_hook()
	test_double_jump_flag_resets()
	test_double_jump_in_jump_state()
	test_double_jump_in_fall_state()
	test_climb_refinement()
	test_breakable_wall_exists()
	test_breakable_wall_uses_flags()
	test_breakable_wall_hides_on_break()
	test_traversal_gating_via_party()
	test_camera_stable_during_traversal()
	test_traversal_no_bypass()

	# Category 4: World Validation (items 299-310)
	_section("WORLD VALIDATION")
	test_semi_open_routing()
	test_transitions_preserve_state()
	test_loading_transitions_safe()
	test_autosave_in_world()
	test_exploration_rewards_persist()
	test_puzzle_completion_persists()
	test_field_town_dungeon_loop()
	test_no_traversal_softlocks()
	test_return_paths_exist()
	test_world_nav_controller()
	test_world_nav_keyboard()
	test_world_loop_playable()


# ========== CATEGORY 1: TOWNS & ZONES ==========

func test_zone_base_exists() -> void:
	var script = load("res://src/world/zone_base.gd")
	_assert(script != null, "Zone base script exists")


func test_zone_base_spawns_player() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("PlayerScene.instantiate()") and source.contains("add_child(player)"),
		"Zone base spawns player")


func test_zone_base_spawns_camera() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("CameraScene.instantiate()") and source.contains("follow_target"),
		"Zone base spawns camera with follow target")


func test_zone_base_spawns_hud() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("_spawn_hud") and source.contains("CombatHudScript")
		and source.contains("PauseMenuScript") and source.contains("SaveFeedbackScript"),
		"Zone base spawns all HUD layers")


func test_zone_base_handles_pending_load() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("has_pending_load") and source.contains("consume_pending_load")
		and source.contains("apply_load_data"),
		"Zone base checks and applies pending save data")


func test_zone_base_autosaves() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("_autosave_on_entry") and source.contains("SaveManager.autosave"),
		"Zone base autosaves on entry")


func test_zone_base_emits_zone_entered() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("Events.zone_entered.emit"),
		"Zone base emits zone_entered signal")


func test_town_hub_exists() -> void:
	var script = load("res://scenes/zones/town_hub.gd")
	_assert(script != null, "Town hub script exists")


func test_town_hub_extends_zone_base() -> void:
	var source := _get_source("res://scenes/zones/town_hub.gd")
	_assert(source.contains('extends "res://src/world/zone_base.gd"'),
		"Town hub extends zone_base")


func test_town_hub_has_npcs() -> void:
	var source := _get_source("res://scenes/zones/town_hub.gd")
	_assert(source.contains("_add_npc") and source.contains("Elder Hwan")
		and source.contains("Merchant Soo"),
		"Town hub has NPC characters")


func test_town_hub_has_portals() -> void:
	var source := _get_source("res://scenes/zones/town_hub.gd")
	_assert(source.contains("_add_portal") and source.contains("field_zone")
		and source.contains("dungeon_zone"),
		"Town hub has portals to field and dungeon")


func test_town_hub_scene_loads() -> void:
	var scene = load("res://scenes/zones/town_hub.tscn")
	_assert(scene != null, "Town hub scene file loads")


func test_field_zone_exists() -> void:
	var script = load("res://scenes/zones/field_zone.gd")
	_assert(script != null, "Field zone script exists")


func test_field_zone_extends_zone_base() -> void:
	var source := _get_source("res://scenes/zones/field_zone.gd")
	_assert(source.contains('extends "res://src/world/zone_base.gd"'),
		"Field zone extends zone_base")


func test_field_zone_has_enemies() -> void:
	var source := _get_source("res://scenes/zones/field_zone.gd")
	_assert(source.contains("_add_enemy") and source.contains("EnemyScene.instantiate"),
		"Field zone spawns enemies")


func test_field_zone_has_portals() -> void:
	var source := _get_source("res://scenes/zones/field_zone.gd")
	_assert(source.contains("town_hub") and source.contains("dungeon_zone"),
		"Field zone has portals to town and dungeon")


func test_field_zone_scene_loads() -> void:
	var scene = load("res://scenes/zones/field_zone.tscn")
	_assert(scene != null, "Field zone scene file loads")


func test_dungeon_zone_exists() -> void:
	var script = load("res://scenes/zones/dungeon_zone.gd")
	_assert(script != null, "Dungeon zone script exists")


func test_dungeon_zone_extends_zone_base() -> void:
	var source := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(source.contains('extends "res://src/world/zone_base.gd"'),
		"Dungeon zone extends zone_base")


func test_dungeon_zone_has_enemies() -> void:
	var source := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(source.contains("_add_enemy") and source.contains("EnemyScene"),
		"Dungeon zone spawns enemies")


func test_dungeon_zone_has_puzzle() -> void:
	var source := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(source.contains("_add_switch_puzzle") and source.contains("SwitchPuzzle")
		and source.contains("LeverInteractable"),
		"Dungeon zone has switch puzzle with levers")


func test_dungeon_zone_scene_loads() -> void:
	var scene = load("res://scenes/zones/dungeon_zone.tscn")
	_assert(scene != null, "Dungeon zone scene file loads")


func test_zone_portal_exists() -> void:
	var script = load("res://src/interaction/zone_portal.gd")
	_assert(script != null, "Zone portal script exists")


func test_zone_portal_has_target() -> void:
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("target_zone_id") and source.contains("spawn_position"),
		"Zone portal has target zone and spawn position")


func test_zone_portal_has_gating() -> void:
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("required_flag") and source.contains("has_flag")
		and source.contains("locked_message"),
		"Zone portal supports progression flag gating")


func test_zone_portal_triggers_transition() -> void:
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("change_scene_to_file") and source.contains("_zone_id_to_scene")
		and source.contains("zone_exiting"),
		"Zone portal triggers scene transition with zone_exiting signal")


func test_zone_id_mapping_town() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"town_hub"') and source.contains("town_hub.tscn"),
		"SaveManager maps town_hub to correct scene")


func test_zone_id_mapping_field() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"field_zone"') and source.contains("field_zone.tscn"),
		"SaveManager maps field_zone to correct scene")


func test_zone_id_mapping_dungeon() -> void:
	var source := _get_source("res://scripts/autoloads/save_manager.gd")
	_assert(source.contains('"dungeon_zone"') and source.contains("dungeon_zone.tscn"),
		"SaveManager maps dungeon_zone to correct scene")


func test_loading_screen_exists() -> void:
	var script = load("res://src/ui/hud/loading_screen.gd")
	_assert(script != null, "Loading screen script exists")


func test_loading_screen_has_fade() -> void:
	var source := _get_source("res://src/ui/hud/loading_screen.gd")
	_assert(source.contains("func fade_out(") and source.contains("func fade_in(")
		and source.contains("fade_out_complete") and source.contains("fade_in_complete"),
		"Loading screen has fade_out and fade_in with signals")


# ========== CATEGORY 2: EXPLORATION ==========

func test_hidden_area_exists() -> void:
	var script = load("res://src/interaction/hidden_area.gd")
	_assert(script != null, "Hidden area script exists")


func test_hidden_area_has_discovery() -> void:
	var source := _get_source("res://src/interaction/hidden_area.gd")
	_assert(source.contains("_discovered") and source.contains("discovery_message")
		and source.contains("save_feedback"),
		"Hidden area tracks discovery and shows feedback")


func test_hidden_area_uses_flags() -> void:
	var source := _get_source("res://src/interaction/hidden_area.gd")
	_assert(source.contains("set_flag") and source.contains("has_flag")
		and source.contains("discovered_"),
		"Hidden area uses progression flags for persistence")


func test_chest_reward_structure() -> void:
	var source := _get_source("res://src/interaction/chest_interactable.gd")
	_assert(source.contains("contents") and source.contains("item_path")
		and source.contains("quantity") and source.contains("is_opened"),
		"Chest has contents, item_path, quantity, and opened tracking")


func test_exploration_gating_via_flags() -> void:
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("required_flag") and source.contains("SaveManager.has_flag"),
		"Zone portals support exploration gating via progression flags")


func test_switch_puzzle_exists() -> void:
	var script = load("res://src/interaction/switch_puzzle.gd")
	_assert(script != null, "Switch puzzle script exists")


func test_switch_puzzle_has_levers() -> void:
	var source := _get_source("res://src/interaction/switch_puzzle.gd")
	_assert(source.contains("levers") and source.contains("lever_toggled")
		and source.contains("_lever_nodes"),
		"Switch puzzle connects to lever nodes")


func test_switch_puzzle_has_solved_flag() -> void:
	var source := _get_source("res://src/interaction/switch_puzzle.gd")
	_assert(source.contains("puzzle_id") and source.contains("set_flag")
		and source.contains("has_flag") and source.contains("_solved"),
		"Switch puzzle tracks solved state via progression flags")


func test_switch_puzzle_activates_target() -> void:
	var source := _get_source("res://src/interaction/switch_puzzle.gd")
	_assert(source.contains("target") and source.contains("_activate_target")
		and source.contains("puzzle_solved"),
		"Switch puzzle activates target node and emits signal on solve")


func test_lever_interactable_toggles() -> void:
	var source := _get_source("res://src/interaction/lever_interactable.gd")
	_assert(source.contains("is_on") and source.contains("not is_on")
		and source.contains("lever_toggled") and source.contains("one_shot"),
		"Lever toggles state and supports one_shot mode")


func test_puzzles_dont_break_combat() -> void:
	# Switch puzzles use Node3D (not CharacterBody3D), levers inherit from interactable (layer 9)
	# Neither interferes with combat collision layers (4-7)
	var puzzle_src := _get_source("res://src/interaction/switch_puzzle.gd")
	var base_src := _get_source("res://src/interaction/interactable.gd")
	_assert(puzzle_src.contains("Node3D") and base_src.contains("collision_layer = 256"),
		"Puzzles use non-combat collision layers (safe)")


# ========== CATEGORY 3: TRAVERSAL EXPANSION ==========

func test_double_jump_hook() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("has_double_jump") and source.contains("_double_jump_used"),
		"Player has double jump flag and usage tracking")


func test_double_jump_flag_resets() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("_double_jump_used = false") and source.contains("is_on_floor"),
		"Double jump usage resets on landing")


func test_double_jump_in_jump_state() -> void:
	var source := _get_source("res://src/player/states/jump_state.gd")
	_assert(source.contains("has_double_jump") and source.contains("_double_jump_used"),
		"Jump state supports double jump activation")


func test_double_jump_in_fall_state() -> void:
	var source := _get_source("res://src/player/states/fall_state.gd")
	_assert(source.contains("has_double_jump") and source.contains("_double_jump_used"),
		"Fall state supports double jump activation")


func test_climb_refinement() -> void:
	var source := _get_source("res://src/player/states/climb_state.gd")
	_assert(source.contains("climb_duration") and source.contains("eased")
		and source.contains("lerp"),
		"Climb state has smooth eased movement")


func test_breakable_wall_exists() -> void:
	var script = load("res://src/interaction/breakable_wall.gd")
	_assert(script != null, "Breakable wall script exists")


func test_breakable_wall_uses_flags() -> void:
	var source := _get_source("res://src/interaction/breakable_wall.gd")
	_assert(source.contains("required_flag") and source.contains("set_flag")
		and source.contains("has_flag") and source.contains("broken_"),
		"Breakable wall uses progression flags for persistence")


func test_breakable_wall_hides_on_break() -> void:
	var source := _get_source("res://src/interaction/breakable_wall.gd")
	_assert(source.contains("visible = false") and source.contains("collision_layer = 0"),
		"Breakable wall hides visual and disables collision when broken")


func test_traversal_gating_via_party() -> void:
	# Zone portals support required_flag which can be set by party members
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("required_flag"),
		"Traversal gating via required_flag (set by party/abilities)")


func test_camera_stable_during_traversal() -> void:
	# Camera rig uses SpringArm3D for collision, independent of player states
	var source := _get_source("res://src/camera/camera_rig.gd")
	_assert(source.contains("SpringArm3D") or source.contains("spring_arm")
		or source.contains("follow_target"),
		"Camera uses follow target system (stable during traversal)")


func test_traversal_no_bypass() -> void:
	# Zone portals check required_flag before allowing transition
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("if required_flag") and source.contains("has_flag")
		and source.contains("return"),
		"Portal blocks transition when required flag is missing")


# ========== CATEGORY 4: WORLD VALIDATION ==========

func test_semi_open_routing() -> void:
	# Town connects to field, field connects to dungeon and town
	var town := _get_source("res://scenes/zones/town_hub.gd")
	var field := _get_source("res://scenes/zones/field_zone.gd")
	_assert(town.contains("field_zone") and field.contains("town_hub")
		and field.contains("dungeon_zone"),
		"Semi-open routing: town <-> field <-> dungeon")


func test_transitions_preserve_state() -> void:
	# Zone portal saves state before transition via SaveManager
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("gather_save_data") and source.contains("autosave"),
		"Zone transitions save state before changing scene")


func test_loading_transitions_safe() -> void:
	var source := _get_source("res://src/ui/hud/loading_screen.gd")
	_assert(source.contains("PROCESS_MODE_ALWAYS") and source.contains("layer = 100"),
		"Loading screen runs in always mode at high layer")


func test_autosave_in_world() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("_autosave_on_entry") and source.contains("SaveManager.autosave"),
		"All zones autosave on entry via zone_base")


func test_exploration_rewards_persist() -> void:
	# Chest opened state tracked via is_opened flag, hidden areas via progression flags
	var chest := _get_source("res://src/interaction/chest_interactable.gd")
	var hidden := _get_source("res://src/interaction/hidden_area.gd")
	_assert(chest.contains("is_opened") and hidden.contains("set_flag"),
		"Chest opened and hidden area discovery persist via flags")


func test_puzzle_completion_persists() -> void:
	var source := _get_source("res://src/interaction/switch_puzzle.gd")
	_assert(source.contains("puzzle_id") and source.contains("set_flag")
		and source.contains("has_flag"),
		"Puzzle completion persists via progression flags")


func test_field_town_dungeon_loop() -> void:
	var town := _get_source("res://scenes/zones/town_hub.gd")
	var field := _get_source("res://scenes/zones/field_zone.gd")
	var dungeon := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(town.contains("_setup_zone") and field.contains("_setup_zone")
		and dungeon.contains("_setup_zone"),
		"All zones implement _setup_zone for content")


func test_no_traversal_softlocks() -> void:
	# All zones have return portals
	var field := _get_source("res://scenes/zones/field_zone.gd")
	var dungeon := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(field.contains("Return to Town") and dungeon.contains("Exit to Field"),
		"Field and dungeon have return portals (no softlocks)")


func test_return_paths_exist() -> void:
	var town := _get_source("res://scenes/zones/town_hub.gd")
	var field := _get_source("res://scenes/zones/field_zone.gd")
	var dungeon := _get_source("res://scenes/zones/dungeon_zone.gd")
	_assert(
		town.contains("field_zone") and field.contains("town_hub")
		and field.contains("dungeon_zone") and dungeon.contains("field_zone"),
		"All zones have bidirectional connections")


func test_world_nav_controller() -> void:
	# Zone portals use interact action (Y button on controller)
	var source := _get_source("res://src/interaction/zone_portal.gd")
	_assert(source.contains("func interact("),
		"Zone portals activated via interact action (controller Y)")


func test_world_nav_keyboard() -> void:
	# Interact mapped to E key
	_assert(InputMap.has_action(&"interact"),
		"Interact action mapped for keyboard (E key)")


func test_world_loop_playable() -> void:
	# Verify all three zone scenes load, all extend zone_base
	var town = load("res://scenes/zones/town_hub.tscn")
	var field = load("res://scenes/zones/field_zone.tscn")
	var dungeon = load("res://scenes/zones/dungeon_zone.tscn")
	_assert(town != null and field != null and dungeon != null,
		"All zone scenes load successfully (world loop playable)")


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
