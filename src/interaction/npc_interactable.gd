## NPC interactable — triggers dialogue when interacted.
extends "res://src/interaction/interactable.gd"

@export var npc_name: String = "NPC"
@export var dialogue_pages: Array[Dictionary] = []
## Each page: {"speaker": "Name", "text": "Line of dialogue"}
## If empty, uses a default greeting.


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.NPC
	interact_priority = 10  # NPCs have high interact_priority
	if interaction_name == "Interact":
		interaction_name = "Talk to %s" % npc_name


func get_prompt_text() -> String:
	return "Talk to %s" % npc_name


func interact(player: Node) -> void:
	if not _is_active:
		return
	var pages: Array[Dictionary] = dialogue_pages.duplicate()
	if pages.is_empty():
		pages.append({"speaker": npc_name, "text": "..."})
	Events.interaction_available.emit(self)
	# Dialogue UI listens for this via a direct call
	var dialogue_ui := _find_dialogue_ui()
	if dialogue_ui and dialogue_ui.has_method("start_dialogue"):
		dialogue_ui.start_dialogue(pages)


func _find_dialogue_ui() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group(&"dialogue_ui")
	if nodes.size() > 0:
		return nodes[0]
	return null
