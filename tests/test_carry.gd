## Carry / ThrowAim tests (Controls v2, Packages H + I) and solid props (J4).
## Spec: docs/plans/controls_v2_carry_plan.md -> "Carry / throw rules".
## Published APIs:
##  - Crate (H): CarryableCrate RigidBody3D, interact(player) -> CarryComponent.request_pick_up(self),
##    can_pick_up(), pick_up(holder), put_down(pos) -> bool, throw(impulse), release(),
##    is_held / is_flying, signal impacted(body), signal broken.
##  - Player (I): CarryAnchor, CarryComponent (request_pick_up / put_down / throw / drop /
##    is_carrying / held_object), StateMachine/Carry + StateMachine/ThrowAim,
##    Events.carry_started(obj) / carry_ended(obj, reason).
## Anything not implemented yet fails with a "not implemented" reason instead of crashing.
## v3 (battle_system_v3_plan): interact = Y (tap = put down, hold = throw aim, + X
## throws), jump = A, dodge = B. Carrying is free-roam only (entering battle drops
## the crate; covered in tests/test_battle.gd).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_AXIS_RT := 5

const PLAYER_SCENE := "res://src/player/player.tscn"
const CRATE_SCENE := "res://src/interaction/carryable_crate.tscn"
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const FIELD_ZONE_SCENE := "res://scenes/zones/field_zone.tscn"
const CRATE_GLTF := "Prop_Crate.gltf"
const CHEST_SCRIPT := "res://src/interaction/chest_interactable.gd"
const CARRY_COMPONENT_SCRIPT := "res://src/player/components/carry_component.gd"
const CARRY_STATE_SCRIPT := "res://src/player/states/carry_state.gd"
const THROW_AIM_STATE_SCRIPT := "res://src/player/states/throw_aim_state.gd"

const HOLD_SECONDS := 0.45  # > 0.25s hold threshold
const WATCHDOG_SECONDS := 120.0

var _world: Node3D = null
var _player: Node = null
var _carry: Node = null
var _crate_scene: PackedScene = null
## carry_started / carry_ended log: [{"sig": "started"/"ended", "obj": Node, "reason": StringName}]
var _carry_log: Array[Dictionary] = []


func _ready() -> void:
	print("=== Carry / Throw Tests (Controls v2) ===")
	print("")
	_start_watchdog()
	await _run_tests()
	_finish()


func _finish() -> void:
	_release_all_input()
	print("\n=== Carry Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _start_watchdog() -> void:
	var t := get_tree().create_timer(WATCHDOG_SECONDS, true, false, true)
	t.timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs (a test hung or aborted)" % WATCHDOG_SECONDS)
		_finish())


func _run_tests() -> void:
	_section("CONTRACT — EVENTS / SCRIPTS")
	test_events_signals()
	test_scripts_exist()

	_section("CONTRACT — CRATE SCENE (H)")
	await test_crate_scene_contract()

	_world = _make_world()
	add_child(_world)
	await get_tree().physics_frame
	_connect_carry_log()

	var harness_ok := await _setup_player()

	_section("CONTRACT — PLAYER NODES (I)")
	test_player_nodes()

	if harness_ok:
		_section("RUNTIME — PICK UP")
		await test_pick_up()

		_section("RUNTIME — BLOCKED ACTIONS WHILE CARRYING")
		await test_blocked_actions()

		_section("RUNTIME — CARRY LOCOMOTION")
		await test_carry_locomotion()

		_section("RUNTIME — TAP Y PUTS DOWN")
		await test_tap_puts_down()

		_section("RUNTIME — HOLD Y AIMS, RELEASE CANCELS")
		await test_hold_aim_cancel()

		_section("RUNTIME — HOLD Y + X THROWS")
		await test_hold_aim_throw()

		_section("RUNTIME — HIT WHILE CARRYING DROPS")
		await test_hit_drops()

		_section("RUNTIME — SAVE DATA NEVER HOLDS A CRATE")
		await test_save_never_persists_carry()

		_section("HARNESS — NO LEFTOVER CRATES (v5 FF1)")
		await _ground_player()
		await _clear_loose_crates()
		_assert(_loose_crate_count() == 0, "Leftover crates cleared between tests",
			"%d loose crates remain" % _loose_crate_count())
	else:
		_fail("Carry runtime tests", "skipped: carry system not implemented (see failures above)")

	_section("RUNTIME — THROWN CRATE DAMAGES ENEMY (H)")
	await test_crate_hits_enemy()

	_teardown_world()
	await _frames(3)

	_section("SOLID PROPS — FIELD ZONE (J4)")
	await test_field_zone_solid_props()


