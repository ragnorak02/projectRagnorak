## Battle System v3 tests (Free Roam / Battle modes, light-heavy combos,
## stagger, Amaro's Arcane Stance, airborne Command Menu, tactical 0.05).
## Spec: docs/plans/battle_system_v3_plan.md -> "Approved Design".
## Published APIs used:
##  - Q: player.in_battle, player.battle_mode (BattleModeComponent: in_battle,
##    changed, force_check(credit_ms), force_exit(), get_exit_time_remaining()),
##    player.is_command_press / is_jump_press / is_interact_press / is_unique_press,
##    player.request_transition, player.get_member_data, player.combo, player.stance,
##    StateMachine/MeleeStrike (kind, step), PartyMemberData.unique_ability_id,
##    Events.battle_mode_changed / combo_step / combo_finisher / stance_changed /
##    enemy_staggered.
##  - R: ComboComponent (HOLD_THRESHOLD_MS, on_attack_pressed/released,
##    current_string, reset), EnemyBase stagger_value / stagger_max /
##    is_staggered() / stagger_damage_multiplier / add_stagger(), AIState.STAGGERED.
##  - S: StanceComponent toggle / is_active / current_stance / handle_attack_* /
##    exit_stance; arcane orbs + fireball projectiles under src/effects/.
##  - T: routing in states, airborne Command Menu, tactical time scale 0.05.
## Input is driven through real Input.parse_input_event (tap and hold), with
## real-time waits, so hold detection sees genuine press/release timing.
## Parts whose package hasn't landed fail with "not implemented" instead of crashing.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3

const PLAYER_SCENE := "res://src/player/player.tscn"
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const CRATE_SCENE := "res://src/interaction/carryable_crate.tscn"
const COMBO_SCRIPT := "res://src/combat/combo_component.gd"
const MELEE_SCRIPT := "res://src/player/states/melee_strike_state.gd"
const STANCE_SCRIPT := "res://src/combat/stance_component.gd"
## Q's stub scripts carry this marker until R / S replace their bodies.
const STUB_MARK := "STUB by Package Q"

const TACTICAL_SCALE := 0.05
const EXIT_DELAY_SEC := 3.0
## Finisher blast radii from the Approved Design table.
const RADIUS_LLL := 0.0
const RADIUS_ONE_H := 2.5   # L-L-H
const RADIUS_TWO_H := 3.5   # L-H-H / H-L-H
const RADIUS_HHH := 5.0
## Real-time input timings (HOLD_THRESHOLD_MS = 220).
const TAP_SEC := 0.06
const HOLD_SEC := 0.34
## Delay into the current strike before the next input (inside the combo window).
const LEAD_AFTER_L := 0.12
const LEAD_AFTER_H := 0.20
const WATCHDOG_SECONDS := 150.0

var _world: Node3D = null
var _player: Node = null
var _enemy: Node = null  # far, frozen "engaged" enemy that drives Battle Mode

var _battle_log: Array[bool] = []
var _combo_steps: Array = []       # [[step, kind], ...]
var _combo_finishers: Array = []   # [[kind, radius], ...]
var _stance_log: Array = []        # [[member_id, stance], ...]
var _staggered_log: Array = []
var _damage_log: Array = []        # [[enemy, amount], ...]
var _carry_log: Array = []         # [[obj, reason], ...]
var _spawned: Array[Node] = []     # nodes added to the tree while tracking


