## Data resource for a single ability/spell.
class_name AbilityData
extends Resource

enum AbilityType { MELEE, PROJECTILE, AOE, MOVEMENT, DEFENSE, HEAL }
## v5 BB1: how the ability reaches its target.
##  PROJECTILE — effect_scene flies from the caster (Fire Bolt, Ice Freeze).
##  AT_TARGET  — effect_script spawns at/around the chosen enemy (Water Geyser).
##  SELF_ALLY  — caster or an ally (Heal); no enemy range check.
enum Targeting { PROJECTILE, AT_TARGET, SELF_ALLY }
## v5 BB6: caster movement during the release phase.
##  NONE — rooted (default). PLUNGE — dive straight down (toward the target
##  when one is chosen); the effect fires on landing.
##  LAUNCH — v8: the release launches the caster straight up (Super Jump:
##  ~5x the jump apex, see super_jump.gd constants) into Jump. Self-only: the
##  Command Menu fires it without a target step.
enum CasterMotion { NONE, PLUNGE, LAUNCH }

## Default reach (m) = LockOnComponent.detection_range default (20 m).
const DEFAULT_RANGE := 20.0

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

## v5 BB1 (user range rule, item 3): max distance (m) from the caster to an
## enemy target. Enemies beyond it are listed but darkened and can't be
## confirmed for this ability. The active member's max over offensive
## abilities (AbilitySystem.get_max_range()) bounds the target list + lock-on.
@export var range: float = DEFAULT_RANGE
@export var targeting: Targeting = Targeting.PROJECTILE
## Only shown in the Command Menu while airborne (Plunge Strike, Air Burst).
@export var aerial_only: bool = false
## Greyed "Grounded only" in the airborne Command Menu.
@export var ground_only: bool = false
## Member ids that may use it (&"hero", &"companion"). Empty = anyone.
@export var owner_member: Array[StringName] = []
## Stagger added per hit by effect_script abilities.
@export var stagger: float = 0.0
## Script for AT_TARGET / caster-centred effects (src/effects/abilities/*.gd).
## Contract: extends Node3D, `func setup(caster: Node3D, target: Node3D,
## ability: AbilityData, aim_dir: Vector3) -> void`, called after add_child.
@export var effect_script: Script = null
@export var caster_motion: CasterMotion = CasterMotion.NONE


## Offensive = targets enemies (MELEE / PROJECTILE / AOE, not SELF_ALLY).
func is_offensive() -> bool:
	if targeting == Targeting.SELF_ALLY:
		return false
	return ability_type in [AbilityType.MELEE, AbilityType.PROJECTILE, AbilityType.AOE]


## v8: self-only commands skip the Command Menu target step (Super Jump).
func is_self_only() -> bool:
	return caster_motion == CasterMotion.LAUNCH


func usable_by(member_id: StringName) -> bool:
	return owner_member.is_empty() or member_id == &"" or owner_member.has(member_id)