# ========== CONTRACT ==========

func test_events_signals() -> void:
	for sig in [&"carry_started", &"carry_ended", &"carryable_in_range"]:
		_assert(Events.has_signal(sig), "Events.%s signal exists" % sig)


func test_scripts_exist() -> void:
	_assert(ResourceLoader.exists(CRATE_SCENE), "carryable_crate.tscn exists (Package H)")
	_assert(ResourceLoader.exists(CARRY_COMPONENT_SCRIPT), "carry_component.gd exists (Package I)",
		"not implemented")
	_assert(ResourceLoader.exists(CARRY_STATE_SCRIPT), "carry_state.gd exists (Package I)",
		"not implemented")
	_assert(ResourceLoader.exists(THROW_AIM_STATE_SCRIPT), "throw_aim_state.gd exists (Package I)",
		"not implemented")


func test_crate_scene_contract() -> void:
	if not ResourceLoader.exists(CRATE_SCENE):
		_fail("Crate scene contract", "not implemented: %s" % CRATE_SCENE)
		return
	_crate_scene = load(CRATE_SCENE) as PackedScene
	if _crate_scene == null:
		_fail("Crate scene loads", "load failed")
		return
	var crate: Node = _crate_scene.instantiate()
	add_child(crate)
	await get_tree().process_frame
	_assert(crate is RigidBody3D, "Crate root is a RigidBody3D")
	var methods_ok := true
	var missing: Array[String] = []
	for m in ["interact", "can_pick_up", "pick_up", "put_down", "throw"]:
		if not crate.has_method(m):
			methods_ok = false
			missing.append(m)
	_assert(methods_ok, "Crate exposes interact / can_pick_up / pick_up / put_down / throw",
		"missing %s" % str(missing))
	_assert(crate.has_signal(&"impacted"), "Crate has signal impacted(body)")
	_assert("is_held" in crate and not crate.is_held, "Crate has is_held (false at rest)")
	_assert(_find_shape(crate) != null, "Crate has a CollisionShape3D with a shape")
	var area := _crate_interact_area(crate)
	_assert(area != null and area.is_in_group(&"interactable"),
		"Crate has an interaction Area3D in group 'interactable'")
	if area and area.has_method("get_prompt_text"):
		_assert(area.get_prompt_text() == "Pick Up", "Crate prompt text is 'Pick Up'",
			"got '%s'" % area.get_prompt_text())
	if crate.has_method("can_pick_up"):
		_assert(crate.can_pick_up(), "Resting crate can be picked up")
	crate.queue_free()
	await get_tree().process_frame


func test_player_nodes() -> void:
	if _player == null:
		_fail("Player nodes", "player failed to spawn")
		return
	var anchor := _player.get_node_or_null("CarryAnchor") as Node3D
	_assert(anchor != null, "Player has CarryAnchor (Marker3D)", "not implemented")
	if anchor:
		_assert(anchor.position.y > 1.5 and anchor.position.y < 2.4,
			"CarryAnchor about 1.9m above the root", "y=%.2f" % anchor.position.y)
	_assert(_carry != null, "Player has CarryComponent", "not implemented")
	if _carry:
		var missing: Array[String] = []
		for m in ["request_pick_up", "put_down", "throw", "drop"]:
			if not _carry.has_method(m):
				missing.append(m)
		for p in ["is_carrying", "held_object"]:
			if not _carry.has_method(p) and not (p in _carry):
				missing.append(p)
		_assert(missing.is_empty(),
			"CarryComponent exposes request_pick_up / put_down / throw / drop / is_carrying / held_object",
			"missing %s" % str(missing))
	var sm: Node = _player.state_machine
	_assert(sm.states.has(&"Carry"), "StateMachine has Carry state", "not implemented")
	_assert(sm.states.has(&"ThrowAim"), "StateMachine has ThrowAim state", "not implemented")


