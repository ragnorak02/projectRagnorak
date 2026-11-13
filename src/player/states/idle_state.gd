extends State

@export var deceleration: float = 30.0


func enter(_msg: Dictionary = {}) -> void:
	player.play_animation(&"idle")


func process_physics(delta: float) -> StringName:
	var input := InputManager.get_movement_vector()

	if not player.is_on_floor():
		return &"Fall"

	if input.length() > 0.1:
		return &"Run"

	# Decelerate to stop
	player.velocity.x = move_toward(player.velocity.x, 0.0, deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, deceleration * delta)

	return &""


## v3 routing (battle_system_v3_plan T1): every mode-dependent press goes
## through the player's routing helpers; this state never checks the mode.
func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		return _route_attack_press()
	if event.is_action_released(&"attack"):
		return _route_attack_release()
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"Dodge"
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
