extends State

var _timer: float = 0.0

@export var attack_duration: float = 0.7
@export var forward_movement: float = 4.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	Events.combo_count_changed.emit(3)


func process_physics(delta: float) -> StringName:
	_timer += delta

	if _timer < 0.25:
		player.velocity.x = player.global_basis.z.x * -forward_movement
		player.velocity.z = player.global_basis.z.z * -forward_movement

	if _timer >= attack_duration:
		Events.combo_reset.emit()
		return &"Idle"

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"dodge"):
		return &"Dodge"
	return &""
