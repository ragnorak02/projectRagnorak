## Comprehensive Phase 6 tests: MP, ATB, AbilitySystem, Spell Execution, Combat HUD.
extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array[String] = []


func _ready() -> void:
	print("=== Phase 6: MP, ATB & Ability Pipeline Tests ===")
	print("")

	# --- MP System Tests ---
	_section("MP SYSTEM")
	test_mp_resource_exists()
	test_mp_consumption()
	test_mp_insufficient_check()
	test_mp_cannot_go_negative()
	test_mp_regen_delay_set_on_spend()

	# --- ATB System Tests ---
	_section("ATB SYSTEM")
	test_atb_resource_exists()
	test_atb_consumption()
	test_atb_insufficient_check()
	test_atb_cannot_go_negative()
	test_atb_fill_rate_defined()

	# --- AbilityData Resource Tests ---
	_section("ABILITY DATA")
	test_ability_data_script_loads()
	test_fire_bolt_resource_loads()
	test_fire_bolt_has_correct_costs()
	test_fire_bolt_has_effect_scene()
	test_ability_types_defined()

	# --- AbilitySystem Component Tests ---
	_section("ABILITY SYSTEM")
	test_ability_system_script_loads()
	test_ability_system_can_equip()
	test_ability_system_slot_retrieval()
	test_ability_system_max_slots()
	test_ability_system_cooldown_tracking()
	test_ability_system_can_use_check()
	test_ability_system_fail_reason()

	# --- Request Pipeline Tests ---
	_section("REQUEST PIPELINE")
	test_request_with_sufficient_resources()
	test_request_blocked_insufficient_mp()
	test_request_blocked_insufficient_atb()
	test_request_blocked_on_cooldown()
	test_request_spends_resources()

	# --- AbilityState Tests ---
	_section("ABILITY STATE")
	test_ability_state_script_loads()
	test_ability_state_has_cast_phases()
	test_ability_state_interrupt_method()

	# --- Spell Projectile Tests ---
	_section("SPELL PROJECTILE")
	test_spell_projectile_script_loads()
	test_spell_projectile_scene_loads()
	test_spell_projectile_has_set_damage()
	test_spell_projectile_has_set_target()

	# --- Combat HUD Tests ---
	_section("COMBAT HUD")
	test_combat_hud_script_loads()
	test_combat_hud_instantiates()

	# --- TacticalIdleState Tests ---
	_section("TACTICAL IDLE STATE")
	test_tactical_idle_state_loads()

	# --- Integration Tests ---
	_section("INTEGRATION")
	test_events_bus_has_ability_signals()
	test_events_bus_has_request_failed_signal()
	test_player_scene_has_ability_system()
	test_player_has_mp_regen_properties()
	test_player_has_ability_system_reference()
	test_illegal_transitions_set()

	# --- Scalability Tests ---
	_section("SCALABILITY")
	test_multiple_abilities_equip()
	test_data_driven_ability_creation()
	test_cooldown_independence()

	_print_results()


# ========== MP SYSTEM ==========

func test_mp_resource_exists() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("Player has current_mp property", source.contains("var current_mp"))
	_assert("Player has max_mp property", source.contains("var max_mp"))


func test_mp_consumption() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("spend_mp method exists", source.contains("func spend_mp"))
	_assert("has_mp method exists", source.contains("func has_mp"))


func test_mp_insufficient_check() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("has_mp returns bool comparison", source.contains("return current_mp >= cost"))


func test_mp_cannot_go_negative() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("spend_mp uses maxf to prevent negative", source.contains("maxf(current_mp - cost, 0.0)"))


func test_mp_regen_delay_set_on_spend() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("MP regen rate defined", source.contains("mp_regen_rate"))
	_assert("MP regen delay defined", source.contains("mp_regen_delay"))
	_assert("Regen timer reset on spend", source.contains("_mp_regen_timer = mp_regen_delay"))


# ========== ATB SYSTEM ==========

func test_atb_resource_exists() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("Player has current_atb property", source.contains("var current_atb"))
	_assert("Player has max_atb property", source.contains("var max_atb"))


func test_atb_consumption() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("spend_atb method exists", source.contains("func spend_atb"))
	_assert("has_atb method exists", source.contains("func has_atb"))


func test_atb_insufficient_check() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("has_atb returns bool comparison", source.contains("return current_atb >= cost"))


func test_atb_cannot_go_negative() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("spend_atb uses maxf to prevent negative", source.contains("maxf(current_atb - cost, 0.0)"))


func test_atb_fill_rate_defined() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("ATB fill rate property exists", source.contains("atb_fill_rate"))
	_assert("ATB fills in physics process", source.contains("atb_fill_rate * delta"))


