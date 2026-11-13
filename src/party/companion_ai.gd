## AI behavior for non-controlled party members.
## Follows the active player, attacks nearby enemies, and provides support.
##
## v5 party switch (Package CC): PartySystem swaps IDENTITIES between this body
## and the Player body (member data, HP/MP/ATB, command list, visual). This node
## can therefore embody any member (Taighe at start, Amaro after a switch).
## Identity API used by PartySystem:
##   export_member_state() -> Dictionary
##   import_member_state(data: Resource, state: Dictionary)
##   visual_root (Node3D; its single child is the member's model)
extends CharacterBody3D

@export var follow_distance: float = 3.0
@export var attack_range: float = 2.5
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 2.0
@export var move_speed: float = 7.0
@export var gravity: float = 20.0

var member_data: Resource = null  # PartyMemberData
var current_hp: float = 80.0
var max_hp: float = 80.0
var current_mp: float = 70.0
var max_mp: float = 70.0
var current_atb: float = 0.0
var max_atb: float = 100.0
var atb_fill_rate: float = 6.0

var mp_regen_rate: float = 2.0
## The embodied member's command list while AI-controlled (carried across switches).
var abilities: Array = []

var follow_target: Node3D = null
var _is_downed: bool = false
var _attack_cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _target_enemy: Node3D = null

enum AIState { FOLLOW, ATTACK, SUPPORT, DOWNED }
var ai_state: AIState = AIState.FOLLOW

# Visual
var visual_root: Node3D = null
var _mesh: MeshInstance3D  # Built-in capsule (null while another model is embodied)
var _anim: AnimationPlayer = null


func _ready() -> void:
	add_to_group(&"party_members")
	collision_layer = 2  # PlayerBody
	collision_mask = 1   # World

	# Build visual
	_build_visual()


func initialize(data: Resource, target: Node3D) -> void:
	member_data = data
	follow_target = target
	if data:
		max_hp = data.max_hp
		current_hp = max_hp
		max_mp = data.max_mp
		current_mp = max_mp
		max_atb = data.max_atb
		atb_fill_rate = data.atb_fill_rate
		attack_damage = data.attack_damage
		move_speed = data.move_speed
		mp_regen_rate = data.mp_regen_rate
		if data.has_method("get_starting_abilities"):
			abilities = data.get_starting_abilities()
		if _mesh and data.get("capsule_color"):
			_mesh.material_override.albedo_color = data.capsule_color
		# v5 EE: rigless member model replaces the capsule (dormant until a
		# .tres sets rigless + model_scene).
		var rv: Node3D = data.make_rigless_visual() if data.has_method("make_rigless_visual") else null
		if rv and visual_root:
			for c in visual_root.get_children():
				visual_root.remove_child(c)
				c.queue_free()
			visual_root.add_child(rv)
			refresh_visual()


func _physics_process(delta: float) -> void:
	if _is_downed:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# ATB fills passively; MP regenerates (same rule as the player body).
	if current_atb < max_atb:
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)
	if current_mp < max_mp:
		current_mp = minf(current_mp + mp_regen_rate * delta, max_mp)

	# Attack cooldown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	match ai_state:
		AIState.FOLLOW:
			_process_follow(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.SUPPORT:
			_process_follow(delta)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if _anim == null or not is_instance_valid(_anim):
		return
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var anim_name: StringName = &"walk" if horizontal > 0.5 else &"idle"
	if _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)