# ========== RUNTIME: CARRY FLOW ==========

func test_pick_up() -> void:
	# Rejected while airborne.
	var crate := await _spawn_crate(_front_of_player(1.6))
	_player.global_position = Vector3(0, 5, 0)
	_player.velocity = Vector3.ZERO
	await _physics_frames(3)
	_assert(not _player.is_on_floor(), "Player is airborne for the rejection check")
	_carry.request_pick_up(crate)
	await _physics_frames(1)
	_assert(not _is_carrying() and not crate.is_held, "request_pick_up rejected while airborne",
		"carrying=%s state=%s" % [_is_carrying(), _state()])
	if _is_carrying():
		_carry.drop(&"forced")
	await _ground_player()

	# Interact handoff (Y -> crate.interact -> CarryComponent.request_pick_up).
	_carry_log.clear()
	crate.interact(_player)
	await _physics_frames(1)
	_assert(_state() == &"Carry", "crate.interact(player) picks it up and enters Carry",
		"state=%s" % _state())
	_assert(_is_carrying() and _held() == crate, "CarryComponent reports carrying the crate",
		"carrying=%s held=%s" % [_is_carrying(), _held()])
	_assert(crate.is_held and crate.freeze, "Held crate is frozen and is_held")
	var anchor := _player.get_node_or_null("CarryAnchor")
	_assert(anchor != null and crate.get_parent() == anchor, "Held crate is parented to CarryAnchor",
		"parent=%s" % crate.get_parent())
	_assert(crate.global_position.y > _player.global_position.y + 1.5, "Held crate is above Amaro's head",
		"crate y=%.2f player y=%.2f" % [crate.global_position.y, _player.global_position.y])
	_assert(_log_has("started", crate), "Events.carry_started(crate) emitted")

	# Rejected while already carrying.
	var other := await _spawn_crate(_front_of_player(-1.6))
	_carry.request_pick_up(other)
	await _physics_frames(1)
	_assert(_held() == crate and not other.is_held, "request_pick_up rejected while already carrying")
	other.queue_free()

	# Leave the crate held for the next tests.


func test_blocked_actions() -> void:
	if not await _ensure_carrying("Blocked actions while carrying"):
		return
	var gm_before = GameManager.current_state
	var checks := [
		["attack (X)", _joy_press(JOY_X), _joy_release(JOY_X)],
		["dodge (B)", _joy_press(JOY_B), _joy_release(JOY_B)],
		["unique ability (R)", _key_press(KEY_R), _key_release(KEY_R)],
		["lock-on (RT)", _joy_axis(JOY_AXIS_RT, 1.0), _joy_axis(JOY_AXIS_RT, 0.0)],
		["Command Menu (Q)", _key_press(KEY_Q), _key_release(KEY_Q)],
	]
	for c in checks:
		_player.state_machine._unhandled_input(c[1])
		await _physics_frames(2)
		_player.state_machine._unhandled_input(c[2])
		_assert(_state() == &"Carry" and _is_carrying(),
			"%s is blocked while carrying" % c[0], "state=%s carrying=%s" % [_state(), _is_carrying()])
	_assert(GameManager.current_state == gm_before, "GameManager state unchanged (no tactical mode)")
	_assert(not _player.is_locked_on, "No lock-on acquired while carrying")


