## AI behavior for non-controlled party members.
## Follows the active player, attacks nearby enemies, and provides support.
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

var follow_target: Node3D = null
var _is_downed: bool = false
var _attack_cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _target_enemy: Node3D = null

enum AIState { FOLLOW, ATTACK, SUPPORT, DOWNED }
var ai_state: AIState = AIState.FOLLOW

# Visual
var _mesh: MeshInstance3D


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
		if _mesh and data.get("capsule_color"):
			_mesh.material_override.albedo_color = data.capsule_color


func _physics_process(delta: float) -> void:
	if _is_downed:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# ATB fills passively
	if current_atb < max_atb:
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)

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
	if _mesh:
		_mesh.scale = Vector3(0.7, 0.4, 0.7)


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
	if _mesh:
		_mesh.scale = Vector3.ONE


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
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	_mesh.mesh = capsule
	_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.4, 0.5)
	_mesh.material_override = mat
	add_child(_mesh)

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
