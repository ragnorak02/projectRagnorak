extends State

var _timer: float = 0.0
var _buffered_next: StringName = &""

@export var attack_duration: float = 0.6
@export var combo_window_start: float = 0.3
@export var combo_window_end: float = 0.55
@export var forward_movement: float = 2.5


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_buffered_next = &""
	Events.combo_count_changed.emit(2)


func process_physics(delta: float) -> StringName:
	_timer += delta

	if _timer < 0.2:
		player.velocity.x = player.global_basis.z.x * -forward_movement
		player.velocity.z = player.global_basis.z.z * -forward_movement

	if _timer >= attack_duration:
		if _buffered_next != &"":
			return _buffered_next
		Events.combo_reset.emit()
		return &"Idle"

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		if _timer >= combo_window_start and _timer <= combo_window_end:
			return &"Attack3"
		else:
			_buffered_next = &"Attack3"

	if event.is_action_pressed(&"dodge"):
		return &"Dodge"

	return &""
