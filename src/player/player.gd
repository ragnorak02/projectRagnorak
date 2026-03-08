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
@onready var ability_system: Node = $AbilitySystem
@onready var inventory_system: Node = $InventorySystem
@onready var equipment_system: Node = $EquipmentSystem
@onready var quest_system: Node = $QuestSystem
var party_system: Node = null  # Assigned by zone/arena after spawn

var is_locked_on: bool = false
var lock_on_target: Node3D = null
var dodge_ready: bool = true
var _dodge_cooldown_timer: float = 0.0
@export var dodge_cooldown_time: float = 0.6

# Jump buffering
var jump_buffer_time: float = 0.12
var _jump_buffer_timer: float = 0.0

# Ledge detection
@onready var chest_ray: RayCast3D = $LedgeDetector/ChestRay
@onready var head_ray: RayCast3D = $LedgeDetector/HeadRay
var _ledge_surface_y: float = 0.0
var _ledge_wall_point: Vector3 = Vector3.ZERO
var _ledge_wall_normal: Vector3 = Vector3.ZERO

# Interaction detection
var _nearby_interactables: Array[Node3D] = []
var _current_interactable: Node3D = null

# Traversal abilities
var has_double_jump: bool = false
var _double_jump_used: bool = false

var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mp: float = 50.0
var max_mp: float = 50.0
var current_atb: float = 0.0
var max_atb: float = 100.0
var atb_fill_rate: float = 5.0

# MP regen
var mp_regen_rate: float = 1.5  # MP per second (passive regen)
var mp_regen_delay: float = 2.0  # Seconds after spending MP before regen starts
var _mp_regen_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	state_machine.initialize(self)
	ability_system.initialize(self)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	Events.lock_on_target_acquired.connect(_on_lock_on_acquired)
	Events.lock_on_target_lost.connect(_on_lock_on_lost)
	Events.player_spawned.emit(self)

	# Interaction detection
	interaction_anchor.area_entered.connect(_on_interactable_entered)
	interaction_anchor.area_exited.connect(_on_interactable_exited)

	# Equip default ability (Fire Bolt)
	var fire_bolt := load("res://resources/abilities/fire_bolt.tres") as AbilityData
	if fire_bolt:
		ability_system.equip_ability(fire_bolt, 0)

	# Illegal transitions per design contract
	state_machine.add_illegal_transition(&"Ability", &"Dodge")
	state_machine.add_illegal_transition(&"Flinch", &"TacticalIdle")
	state_machine.add_illegal_transition(&"Flinch", &"Attack1")
	state_machine.add_illegal_transition(&"LedgeGrab", &"Attack1")
	state_machine.add_illegal_transition(&"ClimbUp", &"Attack1")

	# Block tactical mode from forced/locked states (items 167-170)
	for blocked_state in [&"Dodge", &"Ability", &"LedgeGrab", &"ClimbUp",
			&"JumpAttack", &"Attack1", &"Attack2", &"Attack3", &"Land"]:
		state_machine.add_illegal_transition(blocked_state, &"TacticalIdle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		_double_jump_used = false

	# Jump buffer countdown
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	# Dodge cooldown
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
		if _dodge_cooldown_timer <= 0.0:
			dodge_ready = true

	# ATB fills over time during combat
	if current_atb < max_atb:
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)
		Events.player_atb_changed.emit(current_atb, max_atb)

	# MP passive regen after delay
	if _mp_regen_timer > 0.0:
		_mp_regen_timer -= delta
	elif current_mp < max_mp:
		current_mp = minf(current_mp + mp_regen_rate * delta, max_mp)
		Events.player_mp_changed.emit(current_mp, max_mp)

	move_and_slide()


func take_damage(amount: float, source: Node3D = null) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_hurt.emit(amount, source)
	disable_hitbox()
	state_machine.force_transition(&"Flinch")
	GameManager.hit_stop(65.0)
	Events.camera_shake_requested.emit(0.15, 0.2)

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
	_mp_regen_timer = mp_regen_delay
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


