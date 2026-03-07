## Manages the player's item inventory with categories and stacking.
## Emits signals through Events bus for UI updates.
extends Node

## Each entry: { "item": ItemData, "quantity": int }
var _items: Array[Dictionary] = []

## Max slots before inventory is full
@export var max_slots: int = 40


func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if item_data == null or quantity <= 0:
		return false

	if item_data.stackable:
		# Try to stack with existing
		for entry in _items:
			if entry["item"].item_id == item_data.item_id:
				var space: int = entry["item"].max_stack - entry["quantity"]
				if space >= quantity:
					entry["quantity"] += quantity
					Events.item_acquired.emit(item_data, quantity)
					return true
				elif space > 0:
					entry["quantity"] = entry["item"].max_stack
					quantity -= space

	# Need new slot(s)
	while quantity > 0:
		if _items.size() >= max_slots:
			return false
		var stack_size: int = mini(quantity, item_data.max_stack if item_data.stackable else 1)
		_items.append({"item": item_data, "quantity": stack_size})
		quantity -= stack_size

	Events.item_acquired.emit(item_data, quantity)
	return true


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false

	var remaining := quantity
	for i in range(_items.size() - 1, -1, -1):
		if _items[i]["item"].item_id == item_id:
			if _items[i]["quantity"] <= remaining:
				remaining -= _items[i]["quantity"]
				_items.remove_at(i)
			else:
				_items[i]["quantity"] -= remaining
				remaining = 0
			if remaining <= 0:
				return true
	return remaining <= 0


func has_item(item_id: StringName, quantity: int = 1) -> bool:
	var total := 0
	for entry in _items:
		if entry["item"].item_id == item_id:
			total += entry["quantity"]
			if total >= quantity:
				return true
	return false


func get_item_count(item_id: StringName) -> int:
	var total := 0
	for entry in _items:
		if entry["item"].item_id == item_id:
			total += entry["quantity"]
	return total


func get_items_by_category(category: ItemData.ItemCategory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _items:
		if entry["item"].category == category:
			result.append(entry)
	return result


func get_all_items() -> Array[Dictionary]:
	return _items.duplicate()


func get_consumables() -> Array[Dictionary]:
	return get_items_by_category(ItemData.ItemCategory.CONSUMABLE)


func get_equipment() -> Array[Dictionary]:
	return get_items_by_category(ItemData.ItemCategory.EQUIPMENT)


func get_key_items() -> Array[Dictionary]:
	return get_items_by_category(ItemData.ItemCategory.KEY_ITEM)


func get_slot_count() -> int:
	return _items.size()


func is_full() -> bool:
	return _items.size() >= max_slots


func use_item(item_data: ItemData, target: Node = null) -> bool:
	if item_data == null:
		return false
	if not has_item(item_data.item_id):
		return false
	if item_data.category != ItemData.ItemCategory.CONSUMABLE:
		return false

	# Apply item effect based on item_id
	var player: CharacterBody3D = _get_player(target)
	if player == null:
		return false

	_apply_consumable_effect(item_data, player)
	remove_item(item_data.item_id, 1)
	Events.item_used.emit(item_data)
	return true


func _apply_consumable_effect(item_data: ItemData, player: CharacterBody3D) -> void:
	# Check for known effect metadata
	if item_data.has_meta("heal_amount"):
		player.heal(item_data.get_meta("heal_amount"))
	if item_data.has_meta("mp_restore"):
		var amount: float = item_data.get_meta("mp_restore")
		player.current_mp = minf(player.current_mp + amount, player.max_mp)
		Events.player_mp_changed.emit(player.current_mp, player.max_mp)


func _get_player(target: Node = null) -> CharacterBody3D:
	if target is CharacterBody3D:
		return target as CharacterBody3D
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null


func get_save_data() -> Array:
	var data: Array = []
	for entry in _items:
		data.append({
			"item_id": String(entry["item"].item_id),
			"quantity": entry["quantity"],
		})
	return data


func load_save_data(data: Array) -> void:
	_items.clear()
	for entry_data in data:
		# Items would be loaded from a registry; placeholder path
		var item_id: String = entry_data.get("item_id", "")
		var qty: int = entry_data.get("quantity", 1)
		if item_id != "":
			var item := _load_item_by_id(StringName(item_id))
			if item:
				_items.append({"item": item, "quantity": qty})


func _load_item_by_id(item_id: StringName) -> Resource:
	# Try loading from standard paths
	var dirs: Array[String] = ["res://resources/items/", "res://resources/equipment/"]
	for dir_path in dirs:
		var full_path: String = dir_path + String(item_id) + ".tres"
		if ResourceLoader.exists(full_path):
			return load(full_path)
	return null
