## v8 tests — context button A, hold-to-aim dodge, Arcane Focus, Super Jump command.
## Runs in the Battle Test arena (flat, walled; the stations are removed so no
## enemy engages by itself). Every input goes through real InputEvents
## (Input.parse_input_event) unless a check is a pure unit check.
##  - A (pad) interacts while a prompt is up (no jump), jumps otherwise; Y (pad)
##    opens the Command Menu in Free Roam even with a prompt; keyboard E still
##    interacts and Space still jumps; in battle A = Command Menu, never a jump.
##    Hold interactions charge on A. Hints and the world prompt show A.
##  - Dodge: B tap dodges on release; holding B keeps the momentum and aims with
##    the stick; release fires roll / side / back by the aim vs facing; back =
##    big backflip (Amaro) / floaty back-leap (Taighe); auto-fire at 1 s; a hit
##    in DodgeReady flinches; visuals are restored after.
##  - Taighe: Y in battle = Arcane Focus (hold channel: rooted, MP up, 3
##    empowered bolts, faster charged shot; short / hit channels give nothing);
##    Super Jump is a Command Menu command (no target step, ~5x jump height).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const ARENA := "res://scenes/zones/battle_test.tscn"
const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_DPAD_DOWN := 12
const PHASE_ABILITY := 1
const SWITCH_WAIT := 1.15
const WATCHDOG_SECONDS := 300.0

## Test interactable: counts interact() calls.
class Probe extends "res://src/interaction/interactable.gd":
	var hits: int = 0
	func interact(_p: Node) -> void:
		hits += 1

var _zone: Node = null
var _player: Node = null
var _party: Node = null
var _rig: Node = null
var _finished: bool = false


func _ready() -> void:
	print("=== v8 Tests (context A, hold dodge, Arcane Focus, Super Jump command) ===")
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs" % WATCHDOG_SECONDS)
		_finish())
	await _run_tests()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all_input()
	Engine.time_scale = 1.0
	print("\n=== V8 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	if not await _load_zone():
		return
	_section("Context button (A) / Command (Y)")
	await test_context_button()
	await test_hold_interact_on_a()
	await test_battle_buttons()
	_section("Hold-to-aim dodge (Amaro)")
	await test_dodge_tap()
	await test_dodge_hold_back()
	await test_dodge_hold_side()
	await test_dodge_auto_fire_and_hit()
	await test_dodge_lock_on_back()
	_section("Taighe")
	await _switch_to(&"companion")
	await test_taighe_glide_dodge()
	await test_arcane_focus()
	await test_super_jump_command()
	_teardown_zone()
	await _frames(5)


# ========== CONTEXT BUTTON ==========

func _make_probe(offset: Vector3, hold: bool = false) -> Probe:
	var p := Probe.new()
	p.name = "Probe"
	p.interaction_name = "Probe"
	p.hold_to_interact = hold
	p.hold_duration = 0.6
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	col.shape = sh
	p.add_child(col)
	_zone.add_child(p)
	p.global_position = _player.global_position + offset
	return p


func test_context_button() -> void:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	await _ground_idle()
	var probe := _make_probe(Vector3(0, 0.5, -0.8))
	var got := await _wait_until(func() -> bool: return _player.get_current_interactable() == probe, 2.0)
	_assert(got, "probe interactable is targeted")

	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	var y0: float = _player.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	await _physics_frames(6)
	_assert(probe.hits == 1, "pad A with a prompt interacts", "hits=%d" % probe.hits)
	_assert(_player.global_position.y - y0 < 0.1 and _state() != &"Jump",
		"... and does not jump", "dy=%.2f state=%s" % [_player.global_position.y - y0, _state()])

	var wp := _hud("world_prompt.gd")
	await _frames(4)
	_assert(wp != null and wp.get_glyph_label() == "A", "world prompt shows the A button on a pad",
		"label=%s" % (wp.get_glyph_label() if wp else "?"))
	var bar := _hud("control_bar.gd")
	var entries: Array = bar.get_hint_entries() if bar else []
	var a_text := ""
	var y_text := ""
	for e in entries:
		if e[0] == "A":
			a_text = e[1]
		if e[0] == "Y":
			y_text = e[1]
	_assert(a_text == "Interact" and y_text == "Command", "hints: A Interact, Y Command while a prompt is up",
		str(entries))

	# Pad Y with a prompt: Command Menu, no interaction.
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(_state() == &"TacticalIdle" and probe.hits == 1, "pad Y with a prompt opens the Command Menu",
		"state=%s hits=%d" % [_state(), probe.hits])
	await _close_menu()
	await _ground_idle()

	# Keyboard: E interacts, Space jumps.
	InputManager.active_device = InputManager.DeviceType.KEYBOARD_MOUSE
	await _tap(_key_press(KEY_E), _key_release(KEY_E))
	await _physics_frames(3)
	_assert(probe.hits == 2, "keyboard E with a prompt interacts", "hits=%d" % probe.hits)
	await _frames(4)
	_assert(wp != null and wp.get_glyph_label() == "E", "world prompt shows E on keyboard",
		"label=%s" % (wp.get_glyph_label() if wp else "?"))
	await _ground_idle()
	await _tap(_key_press(KEY_SPACE), _key_release(KEY_SPACE))
	await _physics_frames(4)
	_assert(_state() == &"Jump" or _state() == &"Fall", "keyboard Space with a prompt still jumps",
		"state=%s" % _state())
	await _ground_idle()
	InputManager.active_device = InputManager.DeviceType.CONTROLLER

	# No prompt: A jumps.
	probe.queue_free()
	await _wait_until(func() -> bool: return _player.get_current_interactable() == null, 2.0)
	await _ground_idle()
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.03)
	await _physics_frames(3)
	_assert(_state() == &"Jump" or _state() == &"Fall", "pad A with no prompt jumps", "state=%s" % _state())
	await _ground_idle()
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	_assert(_state() == &"TacticalIdle", "pad Y with no prompt opens the Command Menu", "state=%s" % _state())
	await _close_menu()


