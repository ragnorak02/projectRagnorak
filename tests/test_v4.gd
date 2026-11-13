## Battle v4 polish tests (docs/plans/battle_v4_polish_plan.md, Package Z).
## Covers:
##  - W: manual Battle / Free Roam toggle (battle_toggle = View/Back joy 4, F):
##    on, off, manual hold (no 3 s timeout), stand-down suppression and the
##    resume triggers (player hit lifts it, companion-sourced hit does not,
##    player_hurt, a new engagement), the 3 s rule after a fight, and every
##    blocked state (pause, cutscene, Command Menu, dialogue, dead, carrying).
##  - X: the target step always shows for offensive commands; Fire Forward is the
##    only row with no enemies; enemies are nearest-first with Fire Forward last;
##    cycling wraps; Y fires forward from any row; B backs out one layer; ATB is
##    checked on confirm (the step stays open); A on a chosen enemy hits only it.
##  - Y: the minimap is part of the zone HUD, top-right, hidden in the pause
##    menu, visible in free roam, the Command Menu and the target step.
##  - H-5: the quest tracker mode chip follows battle_mode_changed.
##  - H-1: after leaving a crate's area the prompt hides and _carryable is null.
## Input goes through Input.parse_input_event (the real _unhandled_input path)
## with real-time waits. Part 1 runs in a bare test world with frozen dummies;
## part 2 instances the real town_hub zone (HUD spawned by zone_base).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_A := 0
const JOY_B := 1
const JOY_Y := 3
const JOY_BACK := 4
const JOY_DPAD_DOWN := 12
const JOY_DPAD_RIGHT := 14

const PLAYER_SCENE := "res://src/player/player.tscn"
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const CRATE_SCENE := "res://src/interaction/carryable_crate.tscn"
const TOWN_SCENE := "res://scenes/zones/town_hub.tscn"
const FIRE_FORWARD := "Fire Forward"
const PHASE_ABILITY := 1
const PHASE_TARGET := 2
const WATCHDOG_SECONDS := 150.0

var _world: Node3D = null
var _player: Node = null
var _enemy: Node = null  # far frozen enemy; ai_state set by hand to drive Battle Mode
var _zone: Node = null

var _battle_log: Array[bool] = []
var _manual_log: Array[bool] = []
var _damage_log: Array = []   # [[enemy, amount], ...]
var _fail_log: Array = []     # [reason, ...]
var _effects: Array = []      # ability_effect_spawned effects