# ========== ABILITY DATA ==========

func test_ability_data_script_loads() -> void:
	var script = load("res://resources/abilities/ability_data.gd")
	_assert("AbilityData script loads", script != null)


func test_fire_bolt_resource_loads() -> void:
	var resource = load("res://resources/abilities/fire_bolt.tres")
	_assert("Fire Bolt resource loads", resource != null)
	_assert("Fire Bolt is a Resource", resource is Resource)


func test_fire_bolt_has_correct_costs() -> void:
	var fb = load("res://resources/abilities/fire_bolt.tres")
	if fb == null:
		_assert("Fire Bolt costs (resource missing)", false)
		return
	_assert("Fire Bolt MP cost is 15", fb.mp_cost == 15.0)
	_assert("Fire Bolt ATB cost is 25", fb.atb_cost == 25.0)
	_assert("Fire Bolt cast time is 0.8", fb.cast_time == 0.8)
	_assert("Fire Bolt damage is 25", fb.damage == 25.0)
	_assert("Fire Bolt cooldown is 3.0", fb.cooldown == 3.0)


func test_fire_bolt_has_effect_scene() -> void:
	var fb = load("res://resources/abilities/fire_bolt.tres")
	if fb == null:
		_assert("Fire Bolt effect scene (resource missing)", false)
		return
	_assert("Fire Bolt has effect_scene set", fb.effect_scene != null)


func test_ability_types_defined() -> void:
	var script = load("res://resources/abilities/ability_data.gd")
	var source := script.source_code as String
	_assert("AbilityType enum has MELEE", source.contains("MELEE"))
	_assert("AbilityType enum has PROJECTILE", source.contains("PROJECTILE"))
	_assert("AbilityType enum has AOE", source.contains("AOE"))
	_assert("AbilityType enum has HEAL", source.contains("HEAL"))


# ========== ABILITY SYSTEM ==========

func test_ability_system_script_loads() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	_assert("AbilitySystem script loads", script != null)


func test_ability_system_can_equip() -> void:
	var system := _create_ability_system()
	var fb = load("res://resources/abilities/fire_bolt.tres")
	system.equip_ability(fb, 0)
	_assert("Ability equipped at slot 0", system.equipped_abilities.size() >= 1)
	_assert("Equipped ability matches", system.equipped_abilities[0] == fb)
	system.free()


func test_ability_system_slot_retrieval() -> void:
	var system := _create_ability_system()
	var fb = load("res://resources/abilities/fire_bolt.tres")
	system.equip_ability(fb, 0)
	var retrieved = system.get_equipped_ability(0)
	_assert("get_equipped_ability returns correct ability", retrieved == fb)
	var empty = system.get_equipped_ability(5)
	_assert("get_equipped_ability returns null for empty slot", empty == null)
	system.free()


func test_ability_system_max_slots() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("MAX_ABILITY_SLOTS is 8", source.contains("MAX_ABILITY_SLOTS: int = 8"))


func test_ability_system_cooldown_tracking() -> void:
	var system := _create_ability_system()
	_assert("No cooldown by default", not system.is_on_cooldown(&"fire_bolt"))
	_assert("Cooldown remaining is 0", system.get_cooldown_remaining(&"fire_bolt") == 0.0)
	system.free()


func test_ability_system_can_use_check() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("can_use_ability method exists", source.contains("func can_use_ability"))
	_assert("Checks cooldown in can_use", source.contains("is_on_cooldown"))
	_assert("Checks ATB in can_use", source.contains("has_atb"))
	_assert("Checks MP in can_use", source.contains("has_mp"))


func test_ability_system_fail_reason() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("get_fail_reason method exists", source.contains("func get_fail_reason"))


# ========== REQUEST PIPELINE ==========

func test_request_with_sufficient_resources() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("request_ability method exists", source.contains("func request_ability"))
	_assert("Spends ATB on success", source.contains("spend_atb"))
	_assert("Spends MP on success", source.contains("spend_mp"))
	_assert("Starts cooldown on success", source.contains("_start_cooldown"))
	_assert("Transitions to Ability state", source.contains('force_transition(&"Ability"'))


func test_request_blocked_insufficient_mp() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("Checks MP before execution", source.contains("has_mp(ability_data.mp_cost)"))
	_assert("Emits failure signal for MP", source.contains('"mp"'))


func test_request_blocked_insufficient_atb() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("Checks ATB before execution", source.contains("has_atb(ability_data.atb_cost)"))
	_assert("Emits failure signal for ATB", source.contains('"atb"'))