func test_hold_interact_on_a() -> void:
	await _ground_idle()
	var probe := _make_probe(Vector3(0, 0.5, -0.8), true)
	await _wait_until(func() -> bool: return _player.get_current_interactable() == probe, 2.0)
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.15)
	await _physics_frames(4)
	_assert(probe.hits == 0 and _state() != &"Jump", "hold interaction: a short A tap does nothing",
		"hits=%d state=%s" % [probe.hits, _state()])
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.9)
	await _physics_frames(4)
	_assert(probe.hits == 1, "hold interaction: holding A 0.9 s fires it", "hits=%d" % probe.hits)
	probe.queue_free()
	await _wait_until(func() -> bool: return _player.get_current_interactable() == null, 2.0)


func test_battle_buttons() -> void:
	await _ground_idle()
	await _enter_battle()
	var y0: float = _player.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(_state() == &"TacticalIdle" and _player.global_position.y - y0 < 0.1,
		"battle: A opens the Command Menu and never jumps", "state=%s" % _state())
	await _close_menu()
	await _ground_idle()
	_player.battle_mode.force_exit()
	await _frames(3)


# ========== DODGE ==========

func test_dodge_tap() -> void:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	await _ground_idle()
	await _real_seconds(0.5)
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	_assert(_state() == &"DodgeReady", "B press enters DodgeReady (hold to aim)", "state=%s" % _state())
	Input.parse_input_event(_joy_release(JOY_B))
	await _physics_frames(2)
	var st: Node = _player.state_machine.states[&"Dodge"]
	_assert(_state() == &"Dodge" and st.kind == &"roll", "B tap (released) dodges: forward roll",
		"state=%s kind=%s" % [_state(), st.kind])
	await _ground_idle()


## Runs forward (-Z, camera yaw 0), presses B and keeps it held.
func _run_then_hold_b() -> Vector3:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	await _ground_idle()
	await _real_seconds(0.5)
	Input.action_press(&"move_up")
	await _physics_frames(30)
	var mom := Vector3(_player.velocity.x, 0, _player.velocity.z)
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	return mom


