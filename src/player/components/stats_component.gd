## Tracks and modifies character stats with equipment modifiers.
class_name StatsComponent
extends Node

@export var base_max_hp: float = 100.0
@export var base_max_mp: float = 50.0
@export var base_attack: float = 10.0
@export var base_defense: float = 5.0
@export var base_magic_attack: float = 8.0
@export var base_magic_defense: float = 4.0

var equipment_modifiers: Dictionary = {}

var max_hp: float:
	get: return base_max_hp + _get_mod("max_hp")
var max_mp: float:
	get: return base_max_mp + _get_mod("max_mp")
var attack: float:
	get: return base_attack + _get_mod("attack")
var defense: float:
	get: return base_defense + _get_mod("defense")
var magic_attack: float:
	get: return base_magic_attack + _get_mod("magic_attack")
var magic_defense: float:
	get: return base_magic_defense + _get_mod("magic_defense")


func apply_equipment_modifier(slot: String, modifiers: Dictionary) -> void:
	equipment_modifiers[slot] = modifiers


func remove_equipment_modifier(slot: String) -> void:
	equipment_modifiers.erase(slot)


func _get_mod(stat: String) -> float:
	var total := 0.0
	for slot_mods in equipment_modifiers.values():
		total += slot_mods.get(stat, 0.0)
	return total
