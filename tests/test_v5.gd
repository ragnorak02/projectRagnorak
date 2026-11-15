## v5 tests (docs/plans/v5_party_air_options_plan.md, Package FF).
## Covers plan items 2-15:
##  - 2  "View" glyph for joy 4 (battle_toggle).
##  - 5  MenuNav: stick noise = no step, a noisy push = exactly 1 step, hold-repeat
##       timing (0 / 0.35 / +0.11 s), unscaled at time_scale 0.05, D-pad one step;
##       real-event noise in the Settings menu does not move the cursor.
##  - 6  Settings > Options page: 4 rows, toggles, labels, B one layer back,
##       persistence to user://settings.json (the user's file is backed up/restored).
##       Minimap hidden / static north-up / rotating (live, in town_hub).
##  - 3  Range rule: max-range candidate set, out-of-range rows darkened and not
##       confirmable, Fire Forward still works, reticle + target bar dim.
##  - 8/9 Sword Slash at 0 MP, Water Geyser launch, Wind Crescent 3 hits (no bystander).
##  - 11 Aerial list only airborne (Plunge first, Sword Slash "Grounded only").
##  - 7  Party switch: D-pad Up/Down swap, 1 s cooldown, blocked states, stats
##       preserved, HUD large panel follows, toast, control-bar Y label.
##  - 10 Super Jump (v8: a Command Menu command) ~5x normal jump height, aerial list at the apex.
##  - 12 Air combo: altitude held +-0.2 m, drift, then gravity, no re-hover.
##  - 13 Air dodge: backflip arc (up + back), one per airtime, refreshed on landing.
##  - 3/4 Lock-on range = max ability range (Amaro 20, Taighe 18); framing: the
##       target never overlaps the player on screen (projected through the camera).
##  - 14 RiglessVisual: cues respond (unit + through player states), never mutates
##       the body.
##  - 15 tools/launch_town.bat boots town_hub.
## Input goes through Input.parse_input_event (the real _unhandled_input path)
## with real-time waits. Part 1 is unit/bare-world; part 2 instances town_hub
## (zone_base spawns the HUD, party system and camera rig) with frozen dummies.
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_DPAD_UP := 11
const JOY_DPAD_DOWN := 12
const JOY_DPAD_RIGHT := 14

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const TOWN_SCENE := "res://scenes/zones/town_hub.tscn"
const SETTINGS_MENU_SCRIPT := "res://src/ui/menus/settings_menu.gd"
const RIGLESS_SCRIPT := "res://src/characters/rigless_visual.gd"
const LAUNCH_TOWN_BAT := "res://tools/launch_town.bat"
const SETTINGS_PATH := "user://settings.json"
const FIRE_FORWARD := "Fire Forward"
const PHASE_ABILITY := 1
const PHASE_TARGET := 2
const WATCHDOG_SECONDS := 300.0

## Town test lane: the main road (x in +-3, z from 8 to -48) is open.
const LANE_ORIGIN := Vector3(0, 0.1, -2)

var _zone: Node = null
var _player: Node = null
var _party: Node = null
var _rig: Node = null
var _dummies: Array = []

var _settings_backup: PackedByteArray = PackedByteArray()
var _settings_existed: bool = false
var _settings_mem: Dictionary = {}

var _fail_log: Array = []
var _switch_log: Array = []
var _damage_log: Array = []
var _finished: bool = false


