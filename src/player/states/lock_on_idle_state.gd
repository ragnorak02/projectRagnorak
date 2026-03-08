extends State


func enter(_msg: Dictionary = {}) -> void:
	player.play_animation(&"idle")
	if player.lock_on_target == null:
		var target: Node3D = player.lock_on_component.acquire_target()
		if target == null:
			return


func process_physics(delta: float) -> StringName:
	# Lost target — return to free movement
	if player.lock_on_target == null:
		return &"Idle"

	player.face_lock_target(delta)

	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		return &"LockOnStrafe"

	if not player.is_on_floor():
		return &"Fall"

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"lock_on"):
		player.lock_on_component.release_target()
		return &"Idle"
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
