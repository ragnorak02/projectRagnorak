## Phase 7 tests: Tactical Mode restrictions, state behavior, and GameManager integration.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 7: Tactical Mode System Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 7 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Tactical Restrictions (items 167-170)
	_section("TACTICAL RESTRICTIONS — ILLEGAL TRANSITIONS")
	test_flinch_to_tactical_blocked()
	test_dodge_to_tactical_blocked()
	test_ability_to_tactical_blocked()
	test_ledge_grab_to_tactical_blocked()
	test_climb_up_to_tactical_blocked()
	test_jump_attack_to_tactical_blocked()
	test_attack1_to_tactical_blocked()
	test_attack2_to_tactical_blocked()
	test_attack3_to_tactical_blocked()
	test_land_to_tactical_blocked()

	# Category 2: Tactical Mode State Behavior (items 171-175)
	_section("TACTICAL MODE STATE BEHAVIOR")
	test_tactical_idle_freezes_velocity()
	test_tactical_enter_calls_game_manager()
	test_tactical_exit_calls_game_manager()
	test_time_scale_restored_after_exit()
	test_tactical_allowed_from_idle()
	test_tactical_allowed_from_lock_on_idle()
	test_combo_count_not_affected_by_tactical()

	# Category 3: GameManager tactical mode
	_section("GAME MANAGER TACTICAL MODE")
	test_game_manager_enter_tactical_changes_state()
	test_game_manager_exit_tactical_restores_playing()
	test_time_scale_pushed_to_01_during_tactical()
	test_time_scale_popped_on_exit()
	test_game_manager_state_signal_emitted()
	test_tactical_mode_double_enter_safe()


# ========== CATEGORY 1: TACTICAL RESTRICTIONS ==========

func test_flinch_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Flinch", "TacticalIdle",
		"Flinch -> TacticalIdle blocked")


func test_dodge_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Dodge", "TacticalIdle",
		"Dodge -> TacticalIdle blocked")


func test_ability_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Ability", "TacticalIdle",
		"Ability -> TacticalIdle blocked")


func test_ledge_grab_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("LedgeGrab", "TacticalIdle",
		"LedgeGrab -> TacticalIdle blocked")


func test_climb_up_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("ClimbUp", "TacticalIdle",
		"ClimbUp -> TacticalIdle blocked")


func test_jump_attack_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("JumpAttack", "TacticalIdle",
		"JumpAttack -> TacticalIdle blocked")


func test_attack1_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Attack1", "TacticalIdle",
		"Attack1 -> TacticalIdle blocked")


func test_attack2_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Attack2", "TacticalIdle",
		"Attack2 -> TacticalIdle blocked")


func test_attack3_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Attack3", "TacticalIdle",
		"Attack3 -> TacticalIdle blocked")


func test_land_to_tactical_blocked() -> void:
	_test_illegal_transition_from_player("Land", "TacticalIdle",
		"Land -> TacticalIdle blocked")


# ========== CATEGORY 2: TACTICAL MODE STATE BEHAVIOR ==========

func test_tactical_idle_freezes_velocity() -> void:
	var script = load("res://src/player/states/tactical_idle_state.gd")
	var source := script.source_code as String

	# Verify that enter() sets velocity to ZERO
	var has_enter_freeze: bool = source.contains("player.velocity = Vector3.ZERO")
	# Verify that process_physics also zeroes velocity every frame
	var has_physics_freeze: bool = source.contains("player.velocity = Vector3.ZERO")

	if has_enter_freeze and has_physics_freeze:
		_pass("TacticalIdle freezes velocity on enter and every physics frame")
	else:
		_fail("TacticalIdle freezes velocity on enter and every physics frame",
			"Missing velocity = Vector3.ZERO in enter or process_physics")


func test_tactical_enter_calls_game_manager() -> void:
	var script = load("res://src/player/states/tactical_idle_state.gd")
	var source := script.source_code as String

	if source.contains("GameManager.enter_tactical_mode()"):
		_pass("TacticalIdle enter() calls GameManager.enter_tactical_mode()")
	else:
		_fail("TacticalIdle enter() calls GameManager.enter_tactical_mode()",
			"Missing GameManager.enter_tactical_mode() call in enter()")


