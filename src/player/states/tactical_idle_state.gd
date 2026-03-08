extends State

## FF7R-style tactical menu: Category → Ability → Target.
## Player is FROZEN. Game slows to 10%.
## Phase 1: Pick category (Abilities / Magic / Items)
## Phase 2: Pick ability from that category
## Phase 3: Pick target, then execute

enum Phase { CATEGORY_SELECT, ABILITY_SELECT, TARGET_SELECT }
enum Category { ABILITIES, MAGIC, ITEMS }

var _phase: Phase = Phase.CATEGORY_SELECT
var _category_index: int = 0
var _current_category: Category = Category.ABILITIES
var _selected_slot: int = 0

## Target selection
var _selected_ability: AbilityData = null
var _target_candidates: Array[Node3D] = []
var _target_index: int = 0


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.CATEGORY_SELECT
	_category_index = 0
	_current_category = Category.ABILITIES
	_selected_slot = 0
	_selected_ability = null
	_target_candidates.clear()
	_target_index = 0

	player.velocity = Vector3.ZERO

	GameManager.enter_tactical_mode()
	Events.tactical_mode_entered.emit()
	Events.tactical_phase_changed.emit(Phase.CATEGORY_SELECT)
	Events.tactical_slot_changed.emit(0)

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Entered — Category Select")


func exit() -> void:
	if _phase == Phase.TARGET_SELECT:
		Events.lock_on_target_lost.emit()
		Events.ui_menu_closed.emit(&"target_selection")
	_phase = Phase.CATEGORY_SELECT
	_selected_ability = null
	_target_candidates.clear()

	GameManager.exit_tactical_mode()
	Events.tactical_mode_exited.emit()

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Exited tactical mode")


func process_physics(_delta: float) -> StringName:
	player.velocity = Vector3.ZERO
	return &""


func process_input(event: InputEvent) -> StringName:
	match _phase:
		Phase.CATEGORY_SELECT:
			return _process_category_input(event)
		Phase.ABILITY_SELECT:
			return _process_ability_input(event)
		Phase.TARGET_SELECT:
			return _process_target_input(event)
	return &""


# ── Phase 1: Category Selection ──────────────────────────────

func _process_category_input(event: InputEvent) -> StringName:
	# Close menu
	if event.is_action_pressed(&"tactical_mode") or event.is_action_pressed(&"pause"):
		return _exit_to_idle()
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		return _exit_to_idle()

	# Navigate categories (up/down)
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_category_index = wrapi(_category_index - 1, 0, 3)
		Events.tactical_slot_changed.emit(_category_index)
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_category_index = wrapi(_category_index + 1, 0, 3)
		Events.tactical_slot_changed.emit(_category_index)

	# Confirm category → ability phase
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_current_category = _category_index as Category
		_selected_slot = 0
		_phase = Phase.ABILITY_SELECT
		Events.tactical_category_changed.emit(_category_index)
		Events.tactical_phase_changed.emit(Phase.ABILITY_SELECT)
		Events.tactical_slot_changed.emit(0)

		if DebugFlags.DEBUG_COMBAT:
			var names := ["ABILITIES", "MAGIC", "ITEMS"]
			print("TacticalIdle: Selected category %s" % names[_category_index])

	return &""


# ── Phase 2: Ability Selection ────────────────────────────────

func _process_ability_input(event: InputEvent) -> StringName:
	# Close menu entirely
	if event.is_action_pressed(&"tactical_mode") or event.is_action_pressed(&"pause"):
		return _exit_to_idle()

	# Back to categories
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		_phase = Phase.CATEGORY_SELECT
		Events.tactical_phase_changed.emit(Phase.CATEGORY_SELECT)
		Events.tactical_slot_changed.emit(_category_index)
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Back to categories")
		return &""

	# Navigate abilities (up/down)
	var ability_count: int = player.ability_system.equipped_abilities.size()
	if ability_count > 0:
		if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
			_selected_slot = wrapi(_selected_slot - 1, 0, ability_count)
			Events.tactical_slot_changed.emit(_selected_slot)
		elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
			_selected_slot = wrapi(_selected_slot + 1, 0, ability_count)
			Events.tactical_slot_changed.emit(_selected_slot)

	# Confirm ability → target phase
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_confirm_ability()

	return &""


# ── Phase 3: Target Selection ────────────────────────────────

