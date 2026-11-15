## Chest interactable — gives items when opened.
extends "res://src/interaction/interactable.gd"

@export var contents: Array[Dictionary] = []
## Each entry: {"item_path": "res://resources/items/potion.tres", "quantity": 1}
@export var is_opened: bool = false


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.CHEST
	interact_priority = 5
	prompt_height = 0.95
	if interaction_name == "Interact":
		interaction_name = "Open Chest"
	_add_solid_body()


## Solid, standable body fitted to the chest's visual mesh. The interaction
## Area3D (this node) is kept as-is; the body sits on the World layer.
func _add_solid_body() -> void:
	if has_node("SolidBody"):
		return
	var aabb: AABB = TownBuilder.merged_mesh_aabb(self)
	if aabb.size.length_squared() < 0.0001:
		aabb = AABB(Vector3(-0.4, 0.0, -0.3), Vector3(0.8, 0.6, 0.6))
	var body := StaticBody3D.new()
	body.name = "SolidBody"
	body.collision_layer = 1  # World
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	col.shape = shape
	col.position = aabb.get_center()
	body.add_child(col)
	add_child(body)
	# Hidden chests (e.g. the dungeon reward before the puzzle) must not be invisible walls.
	visibility_changed.connect(_sync_solid_body)
	_sync_solid_body.call_deferred()


func _sync_solid_body() -> void:
	var body := get_node_or_null("SolidBody") as StaticBody3D
	if body:
		body.collision_layer = 1 if is_visible_in_tree() else 0


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
