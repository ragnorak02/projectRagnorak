extends State

## State entered when tactical menu opens. Game slows to 10%.


func enter(_msg: Dictionary = {}) -> void:
	GameManager.enter_tactical_mode()
	Events.tactical_mode_entered.emit()


func exit() -> void:
	GameManager.exit_tactical_mode()
	Events.tactical_mode_exited.emit()


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"tactical_mode") or event.is_action_pressed(&"pause"):
		return &"Idle"
	return &""
