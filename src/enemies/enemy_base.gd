## Base class for all enemies.
extends CharacterBody3D
class_name EnemyBase

@export var max_hp: float = 50.0
@export var attack_damage: float = 10.0
@export var move_speed: float = 4.0
@export var aggro_range: float = 12.0
@export var attack_range: float = 2.0
@export var attack_telegraph: float = 0.4
@export var attack_active: float = 0.2
@export var attack_recovery: float = 0.5
@export var attack_cooldown: float = 1.8
@export var stagger_duration: float = 0.5
@export var gravity: float = 20.0

var current_hp: float

@onready var visual_root: Node3D = $VisualRoot
@onready var hurtbox: Area3D = $Hurtbox
@onready var attack_origin: Node3D = $AttackOrigin
@onready var attack_hitbox_shape: CollisionShape3D = $AttackOrigin/AttackHitbox/CollisionShape3D
@onready var aggro_area: Area3D = $AggroArea
@onready var lock_on_point: Marker3D = $LockOnPoint

var _target: Node3D = null
var _is_dead: bool = false
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _hit_active: bool = false
var _original_color: Color

enum AIState { IDLE, CHASE, ATTACK_TELEGRAPH, ATTACK_STRIKE, ATTACK_RECOVERY, HURT, DEAD }
var ai_state: AIState = AIState.IDLE


func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	aggro_area.body_entered.connect(_on_aggro_body_entered)

	var mesh: MeshInstance3D = visual_root.get_node("MeshInstance3D")
	if mesh and mesh.material_override:
		_original_color = mesh.material_override.albedo_color

	Events.enemy_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Attack cooldown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK_TELEGRAPH:
			_process_attack_telegraph(delta)
		AIState.ATTACK_STRIKE:
			_process_attack_strike(delta)
		AIState.ATTACK_RECOVERY:
			_process_attack_recovery(delta)
		AIState.HURT:
			_process_hurt(delta)

	move_and_slide()


func take_damage(amount: float, _source: Node3D = null) -> void:
	if _is_dead:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	Events.enemy_damaged.emit(self, amount)

	# Hit stop feedback
	GameManager.hit_stop(40.0)

	if current_hp <= 0.0:
		die()
	else:
		_enter_hurt()


func die() -> void:
	_is_dead = true
	ai_state = AIState.DEAD
	_disable_attack_hitbox()

	# Disable collisions so player/lock-on clean up
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	aggro_area.set_deferred("monitoring", false)

	Events.enemy_died.emit(self)

	# Death shrink then cleanup
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(queue_free)


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"), area.get_parent())


func _on_aggro_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_target = body
		if ai_state == AIState.IDLE:
			ai_state = AIState.CHASE
			Events.enemy_aggro_triggered.emit(self)


# --- AI States ---

func _process_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _process_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		ai_state = AIState.IDLE
		return

	var dist := global_position.distance_to(_target.global_position)

	# Lost interest
	if dist > aggro_range * 1.5:
		_target = null
		ai_state = AIState.IDLE
		return

	# In attack range and cooldown ready
	if dist < attack_range and _attack_cooldown_timer <= 0.0:
		_enter_attack_telegraph()
		return

	# Navigate toward target — use direct steering (no nav mesh dependency)
	var direction: Vector3 = (_target.global_position - global_position)
	direction.y = 0.0
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		# Face movement direction
		basis = basis.slerp(Basis.looking_at(direction), clampf(8.0 * delta, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _enter_attack_telegraph() -> void:
	ai_state = AIState.ATTACK_TELEGRAPH
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _process_attack_telegraph(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	# Face the target during wind-up
	if _target and is_instance_valid(_target):
		var dir: Vector3 = (_target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			basis = basis.slerp(Basis.looking_at(dir.normalized()), clampf(12.0 * delta, 0.0, 1.0))

	if _state_timer >= attack_telegraph:
		_enter_attack_strike()


func _enter_attack_strike() -> void:
	ai_state = AIState.ATTACK_STRIKE
	_state_timer = 0.0
	_enable_attack_hitbox()


func _process_attack_strike(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_active:
		_disable_attack_hitbox()
		ai_state = AIState.ATTACK_RECOVERY
		_state_timer = 0.0


func _process_attack_recovery(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_recovery:
		_attack_cooldown_timer = attack_cooldown
		ai_state = AIState.CHASE


func _enter_hurt() -> void:
	_disable_attack_hitbox()
	ai_state = AIState.HURT
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	# Flash red on hit
	_flash_color(Color(1.0, 0.5, 0.5, 1.0), 0.15)


func _process_hurt(delta: float) -> void:
	_state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	if _state_timer >= stagger_duration:
		ai_state = AIState.CHASE


# --- Attack Hitbox ---

func _enable_attack_hitbox() -> void:
	attack_hitbox_shape.disabled = false
	var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
	hitbox_area.set_meta("damage", attack_damage)
	_hit_active = true


func _disable_attack_hitbox() -> void:
	if _hit_active:
		attack_hitbox_shape.set_deferred("disabled", true)
		var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
		if hitbox_area.has_meta("damage"):
			hitbox_area.remove_meta("damage")
		_hit_active = false


# --- Visual Feedback ---

func _flash_color(color: Color, duration: float) -> void:
	var mesh: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D")
	if mesh == null or mesh.material_override == null:
		return
	mesh.material_override.albedo_color = color
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(mesh) and mesh.material_override:
			mesh.material_override.albedo_color = _original_color
	)