func _ready() -> void:
	print("=== Battle v4 Tests (manual toggle, target step, minimap, mode chip, prompt) ===")
	print("")
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs (a test hung or aborted)" % WATCHDOG_SECONDS)
		_release_all_input()
		print("\n=== V4 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
		get_tree().quit(1))
	await _run_tests()
	_release_all_input()
	Engine.time_scale = 1.0
	print("\n=== V4 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("CONTRACT — EVENTS / APIS")
	test_contract()
	_connect_logs()

	_world = _make_world()
	add_child(_world)
	await get_tree().physics_frame
	if not await _setup_player():
		_fail("V4 runtime tests", "skipped: player harness failed")
		return

	_section("TARGET STEP — NO ENEMIES: FIRE FORWARD ONLY")
	# The battle-driving enemy is parked out of the tree for this part.
	_world.remove_child(_enemy)
	await test_target_step_no_enemies()
	_world.add_child(_enemy)
	_enemy.global_position = Vector3(80, 0, 80)
	_freeze(_enemy)
	_enemy.ai_state = EnemyBase.AIState.IDLE
	await _physics_frames(2)

	_section("MANUAL TOGGLE — ON / OFF / HOLD")
	await test_manual_toggle_on_off()
	await test_manual_after_fight_uses_timer()

	_section("MANUAL TOGGLE — STAND-DOWN RESUME TRIGGERS")
	await test_resume_player_hit()
	await test_companion_hit_keeps_suppression()
	await test_resume_player_hurt()
	await test_resume_new_engagement()

	_section("MANUAL TOGGLE — BLOCKED STATES")
	await test_toggle_blocked_states()

	_section("TARGET STEP — 3+ ENEMIES")
	await test_target_step_enemies()

	_teardown_world()
	await _frames(3)

	_section("TOWN HUB — MINIMAP / MODE CHIP / PROMPT / TARGET STEP")
	if await _load_town():
		test_minimap_present()
		await test_mode_chip()
		await test_minimap_menus()
		await test_crate_prompt_clears()
	_teardown_zone()
	await _frames(3)


# ========== CONTRACT ==========

func test_contract() -> void:
	for sig in [&"battle_mode_changed", &"battle_mode_manual_toggled", &"enemy_hit", &"player_hurt",
			&"tactical_target_info"]:
		_assert(Events.has_signal(sig), "Events.%s signal exists" % sig)
	var bm := BattleModeComponent.new()
	_assert(bm.has_method("toggle_manual") and "is_suppressed" in bm and "is_manual_hold" in bm,
		"BattleModeComponent has toggle_manual(), is_suppressed, is_manual_hold")
	bm.free()
	var tac_consts: Dictionary = load("res://src/player/states/tactical_idle_state.gd").get_script_constant_map()
	_assert(tac_consts.get("FIRE_FORWARD_LABEL", "") == FIRE_FORWARD,
		"TacticalIdle.FIRE_FORWARD_LABEL is \"Fire Forward\"")
	var ab_src := _get_source("res://src/player/states/ability_state.gd")
	_assert(ab_src.contains("func aim_forward("), "AbilityState exposes aim_forward()")
	var mm := _get_source("res://src/ui/hud/minimap.gd")
	_assert(mm.contains("mouse_filter = Control.MOUSE_FILTER_IGNORE") and not mm.contains("func _input(")
			and not mm.contains("func _unhandled_input("),
		"Minimap never handles input (mouse_filter IGNORE, no input callbacks)")


# ========== MANUAL TOGGLE ==========

func test_manual_toggle_on_off() -> void:
	var bm: Node = _player.battle_mode
	await _to_free_roam()
	_battle_log.clear()
	_manual_log.clear()
	_assert(not _player.in_battle and _player.can_toggle_battle(), "Free roam, toggle allowed in PLAYING")

	# Pad View/Back: free roam -> Battle with no enemy engaged ("weapon drawn").
	await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
	_assert(_player.in_battle, "Pad View/Back enters Battle with no enemy engaged")
	_assert(bm.is_manual_hold and not bm.is_suppressed, "Manual Battle holds (no fight yet), not suppressed")
	_assert(_battle_log == [true] and _manual_log == [true],
		"battle_mode_changed [true] + battle_mode_manual_toggled [true]",
		"changed=%s manual=%s" % [_battle_log, _manual_log])

	# Held manual Battle never times out on the 3 s rule.
	bm.force_check(0)
	bm.force_check(3500)
	bm.force_check(3500)
	_assert(_player.in_battle and bm.get_exit_time_remaining() == 0.0,
		"Manual Battle with nothing engaged does not time out (7 s credited)")
	var start := Time.get_ticks_msec()
	await _real_seconds(0.6)
	_assert(_player.in_battle, "Manual Battle still on after real polling (%d ms)" % (Time.get_ticks_msec() - start))

	# Keyboard F: Battle -> Free Roam.
	await _tap(_key_press(KEY_F), _key_release(KEY_F))
	_assert(not _player.in_battle, "Keyboard F returns to Free Roam")
	_assert(bm.is_suppressed and not bm.is_manual_hold, "Stand-down sets suppression, clears the hold")
	_assert(_battle_log == [true, false] and _manual_log == [true, false],
		"battle_mode_changed [true,false] + manual_toggled [true,false]",
		"changed=%s manual=%s" % [_battle_log, _manual_log])

	# Back on again clears the suppression.
	await _tap(_key_press(KEY_F), _key_release(KEY_F))
	_assert(_player.in_battle and not bm.is_suppressed, "Toggling on again clears the suppression")
	await _to_free_roam()


func test_manual_after_fight_uses_timer() -> void:
	var bm: Node = _player.battle_mode
	await _to_free_roam()
	bm.toggle_manual()
	_assert(_player.in_battle and bm.is_manual_hold, "Manual Battle on (hold)")
	_enemy.ai_state = EnemyBase.AIState.CHASE
	bm.force_check(0)
	_assert(_player.in_battle and not bm.is_manual_hold, "An engagement drops the manual hold")
	_enemy.ai_state = EnemyBase.AIState.IDLE
	bm.force_check(0)
	bm.force_check(2800)
	_assert(_player.in_battle, "After the fight: still Battle 2.8 s after the last disengage")
	bm.force_check(300)
	_assert(not _player.in_battle, "After the fight: Free Roam 3 s after the last disengage (v3 rule)")
	await _to_free_roam()


## Battle with E0 engaged, then stand down (real F press). Returns true when the
## stand-down left the player in suppressed Free Roam with E0 still engaged.
func _stand_down_engaged() -> bool:
	await _to_free_roam()
	_enemy.ai_state = EnemyBase.AIState.CHASE
	_player.battle_mode.force_check(0)
	if not _player.in_battle:
		_fail("Stand-down harness: auto Battle on engage", "not in battle")
		return false
	await _tap(_key_press(KEY_F), _key_release(KEY_F))
	_player.battle_mode.force_check(0)
	return not _player.in_battle and _player.battle_mode.is_suppressed \
		and _enemy.ai_state == EnemyBase.AIState.CHASE


func test_resume_player_hit() -> void:
	var ok := await _stand_down_engaged()
	_assert(ok, "Stand-down with an enemy engaged: Free Roam, suppressed")
	if not ok:
		return
	_player.battle_mode.force_check(400)
	await _real_seconds(0.5)  # real polls too
	_assert(not _player.in_battle, "Engaged enemy does not re-enter Battle while suppressed")
	# The player deals damage (source = the player's hitbox anchor).
	var src: Node3D = _player.get_node_or_null(^"HitboxAnchor")
	if src == null:
		src = _player
	_enemy.take_damage(1.0, src)
	_enemy.ai_state = EnemyBase.AIState.CHASE
	await _frames(2)
	_assert(_player.in_battle and not _player.battle_mode.is_suppressed,
		"A player hit lifts the suppression and auto Battle resumes at once",
		"in_battle=%s suppressed=%s" % [_player.in_battle, _player.battle_mode.is_suppressed])
	await _to_free_roam()


func test_companion_hit_keeps_suppression() -> void:
	# A non-player party member (group party_members) whose child is the source.
	var companion := Node3D.new()
	companion.name = "StubCompanion"
	companion.add_to_group(&"party_members")
	var weapon := Node3D.new()
	weapon.name = "Weapon"
	companion.add_child(weapon)
	_world.add_child(companion)
	var ok := await _stand_down_engaged()
	_assert(ok, "Stand-down (companion case): Free Roam, suppressed")
	if ok:
		_enemy.take_damage(1.0, weapon)
		_enemy.take_damage(1.0, companion)
		_enemy.ai_state = EnemyBase.AIState.CHASE
		_player.battle_mode.force_check(0)
		await _real_seconds(0.5)
		_assert(not _player.in_battle and _player.battle_mode.is_suppressed,
			"Companion-sourced hits (node or child under party_members) keep the suppression",
			"in_battle=%s suppressed=%s" % [_player.in_battle, _player.battle_mode.is_suppressed])
		# A source-less hit counts as the player's (only companions are excluded).
		_enemy.take_damage(1.0, null)
		_enemy.ai_state = EnemyBase.AIState.CHASE
		await _frames(2)
		_assert(_player.in_battle, "A hit with no source is not a companion hit (lifts the suppression)")
	companion.queue_free()
	await _to_free_roam()


func test_resume_player_hurt() -> void:
	var ok := await _stand_down_engaged()
	_assert(ok, "Stand-down (player_hurt case): Free Roam, suppressed")
	if not ok:
		return
	var hp: float = _player.current_hp
	_player.take_damage(1.0, _enemy)  # real path: emits Events.player_hurt
	await _frames(2)
	_assert(_player.in_battle and not _player.battle_mode.is_suppressed,
		"Taking damage (player_hurt) lifts the suppression and auto Battle resumes")
	_player.current_hp = hp
	await _physics_frames(30)
	await _ground_idle()
	await _to_free_roam()


func test_resume_new_engagement() -> void:
	var second := await _spawn_dummy(Vector3(-80, 0, 80))
	if second == null:
		_fail("New engagement harness", "enemy.tscn failed to load")
		return
	var ok := await _stand_down_engaged()
	_assert(ok, "Stand-down (new engagement case): Free Roam, suppressed")
	if ok:
		# A stand-down enemy that disengages and re-engages counts as new.
		_enemy.ai_state = EnemyBase.AIState.IDLE
		_player.battle_mode.force_check(0)
		_assert(not _player.in_battle and _player.battle_mode.is_suppressed,
			"Stand-down enemy disengaging keeps Free Roam (still suppressed)")
		second.ai_state = EnemyBase.AIState.CHASE
		_player.battle_mode.force_check(0)
		_assert(_player.in_battle and not _player.battle_mode.is_suppressed,
			"An enemy that was not engaged at stand-down engages -> auto Battle resumes")
	second.queue_free()
	await _physics_frames(2)
	await _to_free_roam()


func test_toggle_blocked_states() -> void:
	await _to_free_roam()
	await _ground_idle()
	_manual_log.clear()
	# GameManager states (pause/menus, cutscene).
	for st in [GameManager.GameState.PAUSED, GameManager.GameState.CUTSCENE]:
		GameManager.change_state(st)
		await _frames(2)
		_assert(not _player.can_toggle_battle(), "can_toggle_battle() false in %s" % GameManager.GameState.keys()[st])
		await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
		_assert(not _player.in_battle, "View/Back does nothing in %s" % GameManager.GameState.keys()[st])
		GameManager.change_state(GameManager.GameState.PLAYING)
		await _frames(2)

	# The real Command Menu (Y with no prompt in free roam).
	await _open_command_menu()
	if _state() == &"TacticalIdle":
		await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
		_assert(not _player.in_battle and _state() == &"TacticalIdle",
			"View/Back does nothing while the Command Menu is open", "state=%s" % _state())
		await _close_menu()
	else:
		_fail("Blocked: Command Menu harness", "menu did not open (state=%s)" % _state())

	# Dialogue (a dialogue_ui reporting an active dialogue).
	var dlg := _make_stub_dialogue()
	add_child(dlg)
	await _frames(1)
	_assert(not _player.is_battle_toggle_press(_joy_press(JOY_BACK)) and not _player.can_toggle_battle(),
		"Dialogue open: is_battle_toggle_press() and can_toggle_battle() are false")
	await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
	_assert(not _player.in_battle, "View/Back does nothing during dialogue")
	dlg.queue_free()
	await _frames(2)

	# Dead.
	var hp: float = _player.current_hp
	_player.current_hp = 0.0
	await _tap(_key_press(KEY_F), _key_release(KEY_F))
	_assert(not _player.in_battle and not _player.can_toggle_battle(), "F does nothing with hp 0")
	_player.current_hp = hp

	# Carrying a crate.
	var cs = load(CRATE_SCENE) as PackedScene
	if cs:
		await _ground_idle()
		var crate: Node3D = cs.instantiate()
		_world.add_child(crate)
		crate.global_position = _player.global_position + (-_player.global_basis.z * 1.6) + Vector3(0, 0.2, 0)
		await _physics_frames(30)
		crate.interact(_player)
		await _physics_frames(10)
		var carry: Node = _player.get_node_or_null(^"CarryComponent")
		var carrying: bool = carry != null and carry.is_carrying
		_assert(carrying, "Blocked: carrying harness picked up the crate", "state=%s" % _state())
		if carrying:
			await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
			_assert(not _player.in_battle and carry.is_carrying, "View/Back does nothing while carrying")
			carry.drop(&"forced")
			await _physics_frames(5)
		crate.queue_free()
	else:
		_fail("Blocked: carrying harness", "carryable_crate.tscn failed to load")

	_assert(_manual_log.is_empty(), "No manual toggle fired in any blocked state", str(_manual_log))
	# Allowed again after all of that.
	await _ground_idle()
	_assert(_player.can_toggle_battle(), "Toggle allowed again in PLAYING / Idle")
	await _to_free_roam()


# ========== TARGET STEP ==========

func test_target_step_no_enemies() -> void:
	await _ground_idle()
	_assert(get_tree().get_nodes_in_group(&"enemies").is_empty(), "No enemies in the tree for this part")
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	var tac := await _open_to_target_step()
	if tac == null:
		return
	_assert(tac._get_target_names() == PackedStringArray([FIRE_FORWARD]) and tac._target_index == 0,
		"No enemies: the only row is Fire Forward, pre-selected", str(tac._get_target_names()))
	_assert(_effects.is_empty() and _player.current_atb >= _player.max_atb - 0.01,
		"No enemies: nothing is cast until the player confirms")
	# Cycling a single row stays put.
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	_assert(tac._target_index == 0, "Cycling the single Fire Forward row stays on it")
	# B goes back one layer, A re-enters.
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(_state() == &"TacticalIdle" and int(tac._phase) == PHASE_ABILITY,
		"B in the target step goes back one layer (ability list)", "phase=%d" % int(tac._phase))
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == PHASE_TARGET, "A on the spell re-opens the target step")
	# Y = Fire Forward shortcut: casts along camera forward.
	_effects.clear()
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	var cast := await _wait_until(func(): return not _effects.is_empty(), 2.0)
	_assert(cast and _state() != &"TacticalIdle", "Y in the target step fires forward (no enemies)",
		"effects=%d state=%s" % [_effects.size(), _state()])
	if cast:
		_assert_forward(_effects[0], "Fire Forward projectile flies along camera forward (no enemies)")
	_assert(GameManager.current_state == GameManager.GameState.PLAYING,
		"Fire Forward closes the Command Menu (GameManager PLAYING)")
	await _wait_until(func(): return _state() != &"Ability", 2.0)
	_clear_effects()
	await _ground_idle()