func _ready() -> void:
	print("=== Battle System v3 Tests (modes, combos, stagger, stance, command menu) ===")
	print("")
	# Watchdog (same pattern as test_controls): a hung test must not hang the runner.
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs (a test hung or aborted)" % WATCHDOG_SECONDS)
		_release_all_input()
		print("\n=== Battle Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
		get_tree().quit(1))
	await _run_tests()
	_release_all_input()
	print("\n=== Battle Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("CONTRACT — EVENTS / DATA / NODES")
	test_events_signals()
	test_member_data()

	_world = _make_world()
	add_child(_world)
	await get_tree().physics_frame
	_connect_logs()
	if not await _setup_player():
		_fail("Battle runtime tests", "skipped: player harness failed")
		return
	test_player_nodes()

	_section("BATTLE MODE — ENTER ON ENGAGE / EXIT AFTER 3s")
	await test_battle_mode_enter_exit()
	await test_battle_mode_exit_real_time()

	_section("ROUTING — FREE ROAM")
	await test_routing_free_roam()

	_section("ROUTING — BATTLE")
	await test_routing_battle()

	_section("COMMAND MENU — BATTLE A OPEN / CONFIRM / B ONE LAYER / TIME 0.05")
	await test_battle_command_menu()

	_section("COMMAND MENU — AIRBORNE")
	await test_airborne_command_menu()
	await test_land_buffered_command()

	_section("COMMAND MENU — LOCK-ON RESTORED AFTER B x3 (T6b)")
	await test_lock_restore_after_back_out()

	_section("CARRY — DROP ON ENTERING BATTLE / NO PICK-UP IN BATTLE")
	await test_carry_drop_on_battle()

	_section("MELEE — TAP / HOLD, DODGE CANCEL (R)")
	await test_tap_hold_and_dodge_cancel()

	_section("MELEE — FINISHER TABLE (R)")
	await test_finisher_table()

	_section("STAGGER (R)")
	await test_stagger()

	_section("ARCANE STANCE (S)")
	await test_arcane_stance()

	_teardown()
	await _frames(3)


# ========== CONTRACT ==========

func test_events_signals() -> void:
	for sig in [&"battle_mode_changed", &"combo_step", &"combo_finisher", &"stance_changed", &"enemy_staggered"]:
		_assert(Events.has_signal(sig), "Events.%s signal exists" % sig)


func test_member_data() -> void:
	var hero = load("res://resources/characters/hero.tres")
	var comp = load("res://resources/characters/companion.tres")
	_assert(hero != null and "unique_ability_id" in hero and hero.unique_ability_id == &"arcane_stance",
		"hero.tres unique_ability_id is &\"arcane_stance\"")
	_assert(comp != null and "unique_ability_id" in comp and comp.unique_ability_id == &"arcane_focus",
		"companion.tres unique_ability_id is &\"arcane_focus\" (v8 Taighe unique)")


func test_player_nodes() -> void:
	_assert(_player.battle_mode != null and _player.battle_mode is BattleModeComponent,
		"Player has BattleModeComponent")
	_assert(_player.combo != null and _player.combo is ComboComponent, "Player has ComboComponent")
	_assert(_player.stance != null and _player.stance is StanceComponent, "Player has StanceComponent")
	_assert(_player.state_machine.states.has(&"MeleeStrike"), "StateMachine has MeleeStrike")
	if _player.stance:
		_assert(_player.stance.ability_id == &"arcane_stance", "Amaro's StanceComponent resolves arcane_stance",
			"got '%s'" % _player.stance.ability_id)
	if _player.combo:
		_assert(_player.combo.HOLD_THRESHOLD_MS == 220, "ComboComponent.HOLD_THRESHOLD_MS is 220 (0.22s)")


# ========== BATTLE MODE ==========

func test_battle_mode_enter_exit() -> void:
	var bm: Node = _player.battle_mode
	await _to_free_roam()
	_assert(not _player.in_battle, "Free Roam with no engaged enemy")
	_battle_log.clear()

	_engage()
	_assert(_player.in_battle, "Battle Mode enters immediately when an enemy engages")
	_assert(_battle_log == [true], "Events.battle_mode_changed(true) emitted once on enter", str(_battle_log))

	_disengage()
	bm.force_check(0)
	_assert(_player.in_battle, "Still in battle right after the enemy disengages")
	bm.force_check(2800)
	_assert(_player.in_battle, "Still in battle 2.8s after disengage",
		"remaining=%.2f" % bm.get_exit_time_remaining())
	bm.force_check(300)
	_assert(not _player.in_battle, "Battle Mode exits 3.0s after the last enemy disengages")
	_assert(_battle_log == [true, false], "battle_mode_changed emitted [true, false]", str(_battle_log))

	# Re-engaging during the exit delay cancels it.
	_engage()
	_disengage()
	bm.force_check(0)
	bm.force_check(2000)
	_enemy.ai_state = EnemyBase.AIState.CHASE
	bm.force_check(0)
	_disengage()
	bm.force_check(0)
	bm.force_check(2000)
	_assert(_player.in_battle, "Re-engaging during the exit delay restarts the 3s countdown")
	await _to_free_roam()

	# A dead enemy counts as disengaged.
	_engage()
	_enemy.ai_state = EnemyBase.AIState.DEAD
	bm.force_check(0)
	bm.force_check(3100)
	_assert(not _player.in_battle, "A DEAD enemy is not engaged (battle ends)")
	_disengage()


func test_battle_mode_exit_real_time() -> void:
	await _to_free_roam()
	_engage()
	_disengage()
	var start := Time.get_ticks_msec()
	var left := await _wait_until(func(): return not _player.in_battle, 5.0)
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	_assert(left and elapsed >= EXIT_DELAY_SEC - 0.1 and elapsed <= EXIT_DELAY_SEC + 0.6,
		"Real-time exit happens ~3.0s after disengage (polled, real time)", "left=%s elapsed=%.2fs" % [left, elapsed])


# ========== ROUTING ==========

func test_routing_free_roam() -> void:
	await _to_free_roam()
	await _ground_idle()
	var target := _make_stub_interactable()
	_world.add_child(target)

	# Helper truth table (no prompt).
	_player._current_interactable = null
	_assert(_player.is_jump_press(_joy_press(JOY_A)) and not _player.is_command_press(_joy_press(JOY_A)),
		"Free roam: A is jump, not command")
	_assert(_player.is_command_press(_joy_press(JOY_Y)) and not _player.is_interact_press(_joy_press(JOY_Y)),
		"Free roam: Y with no prompt is command")
	_assert(_player.is_command_press(_key_press(KEY_Q)), "Free roam: Q is command")
	_assert(not _player.is_unique_press(_joy_press(JOY_Y)) and not _player.is_unique_press(_key_press(KEY_R)),
		"Free roam: Y / R are never the unique ability")
	_player._current_interactable = target
	_assert(_player.is_command_press(_joy_press(JOY_Y)) and not _player.is_interact_press(_joy_press(JOY_Y)),
		"Free roam (v8): Y with a prompt is command, not interact")
	_assert(_player.is_interact_press(_joy_press(JOY_A)) and not _player.is_jump_press(_joy_press(JOY_A)),
		"Free roam (v8): A with a prompt is interact, not jump")

	# Runtime: A jumps.
	_player._current_interactable = null
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"Jump" or (_player.velocity.y > 0.5 and not _player.is_on_floor()),
		"Free roam: A (real input) jumps", "state=%s vy=%.2f" % [_state(), _player.velocity.y])
	await _ground_idle()

	# Runtime (v8): A next to an NPC interacts (no jump, no menu).
	_player._current_interactable = target
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(target.calls == 1 and _state() != &"TacticalIdle" and _state() != &"Jump",
		"Free roam: A near an NPC interacts", "calls=%d state=%s" % [target.calls, _state()])

	# Runtime: Y with no prompt opens the Command Menu.
	_player._current_interactable = null
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(_state() == &"TacticalIdle", "Free roam: Y with no prompt opens the Command Menu", "state=%s" % _state())
	await _close_menu()

	# B dodges in free roam.
	await _ground_idle()
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.04)
	_assert(_state() == &"Dodge" or _saw_state_recently(&"Dodge"), "Free roam: B dodges", "state=%s" % _state())
	await _real_seconds(0.6)
	target.queue_free()


