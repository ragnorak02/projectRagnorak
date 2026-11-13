extends State

## FF7R-style tactical menu: Category → Ability → Target.
## Player is FROZEN. Game slows to 5% (GameManager.TACTICAL_TIME_SCALE, v3).
## v3: opens from the ground AND airborne (Jump/Fall/Land); closing while still
## airborne returns to Fall.
## Phase 1: Pick category (Abilities / Magic / Items)
## Phase 2: Pick ability from that category
## Phase 3: Pick target, then execute
## v4 X: offensive commands ALWAYS open the target step (never cast straight from
## the list). Rows = living enemies nearest-first, then a final "Fire Forward"
## row (camera-forward aim, untargeted cast). With no enemies only "Fire Forward"
## is listed, pre-selected, so the player still confirms. A confirms the row,
## Y/E (interact) fires forward from any row, B/Esc backs out one layer.
## Self/ally spells keep their ally list (no Fire Forward row).
## v5 BB1 (user range rule): rows = living enemies within the active member's
## MAX ability range (AbilitySystem.get_max_range()), nearest-first. Rows beyond
## the SELECTED ability's range are darkened ("Out of range"): they can be
## highlighted but A refuses with an "out_of_range" toast; Y Fire Forward works.
## v5 BB6: opened airborne -> the aerial list (aerial_only abilities first,
## ground_only ones greyed "Grounded only"); grounded hides aerial_only ones.
## Visible rows map to ability slots via _menu_slots (AbilitySystem.get_menu_slots).

const FIRE_FORWARD_LABEL := "Fire Forward"

enum Phase { CATEGORY_SELECT, ABILITY_SELECT, TARGET_SELECT }
enum Category { ABILITIES, MAGIC, ITEMS }

var _phase: Phase = Phase.CATEGORY_SELECT
var _category_index: int = 0
var _current_category: Category = Category.ABILITIES
var _selected_slot: int = 0
## v5 BB6: visible ability rows -> indices into ability_system.equipped_abilities.
var _menu_slots: Array[int] = []

## Target selection
var _selected_ability: AbilityData = null
var _target_candidates: Array[Node3D] = []
var _target_index: int = 0
## v4 X: true when the target list ends with the "Fire Forward" row, whose row
## index is _target_candidates.size() (offensive commands only).
var _has_forward_row: bool = false

## Open-press guard: the A press that opens the Command Menu in battle is also
## ui_accept, so confirm is ignored until at least one physics frame has passed
## since enter() AND neither ui_accept nor tactical_mode is still held (i.e. the
## opening press has been released). Armed in process_physics().
var _confirm_armed: bool = false

## v3 T2: true when the menu opened in the air (Jump/Fall/Land).
var _opened_airborne: bool = false

## v5 BB2: AA's MenuNav — one stick push = one step, hold = steady repeat
## (unscaled time, so the 0.05 tactical time scale never changes the feel).
## D-pad / keys stay one press = one step. Raw left-stick motion is swallowed
## so it never reaches is_action_pressed navigation.
var _nav := MenuNav.new(
	[&"move_up", &"ui_up"], [&"move_down", &"ui_down"],
	[&"move_left", &"ui_left", &"target_switch_left"],
	[&"move_right", &"ui_right", &"target_switch_right"])


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.CATEGORY_SELECT
	_category_index = 0
	_current_category = Category.ABILITIES
	_selected_slot = 0
	_selected_ability = null
	_target_candidates.clear()
	_target_index = 0
	_has_forward_row = false
	_confirm_armed = false
	_opened_airborne = not player.is_on_floor()
	_set_menu_context(_opened_airborne, null)
	_rebuild_menu_slots()
	_nav.reset()
	_nav.horizontal = false

	player.velocity = Vector3.ZERO
	# A light/heavy hold pending when the menu opened must not start a heavy
	# strike from inside the menu.
	var combo: Node = player.get(&"combo")  # null on hand-built stub players
	if combo:
		combo.reset(&"manual")

	GameManager.enter_tactical_mode()
	Events.tactical_mode_entered.emit()
	Events.tactical_phase_changed.emit(Phase.CATEGORY_SELECT)
	Events.tactical_slot_changed.emit(0)

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Entered — Category Select")