func test_target_step_enemies() -> void:
	await _to_free_roam()
	await _ground_idle()
	_player.global_position = Vector3(0, 0.05, 0)
	_player.basis = Basis.IDENTITY
	# Camera looks down -Z: nearest left, middle right, farthest behind — none
	# in the camera-forward line, so Fire Forward can't hit any of them.
	var a := await _spawn_dummy(Vector3(-5, 0, -1))
	var b := await _spawn_dummy(Vector3(5, 0, -3))
	var c := await _spawn_dummy(Vector3(0, 0, 8))
	if a == null or b == null or c == null:
		_fail("Target step harness", "enemy.tscn failed to load")
		return
	await _ground_idle()
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	var tac := await _open_to_target_step()
	if tac == null:
		for e in [a, b, c]:
			e.queue_free()
		return
	var cands: Array = tac._target_candidates
	var names: PackedStringArray = tac._get_target_names()
	_assert(cands.size() >= 3 and cands[0] == a and cands[1] == b and cands[2] == c,
		"Enemies listed nearest-first (left 5.1 m, right 5.8 m, behind 8 m)", str(cands))
	_assert(names.size() == cands.size() + 1 and names[names.size() - 1] == FIRE_FORWARD,
		"Fire Forward is the final row after %d enemies" % cands.size(), str(names))
	_assert(tac._target_index == 0 and _player.lock_on_target == a,
		"Nearest enemy is pre-selected and highlighted", "index=%d" % tac._target_index)

	# Cycle: D-pad down to B; right wraps through to Fire Forward and back.
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	_assert(tac._target_index == 1 and _player.lock_on_target == b, "D-pad down highlights the next enemy (B)")
	var rows: int = names.size()
	for i in rows - 2:
		await _tap(_joy_press(JOY_DPAD_RIGHT), _joy_release(JOY_DPAD_RIGHT))
	_assert(tac._target_index == rows - 1 and tac._is_forward_row_selected(),
		"D-pad right reaches the Fire Forward row", "index=%d rows=%d" % [tac._target_index, rows])
	_assert(not _player.is_locked_on and _player.lock_on_target == null,
		"Fire Forward row clears the enemy highlight")
	await _tap(_joy_press(JOY_DPAD_RIGHT), _joy_release(JOY_DPAD_RIGHT))
	_assert(tac._target_index == 0 and _player.lock_on_target == a, "Cycling wraps from Fire Forward to the first enemy")
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))

	# ATB is checked on confirm: a failed confirm keeps the step open.
	_fail_log.clear()
	_player.current_atb = 0.0
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"TacticalIdle" and int(tac._phase) == PHASE_TARGET and _fail_log.size() > 0,
		"Confirm with ATB 0: ability_request_failed toast, target step stays open",
		"state=%s fails=%s" % [_state(), str(_fail_log)])
	_player.current_atb = _player.max_atb

	# A on B hits B only.
	_damage_log.clear()
	_effects.clear()
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() != &"TacticalIdle", "A on enemy B casts (menu closes)", "state=%s" % _state())
	var hit := await _wait_until(func(): return not _damage_log.is_empty(), 3.0)
	await _real_seconds(0.3)
	var hit_b := false
	var hit_other := false
	for d in _damage_log:
		if d[0] == b:
			hit_b = true
		elif d[0] == a or d[0] == c or d[0] == _enemy:
			hit_other = true
	_assert(hit and hit_b and not hit_other, "A on the chosen enemy (B) damages B and nothing else",
		"log=%s" % str(_damage_log))
	await _wait_until(func(): return _state() != &"Ability", 2.0)
	_clear_effects()
	for e in [a, b, c]:
		e.ai_state = EnemyBase.AIState.IDLE

	# Y from an enemy row fires forward: no enemy is hit.
	await _to_free_roam()
	await _ground_idle()
	_player.global_position = Vector3(0, 0.05, 0)
	_player.basis = Basis.IDENTITY
	var bolt: AbilityData = _player.ability_system.get_equipped_ability(0)
	await _wait_until(func(): return not _player.ability_system.is_on_cooldown(bolt.ability_id), 6.0)
	_fail_log.clear()
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	tac = await _open_to_target_step()
	if tac != null:
		_assert(not tac._is_forward_row_selected(), "Target step opened on an enemy row")
		_damage_log.clear()
		_effects.clear()
		await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
		var cast := await _wait_until(func(): return not _effects.is_empty(), 2.0)
		_assert(cast, "Y from an enemy row fires (Fire Forward shortcut)", "state=%s fails=%s" % [_state(), str(_fail_log)])
		if cast:
			_assert_forward(_effects[0], "Y-shortcut projectile flies along camera forward, not at the row's enemy")
		await _real_seconds(1.5)
		_assert(_damage_log.is_empty(), "Fire Forward hits no enemy off the forward line", str(_damage_log))
		await _wait_until(func(): return _state() != &"Ability", 2.0)
	_clear_effects()
	for e in [a, b, c]:
		e.queue_free()
	await _physics_frames(2)
	await _to_free_roam()


