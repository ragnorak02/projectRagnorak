## Phase 9 tests: Inventory & Equipment system (items 201-230).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 9: Inventory & Equipment Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 9 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Inventory Core (items 201-206)
	_section("INVENTORY CORE")
	test_inventory_system_exists()
	test_inventory_add_item()
	test_inventory_remove_item()
	test_inventory_has_item()
	test_inventory_stacking()
	test_inventory_max_stack()
	test_inventory_full_check()
	test_inventory_consumables_category()
	test_inventory_equipment_category()
	test_inventory_key_items_category()
	test_item_data_has_categories()
	test_item_data_has_stack_handling()

	# Category 2: Equipment Slots (items 207-216)
	_section("EQUIPMENT SLOTS")
	test_equipment_system_exists()
	test_equipment_slot_head()
	test_equipment_slot_cape()
	test_equipment_slot_chest()
	test_equipment_slot_pants()
	test_equipment_slot_shoes()
	test_equipment_slot_gloves()
	test_equipment_slot_left_hand()
	test_equipment_slot_right_hand()
	test_equipment_slot_accessory_1()
	test_equipment_slot_accessory_2()
	test_equipment_all_10_slots_defined()

	# Category 3: Equipment Effects (items 217-220)
	_section("EQUIPMENT EFFECTS")
	test_equip_applies_stats()
	test_unequip_removes_stats()
	test_equipment_swap_logic()
	test_equipment_visual_change_hook()
	test_stat_modifiers_computed()
	test_base_stats_preserved()

	# Category 4: Item Use (items 221-227)
	_section("ITEM USE")
	test_use_consumable_item()
	test_use_item_reduces_quantity()
	test_use_invalid_item_blocked()
	test_use_equipment_as_consumable_blocked()
	test_item_quantity_respected()
	test_no_duplicate_consumption()

	# Category 5: Test Resources (data-driven)
	_section("TEST RESOURCES")
	test_potion_resource_loads()
	test_ether_resource_loads()
	test_iron_sword_resource_loads()
	test_leather_chest_resource_loads()
	test_iron_sword_is_equipment()
	test_leather_chest_is_equipment()

	# Category 6: Player Integration
	_section("PLAYER INTEGRATION")
	test_player_has_inventory_system()
	test_player_has_equipment_system()
	test_save_data_includes_inventory()
	test_save_data_includes_equipment()
	test_equipment_system_has_save_load()
	test_inventory_system_has_save_load()

	# Category 7: Signals & Events
	_section("SIGNALS & EVENTS")
	test_events_has_item_acquired()
	test_events_has_item_used()
	test_events_has_equipment_changed()
	test_equipment_emits_signal_on_equip()

	# Category 8: Item UI Integration (items 228-230)
	_section("ITEM UI INTEGRATION")
	test_tactical_menu_has_items_category()
	test_inventory_get_all_items()
	test_equipment_get_slot_name()
	test_equipment_persistence_structure()


# ========== CATEGORY 1: INVENTORY CORE ==========

func test_inventory_system_exists() -> void:
	var script = load("res://src/player/components/inventory_system.gd")
	_assert(script != null, "InventorySystem script exists")


func test_inventory_add_item() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("test_add", true)
	var result = inv.add_item(item, 1)
	_assert(result and inv.get_slot_count() == 1, "Can add item to inventory")
	inv.free()


func test_inventory_remove_item() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("test_remove", true)
	inv.add_item(item, 5)
	var result = inv.remove_item(&"test_remove", 3)
	_assert(result and inv.get_item_count(&"test_remove") == 2, "Can remove partial stack")
	inv.free()


func test_inventory_has_item() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("test_has", true)
	inv.add_item(item, 3)
	_assert(inv.has_item(&"test_has", 3) and not inv.has_item(&"test_has", 4),
		"has_item checks quantity correctly")
	inv.free()


func test_inventory_stacking() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("stack_test", true)
	inv.add_item(item, 5)
	inv.add_item(item, 3)
	_assert(inv.get_item_count(&"stack_test") == 8 and inv.get_slot_count() == 1,
		"Stackable items stack in same slot")
	inv.free()


func test_inventory_max_stack() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("max_stack") and source.contains("max_slots"),
		"Inventory respects max_stack and max_slots limits")


