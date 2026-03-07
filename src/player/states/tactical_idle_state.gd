extends State

## State entered when tactical menu opens. Game slows to 10%.
## Player is FROZEN — no movement allowed.
## Player navigates an ATB command menu (FF7R style).
## Execution is blocked without sufficient ATB/MP.
## Menu can be opened with zero ATB for observation.

var _selected_slot: int = 0

enum Category { ABILITIES, MAGIC, ITEMS }
var _current_category: Category = Category.ABILITIES


func enter(_msg: Dictionary = {}) -> void:
	_selected_slot = 0
	_current_category = Category.ABILITIES

	# Freeze player in place
	player.velocity = Vector3.ZERO

	GameManager.enter_tactical_mode()
	Events.tactical_mode_entered.emit()

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Entered tactical mode")
		_print_available_abilities()


func exit() -> void:
	GameManager.exit_tactical_mode()
	Events.tactical_mode_exited.emit()

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Exited tactical mode")


func process_physics(_delta: float) -> StringName:
	# Player is completely frozen — zero all velocity every frame
	player.velocity = Vector3.ZERO
	return &""


func process_input(event: InputEvent) -> StringName:
	# Close menu
	if event.is_action_pressed(&"tactical_mode") or event.is_action_pressed(&"pause"):
		if player.is_locked_on:
			return &"LockOnIdle"
		return &"Idle"

	# Cancel (dodge button / B button)
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		if player.is_locked_on:
			return &"LockOnIdle"
		return &"Idle"

	# Category switch (LB/RB or left/right)
	if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		_switch_category(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		_switch_category(1)

	# Navigate ability slots (up/down)
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_navigate_slot(-1)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_navigate_slot(1)

	# Confirm selection (attack button / X on controller)
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_execute_selected()

	return &""


func _switch_category(direction: int) -> void:
	var cat_int := wrapi(int(_current_category) + direction, 0, 3)
	_current_category = cat_int as Category
	_selected_slot = 0

	# Emit signals so the tactical menu UI can update
	Events.tactical_mode_exited.emit()
	Events.tactical_mode_entered.emit()

	if DebugFlags.DEBUG_COMBAT:
		var cat_names := ["ABILITIES", "MAGIC", "ITEMS"]
		print("TacticalIdle: Switched to %s" % cat_names[cat_int])


func _navigate_slot(direction: int) -> void:
	var ability_count: int = player.ability_system.equipped_abilities.size()
	if ability_count == 0:
		return

	_selected_slot = wrapi(_selected_slot + direction, 0, ability_count)

	if DebugFlags.DEBUG_COMBAT:
		var ability = player.ability_system.get_equipped_ability(_selected_slot)
		if ability:
			print("TacticalIdle: Selected slot %d - %s" % [_selected_slot, ability.display_name])


func _execute_selected() -> void:
	if _current_category == Category.ITEMS:
		# Items not yet implemented
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Items not yet available")
		return

	var ability = player.ability_system.get_equipped_ability(_selected_slot)
	if ability == null:
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: No ability in slot %d" % _selected_slot)
		return

	# AbilitySystem handles validation and emits failure signals if needed
	var success: bool = player.ability_system.request_ability(ability)

	if DebugFlags.DEBUG_COMBAT:
		if success:
			print("TacticalIdle: Executing %s" % ability.display_name)
		else:
			print("TacticalIdle: Cannot execute %s - %s" % [
				ability.display_name, player.ability_system.get_fail_reason(ability)])


func _print_available_abilities() -> void:
	for i in player.ability_system.equipped_abilities.size():
		var ability = player.ability_system.equipped_abilities[i]
		if ability:
			var usable: bool = player.ability_system.can_use_ability(ability)
			var reason: String = "" if usable else (" [" + player.ability_system.get_fail_reason(ability) + "]")
			print("  [%d] %s - MP: %.0f, ATB: %.0f%s" % [
				i, ability.display_name, ability.mp_cost, ability.atb_cost, reason])
