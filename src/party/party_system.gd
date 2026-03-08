## Party system coordinator — manages roster, active member switching,
## team meter, team attacks, and companion AI instances.
extends Node

const CompanionAIScript := preload("res://src/party/companion_ai.gd")

# Roster
var members: Array[Dictionary] = []  # [{id, data, node, is_active}]
var active_index: int = 0

# Team meter (shared resource for team attacks)
var team_meter: float = 0.0
var team_meter_max: float = 100.0
var team_meter_fill_per_hit: float = 5.0  # Gained per damage dealt
var team_meter_fill_per_atb: float = 2.0  # Gained per ATB spent

# State
var _initialized: bool = false


func _ready() -> void:
	Events.attack_hit.connect(_on_attack_hit)


func initialize(player: Node3D, companion_data: Resource = null) -> void:
	if _initialized:
		return
	_initialized = true

	# Add the player as first member
	var hero_data := load("res://resources/characters/hero.tres")
	members.append({
		"id": &"hero",
		"data": hero_data,
		"node": player,
		"is_active": true,
	})

	# Add companion if data provided
	if companion_data:
		_spawn_companion(companion_data, player)


func _spawn_companion(data: Resource, follow_target: Node3D) -> void:
	var companion := CharacterBody3D.new()
	companion.set_script(CompanionAIScript)
	get_tree().current_scene.add_child(companion)
	companion.initialize(data, follow_target)

	# Position near player
	companion.global_position = follow_target.global_position + Vector3(2, 0, 1)

	members.append({
		"id": data.member_id,
		"data": data,
		"node": companion,
		"is_active": false,
	})

	Events.party_member_joined.emit(data.member_id)


func add_member(data: Resource, follow_target: Node3D) -> void:
	# Check not already in party
	for m in members:
		if m["id"] == data.member_id:
			return
	_spawn_companion(data, follow_target)


func get_member_count() -> int:
	return members.size()


func get_active_member() -> Node3D:
	if active_index < members.size():
		return members[active_index]["node"]
	return null


func get_companion() -> Node3D:
	for m in members:
		if not m["is_active"]:
			return m["node"]
	return null


func is_member_downed(member_id: StringName) -> bool:
	for m in members:
		if m["id"] == member_id:
			var node: Node3D = m["node"]
			if node.has_method("is_downed"):
				return node.is_downed()
	return false


# --- Switching ---

func switch_member() -> void:
	if members.size() < 2:
		return

	# Find next non-downed member
	var next_index := (active_index + 1) % members.size()
	var attempts := 0
	while attempts < members.size():
		var node: Node3D = members[next_index]["node"]
		if node.has_method("is_downed") and node.is_downed():
			next_index = (next_index + 1) % members.size()
			attempts += 1
			continue
		break

	if next_index == active_index:
		Events.save_feedback.emit("No other members available")
		return

	var old_id: StringName = members[active_index]["id"]
	members[active_index]["is_active"] = false

	active_index = next_index
	members[active_index]["is_active"] = true
	var new_id: StringName = members[active_index]["id"]

	# Transfer control
	var old_node: Node3D = members[(active_index + members.size() - 1) % members.size()]["node"]
	var new_node: Node3D = members[active_index]["node"]

	# If old node was player, make it companion AI
	# If new node was companion AI, make it player-controlled
	# For now, camera switches via signal
	Events.party_member_switched.emit(old_id, new_id)


func switch_member_battle() -> void:
	## Battle switching — same as switch_member but allowed during combat.
	switch_member()


func switch_member_menu() -> void:
	## Out-of-battle switching via pause menu.
	if GameManager.current_state == GameManager.GameState.PAUSED:
		switch_member()


# --- Team Meter ---

func _on_attack_hit(_target: Node3D, damage: float) -> void:
	if damage > 0:
		add_team_meter(team_meter_fill_per_hit)


func add_team_meter(amount: float) -> void:
	team_meter = minf(team_meter + amount, team_meter_max)
	Events.team_meter_changed.emit(team_meter, team_meter_max)


func spend_team_meter(cost: float) -> bool:
	if team_meter < cost:
		return false
	team_meter -= cost
	Events.team_meter_changed.emit(team_meter, team_meter_max)
	return true


func has_team_meter(cost: float) -> bool:
	return team_meter >= cost


# --- Revive ---

func revive_member(member_id: StringName, hp_amount: float = -1.0) -> bool:
	for m in members:
		if m["id"] == member_id:
			var node: Node3D = m["node"]
			if node.has_method("revive"):
				node.revive(hp_amount)
				return true
	return false


# --- Traversal Flags ---

func get_party_traversal_flags() -> Array[String]:
	## Returns all traversal flags from all party members.
	var flags: Array[String] = []
	for m in members:
		var data: Resource = m["data"]
		if data and data.get("traversal_flags"):
			for flag in data.traversal_flags:
				if not flags.has(flag):
					flags.append(flag)
	return flags


func apply_traversal_flags() -> void:
	## Set progression flags from party member abilities.
	for flag in get_party_traversal_flags():
		SaveManager.set_flag(flag, true)


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var member_saves: Array[Dictionary] = []
	for m in members:
		var node: Node3D = m["node"]
		var entry: Dictionary = {
			"id": String(m["id"]),
			"is_active": m["is_active"],
		}
		if node.has_method("get_save_data") and not m["is_active"]:
			# Non-active members (companions) save their own state
			entry["companion_data"] = node.get_save_data()
		if m["data"]:
			entry["data_path"] = m["data"].resource_path
		member_saves.append(entry)
	return {
		"members": member_saves,
		"active_index": active_index,
		"team_meter": team_meter,
	}


func load_save_data(data: Dictionary) -> void:
	team_meter = data.get("team_meter", 0.0)
	Events.team_meter_changed.emit(team_meter, team_meter_max)
	# Companion state is restored via companion_ai.load_save_data
	var member_saves: Array = data.get("members", [])
	for save_entry in member_saves:
		var id: String = save_entry.get("id", "")
		if save_entry.has("companion_data"):
			for m in members:
				if String(m["id"]) == id and m["node"].has_method("load_save_data"):
					m["node"].load_save_data(save_entry["companion_data"])