func test_carry_locomotion() -> void:
	if not await _ensure_carrying("Carry locomotion"):
		return
	var start: Vector3 = _player.global_position
	Input.action_press(&"move_up")
	await _physics_frames(40)
	Input.action_release(&"move_up")
	var moved := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	_assert(moved > 1.0 and _is_carrying(), "Amaro can walk while carrying",
		"moved=%.2f carrying=%s state=%s" % [moved, _is_carrying(), _state()])
	await _physics_frames(20)

	# Jump (A) while carrying.
	await _ground_player_keep_state()
	Input.parse_input_event(_joy_press(JOY_A))
	await _physics_frames(3)
	Input.parse_input_event(_joy_release(JOY_A))
	await _physics_frames(3)
	_assert(_player.velocity.y > 0.5 or not _player.is_on_floor(), "Amaro can jump (A) while carrying",
		"vy=%.2f state=%s" % [_player.velocity.y, _state()])
	_assert(_is_carrying(), "Still carrying after jumping")
	await _ground_player_keep_state()
	_assert(_state() == &"Carry" and _is_carrying(), "Back in Carry after landing", "state=%s" % _state())


func test_tap_puts_down() -> void:
	if not await _ensure_carrying("Tap Y puts the crate down"):
		return
	var crate: Node = _held()
	_carry_log.clear()
	Input.parse_input_event(_joy_press(JOY_Y))
	await _physics_frames(3)  # well under 0.25s
	Input.parse_input_event(_joy_release(JOY_Y))
	await _physics_frames(6)
	_assert(not _is_carrying(), "Tap Y puts the crate down", "state=%s" % _state())
	_assert(_state() == &"Idle" or _state() == &"Run", "Tap Y returns to Idle/Run", "state=%s" % _state())
	_assert(is_instance_valid(crate) and not crate.is_held and crate.get_parent() != _player.get_node_or_null("CarryAnchor"),
		"Put-down crate is released from the anchor")
	if is_instance_valid(crate):
		var flat := Vector2(crate.global_position.x - _player.global_position.x,
			crate.global_position.z - _player.global_position.z).length()
		_assert(flat > 0.5 and flat < 3.0, "Crate placed in front of Amaro", "dist=%.2f" % flat)
		_assert(absf(crate.global_position.y) < 0.3, "Crate snapped to the ground",
			"y=%.2f" % crate.global_position.y)
		await _physics_frames(30)
		_assert(crate.can_pick_up(), "Put-down crate is liftable again")
	_assert(_log_has("ended", crate, &"put_down"), "carry_ended(crate, &\"put_down\") emitted",
		str(_carry_log))


func test_hold_aim_cancel() -> void:
	if not await _ensure_carrying("Hold Y (>=0.25s) enters ThrowAim"):
		return
	Input.parse_input_event(_joy_press(JOY_Y))
	await _real_seconds(HOLD_SECONDS)
	await _physics_frames(2)
	_assert(_state() == &"ThrowAim", "Hold Y (>=0.25s) enters ThrowAim", "state=%s" % _state())
	_assert(_is_carrying(), "Still carrying in ThrowAim")

	# Rooted while aiming.
	Input.action_press(&"move_up")
	await _physics_frames(10)
	var xz := Vector2(_player.velocity.x, _player.velocity.z).length()
	Input.action_release(&"move_up")
	_assert(xz < 0.05, "Amaro is rooted in ThrowAim (xz velocity 0)", "xz=%.2f" % xz)

	Input.parse_input_event(_joy_release(JOY_Y))
	await _physics_frames(4)
	_assert(_state() == &"Carry" and _is_carrying(), "Releasing Y without X cancels back to Carry",
		"state=%s carrying=%s" % [_state(), _is_carrying()])