func test_routing_battle() -> void:
	await _ground_idle()
	_engage()
	_assert(_player.in_battle, "Battle routing harness: in battle")
	var target := _make_stub_interactable()
	_world.add_child(target)
	_player._current_interactable = target

	# Helper truth table.
	_assert(_player.is_command_press(_joy_press(JOY_A)) and not _player.is_jump_press(_joy_press(JOY_A)),
		"Battle: A is command, not jump")
	_assert(not _player.is_jump_press(_key_press(KEY_SPACE)), "Battle: Space is not jump")
	_assert(_player.is_unique_press(_joy_press(JOY_Y)) and not _player.is_interact_press(_joy_press(JOY_Y))
			and not _player.is_command_press(_joy_press(JOY_Y)),
		"Battle: Y is the unique ability (never interact / command), even with a prompt")
	_assert(_player.is_unique_press(_key_press(KEY_R)), "Battle: R is the unique ability")
	_assert(_player.is_unique_press(_key_press(KEY_E)) and not _player.is_interact_press(_key_press(KEY_E)),
		"Battle: E is the unique ability, not interact")
	_assert(_player.is_command_press(_key_press(KEY_Q)), "Battle: Q is command")

	# Runtime: A opens the menu and does not jump.
	await _ground_idle()
	var y0: float = _player.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"TacticalIdle", "Battle: A (real input) opens the Command Menu", "state=%s" % _state())
	_assert(_player.global_position.y < y0 + 0.05 and _player.velocity.y <= 0.01,
		"Battle: A does not jump", "dy=%.2f vy=%.2f" % [_player.global_position.y - y0, _player.velocity.y])
	await _close_menu()

	# Runtime: Space does not jump.
	await _ground_idle()
	await _tap(_key_press(KEY_SPACE), _key_release(KEY_SPACE))
	_assert(_state() != &"Jump" and _player.velocity.y <= 0.01, "Battle: Space does not jump (no jump in battle)",
		"state=%s vy=%.2f" % [_state(), _player.velocity.y])

	# Runtime: Y toggles the stance, never interacts.
	await _ground_idle()
	if _stub(STANCE_SCRIPT, "S"):
		_assert(target.calls == 0, "Battle: Y never interacts", "calls=%d" % target.calls)
	else:
		_stance_log.clear()
		await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
		_assert(_player.stance.is_active() and _player.stance.current_stance() == &"arcane_stance",
			"Battle: Y toggles Arcane Stance on", "stance='%s'" % _player.stance.current_stance())
		_assert(target.calls == 0 and _state() != &"TacticalIdle", "Battle: Y never interacts or opens the menu",
			"calls=%d state=%s" % [target.calls, _state()])
		await _tap(_key_press(KEY_R), _key_release(KEY_R))
		_assert(not _player.stance.is_active(), "Battle: R toggles the stance off")
		_assert(_stance_log.size() >= 2 and _stance_log[0][1] == &"arcane_stance" and _stance_log[-1][1] == &"",
			"Events.stance_changed emitted on enter (arcane_stance) and exit (&\"\")", str(_stance_log))

	# Sprint is ignored in battle.
	await _ground_idle()
	Input.action_press(&"move_up")
	Input.action_press(&"sprint")
	await _physics_frames(30)
	_assert(not _player.is_sprinting, "Battle: sprint (L3 / Ctrl) is ignored")
	Input.action_release(&"sprint")
	Input.action_release(&"move_up")
	await _physics_frames(10)

	# B dodges in battle too.
	await _ground_idle()
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.04)
	_assert(_state() == &"Dodge" or _saw_state_recently(&"Dodge"), "Battle: B dodges", "state=%s" % _state())
	await _real_seconds(0.6)

	_player._current_interactable = null
	target.queue_free()
	await _to_free_roam()


# ========== COMMAND MENU ==========

func test_battle_command_menu() -> void:
	var gm_const = GameManager.get_script().get_script_constant_map().get("TACTICAL_TIME_SCALE", -1.0)
	_assert(is_equal_approx(float(gm_const), TACTICAL_SCALE), "GameManager.TACTICAL_TIME_SCALE is 0.05",
		"got %s" % str(gm_const))
	await _ground_idle()
	_engage()
	# A opens; the same A press must not confirm the first category (open-press guard).
	Input.parse_input_event(_joy_press(JOY_A))
	await _frames(2)
	var tac: Node = _player.state_machine.current_state
	_assert(_state() == &"TacticalIdle", "Battle: A press opens the Command Menu", "state=%s" % _state())
	if _state() != &"TacticalIdle":
		Input.parse_input_event(_joy_release(JOY_A))
		await _to_free_roam()
		return
	_assert(is_equal_approx(Engine.time_scale, TACTICAL_SCALE),
		"Command Menu time scale is 0.05", "time_scale=%.3f" % Engine.time_scale)
	_assert(GameManager.current_state == GameManager.GameState.TACTICAL_MODE, "GameManager in TACTICAL_MODE")
	await _real_seconds(0.1)
	Input.parse_input_event(_joy_release(JOY_A))
	await _real_seconds(0.4)  # arm the guard (armed in process_physics)
	_assert(int(tac._phase) == 0, "The opening A press does not confirm a category", "phase=%d" % int(tac._phase))

	# A confirms inside the menu.
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == 1 and _state() == &"TacticalIdle", "A confirms the category (ABILITY_SELECT)",
		"phase=%d state=%s" % [int(tac._phase), _state()])
	# B backs out exactly one layer.
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(int(tac._phase) == 0 and _state() == &"TacticalIdle", "B backs out one layer (ABILITY -> CATEGORY)",
		"phase=%d state=%s" % [int(tac._phase), _state()])
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(_state() != &"TacticalIdle" and _state() != &"Dodge",
		"B at the top layer closes the menu (and does not dodge)", "state=%s" % _state())
	_assert(is_equal_approx(Engine.time_scale, 1.0), "Time scale restored to 1.0 after close",
		"time_scale=%.3f" % Engine.time_scale)
	await _to_free_roam()


func test_airborne_command_menu() -> void:
	# Free roam: falling, Y (no prompt) opens the menu mid-air.
	await _to_free_roam()
	_player._current_interactable = null
	_player.global_position = Vector3(0, 6, 0)
	_player.velocity = Vector3.ZERO
	_player.state_machine.force_transition(&"Fall")
	await _physics_frames(4)
	_assert(not _player.is_on_floor(), "Airborne harness: player is in the air")
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(_state() == &"TacticalIdle", "Free roam: Command Menu opens mid-air (Fall + Y)", "state=%s" % _state())
	if _state() == &"TacticalIdle":
		var y_open: float = _player.global_position.y
		await _real_seconds(0.4)
		_assert(_player.velocity.length() < 0.01 and absf(_player.global_position.y - y_open) < 0.05,
			"Player is frozen in place while the airborne menu is open",
			"v=%s dy=%.3f" % [_player.velocity, _player.global_position.y - y_open])
		_assert(is_equal_approx(Engine.time_scale, TACTICAL_SCALE), "Airborne menu time scale is 0.05",
			"time_scale=%.3f" % Engine.time_scale)
		await _close_menu()
		_assert(_state() == &"Fall", "Closing the airborne menu returns to Fall", "state=%s" % _state())
	await _ground_idle()

	# Free roam: during a Jump, Y opens the menu.
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	await _physics_frames(3)
	var in_jump := _state() == &"Jump"
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(in_jump and _state() == &"TacticalIdle", "Free roam: Command Menu opens from Jump",
		"was_jump=%s state=%s" % [in_jump, _state()])
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _ground_idle()

	# Battle: falling, A opens the menu mid-air.
	_engage()
	_player.global_position = Vector3(0, 6, 0)
	_player.velocity = Vector3.ZERO
	_player.state_machine.force_transition(&"Fall")
	await _physics_frames(4)
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"TacticalIdle", "Battle: Command Menu opens mid-air (Fall + A)", "state=%s" % _state())
	if _state() == &"TacticalIdle":
		await _close_menu()
		_assert(_state() == &"Fall", "Battle: closing the airborne menu returns to Fall", "state=%s" % _state())
	await _ground_idle()
	await _to_free_roam()


