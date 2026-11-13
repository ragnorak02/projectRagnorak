## Manages ability slots, cooldowns, and the request/execution pipeline.
## Validates ATB and MP before allowing ability execution.
class_name AbilitySystem
extends Node

const MAX_ABILITY_SLOTS: int = 8

var _player: CharacterBody3D
var _cooldowns: Dictionary = {}  # ability_id -> remaining seconds
var equipped_abilities: Array[AbilityData] = []
var _casting_ability: AbilityData = null

## v5 BB6: Command Menu context, written by TacticalIdleState (read-only for
## the HUD). menu_airborne = the menu opened in the air (aerial list shown).
var menu_airborne: bool = false
## v5 BB1: the ability whose target step is open (null otherwise).
var menu_ability: AbilityData = null


func _ready() -> void:
	Events.tactical_command_selected.connect(_on_tactical_command_selected)
	Events.ability_cast_completed.connect(_on_cast_completed)
	Events.ability_cast_interrupted.connect(_on_cast_interrupted)


func initialize(player: CharacterBody3D) -> void:
	_player = player


func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)


func request_ability(ability_data: AbilityData) -> bool:
	if _player == null:
		return false

	# Check cooldown
	if is_on_cooldown(ability_data.ability_id):
		var remaining := get_cooldown_remaining(ability_data.ability_id)
		Events.ability_request_failed.emit("cooldown", ability_data)
		if DebugFlags.DEBUG_COMBAT:
			print("AbilitySystem: %s on cooldown (%.1fs left)" % [ability_data.display_name, remaining])
		return false

	# Check ATB
	if not _player.has_atb(ability_data.atb_cost):
		Events.ability_request_failed.emit("atb", ability_data)
		if DebugFlags.DEBUG_COMBAT:
			print("AbilitySystem: Insufficient ATB for %s (need %.0f, have %.0f)" % [
				ability_data.display_name, ability_data.atb_cost, _player.current_atb])
		return false

	# Check MP
	if not _player.has_mp(ability_data.mp_cost):
		Events.ability_request_failed.emit("mp", ability_data)
		if DebugFlags.DEBUG_COMBAT:
			print("AbilitySystem: Insufficient MP for %s (need %.0f, have %.0f)" % [
				ability_data.display_name, ability_data.mp_cost, _player.current_mp])
		return false

	# Spend resources
	_player.spend_atb(ability_data.atb_cost)
	_player.spend_mp(ability_data.mp_cost)

	# Start cooldown
	_start_cooldown(ability_data)

	# Track what we're casting
	_casting_ability = ability_data

	# Transition player to ability state
	_player.state_machine.force_transition(&"Ability", {
		"ability_data": ability_data,
		"cast_time": ability_data.cast_time,
	})

	if DebugFlags.DEBUG_COMBAT:
		print("AbilitySystem: Casting %s (MP: -%.0f, ATB: -%.0f)" % [
			ability_data.display_name, ability_data.mp_cost, ability_data.atb_cost])

	return true


func request_ability_with_target(ability_data: AbilityData, target: Node3D) -> bool:
	if _player == null:
		return false

	# v5 BB1: an enemy beyond this ability's range can't be confirmed.
	if target != null and target != _player and target.is_in_group(&"enemies") 			and not is_in_range(ability_data, target):
		Events.ability_request_failed.emit("out_of_range", ability_data)
		return false

	# Validate resources
	if is_on_cooldown(ability_data.ability_id):
		Events.ability_request_failed.emit("cooldown", ability_data)
		return false
	if not _player.has_atb(ability_data.atb_cost):
		Events.ability_request_failed.emit("atb", ability_data)
		return false
	if not _player.has_mp(ability_data.mp_cost):
		Events.ability_request_failed.emit("mp", ability_data)
		return false

	# Spend resources
	_player.spend_atb(ability_data.atb_cost)
	_player.spend_mp(ability_data.mp_cost)
	_start_cooldown(ability_data)
	_casting_ability = ability_data

	# Transition with explicit target
	_player.state_machine.force_transition(&"Ability", {
		"ability_data": ability_data,
		"cast_time": ability_data.cast_time,
		"target": target,
	})

	if DebugFlags.DEBUG_COMBAT:
		print("AbilitySystem: Casting %s → %s (MP: -%.0f, ATB: -%.0f)" % [
			ability_data.display_name, target.name, ability_data.mp_cost, ability_data.atb_cost])

	return true


func can_use_ability(ability_data: AbilityData) -> bool:
	if _player == null:
		return false
	if is_on_cooldown(ability_data.ability_id):
		return false
	if not _player.has_atb(ability_data.atb_cost):
		return false
	if not _player.has_mp(ability_data.mp_cost):
		return false
	return true


func get_fail_reason(ability_data: AbilityData) -> String:
	if is_on_cooldown(ability_data.ability_id):
		return "cooldown"
	if not _player.has_atb(ability_data.atb_cost):
		return "atb"
	if not _player.has_mp(ability_data.mp_cost):
		return "mp"
	return ""


# --- Cooldown Management ---

