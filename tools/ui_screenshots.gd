## UI screenshot capture (UI Modernization plan, Package P2).
## Runs WINDOWED at 1920x1080 through the normal game path: zone_base spawns the
## HUD in town_hub / field_zone, and every screen is driven by the same input
## actions the game reads (InputEventAction) — pause, interact, tactical_mode,
## lock_on, ui_up/ui_down/ui_accept/ui_cancel.
##
## Run (from the project root):
##   Z:/godot/godot.exe --path . --resolution 1920x1080 --script res://tools/ui_screenshots.gd
##   ... -- kb        keyboard glyph set (files get a _kb suffix)
## Output: docs/ui_screenshots/*.png
## v4 (Package Z3): v4_01 free roam (minimap, hints bottom-left, FREE ROAM chip),
## v4_02 manual Battle (BATTLE chip), v4_03 town target step (Fire Forward only),
## v4_04 field target step (3+ enemies).
## v5 (Package FF4): v5_01 Options page, v5_02 static (north-up) minimap, v5_03 target
## list with darkened out-of-range rows (+ dimmed reticle), v5_04-06 Sword Slash /
## Water Geyser / Wind Crescent mid-effect, v5_07 Taighe active (HUD), v5_08 Super
## Jump apex with the aerial list, v5_09 air combo mid-air, v5_10 lock-on framing.
##   ... -- v5        only the v5 set (town_hub), skips the older shots
## Not a test: it never saves a game (save/load is only viewed; the zone-entry
## autosave is blocked) and quits itself.
extends SceneTree

const OUT_DIR := "res://docs/ui_screenshots/"
const TOWN := "res://scenes/zones/town_hub.tscn"
const FIELD := "res://scenes/zones/field_zone.tscn"
const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const QUEST := "res://resources/quests/test_fetch_quest.tres"
const WATCHDOG_SEC := 360.0
const ENEMY := "res://src/enemies/enemy.tscn"
const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_DPAD_UP := 11
const JOY_DPAD_DOWN := 12
const JOY_DPAD_RIGHT := 14

var _pad := true
var _out := ""
var _shots: PackedStringArray = []
var _notes: PackedStringArray = []
var _only_v5 := false
var _dummies: Array = []


func _initialize() -> void:
	_pad = not OS.get_cmdline_user_args().has("kb")
	_only_v5 = OS.get_cmdline_user_args().has("v5")
	_run.call_deferred()


# ---------------------------------------------------------------- helpers

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _real(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _set_device() -> void:
	var im := root.get_node_or_null("InputManager")
	if im and im.active_device != (1 if _pad else 0):
		im.active_device = 1 if _pad else 0
		im.device_changed.emit(im.active_device)


## Press + release an action the way a button tap arrives (separate frames, so
## polled Input.is_action_pressed checks and _unhandled_input both see it).
func _tap(action: StringName, hold_frames: int = 2) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	e.strength = 1.0
	Input.parse_input_event(e)
	await _frames(hold_frames)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)
	_set_device()


func _shot(name: String) -> void:
	_set_device()
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out + name + ("" if _pad else "_kb") + ".png"
	var err := img.save_png(path)
	_shots.append("%s %dx%d %s" % [path, img.get_width(), img.get_height(), "ok" if err == OK else "ERR %d" % err])
	print("UI_SHOT: ", path, " ", img.get_size())


func _note(msg: String) -> void:
	_notes.append(msg)
	print("UI_NOTE: ", msg)


func _player() -> Node3D:
	var ps := get_nodes_in_group(&"player")
	return ps[0] if not ps.is_empty() else null


func _cam() -> Node:
	for n in root.find_children("*", "Node3D", true, false):
		if n.get(&"yaw_pivot") != null and n.has_method("_reset_camera"):
			return n
	return null


func _hud(script_file: String) -> Node:
	if current_scene == null:
		return null
	for c in current_scene.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with(script_file):
			return c
	return null


