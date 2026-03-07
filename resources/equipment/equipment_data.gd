## Equipment item resource with slot and stat modifiers.
class_name EquipmentData
extends "res://resources/items/item_data.gd"

enum EquipmentSlot { HEAD, CAPE, CHEST, PANTS, SHOES, GLOVES, LEFT_HAND, RIGHT_HAND, ACCESSORY_1, ACCESSORY_2 }

@export var slot_type: EquipmentSlot = EquipmentSlot.CHEST
@export var stat_modifiers: Dictionary = {} ## e.g. {"attack": 5.0, "defense": 3.0}
@export var mesh_override: PackedScene = null
@export var required_level: int = 1


func _init() -> void:
	category = ItemCategory.EQUIPMENT
	stackable = false
	max_stack = 1
