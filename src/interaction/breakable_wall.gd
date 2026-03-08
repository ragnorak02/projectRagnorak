## Breakable wall — requires a specific ability or progression flag to destroy.
## Once broken, sets a progression flag and hides/disables collision.
extends StaticBody3D

@export var wall_id: String = ""
@export var required_flag: String = ""  # e.g. "has_wall_break" from a party member
@export var blocked_message: String = "This wall looks fragile..."

var _broken: bool = false


func _ready() -> void:
	if wall_id != "" and SaveManager.has_flag("broken_" + wall_id):
		_break_wall()


func try_break(player: Node) -> bool:
	if _broken:
		return false

	if required_flag != "" and not SaveManager.has_flag(required_flag):
		Events.save_feedback.emit(blocked_message)
		return false

	_break_wall()
	Events.save_feedback.emit("Wall destroyed!")
	return true


func _break_wall() -> void:
	_broken = true
	if wall_id != "":
		SaveManager.set_flag("broken_" + wall_id, true)
	# Disable collision and hide visual
	collision_layer = 0
	collision_mask = 0
	visible = false
	set_physics_process(false)