func exit() -> void:
	if _phase == Phase.TARGET_SELECT:
		Events.ui_menu_closed.emit(&"target_selection")
		_emit_reach(null, true)
		_restore_lock_on()
	_phase = Phase.CATEGORY_SELECT
	_selected_ability = null
	_target_candidates.clear()
	_has_forward_row = false
	_set_menu_context(false, null)

	GameManager.exit_tactical_mode()
	Events.tactical_mode_exited.emit()

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Exited tactical mode")


func process_physics(_delta: float) -> StringName:
	player.velocity = Vector3.ZERO
	if not _confirm_armed and not Input.is_action_pressed(&"ui_accept") \
			and not Input.is_action_pressed(&"tactical_mode"):
		_confirm_armed = true
	return &""


## v5 BB2: stick steps + held repeats (MenuNav, unscaled time), every frame.
func process_frame(_delta: float) -> StringName:
	var step: Vector2i = _nav.poll()
	if step != Vector2i.ZERO:
		_apply_nav_step(step)
	return &""


func process_input(event: InputEvent) -> StringName:
	# v5 BB2: raw stick motion feeds MenuNav and is never a navigation press.
	# Only the LEFT stick is marked handled; right-stick (camera) events pass on.
	if _nav.consume_event(event):
		var m := event as InputEventJoypadMotion
		if m and (m.axis == JOY_AXIS_LEFT_X or m.axis == JOY_AXIS_LEFT_Y) and is_inside_tree():
			get_viewport().set_input_as_handled()
		return &""
	# The menu owns confirm/back/close/interact presses. Mark them handled so a
	# shared button (B = ui_cancel + dodge, A = ui_accept + command in battle,
	# Y = interact) never also reaches player._unhandled_input (interact) or a
	# dodge after the menu closes on this same event. Camera input is untouched.
	if _is_menu_owned_event(event) and is_inside_tree():
		get_viewport().set_input_as_handled()
	# D-pad / keys: one press = one step (MenuNav.event_step, no echo).
	var step: Vector2i = _nav.event_step(event)
	if step != Vector2i.ZERO:
		# Menus own the D-pad while open (D-pad Up/Down is also party_switch).
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		_apply_nav_step(step)
		return &""
	match _phase:
		Phase.CATEGORY_SELECT:
			return _process_category_input(event)
		Phase.ABILITY_SELECT:
			return _process_ability_input(event)
		Phase.TARGET_SELECT:
			return _process_target_input(event)
	return &""


## v5 BB2: one cursor step in the current phase. Category / ability lists are
## vertical (y); the target list cycles on both axes (left/up = previous,
## right/down = next), matching the vertical list + D-pad target switch.
func _apply_nav_step(step: Vector2i) -> void:
	match _phase:
		Phase.CATEGORY_SELECT:
			if step.y != 0:
				_category_index = wrapi(_category_index + step.y, 0, 3)
				Events.tactical_slot_changed.emit(_category_index)
		Phase.ABILITY_SELECT:
			if step.y != 0:
				_navigate_slot(step.y)
		Phase.TARGET_SELECT:
			var d: int = step.y if step.y != 0 else step.x
			if d != 0:
				_cycle_target(d)


## Phase change bookkeeping for MenuNav: the target list also steps on X.
func _set_phase(phase: Phase) -> void:
	_phase = phase
	_nav.horizontal = phase == Phase.TARGET_SELECT


func _is_menu_owned_event(event: InputEvent) -> bool:
	for action in [&"ui_accept", &"ui_cancel", &"tactical_mode", &"pause", &"interact",
			&"dodge", &"unique_ability"]:
		if event.is_action_pressed(action):
			return true
	return false


# ── Phase 1: Category Selection ──────────────────────────────

