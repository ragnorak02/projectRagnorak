extends State

var _timer: float = 0.0
@export var land_duration: float = 0.1


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0


func process_physics(delta: float) -> StringName:
	# Buffered jump fires immediately on landing
	if player.has_buffered_jump():
		player.consume_jump_buffer()
		return &"Jump"

	_timer += delta
	if _timer >= land_duration:
		var input := InputManager.get_movement_vector()
		if input.length() > 0.1:
			return &"Run"
		return &"Idle"
	return &""