## Opens the Command Menu (free roam Y), A -> Abilities, A on Fire Bolt (slot 0).
## Returns the TacticalIdle state when the target step is open, else null.
func _open_to_target_step() -> Node:
	await _open_command_menu()
	if _state() != &"TacticalIdle":
		_fail("Target step harness: Command Menu opens on Y", "state=%s" % _state())
		return null
	var tac: Node = _player.state_machine.current_state
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	var ok: bool = _state() == &"TacticalIdle" and int(tac._phase) == PHASE_TARGET
	_assert(ok, "Offensive spell always opens the target step (A, A)",
		"state=%s phase=%s fails=%s" % [_state(), str(tac.get(&"_phase")), str(_fail_log)])
	return tac if ok else null


func _assert_forward(effect: Node, test_name: String) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(effect) or not ("_direction" in effect):
		_fail(test_name, "no camera / effect / _direction")
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var dir: Vector3 = effect._direction
	dir.y = 0.0
	var dot := fwd.normalized().dot(dir.normalized())
	var homing: bool = "_target" in effect and is_instance_valid(effect._target)
	_assert(dot > 0.95 and not homing, test_name, "dot=%.3f homing=%s" % [dot, homing])


# ========== TOWN HUB (real HUD) ==========

func _load_town() -> bool:
	var ps = load(TOWN_SCENE) as PackedScene
	if ps == null:
		_fail("Town hub harness", "town_hub.tscn failed to load")
		return false
	GameManager.change_state(GameManager.GameState.PLAYING)
	_zone = ps.instantiate()
	add_child(_zone)
	await _frames(2)
	# Block the deferred autosave on entry (it only saves while PLAYING).
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	await _frames(45)
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(45)
	_player = _zone.get(&"player")
	if _player == null or not is_instance_valid(_player):
		_fail("Town hub harness", "zone has no player")
		return false
	await _wait_on_floor(240)
	var im := InputManager
	im.active_device = InputManager.DeviceType.CONTROLLER
	return true