func test_dodge_hold_back() -> void:
	var mom := await _run_then_hold_b()
	_assert(_state() == &"DodgeReady" and mom.length() > 4.0, "running + hold B -> DodgeReady",
		"state=%s speed=%.1f" % [_state(), mom.length()])
	var face0: Vector3 = -_player.global_basis.z
	Input.action_release(&"move_up")
	Input.action_press(&"move_down")
	await _physics_frames(12)
	var ready: Node = _player.state_machine.states[&"DodgeReady"]
	var vel := Vector3(_player.velocity.x, 0, _player.velocity.z)
	_assert(_state() == &"DodgeReady" and vel.distance_to(mom) < 0.5,
		"while held the momentum is kept (stick only aims)", "vel=%s mom=%s" % [vel, mom])
	_assert((-_player.global_basis.z).dot(face0) > 0.99, "while held the facing is kept")
	_assert(ready.pending_kind() == &"back", "stick back while held aims a BACK dodge", "kind=%s" % ready.pending_kind())
	var marker := _zone.find_child("DodgeAimMarker", true, false)
	_assert(marker != null, "an aim chevron shows on the ground while held")
	var start: Vector3 = _player.global_position
	Input.parse_input_event(_joy_release(JOY_B))
	await _physics_frames(2)
	var st: Node = _player.state_machine.states[&"Dodge"]
	_assert(_state() == &"Dodge" and st.kind == &"back" and st.style == &"acrobat",
		"release fires the backflip (Amaro: acrobat)", "state=%s kind=%s style=%s" % [_state(), st.kind, st.style])
	var peak := start.y
	var rotated := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and _state() == &"Dodge":
		await get_tree().physics_frame
		peak = maxf(peak, _player.global_position.y)
		var b: Basis = _player.visual_root.transform.basis
		if absf(b.y.z) > 0.5:
			rotated = true  # flipped about the side axis
	Input.action_release(&"move_down")
	var travel: Vector3 = _player.global_position - start
	_assert(peak - start.y >= 1.2, "backflip is a big jump (>= 1.2 m)", "peak=%.2f" % (peak - start.y))
	_assert(travel.z > 4.0, "backflip travels back (>= 4 m, opposite the run)", "travel=%s" % travel)
	_assert(rotated, "backflip visual: the model flips about its side axis")
	_assert((-_player.global_basis.z).dot(face0) > 0.99, "backflip keeps facing forward")
	await _physics_frames(3)
	_assert(_player.is_on_floor() and (_state() == &"Idle" or _state() == &"Run"),
		"backflip lands back in free locomotion", "state=%s" % _state())
	_assert(_player.visual_root.transform.is_equal_approx(Transform3D.IDENTITY),
		"visual root restored after the dodge")
	_assert(_zone.find_child("DodgeAimMarker", true, false) == null or \
		_zone.find_child("DodgeAimMarker", true, false).is_queued_for_deletion(), "aim chevron removed")


func test_dodge_hold_side() -> void:
	await _run_then_hold_b()
	Input.action_release(&"move_up")
	Input.action_press(&"move_right")
	await _physics_frames(8)
	var start: Vector3 = _player.global_position
	Input.parse_input_event(_joy_release(JOY_B))
	await _physics_frames(2)
	var st: Node = _player.state_machine.states[&"Dodge"]
	_assert(st.kind == &"side" and st.side_sign > 0.0, "stick right while held -> SIDE dodge to the right",
		"kind=%s side=%.0f" % [st.kind, st.side_sign])
	var rolled := false
	while _state() == &"Dodge":
		await get_tree().physics_frame
		if absf(_player.visual_root.transform.basis.y.x) > 0.5:
			rolled = true  # cartwheel: up axis swings sideways
	Input.action_release(&"move_right")
	var travel: Vector3 = _player.global_position - start
	_assert(travel.x > 2.0 and absf(travel.x) > absf(travel.z), "side dodge moves right", "travel=%s" % travel)
	_assert(rolled, "Amaro side dodge is a cartwheel (model rolls over sideways)")
	await _ground_idle()


