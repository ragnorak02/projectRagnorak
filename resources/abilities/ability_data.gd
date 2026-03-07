## Data resource for a single ability/spell.
class_name AbilityData
extends Resource

enum AbilityType { MELEE, PROJECTILE, AOE, MOVEMENT, DEFENSE, HEAL }

@export var ability_id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var ability_type: AbilityType = AbilityType.MELEE
@export var mp_cost: float = 10.0
@export var atb_cost: float = 25.0
@export var cooldown: float = 5.0
@export var cast_time: float = 1.0
@export var damage: float = 20.0
@export var animation_name: StringName = &""
@export var effect_scene: PackedScene = null
@export var icon: Texture2D = null