func start_dodge_cooldown() -> void:
	dodge_ready = false
	_dodge_cooldown_timer = dodge_cooldown_time


func enable_hitbox(damage: float) -> void:
	hitbox.set_meta("damage", damage)
	hitbox_shape.set_deferred("disabled", false)


func disable_hitbox() -> void:
	hitbox_shape.set_deferred("disabled", true)
	if hitbox.has_meta("damage"):
		hitbox.remove_meta("damage")


func face_lock_target(delta: float) -> void:
	if lock_on_target == null or not is_instance_valid(lock_on_target):
		return
	var dir: Vector3 = (lock_on_target.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		var target_basis := Basis.looking_at(dir.normalized())
		basis = basis.slerp(target_basis, clampf(10.0 * delta, 0.0, 1.0))


func _on_lock_on_acquired(target: Node3D) -> void:
	is_locked_on = true
	lock_on_target = target


func _on_lock_on_lost() -> void:
	is_locked_on = false
	lock_on_target = null


# --- Interaction Detection ---

func _on_interactable_entered(area: Area3D) -> void:
	if not area.is_in_group(&"interactable"):
		return
	if area.has_method("is_active") and not area.is_active():
		return
	if not _nearby_interactables.has(area):
		_nearby_interactables.append(area)
	_update_nearest_interactable()


func _on_interactable_exited(area: Area3D) -> void:
	_nearby_interactables.erase(area)
	_update_nearest_interactable()


func _update_nearest_interactable() -> void:
	# Remove invalid entries
	_nearby_interactables = _nearby_interactables.filter(
		func(n: Node3D) -> bool:
			return is_instance_valid(n) and n.is_in_group(&"interactable") \
				and (not n.has_method("is_active") or n.is_active())
	)

	if _nearby_interactables.is_empty():
		if _current_interactable != null:
			_current_interactable = null
			Events.interaction_cleared.emit()
		return

	# Pick best: highest interact_priority, then nearest
	var best: Node3D = _nearby_interactables[0]
	var best_priority: int = best.interact_priority if "interact_priority" in best else 0
	var best_dist: float = global_position.distance_squared_to(best.global_position)

	for i in range(1, _nearby_interactables.size()):
		var candidate: Node3D = _nearby_interactables[i]
		var c_priority: int = candidate.interact_priority if "interact_priority" in candidate else 0
		var c_dist: float = global_position.distance_squared_to(candidate.global_position)
		if c_priority > best_priority or (c_priority == best_priority and c_dist < best_dist):
			best = candidate
			best_priority = c_priority
			best_dist = c_dist

	if best != _current_interactable:
		_current_interactable = best
		Events.interaction_available.emit(best)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and _current_interactable != null:
		if _current_interactable.has_method("interact"):
			_current_interactable.interact(self)


func get_save_data() -> Dictionary:
	var data := {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"rotation_y": global_rotation.y,
		"hp": current_hp,
		"mp": current_mp,
		"atb": current_atb,
		"inventory": inventory_system.get_save_data(),
		"equipment": equipment_system.get_save_data(),
		"quests": quest_system.get_save_data(),
	}
	if party_system and party_system.has_method("get_save_data"):
		data["party"] = party_system.get_save_data()
	return data


func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos = data["position"]
		global_position = Vector3(pos["x"], pos["y"], pos["z"])
	if data.has("rotation_y"):
		global_rotation.y = data["rotation_y"]
	current_hp = data.get("hp", max_hp)
	current_mp = data.get("mp", max_mp)
	current_atb = data.get("atb", 0.0)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_mp_changed.emit(current_mp, max_mp)
	Events.player_atb_changed.emit(current_atb, max_atb)
	if data.has("inventory"):
		inventory_system.load_save_data(data["inventory"])
	if data.has("equipment"):
		equipment_system.load_save_data(data["equipment"])
	if data.has("quests"):
		quest_system.load_save_data(data["quests"])
	if data.has("party") and party_system and party_system.has_method("load_save_data"):
		party_system.load_save_data(data["party"])