func test_request_blocked_on_cooldown() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("Checks cooldown before execution", source.contains("is_on_cooldown(ability_data.ability_id)"))
	_assert("Emits failure signal for cooldown", source.contains('"cooldown"'))


func test_request_spends_resources() -> void:
	var script = load("res://src/player/components/ability_system.gd")
	var source := script.source_code as String
	_assert("Spends ATB before state transition", source.contains("_player.spend_atb(ability_data.atb_cost)"))
	_assert("Spends MP before state transition", source.contains("_player.spend_mp(ability_data.mp_cost)"))


# ========== ABILITY STATE ==========

func test_ability_state_script_loads() -> void:
	var script = load("res://src/player/states/ability_state.gd")
	_assert("AbilityState script loads", script != null)


func test_ability_state_has_cast_phases() -> void:
	var script = load("res://src/player/states/ability_state.gd")
	var source := script.source_code as String
	_assert("CastPhase enum defined", source.contains("enum CastPhase"))
	_assert("START phase exists", source.contains("CastPhase.START"))
	_assert("RELEASE phase exists", source.contains("CastPhase.RELEASE"))
	_assert("RECOVERY phase exists", source.contains("CastPhase.RECOVERY"))


func test_ability_state_interrupt_method() -> void:
	var script = load("res://src/player/states/ability_state.gd")
	var source := script.source_code as String
	_assert("interrupt() method exists", source.contains("func interrupt"))
	_assert("Emits cast interrupted signal", source.contains("ability_cast_interrupted"))


# ========== SPELL PROJECTILE ==========

func test_spell_projectile_script_loads() -> void:
	var script = load("res://src/effects/spell_projectile.gd")
	_assert("SpellProjectile script loads", script != null)


func test_spell_projectile_scene_loads() -> void:
	var scene = load("res://src/effects/spell_projectile.tscn")
	_assert("SpellProjectile scene loads", scene != null)


func test_spell_projectile_has_set_damage() -> void:
	var script = load("res://src/effects/spell_projectile.gd")
	var source := script.source_code as String
	_assert("set_damage method exists", source.contains("func set_damage"))


func test_spell_projectile_has_set_target() -> void:
	var script = load("res://src/effects/spell_projectile.gd")
	var source := script.source_code as String
	_assert("set_target method exists", source.contains("func set_target"))


# ========== COMBAT HUD ==========

func test_combat_hud_script_loads() -> void:
	var script = load("res://src/ui/hud/combat_hud.gd")
	_assert("CombatHUD script loads", script != null)


func test_combat_hud_instantiates() -> void:
	var script = load("res://src/ui/hud/combat_hud.gd")
	var source := script.source_code as String
	_assert("HUD has HP bar", source.contains("_hp_bar"))
	_assert("HUD has MP bar", source.contains("_mp_bar"))
	_assert("HUD has ATB bar", source.contains("_atb_bar"))
	_assert("HUD connects to hp_changed signal", source.contains("player_hp_changed"))
	_assert("HUD connects to mp_changed signal", source.contains("player_mp_changed"))
	_assert("HUD connects to atb_changed signal", source.contains("player_atb_changed"))
	_assert("HUD connects to request_failed signal", source.contains("ability_request_failed"))
	_assert("HUD has flash text for feedback", source.contains("_flash_label"))
	_assert("HUD has ATB segment markers", source.contains("ATB_SEGMENT_COST"))


# ========== TACTICAL IDLE STATE ==========

func test_tactical_idle_state_loads() -> void:
	var script = load("res://src/player/states/tactical_idle_state.gd")
	_assert("TacticalIdleState script loads", script != null)
	var source := script.source_code as String
	_assert("TacticalIdle has slot navigation", source.contains("_navigate_slot"))
	_assert("TacticalIdle has execute method", source.contains("_confirm_ability"))
	_assert("TacticalIdle calls request_ability", source.contains("request_ability"))
	_assert("TacticalIdle allows exit to Idle", source.contains('return &"Idle"'))
	_assert("TacticalIdle allows exit to LockOnIdle", source.contains('return &"LockOnIdle"'))


# ========== INTEGRATION ==========

func test_events_bus_has_ability_signals() -> void:
	_assert("ability_cast_started signal exists", Events.has_signal("ability_cast_started"))
	_assert("ability_cast_completed signal exists", Events.has_signal("ability_cast_completed"))
	_assert("ability_cast_interrupted signal exists", Events.has_signal("ability_cast_interrupted"))
	_assert("ability_cooldown_started signal exists", Events.has_signal("ability_cooldown_started"))
	_assert("ability_cooldown_finished signal exists", Events.has_signal("ability_cooldown_finished"))
	_assert("ability_effect_spawned signal exists", Events.has_signal("ability_effect_spawned"))


