## Climb up from a ledge grab. Lerps player to the top of the ledge.
extends State

@export var climb_duration: float = 0.35

var _timer: float = 0.0
var _start_pos: Vector3
var _target_pos: Vector3


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_start_pos = player.global_position
	_target_pos = player.get_ledge_climb_position()
	player.velocity = Vector3.ZERO


func process_physics(delta: float) -> StringName:
	_timer += delta
	var t := clampf(_timer / climb_duration, 0.0, 1.0)
	# Ease out for smooth finish
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	player.global_position = _start_pos.lerp(_target_pos, eased)

	if t >= 1.0:
		return &"Idle"

	return &""
