extends State

## Rising part of a jump. Jump parameters (jump_force, double_jump_force,
## air_control, air_move_speed) live on the player so Fall and the future Carry
## state share one source of truth.


func enter(_msg: Dictionary = {}) -> void:
	# Air jump (from Fall via player.try_double_jump): velocity is already set.
	# Ground jump (Idle/Run/Land/LockOn/LedgeGrab exits): apply jump_force.
	if not player.consume_air_jump_pending():
		player.velocity.y = player.jump_force
	player.consume_jump_buffer()


func process_physics(delta: float) -> StringName:
	if player.velocity.y < 0:
		return &"Fall"

	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		var camera_basis := player.get_viewport().get_camera_3d().global_basis
		var forward := (-camera_basis.z).normalized()
		forward.y = 0.0
		forward = forward.normalized()
		var right := camera_basis.x
		right.y = 0.0
		right = right.normalized()
		var direction := (forward * -input.y + right * input.x).normalized()
		player.velocity.x = move_toward(player.velocity.x, direction.x * player.air_move_speed, player.air_control * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * player.air_move_speed, player.air_control * delta)

		# Face movement direction in air
		if direction.length() > 0.1:
			player.basis = player.basis.slerp(Basis.looking_at(direction), clampf(8.0 * delta, 0.0, 1.0))

	return &""


## v3 routing (battle_system_v3_plan T1/T2): see idle_state.gd.
func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		return _route_air_attack_press()
	if event.is_action_released(&"attack"):
		return _route_attack_release()
	if event.is_action_pressed(&"dodge"):
		var dodge_to := _route_air_dodge()
		if dodge_to != &"":
			return dodge_to
	# v3 T2: the Command Menu opens airborne (TacticalIdle returns to Fall).
	if player.is_command_press(event):
		return &"TacticalIdle"
	if player.is_unique_press(event):
		if player.stance:
			player.stance.toggle()
		get_viewport().set_input_as_handled()
		return &""
	# Double jump while rising (free roam only; player.has_double_jump /
	# _double_jump_used are checked inside try_double_jump). Stay in Jump.
	if player.is_jump_press(event) and player.try_double_jump():
		player.consume_air_jump_pending()
		return &""
	return &""


## Airborne attack: in battle the stance gets the press first; otherwise the
## v5 DD air combo (ComboComponent times the press; the resolved light/heavy
## starts an air-mode MeleeStrike that holds altitude). Once the air combo is
## spent this airtime the press is ignored. JumpAttack (dive) is only the
## fallback for a player without a ComboComponent.
func _route_air_attack_press() -> StringName:
	if player.in_battle and player.stance and player.stance.handle_attack_press():
		return &""
	if player.combo:
		return player.combo.on_attack_pressed()
	return &"JumpAttack"


## v5 DD: air dodge, once per airtime. Falls back to the ground Dodge only if
## the AirDodge node is missing (older player scenes / stubs).
func _route_air_dodge() -> StringName:
	if not player.dodge_ready:
		return &""
	if not player.state_machine.states.has(&"AirDodge"):
		return &"Dodge"
	if player.combo and not player.combo.air_dodge_available():
		return &""
	return &"AirDodge"


## Releases go to BOTH components (hold detection needs them).
func _route_attack_release() -> StringName:
	var consumed: bool = player.stance != null and player.stance.handle_attack_release()
	var next: StringName = player.combo.on_attack_released() if player.combo else &""
	return &"" if consumed else next
