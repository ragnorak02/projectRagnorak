extends State


func enter(_msg: Dictionary = {}) -> void:
	pass


func process_physics(_delta: float) -> StringName:
	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		return &"LockOnStrafe"
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"lock_on"):
		Events.lock_on_target_lost.emit()
		return &"Idle"
	if event.is_action_pressed(&"attack"):
		return &"Attack1"
	if event.is_action_pressed(&"dodge"):
		return &"Dodge"
	if event.is_action_pressed(&"jump"):
		return &"Jump"
	if event.is_action_pressed(&"tactical_mode"):
		return &"TacticalIdle"
	return &""
