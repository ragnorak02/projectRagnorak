## Manages equipped items across 10 slots with stat modifiers.
## Emits equipment_changed signals through Events bus.
extends Node

## Equipped items indexed by EquipmentData.EquipmentSlot
var _equipped: Dictionary = {}

## Base stats (before equipment modifiers)
var _base_stats: Dictionary = {
	"attack": 10.0,
	"defense": 5.0,
	"magic_attack": 8.0,
	"magic_defense": 4.0,
	"max_hp_bonus": 0.0,
	"max_mp_bonus": 0.0,
}

## Computed stats (base + equipment)
var _computed_stats: Dictionary = {}


func _ready() -> void:
	_recompute_stats()


func equip(equipment: EquipmentData) -> EquipmentData:
	if equipment == null:
		return null

	var slot: int = equipment.slot_type
	var old_item: EquipmentData = _equipped.get(slot, null)

	_equipped[slot] = equipment
	_recompute_stats()

	Events.equipment_changed.emit(slot, old_item, equipment)
	return old_item


func unequip(slot: int) -> EquipmentData:
	if not _equipped.has(slot):
		return null

	var old_item: EquipmentData = _equipped[slot]
	_equipped.erase(slot)
	_recompute_stats()

	Events.equipment_changed.emit(slot, old_item, null)
	return old_item


func get_equipped(slot: int) -> EquipmentData:
	return _equipped.get(slot, null)


func get_all_equipped() -> Dictionary:
	return _equipped.duplicate()


func is_slot_empty(slot: int) -> bool:
	return not _equipped.has(slot)


func get_stat(stat_name: String) -> float:
	return _computed_stats.get(stat_name, 0.0)


func get_base_stat(stat_name: String) -> float:
	return _base_stats.get(stat_name, 0.0)


func get_stat_bonus(stat_name: String) -> float:
	return get_stat(stat_name) - get_base_stat(stat_name)


func _recompute_stats() -> void:
	_computed_stats = _base_stats.duplicate()

	for slot in _equipped:
		var item: EquipmentData = _equipped[slot]
		if item == null:
			continue
		for stat_key in item.stat_modifiers:
			if _computed_stats.has(stat_key):
				_computed_stats[stat_key] += item.stat_modifiers[stat_key]
			else:
				_computed_stats[stat_key] = item.stat_modifiers[stat_key]


func get_slot_name(slot: int) -> String:
	match slot:
		EquipmentData.EquipmentSlot.HEAD: return "Head"
		EquipmentData.EquipmentSlot.CAPE: return "Cape"
		EquipmentData.EquipmentSlot.CHEST: return "Chest"
		EquipmentData.EquipmentSlot.PANTS: return "Pants"
		EquipmentData.EquipmentSlot.SHOES: return "Shoes"
		EquipmentData.EquipmentSlot.GLOVES: return "Gloves"
		EquipmentData.EquipmentSlot.LEFT_HAND: return "Left Hand"
		EquipmentData.EquipmentSlot.RIGHT_HAND: return "Right Hand"
		EquipmentData.EquipmentSlot.ACCESSORY_1: return "Accessory 1"
		EquipmentData.EquipmentSlot.ACCESSORY_2: return "Accessory 2"
	return "Unknown"


func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for slot in _equipped:
		var item: EquipmentData = _equipped[slot]
		if item:
			data[str(slot)] = String(item.item_id)
	return data


func load_save_data(data: Dictionary) -> void:
	_equipped.clear()
	for slot_str in data:
		var slot: int = int(slot_str)
		var item_id: String = data[slot_str]
		if item_id != "":
			var path := "res://resources/equipment/" + item_id + ".tres"
			if ResourceLoader.exists(path):
				var item := load(path) as EquipmentData
				if item:
					_equipped[slot] = item
	_recompute_stats()