func test_dodge_auto_fire_and_hit() -> void:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	await _ground_idle()
	await _real_seconds(0.5)
	Input.parse_input_event(_joy_press(JOY_B))
	var fired := await _wait_until(func() -> bool: return _state() == &"Dodge", 2.0)
	var ready: Node = _player.state_machine.states[&"DodgeReady"]
	_assert(fired and ready.held_time >= 0.95, "holding B fires the dodge by itself after ~1 s",
		"fired=%s held=%.2f" % [fired, ready.held_time])
	Input.parse_input_event(_joy_release(JOY_B))
	await _ground_idle()
	await _real_seconds(0.5)
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	_player.take_damage(1.0, null)
	await _physics_frames(1)
	_assert(_state() == &"Flinch", "a hit while aiming a dodge flinches (no i-frames)", "state=%s" % _state())
	Input.parse_input_event(_joy_release(JOY_B))
	_player.current_hp = _player.max_hp
	await _ground_idle()


func test_dodge_lock_on_back() -> void:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	var target := _spawn_frozen_enemy(Vector3(0, 1, 15))
	await _physics_frames(4)
	await _tap(_action_event(&"lock_on", true), _action_event(&"lock_on", false))
	await _physics_frames(10)
	_assert(_player.is_locked_on, "locked on to the enemy ahead")
	Input.action_press(&"move_down")
	await _physics_frames(4)
	await _tap(_joy_press(JOY_B), _joy_release(JOY_B), 0.1)
	var st: Node = _player.state_machine.states[&"Dodge"]
	_assert(st.kind == &"back", "locked on + stick back: dodge is a backflip away from the target",
		"kind=%s" % st.kind)
	Input.action_release(&"move_down")
	await _ground_idle()
	await _tap(_action_event(&"lock_on", true), _action_event(&"lock_on", false))
	target.queue_free()
	await _physics_frames(4)
	_player.battle_mode.force_exit()
	await _ground_idle()


# ========== TAIGHE ==========

func test_taighe_glide_dodge() -> void:
	_assert(_is_member(&"companion"), "switched to Taighe")
	var mom := await _run_then_hold_b()
	Input.action_release(&"move_up")
	Input.action_press(&"move_down")
	await _physics_frames(8)
	var start: Vector3 = _player.global_position
	var ghosts_before := _count_ghosts()
	Input.parse_input_event(_joy_release(JOY_B))
	await _physics_frames(2)
	var st: Node = _player.state_machine.states[&"Dodge"]
	_assert(st.kind == &"back" and st.style == &"glide", "Taighe back dodge uses the glide style",
		"kind=%s style=%s" % [st.kind, st.style])
	var spun := false
	var t0 := Time.get_ticks_msec()
	var ghosts_max := 0
	while _state() == &"Dodge" and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().physics_frame
		var b: Basis = _player.visual_root.transform.basis
		if absf(b.x.z) > 0.7:
			spun = true  # spun about the vertical axis
		ghosts_max = maxi(ghosts_max, _count_ghosts())
	var air_ms := Time.get_ticks_msec() - t0
	Input.action_release(&"move_down")
	_assert(spun, "Taighe back-leap spins (spin of light)")
	_assert(st.move_time > 0.85, "Taighe back-leap floats longer than Amaro's flip (~0.65 s)",
		"airtime=%.2f s" % st.move_time)
	_assert(ghosts_max - ghosts_before >= 3, "Taighe dodge leaves an ice trail of afterimages",
		"ghosts=%d" % (ghosts_max - ghosts_before))
	_assert((_player.global_position - start).z > 4.0, "Taighe back-leap travels back")
	await _ground_idle()