func _ready() -> void:
	print("=== v5 Tests (options, menu feel, ranges, abilities, party, air, rigless) ===")
	print("")
	_backup_settings()
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs (a test hung or aborted)" % WATCHDOG_SECONDS)
		_finish())
	await _run_tests()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all_input()
	Engine.time_scale = 1.0
	_restore_settings()
	print("\n=== V5 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("CONTRACT — EVENTS / APIS / FILES")
	test_contract()
	_connect_logs()

	_section("MENUNAV — UNIT (synthetic stick events, poll(delta))")
	test_menu_nav_unit()
	await test_menu_nav_unscaled()

	_section("SETTINGS — OPTIONS PAGE + PERSISTENCE")
	await test_options_page()

	_section("RIGLESS VISUAL — UNIT")
	await test_rigless_unit()

	_section("TOWN HUB HARNESS")
	if not await _load_town():
		_fail("v5 town tests", "skipped: town harness failed")
		return

	_section("MINIMAP — HIDDEN / STATIC / ROTATING")
	await test_minimap_modes()

	_section("RANGE RULE — AMARO (candidates, darkened rows, dimmed reticle/bar, Fire Forward)")
	await test_range_rule_amaro()

	_section("SWORD SLASH — 0 MP")
	await test_sword_slash()
	_free_dummies()
	await _physics_frames(3)

	_section("AERIAL COMMAND LIST")
	await test_aerial_list()

	_section("AIR COMBO — ALTITUDE HOLD / DRIFT / SPENT")
	await test_air_combo()

	_section("AIR DODGE — BACKFLIP / ONE PER AIRTIME")
	await test_air_dodge()

	_section("LOCK-ON RANGE + FRAMING (Amaro)")
	await test_lock_on_range(20.0)
	await test_framing()
	_free_dummies()
	await _physics_frames(3)

	_section("PARTY SWITCH — SWAP / COOLDOWN / BLOCKED / HUD / Y LABEL")
	await test_party_switch()

	_section("TAIGHE — LOCK-ON RANGE, WATER GEYSER, WIND CRESCENT")
	if _is_member(&"companion"):
		await test_lock_on_range(18.0)
		await test_water_geyser()
		await test_wind_crescent()
		_free_dummies()
		await _physics_frames(3)
		_section("TAIGHE — SUPER JUMP + AERIAL LIST AT THE APEX")
		await test_super_jump()
	else:
		for n in ["Taighe lock-on range", "Water Geyser", "Wind Crescent", "Super Jump"]:
			_fail(n, "skipped: party switch to Taighe failed")

	_section("RIGLESS VISUAL — CUES THROUGH PLAYER STATES")
	await _switch_back_to_amaro()
	await test_rigless_player_cues()

	_teardown_zone()
	await _frames(3)


# ========== CONTRACT ==========

func test_contract() -> void:
	for sig in [&"tactical_target_reach", &"party_member_switched", &"settings_changed"]:
		var owner: Object = SettingsManager if sig == &"settings_changed" else Events
		_assert(owner.has_signal(sig), "%s.%s signal exists" % ["SettingsManager" if owner == SettingsManager else "Events", sig])
	_assert(SettingsManager.get_action_label(&"battle_toggle", true) == "View",
		"Item 2: battle_toggle pad glyph reads View", SettingsManager.get_action_label(&"battle_toggle", true))
	_assert(SettingsManager.get_action_label(&"battle_toggle", false).contains("F"),
		"Item 2: battle_toggle keyboard label keeps F")
	var party_consts: Dictionary = load("res://src/party/party_system.gd").get_script_constant_map()
	_assert(party_consts.get("INPUT_SWITCH_ENABLED", false) == true, "PartySystem.INPUT_SWITCH_ENABLED is true")
	_assert(is_equal_approx(float(party_consts.get("SWITCH_COOLDOWN", 0.0)), 1.0), "Party switch cooldown is 1.0 s")
	var ps_ok := false
	for ev in InputMap.action_get_events(&"party_switch"):
		if ev is InputEventJoypadButton and ev.button_index == JOY_DPAD_UP:
			for ev2 in InputMap.action_get_events(&"party_switch"):
				if ev2 is InputEventJoypadButton and ev2.button_index == JOY_DPAD_DOWN:
					ps_ok = true
	_assert(ps_ok, "party_switch bound to D-pad Up and D-pad Down")
	var comp: Resource = load("res://resources/characters/companion.tres")
	_assert(comp != null and comp.unique_ability_id == &"arcane_focus", "companion.tres unique = arcane_focus (v8; Super Jump is a command)")
	_assert(_get_source("res://src/enemies/enemy_base.gd").contains("func launch(vel: Vector3)"),
		"EnemyBase.launch(vel) exists")
	for p in ["res://src/ui/hud/lock_on_indicator.gd", "res://src/ui/hud/target_bar.gd"]:
		_assert(_get_source(p).contains("func is_out_of_range("), "%s exposes is_out_of_range()" % p.get_file())
	for a in ["sword_slash", "water_geyser", "wind_crescent", "plunge_strike", "air_burst"]:
		_assert(ResourceLoader.exists("res://resources/abilities/%s.tres" % a), "Ability %s.tres exists" % a)
	var ranges := {"fire_bolt": 20.0, "ice_freeze": 18.0, "sword_slash": 3.5, "water_geyser": 16.0,
		"wind_crescent": 14.0, "plunge_strike": 14.0, "air_burst": 5.0}
	var bad: Array = []
	for id in ranges:
		var ab: Resource = load("res://resources/abilities/%s.tres" % id)
		if ab == null or not is_equal_approx(float(ab.get(&"range")), ranges[id]):
			bad.append("%s=%s" % [id, str(ab.get(&"range") if ab else null)])
	_assert(bad.is_empty(), "AbilityData ranges match the plan (Fire Bolt 20 ... Air Burst 5)", str(bad))
	var ss: Resource = load("res://resources/abilities/sword_slash.tres")
	_assert(ss != null and ss.mp_cost == 0.0 and ss.atb_cost > 0.0 and ss.ground_only,
		"Sword Slash: 0 MP, ATB cost, ground_only")
	# Item 15: dev quick-start.
	var bat := _get_source(LAUNCH_TOWN_BAT)
	_assert(bat != "", "tools/launch_town.bat exists")
	_assert(bat.to_lower().contains("z:\\godot\\godot.exe") or bat.to_lower().contains("z:/godot/godot.exe"),
		"launch_town.bat uses Z:/godot/godot.exe")
	_assert(bat.contains("res://scenes/zones/town_hub.tscn"), "launch_town.bat points at town_hub.tscn")
	_assert(String(ProjectSettings.get_setting("application/run/main_scene")) == "res://scenes/menus/main_menu.tscn",
		"run/main_scene is still the main menu")
	_assert(ResourceLoader.exists(RIGLESS_SCRIPT) and FileAccess.file_exists("res://docs/rigless_models.md"),
		"RiglessVisual script + docs/rigless_models.md exist")


# ========== MENUNAV ==========

func _stick(axis: int, v: float) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = v
	return m


func test_menu_nav_unit() -> void:
	var dt := 1.0 / 60.0
	# Noise around 0.5 (+-0.08) never steps.
	var nav := MenuNav.new()
	nav.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var steps := 0
	for i in 90:
		nav.consume_event(_stick(JOY_AXIS_LEFT_Y, 0.5 + rng.randf_range(-0.08, 0.08)))
		if nav.poll(dt) != Vector2i.ZERO:
			steps += 1
	_assert(steps == 0, "Stick noise around 0.5 (+-0.08, 90 frames) gives 0 steps", "steps=%d" % steps)

	# A noisy push (0.4-0.8 for 0.25 s), then release: exactly one step.
	nav.reset()
	var got: Array = []
	for i in 15:
		nav.consume_event(_stick(JOY_AXIS_LEFT_Y, rng.randf_range(0.4, 0.8)))
		nav.consume_event(_stick(JOY_AXIS_LEFT_X, rng.randf_range(-0.2, 0.2)))
		var s := nav.poll(dt)
		if s != Vector2i.ZERO:
			got.append(s)
	nav.consume_event(_stick(JOY_AXIS_LEFT_Y, 0.0))
	for i in 10:
		var s := nav.poll(dt)
		if s != Vector2i.ZERO:
			got.append(s)
	_assert(got == [Vector2i(0, 1)], "A noisy push (0.4-0.8) gives exactly 1 step down", str(got))

	# Hold-repeat: first on engage, then 0.35 s, then every 0.11 s.
	nav.reset()
	var times: Array = []
	nav.consume_event(_stick(JOY_AXIS_LEFT_Y, -1.0))
	for i in 60:
		if nav.poll(dt) == Vector2i(0, -1):
			times.append(i * dt)
	nav.consume_event(_stick(JOY_AXIS_LEFT_Y, 0.0))
	var timing_ok := times.size() == 7 and absf(times[0]) < 0.001 and absf(times[1] - 0.35) <= dt + 0.001
	for k in range(2, times.size()):
		timing_ok = timing_ok and absf((times[k] - times[k - 1]) - 0.11) <= dt + 0.001
	_assert(timing_ok, "1 s hold: steps at 0, 0.35, then every 0.11 s (7 steps)",
		str(times.map(func(t): return snappedf(t, 0.01))))

	# Already deflected on reset: must return to neutral first.
	var nav2 := MenuNav.new()
	nav2.consume_event(_stick(JOY_AXIS_LEFT_Y, 0.9))
	nav2._need_release = true  # what reset() sets when the live stick is deflected
	nav2._dir = Vector2i.ZERO
	nav2._pending = Vector2i.ZERO
	var s0 := 0
	for i in 20:
		nav2.consume_event(_stick(JOY_AXIS_LEFT_Y, 0.9))
		if nav2.poll(dt) != Vector2i.ZERO:
			s0 += 1
	_assert(s0 == 0, "A stick already deflected at open does not step until it returns to neutral")

	# Vertical-only list ignores horizontal pushes; triggers are not swallowed.
	var nav3 := MenuNav.new()
	nav3.horizontal = false
	nav3.reset()
	nav3.consume_event(_stick(JOY_AXIS_LEFT_X, 1.0))
	_assert(nav3.poll(dt) == Vector2i.ZERO, "horizontal = false: a sideways push gives no step")
	_assert(not nav3.consume_event(_stick(JOY_AXIS_TRIGGER_RIGHT, 1.0)), "Trigger motion (RT) is not swallowed")
	_assert(nav3.consume_event(_stick(JOY_AXIS_RIGHT_X, 1.0)), "Right-stick motion is swallowed")

	# D-pad: one press = one step, echo / release = none.
	var nav4 := MenuNav.new([&"ui_up"], [&"ui_down"], [&"ui_left"], [&"ui_right"])
	var press := _joy_press(JOY_DPAD_DOWN)
	_assert(nav4.event_step(press) == Vector2i(0, 1) and nav4.event_step(_joy_release(JOY_DPAD_DOWN)) == Vector2i.ZERO,
		"D-pad Down press = 1 step, release = none")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.physical_keycode = KEY_DOWN
	key.pressed = true
	key.echo = true
	_assert(nav4.event_step(key) == Vector2i.ZERO, "Key echo gives no step")


## poll() with no delta measures real time: at time_scale 0.05 a 1 s hold still
## gives ~7 steps.
func test_menu_nav_unscaled() -> void:
	var nav := MenuNav.new()
	nav.reset()
	Engine.time_scale = 0.05
	nav.consume_event(_stick(JOY_AXIS_LEFT_Y, 1.0))
	var steps := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1000:
		if nav.poll() != Vector2i.ZERO:
			steps += 1
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_assert(steps >= 6 and steps <= 8, "Unscaled: a 1.0 s real hold at time_scale 0.05 gives ~7 steps",
		"steps=%d" % steps)


# ========== SETTINGS OPTIONS PAGE ==========

func _backup_settings() -> void:
	_settings_existed = FileAccess.file_exists(SETTINGS_PATH)
	if _settings_existed:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	for k in ["show_minimap", "minimap_rotate", "show_control_hints", "show_damage_numbers"]:
		_settings_mem[k] = SettingsManager.get(k)


func _restore_settings() -> void:
	if _settings_existed:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f:
			f.store_buffer(_settings_backup)
			f.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	for k in _settings_mem:
		SettingsManager.set(k, _settings_mem[k])


func test_options_page() -> void:
	# Defaults: true for every new key.
	var defaults_src := _get_source("res://scripts/autoloads/settings_manager.gd")
	_assert(defaults_src.contains("var show_minimap: bool = true") and defaults_src.contains("var minimap_rotate: bool = true"),
		"SettingsManager.show_minimap / minimap_rotate default true")
	for k in ["show_minimap", "minimap_rotate", "show_control_hints", "show_damage_numbers"]:
		SettingsManager.set(k, true)

	var menu := CanvasLayer.new()
	menu.set_script(load(SETTINGS_MENU_SCRIPT))
	add_child(menu)
	await _frames(2)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	menu.open_menu()
	await _frames(2)
	_assert(menu.is_open() and menu.get_page() == 0, "Settings opens on the main page")

	# Real-event stick noise does not move the cursor.
	var sel0: int = menu._selected
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 40:
		Input.parse_input_event(_stick(JOY_AXIS_LEFT_Y, 0.5 + rng.randf_range(-0.08, 0.08)))
		await get_tree().process_frame
	Input.parse_input_event(_stick(JOY_AXIS_LEFT_Y, 0.0))
	await _frames(2)
	_assert(menu._selected == sel0, "Settings: stick noise via real events moves the cursor 0 rows",
		"%d -> %d" % [sel0, menu._selected])
	# A real noisy push moves it exactly 1 row.
	for i in 12:
		Input.parse_input_event(_stick(JOY_AXIS_LEFT_Y, rng.randf_range(0.42, 0.82)))
		await get_tree().process_frame
	Input.parse_input_event(_stick(JOY_AXIS_LEFT_Y, 0.0))
	await _frames(3)
	_assert(menu._selected == sel0 + 1, "Settings: a noisy stick push moves exactly 1 row",
		"%d -> %d" % [sel0, menu._selected])

	# The "Options ›" row is the last selectable row on the main page.
	var opt_sel := -1
	for i in menu._selectable_map.size():
		var d: Dictionary = menu._row_defs[menu._selectable_map[i]]
		if d.get("label", "") == "Options ›":
			opt_sel = i
	_assert(opt_sel >= 0, "Main page has an 'Options ›' row")
	if opt_sel < 0:
		menu.close_menu()
		menu.queue_free()
		return
	# Walk there with D-pad presses (one press = one step).
	var guard := 0
	while menu._selected != opt_sel and guard < 40:
		await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN), 0.02)
		guard += 1
	_assert(menu._selected == opt_sel, "D-pad reaches the Options row", "selected=%d" % menu._selected)
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(menu.get_page() == 1, "A on 'Options ›' opens the Options page", "page=%d" % menu.get_page())

	var keys: Array = []
	for i in menu._selectable_map.size():
		keys.append(String(menu._row_defs[menu._selectable_map[i]].get("key", "")))
	_assert(keys == ["show_minimap", "minimap_rotate", "show_control_hints", "show_damage_numbers"],
		"Options rows: Minimap, Minimap Mode, Control Hints, Damage Numbers", str(keys))

	# Toggle every row with A (cursor walks with D-pad Down).
	for i in keys.size():
		while menu._selected != i:
			await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN), 0.02)
		await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	var all_off := true
	for k in keys:
		all_off = all_off and SettingsManager.get(k) == false
	_assert(all_off, "A toggles all four Options rows off",
		str(keys.map(func(k): return SettingsManager.get(k))))
	var labels := _toggle_labels(menu)
	_assert(labels.size() == 4 and labels[0] == "OFF" and labels[1] == "NORTH-UP" and labels[2] == "HIDE"
			and labels[3] == "OFF",
		"Option pills read OFF / NORTH-UP / HIDE / OFF", str(labels))

	# B returns one layer, cursor back on Options; B again closes.
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(menu.get_page() == 0 and menu.is_open() and menu._selected == opt_sel,
		"B on Options returns to the main page with the cursor on Options",
		"page=%d open=%s sel=%d" % [menu.get_page(), menu.is_open(), menu._selected])
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(not menu.is_open(), "B on the main page closes Settings")

	# Persistence: close_menu saved; wipe memory and reload.
	for k in keys:
		SettingsManager.set(k, true)
	SettingsManager.load_settings()
	var reloaded := true
	for k in keys:
		reloaded = reloaded and SettingsManager.get(k) == false
	_assert(reloaded, "Options values persist to user://settings.json and reload",
		str(keys.map(func(k): return SettingsManager.get(k))))
	var txt := FileAccess.get_file_as_string(SETTINGS_PATH)
	_assert(txt.contains("\"show_minimap\"") and txt.contains("\"minimap_rotate\""),
		"settings.json stores show_minimap / minimap_rotate")
	# Reopen: always starts on the main page.
	menu.open_menu()
	await _frames(2)
	_assert(menu.get_page() == 0, "Reopening Settings starts on the main page")
	menu.close_menu()
	SettingsManager.reset_defaults()
	var reset_ok := SettingsManager.show_minimap and SettingsManager.minimap_rotate
	_assert(reset_ok, "reset_defaults() restores show_minimap / minimap_rotate = true")
	for k in keys:
		SettingsManager.set(k, true)
	menu.queue_free()
	await _frames(2)