func test_hold_aim_throw() -> void:
	if not await _ensure_carrying("X in ThrowAim throws the crate"):
		return
	var crate: Node = _held()
	_carry_log.clear()
	Input.parse_input_event(_joy_press(JOY_Y))
	await _real_seconds(HOLD_SECONDS)
	await _physics_frames(2)
	if _state() != &"ThrowAim":
		_fail("Hold Y + X throws", "did not enter ThrowAim (state=%s)" % _state())
		Input.parse_input_event(_joy_release(JOY_Y))
		await _physics_frames(2)
		return
	Input.parse_input_event(_joy_press(JOY_X))
	await _physics_frames(3)
	Input.parse_input_event(_joy_release(JOY_X))
	await _physics_frames(2)
	_assert(not _is_carrying(), "X in ThrowAim throws the crate", "state=%s" % _state())
	_assert(_state() == &"Idle" or _state() == &"Run",
		"After the throw Amaro returns to Idle", "state=%s" % _state())
	if is_instance_valid(crate):
		_assert(not crate.is_held and not crate.freeze, "Thrown crate is a live physics body")
		_assert(crate.linear_velocity.length() > 1.0, "Thrown crate is released with velocity",
			"v=%.2f" % crate.linear_velocity.length())
	else:
		_fail("Thrown crate is released with velocity", "crate freed immediately")
	_assert(_log_has("ended", crate, &"thrown"), "carry_ended(crate, &\"thrown\") emitted", str(_carry_log))
	Input.parse_input_event(_joy_release(JOY_Y))
	await _physics_frames(2)

	# Lands on the world, stays liftable (no fall > 6m here).
	var settled := false
	for i in 300:
		await get_tree().physics_frame
		if is_instance_valid(crate) and crate.can_pick_up():
			settled = true
			break
	_assert(settled, "Thrown crate that hits the world settles and is liftable again")


func test_hit_drops() -> void:
	if not await _ensure_carrying("Taking damage drops the crate"):
		return
	var crate: Node = _held()
	_carry_log.clear()
	_player.take_damage(5.0, null)
	await _physics_frames(3)
	_assert(not _is_carrying(), "Taking damage drops the crate", "state=%s" % _state())
	_assert(is_instance_valid(crate) and not crate.is_held
			and crate.get_parent() != _player.get_node_or_null("CarryAnchor"),
		"Dropped crate is not orphaned on the anchor")
	_assert(_log_has("ended", crate, &"hit"), "carry_ended(crate, &\"hit\") emitted", str(_carry_log))
	_assert(_state() != &"Carry" and _state() != &"ThrowAim", "Player left Carry after the hit",
		"state=%s" % _state())
	# Let flinch + hit stop finish.
	await _real_seconds(0.6)
	var bad := _non_finite_nodes(_world)
	_assert(bad.is_empty(), "No non-finite (NaN) transforms after a hit-drop", ", ".join(bad))
	_player.current_hp = _player.max_hp

	# Forced transition (e.g. Flinch / death) while carrying also drops.
	# v5 FF1: a failed pick-up fails loudly (no silent skip, stable count).
	if await _pick_up_fresh("Forced transition out of Carry drops the crate (no orphan)"):
		var c2: Node = _held()
		_player.state_machine.force_transition(&"Flinch")
		await _physics_frames(2)
		_assert(not _is_carrying() and is_instance_valid(c2) and not c2.is_held,
			"Forced transition out of Carry drops the crate (no orphan)")
		await _real_seconds(0.6)


func test_save_never_persists_carry() -> void:
	if not await _pick_up_fresh("Player save data has no carry / held state"):
		_fail("drop(&\"forced\") releases the crate", "skipped: pick-up precondition failed")
		return
	var data: Dictionary = _player.get_save_data()
	var text := JSON.stringify(data).to_lower()
	_assert(not text.contains("carry") and not text.contains("held"),
		"Player save data has no carry / held state")
	_carry.drop(&"forced")
	await _physics_frames(2)
	_assert(not _is_carrying(), "drop(&\"forced\") releases the crate")


