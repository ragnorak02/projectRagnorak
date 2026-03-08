extends State

@export var air_control: float = 5.0
@export var air_move_speed: float = 8.0


func process_physics(delta: float) -> StringName:
	if player.is_on_floor():
		return &"Land"

	# Check for ledge grab while falling
	if player.velocity.y < 0.0 and player.can_grab_ledge():
		return &"LedgeGrab"

	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		var camera_basis := player.get_viewport().get_camera_3d().global_basis
		var forward := (-camera_basis.z).normalized()
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera_basis.x
		right.y = 0.0
		right = right.normalized()
		var direction := (forward * -input.y + right * input.x).normalized()
		player.velocity.x = move_toward(player.velocity.x, direction.x * air_move_speed, air_control * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * air_move_speed, air_control * delta)

		# Face movement direction in air
		if direction.length() > 0.1:
			player.basis = player.basis.slerp(Basis.looking_at(direction), clampf(8.0 * delta, 0.0, 1.0))

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"jump"):
		if player.has_double_jump and not player._double_jump_used:
			player._double_jump_used = true
			player.velocity.y = 10.0
			return &"Jump"
		else:
			player.buffer_jump()
	if event.is_action_pressed(&"attack"):
		return &"JumpAttack"
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"
	return &""
