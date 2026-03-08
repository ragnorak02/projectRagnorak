extends State

const AttackVFX = preload("res://src/effects/attack_vfx.gd")

var _timer: float = 0.0
var _buffered_next: StringName = &""
var _hit_active: bool = false

@export var attack_duration: float = 0.45
@export var combo_window_start: float = 0.2
@export var combo_window_end: float = 0.42
@export var forward_movement: float = 4.0
@export var hit_window_start: float = 0.08
@export var hit_window_end: float = 0.25
@export var damage: float = 12.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_buffered_next = &""
	_hit_active = false
	Events.combo_count_changed.emit(1)

	# Soft track toward lock-on target
	if player.is_locked_on:
		player.face_lock_target(1.0)

	AttackVFX.spawn(player.get_parent(), 1, player.global_position + Vector3(0, 1.0, 0), -player.global_basis.z)
	AudioManager.play_sfx_varied("attack_1")


func exit() -> void:
	if _hit_active:
		player.disable_hitbox()
		_hit_active = false


func process_physics(delta: float) -> StringName:
	_timer += delta

	# Forward lunge — short burst then quick stop
	if _timer < 0.12:
		player.velocity.x = player.global_basis.z.x * -forward_movement
		player.velocity.z = player.global_basis.z.z * -forward_movement
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 35.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 35.0 * delta)

	# Hit window
	if _timer >= hit_window_start and _timer < hit_window_end:
		if not _hit_active:
			player.enable_hitbox(damage)
			_hit_active = true
	elif _hit_active:
		player.disable_hitbox()
		_hit_active = false

	if _timer >= attack_duration:
		if _buffered_next != &"":
			return _buffered_next
		Events.combo_reset.emit()
		if player.is_locked_on:
			return &"LockOnIdle"
		return &"Idle"

	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		if _timer >= combo_window_start and _timer <= combo_window_end:
			return &"Attack2"
		else:
			_buffered_next = &"Attack2"

	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"

	return &""