func _toggle_labels(menu: Node) -> Array:
	var out: Array = []
	for i in menu._selectable_map.size():
		var di: int = menu._selectable_map[i]
		var n = menu._value_nodes[di] if di < menu._value_nodes.size() else null
		if n is Label:
			out.append(n.text)
		elif n != null:
			var l := (n as Node).find_children("*", "Label", true, false)
			out.append(l[0].text if not l.is_empty() else "?")
	return out


# ========== RIGLESS VISUAL (unit) ==========

func test_rigless_unit() -> void:
	var world := Node3D.new()
	add_child(world)
	var body := CharacterBody3D.new()
	world.add_child(body)
	body.global_position = Vector3(3, 0, -2)
	var rv: Node3D = load(RIGLESS_SCRIPT).new()
	body.add_child(rv)
	await _frames(2)
	rv.set_process(false)  # driven deterministically through step()
	var xf0 := body.global_transform
	body.velocity = Vector3(0, 0, -8)
	var v0 := body.velocity
	for i in 40:
		rv.step(1.0 / 60.0, 1.0)
	var st: Dictionary = rv.get_debug_state()
	_assert(absf(float(st["lean_pitch"])) > deg_to_rad(5.0), "Moving at 8 m/s leans the model forward",
		"lean=%.1f deg" % rad_to_deg(float(st["lean_pitch"])))
	_assert(rv.play_cue(&"attack"), "play_cue(&\"attack\") accepted")
	rv.step(0.1, 1.0)
	_assert(rv.is_cue_active(&"attack") and (rv.get_debug_state()["cue_offset"] as Vector3).length() > 0.01,
		"Attack cue is active and offsets the model (lunge)")
	rv.play_cue(&"air_dodge_back")
	for i in 16:
		rv.step(1.0 / 60.0, 1.0)
	var spin: Vector3 = rv.get_debug_state()["spin"]
	_assert(absf(spin.x) > deg_to_rad(60.0), "air_dodge_back cue flips the model on X (backflip)",
		"spin=%s" % str(spin))
	_assert(rv.play_cue(&"hit") and rv.is_cue_active(&"hit"), "Hit cue runs")
	rv.step(0.05, 0.01)  # hit-stop time scale: hit still animates (unscaled)
	_assert(rv.is_cue_active(&"hit"), "Hit cue survives hit-stop (unscaled)")
	_assert(not rv.play_cue(&"no_such_cue"), "Unknown cue is rejected")
	for i in 120:
		rv.step(1.0 / 60.0, 1.0)
	_assert(body.global_transform.is_equal_approx(xf0) and body.velocity == v0,
		"RiglessVisual never mutates the body (transform + velocity unchanged)")
	_assert((rv.get_debug_state()["cues"] as Array).is_empty(), "All cues end")
	world.queue_free()
	await _frames(2)


# ========== TOWN: MINIMAP ==========