func test_crate_hits_enemy() -> void:
	if _crate_scene == null:
		_fail("Thrown crate damages enemy", "not implemented: crate scene")
		return
	if _world == null:
		return
	# Move the player away so the enemy does not aggro it mid-test.
	if _player:
		_player.global_position = Vector3(60, 0.1, 60)
	var enemy_scene = load(ENEMY_SCENE) as PackedScene
	if enemy_scene == null:
		_fail("Thrown crate damages enemy", "enemy.tscn failed to load")
		return
	var enemy: Node3D = enemy_scene.instantiate()
	_world.add_child(enemy)
	enemy.global_position = Vector3(-20, 0, -20)
	await _physics_frames(2)
	var hp_before: float = enemy.current_hp

	# Holder stub with a CarryAnchor, 2.5m from the enemy (H API in isolation).
	var holder := Node3D.new()
	_world.add_child(holder)
	holder.global_position = Vector3(-20, 0, -17.5)
	var anchor := Marker3D.new()
	anchor.name = "CarryAnchor"
	anchor.position = Vector3(0, 0.6, 0)
	holder.add_child(anchor)
	var crate: Node = _crate_scene.instantiate()
	_world.add_child(crate)
	crate.global_position = holder.global_position + Vector3(0, 0, -0.2)
	await _physics_frames(2)
	crate.pick_up(holder)
	var broke := {"v": false, "impacts": 0}
	if crate.has_signal(&"broken"):
		crate.broken.connect(func(): broke.v = true)
	crate.impacted.connect(func(_b): broke.impacts += 1)
	var to_enemy: Vector3 = (enemy.global_position + Vector3(0, 0.8, 0)) - crate.global_position
	crate.throw(to_enemy.normalized() * 12.0 * crate.mass)

	var hit := false
	for i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(enemy) or enemy.current_hp < hp_before:
			hit = true
			break
	_assert(hit, "Thrown crate hitting an enemy reduces enemy HP",
		"hp %.1f -> %.1f, impacts=%d" % [hp_before, enemy.current_hp if is_instance_valid(enemy) else -1.0, broke.impacts])
	if hit and is_instance_valid(enemy):
		var dmg: float = hp_before - enemy.current_hp
		_assert(dmg > 0.0 and dmg <= 20.0, "Crate impact deals small damage (~10)", "dmg=%.1f" % dmg)
	await _real_seconds(0.4)
	_assert(broke.v or not is_instance_valid(crate) or crate.is_queued_for_deletion(),
		"Crate breaks after hitting an enemy")

	if is_instance_valid(enemy):
		enemy.queue_free()
	holder.queue_free()
	if is_instance_valid(crate):
		crate.queue_free()
	await _physics_frames(2)


# ========== J4: SOLID PROPS IN FIELD ZONE ==========

func test_field_zone_solid_props() -> void:
	var scene = load(FIELD_ZONE_SCENE) as PackedScene
	if scene == null:
		_fail("Field zone loads", "field_zone.tscn failed to load")
		return
	var zone: Node3D = scene.instantiate()
	add_child(zone)
	await _physics_frames(4)
	# Block the deferred autosave (it only saves while PLAYING).
	GameManager.change_state(GameManager.GameState.MAIN_MENU)

	var static_crates: Array[Node3D] = []
	var chests: Array[Node] = []
	var carryables: Array[Node] = []
	_collect_props(zone, static_crates, chests, carryables)

	_assert(static_crates.size() > 0, "Field zone has static Prop_Crate placements",
		"found %d" % static_crates.size())
	var unsolid: Array[String] = []
	for c in static_crates:
		if not _has_solid_body(c):
			unsolid.append("%s@%s" % [c.name, c.global_position])
	_assert(unsolid.is_empty(), "Every static Prop_Crate has a StaticBody3D + CollisionShape3D (%d crates)" % static_crates.size(),
		"not solid: %s" % ", ".join(unsolid))

	_assert(chests.size() > 0, "Field zone has chests", "found %d" % chests.size())
	var chest_bad: Array[String] = []
	for ch in chests:
		if not _has_solid_body(ch):
			chest_bad.append("%s@%s" % [ch.name, ch.global_position])
	_assert(chest_bad.is_empty(), "Every chest has a solid StaticBody3D (standable) (%d chests)" % chests.size(),
		"not solid: %s" % ", ".join(chest_bad))
	var chest_interact_ok := true
	for ch in chests:
		if not (ch is Area3D and ch.is_in_group(&"interactable")):
			chest_interact_ok = false
	_assert(chest_interact_ok, "Chests keep their interaction Area3D")

	# Standable: a ray cast down onto a static crate / chest hits its solid body.
	var space := zone.get_world_3d().direct_space_state
	if static_crates.size() > 0:
		_assert(_ray_hits_descendant(space, static_crates[0]),
			"Ray down onto a static crate hits its collision (standable)")
	if chests.size() > 0:
		_assert(_ray_hits_descendant(space, chests[0]),
			"Ray down onto a chest hits its collision (standable)")

	# Liftable crates (H5): 2-3 per zone, one near the field spawn.
	_assert(carryables.size() >= 2, "Field zone has at least 2 carryable crates",
		"found %d" % carryables.size())
	var spawn := Vector3(0, 1, 8)
	if "spawn_position" in zone:
		spawn = zone.spawn_position
	var near_spawn := false
	for c in carryables:
		if (c as Node3D).global_position.distance_to(spawn) < 20.0:
			near_spawn = true
	_assert(near_spawn, "A carryable crate is near the field spawn (within 20m)")
	var stacked_liftable := false
	for c in carryables:
		if (c as Node3D).global_position.y > 0.5:
			stacked_liftable = true
	_assert(not stacked_liftable, "Only ground-level crates are carryable (stacked stay static)")

	print("  INFO: field_zone static crates=%d chests=%d carryable=%d" % [
		static_crates.size(), chests.size(), carryables.size()])

	# Let the deferred autosave timer lapse (skipped because not PLAYING), then free.
	await _real_seconds(0.7)
	zone.queue_free()
	await _frames(3)


