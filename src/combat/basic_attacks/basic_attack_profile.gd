## v6 HH — per-member basic-attack (X) profile.
##
## PartyMemberData.basic_attack_profile points at one of these. The profile only
## decides WHAT a strike does; the timing of the press (tap = light, hold =
## heavy at ComboComponent.HOLD_THRESHOLD_MS), the L/H string, the chain window,
## dodge-cancel, the Command-Menu survival and the v5 air-combo budget stay in
## ComboComponent / the MeleeStrike state and are identical for every kind.
##
## kind:
##   &"melee"  Amaro. MeleeStrike keeps its own STRIKES table and
##             ComboComponent.FINISHERS (bit-identical to v5). `strikes` and
##             `finishers` are ignored.
##   &"mage"   Taighe. Every step fires a MageBolt (mage_bolt.gd) at the fire
##             time (`hit_start`): light = quick bolt, heavy = charged shot. Both
##             soft-track the lock-on target (or the nearest enemy inside
##             SOFT_AIM_DOT / SOFT_AIM_RANGE). Step 3 is a ranged finisher burst
##             picked by the number of heavies in the string
##             (finisher_by_heavies[0..3]) and detonates on impact / at range.
##             0 MP, builds stagger.
##
## The same profile drives CompanionAI when the member is AI-controlled
## (ai_* fields), so the kit travels with the identity on a party switch.
##
## strikes: {&"light"|&"heavy": {duration, hit_start, hit_end, chain_at, lunge,
##   lunge_time, damage, stagger, speed, lifetime, homing, radius}} (seconds of
##   game time, metres, m/s).
## finishers: {name: {mult, radius, stagger, shake: [intensity, duration] | [],
##   speed, lifetime, homing, size}}.
class_name BasicAttackProfile
extends Resource

const KIND_MELEE := &"melee"
const KIND_MAGE := &"mage"

## Soft aim without lock-on: nearest live enemy within this cone (dot of the
## flat facing) and range gets the bolt's homing.
const SOFT_AIM_DOT := 0.82
const SOFT_AIM_RANGE := 18.0

const DEFAULT_MELEE_PATH := "res://src/combat/basic_attacks/melee_profile.tres"

@export var kind: StringName = KIND_MELEE
@export var display_name: String = ""
@export var strikes: Dictionary = {}
@export var finishers: Dictionary = {}
## Finisher name by heavy count in the 3-letter string (index 0..3).
@export var finisher_by_heavies: Array[StringName] = []
## Bolt colours (mage): core / glow.
@export var core_color: Color = Color(0.85, 0.97, 1.0, 1.0)
@export var glow_color: Color = Color(0.35, 0.8, 1.0, 1.0)

@export_group("Companion AI")
## Distance at which the AI starts a string.
@export var ai_attack_range: float = 2.5
## The AI backs off when an enemy is closer than this (0 = never).
@export var ai_keep_distance: float = 0.0
## The L/H string the AI plays (1..3 letters).
@export var ai_pattern: String = "LLL"
## Seconds between AI strings.
@export var ai_string_cooldown: float = 2.0


func is_mage() -> bool:
	return kind == KIND_MAGE


## Strike data for &"light" / &"heavy" (mage). {} for melee (MeleeStrike owns it).
func get_strike(strike_kind: StringName) -> Dictionary:
	if not is_mage():
		return {}
	return strikes.get(strike_kind, strikes.get(&"light", {}))


## Finisher for a full 3-letter string. Melee = ComboComponent.get_finisher.
func get_finisher(combo_string: String) -> StringName:
	if not is_mage():
		return ComboComponent.get_finisher(combo_string)
	if combo_string.length() < ComboComponent.MAX_STEPS:
		return &""
	if finisher_by_heavies.is_empty():
		return &""
	var heavies := clampi(combo_string.count("H"), 0, finisher_by_heavies.size() - 1)
	return finisher_by_heavies[heavies]


func get_finisher_data(finisher: StringName) -> Dictionary:
	if not is_mage():
		return ComboComponent.get_finisher_data(finisher)
	return finishers.get(finisher, {})


## The profile of `data` (a PartyMemberData), else the default melee profile.
## Never null (falls back to an in-memory melee profile).
static func for_member(data: Resource) -> BasicAttackProfile:
	if data != null:
		var p = data.get(&"basic_attack_profile")
		if p is BasicAttackProfile:
			return p
	if ResourceLoader.exists(DEFAULT_MELEE_PATH):
		var res := load(DEFAULT_MELEE_PATH)
		if res is BasicAttackProfile:
			return res
	return BasicAttackProfile.new()
