## Liftable crate — a RigidBody3D the player can pick up, put down and throw.
## Package H (controls v2). The player side (CarryComponent, Carry/ThrowAim states)
## is Package I and drives this object only through the public API below.
##
## Lifecycle:  RESTING --pick_up--> HELD --put_down--> RESTING
##                                   HELD --throw/release--> FLYING --settle--> RESTING
##                                                           FLYING --hit enemy / long fall--> BROKEN
extends RigidBody3D
class_name CarryableCrate

signal impacted(body: Node)
signal broken

const CRATE_SIZE := Vector3(1.08, 1.06, 1.08)  # Prop_Crate AABB, origin at bottom centre
const LAYER_WORLD := 1
const LAYER_PLAYER_BODY := 2
const LAYER_ENEMY_BODY := 4
const LAYER_INTERACTION := 256

@export var impact_damage: float = 10.0
@export var break_fall_height: float = 6.0
@export var min_flight_time: float = 0.25   # seconds before a thrown crate may settle
@export var settle_speed: float = 0.4

var is_held: bool = false
var is_flying: bool = false
var holder: Node3D = null

var _is_broken: bool = false
var _world_parent: Node = null
var _flight_time: float = 0.0
var _peak_y: float = 0.0
var _last_holder: Node3D = null
var _interact_area: Area3D = null


# ── Interaction area (forwards to the crate) ───────────────────────────────────

class CrateInteractArea extends "res://src/interaction/interactable.gd":
	var crate: Node = null

	func _ready() -> void:
		super._ready()
		interaction_name = "Pick Up"
		interact_priority = 3  # below chests (5)
		add_to_group(&"carryable")
		Events.interaction_available.connect(_on_interaction_available)

	func get_prompt_text() -> String:
		return "Pick Up"

	func interact(player: Node) -> void:
		if crate:
			crate.interact(player)

	func _on_interaction_available(obj: Node3D) -> void:
		if obj == self and crate:
			Events.carryable_in_range.emit(crate)


# ── Setup ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group(&"carryable")
	mass = 8.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_set_resting_collision()
	body_entered.connect(_on_body_entered)

	_interact_area = CrateInteractArea.new()
	_interact_area.name = "InteractArea"
	_interact_area.crate = self
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = CRATE_SIZE + Vector3(0.6, 0.4, 0.6)
	col.shape = shape
	col.position.y = CRATE_SIZE.y * 0.5
	_interact_area.add_child(col)
	add_child(_interact_area)


# ── Public API ─────────────────────────────────────────────────────────────────

## Interact handoff: B/E near the crate. The player owns the carry decision.
func interact(player: Node) -> void:
	if not can_pick_up():
		return
	if player and player.has_node("CarryComponent"):
		player.get_node("CarryComponent").request_pick_up(self)


## True when the crate is resting and free to lift.
func can_pick_up() -> bool:
	return not is_held and not is_flying and not _is_broken and is_inside_tree()


## Freeze the crate and attach it to holder's CarryAnchor (or the holder itself).
func pick_up(new_holder: Node3D) -> void:
	if not can_pick_up() or new_holder == null:
		return
	_world_parent = get_parent()
	holder = new_holder
	_last_holder = new_holder
	is_held = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_set_interact_active(false)
	var anchor: Node3D = new_holder.get_node_or_null("CarryAnchor") as Node3D
	if anchor == null:
		anchor = new_holder
	reparent(anchor, false)
	if anchor == new_holder:
		position = Vector3(0, 1.9, 0)
	else:
		position = Vector3.ZERO
	# Centre the crate on the anchor horizontally; bottom sits on the anchor.
	rotation = Vector3.ZERO


## Place the crate at world_pos (bottom centre), snapped to the ground.
## Returns false and keeps the crate held if there's no room.
func put_down(world_pos: Vector3) -> bool:
	if not is_held:
		return false
	var snapped := snap_to_ground(world_pos)
	if not can_place_at(snapped):
		return false
	var yaw := holder.global_rotation.y if holder else 0.0
	_detach_to_world()
	global_position = snapped
	global_rotation = Vector3(0, yaw, 0)
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_set_resting_collision()
	_set_interact_active(true)
	return true


## Launch the held crate with an impulse (N*s; velocity = impulse / mass).
func throw(impulse: Vector3) -> void:
	if not is_held:
		return
	_detach_to_world()
	_begin_flight()
	apply_central_impulse(impulse)


## Let go without a throw (forced drop / hit). Falls from where it is, nudged
## forward so it doesn't land on the holder. Optional extra velocity.
func release(extra_velocity: Vector3 = Vector3.ZERO) -> void:
	if not is_held:
		return
	var fwd := Vector3.ZERO
	if holder:
		fwd = -holder.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.ZERO
	_detach_to_world()
	global_position += fwd * 1.0
	_begin_flight()
	linear_velocity = extra_velocity


