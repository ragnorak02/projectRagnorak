## Lever/switch interactable — toggles on/off state.
extends "res://src/interaction/interactable.gd"

signal lever_toggled(is_on: bool)

@export var is_on: bool = false
@export var one_shot: bool = false  # If true, cannot toggle back


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.LEVER
	interact_priority = 3
	if interaction_name == "Interact":
		interaction_name = "Pull Lever"


func get_prompt_text() -> String:
	if one_shot and is_on:
		return "Lever (Activated)"
	return "Pull Lever"


func interact(_player: Node) -> void:
	if not _is_active:
		return
	if one_shot and is_on:
		return

	is_on = not is_on
	lever_toggled.emit(is_on)

	if one_shot and is_on:
		set_active(false)
