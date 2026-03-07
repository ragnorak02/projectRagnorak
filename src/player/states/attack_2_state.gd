extends State

var _timer: float = 0.0
var _buffered_next: StringName = &""
var _hit_active: bool = false

@export var attack_duration: float = 0.6
@export var combo_window_start: float = 0.3
@export var combo_window_end: float = 0.55
@export var forward_movement: float = 2.5
@export var hit_window_start: float = 0.12
@export var hit_window_end: float = 0.35
@export var damage: float = 15.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	_buffered_next = &""
	_hit_active = false
	Events.combo_count_changed.emit(2)

	if player.is_locked_on:
		player.face_lock_target(1.0)


func exit() -> void:
	if _hit_active:
		player.disable_hitbox()
		_hit_active = false


func process_physics(delta: float) -> StringName:
	_timer += delta

	if _timer < 0.2:
		player.velocity.x = player.global_basis.z.x * -forward_movement
		player.velocity.z = player.global_basis.z.z * -forward_movement
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)

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
			return &"Attack3"
		else:
			_buffered_next = &"Attack3"

	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"

	return &""
