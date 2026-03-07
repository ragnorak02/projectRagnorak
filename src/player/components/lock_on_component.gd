## Handles target lock acquisition, switching, and release.
class_name LockOnComponent
extends Node

@export var detection_range: float = 20.0
@export var lose_range_multiplier: float = 1.5

var current_target: Node3D = null
var _player: CharacterBody3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D


func _physics_process(_delta: float) -> void:
	if current_target != null:
		if not is_instance_valid(current_target):
			release_target()
			return
		var dist := _player.global_position.distance_to(current_target.global_position)
		if dist > detection_range * lose_range_multiplier:
			release_target()


func acquire_target() -> Node3D:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var closest: Node3D = null
	var closest_dist: float = detection_range

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
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
		if enemy == current_target or not is_instance_valid(enemy):
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

	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	current_target = candidates[0]["node"]
	Events.lock_on_target_switched.emit(current_target)
