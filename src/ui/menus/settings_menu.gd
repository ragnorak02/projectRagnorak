## Settings menu overlay with Camera, Audio, Controls, and Gameplay sections.
## Builds UI programmatically. Opens from pause menu or main menu.
## Visuals: "Lumina Frost" menu shell — header tab, glass content panel with
## slanted rows, Gauge sliders, ON/OFF pills, ButtonGlyph keybinds and a footer
## glyph bar. Input handling and rebind capture are unchanged.
## v5 (AA): stick navigation through MenuNav (one push = one step, hold =
## steady repeat), and an Options sub-page (GAMEPLAY -> "Options ›") with
## Minimap On/Off, Minimap Mode Rotating/North-Up, Control Hints, Damage Numbers.
## B / Esc on the sub-page returns one layer to the main page.
extends CanvasLayer

# --- Colors ---
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const PANEL_BG := Color(0.05, 0.08, 0.15, 0.95)
const PANEL_BORDER := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const SECTION_COLOR := Color(0.9, 0.7, 0.1)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const VALUE_COLOR := Color(0.6, 0.8, 1.0)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const DIMMED_COLOR := Color(0.4, 0.4, 0.5)
const BAR_BG := Color(0.15, 0.15, 0.2)
const BAR_FILL := Color(0.3, 0.6, 1.0)
const REBIND_COLOR := Color(1.0, 0.8, 0.2)

# --- Row types ---
enum RowType { SECTION, SLIDER, TOGGLE, KEYBIND, SUBPAGE }

# --- Pages ---
enum Page { MAIN, OPTIONS }

# --- Row definitions (built in _init_row_defs) ---
var _row_defs: Array[Dictionary] = []
var _selectable_map: Array[int] = []  # selectable index -> row def index
var _selected: int = 0
var _is_open: bool = false
var _rebinding: bool = false
var _rebind_def_index: int = -1
var _page: int = Page.MAIN
var _main_selected: int = 0        # main-page cursor, restored when the sub-page closes
## Stick/D-pad/key navigation (v5 AA): one push = one step, hold = steady repeat.
var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"],
	[&"move_left", &"ui_left"], [&"move_right", &"ui_right"])

# --- UI references ---
var _root: Control
var _overlay: ColorRect
var _scroll: ScrollContainer
var _panel: PanelContainer
var _vbox: VBoxContainer
var _row_panels: Array[PanelContainer] = []   # parallel to _row_defs (null for sections)
var _value_nodes: Array[Control] = []          # parallel to _row_defs (null for sections)
var _hint_label: Label
var _hint_box: HBoxContainer                   # footer glyph hints (rebuilt per row type)
var _hint_device_controller: bool = false
var _hint_key: String = ""
var _title: Control                  # the HeaderTab (Control-typed member)
var _meta_holders: Array = []                  # slider meta nodes (freed on page rebuild)

# --- Bar geometry ---
const BAR_WIDTH: float = 240.0
const BAR_HEIGHT: float = 12.0

# --- Shell geometry ---
const SHELL_WIDTH := 1080.0
const ROW_WIDTH := 1000.0
const VALUE_WIDTH := 400.0
const GLYPH_CELL := 150.0

signal closed()


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_row_defs()
	_build_ui()
	_hide_menu()


func _init_row_defs() -> void:
	if _page == Page.OPTIONS:
		_row_defs = _options_row_defs()
	else:
		_row_defs = _main_row_defs()
	_selectable_map.clear()
	for i in _row_defs.size():
		if _row_defs[i]["type"] != RowType.SECTION:
			_selectable_map.append(i)


