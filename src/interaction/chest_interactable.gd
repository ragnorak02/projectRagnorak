## Chest interactable — gives items when opened.
extends "res://src/interaction/interactable.gd"

@export var contents: Array[Dictionary] = []
## Each entry: {"item_path": "res://resources/items/potion.tres", "quantity": 1}
@export var is_opened: bool = false


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.CHEST
	interact_priority = 5
	if interaction_name == "Interact":
		interaction_name = "Open Chest"


func get_prompt_text() -> String:
	if is_opened:
		return "Empty Chest"
	return "Open Chest"


func interact(player: Node) -> void:
	if not _is_active or is_opened:
		return
	is_opened = true
	set_active(false)

	# Give items to player inventory
	if player.has_node("InventorySystem"):
		var inv: Node = player.get_node("InventorySystem")
		for entry: Dictionary in contents:
			var item_res: Resource = load(entry.get("item_path", ""))
			if item_res:
				var qty: int = entry.get("quantity", 1)
				inv.add_item(item_res, qty)
				Events.item_acquired.emit(item_res, qty)

	Events.interaction_cleared.emit()