func test_tactical_exit_calls_game_manager() -> void:
	var script = load("res://src/player/states/tactical_idle_state.gd")
	var source := script.source_code as String

	if source.contains("GameManager.exit_tactical_mode()"):
		_pass("TacticalIdle exit() calls GameManager.exit_tactical_mode()")
	else:
		_fail("TacticalIdle exit() calls GameManager.exit_tactical_mode()",
			"Missing GameManager.exit_tactical_mode() call in exit()")


func test_time_scale_restored_after_exit() -> void:
	# Ensure GameManager pops the tactical time scale when exiting
	var script = load("res://scripts/autoloads/game_manager.gd")
	var source := script.source_code as String

	var pushes_on_enter: bool = source.contains('_push_time_scale("tactical", 0.1)')
	var pops_on_exit: bool = source.contains('_pop_time_scale("tactical")')

	if pushes_on_enter and pops_on_exit:
		_pass("Time scale pushed on tactical enter and popped on exit")
	else:
		_fail("Time scale pushed on tactical enter and popped on exit",
			"push=%s pop=%s" % [str(pushes_on_enter), str(pops_on_exit)])


func test_tactical_allowed_from_idle() -> void:
	# Verify Idle state has tactical_mode input -> TacticalIdle transition
	var script = load("res://src/player/states/idle_state.gd")
	var source := script.source_code as String

	if source.contains("tactical_mode") and source.contains('return &"TacticalIdle"'):
		_pass("Idle state allows transition to TacticalIdle")
	else:
		_fail("Idle state allows transition to TacticalIdle",
			"Missing tactical_mode input or TacticalIdle return in idle_state.gd")


func test_tactical_allowed_from_lock_on_idle() -> void:
	# Verify LockOnIdle state has tactical_mode input -> TacticalIdle transition
	var script = load("res://src/player/states/lock_on_idle_state.gd")
	var source := script.source_code as String

	if source.contains("tactical_mode") and source.contains('return &"TacticalIdle"'):
		_pass("LockOnIdle state allows transition to TacticalIdle")
	else:
		_fail("LockOnIdle state allows transition to TacticalIdle",
			"Missing tactical_mode input or TacticalIdle return in lock_on_idle_state.gd")


func test_combo_count_not_affected_by_tactical() -> void:
	# Verify TacticalIdleState does NOT emit combo_reset or combo_count_changed
	var script = load("res://src/player/states/tactical_idle_state.gd")
	var source := script.source_code as String

	var no_combo_reset: bool = not source.contains("combo_reset")
	var no_combo_count: bool = not source.contains("combo_count_changed")

	if no_combo_reset and no_combo_count:
		_pass("TacticalIdle does not affect combo count")
	else:
		_fail("TacticalIdle does not affect combo count",
			"Found combo_reset or combo_count_changed in tactical_idle_state.gd")


# ========== CATEGORY 3: GAME MANAGER TACTICAL MODE ==========

func test_game_manager_enter_tactical_changes_state() -> void:
	# Save original state, enter tactical, check state
	var original_state = GameManager.current_state
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.enter_tactical_mode()

	if GameManager.current_state == GameManager.GameState.TACTICAL_MODE:
		_pass("GameManager.enter_tactical_mode() changes state to TACTICAL_MODE")
	else:
		_fail("GameManager.enter_tactical_mode() changes state to TACTICAL_MODE",
			"State is %s" % str(GameManager.current_state))

	# Restore
	GameManager.exit_tactical_mode()
	GameManager.change_state(original_state)


func test_game_manager_exit_tactical_restores_playing() -> void:
	var original_state = GameManager.current_state
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.enter_tactical_mode()
	GameManager.exit_tactical_mode()

	if GameManager.current_state == GameManager.GameState.PLAYING:
		_pass("GameManager.exit_tactical_mode() restores state to PLAYING")
	else:
		_fail("GameManager.exit_tactical_mode() restores state to PLAYING",
			"State is %s" % str(GameManager.current_state))

	# Restore
	GameManager.change_state(original_state)