func _main_row_defs() -> Array[Dictionary]:
	return [
		# Camera
		{"type": RowType.SECTION, "label": "CAMERA"},
		{"type": RowType.SLIDER, "label": "Mouse Sensitivity", "key": "mouse_sensitivity",
		 "min": 0.0005, "max": 0.004, "step": 0.0005, "format": "mouse_sens"},
		{"type": RowType.SLIDER, "label": "Controller Camera", "key": "controller_sensitivity",
		 "min": 0.5, "max": 2.0, "step": 0.1, "format": "multiplier"},
		{"type": RowType.TOGGLE, "label": "Camera Shake", "key": "camera_shake"},
		# Audio
		{"type": RowType.SECTION, "label": "AUDIO"},
		{"type": RowType.SLIDER, "label": "Music Volume", "key": "music_volume",
		 "min": 0.0, "max": 1.0, "step": 0.1, "format": "percent"},
		{"type": RowType.SLIDER, "label": "SFX Volume", "key": "sfx_volume",
		 "min": 0.0, "max": 1.0, "step": 0.1, "format": "percent"},
		# Controls
		{"type": RowType.SECTION, "label": "CONTROLS"},
		{"type": RowType.KEYBIND, "label": "Jump", "action": "jump"},
		{"type": RowType.KEYBIND, "label": "Attack", "action": "attack"},
		{"type": RowType.KEYBIND, "label": "Dodge", "action": "dodge"},
		{"type": RowType.KEYBIND, "label": "Interact", "action": "interact"},
		{"type": RowType.KEYBIND, "label": "Run", "action": "sprint"},
		{"type": RowType.KEYBIND, "label": "Command Menu", "action": "tactical_mode"},
		{"type": RowType.KEYBIND, "label": "Lock-On", "action": "lock_on"},
		{"type": RowType.KEYBIND, "label": "Battle Mode", "action": "battle_toggle"},
		{"type": RowType.KEYBIND, "label": "Pause", "action": "pause"},
		{"type": RowType.KEYBIND, "label": "Party Switch", "action": "party_switch"},
		# Gameplay
		{"type": RowType.SECTION, "label": "GAMEPLAY"},
		{"type": RowType.SUBPAGE, "label": "Options ›", "page": Page.OPTIONS,
		 "detail": "Minimap · Control Hints · Damage Numbers"},
	]


## Options sub-page (v5 AA3). "on"/"off" are the pill texts for true/false.
func _options_row_defs() -> Array[Dictionary]:
	return [
		{"type": RowType.SECTION, "label": "MINIMAP"},
		{"type": RowType.TOGGLE, "label": "Minimap", "key": "show_minimap"},
		{"type": RowType.TOGGLE, "label": "Minimap Mode", "key": "minimap_rotate",
		 "on": "ROTATING", "off": "NORTH-UP"},
		{"type": RowType.SECTION, "label": "HUD"},
		{"type": RowType.TOGGLE, "label": "Control Hints", "key": "show_control_hints",
		 "on": "SHOW", "off": "HIDE"},
		{"type": RowType.TOGGLE, "label": "Damage Numbers", "key": "show_damage_numbers"},
	]


