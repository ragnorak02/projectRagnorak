## Zone portal — teleports player to another zone on interaction.
## Use progression flags for gating (e.g. require a key or ability).
extends "res://src/interaction/interactable.gd"

@export var target_zone_id: String = ""
@export var spawn_position: Vector3 = Vector3.ZERO
@export var required_flag: String = ""  # Progression flag required to use
@export var locked_message: String = "The path is blocked."

signal portal_activated(target_zone: String)


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.GENERIC
	interact_priority = 8
	if interaction_name == "Interact":
		interaction_name = "Enter"


func get_prompt_text() -> String:
	if required_flag != "" and not SaveManager.has_flag(required_flag):
		return locked_message
	return interaction_name


func interact(player: Node) -> void:
	if not _is_active:
		return

	# Check gating
	if required_flag != "" and not SaveManager.has_flag(required_flag):
		Events.save_feedback.emit(locked_message)
		return

	portal_activated.emit(target_zone_id)

	# Save current state before transitioning
	var data := SaveManager.gather_save_data()
	# Override zone_id and position to the target
	data["zone_id"] = target_zone_id
	if data.has("player"):
		data["player"]["position"] = {
			"x": spawn_position.x,
			"y": spawn_position.y,
			"z": spawn_position.z
		}
	SaveManager.autosave(data)

	# Set pending load and transition
	Events.zone_exiting.emit(StringName(SaveManager._get_current_zone_id()))
	SaveManager._pending_load_data = data
	var scene_path := SaveManager._zone_id_to_scene(target_zone_id)
	get_tree().change_scene_to_file(scene_path)