func is_on_cooldown(ability_id: StringName) -> bool:
	return _cooldowns.has(ability_id) and _cooldowns[ability_id] > 0.0


func get_cooldown_remaining(ability_id: StringName) -> float:
	if _cooldowns.has(ability_id):
		return maxf(_cooldowns[ability_id], 0.0)
	return 0.0


func get_cooldown_fraction(ability_id: StringName, total_cooldown: float) -> float:
	if total_cooldown <= 0.0:
		return 0.0
	return get_cooldown_remaining(ability_id) / total_cooldown


func _start_cooldown(ability_data: AbilityData) -> void:
	if ability_data.cooldown > 0.0:
		_cooldowns[ability_data.ability_id] = ability_data.cooldown
		Events.ability_cooldown_started.emit(ability_data.ability_id, ability_data.cooldown)


func _tick_cooldowns(delta: float) -> void:
	var finished: Array[StringName] = []
	for ability_id in _cooldowns:
		_cooldowns[ability_id] -= delta
		if _cooldowns[ability_id] <= 0.0:
			finished.append(ability_id)

	for ability_id in finished:
		_cooldowns.erase(ability_id)
		Events.ability_cooldown_finished.emit(ability_id)


# --- Equipped Abilities ---

func equip_ability(ability_data: AbilityData, slot: int = -1) -> void:
	if slot < 0:
		if equipped_abilities.size() < MAX_ABILITY_SLOTS:
			equipped_abilities.append(ability_data)
	elif slot < MAX_ABILITY_SLOTS:
		while equipped_abilities.size() <= slot:
			equipped_abilities.append(null)
		equipped_abilities[slot] = ability_data


func get_equipped_ability(slot: int) -> AbilityData:
	if slot >= 0 and slot < equipped_abilities.size():
		return equipped_abilities[slot]
	return null


# --- v5 BB1: Range rule (user rule, item 3) ---

## Ability range in metres (AbilityData.range; old resources fall back to 20 m).
static func range_of(ability: AbilityData) -> float:
	if ability == null:
		return 0.0
	var r = ability.get(&"range")
	return float(r) if r != null and float(r) > 0.0 else AbilityData.DEFAULT_RANGE


## The active member's maximum offensive reach: the longest `range` across the
## equipped offensive abilities (SELF_ALLY abilities don't target enemies).
## Bounds the Command Menu target list and lock-on acquisition (DD).
func get_max_range() -> float:
	var best := 0.0
	for a in equipped_abilities:
		if a != null and a.is_offensive():
			best = maxf(best, range_of(a))
	return best if best > 0.0 else AbilityData.DEFAULT_RANGE


## True when `target` is within `ability`'s range of the caster.
func is_in_range(ability: AbilityData, target: Node3D) -> bool:
	if _player == null or ability == null or target == null or not is_instance_valid(target):
		return false
	if not ability.is_offensive():
		return true
	return _player.global_position.distance_to(target.global_position) <= range_of(ability) + 0.01


## Living enemies within get_max_range(), nearest-first (ties by instance id).
## Single source of truth for the target step (TacticalIdleState + HUD).
func get_enemy_candidates() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _player == null or not _player.is_inside_tree():
		return out
	var max_r := get_max_range()
	var origin: Vector3 = _player.global_position
	for enemy in _player.get_tree().get_nodes_in_group(&"enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		if "_is_dead" in enemy and enemy._is_dead:
			continue
		if not enemy.is_inside_tree():
			continue
		if origin.distance_to(enemy.global_position) > max_r + 0.01:
			continue
		out.append(enemy)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var da := origin.distance_squared_to(a.global_position)
		var db := origin.distance_squared_to(b.global_position)
		if is_equal_approx(da, db):
			return a.get_instance_id() < b.get_instance_id()
		return da < db)
	return out


# --- v5 BB6: Command Menu list (aerial / ground) ---

## Slots shown in the Command Menu, as indices into equipped_abilities.
## Grounded: everything except aerial_only. Airborne: everything except
## aerial_only is still listed (ground_only rows grey "Grounded only") and the
## aerial_only abilities come FIRST so the air list leads with them.
func get_menu_slots(airborne: bool) -> Array[int]:
	var air: Array[int] = []
	var rest: Array[int] = []
	for i in equipped_abilities.size():
		var a: AbilityData = equipped_abilities[i]
		if a == null:
			continue
		if a.aerial_only:
			if airborne:
				air.append(i)
		else:
			rest.append(i)
	return air + rest


## Menu-validity of an ability for the current altitude ("" = valid).
func get_air_block_reason(ability: AbilityData, airborne: bool) -> String:
	if ability == null:
		return "unavailable"
	if airborne and ability.ground_only:
		return "grounded_only"
	if not airborne and ability.aerial_only:
		return "airborne_only"
	return ""


# --- Signal Handlers ---

func _on_tactical_command_selected(ability_data: Resource) -> void:
	if ability_data is AbilityData:
		request_ability(ability_data as AbilityData)


func _on_cast_completed(_ability_data: Resource) -> void:
	_casting_ability = null


func _on_cast_interrupted(_ability_data: Resource) -> void:
	_casting_ability = null
