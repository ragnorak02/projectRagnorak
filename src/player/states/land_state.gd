extends State

var _timer: float = 0.0
@export var land_duration: float = 0.1

## v3 T2: a command press during the landing recovery is buffered and opened
## when the recovery ends (Land -> TacticalIdle stays an illegal transition, so
## the menu opens from the state Land hands over to).
var _command_buffered: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_command_buffered = false


func process_physics(delta: float) -> StringName:
	# Buffered jump fires immediately on landing
	if player.has_buffered_jump():
		player.consume_jump_buffer()
		return &"Jump"

	_timer += delta
	if _timer >= land_duration:
		var next: StringName = &"LockOnIdle" if player.is_locked_on else &"Idle"
		if _command_buffered:
			_command_buffered = false
			if player.request_transition(next):
				player.request_transition(&"TacticalIdle")
			return &""
		var input := InputManager.get_movement_vector()
		if input.length() > 0.1:
			return &"LockOnStrafe" if player.is_locked_on else &"Run"
		return next
	return &""


func process_input(event: InputEvent) -> StringName:
	# Releases go to BOTH components (a hold may have started before landing).
	if event.is_action_released(&"attack"):
		var consumed: bool = player.stance != null and player.stance.handle_attack_release()
		var next: StringName = player.combo.on_attack_released() if player.combo else &""
		return &"" if consumed else next
	if player.is_command_press(event):
		_command_buffered = true
		return &""
	if player.is_unique_press(event):
		if player.stance:
			player.stance.toggle()
		get_viewport().set_input_as_handled()
		return &""
	return &""
