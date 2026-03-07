extends State

@export var strafe_speed: float = 6.0


func process_physics(delta: float) -> StringName:
	# Lost target — return to free movement
	if player.lock_on_target == null:
		return &"Run"

	if not player.is_on_floor():
		return &"Fall"

	player.face_lock_target(delta)

	var input := InputManager.get_movement_vector()
	if input.length() < 0.1:
		return &"LockOnIdle"

	var camera_basis := player.get_viewport().get_camera_3d().global_basis
	var forward := (-camera_basis.z).normalized()
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := (forward * -input.y + right * input.x).normalized()
	player.velocity.x = direction.x * strafe_speed
	player.velocity.z = direction.z * strafe_speed

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"lock_on"):
		player.lock_on_component.release_target()
		return &"Run"
	if event.is_action_pressed(&"target_switch_left"):
		player.lock_on_component.switch_target(-1.0)
	elif event.is_action_pressed(&"target_switch_right"):
		player.lock_on_component.switch_target(1.0)
	if event.is_action_pressed(&"attack"):
		return &"Attack1"
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"
	if event.is_action_pressed(&"jump"):
		return &"Jump"
	if event.is_action_pressed(&"tactical_mode"):
		return &"TacticalIdle"
	return &""