func test_land_buffered_command() -> void:
	# Land -> TacticalIdle stays illegal (test_phase7 contract); a command press
	# during the landing recovery is buffered and opens the menu when it ends.
	await _to_free_roam()
	await _ground_idle()
	_player._current_interactable = null
	_player.state_machine.force_transition(&"Land")
	await _frames(1)
	var was_land := _state() == &"Land"
	Input.parse_input_event(_joy_press(JOY_Y))
	await _frames(2)
	var not_instant := _state() != &"TacticalIdle"
	Input.parse_input_event(_joy_release(JOY_Y))
	var opened := await _wait_until(func(): return _state() == &"TacticalIdle", 1.0)
	_assert(was_land, "Land harness: in Land after force_transition", "state=%s" % _state())
	_assert(opened, "Command press during Land is buffered and opens the menu after the recovery",
		"state=%s" % _state())
	_assert(not_instant or not was_land, "Land never transitions straight to TacticalIdle (illegal; buffered)")
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _ground_idle()


func test_lock_restore_after_back_out() -> void:
	var near := await _spawn_dummy(Vector3(0, 0, -5))
	var far := await _spawn_dummy(Vector3(2.5, 0, -10))
	if near == null or far == null:
		_fail("Lock restore harness", "enemy.tscn failed to load")
		return
	near.ai_state = EnemyBase.AIState.CHASE
	far.ai_state = EnemyBase.AIState.CHASE
	await _ground_idle()
	_player.global_position = Vector3(0, 0.05, 0)
	_player.basis = Basis.IDENTITY
	_engage()
	await _physics_frames(2)
	# RT = lock-on (real input).
	await _tap(_joy_axis(5, 1.0), _joy_axis(5, 0.0))
	await _physics_frames(2)
	if not _player.is_locked_on:
		_fail("Lock restore: locked on before opening the menu", "lock-on not acquired (state=%s)" % _state())
		near.queue_free()
		far.queue_free()
		await _to_free_roam()
		return
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	# A opens (battle), A -> abilities, A -> target select.
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	await _real_seconds(0.3)
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	var tac: Node = _player.state_machine.current_state
	var in_target := _state() == &"TacticalIdle" and int(tac._phase) == 2
	_assert(in_target, "Lock restore: reached TARGET_SELECT with A, A, A",
		"state=%s phase=%s" % [_state(), str(tac._phase) if "_phase" in tac else "?"])
	# Switch to the farther enemy, then B x3 (target -> ability -> category -> close).
	await _tap(_joy_press(14), _joy_release(14))  # D-pad Right = target_switch_right
	for i in 3:
		await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	await _physics_frames(3)
	_assert(_state() == &"LockOnIdle" or _state() == &"LockOnStrafe",
		"Closing the menu with B x3 while locked on returns to LockOnIdle", "state=%s" % _state())
	_assert(_player.is_locked_on and is_instance_valid(_player.lock_on_target),
		"Lock-on is still held after B x3 (target still valid)",
		"locked=%s target=%s" % [_player.is_locked_on, _player.lock_on_target])
	# Unlock and clean up.
	if _player.is_locked_on:
		await _tap(_joy_axis(5, 1.0), _joy_axis(5, 0.0))
	near.queue_free()
	far.queue_free()
	await _physics_frames(2)
	await _to_free_roam()


# ========== CARRY ==========

func test_carry_drop_on_battle() -> void:
	var carry: Node = _player.get_node_or_null("CarryComponent")
	var crate_scene = load(CRATE_SCENE) as PackedScene
	if carry == null or crate_scene == null:
		_fail("Carry drop on battle", "CarryComponent or crate scene missing")
		return
	await _to_free_roam()
	await _ground_idle()
	var crate: Node = crate_scene.instantiate()
	_world.add_child(crate)
	crate.global_position = _player.global_position + Vector3(0, 0, -1.6)
	await _physics_frames(3)
	carry.request_pick_up(crate)
	await _physics_frames(2)
	_assert(carry.is_carrying, "Free roam: picked up a crate", "state=%s" % _state())
	_carry_log.clear()
	_engage()
	await _physics_frames(3)
	_assert(not carry.is_carrying, "Entering battle drops the carried crate")
	var forced := false
	for e in _carry_log:
		if e[0] == crate and StringName(e[1]) == &"forced":
			forced = true
	_assert(forced, "carry_ended(crate, &\"forced\") emitted on battle enter", str(_carry_log))
	_assert(_state() != &"Carry" and _state() != &"ThrowAim", "Player left Carry on battle enter", "state=%s" % _state())

	# Pick-up is blocked in battle: Y next to the crate is the unique ability.
	await _real_seconds(0.4)
	await _ground_idle()
	var area: Node = null
	for child in crate.get_children():
		if child is Area3D:
			area = child
	_player._current_interactable = area
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(not carry.is_carrying, "Battle: Y next to a crate does not pick it up", "state=%s" % _state())
	if _player.stance and _player.stance.is_active():
		_player.stance.exit_stance(&"manual")
	_player._current_interactable = null
	await _to_free_roam()
	if is_instance_valid(crate):
		crate.queue_free()
	await _physics_frames(2)


# ========== MELEE (R) ==========

