## Battle Test arena tests (Main Menu > Battle Test).
##  - Main menu: "Battle Test" is the first button and has focus; the zone id
##    maps to scenes/zones/battle_test.tscn.
##  - Arena: walled (4 ZoneBounds walls + 4 visible walls, no glow edge), ground
##    reaches every corner, no autosave on entry (story save untouched).
##  - Training Dummy: never aggros / attacks (player 2.5 m away for 3 s), flinches
##    when hit and goes back to idle, dies, and is back with full HP after ~3 s.
##  - Enemy Spawner: 2 hostiles alive near the crystal, they aggro the player,
##    a killed one is replaced after 4 s.
##  - Combo Partner: survives a 5000 hit at full HP, never attacks, wanders but
##    stays inside its 5 m ring, walks back when knocked 9 m out.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const ZONE_SCENE := "res://scenes/zones/battle_test.tscn"
const MENU_SCENE := "res://scenes/menus/main_menu.tscn"
const WATCHDOG_SECONDS := 240.0

var _zone: Node = null
var _player: Node = null
var _party: Node = null
var _autosaves: int = 0
var _finished: bool = false


func _ready() -> void:
	print("=== Battle Test arena tests ===")
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs" % WATCHDOG_SECONDS)
		_finish())
	Events.save_completed.connect(func(slot: int) -> void:
		if slot == -1:
			_autosaves += 1)
	await _run_tests()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	print("\n=== Battle Test Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("MAIN MENU")
	await test_menu()

	_section("ARENA")
	if not await _load_zone():
		return
	await test_arena()
	_section("TRAINING DUMMY")
	await test_dummy()
	_section("ENEMY SPAWNER")
	await test_spawner()
	_section("COMBO PARTNER")
	await test_partner()
	_teardown_zone()
	await _frames(5)


# ========== TESTS ==========

func test_menu() -> void:
	var menu: Control = (load(MENU_SCENE) as PackedScene).instantiate()
	add_child(menu)
	await _frames(3)
	var buttons: Array = []
	for c in menu.get_node(^"VBox").get_children():
		if c is Button:
			buttons.append(c.text)
	_assert(not buttons.is_empty() and buttons[0] == "Battle Test" and buttons[1] == "New Game",
		"Battle Test is the top main-menu option (above New Game)", str(buttons))
	var focused := get_viewport().gui_get_focus_owner()
	_assert(focused != null and focused.name == &"BattleTest", "Battle Test has focus when the menu opens",
		"focus=%s" % focused)
	_assert(menu.has_method(&"_on_battle_test") and menu.battle_test_btn.pressed.is_connected(menu._on_battle_test),
		"Battle Test button is wired to _on_battle_test")
	_assert(SaveManager._zone_id_to_scene("battle_test") == ZONE_SCENE and ResourceLoader.exists(ZONE_SCENE),
		"zone id 'battle_test' maps to the arena scene")
	menu.queue_free()
	await _frames(2)


func test_arena() -> void:
	var b: Node3D = _zone.get_node_or_null(^"ZoneBounds")
	var walls := 0
	var edges := 0
	if b:
		for c in b.get_children():
			if c is StaticBody3D:
				walls += 1
			elif c is MeshInstance3D:
				edges += 1
	var visible_walls := 0
	for c in _zone.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("ArenaWall"):
			visible_walls += 1
	_assert(walls == 4 and edges == 0 and visible_walls == 4,
		"arena walled in: 4 collision walls + 4 visible stone walls (no glow edge)",
		"walls=%d edges=%d visible=%d" % [walls, edges, visible_walls])
	var space := (_zone as Node3D).get_world_3d().direct_space_state
	var floored := 0
	for c in [Vector3(-39.5, 0, -39.5), Vector3(39.5, 0, -39.5), Vector3(-39.5, 0, 39.5), Vector3(39.5, 0, 39.5)]:
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 3, 0), c + Vector3(0, -3, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf(hit.position.y) < 0.2:
			floored += 1
	_assert(floored == 4, "ground reaches all 4 arena corners", "floored=%d" % floored)
	await _real_seconds(1.0)
	_assert(_autosaves == 0, "entering the arena does not autosave (story save untouched)",
		"autosaves=%d" % _autosaves)


func test_dummy() -> void:
	var dummy: Node3D = _zone.dummy
	_assert(dummy != null and dummy.passive and not dummy.invincible, "Training Dummy present (passive, killable)")
	_assert(dummy.is_in_group(&"training_targets"), "training targets are tagged so the AI companion leaves them alone")
	var home: Vector3 = _zone.DUMMY_POS
	_player.global_position = home + Vector3(0, 0.1, 2.5)
	_player.velocity = Vector3.ZERO
	var hp0: float = _player.current_hp
	await _real_seconds(3.0)
	_assert(dummy.ai_state == EnemyBase.AIState.IDLE and _player.current_hp == hp0,
		"dummy never aggros or attacks with the player 2.5 m away for 3 s",
		"state=%s hp %s -> %s" % [dummy.ai_state, hp0, _player.current_hp])

	dummy.take_damage(20.0, _player)
	_assert(dummy.current_hp == dummy.max_hp - 20.0 and dummy.ai_state == EnemyBase.AIState.HURT,
		"hitting the dummy deals damage and flinches it")
	var back := await _wait_until(func() -> bool: return dummy.ai_state == EnemyBase.AIState.IDLE, 2.0)
	await _real_seconds(2.0)
	_assert(back and _player.current_hp == hp0, "after the flinch it goes back to idle, never hits back",
		"state=%s hp=%s" % [dummy.ai_state, _player.current_hp])

	dummy.take_damage(10000.0, _player)
	_assert(dummy.ai_state == EnemyBase.AIState.DEAD, "the dummy can be killed")
	var old_id := dummy.get_instance_id()
	var respawned := await _wait_until(func() -> bool:
		var d = _zone.dummy
		return is_instance_valid(d) and d.get_instance_id() != old_id and d.is_inside_tree(), 5.0)
	var nd: Node3D = _zone.dummy
	_assert(respawned and nd.current_hp == nd.max_hp and nd.global_position.distance_to(home) < 1.6,
		"a fresh dummy is back at its spot with full HP (~3 s)")
	_player.global_position = Vector3(0, 0.1, 30)
	await _real_seconds(4.0)  # let Battle Mode time out


func _hostiles() -> Array:
	var out: Array = []
	for e in _zone.spawner.get_alive():
		out.append(e)
	return out


func test_spawner() -> void:
	var sp: Node3D = _zone.spawner
	_assert(sp != null and sp.get_node_or_null(^"Crystal") != null and sp.get_node_or_null(^"SpawnRing") != null,
		"spawner structure present (plinth, crystal, red ring)")
	var two := await _wait_until(func() -> bool: return sp.get_alive().size() == 2, 3.0)
	var near := true
	for e in _hostiles():
		near = near and (e as Node3D).global_position.distance_to(sp.global_position) < 3.5 \
			and not (e.get_script() as Script).resource_path.ends_with("training_enemy.gd")
	_assert(two and near, "2 hostile enemies spawn at the crystal", "alive=%d" % sp.get_alive().size())

	_player.global_position = sp.global_position + Vector3(0, 0.1, 6.0)
	_player.velocity = Vector3.ZERO
	var aggro := await _wait_until(func() -> bool:
		for e in _hostiles():
			if e.ai_state != EnemyBase.AIState.IDLE:
				return true
		return false, 3.0)
	_assert(aggro, "spawned enemies are hostile (they engage the player)")
	_player.global_position = Vector3(0, 0.1, 30)
	_player.max_hp = 1e6
	_player.current_hp = 1e6

	var victim: Node3D = _hostiles()[0]
	victim.take_damage(1e6, _player)
	await _physics_frames(3)
	_assert(sp.get_alive().size() == 1, "a killed hostile leaves the spawner one short")
	await _real_seconds(2.5)
	_assert(sp.get_alive().size() == 1, "... not replaced instantly (respawn delay)")
	var refilled := await _wait_until(func() -> bool: return sp.get_alive().size() == 2, 3.5)
	_assert(refilled and sp.get_spawned_total() == 3, "... and replaced about 4 s later",
		"alive=%d total=%d" % [sp.get_alive().size(), sp.get_spawned_total()])


func test_partner() -> void:
	var p: Node3D = _zone.partner
	_assert(p != null and p.invincible and p.passive, "Combo Partner present (invincible, passive)")
	var home: Vector3 = _zone.PARTNER_POS
	var leash: float = _zone.PARTNER_LEASH
	p.take_damage(5000.0, _player)
	await _physics_frames(2)
	_assert(p.ai_state != EnemyBase.AIState.DEAD and p.current_hp == p.max_hp,
		"5000 damage: still alive at full HP")
	for i in 5:
		p.take_damage(300.0, _player)
		p.add_stagger(40.0)
		await _real_seconds(0.15)
	_assert(p.ai_state != EnemyBase.AIState.DEAD and p.current_hp == p.max_hp,
		"a combo string + stagger break never kills it")

	# Wander inside the ring (player far away; it never chases or attacks).
	_player.global_position = home + Vector3(0, 0.1, 9.0)
	var hp0: float = _player.current_hp
	await _wait_until(func() -> bool: return p.ai_state == EnemyBase.AIState.IDLE, 6.0)
	var start := p.global_position
	var max_out := 0.0
	var travelled := 0.0
	var last := start
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		await get_tree().physics_frame
		max_out = maxf(max_out, p.distance_from_home())
		travelled += p.global_position.distance_to(last)
		last = p.global_position
	_assert(travelled > 1.0, "it wanders around its area", "travelled=%.2f m" % travelled)
	_assert(max_out <= leash + 0.4, "it stays inside its %.0f m ring" % leash, "max=%.2f m" % max_out)
	_assert(_player.current_hp == hp0, "it never attacks")

	# Knocked far out of the ring -> walks back.
	p.global_position = home + Vector3(9.0, 0.5, 0.0)
	var back := await _wait_until(func() -> bool: return p.distance_from_home() <= leash, 9.0)
	_assert(back, "knocked 9 m out of its ring, it walks back in", "dist=%.2f" % p.distance_from_home())


# ========== HELPERS ==========

func _load_zone() -> bool:
	GameManager.change_state(GameManager.GameState.PLAYING)
	_zone = (load(ZONE_SCENE) as PackedScene).instantiate()
	add_child(_zone)
	await _frames(30)
	_player = _zone.get(&"player")
	if _player == null:
		_fail("Zone harness", "no player")
		return false
	_party = _player.party_system
	for i in 240:
		if _player.is_on_floor():
			break
		await get_tree().physics_frame
	_assert(_player.is_on_floor(), "player spawns on the arena floor")
	return true


func _teardown_zone() -> void:
	if _party:
		for m in _party.members:
			var n: Node = m.get("node")
			if is_instance_valid(n) and n != _player and not _zone.is_ancestor_of(n):
				n.queue_free()
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout_s * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _real_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


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