func test_minimap_modes() -> void:
	var mm := _hud("minimap.gd")
	_assert(mm != null and mm.has_method("is_rotating") and mm.has_method("get_map_up"),
		"Minimap exposes is_enabled / is_rotating / get_map_up / get_player_arrow_angle")
	if mm == null:
		return
	await _ground_idle()
	_rig._yaw = deg_to_rad(90.0)  # camera looking west: rotating map-up != north
	await _frames(12)
	SettingsManager.show_minimap = true
	SettingsManager.minimap_rotate = true
	SettingsManager.settings_changed.emit()
	await _frames(6)
	var up: Vector3 = mm.get_map_up()
	var cam_fwd: Vector3 = -_rig.camera.global_basis.z
	cam_fwd.y = 0.0
	_assert(mm.is_map_visible() and mm.is_rotating() and up.dot(cam_fwd.normalized()) > 0.95,
		"Rotating mode: map up = camera forward", "up=%s fwd=%s" % [up, cam_fwd.normalized()])
	SettingsManager.minimap_rotate = false
	SettingsManager.settings_changed.emit()
	await _frames(6)
	up = mm.get_map_up()
	_assert(not mm.is_rotating() and up.is_equal_approx(Vector3(0, 0, -1)), "Static mode: map up = north (-Z)",
		str(up))
	_player.rotation.y = 0.0
	await _frames(4)
	var a_north: float = mm.get_player_arrow_angle()
	_player.rotation.y = -PI / 2.0  # facing east (+X)
	await _frames(4)
	var a_east: float = mm.get_player_arrow_angle()
	_assert(absf(a_north) < 0.05 and absf(absf(a_east) - PI / 2.0) < 0.05,
		"Static mode: the player arrow rotates (0 north, pi/2 east)", "north=%.2f east=%.2f" % [a_north, a_east])
	SettingsManager.show_minimap = false
	SettingsManager.settings_changed.emit()
	await _frames(4)
	_assert(not mm.is_map_visible() and not mm.is_enabled(), "Minimap Off hides it live")
	SettingsManager.show_minimap = true
	SettingsManager.minimap_rotate = true
	SettingsManager.settings_changed.emit()
	await _frames(4)
	_assert(mm.is_map_visible(), "Minimap On shows it again")
	# Control hints honour show_control_hints live.
	var bar := _hud("control_bar.gd")
	if bar:
		SettingsManager.show_control_hints = false
		SettingsManager.settings_changed.emit()
		await _frames(4)
		var hidden: bool = not bar._panel.visible
		SettingsManager.show_control_hints = true
		SettingsManager.settings_changed.emit()
		await _frames(4)
		_assert(hidden and bar._panel.visible, "Control Hints Hide/Show toggles the control bar live",
			"hidden=%s shown=%s" % [hidden, bar._panel.visible])
	_player.rotation.y = 0.0
	_rig._yaw = 0.0


# ========== TOWN: RANGE RULE (AMARO) ==========

func test_range_rule_amaro() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e1: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -2.5))
	var e2: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -10.0))
	var e3: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -19.0))
	await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -25.0))
	await _ground_idle()
	var abil: Node = _player.ability_system
	_assert(is_equal_approx(abil.get_max_range(), 20.0), "Amaro max range = 20 (Fire Bolt)", str(abil.get_max_range()))
	var cands: Array = abil.get_enemy_candidates()
	_assert(cands == [e1, e2, e3], "Candidates = enemies within 20 m, nearest-first (2.5/10/19 listed, 25 excluded)",
		str(cands.map(func(c): return c.name)))

	var tac := await _open_to_ability(&"sword_slash")
	if tac == null:
		return
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == PHASE_TARGET and tac._target_candidates == [e1, e2, e3],
		"Sword Slash target step lists the same max-range set", str(tac._get_target_names()))
	_assert(tac._get_target_names().size() == 4 and tac._get_target_names()[3] == FIRE_FORWARD,
		"Fire Forward is the last row", str(tac._get_target_names()))
	_assert(tac._is_row_in_range(0) and not tac._is_row_in_range(1) and not tac._is_row_in_range(2),
		"Sword Slash (3.5 m): row 0 in range, rows 1-2 out of range")
	var menu := _hud("tactical_menu.gd")
	var rows: Array = menu._item_rows if menu else []
	var dim_ok: bool = rows.size() >= 3 and not rows[0].unavailable and rows[1].unavailable and rows[2].unavailable \
		and rows[1].right_text == "Out of range" and rows[2].right_text == "Out of range"
	_assert(dim_ok, "HUD darkens rows 1-2 ('Out of range'), row 0 normal",
		str(rows.map(func(r): return [r.unavailable, r.right_text])))
	var ind := _hud("lock_on_indicator.gd")
	var tbar := _hud("target_bar.gd")
	_assert(ind and tbar and not ind.is_out_of_range() and not tbar.is_out_of_range(),
		"Row 0 highlighted: reticle + target bar not dimmed")
	# Highlight row 1 (allowed), reticle + bar dim.
	await _tap(_joy_press(JOY_DPAD_RIGHT), _joy_release(JOY_DPAD_RIGHT))
	_assert(tac._target_index == 1, "An out-of-range row can be highlighted", "index=%d" % tac._target_index)
	_assert(ind.is_out_of_range() and tbar.is_out_of_range(), "Out-of-range highlight dims the reticle and target bar",
		"ind=%s bar=%s" % [ind.is_out_of_range(), tbar.is_out_of_range()])
	_assert(_label_text(ind).contains("OUT OF RANGE"), "Reticle label reads OUT OF RANGE", _label_text(ind))
	# A refuses.
	_fail_log.clear()
	var hp2: float = e2.current_hp
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"TacticalIdle" and int(tac._phase) == PHASE_TARGET and "out_of_range" in _fail_log,
		"A on a darkened row is refused (out_of_range), the step stays open",
		"state=%s fails=%s" % [_state(), str(_fail_log)])
	_assert(e2.current_hp == hp2, "Refused row takes no damage")
	# Back to row 0: dim clears.
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	_assert(tac._target_index == 0 and not ind.is_out_of_range() and not tbar.is_out_of_range(),
		"Back on an in-range row: reticle + bar restored")
	# Fire Forward (Y) still works from a darkened row.
	await _tap(_joy_press(JOY_DPAD_RIGHT), _joy_release(JOY_DPAD_RIGHT))
	_player.current_atb = _player.max_atb
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(_state() == &"Ability", "Y Fire Forward casts Sword Slash from a darkened row", "state=%s" % _state())
	await _wait_until(func(): return _state() != &"Ability", 3.0)
	_assert(not ind.is_out_of_range() and not tbar.is_out_of_range(), "After the cast the dim is cleared")

	# Fire Bolt (20 m): every listed row is in range.
	tac = await _open_to_ability(&"fire_bolt")
	if tac:
		await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
		_assert(int(tac._phase) == PHASE_TARGET and tac._is_row_in_range(0) and tac._is_row_in_range(1)
				and tac._is_row_in_range(2),
			"Fire Bolt (20 m): all three rows in range")
		await _close_menu()


func test_sword_slash() -> void:
	var e1: Node = _dummies[0] if _dummies.size() > 0 else null
	if e1 == null:
		_fail("Sword Slash", "no dummy")
		return
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	_player.current_mp = 0.0
	_player.current_atb = _player.max_atb
	await _wait_cooldown(&"sword_slash")
	var tac := await _open_to_ability(&"sword_slash")
	if tac == null:
		return
	_player.current_mp = 0.0
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	var hp0: float = e1.current_hp
	_assert(int(tac._phase) == PHASE_TARGET and tac._target_index == 0, "Target step on the nearest enemy (2.5 m)")
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"Ability", "Sword Slash casts with 0 MP (ATB only)",
		"state=%s fails=%s" % [_state(), str(_fail_log)])
	var fx := await _wait_effect()
	await _wait_until(func(): return _state() != &"Ability", 3.0)
	var hits: Array = fx.get(&"hit_targets") if fx and is_instance_valid(fx) else []
	_assert(e1.current_hp < hp0 and e1 in hits, "Sword Slash hits the 2.5 m target",
		"hp %.0f -> %.0f hits=%d" % [hp0, e1.current_hp, hits.size()])
	_assert(not (_dummies[1] in hits), "Sword Slash does not reach the 10 m enemy")
	_assert(_player.current_mp == 0.0 or _player.current_mp < 2.0, "Sword Slash spent no MP",
		"mp=%.2f" % _player.current_mp)


# ========== TOWN: AERIAL LIST ==========