func test_tap_hold_and_dodge_cancel() -> void:
	if _stub(COMBO_SCRIPT, "R") or _stub(MELEE_SCRIPT, "R"):
		return
	await _ground_idle()
	_engage()
	await _reset_combo()
	var mp0: float = _player.current_mp
	var atb0: float = _player.current_atb

	# Tap = light, fires on release.
	_combo_steps.clear()
	Input.parse_input_event(_joy_press(JOY_X))
	await _real_seconds(TAP_SEC)
	_assert(_combo_steps.is_empty(), "No strike yet while a tap is still held (< 0.22s)", str(_combo_steps))
	Input.parse_input_event(_joy_release(JOY_X))
	await _wait_until(func(): return not _combo_steps.is_empty(), 0.6)
	_assert(_combo_steps.size() == 1 and _combo_steps[0][1] == &"light", "Tap X = light strike (combo_step 1, light)",
		str(_combo_steps))
	_assert(_state() == &"MeleeStrike" and _player.state_machine.current_state.kind == &"light",
		"Light strike runs in MeleeStrike (kind light)", "state=%s" % _state())
	_assert(_player.combo.current_string() == "L", "Combo string is 'L'", "got '%s'" % _player.combo.current_string())

	# Dodge cancels a light strike and resets the string.
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.04)
	_assert(_state() == &"Dodge" or _saw_state_recently(&"Dodge"), "B cancels a light strike into Dodge",
		"state=%s" % _state())
	_assert(_player.combo.current_string() == "", "Dodge resets the combo string",
		"got '%s'" % _player.combo.current_string())
	await _reset_combo()

	# Hold = heavy, starts at the 0.22s threshold without waiting for release.
	_combo_steps.clear()
	var t0 := Time.get_ticks_msec()
	Input.parse_input_event(_joy_press(JOY_X))
	await _wait_until(func(): return not _combo_steps.is_empty(), 0.8)
	var started_ms := Time.get_ticks_msec() - t0
	var still_held := Input.is_action_pressed(&"attack")
	_assert(_combo_steps.size() == 1 and _combo_steps[0][1] == &"heavy" and still_held,
		"Hold X = heavy strike, started while still held", "steps=%s held=%s" % [_combo_steps, still_held])
	_assert(started_ms >= 200 and started_ms <= 400, "Heavy starts at ~0.22s of real hold time",
		"started after %dms" % started_ms)
	Input.parse_input_event(_joy_release(JOY_X))
	_assert(_state() == &"MeleeStrike" and _player.state_machine.current_state.kind == &"heavy",
		"Heavy strike runs in MeleeStrike (kind heavy)", "state=%s" % _state())
	await _reset_combo()

	_assert(is_equal_approx(_player.current_mp, mp0) and _player.current_atb >= atb0 - 0.01,
		"Basic attacks are unlimited (no MP / ATB spent)",
		"mp %.1f -> %.1f atb %.1f -> %.1f" % [mp0, _player.current_mp, atb0, _player.current_atb])
	await _to_free_roam()


func test_finisher_table() -> void:
	if _stub(COMBO_SCRIPT, "R") or _stub(MELEE_SCRIPT, "R"):
		return
	var dummy := await _spawn_dummy(Vector3(0, 0, -1.6))
	var side := await _spawn_dummy(Vector3(3.5, 0, -1.6))
	if dummy == null or side == null:
		_fail("Finisher table", "enemy.tscn failed to load")
		return
	_engage()
	var results := {}
	for seq in ["LLL", "LLH", "LHH", "HHH"]:
		results[seq] = await _run_string(seq, dummy, side)

	var exp_radius := {"LLL": RADIUS_LLL, "LLH": RADIUS_ONE_H, "LHH": RADIUS_TWO_H, "HHH": RADIUS_HHH}
	for seq in results:
		var r: Dictionary = results[seq]
		print("  INFO: %s steps=%s finisher=%s dmg=%.1f side_dmg=%.1f" % [seq, r.steps, r.finisher, r.dmg, r.side_dmg])
		_assert(r.ok, "%s: all 3 steps registered" % seq, "steps=%s string='%s'" % [r.steps, r.string])
		_assert(r.kinds == _kinds_for(seq), "%s: combo_step kinds match the string" % seq,
			"got %s" % str(r.kinds))
		_assert(r.finisher.size() == 2 and absf(float(r.finisher[1]) - exp_radius[seq]) < 0.05,
			"%s finisher blast radius is %.1fm" % [seq, exp_radius[seq]], "finisher=%s" % str(r.finisher))
	_assert(results.HHH.dmg > results.LLH.dmg and results.LLH.dmg > results.LLL.dmg,
		"Damage order: H-H-H > L-L-H > L-L-L",
		"HHH=%.1f LLH=%.1f LLL=%.1f" % [results.HHH.dmg, results.LLH.dmg, results.LLL.dmg])
	_assert(results.HHH.side_dmg > 0.0, "H-H-H blast (5m) hits a second enemy ~3.5m to the side",
		"side_dmg=%.1f" % results.HHH.side_dmg)
	_assert(results.LLH.side_dmg == 0.0 and results.LLL.side_dmg == 0.0,
		"L-L-H blast (2.5m) and L-L-L do not reach the enemy 3.5m away",
		"LLH=%.1f LLL=%.1f" % [results.LLH.side_dmg, results.LLL.side_dmg])
	_assert(results.HHH.side_hits == 1, "Blast damages each enemy in radius once",
		"side hits=%d" % results.HHH.side_hits)

	dummy.queue_free()
	side.queue_free()
	await _physics_frames(2)
	await _to_free_roam()