func _place(pos: Vector3, yaw_deg: float, pitch: float = -12.0) -> void:
	var p := _player()
	if p == null:
		return
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	# v5: park the AI party member beside/behind the player so a teleport never
	# drops the controlled body inside it (both bodies visible on one spot).
	var party: Node = p.get(&"party_system")
	var comp: Node3D = party.get_companion() if party and party.has_method(&"get_companion") else null
	if comp and comp != p:
		var back := Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(2.2, 0.0, 2.6)
		comp.global_position = pos + back
		comp.set(&"velocity", Vector3.ZERO)
	var cam := _cam()
	if cam:
		cam.set(&"_yaw", deg_to_rad(yaw_deg))  # CameraRig._yaw is radians
		cam.set(&"_pitch", pitch)
		cam.global_position = pos
	await _frames(40)
	# A teleport can leave the player in Fall/LedgeGrab; settle into Idle so
	# interact/carry run through their normal free-locomotion gates.
	if p.get(&"state_machine") and _state_name() != "Idle" and p.state_machine.has_method("force_transition"):
		p.velocity = Vector3.ZERO
		p.state_machine.force_transition(&"Idle")
		await _frames(10)


func _state_name() -> String:
	var p := _player()
	if p and p.get(&"state_machine") and p.state_machine.current_state:
		return String(p.state_machine.current_state.name)
	return "?"


func _load_scene(path: String, settle_frames: int = 150) -> void:
	change_scene_to_file(path)
	await _frames(2)
	# Block zone_base's deferred autosave on entry (it only saves while PLAYING),
	# so taking screenshots never overwrites the user's autosave slot.
	var gm := root.get_node_or_null("GameManager")
	var is_zone := path != MAIN_MENU
	if gm and is_zone:
		gm.change_state(gm.GameState.MAIN_MENU)
	await _frames(settle_frames)
	if gm and is_zone:
		gm.change_state(gm.GameState.PLAYING)
		await _frames(4)
	_set_device()


# ---------------------------------------------------------------- run

