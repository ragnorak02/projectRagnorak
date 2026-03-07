extends State

const AttackVFX = preload("res://src/effects/attack_vfx.gd")

var _timer: float = 0.0
var _hit_active: bool = false

@export var attack_duration: float = 0.5
@export var downward_force: float = 15.0
@export var hit_window_start: float = 0.05
@export var hit_window_end: float = 0.4
@export var damage: float = 18.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_hit_active = false
	player.velocity.y = -downward_force

	if player.is_locked_on:
		player.face_lock_target(1.0)

	AttackVFX.spawn(player.get_parent(), 4, player.global_position + Vector3(0, 0.5, 0), -player.global_basis.z)


func exit() -> void:
	if _hit_active:
		player.disable_hitbox()
		_hit_active = false


func process_physics(delta: float) -> StringName:
	_timer += delta

	# Hit window while diving
	if _timer >= hit_window_start and _timer < hit_window_end:
		if not _hit_active:
			player.enable_hitbox(damage)
			_hit_active = true
	elif _hit_active:
		player.disable_hitbox()
		_hit_active = false

	if player.is_on_floor():
		return &"Land"
	if _timer >= attack_duration:
		return &"Fall"
	return &""