func _process_category_input(event: InputEvent) -> StringName:
	# Close menu (Start/Esc, keyboard Q, or B/back at top level)
	if _is_close_event(event):
		return _exit_to_idle()
	if _is_back_event(event):
		return _exit_to_idle()

	# (Navigation: process_input / process_frame via MenuNav.)

	# Confirm category → ability phase
	if _is_confirm_event(event):
		_current_category = _category_index as Category
		_selected_slot = 0
		_rebuild_menu_slots()
		_set_phase(Phase.ABILITY_SELECT)
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
	if _is_close_event(event):
		return _exit_to_idle()

	# Back to categories
	if _is_back_event(event):
		_set_phase(Phase.CATEGORY_SELECT)
		Events.tactical_phase_changed.emit(Phase.CATEGORY_SELECT)
		Events.tactical_slot_changed.emit(_category_index)
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Back to categories")
		return &""

	# (Navigation: process_input / process_frame via MenuNav.)

	# Confirm ability → target phase
	if _is_confirm_event(event):
		_confirm_ability()

	return &""


# ── Phase 3: Target Selection ────────────────────────────────

func _process_target_input(event: InputEvent) -> StringName:
	# Close menu entirely
	if _is_close_event(event):
		return _exit_to_idle()

	# Back to abilities
	if _is_back_event(event):
		_cancel_target_selection()
		return &""

	# Cycle targets: left/right (target switch) AND up/down — handled by
	# _apply_nav_step (MenuNav) before this function runs.

	# Fire Forward shortcut from any row: Y (pad) / E (keyboard) = interact.
	# Gated by the open-press guard like confirm. Offensive lists only.
	if _has_forward_row and _confirm_armed and event.is_action_pressed(&"interact"):
		_fire_forward()
		return &""

	# Confirm target → execute
	if _is_confirm_event(event):
		_confirm_target()

	return &""


## Ability list cursor (wrapping). Kept as its own helper (test_phase6 checks it).
## v5 BB6: wraps over the visible rows (_menu_slots), not every equipped slot.
func _navigate_slot(direction: int) -> void:
	var ability_count: int = _menu_slots.size()
	if ability_count <= 0:
		return
	_selected_slot = wrapi(_selected_slot + direction, 0, ability_count)
	Events.tactical_slot_changed.emit(_selected_slot)


## v5 BB6: rebuild the visible ability rows for the current altitude. Hand-built
## stub ability systems (tests) without get_menu_slots list every slot.
func _rebuild_menu_slots() -> void:
	_menu_slots.clear()
	var abil = player.ability_system
	if abil == null:
		return
	if abil.has_method(&"get_menu_slots"):
		_menu_slots = abil.get_menu_slots(_opened_airborne)
	else:
		for i in abil.equipped_abilities.size():
			_menu_slots.append(i)
	_selected_slot = clampi(_selected_slot, 0, maxi(_menu_slots.size() - 1, 0))


## The ability under the list cursor (null when the row is empty).
func _ability_at_cursor() -> AbilityData:
	if _selected_slot < 0 or _selected_slot >= _menu_slots.size():
		return null
	return player.ability_system.get_equipped_ability(_menu_slots[_selected_slot])


## v5: Command Menu context on the AbilitySystem (read by the HUD).
func _set_menu_context(airborne: bool, ability: AbilityData) -> void:
	var abil = player.ability_system if player else null
	if abil == null:
		return
	if "menu_airborne" in abil:
		abil.menu_airborne = airborne
	if "menu_ability" in abil:
		abil.menu_ability = ability


# ── Helpers ───────────────────────────────────────────────────

## Close the whole menu: pause (Start / Esc) from any phase, or keyboard Q.
## v3: `tactical_mode` is Q only; the key check keeps a future pad binding of it
## from ever closing the menu (on controller A = confirm).
func _is_close_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"pause"):
		return true
	return event is InputEventKey and event.is_action_pressed(&"tactical_mode")


