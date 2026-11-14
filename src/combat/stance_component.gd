## Character unique ability / stance driver (battle system v3, Package S).
##
## Child of Player ($StanceComponent, reachable as player.stance).
## The ability comes from player.get_member_data().unique_ability_id
## (PartyMemberData; Amaro = &"arcane_stance", Taighe = &""), resolved through
## REGISTRY (id -> script). Adding a character's Y ability = one script + one
## registry line + the id in their .tres.
##
## Public API (signatures published by Package Q — keep them):
##   func toggle() -> bool            Y in battle / R. Returns the new is_active().
##                                    Entering requires player.in_battle, a live
##                                    player, GameState PLAYING and a registered
##                                    ability. Exiting is always allowed.
##   func is_active() -> bool
##   func current_stance() -> StringName   The active ability id (&"arcane_stance"),
##                                         &"" when no stance is active.
##   func handle_attack_press() -> bool    Called FIRST on an `attack` press in
##                                         battle. true = consumed (no melee).
##   func handle_attack_release() -> bool  Forwarded on every `attack` release.
##                                         true = consumed (the press was ours).
##   func exit_stance(reason: StringName = &"manual") -> void
## Extras: get_display_name() -> String ("ARCANE"; for the HUD tag),
##   refresh_ability() (re-resolve after a party/member change), var ability.
## Emits Events.stance_changed(member_id, stance) (stance &"" on exit).
## Leaves the stance on Events.battle_mode_changed(false) (reason &"battle_end").
##
## Unique-ability script contract (duck-typed Node, added as a child here):
##   setup(player, component), on_enter(), on_exit(reason),
##   on_attack_press() -> bool, on_attack_release() -> bool, var display_name.
## v5: INSTANT abilities (var is_instant = true, func activate() -> bool) fire
## once per press instead of holding a stance: toggle() calls activate() and
## returns false (is_active() stays false, no aura, no stance_changed).
## Taighe = &"super_jump" (super_jump.gd).
class_name StanceComponent
extends Node

const REGISTRY := {
	# preload, not runtime load(): a runtime script load during the player's _ready
	# breaks Godot 4.6's exit cycle cleanup (v6 KK: "resources still in use at exit").
	&"arcane_stance": preload("res://src/combat/unique_abilities/arcane_stance.gd"),
	&"super_jump": preload("res://src/combat/unique_abilities/super_jump.gd"),
}

var player: Node = null
## Resolved from PartyMemberData.unique_ability_id (&"" if none).
var ability_id: StringName = &""
## The live ability node for ability_id (null if the id is empty/unregistered).
var ability: Node = null
var _stance: StringName = &""
var _aura: Node3D = null


func _ready() -> void:
	player = get_parent()
	refresh_ability()
	Events.battle_mode_changed.connect(_on_battle_mode_changed)


## Re-reads unique_ability_id from the member data and (re)builds the ability.
func refresh_ability() -> void:
	var new_id: StringName = &""
	if player and player.has_method("get_member_data"):
		var data: Resource = player.get_member_data()
		if data and "unique_ability_id" in data:
			new_id = data.unique_ability_id
	if new_id == ability_id and (ability != null or new_id == &""):
		return
	if is_active():
		exit_stance(&"ability_changed")
	if ability:
		ability.queue_free()
		ability = null
	ability_id = new_id
	if ability_id == &"" or not REGISTRY.has(ability_id):
		if ability_id != &"":
			push_warning("StanceComponent: unregistered unique ability '%s'" % ability_id)
		return
	var script: GDScript = REGISTRY[ability_id]
	if script == null:
		return
	ability = script.new()
	ability.name = String(ability_id).to_pascal_case()
	add_child(ability)
	ability.setup(player, self)


func toggle() -> bool:
	if is_active():
		exit_stance(&"toggle")
		return false
	if not _can_enter():
		return false
	if is_instant():
		ability.activate()
		return false
	_enter()
	return true


## True when the resolved unique ability is a one-shot (no stance held).
func is_instant() -> bool:
	return ability != null and ability.get(&"is_instant") == true


func is_active() -> bool:
	return _stance != &""


func current_stance() -> StringName:
	return _stance


func get_display_name() -> String:
	if ability and "display_name" in ability:
		return ability.display_name
	return ""


func handle_attack_press() -> bool:
	if not is_active() or ability == null:
		return false
	return ability.on_attack_press()


func handle_attack_release() -> bool:
	if not is_active() or ability == null:
		return false
	return ability.on_attack_release()


func exit_stance(reason: StringName = &"manual") -> void:
	if not is_active():
		return
	_stance = &""
	if ability:
		ability.on_exit(reason)
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	if player is Node3D and player.is_inside_tree():
		StanceAuraVfx.flash(player.get_parent(), player.global_position, false)
	Events.stance_changed.emit(_member_id(), &"")


func _can_enter() -> bool:
	if player == null:
		return false
	refresh_ability()
	if ability == null:
		return false
	if not player.get("in_battle"):
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if "current_hp" in player and player.current_hp <= 0.0:
		return false
	return true


func _enter() -> void:
	_stance = ability_id
	ability.on_enter()
	if player is Node3D and player.is_inside_tree():
		_aura = StanceAuraVfx.attach(player, StanceAuraVfx.new())
		StanceAuraVfx.flash(player.get_parent(), player.global_position, true)
	AudioManager.play_sfx_named("spell_cast")
	Events.stance_changed.emit(_member_id(), _stance)


func _member_id() -> StringName:
	if player and player.has_method("get_member_data"):
		var data: Resource = player.get_member_data()
		if data and "member_id" in data:
			return data.member_id
	return &""


func _on_battle_mode_changed(in_battle: bool) -> void:
	if not in_battle and is_active():
		exit_stance(&"battle_end")
