## Base class for all interactable objects in the world.
## Attach to an Area3D on physics layer 9 (Interaction).
## Override interact() in subclasses for specific behavior.
extends Area3D

enum InteractableType { GENERIC, NPC, CHEST, LEVER }

@export var interaction_name: String = "Interact"
@export var interactable_type: InteractableType = InteractableType.GENERIC
@export var interact_priority: int = 0  # Higher = preferred when overlapping

var _is_active: bool = true


func _ready() -> void:
	collision_layer = 256  # Layer 9: Interaction
	collision_mask = 0
	add_to_group(&"interactable")


func get_prompt_text() -> String:
	return interaction_name


func interact(_player: Node) -> void:
	pass  # Override in subclasses


func is_active() -> bool:
	return _is_active


func set_active(active: bool) -> void:
	_is_active = active
	monitoring = active
	monitorable = active