func _run() -> void:
	create_timer(WATCHDOG_SEC, true, false, true).timeout.connect(func():
		push_error("ui_screenshots: watchdog fired")
		_finish(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_out = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(_out)

	if not _only_v5:
		await _main_menu()
		await _town()
		await _field()
	await _v5()
	_finish(0)


func _finish(code: int) -> void:
	Engine.time_scale = 1.0
	print("UI_SHOTS_DONE count=%d" % _shots.size())
	for s in _shots:
		print("  ", s)
	for n in _notes:
		print("  note: ", n)
	quit(code)


func _main_menu() -> void:
	await _load_scene(MAIN_MENU, 60)
	await _real(0.4)
	await _shot("01_main_menu")


func _town() -> void:
	await _load_scene(TOWN)
	var gm := root.get_node("GameManager")
	# Track a quest so the tracker and quest log have content.
	var p := _player()
	var qs: Node = p.get_node_or_null("QuestSystem") if p else null
	var q: Resource = load(QUEST)
	if qs and q:
		if not qs.is_quest_active(q.quest_id):
			qs.accept_quest(q)
		qs.set_tracked_quest(q.quest_id)
	await _frames(20)

	# Free roam (town).
	await _place(Vector3(-1, 0.1, -9), 0.0, -10.0)
	await _real(0.3)
	await _shot("02_town_free_roam")
	await _v4_town()

	# Interaction prompt by the Villager (-2, 0, -20).
	await _place(Vector3(-2, 0.1, -18.3), 0.0, -8.0)
	await _real(0.3)
	var prompt := _hud("interaction_prompt.gd")
	if prompt and prompt.has_method("get_prompt_text"):
		_note("prompt text near Villager = '%s'" % prompt.get_prompt_text())
	await _shot("03_town_prompt_npc")

	# Dialogue — through the interact action (pad B / key E).
	_note("before interact: state=%s can_interact=%s has_interactable=%s" % [_state_name(),
		str(_player().can_interact_now()), str(_player().has_interactable())])
	await _tap(&"interact")
	await _real(0.3)
	var dlg := _hud("dialogue_ui.gd")
	_note("dialogue active after interact = %s" % str(dlg.get(&"_is_active") if dlg else null))
	await _shot("04_dialogue")
	for i in 8:
		if dlg == null or not dlg.get(&"_is_active"):
			break
		await _tap(&"ui_accept")
		await _frames(6)
	await _frames(20)

	# Pause menu (Start / Esc).
	await _tap(&"pause")
	await _real(0.4)
	_note("GameManager state after pause = %s" % str(gm.current_state))
	await _shot("05_pause_menu")

	# Quest Log (index 3).
	for i in 3:
		await _tap(&"ui_down")
	await _tap(&"ui_accept")
	await _real(0.4)
	await _shot("06_quest_log")
	await _tap(&"ui_cancel")
	await _real(0.3)

	# Save Game (index 1) — view only, never confirm a slot.
	for i in 2:
		await _tap(&"ui_up")
	await _tap(&"ui_accept")
	await _real(0.4)
	await _shot("07_save_load")
	await _tap(&"ui_cancel")
	await _real(0.3)

	# Settings (index 4), then scroll to the controls section.
	for i in 3:
		await _tap(&"ui_down")
	await _tap(&"ui_accept")
	await _real(0.4)
	await _shot("08_settings")
	for i in 7:
		await _tap(&"ui_down")
	await _real(0.3)
	await _shot("09_settings_controls")
	await _tap(&"ui_cancel")
	await _real(0.3)
	await _tap(&"ui_cancel")  # close pause
	await _real(0.4)
	_note("GameManager state after closing pause = %s" % str(gm.current_state))

	# Carrying: crate near spawn (2, 0, 3).
	await _place(Vector3(2, 0.2, 5.2), 0.0, -12.0)
	await _real(0.3)
	if prompt and prompt.has_method("get_prompt_text"):
		_note("prompt text by crate = '%s'" % prompt.get_prompt_text())
	await _tap(&"interact")
	await _real(0.6)
	var carry: Node = _player().get_node_or_null("CarryComponent")
	_note("carrying after interact = %s, state = %s" % [str(carry.is_carrying if carry else null), _state_name()])
	await _shot("10_town_carrying")


func _field() -> void:
	await _load_scene(FIELD)
	var p := _player()
	# Free roam (field) near spawn, facing north toward the first sentry camp.
	await _place(Vector3(0, 0.1, 6), 20.0, -10.0)
	await _real(0.5)
	await _shot("11_field_free_roam")

	# Walk-up to the sentry pair at (15,-5) / (22,-10): stand south-west, face them.
	await _place(Vector3(9, 0.1, 3), 35.0, -12.0)
	await _real(0.3)
	await _tap(&"lock_on")
	await _real(0.6)
	var bar := _hud("target_bar.gd")
	_note("target bar shown after lock_on = %s, target = %s" % [
		str(bar.is_shown() if bar else null),
		str(bar.call(&"target_display_name", bar.get_target()) if bar and bar.get_target() else null)])
	await _shot("12_field_lock_on_target_bar")

	# Command menu: category -> Magic -> ability list -> target list.
	_fill_atb()
	await _tap(&"tactical_mode")
	await _real(0.5)
	_note("state after tactical_mode = %s, time_scale = %.2f" % [_state_name(), Engine.time_scale])
	var overlay := _hud("tactical_overlay.gd")
	_note("tactical overlay amount = %.2f" % (overlay.get_amount() if overlay else -1.0))
	await _shot("13_command_category")
	await _tap(&"ui_down")
	await _real(0.2)
	await _shot("14_command_category_magic")
	await _tap(&"ui_accept")
	await _real(0.3)
	await _shot("15_command_ability_list")
	await _tap(&"ui_accept")
	await _real(0.3)
	await _shot("16_command_target_select")
	var tac: Node = _player().state_machine.current_state if _player() else null
	if tac and tac.has_method("_get_target_names"):
		_note("field target rows = %s" % str(tac._get_target_names()))
	await _shot("v4_04_field_target_step_enemies")
	await _tap(&"ui_down")
	await _real(0.3)
	await _shot("17_command_target_switched")
	for i in 3:
		await _tap(&"ui_cancel")
		await _real(0.2)
	await _real(0.4)
	_note("state after closing command menu = %s, time_scale = %.2f" % [_state_name(), Engine.time_scale])
	await _shot("18_field_after_tactical")


func _fill_atb() -> void:
	var p := _player()
	if p:
		p.current_atb = p.max_atb
		p.current_mp = p.max_mp


func _chip_text() -> String:
	var qt := _hud("quest_tracker.gd")
	return qt.get_mode_text() if qt and qt.has_method("get_mode_text") else "?"


## v4: minimap + chip in free roam, manual Battle, Fire-Forward-only target step.
func _v4_town() -> void:
	var p := _player()
	var mm := _hud("minimap.gd")
	_note("v4 free roam: chip=%s minimap visible=%s rect=%s" % [_chip_text(),
		str(mm.is_map_visible() if mm else null), str(mm.get_frame_rect() if mm else null)])
	await _shot("v4_01_town_free_roam_minimap")

	# Manual Battle (View/Back / F).
	await _tap(&"battle_toggle")
	await _real(0.9)  # let the chip blink settle
	_note("v4 after battle_toggle: in_battle=%s chip=%s" % [str(p.in_battle), _chip_text()])
	await _shot("v4_02_town_manual_battle")
	await _tap(&"battle_toggle")
	await _real(0.9)
	_note("v4 after second battle_toggle: in_battle=%s chip=%s" % [str(p.in_battle), _chip_text()])

	# Target step with no enemies: Fire Forward only.
	_fill_atb()
	await _tap(&"tactical_mode")
	await _real(0.5)
	await _tap(&"ui_accept")   # Abilities
	await _real(0.3)
	await _tap(&"ui_accept")   # Fire Bolt -> target step
	await _real(0.4)
	var tac: Node = p.state_machine.current_state
	_note("v4 town target step: state=%s phase=%s rows=%s" % [_state_name(), str(tac.get(&"_phase")),
		str(tac._get_target_names() if tac.has_method("_get_target_names") else null)])
	await _shot("v4_03_town_target_fire_forward")
	for i in 3:
		await _tap(&"ui_cancel")
		await _real(0.2)
	await _real(0.3)
	_note("v4 after closing town menu: state=%s time_scale=%.2f" % [_state_name(), Engine.time_scale])


# ---------------------------------------------------------------- v5 (FF4)

func _joy_tap(idx: int, hold_sec: float = 0.05) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = idx
	e.pressed = true
	Input.parse_input_event(e)
	await _real(hold_sec)
	var r := InputEventJoypadButton.new()
	r.button_index = idx
	r.pressed = false
	Input.parse_input_event(r)
	await _real(0.08)
	_set_device()


func _spawn_dummy(pos: Vector3) -> Node3D:
	var ps := load(ENEMY) as PackedScene
	var e: Node3D = ps.instantiate()
	current_scene.add_child(e)
	e.global_position = pos
	await physics_frame
	await physics_frame
	e.set_physics_process(false)
	e.set_process(false)
	e.set(&"max_hp", 100000.0)
	e.set(&"current_hp", 100000.0)
	if "stagger_max" in e:
		e.set(&"stagger_max", 100000.0)
	_dummies.append(e)
	return e


func _free_dummies() -> void:
	for e in _dummies:
		if is_instance_valid(e):
			e.queue_free()
	_dummies.clear()


func _tac() -> Node:
	var p := _player()
	if p and _state_name() == "TacticalIdle":
		return p.state_machine.current_state
	return null


func _wait_armed() -> void:
	var tac := _tac()
	for i in 120:
		if tac == null or bool(tac.get(&"_confirm_armed")):
			return
		await process_frame


## Free roam: Y (no prompt) opens the menu; battle: A. Then Abilities -> walk to `id`.
func _menu_to_ability(id: StringName) -> Node:
	var p := _player()
	_fill_atb()
	var abil: Node = p.get(&"ability_system")
	for i in 400:
		if abil == null or not abil.is_on_cooldown(id):
			break
		await process_frame
	p.set(&"_current_interactable", null)
	await _joy_tap(JOY_A if p.get(&"in_battle") else JOY_Y)
	await _wait_armed()
	var tac := _tac()
	if tac == null:
		_note("v5 menu did not open (state=%s)" % _state_name())
		return null
	await _joy_tap(JOY_A)
	for i in 8:
		var a = tac._ability_at_cursor()
		if a and a.ability_id == id:
			break
		await _joy_tap(JOY_DPAD_DOWN)
	var cur = tac._ability_at_cursor()
	_note("v5 menu cursor on %s (wanted %s)" % [str(cur.ability_id if cur else null), id])
	return tac


func _close_menus() -> void:
	for i in 4:
		if _state_name() != "TacticalIdle":
			break
		await _joy_tap(JOY_B)
	Engine.time_scale = 1.0
	await _real(0.3)


func _ability_effect() -> Node:
	var p := _player()
	var st: Node = p.state_machine.states.get(&"Ability") if p else null
	if st == null:
		return null
	for i in 240:
		await physics_frame
		var fx = st.get(&"last_effect")
		if fx != null and is_instance_valid(fx) and fx != _last_fx:
			_last_fx = fx
			return fx
	return null

var _last_fx: Object = null


func _to_ground() -> void:
	var p := _player()
	for i in 300:
		if p.is_on_floor():
			break
		await physics_frame
	if _state_name() != "Idle":
		p.velocity = Vector3.ZERO
		p.state_machine.force_transition(&"Idle")
	await _frames(4)


func _enter_battle(p: Node) -> void:
	if not p.get(&"in_battle"):
		p.battle_mode.toggle_manual()
	await _real(0.5)


func _v5() -> void:
	await _load_scene(TOWN)
	var p := _player()
	var sm := root.get_node("SettingsManager")
	var lane := Vector3(0, 0.1, -2)

	# 01 Options page: pause -> Settings -> (up wraps to) Options › -> A.
	await _place(lane, 0.0, -12.0)
	await _tap(&"pause")
	await _real(0.4)
	for i in 4:
		await _tap(&"ui_down")
	await _tap(&"ui_accept")
	await _real(0.4)
	await _tap(&"ui_up")   # wraps to the last row: "Options ›"
	await _tap(&"ui_accept")
	await _real(0.4)
	var settings: Node = null
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("settings_menu.gd"):
			settings = n
	_note("v5 options: settings found=%s page=%s" % [str(settings != null),
		str(settings.get_page() if settings else null)])
	await _shot("v5_01_options_page")
	await _tap(&"ui_cancel")
	await _real(0.2)
	await _tap(&"ui_cancel")
	await _real(0.3)
	await _tap(&"ui_cancel")  # close pause
	await _real(0.4)

	# 02 Static (north-up) minimap, player turned east, camera looking north-east.
	var rot_before: bool = sm.minimap_rotate
	sm.minimap_rotate = false
	sm.settings_changed.emit()
	await _place(Vector3(0, 0.1, -6), -45.0, -12.0)
	p.rotation.y = -PI / 2.0
	await _real(0.4)
	var mm := _hud("minimap.gd")
	_note("v5 static minimap: rotating=%s map_up=%s arrow=%.2f" % [str(mm.is_rotating() if mm else null),
		str(mm.get_map_up() if mm else null), mm.get_player_arrow_angle() if mm else -1.0])
	await _shot("v5_02_minimap_static")
	sm.minimap_rotate = rot_before
	sm.settings_changed.emit()

	# 03 Target list with darkened out-of-range rows (Sword Slash, 3.5 m).
	await _place(lane, 0.0, -12.0)
	await _spawn_dummy(lane + Vector3(0.4, -0.1, -2.5))
	await _spawn_dummy(lane + Vector3(-2.0, -0.1, -10.0))
	await _spawn_dummy(lane + Vector3(2.0, -0.1, -17.0))
	await _real(0.3)
	var tac := await _menu_to_ability(&"sword_slash")
	if tac:
		await _joy_tap(JOY_A)
		await _joy_tap(JOY_DPAD_RIGHT)  # highlight the 10 m (out-of-range) enemy
		await _real(0.3)
		var ind := _hud("lock_on_indicator.gd")
		_note("v5 target rows=%s index=%s in_range(row)=%s reticle dim=%s" % [str(tac._get_target_names()),
			str(tac._target_index), str(tac._is_row_in_range(tac._target_index)),
			str(ind.is_out_of_range() if ind else null)])
		await _shot("v5_03_target_list_out_of_range")
		# 04 Sword Slash on the in-range enemy.
		await _joy_tap(JOY_DPAD_UP)
		await _joy_tap(JOY_A)
		var fx := await _ability_effect()
		await _real(0.12)
		_note("v5 sword slash: state=%s effect=%s" % [_state_name(), str(fx)])
		await _shot("v5_04_sword_slash")
	await _close_menus()
	await _to_ground()
	_free_dummies()

	# 07 Taighe active (D-pad Up); battle for the Y label.
	await _place(lane, 0.0, -12.0)
	await _real(1.1)
	await _joy_tap(JOY_DPAD_UP)
	await _real(0.5)
	await _enter_battle(p)
	await _real(0.5)
	var hud := _hud("combat_hud.gd")
	_note("v5 after switch: member=%s toast=%s" % [str(p.get_member_data().display_name),
		str(hud.get(&"last_switch_toast") if hud else null)])
	await _shot("v5_07_taighe_active_hud")
	await _real(0.3)

	# 05 Water Geyser / 06 Wind Crescent (Taighe, at the target).
	await _place(lane, 0.0, -14.0)
	var tg := await _spawn_dummy(lane + Vector3(0.8, -0.1, -8.0))
	tac = await _menu_to_ability(&"water_geyser")
	if tac:
		await _joy_tap(JOY_A)
		await _joy_tap(JOY_A)
		var gfx := await _ability_effect()
		for i in 120:
			if gfx == null or not is_instance_valid(gfx) or gfx.get(&"erupted"):
				break
			await physics_frame
		tg.set_physics_process(true)
		await _real(0.18)
		_note("v5 geyser erupted=%s target y=%.2f" % [
			str(gfx.get(&"erupted") if gfx and is_instance_valid(gfx) else null), tg.global_position.y])
		await _shot("v5_05_water_geyser")
		tg.set_physics_process(false)
	await _close_menus()
	await _to_ground()
	tg.global_position = lane + Vector3(0.8, -0.1, -8.0)
	tg.set(&"velocity", Vector3.ZERO)
	await _real(0.6)
	tac = await _menu_to_ability(&"wind_crescent")
	if tac:
		await _joy_tap(JOY_A)
		await _joy_tap(JOY_A)
		var wfx := await _ability_effect()
		await _real(0.38)
		_note("v5 wind crescent hits so far=%s" % str(wfx.get(&"hit_count") if wfx and is_instance_valid(wfx) else null))
		await _shot("v5_06_wind_crescent")
	await _close_menus()
	await _to_ground()
	_free_dummies()
	p.battle_mode.force_exit()

	# 08 Super Jump apex + aerial Command Menu (battle: Y = unique, A = menu).
	await _place(Vector3(0, 0.1, 2), 0.0, -5.0)
	await _enter_battle(p)
	_fill_atb()
	await _joy_tap(JOY_Y, 0.03)
	var peak := p.global_position.y
	for i in 240:
		await physics_frame
		peak = maxf(peak, p.global_position.y)
		if p.velocity.y <= 0.5 and peak > 4.0:
			break
	await _joy_tap(JOY_A, 0.03)
	await _wait_armed()
	tac = _tac()
	if tac:
		await _joy_tap(JOY_A)   # Abilities -> aerial list
		await _real(0.2)
	_note("v5 super jump apex y=%.2f menu=%s airborne=%s" % [peak, _state_name(),
		str(tac.get(&"_opened_airborne") if tac else null)])
	await _shot("v5_08_super_jump_apex_aerial_list")
	await _close_menus()
	await _to_ground()
	p.battle_mode.force_exit()
	await _real(1.1)
	await _joy_tap(JOY_DPAD_DOWN)   # back to Amaro
	await _real(0.4)

	# 09 Air combo mid-air (free roam: A jump, X X), camera from the side.
	await _place(Vector3(0, 0.1, 2), 0.0, -8.0)
	var cam := _cam()
	await _joy_tap(JOY_A, 0.03)
	await _real(0.25)
	await _joy_tap(JOY_X, 0.05)
	await _real(0.2)
	await _joy_tap(JOY_X, 0.05)
	await _real(0.1)
	_note("v5 air combo: state=%s y=%.2f string=%s" % [_state_name(), p.global_position.y,
		str(p.combo.current_string() if p.combo else "")])
	await _shot("v5_09_air_combo")
	await _to_ground()

	# 10 Lock-on framing: target straight ahead on the camera->player line.
	await _place(lane, 0.0, -12.0)
	var lf := await _spawn_dummy(lane + Vector3(0, -0.1, -8.0))
	await _real(0.3)
	await _tap(&"lock_on")
	await _real(1.6)
	var c3d: Camera3D = cam.get(&"camera") if cam else null
	if c3d:
		var pp := c3d.unproject_position(p.global_position + Vector3(0, 1.0, 0))
		var tp := c3d.unproject_position(lf.global_position + Vector3(0, 1.0, 0))
		_note("v5 framing: locked=%s player px=%s target px=%s dx=%.0f" % [str(p.is_locked_on), str(pp), str(tp),
			absf(pp.x - tp.x)])
	await _shot("v5_10_lockon_framing")
	await _tap(&"lock_on")
	_free_dummies()
