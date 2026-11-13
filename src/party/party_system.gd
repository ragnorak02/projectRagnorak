## Party system coordinator — manages roster, active member switching,
## team meter, team attacks, and companion AI instances.
##
## v5 party switch (Package CC) — "swap identities, not bodies":
## the Player node is always the controlled input body (camera, lock-on, battle
## mode and the state machine never move). A switch exchanges the two bodies'
## IDENTITIES: member data, HP/MP/ATB (+ max values and rates), command list,
## visual model (the child of each body's VisualRoot), and their positions /
## facing, with a flash at both spots. members[i]["node"] always points at the
## body currently embodying member i, so members[active_index]["node"] is the
## Player and player.get_member_data() returns the controlled member.
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

# Input-driven switching (D-pad Up/Down, Tab via `party_switch` action) in
# Free Roam and Battle. Menus own the D-pad while open (GameState != PLAYING or
# the tree is paused, so this handler stays out of their way).
const SWITCH_COOLDOWN := 1.0  # seconds, real time (ignores Engine.time_scale)
var _last_switch_msec: int = -100000
var _active_player_dead: bool = false  # Tracked via Events.player_died / player_hp_changed

# v5: control transfer is real (identity swap), so input switching is on.
const INPUT_SWITCH_ENABLED := true


func _ready() -> void:
	Events.attack_hit.connect(_on_attack_hit)
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(_on_player_alive)
	Events.player_hp_changed.connect(_on_player_hp_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not INPUT_SWITCH_ENABLED:
		return
	if not event.is_action_pressed(&"party_switch") or event.is_echo():
		return
	if not can_switch_from_input():
		return
	get_viewport().set_input_as_handled()
	if get_switch_cooldown_remaining() > 0.0:
		return
	if switch_member_battle():
		_last_switch_msec = Time.get_ticks_msec()


## Seconds until the next input switch is allowed (real time).
func get_switch_cooldown_remaining() -> float:
	return maxf(0.0, SWITCH_COOLDOWN - float(Time.get_ticks_msec() - _last_switch_msec) / 1000.0)


func can_switch_from_input() -> bool:
	## True only in normal gameplay: not paused, not tactical mode, not in a
	## cutscene/dialogue, and the active member is not dead or downed.
	if not _initialized or members.size() < 2:
		return false
	if get_tree().paused:
		return false
	# Blocks PAUSED, TACTICAL_MODE, CUTSCENE, LOADING, MAIN_MENU, GAME_OVER.
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if _is_dialogue_active():
		return false
	if _is_active_member_incapacitated():
		return false
	# Body-level gate (dodge, casts, attacks, flinch, carry, ledge states).
	var node: Node = members[active_index]["node"]
	if node.has_method("can_party_switch") and not node.can_party_switch():
		return false
	return true


func _is_dialogue_active() -> bool:
	for ui in get_tree().get_nodes_in_group(&"dialogue_ui"):
		if ui.has_method("is_dialogue_active") and ui.is_dialogue_active():
			return true
	return false


func _is_active_member_incapacitated() -> bool:
	if active_index >= members.size():
		return true
	var node: Node3D = members[active_index]["node"]
	if not is_instance_valid(node):
		return true
	if node.has_method("is_downed") and node.is_downed():
		return true
	if node.is_in_group(&"player") and _active_player_dead:
		return true
	return false


func _on_player_died() -> void:
	_active_player_dead = true


func _on_player_alive() -> void:
	_active_player_dead = false


func _on_player_hp_changed(current: float, _maximum: float) -> void:
	_active_player_dead = current <= 0.0


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

func switch_member() -> bool:
	## Hand control to the next non-downed member. Returns true if it switched.
	if members.size() < 2:
		return false

	# Find next non-downed member
	var next_index := (active_index + 1) % members.size()
	var attempts := 0
	while attempts < members.size():
		var node: Node3D = members[next_index]["node"]
		if next_index != active_index and node.has_method("is_downed") and node.is_downed():
			next_index = (next_index + 1) % members.size()
			attempts += 1
			continue
		break

	if next_index == active_index:
		Events.save_feedback.emit("No other members available")
		return false

	var old_id: StringName = members[active_index]["id"]
	if not _swap_identities(active_index, next_index, true):
		return false
	var new_id: StringName = members[active_index]["id"]
	AudioManager.play_sfx_named("party_switch")
	Events.party_member_switched.emit(old_id, new_id)
	return true


## Exchange identities between the Player body (members[from_index]) and the
## AI body embodying members[to_index]. `swap_positions` = false on save load
## (the saved position already belongs to the controlled member).
func _swap_identities(from_index: int, to_index: int, swap_positions: bool) -> bool:
	var player: Node3D = members[from_index]["node"]
	var other: Node3D = members[to_index]["node"]
	if not is_instance_valid(player) or not is_instance_valid(other):
		return false
	if not player.has_method("import_member_state") or not other.has_method("import_member_state"):
		return false
	var player_state: Dictionary = player.export_member_state()
	var other_state: Dictionary = other.export_member_state()

	if swap_positions and player.is_inside_tree() and other.is_inside_tree():
		var p_xform := player.global_transform
		var o_xform := other.global_transform
		player.global_transform = Transform3D(Basis(Vector3.UP, o_xform.basis.get_euler().y), o_xform.origin)
		other.global_transform = Transform3D(Basis(Vector3.UP, p_xform.basis.get_euler().y), p_xform.origin)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if other is CharacterBody3D:
			(other as CharacterBody3D).velocity = Vector3.ZERO
		var parent: Node = player.get_parent()
		StanceAuraVfx.flash(parent, p_xform.origin, true)
		StanceAuraVfx.flash(parent, o_xform.origin, true)

	_swap_visuals(player, other)

	members[from_index]["node"] = other
	members[to_index]["node"] = player
	members[from_index]["is_active"] = false
	members[to_index]["is_active"] = true
	active_index = to_index

	player.import_member_state(members[to_index]["data"], other_state)
	other.import_member_state(members[from_index]["data"], player_state)
	return true


## The member's model travels with the identity: exchange the children of each
## body's VisualRoot (local transforms are kept, so authored offsets hold).
func _swap_visuals(a: Node, b: Node) -> void:
	var root_a: Node3D = a.get(&"visual_root")
	var root_b: Node3D = b.get(&"visual_root")
	if root_a == null or root_b == null:
		return
	var models_a: Array[Node] = root_a.get_children()
	var models_b: Array[Node] = root_b.get_children()
	for m in models_a:
		root_a.remove_child(m)
	for m in models_b:
		root_b.remove_child(m)
	for m in models_a:
		root_b.add_child(m)
	for m in models_b:
		root_a.add_child(m)
	if a.has_method("refresh_visual"):
		a.refresh_visual()
	if b.has_method("refresh_visual"):
		b.refresh_visual()


func switch_member_battle() -> bool:
	## Battle switching — same as switch_member but allowed during combat.
	return switch_member()


func switch_member_menu() -> bool:
	## Out-of-battle switching via pause menu.
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return switch_member()
	return false


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
		"active_id": String(members[active_index]["id"]) if active_index < members.size() else "",
		"team_meter": team_meter,
	}


func load_save_data(data: Dictionary) -> void:
	team_meter = data.get("team_meter", 0.0)
	Events.team_meter_changed.emit(team_meter, team_meter_max)
	# v5: restore who is controlled (silent identity swap, positions kept).
	var active_id: String = data.get("active_id", "")
	if active_id != "" and active_index < members.size() and String(members[active_index]["id"]) != active_id:
		for i in members.size():
			if String(members[i]["id"]) == active_id:
				_swap_identities(active_index, i, false)
				break
	# Companion state is restored via companion_ai.load_save_data
	var member_saves: Array = data.get("members", [])
	for save_entry in member_saves:
		var id: String = save_entry.get("id", "")
		if save_entry.has("companion_data"):
			for m in members:
				if String(m["id"]) == id and m["node"].has_method("load_save_data"):
					m["node"].load_save_data(save_entry["companion_data"])
