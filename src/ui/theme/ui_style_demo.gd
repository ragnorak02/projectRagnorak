## UI style demo — shows every Lumina Frost widget (used by Package P for screenshots).
## Up/Down (D-pad/stick/arrows) moves between the menu rows. The gauges cycle damage and heal.
extends Control

var _hp: Gauge
var _mp: Gauge
var _stagger: Gauge
var _atb: SegmentGauge
var _rows: Array = []
var _desc: Label
var _tick: float = 0.0
var _step: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#05090E")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 40)
	margin.add_child(cols)

	# --- Column 1: header, panels, gauges ---
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size.x = 560
	c1.add_theme_constant_override(&"separation", 18)
	cols.add_child(c1)
	c1.add_child(UIStyle.make_label("LUMINA FROST — UI KIT", UIStyle.SIZE_XL, UIStyle.GOLD, true))
	c1.add_child(UIStyle.make_label("Fonts bundled: %s" % UIStyle.fonts_bundled(), UIStyle.SIZE_S, UIStyle.TEXT_DIM))

	var party := SlantPanel.new()
	party.selected = true
	c1.add_child(party)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override(&"separation", 6)
	party.add_child(pv)
	pv.add_child(HeaderTab.new().setup("Amaro", "Lv 12"))
	pv.add_child(UIStyle.make_label("HP", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true))
	_hp = Gauge.new()
	_hp.custom_minimum_size = Vector2(420, 16)
	_hp.low_threshold = 0.25
	_hp.show_label = true
	pv.add_child(_hp)
	_hp.set_values(1000, 1000, true)
	pv.add_child(UIStyle.make_label("MP", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true))
	_mp = Gauge.new()
	_mp.custom_minimum_size = Vector2(420, 10)
	_mp.fill_color = UIStyle.MP
	_mp.fill_color_end = UIStyle.MP.lightened(0.2)
	_mp.show_label = true
	_mp.label_size = 12
	pv.add_child(_mp)
	_mp.set_values(60, 80, true)
	pv.add_child(UIStyle.make_label("ATB", UIStyle.SIZE_S, UIStyle.GOLD, true))
	_atb = SegmentGauge.new()
	_atb.custom_minimum_size = Vector2(420, 10)
	pv.add_child(_atb)

	var target := SlantPanel.new()
	target.slant_right = true
	c1.add_child(target)
	var tv := VBoxContainer.new()
	target.add_child(tv)
	tv.add_child(UIStyle.make_label("Reactor Sentry", UIStyle.SIZE_M, UIStyle.TEXT, true))
	var ehp := Gauge.new()
	ehp.custom_minimum_size = Vector2(420, 12)
	ehp.fill_color = UIStyle.DANGER.darkened(0.2)
	ehp.fill_color_end = UIStyle.DANGER
	tv.add_child(ehp)
	ehp.set_values(640, 1000, true)
	_stagger = Gauge.new()
	_stagger.custom_minimum_size = Vector2(420, 6)
	_stagger.fill_color = UIStyle.STAGGER
	_stagger.fill_color_end = UIStyle.STAGGER.lightened(0.25)
	tv.add_child(_stagger)
	_stagger.set_values(0, 100, true)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override(&"panel", UIStyle.pill(UIStyle.STAGGER.darkened(0.3), UIStyle.STAGGER))
	tag.add_child(UIStyle.make_label("STAGGERED  160%", UIStyle.SIZE_S, UIStyle.TEXT, true))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv.add_child(tag)

	var glass := PanelContainer.new()
	glass.add_theme_stylebox_override(&"panel", UIStyle.glass_panel())
	glass.add_child(UIStyle.make_label("glass_panel()  —  Quest: Reach the reactor gate", UIStyle.SIZE_S))
	c1.add_child(glass)
	var glass_sel := PanelContainer.new()
	glass_sel.add_theme_stylebox_override(&"panel", UIStyle.glass_panel_selected())
	glass_sel.add_child(UIStyle.make_label("glass_panel_selected()", UIStyle.SIZE_S))
	c1.add_child(glass_sel)

	# --- Column 2: command menu ---
	var c2 := VBoxContainer.new()
	c2.custom_minimum_size.x = 460
	c2.add_theme_constant_override(&"separation", 0)
	cols.add_child(c2)
	var cmd_tab := HeaderTab.new().setup("Command", "Amaro")
	cmd_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c2.add_child(cmd_tab)
	var cmd := SlantPanel.new()
	c2.add_child(cmd)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override(&"separation", 4)
	cmd.add_child(cv)
	var data := [
		["Slash Combo", 1, -1, false, "", "A swift three-hit sword chain."],
		["Fire", 1, 8, false, "", "Hurl a fireball. Strong vs. machines."],
		["Blizzard", 1, 12, true, "Not enough MP", "Ice burst. Builds stagger."],
		["Lumina Break", 2, -1, true, "Needs 2 ATB", "Heavy finisher, huge stagger bonus."],
		["Potion", 1, -1, false, "", "Restore 300 HP."],
	]
	for d in data:
		var row := MenuRow.new().setup(d[0], d[1], d[2], d[3], d[4])
		row.description = d[5]
		if d[0] == "Potion":
			row.right_text = "x3"
		row.focus_entered.connect(_on_row_focus.bind(row))
		cv.add_child(row)
		_rows.append(row)
	var desc_panel := PanelContainer.new()
	desc_panel.add_theme_stylebox_override(&"panel", UIStyle.glass_panel(10))
	_desc = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT)
	desc_panel.add_child(_desc)
	c2.add_child(Control.new())
	c2.add_child(desc_panel)

	# --- Column 3: glyphs ---
	var c3 := VBoxContainer.new()
	c3.add_theme_constant_override(&"separation", 10)
	cols.add_child(c3)
	c3.add_child(UIStyle.make_label("GLYPHS", UIStyle.SIZE_L, UIStyle.GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 8)
	c3.add_child(grid)
	for a in [&"ui_accept", &"ui_cancel", &"attack", &"jump", &"interact", &"dodge", &"tactical_mode", &"lock_on", &"pause", &"target_switch_left", &"ui_up", &"camera_reset"]:
		grid.add_child(UIStyle.make_label(String(a), UIStyle.SIZE_S, UIStyle.TEXT_DIM))
		var gp := ButtonGlyph.new().setup(a, ButtonGlyph.Device.CONTROLLER)
		grid.add_child(gp)
		var gk := ButtonGlyph.new().setup(a, ButtonGlyph.Device.KEYBOARD)
		grid.add_child(gk)
	c3.add_child(UIStyle.make_label("HINTS (active device)", UIStyle.SIZE_M, UIStyle.GOLD, true))
	c3.add_child(GlyphHint.create(&"ui_accept", "Confirm"))
	c3.add_child(GlyphHint.create(&"ui_cancel", "Back"))
	c3.add_child(GlyphHint.create(&"interact", "Talk to Villager", UIStyle.SIZE_M))
	var demo_btn := Button.new()
	demo_btn.text = "style_button(Button)"
	UIStyle.style_button(demo_btn)
	c3.add_child(demo_btn)

	if not _rows.is_empty():
		_rows[0].grab_focus()
		_on_row_focus(_rows[0])
	UIStyle.fade_slide_in(cmd, Vector2.LEFT)


func _on_row_focus(row: MenuRow) -> void:
	if _desc == null:
		return
	_desc.text = row.unavailable_reason if row.unavailable and row.unavailable_reason != "" else row.description
	_desc.add_theme_color_override(&"font_color", UIStyle.DANGER if row.unavailable else UIStyle.TEXT)


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.2:
		return
	_tick = 0.0
	_step += 1
	match _step % 4:
		0:
			_hp.value = 1000
			_atb.value = 0
		1:
			_hp.value = 620
			_atb.value = 50
			_stagger.value = 45
		2:
			_hp.value = 180
			_atb.value = 100
			_stagger.value = 100
		3:
			_hp.value = 700
			_mp.value = 40
			_stagger.value = 0
