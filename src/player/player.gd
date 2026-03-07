## Player character controller.
## Designed as CharacterBase for future party member extension.
extends CharacterBody3D

@export var gravity: float = 30.0

@onready var state_machine: Node = $StateMachine
@onready var visual_root: Node3D = $VisualRoot
@onready var hurtbox: Area3D = $Hurtbox
@onready var hitbox_anchor: Node3D = $HitboxAnchor
@onready var hitbox: Area3D = $HitboxAnchor/Hitbox
@onready var hitbox_shape: CollisionShape3D = $HitboxAnchor/Hitbox/CollisionShape3D
@onready var camera_anchor: Node3D = $CameraAnchor
@onready var interaction_anchor: Area3D = $InteractionAnchor
@onready var lock_on_component: LockOnComponent = $LockOnComponent

var is_locked_on: bool = false
var lock_on_target: Node3D = null
var dodge_ready: bool = true

# Jump buffering
var jump_buffer_time: float = 0.12
var _jump_buffer_timer: float = 0.0

# Ledge detection
@onready var chest_ray: RayCast3D = $LedgeDetector/ChestRay
@onready var head_ray: RayCast3D = $LedgeDetector/HeadRay
var _ledge_surface_y: float = 0.0
var _ledge_wall_point: Vector3 = Vector3.ZERO
var _ledge_wall_normal: Vector3 = Vector3.ZERO

var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mp: float = 50.0
var max_mp: float = 50.0
var current_atb: float = 0.0
var max_atb: float = 100.0
var atb_fill_rate: float = 5.0


func _ready() -> void:
	add_to_group(&"player")
	state_machine.initialize(self)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	Events.lock_on_target_acquired.connect(_on_lock_on_acquired)
	Events.lock_on_target_lost.connect(_on_lock_on_lost)
	Events.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump buffer countdown
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	# ATB fills over time during combat
	if current_atb < max_atb:
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)
		Events.player_atb_changed.emit(current_atb, max_atb)

	move_and_slide()


func take_damage(amount: float, source: Node3D = null) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_hurt.emit(amount, source)
	state_machine.force_transition(&"Flinch")

	if current_hp <= 0.0:
		Events.player_died.emit()


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_healed.emit(amount)


func has_mp(cost: float) -> bool:
	return current_mp >= cost


func spend_mp(cost: float) -> void:
	current_mp = maxf(current_mp - cost, 0.0)
	Events.player_mp_changed.emit(current_mp, max_mp)


func has_atb(cost: float) -> bool:
	return current_atb >= cost


func spend_atb(cost: float) -> void:
	current_atb = maxf(current_atb - cost, 0.0)
	Events.player_atb_changed.emit(current_atb, max_atb)


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"), area.get_parent())


func buffer_jump() -> void:
	_jump_buffer_timer = jump_buffer_time


func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0


func consume_jump_buffer() -> void:
	_jump_buffer_timer = 0.0


func can_grab_ledge() -> bool:
	if not chest_ray.is_colliding() or head_ray.is_colliding():
		return false

	_ledge_wall_point = chest_ray.get_collision_point()
	_ledge_wall_normal = chest_ray.get_collision_normal()

	# Raycast down from above the wall hit to find the actual ledge surface
	var space := get_world_3d().direct_space_state
	var ray_start: Vector3 = _ledge_wall_point + Vector3(0, 4.0, 0) - _ledge_wall_normal * 0.3
	var ray_end: Vector3 = _ledge_wall_point + Vector3(0, -0.5, 0) - _ledge_wall_normal * 0.3
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false

	_ledge_surface_y = result["position"].y

	# Check if ledge height is within grab range relative to player
	var ledge_height: float = _ledge_surface_y - global_position.y
	return ledge_height >= 0.5 and ledge_height <= 3.5


func get_ledge_snap_position() -> Vector3:
	# Hang position: back from wall, player center below ledge surface
	var hang_pos: Vector3 = _ledge_wall_point + _ledge_wall_normal * 0.4
	hang_pos.y = _ledge_surface_y - 1.6
	return hang_pos


func get_ledge_climb_position() -> Vector3:
	# Top of ledge: past the wall edge, standing on surface
	var top_pos: Vector3 = _ledge_wall_point - _ledge_wall_normal * 0.6
	top_pos.y = _ledge_surface_y + 0.1
	return top_pos


func enable_hitbox(damage: float) -> void:
	hitbox.set_meta("damage", damage)
	hitbox_shape.disabled = false


func disable_hitbox() -> void:
	hitbox_shape.disabled = true
	if hitbox.has_meta("damage"):
		hitbox.remove_meta("damage")


func face_lock_target(delta: float) -> void:
	if lock_on_target == null or not is_instance_valid(lock_on_target):
		return
	var dir: Vector3 = (lock_on_target.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		basis = basis.slerp(Basis.looking_at(dir.normalized()), 10.0 * delta)


func _on_lock_on_acquired(target: Node3D) -> void:
	is_locked_on = true
	lock_on_target = target


func _on_lock_on_lost() -> void:
	is_locked_on = false
	lock_on_target = null


func get_save_data() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"rotation_y": global_rotation.y,
		"hp": current_hp,
		"mp": current_mp,
		"atb": current_atb,
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos = data["position"]
		global_position = Vector3(pos["x"], pos["y"], pos["z"])
	if data.has("rotation_y"):
		global_rotation.y = data["rotation_y"]
	current_hp = data.get("hp", max_hp)
	current_mp = data.get("mp", max_mp)
	current_atb = data.get("atb", 0.0)