func test_arcane_focus() -> void:
	await _ground_idle()
	_place_player(Vector3(0, 0.1, 20), 0.0)
	var st: Node = _player.stance
	_assert(st.ability_id == &"arcane_focus" and st.is_channel(), "Taighe's unique ability is Arcane Focus",
		"id=%s" % st.ability_id)
	var focus: Node = st.ability
	await _enter_battle()
	_player.current_mp = 10.0
	var mp0: float = _player.current_mp
	var pos0: Vector3 = _player.global_position
	Input.action_press(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", true))
	await _physics_frames(3)
	_assert(_state() == &"Focus" and focus.channeling, "hold R / Y in battle starts the channel",
		"state=%s" % _state())
	Input.action_press(&"move_up")
	await _real_seconds(1.4)
	Input.action_release(&"move_up")
	_assert(_state() == &"Focus" and focus.level >= 1.0, "channel reaches full focus in ~1.2 s",
		"level=%.2f" % focus.level)
	_assert(_player.current_mp >= mp0 + 5.0, "channelling restores MP", "mp %.1f -> %.1f" % [mp0, _player.current_mp])
	var moved: float = Vector2(_player.global_position.x - pos0.x, _player.global_position.z - pos0.z).length()
	_assert(moved < 0.2, "channelling roots her (stick ignored)", "moved=%.2f" % moved)
	Input.action_release(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", false))
	await _physics_frames(3)
	_assert(_state() == &"Idle" and focus.charges == 3 and focus.power >= 0.99,
		"release: FOCUSED with 3 empowered bolts", "state=%s charges=%d power=%.2f" % [_state(), focus.charges, focus.power])
	_assert(_player.combo.hold_threshold_ms() == focus.FOCUSED_HOLD_THRESHOLD_MS,
		"focused: charged shot needs a shorter hold", "ms=%d" % _player.combo.hold_threshold_ms())

	await _real_seconds(0.4)
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.05)
	await _physics_frames(2)
	var ms: Node = _player.state_machine.states[&"MeleeStrike"]
	var base: float = _player.combo.active_profile().get_strike(&"light")["damage"]
	_assert(ms.focused and ms.damage > base * 1.5 and focus.charges == 2,
		"next bolt is empowered (+60% at full focus) and spends a charge",
		"focused=%s dmg=%.1f base=%.1f charges=%d" % [ms.focused, ms.damage, base, focus.charges])
	await _ground_idle()

	# Short channel: nothing.
	focus.clear_focus()
	Input.action_press(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", true))
	await _physics_frames(6)
	Input.action_release(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", false))
	await _physics_frames(3)
	_assert(focus.charges == 0, "a very short channel grants nothing", "charges=%d" % focus.charges)
	await _ground_idle()

	# Hit while channelling: interrupted.
	await _real_seconds(0.2)
	Input.action_press(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", true))
	await _real_seconds(0.6)
	_player.take_damage(1.0, null)
	await _physics_frames(2)
	Input.action_release(&"unique_ability")
	Input.parse_input_event(_action_event(&"unique_ability", false))
	_assert(_state() == &"Flinch" and focus.charges == 0 and not focus.channeling,
		"a hit interrupts the channel (no focus)", "state=%s charges=%d" % [_state(), focus.charges])
	_player.current_hp = _player.max_hp
	await _ground_idle()

	# Battle end clears the buff.
	focus.charges = 3
	_player.battle_mode.force_exit()
	await _frames(3)
	_assert(focus.charges == 0, "leaving Battle Mode clears the focus")
	await _ground_idle()


func test_super_jump_command() -> void:
	await _ground_idle()
	var ids: Array = []
	for a in _player.ability_system.equipped_abilities:
		if a:
			ids.append(a.ability_id)
	_assert(ids.has(&"super_jump"), "Taighe's Command Menu lists Super Jump", str(ids))
	_place_player(Vector3(0, 0.1, 20), 0.0)
	await _ground_idle()
	var ground: float = _player.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A), 0.03)
	var peak_n := await _peak_height(ground)
	await _ground_idle()
	await _physics_frames(6)

	var tac := await _open_to_ability(&"super_jump")
	if tac == null:
		return
	ground = _player.global_position.y
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) != 2, "Super Jump fires without a target step", "phase=%s" % str(tac._phase))
	var launched := await _wait_until(func() -> bool: return _state() == &"Jump" or _state() == &"Fall", 1.5)
	_assert(launched, "confirming Super Jump launches her", "state=%s" % _state())
	var peak_s := await _peak_height(ground)
	var ratio := peak_s / maxf(peak_n, 0.01)
	_assert(ratio >= 4.3 and ratio <= 5.7, "Super Jump command reaches ~5x the normal jump",
		"normal=%.2f super=%.2f ratio=%.2f" % [peak_n, peak_s, ratio])
	await _ground_idle()


# ========== HELPERS ==========

func _count_ghosts() -> int:
	var n := 0
	for c in _zone.get_children():
		if String(c.name).contains("DodgeVFX") and not c.is_queued_for_deletion():
			n += 1
	return n


