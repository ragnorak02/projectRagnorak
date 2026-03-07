extends State

var _timer: float = 0.0
var _cast_time: float = 1.0

## Spells cannot cancel into dodge per design contract.


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	if msg.has("cast_time"):
		_cast_time = msg["cast_time"]
	player.velocity = Vector3.ZERO
	Events.ability_cast_started.emit(msg.get("ability_data"))


func exit() -> void:
	pass


func process_physics(delta: float) -> StringName:
	_timer += delta
	player.velocity = Vector3.ZERO

	if _timer >= _cast_time:
		Events.ability_cast_completed.emit(null)
		return &"Idle"
	return &""


func process_input(_event: InputEvent) -> StringName:
	## No dodge cancel allowed during spell cast.
	return &""
