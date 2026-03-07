extends State

var _timer: float = 0.0
@export var flinch_duration: float = 0.4


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0


func process_physics(delta: float) -> StringName:
	_timer += delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)

	if _timer >= flinch_duration:
		return &"Idle"
	return &""