func _collect_props(node: Node, crates: Array[Node3D], chests: Array[Node], carryables: Array[Node]) -> void:
	for child in node.get_children():
		var script = child.get_script()
		if script and script.resource_path == CHEST_SCRIPT:
			chests.append(child)
			continue  # chest visual reuses Prop_Crate; don't count it as a crate
		if child.is_in_group(&"carryable") and child is RigidBody3D:
			carryables.append(child)
			continue
		if child is Node3D and child.scene_file_path.ends_with(CRATE_GLTF):
			crates.append(child)
			continue
		_collect_props(child, crates, chests, carryables)


func _has_solid_body(node: Node) -> bool:
	for body in node.find_children("*", "StaticBody3D", true, false):
		if (body as StaticBody3D).collision_layer == 0:
			continue
		for col in body.find_children("*", "CollisionShape3D", true, false):
			if col.shape != null and not col.disabled:
				return true
	return false


func _non_finite_nodes(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Node3D", true, false):
		var t: Transform3D = (n as Node3D).global_transform
		if not t.is_finite():
			out.append(str(n.get_path()))
	return out


func _ray_hits_descendant(space: PhysicsDirectSpaceState3D, prop: Node3D) -> bool:
	# Start just above the prop (~1.06m tall) so roofs / awnings above it don't intercept.
	var top := prop.global_position + Vector3(0, 1.8, 0)
	var bottom := prop.global_position + Vector3(0, -0.2, 0)
	var q := PhysicsRayQueryParameters3D.create(top, bottom, 1)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var collider: Node = hit["collider"]
	return collider == prop or prop.is_ancestor_of(collider)


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
	_carry = _player.get_node_or_null("CarryComponent")
	if not await _wait_on_floor():
		_fail("Player lands on test floor", "never on floor")
		return false
	if _carry == null or _crate_scene == null:
		return false
	for m in ["request_pick_up", "drop"]:
		if not _carry.has_method(m):
			return false
	var sm: Node = _player.state_machine
	return sm.states.has(&"Carry") and sm.states.has(&"ThrowAim")


func _teardown_world() -> void:
	_release_all_input()
	if is_instance_valid(_world):
		_world.queue_free()
	_world = null
	_player = null
	_carry = null
	for child in get_children():
		if child is Node3D:
			child.queue_free()


func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "TestWorld"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	floor_body.add_child(col)
	world.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 6)
	world.add_child(cam)
	cam.current = true
	return world


func _spawn_crate(pos: Vector3) -> Node:
	var crate: Node = _crate_scene.instantiate()
	_world.add_child(crate)
	crate.global_position = pos
	await _physics_frames(2)
	return crate


## World position in front of the player (player faces -Z of its basis).
func _front_of_player(dist: float) -> Vector3:
	var p: Vector3 = _player.global_position
	var fwd: Vector3 = -_player.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, -1)
	var out := p + fwd.normalized() * dist
	out.y = 0.0
	return out


## Make sure the player is carrying a crate; picks a fresh one up if needed.
func _ensure_carrying(context: String = "Carry precondition") -> bool:
	if _is_carrying() and _state() == &"Carry":
		return true
	return await _pick_up_fresh(context)