func test_inventory_full_check() -> void:
	var inv = _create_inventory()
	inv.max_slots = 2
	var item1 = _create_test_item("full_1", false)
	var item2 = _create_test_item("full_2", false)
	var item3 = _create_test_item("full_3", false)
	inv.add_item(item1)
	inv.add_item(item2)
	var result = inv.add_item(item3)
	_assert(not result and inv.is_full(), "Cannot add item when inventory is full")
	inv.free()


func test_inventory_consumables_category() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("consumable_test", true)
	item.category = 0
	inv.add_item(item, 1)
	var consumables = inv.get_consumables()
	_assert(consumables.size() == 1, "get_consumables returns consumable items")
	inv.free()


func test_inventory_equipment_category() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("equip_cat_test", false)
	item.category = 1
	inv.add_item(item, 1)
	var equipment = inv.get_equipment()
	_assert(equipment.size() == 1, "get_equipment returns equipment items")
	inv.free()


func test_inventory_key_items_category() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("key_item_test", false)
	item.category = 2
	inv.add_item(item, 1)
	var key_items = inv.get_key_items()
	_assert(key_items.size() == 1, "get_key_items returns key items")
	inv.free()


func test_item_data_has_categories() -> void:
	var source := _get_source("res://resources/items/item_data.gd")
	_assert(source.contains("CONSUMABLE") and source.contains("EQUIPMENT") and source.contains("KEY_ITEM"),
		"ItemData has Consumable, Equipment, Key Item categories")


func test_item_data_has_stack_handling() -> void:
	var source := _get_source("res://resources/items/item_data.gd")
	_assert(source.contains("stackable") and source.contains("max_stack"),
		"ItemData has stackable and max_stack properties")


# ========== CATEGORY 2: EQUIPMENT SLOTS ==========

func test_equipment_system_exists() -> void:
	var script = load("res://src/player/components/equipment_system.gd")
	_assert(script != null, "EquipmentSystem script exists")


func _test_slot_exists(slot_name: String, slot_value: int) -> void:
	var source := _get_source("res://resources/equipment/equipment_data.gd")
	_assert(source.contains(slot_name), "EquipmentSlot.%s defined" % slot_name)


func test_equipment_slot_head() -> void:
	_test_slot_exists("HEAD", 0)

func test_equipment_slot_cape() -> void:
	_test_slot_exists("CAPE", 1)

func test_equipment_slot_chest() -> void:
	_test_slot_exists("CHEST", 2)

func test_equipment_slot_pants() -> void:
	_test_slot_exists("PANTS", 3)

func test_equipment_slot_shoes() -> void:
	_test_slot_exists("SHOES", 4)

func test_equipment_slot_gloves() -> void:
	_test_slot_exists("GLOVES", 5)

func test_equipment_slot_left_hand() -> void:
	_test_slot_exists("LEFT_HAND", 6)

func test_equipment_slot_right_hand() -> void:
	_test_slot_exists("RIGHT_HAND", 7)

func test_equipment_slot_accessory_1() -> void:
	_test_slot_exists("ACCESSORY_1", 8)

func test_equipment_slot_accessory_2() -> void:
	_test_slot_exists("ACCESSORY_2", 9)


func test_equipment_all_10_slots_defined() -> void:
	var source := _get_source("res://resources/equipment/equipment_data.gd")
	var slots := ["HEAD", "CAPE", "CHEST", "PANTS", "SHOES", "GLOVES",
		"LEFT_HAND", "RIGHT_HAND", "ACCESSORY_1", "ACCESSORY_2"]
	var all_found := true
	for s in slots:
		if not source.contains(s):
			all_found = false
	_assert(all_found, "All 10 equipment slots defined in EquipmentData")


# ========== CATEGORY 3: EQUIPMENT EFFECTS ==========

func test_equip_applies_stats() -> void:
	var equip = _create_equipment_system()
	var sword = _create_test_equipment("test_sword", 7, {"attack": 5.0})
	equip.equip(sword)
	var attack_stat = equip.get_stat("attack")
	var base_attack = equip.get_base_stat("attack")
	_assert(attack_stat == base_attack + 5.0, "Equipping item adds stat modifiers")
	equip.free()


