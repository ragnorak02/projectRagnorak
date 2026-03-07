## Base class for all enemies.
extends CharacterBody3D
class_name EnemyBase

@export var max_hp: float = 50.0
@export var attack_damage: float = 10.0
@export var move_speed: float = 4.0
@export var aggro_range: float = 12.0

var current_hp: float

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var hurtbox: Area3D = $Hurtbox
@onready var attack_origin: Node3D = $AttackOrigin
@onready var aggro_area: Area3D = $AggroArea
@onready var lock_on_point: Marker3D = $LockOnPoint

var _target: Node3D = null
var _is_dead: bool = false

enum AIState { IDLE, CHASE, ATTACK, HURT, DEAD }
var ai_state: AIState = AIState.IDLE


func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	aggro_area.body_entered.connect(_on_aggro_body_entered)
	Events.enemy_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.HURT:
			_process_hurt(delta)


func take_damage(amount: float, source: Node3D = null) -> void:
	if _is_dead:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	Events.enemy_damaged.emit(self, amount)

	if current_hp <= 0.0:
		die()
	else:
		ai_state = AIState.HURT


func die() -> void:
	_is_dead = true
	ai_state = AIState.DEAD
	Events.enemy_died.emit(self)
	queue_free()


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"), area.get_parent())


func _on_aggro_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_target = body
		ai_state = AIState.CHASE
		Events.enemy_aggro_triggered.emit(self)


func _process_idle(_delta: float) -> void:
	pass


func _process_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		ai_state = AIState.IDLE
		return
	nav_agent.target_position = _target.global_position
	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0.0
	velocity = direction * move_speed
	move_and_slide()

	if global_position.distance_to(_target.global_position) < 2.0:
		ai_state = AIState.ATTACK


func _process_attack(_delta: float) -> void:
	pass


func _process_hurt(_delta: float) -> void:
	ai_state = AIState.CHASE