func _spawn_frozen_enemy(pos: Vector3) -> Node3D:
	var e: Node3D = (load("res://src/enemies/enemy.tscn") as PackedScene).instantiate()
	_zone.add_child(e)
	e.global_position = pos
	e.set_physics_process(false)
	if e.get_node_or_null(^"AggroArea"):
		e.get_node(^"AggroArea").set_deferred("monitoring", false)
	return e


func _switch_to(id: StringName) -> void:
	await _ground_idle()
	var guard := 0
	while not _is_member(id) and guard < 3:
		await _real_seconds(SWITCH_WAIT)
		_party.switch_member()
		await _physics_frames(4)
		guard += 1
	await _ground_idle()


func _is_member(id: StringName) -> bool:
	return _party != null and _party.members.size() > _party.active_index \
		and _party.members[_party.active_index].id == id


func _enter_battle() -> void:
	if not _player.in_battle:
		_player.battle_mode.toggle_manual()
	await _frames(4)


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


func _open_to_ability(id: StringName) -> Node:
	_player.current_atb = _player.max_atb
	await _ground_idle()
	await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	if _state() != &"TacticalIdle":
		_fail("Command Menu opens (for %s)" % id, "state=%s" % _state())
		return null
	var tac: Node = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	if int(tac._phase) != PHASE_ABILITY:
		_fail("Abilities category opens (for %s)" % id, "phase=%s" % str(tac._phase))
		await _close_menu()
		return null
	var guard := 0
	while (tac._ability_at_cursor() == null or tac._ability_at_cursor().ability_id != id) and guard < 10:
		await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
		guard += 1
	if tac._ability_at_cursor() == null or tac._ability_at_cursor().ability_id != id:
		_fail("Ability list reaches %s" % id)
		await _close_menu()
		return null
	return tac


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


func _ground_idle() -> void:
	_release_all_input()
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _wait_on_floor(300)
	var s := _state()
	if s != &"Idle" and s != &"LockOnIdle":
		_player.state_machine.force_transition(&"LockOnIdle" if _player.is_locked_on else &"Idle")
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)


func _place_player(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	if _rig and _rig.get(&"yaw_pivot"):
		_rig.yaw_pivot.rotation.y = yaw


func _load_zone() -> bool:
	var ps = load(ARENA) as PackedScene
	if ps == null:
		_fail("Zone harness", "arena failed to load")
		return false
	GameManager.change_state(GameManager.GameState.PLAYING)
	_zone = ps.instantiate()
	add_child(_zone)
	await _frames(30)
	_player = _zone.get(&"player")
	if _player == null or not is_instance_valid(_player):
		_fail("Zone harness", "zone has no player")
		return false
	# Remove the stations: nothing may engage on its own.
	for n in [&"EnemySpawner"]:
		var node := _zone.get_node_or_null(NodePath(String(n)))
		if node:
			node.queue_free()
	for e in get_tree().get_nodes_in_group(&"enemies"):
		e.queue_free()
	_party = _player.party_system
	_rig = null
	for ch in _zone.get_children():
		if ch.get(&"yaw_pivot") != null:
			_rig = ch
	await _wait_on_floor(240)
	await _frames(10)
	if _player.in_battle:
		_player.battle_mode.force_exit()
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	return true


func _teardown_zone() -> void:
	_release_all_input()
	if _party:
		for m in _party.members:
			var n: Node = m.get("node")
			if is_instance_valid(n) and n != _player and not _zone.is_ancestor_of(n):
				n.queue_free()
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null


func _hud(script_file: String) -> Node:
	if _zone == null:
		return null
	for ch in _zone.find_children("*", "CanvasLayer", true, false):
		if ch.get_script() and String(ch.get_script().resource_path).ends_with(script_file):
			return ch
	return null


func _state() -> StringName:
	var cur: Node = _player.state_machine.current_state if _player else null
	return StringName(cur.name) if cur else &""


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


func _action_event(action: StringName, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev


func _key_press(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _key_release(code: Key) -> InputEventKey:
	var ev := _key_press(code)
	ev.pressed = false
	return ev


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
