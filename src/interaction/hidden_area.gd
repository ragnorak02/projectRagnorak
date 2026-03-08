## Hidden area trigger — marks discovery via progression flag.
## Place an Area3D in the world; when the player enters, the area is "discovered."
extends Area3D

@export var area_id: String = ""
@export var discovery_message: String = "Discovered a hidden area!"

var _discovered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Layer 2: PlayerBody
	body_entered.connect(_on_body_entered)

	# Check if already discovered
	if area_id != "" and SaveManager.has_flag("discovered_" + area_id):
		_discovered = true


func _on_body_entered(body: Node3D) -> void:
	if _discovered:
		return
	if not body.is_in_group(&"player"):
		return
	_discovered = true
	if area_id != "":
		SaveManager.set_flag("discovered_" + area_id, true)
	Events.save_feedback.emit(discovery_message)