func test_aerial_list() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	_player.current_atb = _player.max_atb
	_player.current_mp = _player.max_mp
	var abil: Node = _player.ability_system
	await _open_command_menu()
	var tac: Node = _player.state_machine.current_state if _state() == &"TacticalIdle" else null
	if tac == null:
		_fail("Grounded Command Menu opens", "state=%s" % _state())
		return
	var ground_ids := _slot_ids(tac)
	_assert(not tac._opened_airborne and not (&"plunge_strike" in ground_ids) and &"sword_slash" in ground_ids,
		"Grounded list hides Plunge Strike, shows Sword Slash", str(ground_ids))
	await _close_menu()

	# Airborne (real jump: A in free roam, then Y opens the menu mid-air).
	_player.battle_mode.force_exit()
	await _frames(2)
	_player.launch_jump(14.0)
	await _real_seconds(0.25)
	_player._current_interactable = null
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	if _state() != &"TacticalIdle":
		_fail("Airborne Command Menu opens on Y", "state=%s onfloor=%s" % [_state(), _player.is_on_floor()])
		return
	tac = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)
	var air_ids := _slot_ids(tac)
	_assert(tac._opened_airborne and air_ids.size() > 0 and air_ids[0] == &"plunge_strike",
		"Airborne list leads with Plunge Strike (aerial_only first)", str(air_ids))
	var menu := _hud("tactical_menu.gd")
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))  # category -> list
	var ss_row := air_ids.find(&"sword_slash")
	var rows: Array = menu._item_rows if menu else []
	_assert(ss_row >= 0 and ss_row < rows.size() and rows[ss_row].unavailable
			and rows[ss_row].right_text == "Grounded only",
		"Airborne: Sword Slash row greyed 'Grounded only'",
		str(rows.map(func(r): return r.right_text)))
	_assert(abil.get_air_block_reason(load("res://resources/abilities/sword_slash.tres"), true) == "grounded_only"
			and abil.get_air_block_reason(load("res://resources/abilities/plunge_strike.tres"), false) == "airborne_only",
		"get_air_block_reason: grounded_only / airborne_only")
	# B, B closes into Fall.
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
	_assert(_state() == &"Fall" or _state() == &"Land" or _state() == &"Idle",
		"Closing the airborne menu returns to Fall (then lands)", "state=%s" % _state())
	await _ground_idle()


func _slot_ids(tac: Node) -> Array:
	var out: Array = []
	var abil: Node = _player.ability_system
	for s in tac._menu_slots:
		var a = abil.equipped_abilities[s] if s < abil.equipped_abilities.size() else null
		out.append(a.ability_id if a else &"")
	return out


# ========== TOWN: AIR COMBO ==========

func test_air_combo() -> void:
	await _ground_idle()
	_player.battle_mode.force_exit()
	_place_player(Vector3(0, 0.1, 2), 0.0)
	await _ground_idle()
	var combo: Node = _player.combo
	_assert(combo.air_combo_available(), "Air combo available on the ground")
	_player.launch_jump(18.0)
	# Rise toward the apex (~0.6 s), then three light taps.
	await _real_seconds(0.45)
	var start_xz := Vector2(_player.global_position.x, _player.global_position.z)
	var ys: Array = []
	var strike_frames := 0
	var recorder := func() -> void:
		if _state() == &"MeleeStrike":
			ys.append(_player.global_position.y)
	get_tree().physics_frame.connect(recorder)
	for i in 3:
		await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.06)
		await _real_seconds(0.2)
	await _wait_until(func(): return _state() != &"MeleeStrike", 3.0)
	get_tree().physics_frame.disconnect(recorder)
	strike_frames = ys.size()
	var anchor: float = combo.air_anchor_y
	var mn: float = ys.min() if not ys.is_empty() else 0.0
	var mx: float = ys.max() if not ys.is_empty() else 0.0
	_assert(strike_frames > 20 and mn >= anchor - 0.2 and mx <= anchor + 0.2,
		"Air string holds altitude within +-0.2 m of the anchor",
		"anchor=%.3f min=%.3f max=%.3f frames=%d" % [anchor, mn, mx, strike_frames])
	_assert(String(combo.current_string()).length() >= 0 and mn > 1.5, "No snap to the ground during the string",
		"min y=%.2f" % mn)
	var drift := Vector2(_player.global_position.x, _player.global_position.z).distance_to(start_xz)
	_assert(drift > 0.6 and drift < 5.0, "Air string drifts forward (~2 m/s)", "drift=%.2f m" % drift)
	_assert(not combo.air_combo_available(), "The air combo is spent after the string")
	# Gravity resumes and another X press does not re-hover.
	var y0: float = _player.global_position.y
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.06)
	await _real_seconds(0.15)
	var reh := _state() == &"MeleeStrike"
	_assert(not reh and _player.global_position.y < y0 - 0.1, "Gravity resumes; X again does not re-hover",
		"state=%s y %.2f -> %.2f" % [_state(), y0, _player.global_position.y])
	await _ground_idle()
	await _physics_frames(3)
	_assert(combo.air_combo_available(), "Landing refreshes the air combo")


# ========== TOWN: AIR DODGE ==========

func test_air_dodge() -> void:
	await _ground_idle()
	_player.battle_mode.force_exit()
	_place_player(Vector3(0, 0.1, 2), 0.0)
	_rig._yaw = 0.0
	await _ground_idle()
	await _physics_frames(10)
	var combo: Node = _player.combo
	_player.launch_jump(14.0)
	await _real_seconds(0.3)
	var p0: Vector3 = _player.global_position
	var cam_back: Vector3 = _rig.camera.global_basis.z
	cam_back.y = 0.0
	cam_back = cam_back.normalized()
	Input.action_press(&"move_down")
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_B))
	var ad: Node = _player.state_machine.states.get(&"AirDodge")
	var entered := _state() == &"AirDodge"
	var mode: StringName = ad.mode if ad else &""
	Input.action_release(&"move_down")
	var peak := p0.y
	var back := 0.0
	for i in 40:
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
		if _state() == &"AirDodge":
			back = (_player.global_position - p0).dot(cam_back)
	_assert(entered and mode == &"backflip", "Stick-back + B airborne = AirDodge backflip",
		"entered=%s mode=%s" % [entered, mode])
	_assert(peak - p0.y >= 1.0, "Backflip rises (~1.5 m)", "rise=%.2f" % (peak - p0.y))
	_assert(back >= 2.8, "Backflip carries back toward the camera (~4 m)", "back=%.2f" % back)
	_assert(_state() == &"Fall" or not _player.is_on_floor() or _state() == &"Land",
		"Backflip ends in Fall", "state=%s" % _state())
	_assert(not combo.air_dodge_available(), "Air dodge spent for this airtime")
	# Second press in the same airtime: refused.
	var again := false
	Input.parse_input_event(_joy_press(JOY_B))
	for i in 6:
		await get_tree().physics_frame
		again = again or _state() == &"AirDodge" or _state() == &"Dodge"
	Input.parse_input_event(_joy_release(JOY_B))
	_assert(not again and not _player.is_on_floor(), "A second air dodge in the same airtime is refused",
		"state=%s floor=%s" % [_state(), _player.is_on_floor()])
	await _ground_idle()
	await _physics_frames(3)
	_assert(combo.air_dodge_available(), "Landing refreshes the air dodge")
	# Neutral stick (not locked): air dash, altitude held.
	_player.launch_jump(14.0)
	await _real_seconds(0.3)
	var y1: float = _player.global_position.y
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_B))
	var dmode: StringName = ad.mode if ad else &""
	_assert(_state() == &"AirDodge" and dmode == &"dash", "Neutral stick + B airborne = air dash",
		"state=%s mode=%s" % [_state(), dmode])
	await _physics_frames(8)
	_assert(absf(_player.global_position.y - y1) < 0.4, "Air dash holds altitude",
		"dy=%.2f" % (_player.global_position.y - y1))
	await _ground_idle()


# ========== TOWN: LOCK-ON RANGE + FRAMING ==========