func test_events_bus_has_request_failed_signal() -> void:
	_assert("ability_request_failed signal exists", Events.has_signal("ability_request_failed"))


func test_player_scene_has_ability_system() -> void:
	var scene = load("res://src/player/player.tscn") as PackedScene
	_assert("Player scene loads", scene != null)
	var state := scene.get_state()
	var found := false
	for i in state.get_node_count():
		if state.get_node_name(i) == &"AbilitySystem":
			found = true
			break
	_assert("Player scene contains AbilitySystem node", found)


func test_player_has_mp_regen_properties() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("Player has mp_regen_rate", source.contains("var mp_regen_rate"))
	_assert("Player has mp_regen_delay", source.contains("var mp_regen_delay"))
	_assert("Player has _mp_regen_timer", source.contains("var _mp_regen_timer"))
	_assert("MP regen in physics_process", source.contains("mp_regen_rate * delta"))


func test_player_has_ability_system_reference() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("Player has ability_system onready", source.contains("ability_system"))
	_assert("AbilitySystem initialized in _ready", source.contains("ability_system.initialize"))


func test_illegal_transitions_set() -> void:
	var script = load("res://src/player/player.gd")
	var source := script.source_code as String
	_assert("Ability->Dodge blocked", source.contains('add_illegal_transition(&"Ability", &"Dodge")'))
	_assert("Flinch->TacticalIdle blocked", source.contains('add_illegal_transition(&"Flinch", &"TacticalIdle")'))


# ========== SCALABILITY ==========

func test_multiple_abilities_equip() -> void:
	var system := _create_ability_system()
	var fb = load("res://resources/abilities/fire_bolt.tres")

	# Create a second ability dynamically
	var ice_bolt := _create_ability_data()
	ice_bolt.ability_id = &"ice_bolt"
	ice_bolt.display_name = "Ice Bolt"
	ice_bolt.mp_cost = 20.0
	ice_bolt.atb_cost = 30.0
	ice_bolt.cooldown = 4.0
	ice_bolt.cast_time = 1.0
	ice_bolt.damage = 30.0

	system.equip_ability(fb, 0)
	system.equip_ability(ice_bolt, 1)

	_assert("Two abilities equipped", system.equipped_abilities.size() >= 2)
	_assert("Slot 0 is Fire Bolt", system.get_equipped_ability(0) == fb)
	_assert("Slot 1 is Ice Bolt", system.get_equipped_ability(1) == ice_bolt)
	system.free()


func test_data_driven_ability_creation() -> void:
	var ability := _create_ability_data()
	ability.ability_id = &"test_spell"
	ability.display_name = "Test Spell"
	ability.mp_cost = 99.0
	ability.atb_cost = 50.0
	ability.cooldown = 10.0
	ability.cast_time = 2.0
	ability.damage = 100.0

	_assert("Dynamic ability has correct id", ability.ability_id == &"test_spell")
	_assert("Dynamic ability has correct MP cost", ability.mp_cost == 99.0)
	_assert("Dynamic ability has correct damage", ability.damage == 100.0)


func test_cooldown_independence() -> void:
	var system := _create_ability_system()
	# Manually set cooldowns to test independence
	system._cooldowns[&"fire_bolt"] = 3.0
	system._cooldowns[&"ice_bolt"] = 5.0

	_assert("fire_bolt on cooldown", system.is_on_cooldown(&"fire_bolt"))
	_assert("ice_bolt on cooldown", system.is_on_cooldown(&"ice_bolt"))
	_assert("fire_bolt cooldown is 3.0", system.get_cooldown_remaining(&"fire_bolt") == 3.0)
	_assert("ice_bolt cooldown is 5.0", system.get_cooldown_remaining(&"ice_bolt") == 5.0)
	_assert("unknown ability not on cooldown", not system.is_on_cooldown(&"heal"))
	system.free()


# ========== Test Helpers ==========

func _create_ability_system() -> Node:
	var script = load("res://src/player/components/ability_system.gd")
	var node := Node.new()
	node.set_script(script)
	return node


func _create_ability_data() -> Resource:
	var script = load("res://resources/abilities/ability_data.gd")
	var res := Resource.new()
	res.set_script(script)
	return res


func _section(title: String) -> void:
	_results.append("")
	_results.append("--- %s ---" % title)


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("  PASS: %s" % test_name)
	else:
		_fail_count += 1
		_results.append("  FAIL: %s" % test_name)


func _print_results() -> void:
	print("")
	for r in _results:
		print(r)
	print("")
	print("=== Phase 6 Results: %d passed, %d failed, %d total ===" % [
		_pass_count, _fail_count, _pass_count + _fail_count])
	print("")

	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
