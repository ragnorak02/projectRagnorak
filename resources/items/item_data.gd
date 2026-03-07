## Base item data resource.
class_name ItemData
extends Resource

enum ItemCategory { CONSUMABLE, EQUIPMENT, KEY_ITEM }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: ItemCategory = ItemCategory.CONSUMABLE
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D = null
@export var gold_value: int = 0
@export var stackable: bool = true
@export var max_stack: int = 99
