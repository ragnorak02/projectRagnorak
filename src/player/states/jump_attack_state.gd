extends State

var _timer: float = 0.0
@export var attack_duration: float = 0.5
@export var downward_force: float = 15.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	player.velocity.y = -downward_force


func process_physics(delta: float) -> StringName:
	_timer += delta
	if player.is_on_floor():
		return &"Land"
	if _timer >= attack_duration:
		return &"Fall"
	return &""