## v5 FF1: picks up a brand-new crate after clearing every loose crate from the test
## world, so the world never accumulates crates and the pick-up target is unambiguous.
## Fails LOUDLY (counted as a failure naming the test that depended on it) instead of
## returning false silently.
func _pick_up_fresh(context: String = "Carry precondition") -> bool:
	_release_all_input()
	await _ground_player()
	await _clear_loose_crates()
	var crate := await _spawn_crate(_front_of_player(1.6))
	_carry.request_pick_up(crate)
	await _physics_frames(2)
	var ok := _is_carrying() and _state() == &"Carry" and _held() == crate
	if not ok:
		_fail(context, "precondition failed: could not pick up a fresh crate (state=%s carrying=%s held=%s)"
			% [_state(), _is_carrying(), _held()])
	return ok


## v5 FF1: free every crate in the test world that isn't currently held.
func _clear_loose_crates() -> void:
	if _world == null:
		return
	var freed := 0
	for n in _world.find_children("*", "RigidBody3D", true, false):
		if n.is_in_group(&"carryable") or n.has_method(&"can_pick_up"):
			if n == _held():
				continue
			n.queue_free()
			freed += 1
	if freed > 0:
		await _physics_frames(2)


func _loose_crate_count() -> int:
	if _world == null:
		return 0
	var c := 0
	for n in _world.find_children("*", "RigidBody3D", true, false):
		if (n.is_in_group(&"carryable") or n.has_method(&"can_pick_up")) and not n.is_queued_for_deletion():
			c += 1
	return c


## Put the player back on the floor in Idle (drops anything still held).
func _ground_player() -> void:
	if _is_carrying():
		_carry.drop(&"forced")
	_player.velocity = Vector3.ZERO
	await _wait_on_floor(240)
	if _state() != &"Idle":
		_player.state_machine.force_transition(&"Idle")
	await _physics_frames(2)


func _ground_player_keep_state() -> void:
	await _wait_on_floor(240)
	await _physics_frames(2)


func _wait_on_floor(max_frames: int = 120) -> bool:
	for i in max_frames:
		if _player.is_on_floor():
			return true
		await get_tree().physics_frame
	return _player.is_on_floor()


func _state() -> StringName:
	if _player == null or _player.state_machine.current_state == null:
		return &""
	return _player.state_machine.current_state.name


func _is_carrying() -> bool:
	if _carry == null:
		return false
	if _carry.has_method("is_carrying"):
		return _carry.is_carrying()
	if "is_carrying" in _carry:
		return _carry.is_carrying
	return false


func _held() -> Node:
	if _carry == null:
		return null
	if _carry.has_method("held_object"):
		return _carry.held_object()
	if "held_object" in _carry:
		return _carry.held_object
	return null


func _connect_carry_log() -> void:
	if Events.has_signal(&"carry_started"):
		Events.carry_started.connect(func(obj): _carry_log.append({"sig": "started", "obj": obj, "reason": &""}))
	if Events.has_signal(&"carry_ended"):
		Events.carry_ended.connect(func(obj, reason): _carry_log.append({"sig": "ended", "obj": obj, "reason": reason}))


func _log_has(sig: String, obj: Node, reason: StringName = &"") -> bool:
	for e in _carry_log:
		if e.sig == sig and e.obj == obj and (reason == &"" or StringName(e.reason) == reason):
			return true
	return false


func _crate_interact_area(crate: Node) -> Area3D:
	for child in crate.get_children():
		if child is Area3D:
			return child
	return null


func _find_shape(node: Node) -> CollisionShape3D:
	for col in node.find_children("*", "CollisionShape3D", true, false):
		if col.shape != null and col.get_parent() == node:
			return col
	return null


func _release_all_input() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"interact", &"attack"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	Input.parse_input_event(_joy_release(JOY_Y))
	Input.parse_input_event(_joy_release(JOY_B))
	Input.parse_input_event(_joy_release(JOY_A))
	Input.parse_input_event(_joy_release(JOY_X))


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