## Ground-snap a candidate position (raycast down against World).
func snap_to_ground(world_pos: Vector3) -> Vector3:
	var space := _space()
	if space == null:
		return world_pos
	var q := PhysicsRayQueryParameters3D.create(world_pos + Vector3.UP * 1.5,
		world_pos + Vector3.DOWN * 4.0, LAYER_WORLD)
	q.exclude = _exclude_rids()
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return world_pos
	return Vector3(world_pos.x, hit.position.y + 0.01, world_pos.z)


## True if a crate-sized box at world_pos (bottom centre) overlaps nothing solid.
func can_place_at(world_pos: Vector3) -> bool:
	var space := _space()
	if space == null:
		return true
	var shape := BoxShape3D.new()
	shape.size = CRATE_SIZE * 0.95
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), world_pos + Vector3.UP * (CRATE_SIZE.y * 0.5 + 0.03))
	q.collision_mask = LAYER_WORLD | LAYER_PLAYER_BODY | LAYER_ENEMY_BODY
	# Only exclude ourselves: overlapping the holder (or a companion) counts as no room.
	q.exclude = [get_rid()]
	return space.intersect_shape(q, 1).is_empty()


func is_broken() -> bool:
	return _is_broken


## Break the crate (enemy hit / long fall). Safe to call more than once.
func break_crate() -> void:
	if _is_broken:
		return
	_is_broken = true
	is_flying = false
	if is_held:
		_detach_to_world()
	collision_layer = 0
	collision_mask = 0
	set_deferred("freeze", true)
	_set_interact_active(false)
	remove_from_group(&"carryable")
	broken.emit()
	AudioManager.play_sfx_varied("enemy_hurt", 0.7, 0.6, 0.8)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.2)
	tween.tween_callback(queue_free)


# ── Internals ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_flying or _is_broken:
		return
	_flight_time += delta
	_peak_y = maxf(_peak_y, global_position.y)
	if global_position.y < -50.0:
		break_crate()
		return
	if _flight_time >= min_flight_time and linear_velocity.length() < settle_speed:
		_try_settle()


func _on_body_entered(body: Node) -> void:
	if not is_flying or _is_broken:
		return
	impacted.emit(body)
	if body.is_in_group(&"enemies") and body.has_method("take_damage"):
		# EnemyBase.take_damage enters its HURT (stagger) state; no separate stagger API.
		body.take_damage(impact_damage, self)
		break_crate()
		return
	if _peak_y - global_position.y > break_fall_height:
		break_crate()


func _begin_flight() -> void:
	is_flying = true
	_flight_time = 0.0
	_peak_y = global_position.y
	freeze = false
	# Ghost to the player while flying; still hits world and enemies.
	collision_layer = 0
	collision_mask = LAYER_WORLD | LAYER_ENEMY_BODY
	if _last_holder and _last_holder is PhysicsBody3D:
		add_collision_exception_with(_last_holder)


func _try_settle() -> void:
	# Don't turn solid inside the player or an enemy.
	var space := _space()
	if space:
		var shape := BoxShape3D.new()
		shape.size = CRATE_SIZE * 0.9
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(global_transform.basis, global_transform * Vector3(0, CRATE_SIZE.y * 0.5, 0))
		q.collision_mask = LAYER_PLAYER_BODY | LAYER_ENEMY_BODY
		if not space.intersect_shape(q, 1).is_empty():
			return
	is_flying = false
	if _last_holder and is_instance_valid(_last_holder) and _last_holder is PhysicsBody3D:
		remove_collision_exception_with(_last_holder)
	_set_resting_collision()
	_set_interact_active(true)


func _detach_to_world() -> void:
	var target: Node = _world_parent
	if target == null or not is_instance_valid(target):
		target = get_tree().current_scene if is_inside_tree() else null
	if target and get_parent() != target:
		reparent(target, true)
	is_held = false
	holder = null


func _set_resting_collision() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = LAYER_WORLD | LAYER_ENEMY_BODY


func _set_interact_active(active: bool) -> void:
	if _interact_area and _interact_area.has_method("set_active"):
		_interact_area.call_deferred("set_active", active)


func _space() -> PhysicsDirectSpaceState3D:
	if not is_inside_tree():
		return null
	return get_world_3d().direct_space_state


func _exclude_rids() -> Array[RID]:
	var rids: Array[RID] = [get_rid()]
	var h := holder if holder else _last_holder
	if h and is_instance_valid(h) and h is CollisionObject3D:
		rids.append((h as CollisionObject3D).get_rid())
	return rids