## Back one level: ui_cancel (B / Esc). `dodge` is kept as a keyboard-only
## back (Shift). On controller B is both ui_cancel and dodge: one event, one
## back, and the press is marked handled so it never dodges.
func _is_back_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel"):
		return true
	return event is InputEventKey and event.is_action_pressed(&"dodge")


## Confirm: ui_accept only (A / Enter / Space), gated by the open-press guard.
## (v3: A is no longer `tactical_mode`, so the v2 pad-tactical_mode path is gone.)
func _is_confirm_event(event: InputEvent) -> bool:
	return _confirm_armed and event.is_action_pressed(&"ui_accept")


## Close: restore the real lock-on first (T6b), then pick the follow-up state.
## Airborne (opened in the air and still not on the floor) -> Fall.
func _exit_to_idle() -> StringName:
	if _phase == Phase.TARGET_SELECT:
		Events.ui_menu_closed.emit(&"target_selection")
		_emit_reach(null, true)
		_restore_lock_on()
		_set_phase(Phase.CATEGORY_SELECT)
	if _opened_airborne and not player.is_on_floor():
		return &"Fall"
	if player.is_locked_on:
		return &"LockOnIdle"
	return &"Idle"


## T6b: target-select highlighting re-uses Events.lock_on_target_acquired, which
## overwrites player.lock_on_target (and the camera/HUD target) with the
## highlighted candidate; leaving target select used to emit lock_on_target_lost,
## which cleared player.is_locked_on although the LockOnComponent still held its
## target. The component never changes during highlighting, so it is the truth:
## re-announce its target if it is still valid, otherwise announce the loss.
func _restore_lock_on() -> void:
	var comp: LockOnComponent = player.get(&"lock_on_component") as LockOnComponent
	var t = comp.current_target if comp else null
	# (A dead target is already released by the component via Events.enemy_died.)
	var in_range: bool = is_instance_valid(t) and t.is_inside_tree() \
			and player.global_position.distance_to(t.global_position) \
				<= comp.detection_range * comp.lose_range_multiplier
	if in_range:
		Events.lock_on_target_acquired.emit(t)
	else:
		Events.lock_on_target_lost.emit()


## Confirm in ABILITY_SELECT. Never fails silently (v2 G5/G7): every blocked
## path emits Events.ability_request_failed(reason, ability) for HUD feedback.
func _confirm_ability() -> void:
	if _current_category == Category.ITEMS:
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Items not yet available")
		Events.ability_request_failed.emit("unavailable", null)
		return

	var ability: AbilityData = _ability_at_cursor()
	if ability == null:
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: No ability in slot %d" % _selected_slot)
		Events.ability_request_failed.emit("empty_slot", null)
		return

	# v5 BB6: ground-only commands are greyed in the aerial list.
	if player.ability_system.has_method(&"get_air_block_reason"):
		var air_reason: String = player.ability_system.get_air_block_reason(ability, _opened_airborne)
		if air_reason != "":
			Events.ability_request_failed.emit(air_reason, ability)
			return

	if not player.ability_system.can_use_ability(ability):
		var reason: String = player.ability_system.get_fail_reason(ability)
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: Cannot use %s - %s" % [ability.display_name, reason])
		Events.ability_request_failed.emit(reason if reason != "" else "unavailable", ability)
		return

	_selected_ability = ability
	var offensive := _is_offensive_ability(ability)
	_has_forward_row = offensive
	_set_menu_context(_opened_airborne, ability)
	_build_target_list()

	if _target_candidates.is_empty() and not offensive:
		_selected_ability = null
		_set_menu_context(_opened_airborne, null)
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: No valid targets for %s" % ability.display_name)
		Events.ability_request_failed.emit("no_target", ability)
		return

	# v4 X: offensive commands always open the target step. Candidates are
	# nearest-first, so row 0 is the nearest enemy; with no enemies the only
	# row is Fire Forward (index 0), pre-selected, and still needs a confirm.
	_set_phase(Phase.TARGET_SELECT)
	_target_index = 0

	_highlight_current_target()
	Events.tactical_phase_changed.emit(Phase.TARGET_SELECT)
	Events.tactical_target_info.emit(ability.display_name, _get_target_names(), _target_index)
	Events.ui_menu_opened.emit(&"target_selection")

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Selecting target for %s (%d candidates%s)" % [
			ability.display_name, _target_candidates.size(),
			" + Fire Forward" if _has_forward_row else ""])


