## Data resource defining a party member's identity and base stats.
extends Resource

@export var member_id: StringName = &""
@export var display_name: String = ""
@export var max_hp: float = 100.0
@export var max_mp: float = 50.0
@export var max_atb: float = 100.0
@export var atb_fill_rate: float = 5.0
@export var mp_regen_rate: float = 1.5
@export var attack_damage: float = 15.0
@export var move_speed: float = 8.0

## Visual color for placeholder capsule
@export var capsule_color: Color = Color(0.3, 0.5, 0.8)

## Traversal abilities this member grants (e.g. "has_wall_break", "has_double_jump")
@export var traversal_flags: Array[String] = []

## Abilities this member can equip
@export var default_abilities: Array[Resource] = []
