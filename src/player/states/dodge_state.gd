extends State

@export var dodge_speed: float = 15.0
@export var dodge_duration: float = 0.4
@export var dodge_cooldown: float = 0.8

var _timer: float = 0.0
var _direction: Vector3 = Vector3.BACK

## No invulnerability frames per design contract.


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		var camera_basis := player.get_viewport().get_camera_3d().global_basis
		var forward := (-camera_basis.z).normalized()
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera_basis.x
		right.y = 0.0
		right = right.normalized()
		_direction = (forward * -input.y + right * input.x).normalized()
	else:
		_direction = -player.global_basis.z.normalized()


func process_physics(delta: float) -> StringName:
	_timer += delta
	if _timer >= dodge_duration:
		return &"Idle"

	var progress := _timer / dodge_duration
	var decay := 1.0 - progress * progress
	player.velocity.x = _direction.x * dodge_speed * decay
	player.velocity.z = _direction.z * dodge_speed * decay

	return &""