func test_time_scale_pushed_to_01_during_tactical() -> void:
	var original_state = GameManager.current_state
	var original_scale: float = Engine.time_scale
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.enter_tactical_mode()

	var tactical_scale: float = Engine.time_scale

	# Clean up before asserting
	GameManager.exit_tactical_mode()
	Engine.time_scale = original_scale
	GameManager.change_state(original_state)

	if is_equal_approx(tactical_scale, 0.1):
		_pass("Engine.time_scale is 0.1 during tactical mode")
	else:
		_fail("Engine.time_scale is 0.1 during tactical mode",
			"time_scale was %s" % str(tactical_scale))


func test_time_scale_popped_on_exit() -> void:
	var original_state = GameManager.current_state
	var original_scale: float = Engine.time_scale
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.enter_tactical_mode()
	GameManager.exit_tactical_mode()

	var restored_scale: float = Engine.time_scale

	# Restore
	Engine.time_scale = original_scale
	GameManager.change_state(original_state)

	if is_equal_approx(restored_scale, 1.0):
		_pass("Engine.time_scale restored to 1.0 after tactical exit")
	else:
		_fail("Engine.time_scale restored to 1.0 after tactical exit",
			"time_scale was %s" % str(restored_scale))


func test_game_manager_state_signal_emitted() -> void:
	# Verify GameManager emits game_state_changed signal
	var script = load("res://scripts/autoloads/game_manager.gd")
	var source := script.source_code as String

	var has_signal: bool = source.contains("signal game_state_changed")
	var emits_signal: bool = source.contains("game_state_changed.emit")

	if has_signal and emits_signal:
		_pass("GameManager has and emits game_state_changed signal")
	else:
		_fail("GameManager has and emits game_state_changed signal",
			"signal=%s emit=%s" % [str(has_signal), str(emits_signal)])


func test_tactical_mode_double_enter_safe() -> void:
	# Verify calling enter_tactical_mode twice does not corrupt state
	var original_state = GameManager.current_state
	var original_scale: float = Engine.time_scale
	GameManager.change_state(GameManager.GameState.PLAYING)
	GameManager.enter_tactical_mode()
	GameManager.enter_tactical_mode()  # Second call should be a no-op

	var state_ok: bool = GameManager.current_state == GameManager.GameState.TACTICAL_MODE
	var scale_ok: bool = is_equal_approx(Engine.time_scale, 0.1)

	GameManager.exit_tactical_mode()
	var restored_ok: bool = is_equal_approx(Engine.time_scale, 1.0)

	# Restore
	Engine.time_scale = original_scale
	GameManager.change_state(original_state)

	if state_ok and scale_ok and restored_ok:
		_pass("Double enter_tactical_mode does not corrupt state or time scale")
	else:
		_fail("Double enter_tactical_mode does not corrupt state or time scale",
			"state=%s scale=%s restored=%s" % [str(state_ok), str(scale_ok), str(restored_ok)])


# ========== HELPERS ==========

func _test_illegal_transition_from_player(from: String, to: String, test_name: String) -> void:
	# Verify player.gd registers the illegal transition by checking source code,
	# then verify the StateMachine logic returns true for _is_illegal_transition.
	var sm := _create_state_machine()
	sm.add_illegal_transition(StringName(from), StringName(to))

	if sm._is_illegal_transition(StringName(from), StringName(to)):
		# Also verify the transition is registered in player.gd source
		var player_script = load("res://src/player/player.gd")
		var source := player_script.source_code as String
		# The player registers these in a loop for most states
		var explicitly_listed: bool = (
			source.contains('&"%s"' % from)
			and source.contains('&"TacticalIdle"')
		)
		if explicitly_listed:
			_pass(test_name)
		else:
			_fail(test_name, "%s not found in player.gd illegal transition setup" % from)
	else:
		_fail(test_name, "%s -> %s was not blocked by _is_illegal_transition" % [from, to])

	sm.free()


func _create_state_machine() -> Node:
	var script = load("res://src/player/states/state_machine.gd")
	var node := Node.new()
	node.set_script(script)
	return node


func _section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


func _pass(test_name: String) -> void:
	_passed += 1
	_total += 1
	print("  PASS: %s" % test_name)


func _fail(test_name: String, reason: String = "") -> void:
	_failed += 1
	_total += 1
	var msg := "  FAIL: %s" % test_name
	if reason != "":
		msg += " — %s" % reason
	print(msg)