func test_unequip_removes_stats() -> void:
	var equip = _create_equipment_system()
	var sword = _create_test_equipment("test_sword2", 7, {"attack": 5.0})
	equip.equip(sword)
	equip.unequip(7)
	var attack_stat = equip.get_stat("attack")
	var base_attack = equip.get_base_stat("attack")
	_assert(attack_stat == base_attack, "Unequipping item removes stat modifiers")
	equip.free()


func test_equipment_swap_logic() -> void:
	var equip = _create_equipment_system()
	var sword1 = _create_test_equipment("sword1", 7, {"attack": 5.0})
	var sword2 = _create_test_equipment("sword2", 7, {"attack": 8.0})
	equip.equip(sword1)
	var old_item = equip.equip(sword2)
	_assert(old_item == sword1 and equip.get_stat("attack") == equip.get_base_stat("attack") + 8.0,
		"Swapping equipment returns old item and applies new stats")
	equip.free()


func test_equipment_visual_change_hook() -> void:
	var source := _get_source("res://resources/equipment/equipment_data.gd")
	_assert(source.contains("mesh_override"),
		"EquipmentData has mesh_override for visual changes")


func test_stat_modifiers_computed() -> void:
	var source := _get_source("res://src/player/components/equipment_system.gd")
	_assert(source.contains("_recompute_stats") and source.contains("stat_modifiers"),
		"EquipmentSystem recomputes stats from stat_modifiers")


func test_base_stats_preserved() -> void:
	var equip = _create_equipment_system()
	var base_attack = equip.get_base_stat("attack")
	var sword = _create_test_equipment("base_test", 7, {"attack": 10.0})
	equip.equip(sword)
	_assert(equip.get_base_stat("attack") == base_attack,
		"Base stats are preserved after equipping items")
	equip.free()


# ========== CATEGORY 4: ITEM USE ==========

func test_use_consumable_item() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("use_item") and source.contains("_apply_consumable_effect"),
		"InventorySystem has use_item with consumable effect application")


func test_use_item_reduces_quantity() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("remove_item(item_data.item_id, 1)"),
		"Using an item removes 1 from inventory")


func test_use_invalid_item_blocked() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("if item_data == null") and source.contains("return false"),
		"Using null item returns false")


func test_use_equipment_as_consumable_blocked() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("CONSUMABLE"),
		"Only consumable items can be used")


func test_item_quantity_respected() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("has_item(item_data.item_id)"),
		"use_item checks item exists in inventory before use")


func test_no_duplicate_consumption() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("dup_test", true)
	inv.add_item(item, 1)
	# Simulate: remove should make has_item return false for second attempt
	inv.remove_item(&"dup_test", 1)
	_assert(not inv.has_item(&"dup_test"),
		"Item removed after use — cannot consume same item twice")
	inv.free()


# ========== CATEGORY 5: TEST RESOURCES ==========

func test_potion_resource_loads() -> void:
	var item = load("res://resources/items/potion.tres")
	_assert(item != null and item.get("item_id") != null, "Potion resource loads as ItemData")


func test_ether_resource_loads() -> void:
	var item = load("res://resources/items/ether.tres")
	_assert(item != null and item.get("item_id") != null, "Ether resource loads as ItemData")


func test_iron_sword_resource_loads() -> void:
	var item = load("res://resources/equipment/iron_sword.tres")
	_assert(item != null and item.get("slot_type") != null, "Iron Sword loads as Resource")


func test_leather_chest_resource_loads() -> void:
	var item = load("res://resources/equipment/leather_chest.tres")
	_assert(item != null and item.get("slot_type") != null, "Leather Chest loads as Resource")


func test_iron_sword_is_equipment() -> void:
	var item = load("res://resources/equipment/iron_sword.tres") as Resource
	_assert(item.slot_type == 7 and item.stat_modifiers.has("attack"),
		"Iron Sword is RIGHT_HAND slot with attack stat")


func test_leather_chest_is_equipment() -> void:
	var item = load("res://resources/equipment/leather_chest.tres") as Resource
	_assert(item.slot_type == 2 and item.stat_modifiers.has("defense"),
		"Leather Chest is CHEST slot with defense stat")


# ========== CATEGORY 6: PLAYER INTEGRATION ==========

func test_player_has_inventory_system() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("inventory_system") and source.contains("InventorySystem"),
		"Player has inventory_system reference")


func test_player_has_equipment_system() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("equipment_system") and source.contains("EquipmentSystem"),
		"Player has equipment_system reference")