func test_stagger() -> void:
	var enemy := await _spawn_dummy(Vector3(-30, 0, -30), false)
	if enemy == null:
		_fail("Stagger", "enemy.tscn failed to load")
		return
	if not enemy.has_method("add_stagger") or not enemy.has_method("is_staggered") or not ("stagger_value" in enemy):
		_fail("EnemyBase stagger API (stagger_value / add_stagger / is_staggered)", "not implemented (Package R)")
		enemy.queue_free()
		return
	_assert(is_equal_approx(enemy.stagger_max, 100.0), "stagger_max defaults to 100", "got %.1f" % enemy.stagger_max)
	_assert(is_equal_approx(enemy.stagger_damage_multiplier, 1.6), "stagger_damage_multiplier is 1.6")
	_assert(not enemy.is_staggered() and enemy.stagger_value == 0.0, "Fresh enemy is not staggered")

	# Unstaggered damage is 1.0x.
	_damage_log.clear()
	var hp0: float = enemy.current_hp
	enemy.take_damage(10.0, null)
	_assert(is_equal_approx(hp0 - enemy.current_hp, 10.0), "Unstaggered take_damage(10) deals 10",
		"dealt %.2f" % (hp0 - enemy.current_hp))
	await _real_seconds(0.6)  # let HURT end

	_staggered_log.clear()
	enemy.add_stagger(60.0)
	_assert(not enemy.is_staggered() and is_equal_approx(enemy.stagger_value, 60.0), "Stagger builds below max",
		"value=%.1f" % enemy.stagger_value)
	enemy.add_stagger(50.0)
	_assert(enemy.is_staggered(), "Stagger at max -> STAGGERED")
	_assert(enemy.ai_state == EnemyBase.AIState.STAGGERED, "ai_state is STAGGERED")
	_assert(_staggered_log.has(enemy), "Events.enemy_staggered(enemy) emitted")

	hp0 = enemy.current_hp
	enemy.take_damage(10.0, null)
	_assert(is_equal_approx(hp0 - enemy.current_hp, 16.0), "Staggered take_damage(10) deals 16 (1.6x)",
		"dealt %.2f" % (hp0 - enemy.current_hp))
	_assert(enemy.is_staggered(), "A hit does not interrupt the stagger break")

	await _real_seconds(3.0)
	_assert(enemy.is_staggered(), "Still STAGGERED 3s into the 4s break")
	var recovered := await _wait_until(func(): return not enemy.is_staggered(), 2.5)
	_assert(recovered, "STAGGERED ends after ~4s")

	# Melee: heavy builds much more stagger than light (R5 / table).
	if not _stub(COMBO_SCRIPT, "R") and not _stub(MELEE_SCRIPT, "R"):
		var dummy := await _spawn_dummy(Vector3(0, 0, -1.6))
		dummy.stagger_max = 100000.0
		_engage()
		await _reset_combo()
		await _place_for_string(dummy, null)
		await _tap(_joy_press(JOY_X), _joy_release(JOY_X), TAP_SEC)
		await _wait_until(func(): return _state() != &"MeleeStrike", 1.5)
		var light_st: float = dummy.stagger_value
		await _reset_combo()
		dummy.stagger_value = 0.0
		await _place_for_string(dummy, null)
		await _tap(_joy_press(JOY_X), _joy_release(JOY_X), HOLD_SEC)
		await _wait_until(func(): return _state() != &"MeleeStrike", 2.0)
		var heavy_st: float = dummy.stagger_value
		_assert(light_st > 0.0, "A light strike builds stagger", "light=%.1f" % light_st)
		_assert(heavy_st > light_st * 1.5, "A heavy strike builds much more stagger than a light",
			"light=%.1f heavy=%.1f" % [light_st, heavy_st])
		dummy.queue_free()
		await _to_free_roam()
	enemy.queue_free()
	await _physics_frames(2)


# ========== ARCANE STANCE (S) ==========

func test_arcane_stance() -> void:
	if _stub(STANCE_SCRIPT, "S"):
		return
	var st: Node = _player.stance
	await _ground_idle()
	_engage()
	if st.is_active():
		st.exit_stance(&"manual")
	await _reset_combo()

	# Toggle on via the API.
	_stance_log.clear()
	_assert(st.toggle() == true and st.is_active(), "toggle() enters Arcane Stance and returns true")
	_assert(st.current_stance() == &"arcane_stance", "current_stance() is arcane_stance",
		"got '%s'" % st.current_stance())
	_assert(_stance_log.size() == 1 and _stance_log[0][1] == &"arcane_stance", "stance_changed emitted on enter",
		str(_stance_log))
	var mp0: float = _player.current_mp

	# Tap X: volley of 3 orbs, no melee.
	_combo_steps.clear()
	_track_spawns(true)
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), TAP_SEC)
	await _real_seconds(0.4)
	var orbs := _projectiles_spawned()
	_track_spawns(false)
	_assert(_count_small(orbs) == 3 and _count_fireballs(orbs) == 0, "Stance: tap X fires a volley of 3 small orbs (no fireball)",
		"spawned %d: %s" % [orbs.size(), _names(orbs)])
	_assert(_combo_steps.is_empty() and _state() != &"MeleeStrike", "Stance: tap X does not start a melee strike",
		"steps=%s state=%s" % [_combo_steps, _state()])
	await _real_seconds(0.3)

	# Hold X: past the 0.22s hold threshold, a 0.4s charge, then one large
	# fireball (fires at ~0.62s while still held; releasing earlier fizzles).
	_track_spawns(true)
	Input.parse_input_event(_joy_press(JOY_X))
	await _real_seconds(0.25)
	var early := _projectiles_spawned().size()
	await _real_seconds(0.65)
	Input.parse_input_event(_joy_release(JOY_X))
	await _real_seconds(0.3)
	var fire := _projectiles_spawned()
	_track_spawns(false)
	_assert(early == 0, "Stance: no fireball before the 0.4s charge completes", "spawned %d early" % early)
	_assert(_count_fireballs(fire) == 1, "Stance: hold X fires one large fireball",
		"spawned %d: %s" % [fire.size(), _names(fire)])
	_assert(_count_small(fire) == 0, "Stance: releasing a hold after the fireball fires no extra orb volley",
		"spawned %d: %s" % [fire.size(), _names(fire)])
	_assert(_combo_steps.is_empty(), "Stance: hold X does not start a heavy melee strike", str(_combo_steps))

	# Cooldown 1.5s blocks a second charged shot.
	_track_spawns(true)
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.9)
	await _real_seconds(0.2)
	var during_cd := _projectiles_spawned()
	_track_spawns(false)
	_assert(_count_fireballs(during_cd) == 0, "Stance: fireball cooldown (1.5s) blocks a second charged shot",
		"spawned %d: %s" % [during_cd.size(), _names(during_cd)])
	await _real_seconds(1.2)
	_track_spawns(true)
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.9)
	await _real_seconds(0.3)
	var after_cd := _projectiles_spawned()
	_track_spawns(false)
	_assert(_count_fireballs(after_cd) == 1, "Stance: fireball available again after the cooldown",
		"spawned %d: %s" % [after_cd.size(), _names(after_cd)])
	_assert(is_equal_approx(_player.current_mp, mp0), "Stance attacks cost no MP",
		"mp %.1f -> %.1f" % [mp0, _player.current_mp])

	# Dodge works in stance.
	await _real_seconds(0.3)
	await _ground_idle()
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.04)
	_assert(_state() == &"Dodge" or _saw_state_recently(&"Dodge"), "Dodge works in stance", "state=%s" % _state())
	_assert(st.is_active(), "Dodging keeps the stance")
	await _real_seconds(0.6)

	# Toggle off.
	_assert(st.toggle() == false and not st.is_active(), "toggle() again exits the stance")
	_assert(_stance_log.size() >= 2 and _stance_log[-1][1] == &"", "stance_changed(member, &\"\") on exit",
		str(_stance_log))

	# Leaving battle exits the stance.
	st.toggle()
	_assert(st.is_active(), "Stance on again before leaving battle")
	await _to_free_roam()
	_assert(not st.is_active(), "Leaving battle exits the stance automatically")

	# Free roam: X is melee again (stance can't be on).
	_assert(not _player.is_unique_press(_joy_press(JOY_Y)), "Free roam: Y is not the unique ability")

	# Fire Bolt (spell_projectile) still works through the Command Menu ability path.
	var fire_bolt = _player.ability_system.get_equipped_ability(0)
	_assert(fire_bolt != null and ResourceLoader.exists("res://src/effects/spell_projectile.tscn"),
		"Fire Bolt ability + spell_projectile.tscn still present")
	_clear_projectiles()


