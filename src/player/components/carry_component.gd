## Carry component (controls v2, Package I).
## Owns the "what am I holding" state for the player. The crate itself
## (CarryableCrate, Package H) owns its physics; this component only calls its
## public API: can_pick_up / pick_up / put_down / throw / release.
##
## Flow:  crate.interact(player) -> request_pick_up(crate) -> StateMachine "Carry"
##        Carry --tap B--> put_down()          (carry_ended reason &"put_down")
##        Carry --hold B--> ThrowAim --X--> throw(dir)  (reason &"thrown")
##        player hurt -> drop(&"hit"); illegal exit / zone exit / death -> drop(&"forced")
##
## Carry is never saved (I6): nothing here is written to save data, and a load
## or zone exit drops the crate first.
class_name CarryComponent
extends Node

## States from which a pick-up is accepted (free, grounded locomotion only).
const PICK_UP_STATES: Array[StringName] = [&"Idle", &"Run", &"Land"]

## Put-down spot distance in front of the player (crate bottom centre).
@export var put_down_distance: float = 1.3
## Launch speed (m/s) and elevation angle for throws.
@export var throw_speed: float = 11.0
@export var throw_angle_deg: float = 28.0

var player: CharacterBody3D = null
var held_object: Node3D = null

## True while a crate is held.
var is_carrying: bool:
	get:
		return held_object != null and is_instance_valid(held_object)

# Set by Carry/ThrowAim right before they hand off to each other, so their
# exit() knows the transition is internal and must not drop the crate.
var _handoff: bool = false


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	Events.player_hurt.connect(_on_player_hurt)
	Events.player_died.connect(_on_forced_event)
	Events.zone_exiting.connect(_on_zone_exiting)
	Events.load_completed.connect(_on_load_completed)


# ── Public API ─────────────────────────────────────────────────────────────────

## Called by CarryableCrate.interact(). Returns true if the crate was lifted.
func request_pick_up(obj: Node3D) -> bool:
	if not can_pick_up_now(obj):
		return false
	obj.pick_up(player)
	if not ("is_held" in obj and obj.is_held):
		return false
	held_object = obj
	_handoff = false
	Events.carryable_in_range.emit(null)  # clear the "[B] Pick Up" prompt
	player.state_machine.force_transition(&"Carry")
	Events.carry_started.emit(obj)
	return true


## True when request_pick_up(obj) would succeed.
func can_pick_up_now(obj: Node3D) -> bool:
	if player == null or obj == null or not is_instance_valid(obj):
		return false
	if is_carrying:
		return false
	if not obj.has_method("pick_up") or not obj.has_method("can_pick_up") or not obj.can_pick_up():
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if not player.is_on_floor():
		return false
	var cur: Node = player.state_machine.current_state
	return cur != null and StringName(cur.name) in PICK_UP_STATES


## Gently place the crate in front of the player. Returns false (and keeps
## carrying) if there's no room.
func put_down() -> bool:
	if not is_carrying:
		return false
	var fwd := _flat_forward()
	var spot: Vector3 = player.global_position + fwd * put_down_distance
	if not held_object.put_down(spot):
		return false
	_finish(&"put_down")
	return true


## Throw the crate along `dir` (flattened) at throw_speed / throw_angle_deg.
func throw(dir: Vector3) -> bool:
	if not is_carrying:
		return false
	var obj := held_object
	var mass: float = obj.mass if "mass" in obj else 1.0
	obj.throw(get_launch_velocity(dir) * mass)
	_finish(&"thrown")
	return true


## Let go without a throw. Can't fail. reason: &"hit" or &"forced".
func drop(reason: StringName = &"forced") -> void:
	if not is_carrying:
		held_object = null
		return
	held_object.release()
	_finish(reason)


## Initial velocity a throw along `dir` would give the crate.
func get_launch_velocity(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = _flat_forward()
	flat = flat.normalized()
	var a := deg_to_rad(throw_angle_deg)
	return flat * cos(a) * throw_speed + Vector3.UP * sin(a) * throw_speed


## Gravity acting on the held crate (for the arc preview).
func get_held_gravity() -> float:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if is_carrying and "gravity_scale" in held_object:
		g *= held_object.gravity_scale
	return g


## Internal Carry <-> ThrowAim handoff (see _handoff).
func mark_handoff() -> void:
	_handoff = true


func consume_handoff() -> bool:
	var h := _handoff
	_handoff = false
	return h


# ── Internals ──────────────────────────────────────────────────────────────────

func _finish(reason: StringName) -> void:
	var obj := held_object
	held_object = null
	_handoff = false
	if player and player.has_method("set_sprinting"):
		player.set_sprinting(false)
	Events.carry_ended.emit(obj, reason)


func _flat_forward() -> Vector3:
	var f := -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _on_player_hurt(_damage: float, _source: Node3D) -> void:
	drop(&"hit")


func _on_forced_event() -> void:
	drop(&"forced")


func _on_zone_exiting(_zone_id: StringName) -> void:
	drop(&"forced")


func _on_load_completed(_slot: int) -> void:
	drop(&"forced")
