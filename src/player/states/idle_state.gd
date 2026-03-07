extends State

@export var deceleration: float = 30.0


func enter(_msg: Dictionary = {}) -> void:
	pass


func process_physics(delta: float) -> StringName:
	var input := InputManager.get_movement_vector()

	if not player.is_on_floor():
		return &"Fall"

	if input.length() > 0.1:
		return &"Run"

	# Decelerate to stop
	player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, deceleration * delta)

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"jump") and player.is_on_floor():
		return &"Jump"
	if event.is_action_pressed(&"attack"):
		return &"Attack1"
	if event.is_action_pressed(&"dodge"):
		return &"Dodge"
	if event.is_action_pressed(&"lock_on"):
		return &"LockOnIdle"
	if event.is_action_pressed(&"tactical_mode"):
		return &"TacticalIdle"

	return &""