# ========== STRING DRIVER ==========

func _run_string(seq: String, dummy: Node, side: Node) -> Dictionary:
	await _reset_combo()
	await _place_for_string(dummy, side)
	_combo_steps.clear()
	_combo_finishers.clear()
	_damage_log.clear()
	var ok := true
	for i in seq.length():
		if i > 0:
			if not await _wait_until(func(): return _combo_steps.size() >= i, 1.5):
				ok = false
				break
			await _real_seconds(LEAD_AFTER_L if seq[i - 1] == "L" else LEAD_AFTER_H)
		if seq[i] == "L":
			await _tap(_joy_press(JOY_X), _joy_release(JOY_X), TAP_SEC, false)
		else:
			await _tap(_joy_press(JOY_X), _joy_release(JOY_X), HOLD_SEC, false)
	var string_seen: String = _player.combo.current_string()
	if ok:
		ok = await _wait_until(func(): return _combo_steps.size() >= 3, 1.5)
	await _wait_until(func(): return not _combo_finishers.is_empty(), 1.5)
	await _wait_until(func(): return _state() != &"MeleeStrike", 2.0)
	await _real_seconds(0.3)  # blast VFX / damage settle
	var dmg := 0.0
	var side_dmg := 0.0
	var side_hits := 0
	for e in _damage_log:
		if e[0] == dummy:
			dmg += float(e[1])
		elif e[0] == side:
			side_dmg += float(e[1])
			side_hits += 1
	var kinds: Array = []
	for s in _combo_steps:
		kinds.append(s[1])
	return {
		"ok": ok and _combo_steps.size() == 3,
		"steps": _combo_steps.duplicate(),
		"kinds": kinds,
		"string": string_seen,
		"finisher": _combo_finishers[0] if not _combo_finishers.is_empty() else [],
		"dmg": dmg,
		"side_dmg": side_dmg,
		"side_hits": side_hits,
	}


func _kinds_for(seq: String) -> Array:
	var out: Array = []
	for c in seq:
		out.append(&"light" if c == "L" else &"heavy")
	return out


func _place_for_string(dummy: Node, side: Node) -> void:
	await _ground_idle()
	_player.global_position = Vector3(0, 0.05, 0)
	_player.basis = Basis.IDENTITY  # faces -Z
	_player.velocity = Vector3.ZERO
	if dummy:
		dummy.global_position = Vector3(0, 0, -1.6)
		dummy.current_hp = dummy.max_hp
		dummy.stagger_value = 0.0
		dummy.ai_state = EnemyBase.AIState.CHASE
	if side:
		side.global_position = Vector3(3.5, 0, -1.6)
		side.current_hp = side.max_hp
		side.stagger_value = 0.0
		side.ai_state = EnemyBase.AIState.CHASE
	await _physics_frames(3)


func _reset_combo() -> void:
	await _wait_until(func(): return _state() != &"MeleeStrike" and _state() != &"Dodge", 2.0)
	if _player.combo:
		_player.combo.reset(&"manual")
	await _ground_idle()


# ========== HARNESS ==========

func _setup_player() -> bool:
	var scene = load(PLAYER_SCENE) as PackedScene
	if scene == null:
		_fail("Player runtime harness", "player.tscn failed to load")
		return false
	_player = scene.instantiate()
	_world.add_child(_player)
	_player.global_position = Vector3(0, 0.1, 0)
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _physics_frames(2)
	if not await _wait_on_floor():
		_fail("Player lands on test floor", "never on floor")
		return false
	if _player.get_script() == null or not _player.has_method("is_command_press"):
		_fail("Player routing API (Q)", "player.gd failed to load or has no is_command_press()")
		return false
	# The battle-driving enemy: far away, AI frozen, ai_state set by hand.
	var es = load(ENEMY_SCENE) as PackedScene
	if es == null:
		_fail("Enemy harness", "enemy.tscn failed to load")
		return false
	_enemy = es.instantiate()
	_world.add_child(_enemy)
	_enemy.global_position = Vector3(80, 0, 80)
	await _physics_frames(2)
	_freeze(_enemy)
	_enemy.ai_state = EnemyBase.AIState.IDLE
	_player.battle_mode.force_exit()
	return true


## A frozen dummy enemy (AI off, huge HP) or a live one (freeze=false).
func _spawn_dummy(pos: Vector3, freeze: bool = true) -> Node:
	var es = load(ENEMY_SCENE) as PackedScene
	if es == null:
		return null
	var e: Node = es.instantiate()
	_world.add_child(e)
	e.global_position = pos
	await _physics_frames(2)
	if freeze:
		_freeze(e)
		e.max_hp = 100000.0
		e.current_hp = e.max_hp
		if "stagger_max" in e:
			e.stagger_max = 100000.0
	e.ai_state = EnemyBase.AIState.IDLE
	return e


