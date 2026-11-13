extends State

## Carrying a crate overhead (controls v2, Package I).
## Ground + air locomotion with walk/run (sprint) and jump/double jump, using the
## player's shared jump parameters. Attack, dodge, Command Menu and lock-on are
## blocked simply by not handling them here.
##
## Y (`interact`, v3; was B in v2) tap vs hold, measured in REAL time (Time.get_ticks_msec) so
## hit-stop / tactical time scale can't stretch it:
##   released < HOLD_MS -> put down (stays in Carry if there's no room)
##   held  >= HOLD_MS   -> ThrowAim (on the ground; in the air it waits to land)
## A tap in the air is ignored (no mid-air put-down).

const HOLD_MS: int = 250

@export var move_speed: float = 7.0
@export var acceleration: float = 20.0
@export var sprint_acceleration: float = 26.0
@export var deceleration: float = 30.0

var _press_ms: int = -1  # tick of the B press seen in THIS state, -1 = none

var _carry: Node = null


func initialize(p: CharacterBody3D) -> void:
	super.initialize(p)
	_carry = p.get_node_or_null("CarryComponent")


func enter(_msg: Dictionary = {}) -> void:
	# The pick-up press happened in Idle/Run, so it never starts a hold here.
	_press_ms = -1


func exit() -> void:
	_press_ms = -1
	player.set_sprinting(false)
	# Leaving Carry for anything but our own ThrowAim handoff (Flinch, Ability,
	# death...) must never leave a crate orphaned on the CarryAnchor.
	if _carry and not _carry.consume_handoff() and _carry.is_carrying:
		_carry.drop(&"forced")


func process_physics(delta: float) -> StringName:
	if _carry == null or not _carry.is_carrying:
		return &"Idle" if player.is_on_floor() else &"Fall"

	var input := InputManager.get_movement_vector()
	var direction := _camera_relative(input)
	var on_floor := player.is_on_floor()

	if on_floor:
		if player.has_buffered_jump():
			_ground_jump()
		var sprinting: bool = input.length() > 0.1 and player.wants_sprint()
		player.set_sprinting(sprinting)
		var speed: float = move_speed * (player.sprint_multiplier if sprinting else 1.0)
		if input.length() > 0.1:
			var accel: float = sprint_acceleration if sprinting else acceleration
			var target := direction * speed * input.length()
			player.velocity.x = move_toward(player.velocity.x, target.x, accel * delta)
			player.velocity.z = move_toward(player.velocity.z, target.z, accel * delta)
			player.play_animation(&"walk")
		else:
			player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, deceleration * delta)
			player.play_animation(&"idle")
	else:
		# Air control unchanged from Jump/Fall (no sprint in the air).
		player.set_sprinting(false)
		if input.length() > 0.1:
			player.velocity.x = move_toward(player.velocity.x, direction.x * player.air_move_speed, player.air_control * delta)
			player.velocity.z = move_toward(player.velocity.z, direction.z * player.air_move_speed, player.air_control * delta)

	if direction.length() > 0.1:
		player.basis = player.basis.slerp(Basis.looking_at(direction), clampf(10.0 * delta, 0.0, 1.0))

	return &""


func process_frame(_delta: float) -> StringName:
	if _press_ms < 0:
		return &""
	var held_ms := Time.get_ticks_msec() - _press_ms
	if not Input.is_action_pressed(&"interact"):
		# Release that never reached process_input (e.g. eaten elsewhere).
		return _on_release(held_ms)
	if held_ms >= HOLD_MS and player.is_on_floor() and _carry and _carry.is_carrying:
		_press_ms = -1
		_carry.mark_handoff()
		return &"ThrowAim"
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_press_ms = Time.get_ticks_msec()
		player.get_viewport().set_input_as_handled()
		return &""
	if event.is_action_released(&"interact") and _press_ms >= 0:
		player.get_viewport().set_input_as_handled()
		return _on_release(Time.get_ticks_msec() - _press_ms)
	# v3 routing: jump is free-roam only (carrying is free-roam only too; entering
	# battle drops the crate and process_physics returns to Idle/Fall).
	if player.is_jump_press(event):
		if player.is_on_floor():
			_ground_jump()
		elif player.try_double_jump():
			# Stay in Carry; velocity already set. Clear the flag JumpState uses.
			player.consume_air_jump_pending()
		else:
			player.buffer_jump()
		return &""
	# attack / dodge / tactical_mode / lock_on: blocked while carrying.
	return &""


func _on_release(held_ms: int) -> StringName:
	_press_ms = -1
	if held_ms < HOLD_MS and player.is_on_floor() and _carry and _carry.is_carrying:
		if _carry.put_down():
			return &"Idle"
	return &""


func _ground_jump() -> void:
	player.velocity.y = player.jump_force
	player.consume_jump_buffer()


func _camera_relative(input: Vector2) -> Vector3:
	if input.length() < 0.1:
		return Vector3.ZERO
	var cam := player.get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if cam:
		forward = -cam.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		right = cam.global_basis.x
		right.y = 0.0
		right = right.normalized()
	return (forward * -input.y + right * input.x).normalized()
