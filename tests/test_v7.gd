## v7 tests — zone edges, lit exits, floating interact prompts, hold-to-interact.
##  - ZoneBounds in town / field / dungeon: 4 walls >= 60 m tall (Super Jump
##    apex ~12 m), the ground reaches every inside corner, rays leaving the area
##    at 1 / 15 / 40 m hit a wall, edge visuals use the additive curtain shader;
##    walking into the north edge stops at the edge (real stick input).
##  - Fall recovery: below fall_reset_y the player returns to the last floor.
##  - ZonePortal: ExitHighlight (pad + 4 curtains) on every exit; cyan idle,
##    gold when the player stands in it (real Area3D overlap), back to cyan after.
##  - WorldPrompt: follows the focused interactable, verb on the pill, visible on
##    screen; nearby markers; bottom pill hidden unless carrying.
##  - Hold-to-interact (dungeon lever): short tap does nothing, a 0.9 s hold of A (v8)
##    pulls it; the prompt reads "Hold" and the progress reaches 1.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_Y := 3
const JOY_A := 0  # v8: A is the context (interact) button
const TOWN_SCENE := "res://scenes/zones/town_hub.tscn"
const FIELD_SCENE := "res://scenes/zones/field_zone.tscn"
const DUNGEON_SCENE := "res://scenes/zones/dungeon_zone.tscn"
const WATCHDOG_SECONDS := 300.0

var _zone: Node = null
var _player: Node = null
var _party: Node = null
var _rig: Node = null
var _hold_log: Array = []
var _finished: bool = false