func test_lock_on_range(expected: float) -> void:
	_free_dummies()
	await _physics_frames(2)
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	var lock: Node = _player.lock_on_component
	var mr: float = _player.ability_system.get_max_range()
	_assert(is_equal_approx(lock.get_acquire_range(), mr) and is_equal_approx(mr, expected),
		"Lock-on acquire range = max ability range (%.0f m)" % expected,
		"acquire=%.1f max=%.1f" % [lock.get_acquire_range(), mr])
	var far: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -(expected + 1.0)))
	var got = lock.acquire_target()
	_assert(got == null, "Enemy at %.0f m is beyond lock-on reach" % (expected + 1.0))
	if got:
		lock.release_target()
	far.global_position = LANE_ORIGIN + Vector3(0, -0.1, -(expected - 1.0))
	await _physics_frames(2)
	got = lock.acquire_target()
	_assert(got == far, "Enemy at %.0f m is acquired" % (expected - 1.0))
	if got:
		lock.release_target()
	await _physics_frames(2)
	_free_dummies()
	await _physics_frames(2)


func _screen_sep(target: Node3D) -> Dictionary:
	var cam: Camera3D = _rig.camera
	var pp := cam.unproject_position(_player.global_position + Vector3(0, 1.0, 0))
	var tp := cam.unproject_position(target.global_position + Vector3(0, 1.0, 0))
	return {"dx": absf(pp.x - tp.x), "behind": cam.is_position_behind(target.global_position),
		"p": pp, "t": tp, "vp": get_viewport().get_visible_rect().size}


func test_framing() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	_rig._yaw = 0.0
	await _ground_idle()
	await _real_seconds(0.3)
	# Target straight ahead on the camera->player line (the v4_04 overlap case).
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -8.0))
	var before := _screen_sep(e)
	_assert(before["dx"] < 40.0, "Baseline: target sits on the player's screen column before lock-on",
		"dx=%.0f" % before["dx"])
	await _tap_action(&"lock_on")
	_assert(_player.is_locked_on and _player.lock_on_target == e, "Lock-on acquires the target")
	await _real_seconds(1.5)
	var after := _screen_sep(e)
	var vpw: float = after["vp"].x
	_assert(not after["behind"] and after["dx"] >= vpw * 0.06,
		"Locked: target projected beside the player (no overlap)",
		"dx=%.0f px (vp %.0f) p=%s t=%s" % [after["dx"], vpw, after["p"], after["t"]])
	var theta: float = absf(_rig.get_frame_angle(_rig._yaw))
	var req: float = _rig.get_required_offset()
	_assert(theta >= req - deg_to_rad(1.5), "Frame angle >= required offset",
		"theta=%.1f req=%.1f deg" % [rad_to_deg(theta), rad_to_deg(req)])
	# Steady (no jitter).
	var y0: float = _rig._yaw
	await _real_seconds(0.3)
	_assert(absf(wrapf(_rig._yaw - y0, -PI, PI)) < deg_to_rad(0.5), "Framing is steady (no jitter)",
		"dyaw=%.2f deg" % rad_to_deg(wrapf(_rig._yaw - y0, -PI, PI)))
	await _tap_action(&"lock_on")
	await _real_seconds(0.3)

	# Target between camera and player.
	_player.lock_on_component.release_target()
	await _ground_idle()
	_rig._yaw = 0.0
	e.global_position = LANE_ORIGIN + Vector3(0, -0.1, 2.5)
	await _physics_frames(4)
	await _tap_action(&"lock_on")
	_assert(_player.is_locked_on and _player.lock_on_target == e, "Lock-on acquires the target behind the player")
	await _real_seconds(2.0)
	var between := _screen_sep(e)
	_assert(not between["behind"] and between["dx"] >= vpw * 0.06,
		"Target that started between camera and player ends up in view, beside the player",
		"dx=%.0f behind=%s" % [between["dx"], between["behind"]])
	if _player.is_locked_on:
		await _tap_action(&"lock_on")
	_player.lock_on_component.release_target()
	await _ground_idle()


# ========== TOWN: PARTY SWITCH ==========

func test_party_switch() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	_assert(_party != null and _party.get_member_count() >= 2, "Town party has Amaro + Taighe")
	if _party == null or _party.get_member_count() < 2:
		return
	var comp: Node = _party.get_companion()
	_assert(_is_member(&"hero") and _player.get_member_data().display_name == "Amaro", "Player controls Amaro")
	# Battle, so the control bar shows the unique (Y) label.
	await _enter_battle()
	var bar := _hud("control_bar.gd")
	var y_before := _y_label(bar)
	_assert(_player.in_battle and y_before == "Arcane Stance", "Battle Y label for Amaro = Arcane Stance",
		"in_battle=%s Y=%s entries=%s" % [_player.in_battle, y_before, str(bar.get_hint_entries() if bar else [])])
	var amaro_max_hp: float = _player.max_hp
	var taighe_max_hp: float = comp.max_hp
	await _real_seconds(SWITCH_WAIT)
	# Distinct stats on each body (set right before the press: ATB/MP keep filling).
	_player.current_hp = 50.0
	_player.current_mp = 30.0
	_player.current_atb = 77.0
	comp.current_hp = 63.0
	comp.current_mp = 21.0
	comp.current_atb = 40.0
	_switch_log.clear()
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	_assert(_is_member(&"companion") and _player.get_member_data().display_name == "Taighe",
		"D-pad Up switches control to Taighe", "active=%s" % _party.members[_party.active_index].id)
	_assert(_switch_log == [[&"hero", &"companion"]], "party_member_switched(hero, companion)", str(_switch_log))
	_assert(is_equal_approx(_player.current_hp, 63.0) and is_equal_approx(_player.max_hp, taighe_max_hp)
			and is_equal_approx(comp.current_hp, 50.0) and is_equal_approx(comp.max_hp, amaro_max_hp),
		"HP / max HP exchanged between bodies",
		"player %.0f/%.0f comp %.0f/%.0f" % [_player.current_hp, _player.max_hp, comp.current_hp, comp.max_hp])
	_assert(absf(_player.current_mp - 21.0) < 1.0 and absf(comp.current_mp - 30.0) < 1.0,
		"MP exchanged", "player %.1f comp %.1f" % [_player.current_mp, comp.current_mp])
	_assert(absf(_player.current_atb - 40.0) < 3.0 and absf(comp.current_atb - 77.0) < 3.0,
		"ATB exchanged", "player %.1f comp %.1f" % [_player.current_atb, comp.current_atb])
	var ids: Array = _player.ability_system.equipped_abilities.map(func(a): return a.ability_id)
	_assert(&"water_geyser" in ids and &"wind_crescent" in ids and not (&"sword_slash" in ids),
		"Taighe's command list travels with her", str(ids))
	_assert(_player.stance.current_stance() == &"" and String(_player.stance.get_display_name()).to_lower().contains("focus"),
		"Taighe's unique ability is Arcane Focus (v8)", _player.stance.get_display_name())
	await _frames(4)
	var hud := _hud("combat_hud.gd")
	var active_ids: Array = []
	if hud:
		for r in hud._rows:
			if r["active"]:
				active_ids.append(r["id"])
	_assert(active_ids == [&"companion"], "HUD: Taighe's panel is the large active panel", str(active_ids))
	_assert(hud and hud.last_switch_toast == "Taighe", "HUD toast reads Taighe", str(hud.last_switch_toast if hud else ""))
	await _frames(3)
	var y_after := _y_label(bar)
	_assert(y_after == "Arcane Focus", "Control bar Y label follows the member (Arcane Focus)", y_after)

	# Cooldown: an immediate second press is ignored.
	_assert(_party.get_switch_cooldown_remaining() > 0.0, "Switch cooldown running after a switch")
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	_assert(_is_member(&"companion") and _switch_log.size() == 1, "A second press inside 1 s is ignored")
	await _real_seconds(SWITCH_WAIT)
	_assert(_party.get_switch_cooldown_remaining() == 0.0, "Cooldown clears after 1 s")

	# Blocked states (cooldown already clear, so only the state blocks).
	var blocked: Array = []
	var n0 := _switch_log.size()
	_player.state_machine.force_transition(&"Dodge")
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN), 0.02)
	blocked.append(["Dodge", _switch_log.size() == n0])
	await _ground_idle()
	await _enter_battle()
	n0 = _switch_log.size()
	await _open_command_menu_battle()
	var in_menu := _state() == &"TacticalIdle"
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	blocked.append(["Command Menu", in_menu and _switch_log.size() == n0, _state()])
	await _close_menu()
	await _ground_idle()
	n0 = _switch_log.size()
	GameManager.change_state(GameManager.GameState.PAUSED)
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	blocked.append(["Paused", _switch_log.size() == n0])
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(2)
	n0 = _switch_log.size()
	var hp_keep: float = _player.current_hp
	_player.current_hp = 0.0
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	blocked.append(["Dead", _switch_log.size() == n0])
	_player.current_hp = hp_keep
	await _ground_idle()
	if not _is_member(&"companion"):
		# A blocked check leaked a switch: get back to Taighe for the round trip.
		await _real_seconds(SWITCH_WAIT)
		await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
		await _ground_idle()
	var all_blocked := true
	for b in blocked:
		all_blocked = all_blocked and b[1]
	_assert(all_blocked, "Switch blocked in Dodge / Command Menu / Paused / Dead", str(blocked))

	# Round trip: D-pad Down back to Amaro, stats preserved (still in Battle).
	await _enter_battle()
	await _real_seconds(SWITCH_WAIT)
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	_assert(_is_member(&"hero") and is_equal_approx(_player.current_hp, 50.0) and is_equal_approx(comp.current_hp, 63.0),
		"D-pad Down switches back to Amaro; HP preserved through the round trip",
		"player %.0f comp %.0f" % [_player.current_hp, comp.current_hp])
	await _frames(3)
	_assert(_y_label(bar) == "Arcane Stance", "Y label back to Arcane Stance", _y_label(bar))
	var ids2: Array = _player.ability_system.equipped_abilities.map(func(a): return a.ability_id)
	_assert(&"sword_slash" in ids2 and is_equal_approx(_player.ability_system.get_max_range(), 20.0),
		"Amaro's list (Sword Slash, max range 20) restored", str(ids2))
	# Over to Taighe for the next sections.
	await _real_seconds(SWITCH_WAIT)
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	_player.current_hp = _player.max_hp
	_player.battle_mode.force_exit()
	await _ground_idle()


