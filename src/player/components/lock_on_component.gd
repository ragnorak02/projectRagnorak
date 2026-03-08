## Handles target lock acquisition, switching, and release.
class_name LockOnComponent
extends Node

@export var detection_range: float = 20.0
@export var lose_range_multiplier: float = 1.5
@export var obstruction_timeout: float = 1.5

var current_target: Node3D = null
var _player: CharacterBody3D
var _obstruction_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	Events.enemy_died.connect(_on_enemy_died)


func _physics_process(delta: float) -> void:
	if current_target != null:
		if not is_instance_valid(current_target):
			release_target()
			return
		var dist := _player.global_position.distance_to(current_target.global_position)
		if dist > detection_range * lose_range_multiplier:
			release_target()
			return

		# Line-of-sight check
		if _is_obstructed():
			_obstruction_timer += delta
			if _obstruction_timer >= obstruction_timeout:
				release_target()
		else:
			_obstruction_timer = 0.0


func _is_obstructed() -> bool:
	if current_target == null:
		return false
	var space := _player.get_world_3d().direct_space_state
	var from: Vector3 = _player.global_position + Vector3(0, 1.2, 0)
	var to: Vector3 = current_target.global_position + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var result := space.intersect_ray(query)
	return not result.is_empty()


func acquire_target() -> Node3D:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var closest: Node3D = null
	var closest_dist: float = detection_range

	for enemy in enemies:
		if not _is_valid_target(enemy):
			continue
		var dist := _player.global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	if closest:
		current_target = closest
		Events.lock_on_target_acquired.emit(closest)
	return closest


func release_target() -> void:
	current_target = null
	Events.lock_on_target_lost.emit()


func _on_enemy_died(enemy: Node3D) -> void:
	if current_target == enemy:
		release_target()


func switch_target(direction: float) -> void:
	if current_target == null:
		return

	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var camera := _player.get_viewport().get_camera_3d()
	if camera == null:
		return

	var cam_right := camera.global_basis.x.normalized()
	var candidates: Array[Dictionary] = []

	for enemy in enemies:
		if enemy == current_target or not _is_valid_target(enemy):
			continue
		var dist := _player.global_position.distance_to(enemy.global_position)
		if dist > detection_range:
			continue
		var dir_to: Vector3 = (enemy.global_position - _player.global_position).normalized()
		var dot: float = dir_to.dot(cam_right) * sign(direction)
		if dot > 0:
			candidates.append({"node": enemy, "dot": dot, "dist": dist})

	if candidates.is_empty():
		return

	# Prefer nearest valid target in the requested direction
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	current_target = candidates[0]["node"]
	Events.lock_on_target_switched.emit(current_target)


func _is_valid_target(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not enemy is Node3D:
		return false
	# Skip dead enemies
	if enemy.has_method("is_dead") and enemy.is_dead():
		return false
	if "ai_state" in enemy and enemy.ai_state == enemy.AIState.DEAD:
		return false
	if "_is_dead" in enemy and enemy._is_dead:
		return false
	return true