func _ready() -> void:
	print("=== v7 Tests (zone edges, lit exits, world prompts, hold interact) ===")
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs" % WATCHDOG_SECONDS)
		_finish())
	Events.interaction_hold_progress.connect(func(o: Node3D, r: float) -> void: _hold_log.append([o, r]))
	await _run_tests()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all_input()
	Engine.time_scale = 1.0
	print("\n=== V7 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	for path in [TOWN_SCENE, FIELD_SCENE, DUNGEON_SCENE]:
		_section(path.get_file())
		if not await _load_zone(path):
			continue
		_clear_enemies()
		await test_bounds(path.get_file())
		await test_fall_recovery(path.get_file())
		await test_portals(path.get_file())
		if path == TOWN_SCENE:
			await test_walk_into_edge()
			await test_world_prompt_town()
		if path == DUNGEON_SCENE:
			await test_hold_lever()
		_teardown_zone()
		await _frames(5)


# ========== TESTS ==========

func test_bounds(tag: String) -> void:
	var b: Node3D = _zone.get_node_or_null(^"ZoneBounds")
	_assert(b != null, "%s: ZoneBounds present" % tag)
	if b == null:
		return
	var walls := 0
	var tall := true
	var edges := 0
	for c in b.get_children():
		if c is StaticBody3D:
			walls += 1
			var box := (c.get_child(0) as CollisionShape3D).shape as BoxShape3D
			tall = tall and box.size.y >= 60.0 and (c as StaticBody3D).collision_layer & 1 != 0
		elif c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as ShaderMaterial
			if m and m.shader and m.shader.resource_path.ends_with("glow_curtain.gdshader"):
				edges += 1
	_assert(walls == 4 and tall, "%s: 4 World-layer walls, all >= 60 m tall" % tag,
		"walls=%d tall=%s" % [walls, tall])
	_assert(edges == 4, "%s: 4 edge curtains with the glow shader" % tag, "edges=%d" % edges)

	var mn: Vector2 = b.rect_min
	var mx: Vector2 = b.rect_max
	var space := (_zone as Node3D).get_world_3d().direct_space_state
	var corners := [Vector2(mn.x, mn.y), Vector2(mx.x, mn.y), Vector2(mn.x, mx.y), Vector2(mx.x, mx.y)]
	var floored := 0
	for c2 in corners:
		var cc: Vector2 = c2
		var inset := Vector3(cc.x - signf(cc.x - (mn.x + mx.x) * 0.5) * 0.4, 0,
			cc.y - signf(cc.y - (mn.y + mx.y) * 0.5) * 0.4)
		var q := PhysicsRayQueryParameters3D.create(inset + Vector3(0, 3, 0), inset + Vector3(0, -3, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf(hit.position.y) < 0.2:
			floored += 1
	_assert(floored == 4, "%s: ground reaches all 4 inside corners (no gap to fall through)" % tag,
		"floored=%d" % floored)

	var centre := Vector3((mn.x + mx.x) * 0.5, 0, (mn.y + mx.y) * 0.5)
	var blocked := 0
	var tried := 0
	for h in [1.0, 15.0, 40.0]:
		for target in [Vector3(centre.x, h, mn.y - 5), Vector3(centre.x, h, mx.y + 5),
				Vector3(mn.x - 5, h, centre.z), Vector3(mx.x + 5, h, centre.z)]:
			var t3: Vector3 = target
			# Start 1 m inside the edge so props in the middle don't block the ray.
			var from := t3.move_toward(Vector3(centre.x, h, centre.z), 6.0)
			tried += 1
			var q := PhysicsRayQueryParameters3D.create(from, t3, 1)
			var hit := space.intersect_ray(q)
			if not hit.is_empty() and b.is_ancestor_of(hit.collider):
				blocked += 1
	_assert(blocked == tried, "%s: leaving rays at 1/15/40 m all hit a ZoneBounds wall" % tag,
		"%d/%d blocked" % [blocked, tried])


func test_fall_recovery(tag: String) -> void:
	await _wait_on_floor(120)
	var safe: Vector3 = _player.get_last_safe_position()
	_assert(safe.is_finite(), "%s: player records a safe floor position" % tag)
	_player.global_position = Vector3(safe.x, -21.0, safe.z)
	_player.velocity = Vector3(0, -30, 0)
	await _physics_frames(3)
	_assert(_player.global_position.y > -2.0 and _player.global_position.distance_to(safe) < 1.5,
		"%s: falling below -20 m puts the player back on the last floor" % tag,
		"pos=%s safe=%s" % [_player.global_position, safe])
	await _wait_on_floor(120)


func _portals() -> Array:
	var out: Array = []
	for c in _zone.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("zone_portal.gd"):
			out.append(c)
	return out


func test_portals(tag: String) -> void:
	var portals := _portals()
	_assert(portals.size() >= 1, "%s: zone has exits" % tag)
	var ok := true
	for p in portals:
		var hl: Node = p.get_node_or_null(^"ExitHighlight")
		ok = ok and hl != null and hl.get_child_count() == 5
	_assert(ok, "%s: every exit has ExitHighlight (pad + 4 curtains)" % tag)
	if portals.is_empty():
		return
	var portal: Node3D = portals[0]
	_assert(not portal.is_focused() and portal.get_highlight_color() == portal.COLOR_IDLE,
		"%s: exit idles cyan" % tag)
	# Stand in the exit for real (Area3D overlap -> player picks it).
	_player.global_position = portal.global_position + Vector3(0, 0.1, 1.2)
	_player.velocity = Vector3.ZERO
	var picked := await _wait_until(func() -> bool: return _player.get_current_interactable() == portal, 2.0)
	_assert(picked and portal.is_focused() and portal.get_highlight_color() == portal.COLOR_FOCUS,
		"%s: standing in '%s' focuses it and turns it gold" % [tag, portal.interaction_name],
		"picked=%s focused=%s" % [picked, portal.is_focused()])
	await _frames(20)
	var pad_mat: ShaderMaterial = portal.get_node(^"ExitHighlight/Pad").material_override
	var col: Color = pad_mat.get_shader_parameter(&"glow_color")
	_assert(col.r > col.b, "%s: pad shader colour moved to gold" % tag, "colour=%s" % col)
	# Walk away.
	_player.global_position = portal.global_position + Vector3(0, 0.1, 9.0)
	var left := await _wait_until(func() -> bool: return not portal.is_focused(), 2.0)
	_assert(left and portal.get_highlight_color() == portal.COLOR_IDLE,
		"%s: leaving the exit returns it to cyan" % tag)


func test_walk_into_edge() -> void:
	var b: Node3D = _zone.get_node(^"ZoneBounds")
	var edge_z: float = b.rect_min.y   # north edge (town: -52)
	# Open lane west of the north gate (gate portal at x = 0).
	_player.global_position = Vector3(-20, 0.1, edge_z + 3.0)
	_player.velocity = Vector3.ZERO
	if _rig and _rig.get(&"yaw_pivot"):
		_rig.yaw_pivot.rotation.y = 0.0
	await _wait_on_floor(60)
	var min_z := 999.0
	Input.action_press(&"move_up")
	for i in 120:
		await get_tree().physics_frame
		min_z = minf(min_z, _player.global_position.z)
	Input.action_release(&"move_up")
	_assert(min_z >= edge_z - 0.05, "town: walking north stops at the edge",
		"min_z=%.2f edge=%.2f" % [min_z, edge_z])
	_assert(min_z < edge_z + 1.0, "town: ... after actually reaching it (within 1 m)",
		"min_z=%.2f edge=%.2f" % [min_z, edge_z])


func test_world_prompt_town() -> void:
	var wp := _hud("world_prompt.gd")
	var pill := _hud("interaction_prompt.gd")
	_assert(wp != null and pill != null, "town: WorldPrompt + InteractionPrompt HUDs spawned")
	if wp == null:
		return
	# Gate exit, approached from the south with the camera behind the player.
	var gate: Node3D = null
	for p in _portals():
		if p.interaction_name == "Northern Gate":
			gate = p
	_player.global_position = gate.global_position + Vector3(0, 0.1, 1.4)
	_player.velocity = Vector3.ZERO
	if _rig and _rig.get(&"yaw_pivot"):
		_rig.yaw_pivot.rotation.y = 0.0
	await _wait_until(func() -> bool: return _player.get_current_interactable() == gate, 2.0)
	await _frames(30)
	_assert(wp.get_target() == gate and wp.get_label_text() == "Northern Gate",
		"town: world prompt targets the gate with its name",
		"target=%s label='%s'" % [wp.get_target(), wp.get_label_text()])
	_assert(wp.is_prompt_visible(), "town: world prompt is on screen near the gate")
	_assert(pill.get(&"_visible_state") and not pill.get(&"_bg_panel").visible,
		"town: bottom pill stays hidden for interactables (world prompt replaces it)")

	# Square: several NPCs nearby -> markers for the ones not focused.
	_player.global_position = Vector3(0, 0.1, -18)
	await _frames(40)
	var pts: PackedVector2Array = wp.get(&"_markers").points
	_assert(pts.size() >= 1, "town square: nearby interactables get markers", "markers=%d" % pts.size())

	# Battle Mode hides it (Y is the unique ability there).
	Events.battle_mode_changed.emit(true)
	await _frames(3)
	_assert(not wp.is_prompt_visible() and wp.get(&"_markers").points.is_empty(),
		"town: world prompt + markers hidden in Battle Mode")
	Events.battle_mode_changed.emit(false)
	await _frames(3)


func test_hold_lever() -> void:
	var lever: Node3D = _zone.get_node_or_null(^"Lever1")
	_assert(lever != null and lever.requires_hold(), "dungeon: Lever1 is a hold interaction")
	if lever == null:
		return
	await _wait_until(func() -> bool: return not _player.in_battle, 6.0)
	_player.global_position = lever.global_position + Vector3(0, 0.1, 1.0)
	_player.velocity = Vector3.ZERO
	var picked := await _wait_until(func() -> bool: return _player.get_current_interactable() == lever, 2.0)
	_assert(picked and not _player.in_battle, "dungeon: lever targeted in Free Roam",
		"picked=%s battle=%s state=%s" % [picked, _player.in_battle, _player.state_machine.current_state.name])
	var wp := _hud("world_prompt.gd")
	await _frames(10)
	_assert(wp != null and wp.get_label_text().begins_with("Hold"), "dungeon: prompt reads 'Hold · Pull Lever'",
		"label='%s'" % (wp.get_label_text() if wp else "?"))

	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	_hold_log.clear()
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.15)
	await _physics_frames(5)
	var cancelled := _hold_log.any(func(e: Array) -> bool: return e[0] == lever and e[1] < 0.0)
	_assert(not lever.is_on and cancelled, "dungeon: a short A tap does not pull the lever (hold cancelled)",
		"is_on=%s log=%s" % [lever.is_on, _hold_log.size()])
	_assert(_player.state_machine.current_state.name != &"TacticalIdle",
		"dungeon: the tap did not jump or open the Command Menu instead")

	_hold_log.clear()
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.9)
	await _physics_frames(5)
	var full := _hold_log.any(func(e: Array) -> bool: return e[0] == lever and e[1] >= 1.0)
	_assert(lever.is_on and full, "dungeon: holding A 0.9 s pulls the lever (progress reached 1)",
		"is_on=%s full=%s" % [lever.is_on, full])


# ========== HELPERS ==========

func _load_zone(path: String) -> bool:
	var ps = load(path) as PackedScene
	if ps == null:
		_fail("Zone harness", "%s failed to load" % path)
		return false
	GameManager.change_state(GameManager.GameState.PLAYING)
	_zone = ps.instantiate()
	add_child(_zone)
	await _frames(2)
	GameManager.change_state(GameManager.GameState.MAIN_MENU)  # block the entry autosave
	await _frames(45)
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(20)
	_player = _zone.get(&"player")
	if _player == null or not is_instance_valid(_player):
		_fail("Zone harness", "zone has no player")
		return false
	_party = _player.party_system
	_rig = null
	for ch in _zone.get_children():
		if ch.get(&"yaw_pivot") != null:
			_rig = ch
	await _wait_on_floor(240)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	return true


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if _zone.is_ancestor_of(e):
			e.queue_free()


func _teardown_zone() -> void:
	_release_all_input()
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	if _party:
		for m in _party.members:
			var n: Node = m.get("node")
			if is_instance_valid(n) and n != _player and not _zone.is_ancestor_of(n):
				n.queue_free()
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null
	_party = null
	_rig = null


func _hud(script_file: String) -> Node:
	if _zone == null:
		return null
	for ch in _zone.find_children("*", "CanvasLayer", true, false):
		if ch.get_script() and String(ch.get_script().resource_path).ends_with(script_file):
			return ch
	return null


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
			&"jump", &"dodge", &"tactical_mode", &"unique_ability", &"battle_toggle", &"lock_on"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(press: InputEvent, release: InputEvent, hold: float = 0.05) -> void:
	Input.parse_input_event(press)
	await _real_seconds(hold)
	Input.parse_input_event(release)
	await _real_seconds(0.08)


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
