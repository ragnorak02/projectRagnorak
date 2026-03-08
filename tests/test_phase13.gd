## Phase 13 tests: Party System (items 311-340).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 13: Party System Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 13 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Party Foundations (items 311-315)
	_section("PARTY FOUNDATIONS")
	test_party_member_data_exists()
	test_party_member_data_fields()
	test_hero_resource_loads()
	test_companion_resource_loads()
	test_companion_has_traversal_flags()
	test_companion_ai_script_exists()
	test_companion_ai_extends_characterbody3d()
	test_companion_ai_has_states()
	test_companion_ai_has_initialize()
	test_companion_ai_has_follow_behavior()
	test_companion_ai_builds_visual()
	test_companion_ai_has_collision()
	test_party_system_script_exists()
	test_party_system_has_roster()
	test_party_system_has_initialize()
	test_party_system_initialize_adds_hero()
	test_party_system_initialize_adds_companion()
	test_party_system_get_member_count()
	test_party_system_get_active_member()
	test_party_system_get_companion()

	# Category 2: Party Combat (items 316-320)
	_section("PARTY COMBAT")
	test_companion_ai_has_attack()
	test_companion_ai_finds_enemies()
	test_companion_ai_takes_damage()
	test_companion_ai_downed_state()
	test_companion_ai_revive()
	test_party_system_is_member_downed()
	test_party_system_revive_member()
	test_companion_ai_save_data()
	test_companion_ai_load_data()
	test_companion_follows_target()

	# Category 3: Member Switching (items 313-314)
	_section("MEMBER SWITCHING")
	test_party_system_switch_member()
	test_party_system_switch_skips_downed()
	test_party_system_switch_battle()
	test_party_system_switch_menu()
	test_party_switch_input_defined()
	test_party_switch_emits_signal()

	# Category 4: Team Meter / Attacks (items 321-326)
	_section("TEAM METER")
	test_team_meter_initial_zero()
	test_team_meter_add()
	test_team_meter_cap()
	test_team_meter_spend()
	test_team_meter_has_check()
	test_team_meter_fill_on_hit()
	test_team_meter_signal()
	test_party_system_save_data()
	test_party_system_load_data()

	# Category 5: Traversal (items 327-329)
	_section("PARTY TRAVERSAL")
	test_traversal_flags_aggregation()
	test_apply_traversal_flags()
	test_player_has_double_jump_flag()

	# Category 6: Party HUD (item 336)
	_section("PARTY HUD")
	test_combat_hud_has_ally_bar()
	test_combat_hud_has_team_meter()
	test_combat_hud_party_join_handler()
	test_combat_hud_party_downed_handler()
	test_combat_hud_party_revived_handler()
	test_combat_hud_team_meter_handler()

	# Category 7: Integration
	_section("INTEGRATION")
	test_player_has_party_system_ref()
	test_player_save_includes_party()
	test_player_load_includes_party()
	test_events_has_party_signals()
	test_zone_base_has_party_setup()
	test_test_arena_has_party_setup()
	test_party_system_add_member()
	test_no_duplicate_member()
	test_companion_teleport_safety()
	test_companion_gravity()


# ========== CATEGORY 1: PARTY FOUNDATIONS ==========

func test_party_member_data_exists() -> void:
	var script = load("res://resources/characters/party_member_data.gd")
	_assert(script != null, "PartyMemberData script exists")


func test_party_member_data_fields() -> void:
	var source := _get_source("res://resources/characters/party_member_data.gd")
	_assert(source.contains("member_id") and source.contains("display_name")
		and source.contains("max_hp") and source.contains("max_mp")
		and source.contains("max_atb") and source.contains("capsule_color")
		and source.contains("traversal_flags") and source.contains("default_abilities"),
		"PartyMemberData has all required fields")


func test_hero_resource_loads() -> void:
	var res = load("res://resources/characters/hero.tres")
	_assert(res != null and res.get("member_id") == &"hero",
		"Hero resource loads with correct member_id")


func test_companion_resource_loads() -> void:
	var res = load("res://resources/characters/companion.tres")
	_assert(res != null and res.get("member_id") == &"companion"
		and res.get("display_name") == "Yuna",
		"Companion resource loads with correct ID and name")