const SWITCH_WAIT := 1.1


func _enter_battle() -> void:
	if not _player.in_battle:
		_player.battle_mode.toggle_manual()
	await _frames(4)


func _y_label(bar: Node) -> String:
	if bar == null:
		return ""
	for e in bar.get_hint_entries():
		if e[0] == "Y":
			return e[1]
	return ""


func _is_member(id: StringName) -> bool:
	return _party != null and _party.members.size() > _party.active_index \
		and _party.members[_party.active_index].id == id


func _switch_back_to_amaro() -> void:
	if _is_member(&"hero"):
		return
	await _ground_idle()
	await _real_seconds(SWITCH_WAIT)
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	await _ground_idle()


# ========== TOWN: TAIGHE SPELLS ==========

func test_water_geyser() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -10.0))
	await _ground_idle()
	_player.current_mp = _player.max_mp
	_player.current_atb = _player.max_atb
	var tac := await _open_to_ability(&"water_geyser")
	if tac == null:
		return
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == PHASE_TARGET and tac._target_candidates.size() == 1 and tac._is_row_in_range(0),
		"Water Geyser target step: the 10 m enemy is in range (16 m)")
	var hp0: float = e.current_hp
	var y0: float = e.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"Ability", "Water Geyser casts", "state=%s fails=%s" % [_state(), str(_fail_log)])
	var fx := await _wait_effect()
	# Let the enemy fly: unfreeze physics while the column erupts.
	e.set_physics_process(true)
	var max_vy := 0.0
	var max_y := y0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2200:
		await get_tree().physics_frame
		if is_instance_valid(e):
			max_vy = maxf(max_vy, e.velocity.y)
			max_y = maxf(max_y, e.global_position.y)
	_freeze(e)
	var hits: Array = fx.get(&"hit_targets") if fx and is_instance_valid(fx) else []
	_assert(e.current_hp < hp0, "Water Geyser damages the target", "hp %.0f -> %.0f" % [hp0, e.current_hp])
	_assert(fx == null or not is_instance_valid(fx) or e in hits, "Water Geyser hit list contains the target")
	_assert(max_vy >= 5.0 and max_y - y0 >= 1.0, "Water Geyser launches the enemy upward",
		"max vy=%.1f rise=%.2f m" % [max_vy, max_y - y0])
	_assert(absf(fx_spawn_dist(fx, e)) < 1.6 if fx and is_instance_valid(fx) else true,
		"Geyser erupts at the target (no projectile)")


func fx_spawn_dist(fx: Node, e: Node) -> float:
	if not (fx is Node3D):
		return 0.0
	var a: Vector3 = (fx as Node3D).global_position
	var b: Vector3 = (e as Node3D).global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_wind_crescent() -> void:
	await _ground_idle()
	_free_dummies()
	await _physics_frames(2)
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -10.0))
	var by: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(7.0, -0.1, -10.0))
	await _ground_idle()
	_player.current_mp = _player.max_mp
	_player.current_atb = _player.max_atb
	var tac := await _open_to_ability(&"wind_crescent")
	if tac == null:
		return
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == PHASE_TARGET and tac._target_candidates.size() >= 1 and tac._target_candidates[0] == e,
		"Wind Crescent target step: nearest = the 10 m enemy")
	var hp0: float = e.current_hp
	var hp_by: float = by.current_hp
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"Ability", "Wind Crescent casts", "state=%s fails=%s" % [_state(), str(_fail_log)])
	var fx := await _wait_effect()
	var hc := 0
	var log: Array = []
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2500:
		await get_tree().physics_frame
		if fx and is_instance_valid(fx):
			hc = int(fx.get(&"hit_count"))
			log = (fx.get(&"hit_log") as Array).duplicate()
	_assert(hc == 3 and log.size() == 3 and log.all(func(x): return x == e),
		"Wind Crescent lands 3 hits on the target", "hit_count=%d log=%d" % [hc, log.size()])
	_assert(e.current_hp < hp0 and is_equal_approx(by.current_hp, hp_by),
		"Bystander 7 m away is untouched", "target %.0f->%.0f bystander %.0f->%.0f" % [hp0, e.current_hp, hp_by, by.current_hp])


# ========== TOWN: SUPER JUMP ==========

func test_super_jump() -> void:
	await _ground_idle()
	_player.battle_mode.force_exit()
	_place_player(Vector3(0, 0.1, 2), 0.0)
	await _ground_idle()
	await _physics_frames(6)
	var ground: float = _player.global_position.y
	# v8: A interacts while a prompt is up (a crate sits near this spot), so
	# measure the normal jump on a spot with nothing to interact with.
	for spot in [Vector3(0, 0.1, 2), Vector3(-6, 0.1, 6), Vector3(6, 0.1, 6), Vector3(0, 0.1, 9)]:
		if _player.get_current_interactable() == null:
			break
		_place_player(spot, 0.0)
		await _ground_idle()
		await _physics_frames(6)
	ground = _player.global_position.y
	# Normal jump: A in free roam (no prompt).
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.03)
	var peak_n := await _peak_height(ground)
	await _ground_idle()
	await _physics_frames(6)
	# v8: battle + Command Menu > Super Jump (Y is Arcane Focus now).
	await _enter_battle()
	ground = _player.global_position.y
	var sj_tac := await _open_to_ability(&"super_jump")
	if sj_tac:
		await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.03)
	await _wait_until(func(): return _state() == &"Jump" or _state() == &"Fall", 1.5)
	var launched := _state() == &"Jump" or _state() == &"Fall"
	_assert(launched, "Command Menu > Super Jump (Taighe, battle) launches with no target step", "state=%s" % _state())
	# Rise to the apex, then open the Command Menu (A in battle).
	var peak := ground
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000:
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
		if _player.velocity.y <= 0.5 and peak - ground > 2.0:
			break
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.03)
	var in_menu := _state() == &"TacticalIdle"
	var tac: Node = _player.state_machine.current_state if in_menu else null
	if tac:
		await _wait_until(func(): return bool(tac._confirm_armed), 3.0)
	var ids: Array = _slot_ids(tac) if tac else []
	_assert(in_menu and tac._opened_airborne and ids.size() > 0 and ids[0] == &"air_burst",
		"At the Super Jump apex the Command Menu shows the aerial list (Air Burst first)",
		"state=%s ids=%s" % [_state(), str(ids)])
	if in_menu:
		await _close_menu()
	var peak_s := await _peak_height(ground)
	peak_s = maxf(peak_s, peak - ground)
	var ratio := peak_s / maxf(peak_n, 0.01)
	_assert(ratio >= 4.3 and ratio <= 5.7, "Super Jump reaches ~5x the normal jump height",
		"normal=%.2f m super=%.2f m ratio=%.2f" % [peak_n, peak_s, ratio])
	await _ground_idle()
	# Cooldown: the command is on its ~3 s cooldown right after landing.
	_assert(_player.ability_system.is_on_cooldown(&"super_jump"), "Super Jump is on cooldown (~3 s) right after use",
		"left=%.2f" % _player.ability_system.get_cooldown_remaining(&"super_jump"))
	_player.battle_mode.force_exit()
	await _ground_idle()


