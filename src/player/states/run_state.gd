extends State

@export var move_speed: float = 8.0
@export var acceleration: float = 20.0


func process_physics(delta: float) -> StringName:
	var input := InputManager.get_movement_vector()

	if not player.is_on_floor():
		return &"Fall"

	if input.length() < 0.1:
		return &"Idle"

	var camera_basis := player.get_viewport().get_camera_3d().global_basis
	var forward := -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := (forward * -input.y + right * input.x).normalized()
	var target_velocity := direction * move_speed * input.length()

	player.velocity.x = move_toward(player.velocity.x, target_velocity.x, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, target_velocity.z, acceleration * delta)

	if direction.length() > 0.1:
		player.basis = player.basis.slerp(Basis.looking_at(direction), clampf(10.0 * delta, 0.0, 1.0))

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"jump") and player.is_on_floor():
		return &"Jump"
	if event.is_action_pressed(&"attack"):
		return &"Attack1"
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"
	if event.is_action_pressed(&"lock_on"):
		return &"LockOnIdle"
	if event.is_action_pressed(&"tactical_mode"):
		return &"TacticalIdle"

	return &""