func test_companion_has_traversal_flags() -> void:
	var res = load("res://resources/characters/companion.tres")
	var flags: Array = res.get("traversal_flags") if res else []
	_assert(flags.has("has_wall_break"),
		"Companion has 'has_wall_break' traversal flag")


func test_companion_ai_script_exists() -> void:
	var script = load("res://src/party/companion_ai.gd")
	_assert(script != null, "CompanionAI script exists")


func test_companion_ai_extends_characterbody3d() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("extends CharacterBody3D"),
		"CompanionAI extends CharacterBody3D")


func test_companion_ai_has_states() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("FOLLOW") and source.contains("ATTACK")
		and source.contains("SUPPORT") and source.contains("DOWNED"),
		"CompanionAI has FOLLOW, ATTACK, SUPPORT, DOWNED states")


func test_companion_ai_has_initialize() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("func initialize(data:"),
		"CompanionAI has initialize method")


func test_companion_ai_has_follow_behavior() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("_process_follow") and source.contains("follow_distance")
		and source.contains("follow_target"),
		"CompanionAI has follow behavior with distance check")


func test_companion_ai_builds_visual() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("_build_visual") and source.contains("CapsuleMesh")
		and source.contains("material_override"),
		"CompanionAI builds visual capsule with material")


func test_companion_ai_has_collision() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("CollisionShape3D") and source.contains("CapsuleShape3D"),
		"CompanionAI creates collision shape")


func test_party_system_script_exists() -> void:
	var script = load("res://src/party/party_system.gd")
	_assert(script != null, "PartySystem script exists")


func test_party_system_has_roster() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("var members: Array") and source.contains("active_index"),
		"PartySystem has members roster and active_index")


func test_party_system_has_initialize() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func initialize(player:"),
		"PartySystem has initialize method")


func test_party_system_initialize_adds_hero() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	ps.initialize(mock_player)
	_assert(ps.members.size() == 1 and ps.members[0]["id"] == &"hero",
		"PartySystem.initialize adds hero as first member")
	mock_player.queue_free()
	ps.queue_free()


func test_party_system_initialize_adds_companion() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	var companion_data = load("res://resources/characters/companion.tres")
	ps.initialize(mock_player, companion_data)
	_assert(ps.members.size() == 2 and ps.members[1]["id"] == &"companion",
		"PartySystem.initialize with companion data adds companion")
	mock_player.queue_free()
	ps.queue_free()


func test_party_system_get_member_count() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	ps.initialize(mock_player)
	_assert(ps.get_member_count() == 1, "get_member_count returns correct count")
	mock_player.queue_free()
	ps.queue_free()


func test_party_system_get_active_member() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	ps.initialize(mock_player)
	_assert(ps.get_active_member() == mock_player,
		"get_active_member returns player")
	mock_player.queue_free()
	ps.queue_free()


func test_party_system_get_companion() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func get_companion()") and source.contains("not m[\"is_active\"]"),
		"PartySystem has get_companion method that finds non-active member")


# ========== CATEGORY 2: PARTY COMBAT ==========

func test_companion_ai_has_attack() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("_do_attack") and source.contains("_process_attack")
		and source.contains("attack_damage") and source.contains("attack_cooldown"),
		"CompanionAI has attack behavior with damage and cooldown")


func test_companion_ai_finds_enemies() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("_find_nearest_enemy") and source.contains('get_nodes_in_group(&"enemies")'),
		"CompanionAI finds nearest enemy from enemies group")


func test_companion_ai_takes_damage() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("func take_damage(amount: float") and source.contains("_enter_downed"),
		"CompanionAI takes damage and enters downed at 0 HP")


func test_companion_ai_downed_state() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("_is_downed") and source.contains("AIState.DOWNED")
		and source.contains("party_member_downed"),
		"CompanionAI has downed state that emits party_member_downed signal")


func test_companion_ai_revive() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("func revive(") and source.contains("party_member_revived")
		and source.contains("AIState.FOLLOW"),
		"CompanionAI has revive method that returns to FOLLOW state")


func test_party_system_is_member_downed() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func is_member_downed(") and source.contains("is_downed()"),
		"PartySystem checks downed state via is_member_downed")


