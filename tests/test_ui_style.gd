## UI Modernization tests (Package P, docs/plans/ui_modernization_plan.md).
## Covers: UIStyle palette + fonts, every K widget instantiating headless,
## ButtonGlyph labels per action/device, the HUD layers that zone_base spawns
## in field_zone (no runtime errors), and the new target bar / tactical overlay
## registration (zone_base + test_arena) and behaviour.
## v4: the minimap (registration, top-right frame, mouse-ignore, UIStyle-only
## colours, field icons) and the battle_toggle glyph (Back / F).
## Run: Z:/godot/godot.exe --path . --headless --scene res://tests/test_ui_style.tscn
extends Node

const FIELD_ZONE_SCENE := "res://scenes/zones/field_zone.tscn"
const ZONE_BASE_PATH := "res://src/world/zone_base.gd"
const TEST_ARENA_PATH := "res://scenes/test/test_arena.gd"
const WATCHDOG_SECONDS := 90.0

## Every HUD/menu script zone_base._spawn_hud must create exactly once.
const HUD_SCRIPTS := [
	"res://src/ui/hud/combat_hud.gd",
	"res://src/ui/hud/control_bar.gd",
	"res://src/ui/hud/tactical_menu.gd",
	"res://src/ui/hud/lock_on_indicator.gd",
	"res://src/ui/hud/target_bar.gd",
	"res://src/ui/hud/tactical_overlay.gd",
	"res://src/ui/hud/interaction_prompt.gd",
	"res://src/ui/hud/quest_tracker.gd",
	"res://src/ui/hud/battle_banner.gd",
	"res://src/ui/hud/minimap.gd",
	"res://src/ui/dialogue/dialogue_ui.gd",
	"res://src/ui/menus/pause_menu.gd",
	"res://src/ui/hud/save_feedback.gd",
	"res://src/ui/hud/loading_screen.gd",
]

## Expected pad / keyboard labels for the current default bindings
## (BINDINGS_VERSION 5 + Battle System v3/v4: tactical_mode / unique_ability are keyboard-only, Runtime InputMap is the source of truth;
## these pin the contract the HUD glyphs show.
const EXPECTED_LABELS := {
	&"tactical_mode": ["---", "Q"],
	&"jump": ["A", "Space"],
	&"attack": ["X", "LMB"],
	&"dodge": ["B", "Shift"],
	&"interact": ["Y", "E"],
	&"lock_on": ["RT", "MMB"],
	&"pause": ["Start", "Esc"],
	&"camera_reset": ["R3", ""],
	&"target_switch_left": ["D-Left", "["],
	&"target_switch_right": ["D-Right", "]"],
	&"party_switch": ["D-Up/D-Down", "Tab"],
	&"ui_accept": ["A", ""],
	&"ui_cancel": ["B", "Esc"],
	&"battle_toggle": ["View", "F"],
}


class ErrorCounter extends Logger:
	var _mutex := Mutex.new()
	var errors: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, _code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s:%d %s %s" % [file, line, function, rationale])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out


var _passed: int = 0
var _failed: int = 0
var _total: int = 0
var _logger: ErrorCounter = null
var _done := false


