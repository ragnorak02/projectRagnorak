## Manages ability slots, cooldowns, and the request/execution pipeline.
## Validates ATB and MP before allowing ability execution.
class_name AbilitySystem
extends Node

const MAX_ABILITY_SLOTS: int = 8

var _player: CharacterBody3D
var _cooldowns: Dictionary = {}  # ability_id -> remaining seconds
var equipped_abilities: Array[AbilityData] = []
var _casting_ability: AbilityData = null


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


# --- Signal Handlers ---

func _on_tactical_command_selected(ability_data: Resource) -> void:
	if ability_data is AbilityData:
		request_ability(ability_data as AbilityData)


func _on_cast_completed(_ability_data: Resource) -> void:
	_casting_ability = null


func _on_cast_interrupted(_ability_data: Resource) -> void:
	_casting_ability = null