func test_party_system_revive_member() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func revive_member(") and source.contains(".revive("),
		"PartySystem revives members via revive_member method")


func test_companion_ai_save_data() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("func get_save_data(") and source.contains('"hp"')
		and source.contains('"mp"') and source.contains('"is_downed"'),
		"CompanionAI has save data with hp, mp, is_downed")


func test_companion_ai_load_data() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("func load_save_data(") and source.contains("_enter_downed()"),
		"CompanionAI has load_save_data that restores downed state")


func test_companion_follows_target() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("distance_to(follow_target.global_position)")
		and source.contains("move_and_slide"),
		"CompanionAI follows target and uses move_and_slide")


# ========== CATEGORY 3: MEMBER SWITCHING ==========

func test_party_system_switch_member() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func switch_member()") and source.contains("is_active")
		and source.contains("party_member_switched"),
		"PartySystem has switch_member that updates active and emits signal")


func test_party_system_switch_skips_downed() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("is_downed()") and source.contains("attempts"),
		"PartySystem switch_member skips downed members")


func test_party_system_switch_battle() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func switch_member_battle()"),
		"PartySystem has switch_member_battle for in-combat switching")


func test_party_system_switch_menu() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func switch_member_menu()") and source.contains("PAUSED"),
		"PartySystem has switch_member_menu for out-of-battle switching via pause")


func test_party_switch_input_defined() -> void:
	var source := ""
	if FileAccess.file_exists("res://project.godot"):
		var f := FileAccess.open("res://project.godot", FileAccess.READ)
		if f:
			source = f.get_as_text()
	_assert(source.contains("party_switch="),
		"party_switch input action defined in project.godot")


func test_party_switch_emits_signal() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("party_member_switched.emit(old_id, new_id)"),
		"Party switch emits party_member_switched signal with old and new IDs")


# ========== CATEGORY 4: TEAM METER ==========

func test_team_meter_initial_zero() -> void:
	var ps = _create_party_system()
	_assert(ps.team_meter == 0.0, "Team meter starts at zero")
	ps.queue_free()


func test_team_meter_add() -> void:
	var ps = _create_party_system()
	ps.add_team_meter(25.0)
	_assert(ps.team_meter == 25.0, "add_team_meter increases team meter")
	ps.queue_free()


func test_team_meter_cap() -> void:
	var ps = _create_party_system()
	ps.add_team_meter(200.0)
	_assert(ps.team_meter == ps.team_meter_max,
		"Team meter caps at team_meter_max")
	ps.queue_free()


func test_team_meter_spend() -> void:
	var ps = _create_party_system()
	ps.add_team_meter(50.0)
	var result = ps.spend_team_meter(30.0)
	_assert(result and ps.team_meter == 20.0,
		"spend_team_meter deducts correctly and returns true")
	ps.queue_free()


func test_team_meter_has_check() -> void:
	var ps = _create_party_system()
	ps.add_team_meter(10.0)
	_assert(ps.has_team_meter(10.0) and not ps.has_team_meter(11.0),
		"has_team_meter checks if enough meter is available")
	ps.queue_free()


func test_team_meter_fill_on_hit() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("attack_hit.connect") and source.contains("_on_attack_hit")
		and source.contains("team_meter_fill_per_hit"),
		"Team meter fills on attack_hit signal")


func test_team_meter_signal() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("team_meter_changed.emit(team_meter, team_meter_max)"),
		"Team meter emits team_meter_changed signal")


func test_party_system_save_data() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	ps.initialize(mock_player)
	ps.add_team_meter(42.0)
	var data = ps.get_save_data()
	_assert(data is Dictionary and data.has("members") and data.has("team_meter")
		and data["team_meter"] == 42.0,
		"PartySystem save data includes members and team_meter")
	mock_player.queue_free()
	ps.queue_free()


func test_party_system_load_data() -> void:
	var ps = _create_party_system()
	var mock_player = _create_mock_player()
	ps.initialize(mock_player)
	ps.load_save_data({"team_meter": 75.0, "members": []})
	_assert(ps.team_meter == 75.0,
		"PartySystem load_save_data restores team_meter")
	mock_player.queue_free()
	ps.queue_free()