func _build_target_list() -> void:
	_target_candidates.clear()

	if _selected_ability == null:
		return

	var offensive := _is_offensive_ability(_selected_ability)
	if offensive and player.ability_system.has_method(&"get_enemy_candidates"):
		# v5 BB1: enemies within the member's max range, nearest-first.
		_target_candidates = player.ability_system.get_enemy_candidates()
	elif offensive:
		var enemies := get_tree().get_nodes_in_group(&"enemies")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node3D:
				if "_is_dead" in enemy and enemy._is_dead:
					continue
				if not enemy.is_inside_tree():
					continue
				_target_candidates.append(enemy)
		# v4 X: nearest-first (ties broken by instance id for determinism).
		var origin: Vector3 = player.global_position
		_target_candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			var da := origin.distance_squared_to(a.global_position)
			var db := origin.distance_squared_to(b.global_position)
			if is_equal_approx(da, db):
				return a.get_instance_id() < b.get_instance_id()
			return da < db)
	else:
		_target_candidates.append(player)
		if player.party_system and player.party_system.has_method("get_companion"):
			var companion: Node3D = player.party_system.get_companion()
			if companion and is_instance_valid(companion):
				_target_candidates.append(companion)


func _is_offensive_ability(ability: AbilityData) -> bool:
	if ability.has_method(&"is_offensive"):
		return ability.is_offensive()
	return ability.ability_type in [
		AbilityData.AbilityType.MELEE,
		AbilityData.AbilityType.PROJECTILE,
		AbilityData.AbilityType.AOE,
	]


## Rows in the target step: enemies/allies, plus Fire Forward when offensive.
func _target_row_count() -> int:
	return _target_candidates.size() + (1 if _has_forward_row else 0)


## v5 BB1: true when candidate row `index` is within the selected ability's
## range (always true for ally rows / the Fire Forward row).
func _is_row_in_range(index: int) -> bool:
	if _selected_ability == null or index < 0 or index >= _target_candidates.size():
		return true
	var t: Node3D = _target_candidates[index]
	if t == player or not t.is_in_group(&"enemies"):
		return true
	if player.ability_system.has_method(&"is_in_range"):
		return player.ability_system.is_in_range(_selected_ability, t)
	return true


## True while the highlighted row is the "Fire Forward" row.
func _is_forward_row_selected() -> bool:
	return _has_forward_row and _target_index == _target_candidates.size()


func _cycle_target(direction: int) -> void:
	var count := _target_row_count()
	if count <= 0:
		return
	_target_index = wrapi(_target_index + direction, 0, count)
	_highlight_current_target()
	Events.tactical_slot_changed.emit(_target_index)

	if DebugFlags.DEBUG_COMBAT:
		var label: String = FIRE_FORWARD_LABEL if _is_forward_row_selected() \
			else String(_target_candidates[_target_index].name)
		print("TacticalIdle: Target -> %s" % label)


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
	if _has_forward_row:
		names.append(FIRE_FORWARD_LABEL)
	return names