func _hud(script_file: String) -> Node:
	if _zone == null:
		return null
	for ch in _zone.get_children():
		if ch.get_script() and String(ch.get_script().resource_path).ends_with(script_file):
			return ch
	return null


func test_minimap_present() -> void:
	var mm := _hud("minimap.gd")
	_assert(mm != null, "Minimap is part of the zone HUD (zone_base._spawn_hud)")
	if mm == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var r: Rect2 = mm.get_frame_rect()
	var expect := Vector2(vp.x - 24.0 - 220.0, 24.0)
	_assert(r.position.distance_to(expect) < 2.0 and absf(r.size.x - 220.0) < 2.0 and absf(r.size.y - 220.0) < 2.0,
		"Minimap frame is 220 px at the top-right with a 24 px margin", "rect=%s vp=%s" % [r, vp])
	_assert(r.position.x > vp.x * 0.5 and r.position.y < vp.y * 0.25, "Minimap sits in the top-right quadrant")
	_assert(mm.is_map_visible() and mm.should_show(), "Minimap visible in free roam")
	var counts: Dictionary = mm.get_icon_counts()
	_assert(int(counts.get(2, 0)) > 0 and int(counts.get(4, 0)) > 0,
		"Town minimap draws NPC and portal icons", str(counts))


func test_mode_chip() -> void:
	var qt := _hud("quest_tracker.gd")
	_assert(qt != null and qt.has_method("get_mode_text") and qt.has_method("is_showing_battle"),
		"Quest tracker exposes get_mode_text() / is_showing_battle()")
	if qt == null:
		return
	await _ground_idle()
	_player.battle_mode.force_exit()
	await _frames(2)
	_assert(qt.get_mode_text() == "FREE ROAM" and not qt.is_showing_battle(), "Mode chip reads FREE ROAM",
		qt.get_mode_text())
	await _tap(_joy_press(JOY_BACK), _joy_release(JOY_BACK))
	_assert(_player.in_battle and qt.get_mode_text() == "BATTLE" and qt.is_showing_battle(),
		"Manual toggle on: chip flips to BATTLE", "in_battle=%s chip=%s" % [_player.in_battle, qt.get_mode_text()])
	await _tap(_key_press(KEY_F), _key_release(KEY_F))
	_assert(not _player.in_battle and qt.get_mode_text() == "FREE ROAM" and not qt.is_showing_battle(),
		"Manual toggle off: chip flips back to FREE ROAM", qt.get_mode_text())
	# Direct signal (auto Battle path) also flips it.
	Events.battle_mode_changed.emit(true)
	_assert(qt.is_showing_battle() and qt.get_mode_text() == "BATTLE", "battle_mode_changed(true) -> BATTLE")
	Events.battle_mode_changed.emit(false)
	_assert(not qt.is_showing_battle() and qt.get_mode_text() == "FREE ROAM", "battle_mode_changed(false) -> FREE ROAM")
	_player.battle_mode.force_exit()


