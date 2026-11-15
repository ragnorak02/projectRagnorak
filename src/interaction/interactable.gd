## Base class for all interactable objects in the world.
## Attach to an Area3D on physics layer 9 (Interaction).
## Override interact() in subclasses for specific behavior.
extends Area3D

enum InteractableType { GENERIC, NPC, CHEST, LEVER }

@export var interaction_name: String = "Interact"
@export var interactable_type: InteractableType = InteractableType.GENERIC
@export var interact_priority: int = 0  # Higher = preferred when overlapping
## v7: true = `interact` must be held for hold_duration seconds (the world
## prompt shows "Hold" and fills a ring). False = a normal press.
@export var hold_to_interact: bool = false
@export var hold_duration: float = 0.6
## v7: height (m) above this node where the floating button prompt sits.
@export var prompt_height: float = 1.2

var _is_active: bool = true


func _ready() -> void:
	collision_layer = 256  # Layer 9: Interaction
	collision_mask = 0
	add_to_group(&"interactable")


func get_prompt_text() -> String:
	return interaction_name


func interact(_player: Node) -> void:
	pass  # Override in subclasses


## v7: true when this interaction needs a hold rather than a press.
func requires_hold() -> bool:
	return hold_to_interact


## v7: world point where the floating button prompt is drawn.
func get_prompt_anchor() -> Vector3:
	return global_position + Vector3(0.0, prompt_height, 0.0)


func is_active() -> bool:
	return _is_active


func set_active(active: bool) -> void:
	_is_active = active
	monitoring = active
	monitorable = active