# ──────────────────────────────────────────────
# BUILD UI
# ──────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(UIStyle.DIM_SCREEN, 0.94)   # full screen: hide the menu beneath
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	# Centered shell (transparent container: header tab + content + footer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(SHELL_WIDTH, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outer_vbox)

	# Title tab
	var title := HeaderTab.new().setup("Settings", "Camera · Audio · Controls · Gameplay")
	title.title_size = UIStyle.SIZE_L
	_title = title
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	outer_vbox.add_child(_title)

	# Glass content panel with the scrollable rows
	var content := SlantPanel.new()
	content.padding = 20
	outer_vbox.add_child(content)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(ROW_WIDTH + 24, 640)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

	_build_rows()

	# Footer glyph bar
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UIStyle.glass_panel(10))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(footer)

	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override("separation", 24)
	fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(fbox)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbox.add_child(left)

	# Context line (also shows the rebind prompt)
	_hint_label = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT)
	left.add_child(_hint_label)
	var note := UIStyle.make_label("Changes save when you close this menu.", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	note.add_theme_font_size_override("font_size", 12)
	left.add_child(note)

	_hint_box = HBoxContainer.new()
	_hint_box.add_theme_constant_override("separation", 24)
	_hint_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbox.add_child(_hint_box)


## (Re)builds the rows of the current page into _vbox.
func _build_rows() -> void:
	for c in _vbox.get_children():
		_vbox.remove_child(c)
		c.queue_free()
	for m in _meta_holders:
		if is_instance_valid(m):
			m.queue_free()
	_meta_holders.clear()
	_row_panels.clear()
	_value_nodes.clear()
	for i in _row_defs.size():
		var def: Dictionary = _row_defs[i]
		var row_type: int = def["type"]
		match row_type:
			RowType.SECTION:
				_build_section_row(def)
			RowType.SLIDER:
				_build_slider_row(def)
			RowType.TOGGLE:
				_build_toggle_row(def)
			RowType.KEYBIND:
				_build_keybind_row(def)
			RowType.SUBPAGE:
				_build_subpage_row(def)


## Switch page (MAIN <-> OPTIONS), rebuild rows, keep the cursor sensible.
func _set_page(page: int) -> void:
	if page == Page.OPTIONS and _page == Page.MAIN:
		_main_selected = _selected
	_page = page
	_init_row_defs()
	_build_rows()
	if _title:
		var opt := _page == Page.OPTIONS
		_title.set(&"title", "Options" if opt else "Settings")
		_title.set(&"subtitle", "Settings › Minimap · HUD" if opt else "Camera · Audio · Controls · Gameplay")
	_selected = 0 if _page == Page.OPTIONS else clampi(_main_selected, 0, _selectable_map.size() - 1)
	_nav.reset()
	_hint_key = ""
	_refresh_all_values()
	_update_selection()
	_update_hint_text()
	if _scroll:
		_scroll.scroll_vertical = 0
		_ensure_selected_visible.call_deferred()


## The page currently shown (Page.MAIN / Page.OPTIONS).
func get_page() -> int:
	return _page


func is_open() -> bool:
	return _is_open


func _build_section_row(def: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(ROW_WIDTH, 52)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(top)

	var label := UIStyle.make_label(def["label"], UIStyle.SIZE_M, SECTION_COLOR, true)
	label.add_theme_color_override("font_color", UIStyle.GOLD)
	label.add_theme_font_size_override("font_size", 24)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(label)

	# Column captions above the keybind glyphs
	if def["label"] == "CONTROLS":
		for cap_text in ["KEYBOARD", "CONTROLLER"]:
			var cap := UIStyle.make_label(cap_text, UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
			cap.add_theme_font_size_override("font_size", 14)
			cap.custom_minimum_size.x = GLYPH_CELL
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.size_flags_vertical = Control.SIZE_SHRINK_END
			top.add_child(cap)
		var pad := Control.new()
		pad.custom_minimum_size.x = 22
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(pad)

	var line := ColorRect.new()
	line.color = UIStyle.GOLD_DIM
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	_vbox.add_child(box)
	_row_panels.append(null)
	_value_nodes.append(null)


func _build_slider_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var name_label := _make_name_label(def["label"])
	hbox.add_child(name_label)

	# Slider visual: < [gauge] > value
	var slider_box := HBoxContainer.new()
	slider_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_theme_constant_override("separation", 12)
	slider_box.custom_minimum_size.x = VALUE_WIDTH
	slider_box.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(slider_box)

	var arrow_l := UIStyle.make_label("<", UIStyle.SIZE_M, DIMMED_COLOR, true)
	arrow_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_box.add_child(arrow_l)

	var bar_fill := Gauge.new()
	bar_fill.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_fill.fill_color = UIStyle.CYAN.darkened(0.25)
	bar_fill.fill_color_end = UIStyle.CYAN
	bar_fill.chip_color = Color(UIStyle.CYAN, 0.0)
	slider_box.add_child(bar_fill)

	var arrow_r := UIStyle.make_label(">", UIStyle.SIZE_M, DIMMED_COLOR, true)
	arrow_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_box.add_child(arrow_r)

	var val_label := UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.TEXT, true)
	val_label.custom_minimum_size.x = 70
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider_box.add_child(val_label)

	_row_panels.append(panel)
	panel.set_meta("arrows", [arrow_l, arrow_r])
	# Store bar_fill and val_label for updates via metadata on a dummy Control
	var meta_holder := Control.new()
	meta_holder.visible = false
	meta_holder.set_meta("bar_fill", bar_fill)
	meta_holder.set_meta("val_label", val_label)
	add_child(meta_holder)
	_meta_holders.append(meta_holder)
	_value_nodes.append(meta_holder)


func _build_toggle_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	hbox.add_child(_make_name_label(def["label"]))

	var val_label := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT, true)
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.custom_minimum_size.x = 84
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(val_label)

	_row_panels.append(panel)
	_value_nodes.append(val_label)


## "Options ›" row: opens a sub-page on confirm (or right).
func _build_subpage_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	hbox.add_child(_make_name_label(def["label"]))
	var detail := UIStyle.make_label(def.get("detail", ""), UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(detail)
	var arrow := UIStyle.make_label("›", UIStyle.SIZE_M, DIMMED_COLOR, true)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(arrow)
	panel.set_meta("arrows", [arrow])

	_row_panels.append(panel)
	_value_nodes.append(null)


func _build_keybind_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	panel.add_child(hbox)

	hbox.add_child(_make_name_label(def["label"]))

	# Current bindings as glyphs: keyboard cell + controller cell
	var glyph_box := HBoxContainer.new()
	glyph_box.add_theme_constant_override("separation", 0)
	glyph_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(glyph_box)
	var glyphs: Array = []
	for dev in [ButtonGlyph.Device.KEYBOARD, ButtonGlyph.Device.CONTROLLER]:
		var cell := CenterContainer.new()
		cell.custom_minimum_size = Vector2(GLYPH_CELL, 34)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph_box.add_child(cell)
		var g := ButtonGlyph.new()
		g.glyph_height = 30
		g.setup(StringName(def["action"]), dev)
		cell.add_child(g)
		glyphs.append(g)

	# Text label: kept for the rebind prompt ("Press key/button...")
	var binding_label := UIStyle.make_label("", UIStyle.SIZE_M, VALUE_COLOR, true)
	binding_label.custom_minimum_size.x = GLYPH_CELL * 2
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binding_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	binding_label.visible = false
	hbox.add_child(binding_label)
	binding_label.set_meta("glyph_box", glyph_box)
	binding_label.set_meta("glyphs", glyphs)

	_row_panels.append(panel)
	_value_nodes.append(binding_label)


func _make_name_label(text: String) -> Label:
	var name_label := UIStyle.make_label(text, UIStyle.SIZE_M, UIStyle.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return name_label


func _create_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_WIDTH, 48)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _row_style(false))
	return panel


func _row_style(selected: bool) -> StyleBoxFlat:
	var style := UIStyle.slant_row("selected" if selected else "normal", 8.0)
	style.skew = Vector2(0.12, 0.0)
	if not selected:
		style.bg_color = Color(UIStyle.GLASS.r, UIStyle.GLASS.g, UIStyle.GLASS.b, 0.35)
	return style


# ──────────────────────────────────────────────
# MENU API
# ──────────────────────────────────────────────

func open_menu() -> void:
	_is_open = true
	_rebinding = false
	_selected = 0
	_main_selected = 0
	if _page != Page.MAIN:
		_set_page(Page.MAIN)
	_nav.reset()
	_refresh_all_values()
	_update_selection()
	_update_hint_text()
	_show_menu()
	AudioManager.play_sfx_named("menu_open")


func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_rebinding = false
	SettingsManager.apply_settings()
	SettingsManager.save_settings()
	_hide_menu()
	AudioManager.play_sfx_named("menu_close")
	closed.emit()


# ──────────────────────────────────────────────
# INPUT
# ──────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Rebinding mode captures raw input
	if _rebinding:
		_handle_rebind_input(event)
		get_viewport().set_input_as_handled()
		return

	# Back: B / Esc returns one layer (Options -> main page -> close). Start
	# closes Settings outright (matching quest log and save/load, so it can't
	# close the pause menu underneath and strand Settings open).
	if event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()
		return

	# Raw stick motion -> MenuNav (stepped in _process).
	if _nav.consume_event(event):
		get_viewport().set_input_as_handled()
		return

	# D-pad / keys: up/down navigate, left/right adjust (one press = one step).
	var step := _nav.event_step(event)
	if step != Vector2i.ZERO:
		_apply_nav_step(step)
		get_viewport().set_input_as_handled()
		return

	# Confirm (toggle or start rebind)
	if event.is_action_pressed(&"ui_accept"):
		_confirm_action()
		get_viewport().set_input_as_handled()
		return

	# Reset defaults: joypad Y via built-in ui_select (non-gameplay action).
	# ui_select also contains Space, but Space is consumed above as ui_accept,
	# so only the joypad event is honoured here. Keyboard fallback: E key
	# (key events only; on controller `interact` is B, which is ui_cancel here).
	var is_pad_select := event is InputEventJoypadButton and event.is_action_pressed(&"ui_select")
	var is_kb_reset := event is InputEventKey and event.is_action_pressed(&"interact")
	if is_pad_select or is_kb_reset:
		_reset_defaults()
		get_viewport().set_input_as_handled()
		return


## B / Esc: one layer back (sub-page -> main page, main page -> close).
func go_back() -> void:
	if _page != Page.MAIN:
		_set_page(Page.MAIN)
		AudioManager.play_sfx_named("menu_close")
	else:
		close_menu()


func _apply_nav_step(step: Vector2i) -> void:
	if step.y != 0:
		_move_selection(step.y)
	elif step.x != 0:
		_adjust_value(step.x)


func _handle_rebind_input(event: InputEvent) -> void:
	var valid := false
	if event is InputEventKey and event.pressed:
		valid = true
	elif event is InputEventMouseButton and event.pressed:
		valid = true
	elif event is InputEventJoypadButton and event.pressed:
		valid = true
	if not valid:
		return

	# Escape cancels rebind
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return

	var def: Dictionary = _row_defs[_rebind_def_index]
	var action: StringName = StringName(def["action"])
	SettingsManager.rebind_action(action, event)
	_rebinding = false
	_rebind_def_index = -1
	_nav.reset()
	_refresh_row(_selected)
	_update_hint_text()
	AudioManager.play_sfx_named("menu_confirm")


func _cancel_rebind() -> void:
	_rebinding = false
	_nav.reset()
	_rebind_def_index = -1
	_refresh_row(_selected)
	_update_hint_text()


# ──────────────────────────────────────────────
# SELECTION
# ──────────────────────────────────────────────

func _move_selection(direction: int) -> void:
	_selected = wrapi(_selected + direction, 0, _selectable_map.size())
	_update_selection()
	_update_hint_text()
	_ensure_selected_visible()
	AudioManager.play_sfx_named("menu_select")


func _update_selection() -> void:
	for i in _selectable_map.size():
		var def_idx: int = _selectable_map[i]
		var panel: PanelContainer = _row_panels[def_idx]
		if panel == null:
			continue
		var is_sel := i == _selected
		panel.add_theme_stylebox_override("panel", _row_style(is_sel))
		if panel.has_meta("arrows"):
			for arrow: Label in panel.get_meta("arrows"):
				arrow.add_theme_color_override("font_color", UIStyle.CYAN if is_sel else DIMMED_COLOR)


func _ensure_selected_visible() -> void:
	if _selected < 0 or _selected >= _selectable_map.size():
		return
	var def_idx: int = _selectable_map[_selected]
	var panel: PanelContainer = _row_panels[def_idx]
	if panel:
		_scroll.ensure_control_visible(panel)


# ──────────────────────────────────────────────
# VALUE ADJUSTMENT
# ──────────────────────────────────────────────

func _adjust_value(direction: int) -> void:
	if _selected < 0 or _selected >= _selectable_map.size():
		return
	var def_idx: int = _selectable_map[_selected]
	var def: Dictionary = _row_defs[def_idx]
	var row_type: int = def["type"]

	if row_type == RowType.SLIDER:
		var key: String = def["key"]
		var current: float = SettingsManager.get(key)
		var step: float = def["step"]
		var new_val: float = clampf(current + step * direction, def["min"], def["max"])
		SettingsManager.set(key, new_val)
		SettingsManager.apply_settings()
		_refresh_row(_selected)
		AudioManager.play_sfx_named("menu_select")
	elif row_type == RowType.TOGGLE:
		_toggle_value(def)
	elif row_type == RowType.SUBPAGE and direction > 0:
		_set_page(def["page"])
		AudioManager.play_sfx_named("menu_confirm")


func _confirm_action() -> void:
	if _selected < 0 or _selected >= _selectable_map.size():
		return
	var def_idx: int = _selectable_map[_selected]
	var def: Dictionary = _row_defs[def_idx]
	var row_type: int = def["type"]

	match row_type:
		RowType.TOGGLE:
			_toggle_value(def)
			AudioManager.play_sfx_named("menu_confirm")
		RowType.KEYBIND:
			_start_rebind(def_idx)
		RowType.SUBPAGE:
			_set_page(def["page"])
			AudioManager.play_sfx_named("menu_confirm")
		RowType.SLIDER:
			pass  # Left/Right adjusts sliders


func _toggle_value(def: Dictionary) -> void:
	var key: String = def["key"]
	var current: bool = SettingsManager.get(key)
	SettingsManager.set(key, not current)
	SettingsManager.apply_settings()
	_refresh_row(_selected)


func _start_rebind(def_index: int) -> void:
	_rebinding = true
	_rebind_def_index = def_index
	var value_node: Control = _value_nodes[def_index]
	if value_node is Label:
		var lbl := value_node as Label
		lbl.text = "Press key/button..."
		lbl.add_theme_color_override("font_color", REBIND_COLOR)
		# Visual: swap the glyph cells for the prompt text while capturing
		lbl.visible = true
		if lbl.has_meta("glyph_box"):
			(lbl.get_meta("glyph_box") as Control).visible = false
	_hint_label.text = "Press the new key or button for this action"
	_rebuild_hints()
	AudioManager.play_sfx_named("menu_select")


func _reset_defaults() -> void:
	SettingsManager.reset_defaults()
	_refresh_all_values()
	AudioManager.play_sfx_named("menu_confirm")


# ──────────────────────────────────────────────
# VALUE DISPLAY
# ──────────────────────────────────────────────

func _refresh_all_values() -> void:
	for i in _selectable_map.size():
		_refresh_row(i)


func _refresh_row(selectable_index: int) -> void:
	if selectable_index < 0 or selectable_index >= _selectable_map.size():
		return
	var def_idx: int = _selectable_map[selectable_index]
	var def: Dictionary = _row_defs[def_idx]
	var value_node: Control = _value_nodes[def_idx]
	if value_node == null:
		return

	var row_type: int = def["type"]
	match row_type:
		RowType.SLIDER:
			_refresh_slider(def, value_node)
		RowType.TOGGLE:
			_refresh_toggle(def, value_node as Label)
		RowType.KEYBIND:
			_refresh_keybind(def, value_node as Label)


func _refresh_slider(def: Dictionary, container: Control) -> void:
	var key: String = def["key"]
	var current: float = SettingsManager.get(key)
	var min_val: float = def["min"]
	var max_val: float = def["max"]
	var ratio: float = (current - min_val) / (max_val - min_val) if max_val > min_val else 0.0
	ratio = clampf(ratio, 0.0, 1.0)

	var bar_fill: Gauge = container.get_meta("bar_fill")
	var val_label: Label = container.get_meta("val_label")

	bar_fill.set_values(ratio * 100.0, 100.0, true)

	var format_type: String = def.get("format", "")
	match format_type:
		"percent":
			val_label.text = "%d%%" % roundi(current * 100)
		"multiplier":
			val_label.text = "%.1fx" % current
		"mouse_sens":
			val_label.text = "%d" % roundi(current / 0.0005)
		_:
			val_label.text = "%.2f" % current


func _refresh_toggle(def: Dictionary, label: Label) -> void:
	var key: String = def["key"]
	var current: bool = SettingsManager.get(key)
	label.text = def.get("on", "ON") if current else def.get("off", "OFF")
	label.add_theme_color_override("font_color", UIStyle.GLASS_DEEP if current else UIStyle.TEXT_DIM)
	label.add_theme_stylebox_override("normal", UIStyle.pill(
		UIStyle.CYAN if current else Color(UIStyle.GLASS_DEEP, 0.9),
		Color(0, 0, 0, 0) if current else UIStyle.TEXT_DISABLED, 16, 3))


func _refresh_keybind(def: Dictionary, label: Label) -> void:
	var action: String = def["action"]
	var kb: String = SettingsManager.get_action_keyboard_text(StringName(action))
	var ctrl: String = SettingsManager.get_action_controller_text(StringName(action))
	label.text = "%s  /  %s" % [kb, ctrl]
	label.add_theme_color_override("font_color", VALUE_COLOR)
	# Visual: glyph cells show the binding; the text label is only the rebind prompt.
	# rebind_action() does not emit settings_changed, so refresh glyphs explicitly.
	label.visible = false
	if label.has_meta("glyph_box"):
		(label.get_meta("glyph_box") as Control).visible = true
	if label.has_meta("glyphs"):
		for g: ButtonGlyph in label.get_meta("glyphs"):
			g.refresh()


func _update_hint_text() -> void:
	if _rebinding:
		_hint_label.text = "Press the new key or button for this action"
		_rebuild_hints()
		return
	if _selected < 0 or _selected >= _selectable_map.size():
		_hint_label.text = "[B/Esc] Back"
		_rebuild_hints()
		return
	var def_idx: int = _selectable_map[_selected]
	var def: Dictionary = _row_defs[def_idx]
	var row_type: int = def["type"]
	match row_type:
		RowType.SLIDER:
			_hint_label.text = "%s  —  adjust with left / right" % def["label"]
		RowType.TOGGLE:
			_hint_label.text = "%s  —  toggle on or off" % def["label"]
		RowType.KEYBIND:
			_hint_label.text = "%s  —  press confirm, then the new key or button" % def["label"]
		RowType.SUBPAGE:
			_hint_label.text = "%s  —  open with confirm" % def.get("detail", def["label"])
		_:
			_hint_label.text = ""
	_rebuild_hints()


## Footer glyph hints for the current row type and device.
func _rebuild_hints() -> void:
	if _hint_box == null:
		return
	var controller := _is_controller()
	var row_type := -1
	if _selected >= 0 and _selected < _selectable_map.size():
		row_type = _row_defs[_selectable_map[_selected]]["type"]
	var key := "%s|%d|%s" % [_rebinding, row_type, controller]
	if key == _hint_key:
		return
	_hint_key = key
	_hint_device_controller = controller
	for c in _hint_box.get_children():
		c.queue_free()

	if _rebinding:
		var esc := GlyphHint.create(&"ui_cancel", "Cancel rebind", UIStyle.SIZE_S, ButtonGlyph.Device.KEYBOARD)
		esc.get_glyph().label_override = "Esc"
		_hint_box.add_child(esc)
		return

	match row_type:
		RowType.SLIDER:
			var adj := GlyphHint.create(&"ui_left", "Adjust", UIStyle.SIZE_S)
			adj.get_glyph().label_override = "%s/%s" % [_first_label(&"ui_left", controller), _first_label(&"ui_right", controller)]
			_hint_box.add_child(adj)
		RowType.TOGGLE:
			_hint_box.add_child(GlyphHint.create(&"ui_accept", "Toggle", UIStyle.SIZE_S))
		RowType.KEYBIND:
			_hint_box.add_child(GlyphHint.create(&"ui_accept", "Rebind", UIStyle.SIZE_S))
		RowType.SUBPAGE:
			_hint_box.add_child(GlyphHint.create(&"ui_accept", "Open", UIStyle.SIZE_S))
	# Defaults: joypad Y (ui_select) / keyboard E (interact key) — matches _unhandled_input
	var defaults := GlyphHint.create(&"ui_select" if controller else &"interact", "Defaults", UIStyle.SIZE_S,
		ButtonGlyph.Device.CONTROLLER if controller else ButtonGlyph.Device.KEYBOARD)
	if controller:
		defaults.get_glyph().label_override = "Y"
	_hint_box.add_child(defaults)
	_hint_box.add_child(GlyphHint.create(&"ui_cancel", "Back", UIStyle.SIZE_S))


func _first_label(action: StringName, controller: bool) -> String:
	var parts := ButtonGlyph.label_for(action, controller).split("/", false)
	return parts[0] if not parts.is_empty() else "---"


func _is_controller() -> bool:
	var im := get_node_or_null(^"/root/InputManager")
	return im != null and im.is_using_controller()


func _process(_delta: float) -> void:
	if not _is_open:
		return
	# Stick steps / held repeats (unscaled time). Not while capturing a rebind.
	var nav_step := _nav.poll()
	if not _rebinding and nav_step != Vector2i.ZERO:
		_apply_nav_step(nav_step)
	# Rebuild the footer glyphs if the active device changes while open.
	if _is_controller() != _hint_device_controller:
		_rebuild_hints()


# ──────────────────────────────────────────────
# VISIBILITY
# ──────────────────────────────────────────────

var _menu_tween: Tween = null


func _show_menu() -> void:
	_root.visible = true
	_hint_key = ""
	_rebuild_hints()
	if _menu_tween and _menu_tween.is_running():
		_menu_tween.kill()
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_menu_tween = UIStyle.ui_tween(_root)
	if _menu_tween == null:
		_overlay.modulate.a = 1.0
		_panel.modulate.a = 1.0
		return
	_menu_tween.set_parallel(true)
	_menu_tween.tween_property(_overlay, "modulate:a", 1.0, 0.15)
	_menu_tween.tween_property(_panel, "modulate:a", 1.0, 0.16).set_delay(0.04)
	_scroll.scroll_vertical = 0


func _hide_menu() -> void:
	_root.visible = false
