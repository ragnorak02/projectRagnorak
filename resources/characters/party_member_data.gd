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

## Battle-mode unique ability (Y in battle / R on keyboard). Resolved by
## StanceComponent's registry (id -> script). Empty = no unique ability yet.
## Amaro = &"arcane_stance", Taighe = &"arcane_focus" (v8; Super Jump moved
## to her Command Menu as the super_jump ability).
@export var unique_ability_id: StringName = &""

## v8 ground dodge look (DodgeState): &"acrobat" = roll / cartwheel / backflip
## (Amaro), &"glide" = ice-trail glide / side glide / floating back-leap (Taighe).
@export var dodge_style: StringName = &"acrobat"

## v6 HH — basic attack (X) kit: a BasicAttackProfile
## (src/combat/basic_attacks/basic_attack_profile.gd). Null = melee (the v5
## sword combo). Amaro = melee_profile.tres, Taighe = mage_profile.tres. Read by
## the MeleeStrike state / ComboComponent on the Player body and by CompanionAI,
## so the kit travels with the identity on a party switch.
@export var basic_attack_profile: Resource = null

## v5 EE — rigless model support (docs/rigless_models.md). Null/false = current
## model (Amaro: red knight in player.tscn; others: the companion capsule tinted
## with capsule_color). The visual is built once per member and then travels
## with the identity on party switches.
@export var model_scene: PackedScene = null
@export var model_scale: float = 1.0
## true = wrap model_scene in a RiglessVisual (procedural bob/lean/squash/cues, no animation).
@export var rigless: bool = false
## Facing fix for meshes that don't face -Z (most glTF/Hunyuan exports need 180).
@export var model_yaw_offset_deg: float = 180.0

const RIGLESS_VISUAL_PATH := "res://src/characters/rigless_visual.gd"


## A RiglessVisual for this member, or null when not rigless / no model / EE's
## script is missing. The caller adds it as the single child of visual_root.
func make_rigless_visual() -> Node3D:
	if not rigless or model_scene == null or not ResourceLoader.exists(RIGLESS_VISUAL_PATH):
		return null
	var script: GDScript = load(RIGLESS_VISUAL_PATH)
	if script == null:
		return null
	var rv: Node3D = script.new()
	rv.name = "RiglessVisual"
	rv.set(&"model_scene", model_scene)
	rv.set(&"model_scale", model_scale)
	rv.set(&"model_yaw_offset_deg", model_yaw_offset_deg)
	return rv

## Fallback command list for members whose default_abilities is still empty.
const LEGACY_ABILITY_PATHS: Array[String] = [
	"res://resources/abilities/fire_bolt.tres",
	"res://resources/abilities/ice_freeze.tres",
	"res://resources/abilities/heal.tres",
]


## The member's starting command list: default_abilities (non-null entries), or
## the legacy Fire Bolt / Ice Freeze / Heal set when that list is empty.
func get_starting_abilities() -> Array:
	var out: Array = []
	for a in default_abilities:
		if a != null:
			out.append(a)
	if out.is_empty():
		for p in LEGACY_ABILITY_PATHS:
			var res: Resource = load(p)
			if res:
				out.append(res)
	return out