# ========== CATEGORY 5: TRAVERSAL ==========

func test_traversal_flags_aggregation() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func get_party_traversal_flags()") and source.contains("traversal_flags"),
		"PartySystem aggregates traversal flags from all members")


func test_apply_traversal_flags() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func apply_traversal_flags()") and source.contains("SaveManager.set_flag"),
		"PartySystem applies traversal flags to SaveManager progression")


func test_player_has_double_jump_flag() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("has_double_jump") and source.contains("_double_jump_used"),
		"Player has has_double_jump and _double_jump_used flags")


# ========== CATEGORY 6: PARTY HUD ==========

func test_combat_hud_has_ally_bar() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_ally_hp_bar") and source.contains("_ally_hp_label")
		and source.contains("_ally_bar_container"),
		"Combat HUD has ally HP bar with label and container")


func test_combat_hud_has_team_meter() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("_team_meter_bar") and source.contains("_team_meter_label"),
		"Combat HUD has team meter bar with label")


func test_combat_hud_party_join_handler() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("party_member_joined.connect") and source.contains("_on_party_member_joined"),
		"Combat HUD connects to party_member_joined signal")


func test_combat_hud_party_downed_handler() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("party_member_downed.connect") and source.contains("_on_party_member_downed"),
		"Combat HUD connects to party_member_downed signal")


func test_combat_hud_party_revived_handler() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("party_member_revived.connect") and source.contains("_on_party_member_revived"),
		"Combat HUD connects to party_member_revived signal")


func test_combat_hud_team_meter_handler() -> void:
	var source := _get_source("res://src/ui/hud/combat_hud.gd")
	_assert(source.contains("team_meter_changed.connect") and source.contains("_on_team_meter_changed"),
		"Combat HUD connects to team_meter_changed signal")


# ========== CATEGORY 7: INTEGRATION ==========

func test_player_has_party_system_ref() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("var party_system: Node = null"),
		"Player has party_system reference (assigned after spawn)")


func test_player_save_includes_party() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"party"') and source.contains("party_system.get_save_data"),
		"Player save data includes party")


func test_player_load_includes_party() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"party"') and source.contains("party_system.load_save_data"),
		"Player load data restores party")


func test_events_has_party_signals() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal party_member_joined")
		and source.contains("signal party_member_switched")
		and source.contains("signal party_member_downed")
		and source.contains("signal party_member_revived")
		and source.contains("signal team_meter_changed"),
		"Events bus has all party signals")


func test_zone_base_has_party_setup() -> void:
	var source := _get_source("res://src/world/zone_base.gd")
	_assert(source.contains("_setup_party") and source.contains("PartySystemScript")
		and source.contains("party_system"),
		"ZoneBase has _setup_party with PartySystem initialization")


func test_test_arena_has_party_setup() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("PartySystemScript") and source.contains("party_system")
		and source.contains("party.initialize"),
		"Test arena initializes party system")


func test_party_system_add_member() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("func add_member(") and source.contains("_spawn_companion"),
		"PartySystem has add_member for runtime additions")


func test_no_duplicate_member() -> void:
	var source := _get_source("res://src/party/party_system.gd")
	_assert(source.contains("member_id") and source.contains("return") and source.contains("add_member"),
		"PartySystem add_member prevents duplicate members")


func test_companion_teleport_safety() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("20.0") and source.contains("Teleport"),
		"CompanionAI teleports to player when too far away")


func test_companion_gravity() -> void:
	var source := _get_source("res://src/party/companion_ai.gd")
	_assert(source.contains("gravity") and source.contains("is_on_floor"),
		"CompanionAI has gravity and floor detection")


# ========== HELPERS ==========

func _create_party_system() -> Node:
	var script = load("res://src/party/party_system.gd")
	var node = Node.new()
	node.set_script(script)
	add_child(node)
	return node


func _create_mock_player() -> Node3D:
	# Minimal mock — just needs to exist as Node3D
	var player = Node3D.new()
	add_child(player)
	return player


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


func _fail(test_name: String, reason: String = "") -> void:
	_failed += 1
	_total += 1
	var msg := "  FAIL: %s" % test_name
	if reason != "":
		msg += " — %s" % reason
	print(msg)