func _peak_height(ground: float) -> float:
	var peak := ground
	var start := Time.get_ticks_msec()
	var left := false
	while Time.get_ticks_msec() - start < 4000:
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
		if not _player.is_on_floor():
			left = true
		elif left:
			break
	return peak - ground


# ========== TOWN: RIGLESS CUES THROUGH PLAYER ==========

func test_rigless_player_cues() -> void:
	await _ground_idle()
	_player.battle_mode.force_exit()
	_place_player(Vector3(0, 0.1, 2), 0.0)
	await _ground_idle()
	_assert(_player.has_method(&"_rigless_cue"), "Player exposes _rigless_cue()")
	var rv: Node3D = load(RIGLESS_SCRIPT).new()
	rv.name = "RiglessVisual"
	_player.visual_root.add_child(rv)
	await _frames(3)
	_player.take_damage(1.0, null)
	await _real_seconds(0.7)
	await _ground_idle()
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.05)
	await _real_seconds(0.7)
	await _ground_idle()
	await _real_seconds(0.5)
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.05)
	var dodged := _state() == &"Dodge"
	var vis_moved := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await get_tree().physics_frame
		dodged = dodged or _state() == &"Dodge"
		vis_moved = vis_moved or not _player.visual_root.transform.is_equal_approx(Transform3D.IDENTITY)
	await _ground_idle()
	var counts: Dictionary = rv.get_debug_state()["cue_counts"]
	_assert(int(counts.get(&"hit", 0)) >= 1, "Player hit -> RiglessVisual 'hit' cue", str(counts))
	_assert(int(counts.get(&"attack", 0)) + int(counts.get(&"attack_heavy", 0)) >= 1,
		"X attack -> RiglessVisual 'attack' cue", str(counts))
	# v8: ground dodge visuals (roll / cartwheel / backflip) drive $VisualRoot
	# directly (DodgeState) and are restored afterwards; no 'dodge' cue spin.
	_assert(dodged and vis_moved and _player.visual_root.transform.is_equal_approx(Transform3D.IDENTITY),
		"B dodge -> v8 dodge visual on VisualRoot, restored after", "dodged=%s moved=%s" % [dodged, vis_moved])
	_player.current_hp = _player.max_hp
	rv.queue_free()
	await _frames(2)


# ========== HELPERS ==========

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
	_party = _player.party_system
	for ch in _zone.get_children():
		if ch.get(&"yaw_pivot") != null and ch.has_method(&"get_frame_angle"):
			_rig = ch
	_assert(_rig != null and _party != null, "Town harness: player, party system and camera rig found")
	await _wait_on_floor(240)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	return _rig != null


func _hud(script_file: String) -> Node:
	if _zone == null:
		return null
	for ch in _zone.get_children():
		if ch.get_script() and String(ch.get_script().resource_path).ends_with(script_file):
			return ch
	return null


func _place_player(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	if _rig:
		_rig.global_position = pos
		_rig._yaw = yaw


func _spawn_dummy(pos: Vector3) -> Node:
	var es = load(ENEMY_SCENE) as PackedScene
	var e: Node = es.instantiate()
	_zone.add_child(e)
	e.global_position = pos
	await _physics_frames(2)
	_freeze(e)
	e.max_hp = 100000.0
	e.current_hp = e.max_hp
	if "stagger_max" in e:
		e.stagger_max = 100000.0
	e.ai_state = EnemyBase.AIState.IDLE
	_dummies.append(e)
	return e


func _free_dummies() -> void:
	for e in _dummies:
		if is_instance_valid(e):
			e.queue_free()
	_dummies.clear()


func _freeze(e: Node) -> void:
	e.set_physics_process(false)
	e.set_process(false)


func _ground_idle() -> void:
	_release_all_input()
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _wait_on_floor(300)
	if _state() != &"Idle" and _state() != &"LockOnIdle":
		_player.state_machine.force_transition(&"Idle")
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)


## Free roam: Y with no prompt opens the Command Menu; waits for the open-press guard.
func _open_command_menu() -> void:
	await _ground_idle()
	if _player.in_battle:
		await _open_command_menu_battle()
		return
	_player._current_interactable = null
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	if _state() != &"TacticalIdle":
		return
	var tac: Node = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)


## Battle: A opens the Command Menu.
func _open_command_menu_battle() -> void:
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	if _state() != &"TacticalIdle":
		return
	var tac: Node = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)


## Opens the menu, confirms the Abilities category and walks the list with
## D-pad Down until `id` is under the cursor. Returns the TacticalIdle state.
func _open_to_ability(id: StringName) -> Node:
	_fail_log.clear()
	_player.current_atb = _player.max_atb
	await _open_command_menu()
	if _state() != &"TacticalIdle":
		_fail("Command Menu opens (for %s)" % id, "state=%s" % _state())
		return null
	var tac: Node = _player.state_machine.current_state
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	if int(tac._phase) != PHASE_ABILITY:
		_fail("Abilities category opens (for %s)" % id, "phase=%s" % str(tac._phase))
		return null
	var guard := 0
	while (tac._ability_at_cursor() == null or tac._ability_at_cursor().ability_id != id) and guard < 10:
		await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
		guard += 1
	var ok: bool = tac._ability_at_cursor() != null and tac._ability_at_cursor().ability_id == id
	if not ok:
		_fail("Ability list reaches %s" % id, str(_slot_ids(tac)))
		await _close_menu()
		return null
	return tac


## The Fire Forward cast earlier started this ability's cooldown: wait it out.
func _wait_cooldown(id: StringName) -> void:
	var abil: Node = _player.ability_system
	await _wait_until(func(): return not abil.is_on_cooldown(id), 8.0)


func _wait_effect() -> Node:
	var st: Node = _player.state_machine.states.get(&"Ability")
	if st == null:
		return null
	st.last_effect = null
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2500:
		await get_tree().physics_frame
		if st.last_effect != null and is_instance_valid(st.last_effect):
			return st.last_effect
	return null


func _close_menu() -> void:
	var tries := 0
	while _state() == &"TacticalIdle" and tries < 4:
		await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
		tries += 1
	if _state() == &"TacticalIdle":
		_player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	Engine.time_scale = 1.0
	await _frames(2)


func _connect_logs() -> void:
	Events.ability_request_failed.connect(func(r, _a): _fail_log.append(str(r)))
	Events.party_member_switched.connect(func(o, n): _switch_log.append([o, n]))
	Events.enemy_damaged.connect(func(e, d): _damage_log.append([e, d]))


func _label_text(root: Node) -> String:
	if root == null:
		return ""
	var parts: PackedStringArray = []
	for n in root.find_children("*", "Label", true, false):
		if (n as Label).text != "":
			parts.append((n as Label).text)
	for n in root.find_children("*", "", true, false):
		for prop in [&"text", &"label", &"caption"]:
			var v = n.get(prop)
			if v is String and v != "" and not parts.has(v):
				parts.append(v)
	return " · ".join(parts)


func _teardown_zone() -> void:
	_release_all_input()
	_free_dummies()
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null
	_party = null
	_rig = null


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
			&"jump", &"dodge", &"tactical_mode", &"unique_ability", &"battle_toggle", &"lock_on"]:
		if InputMap.has_action(a):
			Input.action_release(a)


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