func _highlight_current_target() -> void:
	if _is_forward_row_selected():
		# Fire Forward row: clear the enemy highlight (reticle + target bar).
		# The real lock-on is re-announced by _restore_lock_on() when the step
		# closes (T6b); the LockOnComponent itself is never touched.
		Events.lock_on_target_lost.emit()
		_emit_reach(null, true)
		_face_camera_forward()
		return
	if _target_index < 0 or _target_index >= _target_candidates.size():
		return
	var target: Node3D = _target_candidates[_target_index]
	Events.lock_on_target_acquired.emit(target)
	_emit_reach(target, _is_row_in_range(_target_index))

	var dir := (target.global_position - player.global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		player.basis = Basis.looking_at(dir.normalized())


## v5 BB1: tell the reticle / target bar whether the highlight is reachable
## (dimmed when not). Uses Events.tactical_target_reach once Head adds it.
func _emit_reach(target: Node3D, in_range: bool) -> void:
	if Events.has_signal(&"tactical_target_reach"):
		Events.emit_signal(&"tactical_target_reach", target, in_range)


func _cancel_target_selection() -> void:
	_selected_ability = null
	_target_candidates.clear()
	_has_forward_row = false
	_emit_reach(null, true)
	_set_menu_context(_opened_airborne, null)
	_restore_lock_on()
	Events.ui_menu_closed.emit(&"target_selection")

	_set_phase(Phase.ABILITY_SELECT)
	Events.tactical_phase_changed.emit(Phase.ABILITY_SELECT)
	Events.tactical_slot_changed.emit(_selected_slot)

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Canceled target → back to abilities")


func _confirm_target() -> void:
	if _selected_ability == null or _target_row_count() == 0:
		return
	if _is_forward_row_selected():
		_fire_forward()
		return

	var target: Node3D = _target_candidates[_target_index]
	if not is_instance_valid(target) or not target.is_inside_tree() \
			or ("_is_dead" in target and target._is_dead):
		# The highlighted enemy died while the menu was open: rebuild in place.
		_refresh_target_list()
		return

	# v5 BB1: darkened rows can be highlighted but never confirmed.
	if not _is_row_in_range(_target_index):
		if DebugFlags.DEBUG_COMBAT:
			print("TacticalIdle: %s out of range for %s" % [target.name, _selected_ability.display_name])
		Events.ability_request_failed.emit("out_of_range", _selected_ability)
		return

	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Executing %s on %s" % [_selected_ability.display_name, target.name])

	# ATB/MP/cooldown are re-checked here (v4 X: check on confirm). On failure
	# request_ability_with_target already emitted ability_request_failed (HUD
	# toast) and the target step stays open. On success it force-transitions to
	# Ability synchronously; exit() above closed target selection and restored
	# the real lock-on (T6b) and time scale.
	var success: bool = player.ability_system.request_ability_with_target(
		_selected_ability, target)
	if not success and DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Failed to execute %s" % _selected_ability.display_name)


## v4 X: "Fire Forward" — untargeted cast along the camera's flat forward.
## Offensive lists only (Y/E shortcut from any row, or A on the last row).
func _fire_forward() -> void:
	if _selected_ability == null or not _has_forward_row:
		return
	var ability := _selected_ability
	if DebugFlags.DEBUG_COMBAT:
		print("TacticalIdle: Fire Forward — %s" % ability.display_name)
	# request_ability() re-checks ATB/MP/cooldown and emits ability_request_failed
	# on failure (the target step stays open). On success it force-transitions
	# to Ability synchronously (exit() restores lock-on + time scale), and
	# AbilityState.aim_forward() overrides any lock-on aim with camera forward.
	if not player.ability_system.request_ability(ability):
		return
	var cast_state: Node = player.state_machine.current_state
	if cast_state and cast_state.has_method(&"aim_forward"):
		cast_state.aim_forward()


## Turn the player to the camera's flat forward (reads the camera only).
func _face_camera_forward() -> void:
	if not player.is_inside_tree():
		return
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() > 0.1:
		player.basis = Basis.looking_at(fwd.normalized())


## Rebuild the target rows in place (e.g. the highlighted enemy died).
func _refresh_target_list() -> void:
	if _selected_ability == null:
		return
	_build_target_list()
	if _target_row_count() == 0:
		_cancel_target_selection()
		return
	_target_index = clampi(_target_index, 0, _target_row_count() - 1)
	_highlight_current_target()
	Events.tactical_target_info.emit(_selected_ability.display_name, _get_target_names(), _target_index)
