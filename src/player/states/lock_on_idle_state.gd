extends State


func enter(_msg: Dictionary = {}) -> void:
	player.play_animation(&"idle")
	if player.lock_on_target == null:
		var target: Node3D = player.lock_on_component.acquire_target()
		if target == null:
			return


func process_physics(delta: float) -> StringName:
	# Lost target — return to free movement
	if player.lock_on_target == null:
		return &"Idle"

	player.face_lock_target(delta)

	var input := InputManager.get_movement_vector()
	if input.length() > 0.1:
		return &"LockOnStrafe"

	if not player.is_on_floor():
		return &"Fall"

	return &""


## v3 routing (battle_system_v3_plan T1): see idle_state.gd.
func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"lock_on"):
		player.lock_on_component.release_target()
		return &"Idle"
	if event.is_action_pressed(&"target_switch_left"):
		player.lock_on_component.switch_target(-1.0)
	elif event.is_action_pressed(&"target_switch_right"):
		player.lock_on_component.switch_target(1.0)
	if event.is_action_pressed(&"attack"):
		return _route_attack_press()
	if event.is_action_released(&"attack"):
		return _route_attack_release()
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"DodgeReady"  # v8: hold to aim, fires on release
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
