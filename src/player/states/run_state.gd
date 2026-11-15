extends State

@export var move_speed: float = 8.0
@export var acceleration: float = 20.0
## Extra acceleration while sprinting so the speed-up feels responsive.
@export var sprint_acceleration: float = 28.0


func enter(_msg: Dictionary = {}) -> void:
	player.play_animation(&"walk")


func exit() -> void:
	player.set_sprinting(false)


func process_physics(delta: float) -> StringName:
	var input := InputManager.get_movement_vector()

	if not player.is_on_floor():
		return &"Fall"

	if input.length() < 0.1:
		return &"Idle"

	var camera_basis := player.get_viewport().get_camera_3d().global_basis
	var forward := -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := (forward * -input.y + right * input.x).normalized()
	# Run / sprint (hold `sprint`): free locomotion only. Lock-on strafe, tactical
	# and air movement never read this. Multiplier lives on the player.
	# v3: no sprint in battle.
	var sprinting: bool = player.wants_sprint() and not player.in_battle
	player.set_sprinting(sprinting)
	var speed: float = move_speed * (player.sprint_multiplier if sprinting else 1.0)
	var accel: float = sprint_acceleration if sprinting else acceleration
	var target_velocity := direction * speed * input.length()

	player.velocity.x = move_toward(player.velocity.x, target_velocity.x, accel * delta)
	player.velocity.z = move_toward(player.velocity.z, target_velocity.z, accel * delta)

	if direction.length() > 0.1:
		player.basis = player.basis.slerp(Basis.looking_at(direction), clampf(10.0 * delta, 0.0, 1.0))

	return &""


## v3 routing (battle_system_v3_plan T1): see idle_state.gd.
func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		return _route_attack_press()
	if event.is_action_released(&"attack"):
		return _route_attack_release()
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"DodgeReady"  # v8: hold to aim, fires on release
	if event.is_action_pressed(&"lock_on"):
		return &"LockOnIdle"
	# Command Menu: tactical_mode (Q), A in battle, Y with no prompt in free roam.
	if player.is_command_press(event):
		return &"TacticalIdle"
	# Unique ability: Y / R in battle.
	if player.is_unique_press(event):
		if player.stance:
			player.stance.toggle()
		get_viewport().set_input_as_handled()
		return &""
	# Jump: A / Space in free roam only.
	if player.is_jump_press(event) and player.is_on_floor():
		return &"Jump"

	return &""


## Battle: the stance gets the press first (true = consumed, no melee).
func _route_attack_press() -> StringName:
	if player.in_battle and player.stance and player.stance.handle_attack_press():
		return &""
	return player.combo.on_attack_pressed() if player.combo else &"Attack1"


## Releases go to BOTH components (hold detection needs them).
func _route_attack_release() -> StringName:
	var consumed: bool = player.stance != null and player.stance.handle_attack_release()
	var next: StringName = player.combo.on_attack_released() if player.combo else &""
	return &"" if consumed else next