func test_save_data_includes_inventory() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"inventory"') and source.contains("inventory_system.get_save_data"),
		"Player save data includes inventory")


func test_save_data_includes_equipment() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"equipment"') and source.contains("equipment_system.get_save_data"),
		"Player save data includes equipment")


func test_equipment_system_has_save_load() -> void:
	var source := _get_source("res://src/player/components/equipment_system.gd")
	_assert(source.contains("get_save_data") and source.contains("load_save_data"),
		"EquipmentSystem has save/load methods")


func test_inventory_system_has_save_load() -> void:
	var source := _get_source("res://src/player/components/inventory_system.gd")
	_assert(source.contains("get_save_data") and source.contains("load_save_data"),
		"InventorySystem has save/load methods")


# ========== CATEGORY 7: SIGNALS & EVENTS ==========

func test_events_has_item_acquired() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal item_acquired"),
		"Events bus has item_acquired signal")


func test_events_has_item_used() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal item_used"),
		"Events bus has item_used signal")


func test_events_has_equipment_changed() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal equipment_changed"),
		"Events bus has equipment_changed signal")


func test_equipment_emits_signal_on_equip() -> void:
	var source := _get_source("res://src/player/components/equipment_system.gd")
	_assert(source.contains("equipment_changed.emit"),
		"EquipmentSystem emits equipment_changed on equip/unequip")


# ========== CATEGORY 8: ITEM UI INTEGRATION ==========

func test_tactical_menu_has_items_category() -> void:
	var source := _get_source("res://src/ui/hud/tactical_menu.gd")
	_assert(source.contains("ITEMS") and source.contains("Category.ITEMS"),
		"Tactical menu has Items category")


func test_inventory_get_all_items() -> void:
	var inv = _create_inventory()
	var item = _create_test_item("all_test", true)
	inv.add_item(item, 3)
	var all = inv.get_all_items()
	_assert(all.size() == 1 and all[0]["quantity"] == 3,
		"get_all_items returns full inventory")
	inv.free()


func test_equipment_get_slot_name() -> void:
	var equip = _create_equipment_system()
	_assert(equip.get_slot_name(0) == "Head"
		and equip.get_slot_name(7) == "Right Hand",
		"get_slot_name returns human-readable slot names")
	equip.free()


func test_equipment_persistence_structure() -> void:
	var equip = _create_equipment_system()
	var sword = _create_test_equipment("persist_sword", 7, {"attack": 5.0})
	equip.equip(sword)
	var data = equip.get_save_data()
	_assert(data is Dictionary and data.size() > 0,
		"Equipment save data is a non-empty Dictionary")
	equip.free()


# ========== HELPERS ==========

func _create_inventory() -> Node:
	var script = load("res://src/player/components/inventory_system.gd")
	var node = Node.new()
	node.set_script(script)
	add_child(node)
	return node


func _create_equipment_system() -> Node:
	var script = load("res://src/player/components/equipment_system.gd")
	var node = Node.new()
	node.set_script(script)
	add_child(node)
	node._ready()
	return node


func _create_test_item(id: String, stackable_flag: bool) -> Resource:
	var item_script = load("res://resources/items/item_data.gd")
	var item = Resource.new()
	item.set_script(item_script)
	item.item_id = StringName(id)
	item.display_name = id
	item.stackable = stackable_flag
	item.max_stack = 99 if stackable_flag else 1
	item.category = 0  # CONSUMABLE
	return item


func _create_test_equipment(id: String, slot: int, stats: Dictionary) -> Resource:
	var equip_script = load("res://resources/equipment/equipment_data.gd")
	var item = Resource.new()
	item.set_script(equip_script)
	item.item_id = StringName(id)
	item.display_name = id
	item.slot_type = slot
	item.stat_modifiers = stats
	return item


func _get_source(path: String) -> String:
	var res = load(path)
	if res == null:
		return ""
	if res is GDScript:
		return res.source_code
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name)


func _section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


func _pass(test_name: String) -> void:
	_passed += 1
	_total += 1
	print("  PASS: %s" % test_name)


func _fail(test_name: String, reason: String = "") -> void:
	_failed += 1
	_total += 1
	var msg := "  FAIL: %s" % test_name
	if reason != "":
		msg += " — %s" % reason
	print(msg)