func test_minimap_menus() -> void:
	var mm := _hud("minimap.gd")
	if mm == null:
		return
	await _ground_idle()
	# Away from NPCs / crates so Y opens the Command Menu.
	_player.global_position = Vector3(-1, 0.1, -9)
	await _physics_frames(20)
	await _ground_idle()

	# Pause menu (real pause action).
	await _tap_action(&"pause")
	await _real_seconds(0.3)
	_assert(GameManager.current_state == GameManager.GameState.PAUSED, "Pause action opens the pause menu",
		GameManager.GameState.keys()[GameManager.current_state])
	_assert(not mm.is_map_visible(), "Minimap hidden while the pause menu is open")
	await _tap_action(&"pause")
	await _real_seconds(0.3)
	_assert(GameManager.current_state == GameManager.GameState.PLAYING and mm.is_map_visible(),
		"Minimap back after closing the pause menu")

	# Command Menu + target step (town: Fire Forward only).
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	var tac := await _open_to_target_step()
	if tac != null:
		_assert(mm.is_map_visible(), "Minimap visible in the Command Menu target step")
		_assert(tac._get_target_names() == PackedStringArray([FIRE_FORWARD]),
			"Town: target step lists only Fire Forward", str(tac._get_target_names()))
		var menu := _hud("tactical_menu.gd")
		var footer := _label_text(menu.get(&"_hint_box")) if menu else ""
		_assert(footer.contains("Switch") and footer.contains("Confirm") and footer.contains(FIRE_FORWARD)
				and footer.contains("Back"),
			"Target step footer: Switch · Confirm · Fire Forward · Back", footer)
		await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
		_assert(int(tac._phase) == PHASE_ABILITY and mm.is_map_visible(),
			"B -> ability list; minimap visible in the Command Menu")
	await _close_menu()
	_assert(mm.is_map_visible(), "Minimap visible after the Command Menu closes")