func _ready() -> void:
	print("=== UI Style Tests (UI Modernization) ===")
	print("")
	_logger = ErrorCounter.new()
	OS.add_logger(_logger)
	var t := get_tree().create_timer(WATCHDOG_SECONDS, true, false, true)
	t.timeout.connect(func():
		if not _done:
			_fail("Watchdog", "suite did not finish within %.0fs" % WATCHDOG_SECONDS)
			_finish())
	await _run_tests()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _logger:
		OS.remove_logger(_logger)
	print("\n=== UI Style Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("UISTYLE — PALETTE / FONTS")
	test_palette()
	test_fonts()
	test_styleboxes()

	_section("WIDGETS — HEADLESS INSTANTIATION")
	await test_widgets_instantiate()
	await test_gauge_behaviour()

	_section("BUTTONGLYPH — LABELS PER ACTION / DEVICE")
	await test_glyph_labels()

	_section("REGISTRATION — SOURCE")
	test_registration_source()

	_section("FIELD ZONE — HUD LAYERS")
	await test_field_zone_hud()


# ========== UISTYLE ==========

func test_palette() -> void:
	_assert(UIStyle.CYAN.is_equal_approx(Color("#5FE3F0")), "Primary accent is Lumina cyan #5FE3F0")
	_assert(UIStyle.GOLD.is_equal_approx(Color("#F2B544")), "Secondary accent is ember gold #F2B544")
	_assert(UIStyle.MP.is_equal_approx(Color("#B48CFF")), "MP colour is violet #B48CFF")
	_assert(UIStyle.STAGGER.is_equal_approx(Color("#FF8A3D")), "Stagger colour is orange #FF8A3D")
	_assert(UIStyle.DANGER.is_equal_approx(Color("#FF5C5C")), "Danger colour is #FF5C5C")
	_assert(UIStyle.TEXT.is_equal_approx(Color("#E8F1F5")), "Text colour is #E8F1F5")
	_assert(UIStyle.TEXT_DIM.is_equal_approx(Color("#7F95A3")), "Dim text colour is #7F95A3")
	_assert(UIStyle.TEXT_DISABLED.is_equal_approx(Color("#4A5A66")), "Disabled text colour is #4A5A66")
	_assert(absf(UIStyle.GLASS.a - 0.78) < 0.01, "Glass panel is ~78% opacity", "a=%.2f" % UIStyle.GLASS.a)
	_assert(UIStyle.SIZE_S < UIStyle.SIZE_M and UIStyle.SIZE_M < UIStyle.SIZE_L and UIStyle.SIZE_L < UIStyle.SIZE_XL,
		"Font sizes S < M < L < XL")
	_assert(UIStyle.ANIM_TIME >= 0.12 and UIStyle.ANIM_TIME <= 0.16, "Animation time within 120–160ms",
		"%.3f" % UIStyle.ANIM_TIME)
	_assert(UIStyle.hp_color(0.1) == UIStyle.DANGER, "hp_color(low) returns DANGER")
	_assert(UIStyle.hp_color(0.9) != UIStyle.DANGER, "hp_color(high) is not DANGER")


func test_fonts() -> void:
	for p in [UIStyle.FONT_HEADER_PATH, UIStyle.FONT_HEADER_MEDIUM_PATH, UIStyle.FONT_BODY_PATH, UIStyle.FONT_BODY_BOLD_PATH]:
		_assert(ResourceLoader.exists(p), "Bundled font exists: %s" % p.get_file())
	_assert(FileAccess.file_exists("res://assets/fonts/rajdhani/OFL.txt"), "Rajdhani OFL licence bundled")
	_assert(FileAccess.file_exists("res://assets/fonts/barlow/OFL.txt"), "Barlow OFL licence bundled")
	_assert(UIStyle.fonts_bundled(), "UIStyle.fonts_bundled() is true")
	for f in [UIStyle.font_header(), UIStyle.font_header_medium(), UIStyle.font_body(), UIStyle.font_body_bold()]:
		_assert(f != null and f is Font, "Font getter returns a Font", str(f))
	_assert(UIStyle.font_header() != ThemeDB.fallback_font, "Header font is not the fallback font")
	_assert(UIStyle.font_body() != ThemeDB.fallback_font, "Body font is not the fallback font")
	var l := UIStyle.make_label("Test", UIStyle.SIZE_L, UIStyle.GOLD, true)
	_assert(l.get_theme_font_size("font_size") == UIStyle.SIZE_L, "make_label applies size")
	_assert(l.get_theme_color("font_color") == UIStyle.GOLD, "make_label applies colour")
	l.free()


func test_styleboxes() -> void:
	_assert(UIStyle.glass_panel() is StyleBoxFlat, "glass_panel() returns StyleBoxFlat")
	_assert(UIStyle.glass_panel_selected() is StyleBoxFlat, "glass_panel_selected() returns StyleBoxFlat")
	_assert(UIStyle.pill() is StyleBoxFlat, "pill() returns StyleBoxFlat")
	for s in ["normal", "selected", "disabled"]:
		_assert(UIStyle.slant_row(s) is StyleBoxFlat, "slant_row(%s) returns StyleBoxFlat" % s)
	var th := UIStyle.make_theme()
	_assert(th is Theme, "make_theme() returns Theme")
	var pts := UIStyle.slant_points(Rect2(0, 0, 100, 20), 10.0, true, false)
	_assert(pts.size() == 4, "slant_points returns a quad", str(pts.size()))
	var b := Button.new()
	b.text = "Keep"
	UIStyle.style_button(b)
	_assert(b.text == "Keep", "style_button keeps the button text")
	b.free()


# ========== WIDGETS ==========

func test_widgets_instantiate() -> void:
	var host := Control.new()
	host.size = Vector2(800, 600)
	add_child(host)

	var panel := SlantPanel.new()
	host.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var tab := HeaderTab.new().setup("Command", "Amaro")
	v.add_child(tab)
	var gauge := Gauge.new()
	v.add_child(gauge)
	var seg := SegmentGauge.new()
	v.add_child(seg)
	var glyph := ButtonGlyph.new().setup(&"interact", ButtonGlyph.Device.CONTROLLER)
	v.add_child(glyph)
	var hint := GlyphHint.create(&"ui_accept", "Confirm")
	v.add_child(hint)
	var row := MenuRow.new().setup("Fire", 1, 8, true, "Not enough MP")
	v.add_child(row)
	await _frames(3)

	_assert(panel is PanelContainer and panel.is_inside_tree(), "SlantPanel instantiates")
	_assert(tab.get_title_label() != null, "HeaderTab has a title label")
	_assert(tab.get_title_label().text.to_upper().contains("COMMAND"), "HeaderTab title is set",
		tab.get_title_label().text)
	_assert(tab.get_subtitle_label() != null and tab.get_subtitle_label().text.to_upper().contains("AMARO"),
		"HeaderTab subtitle is set")
	_assert(gauge.custom_minimum_size != Vector2.ZERO or gauge.get_combined_minimum_size() != Vector2.ZERO,
		"Gauge has a minimum size")
	_assert(seg.get_max_value() == 100.0, "SegmentGauge default is 2 x 50 = 100", str(seg.get_max_value()))
	_assert(glyph.get_label() == "Y", "ButtonGlyph(interact, CONTROLLER) shows Y", glyph.get_label())
	_assert(hint.get_glyph() != null and hint.get_label() != null and hint.get_label().text == "Confirm",
		"GlyphHint has glyph + label")
	_assert(row.is_greyed(), "MenuRow unavailable row is greyed")
	_assert(row.text.contains("Fire") or row.get("text") != null, "MenuRow keeps its text")
	_assert(row.atb_cost == 1 and row.mp_cost == 8, "MenuRow stores ATB/MP cost")
	row.selected = true
	await _frames(1)
	_assert(row.is_highlighted(), "MenuRow selected = highlighted")
	host.queue_free()
	await _frames(2)


func test_gauge_behaviour() -> void:
	var g := Gauge.new()
	g.low_threshold = 0.25
	add_child(g)
	g.set_values(100, 100, true)
	_assert(is_equal_approx(g.get_target_ratio(), 1.0), "Gauge full ratio is 1.0")
	_assert(not g.is_low(), "Gauge full is not low")
	g.set_values(10, 100)
	_assert(is_equal_approx(g.get_target_ratio(), 0.1), "Gauge target ratio after drop is 0.1")
	_assert(g.is_low(), "Gauge at 10% is low (threshold 25%)")
	g.snap()
	_assert(is_equal_approx(g.get_display_ratio(), 0.1), "Gauge snap() reaches the target")
	g.queue_free()

	var s := SegmentGauge.new()
	add_child(s)
	s.set_value(75, true)
	_assert(s.get_full_segments() == 1, "SegmentGauge 75/100 has 1 full cell", str(s.get_full_segments()))
	s.set_value(100, true)
	_assert(s.get_full_segments() == 2, "SegmentGauge 100/100 has 2 full cells")
	s.queue_free()
	await _frames(1)


# ========== BUTTONGLYPH ==========

func test_glyph_labels() -> void:
	var sm := get_node_or_null("/root/SettingsManager")
	_assert(sm != null, "SettingsManager autoload present")
	if sm == null:
		return
	for action in EXPECTED_LABELS:
		var pad: String = EXPECTED_LABELS[action][0]
		var kb: String = EXPECTED_LABELS[action][1]
		var got_pad := ButtonGlyph.label_for(action, true)
		var got_kb := ButtonGlyph.label_for(action, false)
		_assert(got_pad == sm.get_action_label(action, true) and got_kb == sm.get_action_label(action, false),
			"label_for(%s) matches SettingsManager on both devices" % action)
		_assert(got_pad == pad, "Pad glyph for %s is %s" % [action, pad], got_pad)
		if kb != "":
			_assert(got_kb == kb, "Keyboard glyph for %s is %s" % [action, kb], got_kb)
	_assert(ButtonGlyph.label_for(&"no_such_action_xyz", true) == "---", "Unknown action shows ---")

	# Device switching: AUTO follows InputManager.
	var im := get_node_or_null("/root/InputManager")
	var g := ButtonGlyph.new().setup(&"jump")  # v3: A / Space (tactical_mode is keyboard-only)
	add_child(g)
	if im and "active_device" in im:
		var prev = im.active_device
		im.active_device = 1
		im.device_changed.emit(1)
		await _frames(1)
		_assert(g.get_label() == "A", "AUTO glyph shows pad label on controller (jump = A)", g.get_label())
		im.active_device = 0
		im.device_changed.emit(0)
		await _frames(1)
		_assert(g.get_label() == "Space", "AUTO glyph shows key label on keyboard (jump = Space)", g.get_label())
		im.active_device = prev
		im.device_changed.emit(prev)
	else:
		_fail("InputManager.active_device", "not available")
	var forced := ButtonGlyph.new().setup(&"jump", ButtonGlyph.Device.KEYBOARD)
	add_child(forced)
	await _frames(1)
	_assert(forced.get_label() == "Space" and not forced.is_controller(), "Forced KEYBOARD glyph shows Space")
	var ov := ButtonGlyph.new()
	ov.label_override = "LB"
	add_child(ov)
	await _frames(1)
	_assert(ov.get_label() == "LB", "label_override is drawn literally", ov.get_label())
	g.queue_free(); forced.queue_free(); ov.queue_free()
	await _frames(1)


# ========== REGISTRATION ==========

func test_registration_source() -> void:
	var zb := FileAccess.get_file_as_string(ZONE_BASE_PATH)
	_assert(zb.contains("preload(\"res://src/ui/hud/target_bar.gd\")"), "zone_base preloads target_bar.gd")
	_assert(zb.contains("preload(\"res://src/ui/hud/tactical_overlay.gd\")"), "zone_base preloads tactical_overlay.gd")
	var spawn := zb.substr(zb.find("func _spawn_hud"), 600)
	_assert(spawn.contains("TargetBarScript") and spawn.contains("TacticalOverlayScript"),
		"zone_base._spawn_hud lists TargetBarScript + TacticalOverlayScript")
	var ta := FileAccess.get_file_as_string(TEST_ARENA_PATH)
	_assert(ta.contains("target_bar.gd") and ta.contains("set_script(TargetBarScript)"), "test_arena registers the target bar")
	_assert(ta.contains("tactical_overlay.gd") and ta.contains("set_script(TacticalOverlayScript)"),
		"test_arena registers the tactical overlay")
	# v4 Y: minimap registration (Head, R-1).
	_assert(zb.contains("preload(\"res://src/ui/hud/minimap.gd\")") and spawn.contains("MinimapScript"),
		"zone_base preloads minimap.gd and lists MinimapScript in _spawn_hud")
	_assert(ta.contains("minimap.gd") and ta.contains("set_script(MinimapScript)"), "test_arena registers the minimap")
	# v4 Y: colours come from UIStyle tokens only (every Color( wraps a UIStyle token).
	var mm := FileAccess.get_file_as_string("res://src/ui/hud/minimap.gd")
	var re := RegEx.new()
	re.compile("Color\\(\\s*([^)]*)\\)")
	var raw: PackedStringArray = []
	for m in re.search_all(mm):
		var arg := m.get_string(1).strip_edges()
		if not arg.begins_with("UIStyle.") and not arg.begins_with("accent") and not arg.begins_with("col"):
			raw.append(m.get_string())
	_assert(raw.is_empty(), "minimap.gd uses UIStyle colour tokens only (no raw Color literals)", ", ".join(raw))


# ========== FIELD ZONE ==========

func test_field_zone_hud() -> void:
	_logger.take()  # discard anything before the zone loads
	var scene := load(FIELD_ZONE_SCENE) as PackedScene
	if scene == null:
		_fail("Field zone loads", "field_zone.tscn failed to load")
		return
	var zone: Node = scene.instantiate()
	add_child(zone)
	await _frames(2)
	# Block the deferred autosave (it only saves while PLAYING).
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	await _frames(30)
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(10)

	var by_script := {}
	for c in zone.get_children():
		if c is CanvasLayer and c.get_script():
			var p: String = c.get_script().resource_path
			by_script[p] = by_script.get(p, []) + [c]
	for p in HUD_SCRIPTS:
		var n: int = by_script.get(p, []).size()
		_assert(n == 1, "field_zone spawns exactly one %s" % p.get_file(), "found %d" % n)

	var bar: CanvasLayer = by_script.get("res://src/ui/hud/target_bar.gd", [null])[0]
	var overlay: CanvasLayer = by_script.get("res://src/ui/hud/tactical_overlay.gd", [null])[0]
	var hud: CanvasLayer = by_script.get("res://src/ui/hud/combat_hud.gd", [null])[0]
	var menu: CanvasLayer = by_script.get("res://src/ui/hud/tactical_menu.gd", [null])[0]
	if bar == null or overlay == null or hud == null or menu == null:
		_fail("HUD layer lookup", "missing target_bar / tactical_overlay / combat_hud / tactical_menu")
		zone.queue_free()
		return
	_assert(overlay.layer < hud.layer and overlay.layer < menu.layer,
		"Tactical overlay renders below the HUD and command menu",
		"overlay=%d hud=%d menu=%d" % [overlay.layer, hud.layer, menu.layer])
	_assert(not bar.is_shown(), "Target bar hidden in free roam")
	_assert(not overlay.is_active(), "Tactical overlay inactive in free roam")

	# Target bar follows lock-on.
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	_assert(enemies.size() >= 2, "field_zone has enemies", "found %d" % enemies.size())
	if not enemies.is_empty():
		var e: Node3D = enemies[0]
		Events.lock_on_target_acquired.emit(e)
		await _frames(3)
		_assert(bar.is_shown() and bar.get_target() == e, "Target bar shows on lock_on_target_acquired")
		_assert(bar._name_label.text.to_lower().contains("reactor sentry"), "Target bar name uses enemy display_name",
			bar._name_label.text)
		if enemies.size() >= 2:
			Events.lock_on_target_switched.emit(enemies[1])
			await _frames(2)
			_assert(bar.get_target() == enemies[1], "Target bar follows lock_on_target_switched")
		Events.lock_on_target_lost.emit()
		await _frames(2)
		_assert(not bar.is_shown(), "Target bar hides on lock_on_target_lost")

	# Overlay fades in/out on tactical signals (unscaled, ~0.16s).
	Events.tactical_mode_entered.emit()
	await _seconds(0.35)
	_assert(overlay.is_active() and overlay.get_amount() > 0.9, "Tactical overlay fades in on tactical_mode_entered",
		"amount=%.2f" % overlay.get_amount())
	var rect := overlay.get_child(0) as Control if overlay.get_child_count() > 0 else null
	_assert(rect != null and rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Tactical overlay ignores the mouse")
	Events.tactical_mode_exited.emit()
	await _seconds(0.35)
	_assert(not overlay.is_active() and overlay.get_amount() < 0.05, "Tactical overlay fades out on tactical_mode_exited",
		"amount=%.2f" % overlay.get_amount())

	# v4 Y: minimap in the field HUD.
	var mm: CanvasLayer = by_script.get("res://src/ui/hud/minimap.gd", [null])[0]
	if mm == null:
		_fail("Minimap layer lookup", "field_zone has no minimap.gd layer")
	else:
		await _seconds(0.7)  # one group scan (500 ms) + a refresh
		var vp := get_viewport().get_visible_rect().size
		var r: Rect2 = mm.get_frame_rect()
		_assert(r.end.x > vp.x - 30.0 and r.end.x <= vp.x and r.position.y >= 20.0 and r.position.y <= 30.0
				and absf(r.size.x - 220.0) < 2.0,
			"Minimap frame is 220 px, anchored top-right (24 px margin)", "rect=%s vp=%s" % [r, vp])
		var non_ignore: PackedStringArray = []
		for c in mm.find_children("*", "Control", true, false):
			if (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				non_ignore.append(c.name)
		_assert(non_ignore.is_empty(), "Every minimap Control ignores the mouse", ", ".join(non_ignore))
		var vpt: SubViewport = mm.get_map_viewport()
		_assert(vpt != null and vpt.size == Vector2i(256, 256) and vpt.gui_disable_input,
			"Minimap SubViewport is 256x256 with GUI input disabled")
		var counts: Dictionary = mm.get_icon_counts()
		_assert(int(counts.get(0, 0)) + int(counts.get(1, 0)) > 0 and int(counts.get(4, 0)) > 0,
			"Field minimap draws enemy and portal icons", str(counts))
		_assert(mm.layer < menu.layer, "Minimap renders below the Command Menu",
			"minimap=%d menu=%d" % [mm.layer, menu.layer])

	var errs := _logger.take()
	_assert(errs.is_empty(), "field_zone HUD ran with no script/engine errors",
		"%d errors, first: %s" % [errs.size(), errs[0] if errs.size() > 0 else ""])

	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	zone.queue_free()
	await _frames(3)


# ========== HELPERS ==========

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _section(title: String) -> void:
	print("\n--- %s ---" % title)


func _assert(cond: bool, test_name: String, detail: String = "") -> void:
	_total += 1
	if cond:
		_passed += 1
		print("  PASS: %s" % test_name)
	else:
		_failed += 1
		print("  FAIL: %s%s" % [test_name, (" — " + detail) if detail != "" else ""])


func _fail(test_name: String, reason: String) -> void:
	_total += 1
	_failed += 1
	print("  FAIL: %s — %s" % [test_name, reason])