func _process_target_input(event: InputEvent) -> StringName:
	# Close menu entirely
	if event.is_action_pressed(&"tactical_mode") or event.is_action_pressed(&"pause"):
		return _exit_to_idle()

	# Back to abilities
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		_cancel_target_selection()
		return &""

	# Cycle targets (left/right)
	if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left") \
			or event.is_action_pressed(&"target_switch_left"):
		_cycle_target(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right") \
			or event.is_action_pressed(&"target_switch_right"):
		_cycle_target(1)

	# Confirm target → execute
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_confirm_target()

	return &""


# ── Helpers ───────────────────────────────────────────────────

func _exit_to_idle() -> StringName:
	if player.is_locked_on:
		return &"LockOnIdle"
	return &"Idle"


func _confirm_ability() -> void:
	if _current_category == Category.ITEMS:
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Items not yet available")
		return

	var ability: AbilityData = player.ability_system.get_equipped_ability(_selected_slot)
	if ability == null:
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: No ability in slot %d" % _selected_slot)
		return

	if not player.ability_system.can_use_ability(ability):
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Cannot use %s - %s" % [
				ability.display_name, player.ability_system.get_fail_reason(ability)])
		return

	_selected_ability = ability
	_build_target_list()

	if _target_candidates.is_empty():
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: No valid targets for %s" % ability.display_name)
		return

	_phase = Phase.TARGET_SELECT
	_target_index = 0

	if _is_offensive_ability(ability):
		_target_index = _find_nearest_enemy_index()

	_highlight_current_target()
	Events.tactical_phase_changed.emit(Phase.TARGET_SELECT)
	Events.tactical_target_info.emit(ability.display_name, _get_target_names(), _target_index)
	Events.ui_menu_opened.emit(&"target_selection")

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Selecting target for %s (%d candidates)" % [
			ability.display_name, _target_candidates.size()])


func _build_target_list() -> void:
	_target_candidates.clear()

	if _selected_ability == null:
		return

	if _is_offensive_ability(_selected_ability):
		var enemies := get_tree().get_nodes_in_group(&"enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node3D:
				if "_is_dead" in enemy and enemy._is_dead:
					continue
				_target_candidates.append(enemy)
	else:
		_target_candidates.append(player)
		if player.party_system and player.party_system.has_method("get_companion"):
			var companion: Node3D = player.party_system.get_companion()
			if companion and is_instance_valid(companion):
				_target_candidates.append(companion)


func _is_offensive_ability(ability: AbilityData) -> bool:
	return ability.ability_type in [
		AbilityData.AbilityType.MELEE,
		AbilityData.AbilityType.PROJECTILE,
		AbilityData.AbilityType.AOE,
	]


func _find_nearest_enemy_index() -> int:
	var best_idx := 0
	var best_dist := INF
	for i in _target_candidates.size():
		var dist := player.global_position.distance_squared_to(_target_candidates[i].global_position)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _cycle_target(direction: int) -> void:
	if _target_candidates.is_empty():
		return
	_target_index = wrapi(_target_index + direction, 0, _target_candidates.size())
	_highlight_current_target()
	Events.tactical_slot_changed.emit(_target_index)

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Target -> %s" % _target_candidates[_target_index].name)


func _get_target_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for candidate in _target_candidates:
		if candidate == player:
			names.append("Self")
		elif "display_name" in candidate:
			names.append(candidate.display_name)
		elif "member_data" in candidate and candidate.member_data \
				and "display_name" in candidate.member_data:
			names.append(candidate.member_data.display_name)
		else:
			names.append(candidate.name)
	return names


func _highlight_current_target() -> void:
	if _target_index < 0 or _target_index >= _target_candidates.size():
		return
	var target: Node3D = _target_candidates[_target_index]
	Events.lock_on_target_acquired.emit(target)

	var dir := (target.global_position - player.global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		player.basis = Basis.looking_at(dir.normalized())


func _cancel_target_selection() -> void:
	_selected_ability = null
	_target_candidates.clear()
	Events.lock_on_target_lost.emit()
	Events.ui_menu_closed.emit(&"target_selection")

	_phase = Phase.ABILITY_SELECT
	Events.tactical_phase_changed.emit(Phase.ABILITY_SELECT)
	Events.tactical_slot_changed.emit(_selected_slot)

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Canceled target → back to abilities")


func _confirm_target() -> void:
	if _selected_ability == null or _target_candidates.is_empty():
		return

	var target: Node3D = _target_candidates[_target_index]

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Executing %s on %s" % [_selected_ability.display_name, target.name])

	var success: bool = player.ability_system.request_ability_with_target(
		_selected_ability, target)

	if not success and DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Failed to execute %s" % _selected_ability.display_name)

	_selected_ability = null
	_target_candidates.clear()
	Events.ui_menu_closed.emit(&"target_selection")