func test_crate_prompt_clears() -> void:
	var prompt := _hud("interaction_prompt.gd")
	var crate: Node3D = null
	for n in get_tree().get_nodes_in_group(&"carryable"):
		if n is RigidBody3D:
			crate = n
			break
	if prompt == null or crate == null:
		_fail("Crate prompt harness", "prompt=%s crate=%s" % [prompt, crate])
		return
	await _ground_idle()
	_player.battle_mode.force_exit()
	_player.global_position = crate.global_position + Vector3(0, 0.2, 2.2)
	await _physics_frames(20)
	await _ground_idle()
	await _physics_frames(5)
	_assert(prompt.get_prompt_text().contains("Pick Up") and prompt.get(&"_visible_state")
			and _player._current_interactable != null,
		"Next to the crate: Pick Up prompt visible (crate area is the current interactable)",
		"text='%s' carryable=%s" % [prompt.get_prompt_text(), prompt.get(&"_carryable")])
	# Remembered-crate path (carryable_in_range), as when the area re-announces it.
	Events.carryable_in_range.emit(crate)
	await _frames(1)
	_assert(prompt.get(&"_carryable") == crate, "carryable_in_range(crate) remembers the crate")
	# Walk away (out of every interactable's area).
	_player.global_position = crate.global_position + Vector3(0, 0.2, 12.0)
	await _physics_frames(20)
	await _ground_idle()
	await _frames(3)
	_assert(not prompt.get(&"_visible_state") and prompt.get(&"_carryable") == null
			and prompt.get_prompt_text() == "",
		"After leaving the crate's area: prompt hidden, _carryable null, no text",
		"visible=%s carryable=%s text='%s'" % [prompt.get(&"_visible_state"), prompt.get(&"_carryable"),
			prompt.get_prompt_text()])
	# Y now opens the Command Menu (no stale crate prompt).
	await _open_command_menu()
	_assert(_state() == &"TacticalIdle", "With the prompt gone, Y opens the Command Menu", "state=%s" % _state())
	await _close_menu()