func _process_follow(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dist := global_position.distance_to(follow_target.global_position)

	# Check for nearby enemies to attack
	if _attack_cooldown_timer <= 0.0:
		var enemy := _find_nearest_enemy()
		if enemy and global_position.distance_to(enemy.global_position) < 8.0:
			_target_enemy = enemy
			ai_state = AIState.ATTACK
			return

	# Follow the active player
	if dist > follow_distance:
		var dir: Vector3 = (follow_target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			basis = basis.slerp(Basis.looking_at(dir), clampf(8.0 * delta, 0.0, 1.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	# Teleport if too far (prevent getting stuck)
	if dist > 20.0:
		global_position = follow_target.global_position + Vector3(2, 0, 2)


func _process_attack(delta: float) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		ai_state = AIState.FOLLOW
		return

	# Check if enemy is dead
	if _target_enemy.has_method("die") and _target_enemy.get("_is_dead"):
		_target_enemy = null
		ai_state = AIState.FOLLOW
		return

	var dist := global_position.distance_to(_target_enemy.global_position)

	if dist > 10.0:
		# Too far, give up
		_target_enemy = null
		ai_state = AIState.FOLLOW
		return

	if dist > attack_range:
		# Move toward enemy
		var dir: Vector3 = (_target_enemy.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			basis = basis.slerp(Basis.looking_at(dir), clampf(8.0 * delta, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		# Strike
		if _attack_cooldown_timer <= 0.0:
			_do_attack()


func _do_attack() -> void:
	if _target_enemy and is_instance_valid(_target_enemy) and _target_enemy.has_method("take_damage"):
		_target_enemy.take_damage(attack_damage, self)
		Events.attack_hit.emit(_target_enemy, attack_damage)
	_attack_cooldown_timer = attack_cooldown
	ai_state = AIState.FOLLOW


func take_damage(amount: float, _source: Node3D = null) -> void:
	if _is_downed:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	if current_hp <= 0.0:
		_enter_downed()


func _enter_downed() -> void:
	_is_downed = true
	ai_state = AIState.DOWNED
	current_hp = 0.0
	velocity = Vector3.ZERO
	Events.party_member_downed.emit(member_data.member_id if member_data else &"companion")
	# Visual feedback — shrink slightly
	if visual_root:
		visual_root.scale = Vector3(0.7, 0.4, 0.7)


func revive(hp_amount: float = -1.0) -> void:
	if not _is_downed:
		return
	_is_downed = false
	if hp_amount < 0:
		current_hp = max_hp * 0.3  # Revive at 30% HP
	else:
		current_hp = minf(hp_amount, max_hp)
	ai_state = AIState.FOLLOW
	Events.party_member_revived.emit(member_data.member_id if member_data else &"companion")
	if visual_root:
		visual_root.scale = Vector3.ONE


func heal(amount: float) -> void:
	if _is_downed:
		return
	current_hp = minf(current_hp + amount, max_hp)


func is_downed() -> bool:
	return _is_downed


func _find_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var best: Node3D = null
	var best_dist := 999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("_is_dead"):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Model"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	_mesh.mesh = capsule
	_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.4, 0.5)
	_mesh.material_override = mat
	visual_root.add_child(_mesh)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)


func get_save_data() -> Dictionary:
	return {
		"member_id": String(member_data.member_id) if member_data else "companion",
		"hp": current_hp,
		"mp": current_mp,
		"atb": current_atb,
		"is_downed": _is_downed,
	}


func load_save_data(data: Dictionary) -> void:
	current_hp = data.get("hp", max_hp)
	current_mp = data.get("mp", max_mp)
	current_atb = data.get("atb", 0.0)
	if data.get("is_downed", false):
		_enter_downed()


# --- v5 identity swap (PartySystem) ---

## Snapshot of the embodied member's live state (see PartySystem._swap_identities).
func export_member_state() -> Dictionary:
	return {
		"hp": current_hp, "max_hp": max_hp,
		"mp": current_mp, "max_mp": max_mp,
		"atb": current_atb, "max_atb": max_atb,
		"atb_fill_rate": atb_fill_rate, "mp_regen_rate": mp_regen_rate,
		"abilities": abilities.duplicate(),
		"downed": _is_downed,
	}


## Become `data` with `state` (from the Player body's export_member_state()).
## The body keeps following follow_target (the Player node).
func import_member_state(data: Resource, state: Dictionary) -> void:
	member_data = data
	if data:
		attack_damage = data.attack_damage
		move_speed = data.move_speed
	max_hp = state.get("max_hp", max_hp)
	max_mp = state.get("max_mp", max_mp)
	max_atb = state.get("max_atb", max_atb)
	atb_fill_rate = state.get("atb_fill_rate", atb_fill_rate)
	mp_regen_rate = state.get("mp_regen_rate", mp_regen_rate)
	current_hp = clampf(state.get("hp", max_hp), 0.0, max_hp)
	current_mp = clampf(state.get("mp", max_mp), 0.0, max_mp)
	current_atb = clampf(state.get("atb", 0.0), 0.0, max_atb)
	abilities = (state.get("abilities", []) as Array).duplicate()
	_is_downed = false
	_target_enemy = null
	_attack_cooldown_timer = 0.5  # short grace so the fresh AI doesn't strike on frame 1
	ai_state = AIState.FOLLOW
	velocity = Vector3.ZERO
	if visual_root:
		visual_root.scale = Vector3.ONE
	if state.get("downed", false) or current_hp <= 0.0:
		_enter_downed()


## Called by PartySystem after the visual_root's child was exchanged.
func refresh_visual() -> void:
	_mesh = null
	_anim = null
	if visual_root == null or visual_root.get_child_count() == 0:
		return
	var model := visual_root.get_child(0)
	if model is MeshInstance3D and (model as MeshInstance3D).mesh is CapsuleMesh:
		_mesh = model
	_anim = _find_anim(model)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null