func _freeze(e: Node) -> void:
	e.set_physics_process(false)
	e.set_process(false)


func _engage() -> void:
	_enemy.ai_state = EnemyBase.AIState.CHASE
	_player.battle_mode.force_check(0)


func _disengage() -> void:
	_enemy.ai_state = EnemyBase.AIState.IDLE


## Back to Free Roam: every enemy idle (or dead), battle mode forced out.
func _to_free_roam() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is EnemyBase and e.ai_state != EnemyBase.AIState.DEAD:
			e.ai_state = EnemyBase.AIState.IDLE
	_player.battle_mode.force_exit()
	if _state() == &"TacticalIdle":
		_player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(2)


func _ground_idle() -> void:
	_release_all_input()
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _wait_on_floor(240)
	if _state() != &"Idle":
		_player.state_machine.force_transition(&"Idle")
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)


func _close_menu() -> void:
	var tries := 0
	while _state() == &"TacticalIdle" and tries < 4:
		await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
		tries += 1
	if _state() == &"TacticalIdle":
		_player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(2)


## Press, hold for `hold` real seconds, release (real input path).
func _tap(press: InputEvent, release: InputEvent, hold: float = 0.05, settle: bool = true) -> void:
	_state_trail.clear()
	Input.parse_input_event(press)
	await _real_seconds(hold)
	Input.parse_input_event(release)
	if settle:
		await _real_seconds(0.08)


var _state_trail: Array[StringName] = []


func _process(_delta: float) -> void:
	if _player and is_instance_valid(_player) and _player.state_machine and _player.state_machine.current_state:
		var s: StringName = _player.state_machine.current_state.name
		if _state_trail.is_empty() or _state_trail[-1] != s:
			_state_trail.append(s)


func _saw_state_recently(s: StringName) -> bool:
	return _state_trail.has(s)


func _connect_logs() -> void:
	Events.battle_mode_changed.connect(func(v): _battle_log.append(v))
	Events.combo_step.connect(func(step, kind): _combo_steps.append([step, kind]))
	Events.combo_finisher.connect(func(kind, radius): _combo_finishers.append([kind, radius]))
	Events.stance_changed.connect(func(m, s): _stance_log.append([m, s]))
	Events.enemy_staggered.connect(func(e): _staggered_log.append(e))
	Events.enemy_damaged.connect(func(e, d): _damage_log.append([e, d]))
	Events.carry_ended.connect(func(o, r): _carry_log.append([o, r]))


func _track_spawns(on: bool) -> void:
	if on:
		_spawned.clear()
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
	elif get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	_spawned.append(n)


## Projectile roots added while tracking: scripts under src/effects/ named
## *orb* / *fireball* / *projectile* (not the aura / arc / blast VFX).
func _projectiles_spawned() -> Array[Node]:
	var out: Array[Node] = []
	for n in _spawned:
		if not is_instance_valid(n):
			continue
		var s = n.get_script()
		if s == null:
			continue
		var p: String = s.resource_path.get_file().to_lower()
		if s.resource_path.begins_with("res://src/effects/") and not p.contains("aura") \
				and (p.contains("orb") or p.contains("fireball") or p.contains("projectile")):
			out.append(n)
	return out


## Large fireball: burst_radius > 0 (ArcaneOrb FIREBALL kind) or named *Fireball*.
func _is_fireball(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	if "burst_radius" in n and float(n.burst_radius) > 0.0:
		return true
	return String(n.name).to_lower().contains("fireball")


func _count_fireballs(nodes: Array) -> int:
	var c := 0
	for n in nodes:
		if _is_fireball(n):
			c += 1
	return c


func _count_small(nodes: Array) -> int:
	var c := 0
	for n in nodes:
		if is_instance_valid(n) and not _is_fireball(n):
			c += 1
	return c


func _names(nodes: Array) -> String:
	var parts: Array[String] = []
	for n in nodes:
		if is_instance_valid(n):
			parts.append("%s(%s)" % [n.name, n.get_script().resource_path.get_file()])
	return ", ".join(parts)


func _clear_projectiles() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


## True (and records a "not implemented" failure) if `path` is still Q's stub.
func _stub(path: String, pkg: String) -> bool:
	var src := _get_source(path)
	if src == "" or src.contains(STUB_MARK):
		_fail("Package %s implementation (%s)" % [pkg, path.get_file()],
			"not implemented: still the Package Q stub")
		return true
	return false


func _teardown() -> void:
	_release_all_input()
	_track_spawns(false)
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null
	_player = null
	_enemy = null


func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "TestWorld"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	world.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 6)
	world.add_child(cam)
	cam.current = true
	return world


func _make_stub_interactable() -> Area3D:
	var gd := GDScript.new()
	gd.source_code = "extends Area3D\nvar calls: int = 0\nvar interact_priority: int = 0\nfunc is_active() -> bool: return true\nfunc interact(_p) -> void: calls += 1\n"
	gd.reload()
	var a := Area3D.new()
	a.set_script(gd)
	a.collision_layer = 0
	a.collision_mask = 0
	a.monitorable = false
	return a


func _state() -> StringName:
	if _player == null or not is_instance_valid(_player) or _player.state_machine.current_state == null:
		return &""
	return _player.state_machine.current_state.name


func _wait_on_floor(max_frames: int = 120) -> bool:
	for i in max_frames:
		if _player.is_on_floor():
			return true
		await get_tree().physics_frame
	return _player.is_on_floor()


## Poll `cond` on process frames (unaffected by time scale) for up to timeout_s real seconds.
func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout_s * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Clears held action state only (no release events reach the states, so a
## stray release can't feed ComboComponent.on_attack_released).
func _release_all_input() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"interact", &"attack",
			&"jump", &"dodge", &"tactical_mode", &"unique_ability"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _real_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _joy_press(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = true
	return ev


func _joy_release(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = false
	return ev


func _joy_axis(axis: int, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _key_press(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _key_release(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = false
	return ev


func _get_source(path: String) -> String:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String, reason: String = "") -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name, reason)


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