# ========== HELPERS ==========

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
	if not _player.has_method("can_toggle_battle"):
		_fail("Player battle toggle API (W)", "no can_toggle_battle()")
		return false
	var es = load(ENEMY_SCENE) as PackedScene
	if es == null:
		_fail("Enemy harness", "enemy.tscn failed to load")
		return false
	_enemy = es.instantiate()
	_world.add_child(_enemy)
	_enemy.global_position = Vector3(80, 0, 80)
	await _physics_frames(2)
	_freeze(_enemy)
	_enemy.max_hp = 100000.0
	_enemy.current_hp = _enemy.max_hp
	_enemy.ai_state = EnemyBase.AIState.IDLE
	_player.battle_mode.force_exit()
	return true


func _spawn_dummy(pos: Vector3) -> Node:
	var es = load(ENEMY_SCENE) as PackedScene
	if es == null:
		return null
	var e: Node = es.instantiate()
	_world.add_child(e)
	e.global_position = pos
	await _physics_frames(2)
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


func _to_free_roam() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is EnemyBase and e.ai_state != EnemyBase.AIState.DEAD:
			e.ai_state = EnemyBase.AIState.IDLE
	if _state() == &"TacticalIdle":
		_player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	_player.battle_mode.force_exit()
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


## Free roam: Y with no prompt opens the Command Menu; waits for the open-press guard.
func _open_command_menu() -> void:
	await _ground_idle()
	_player._current_interactable = null
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	if _state() != &"TacticalIdle":
		return
	var tac: Node = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)


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


func _tap(press: InputEvent, release: InputEvent, hold: float = 0.05) -> void:
	Input.parse_input_event(press)
	await _real_seconds(hold)
	Input.parse_input_event(release)
	await _real_seconds(0.08)


func _tap_action(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	e.strength = 1.0
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)


func _connect_logs() -> void:
	Events.battle_mode_changed.connect(func(v): _battle_log.append(v))
	Events.battle_mode_manual_toggled.connect(func(v): _manual_log.append(v))
	Events.enemy_damaged.connect(func(e, d): _damage_log.append([e, d]))
	Events.ability_request_failed.connect(func(r, _a): _fail_log.append(str(r)))
	Events.ability_effect_spawned.connect(func(e, _a): _effects.append(e))


func _clear_effects() -> void:
	for e in _effects:
		if is_instance_valid(e):
			e.queue_free()
	_effects.clear()


func _make_stub_dialogue() -> Node:
	var gd := GDScript.new()
	gd.source_code = "extends Node\nfunc _ready() -> void: add_to_group(&\"dialogue_ui\")\nfunc is_dialogue_active() -> bool: return true\n"
	gd.reload()
	var n := Node.new()
	n.set_script(gd)
	return n


func _label_text(root: Node) -> String:
	if root == null:
		return ""
	var parts: PackedStringArray = []
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).visible and (n as Label).text != "":
			parts.append((n as Label).text)
	if root is Label:
		parts.append(root.text)
	# GlyphHint widgets may draw their text themselves: fall back to their properties.
	for n in root.find_children("*", "", true, false):
		for prop in [&"text", &"label", &"caption"]:
			var v = n.get(prop)
			if v is String and v != "" and not parts.has(v):
				parts.append(v)
	return " · ".join(parts)


func _teardown_world() -> void:
	_release_all_input()
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null
	_player = null
	_enemy = null


func _teardown_zone() -> void:
	_release_all_input()
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null


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


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout_s * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _release_all_input() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"interact", &"attack",
			&"jump", &"dodge", &"tactical_mode", &"unique_ability", &"battle_toggle"]:
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


func _key_press(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _key_release(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
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
