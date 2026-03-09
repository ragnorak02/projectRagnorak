## Settings menu overlay with Camera, Audio, Controls, and Gameplay sections.
## Builds UI programmatically. Opens from pause menu or main menu.
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
enum RowType { SECTION, SLIDER, TOGGLE, KEYBIND }

# --- Row definitions (built in _init_row_defs) ---
var _row_defs: Array[Dictionary] = []
var _selectable_map: Array[int] = []  # selectable index -> row def index
var _selected: int = 0
var _is_open: bool = false
var _rebinding: bool = false
var _rebind_def_index: int = -1

# --- UI references ---
var _root: Control
var _overlay: ColorRect
var _scroll: ScrollContainer
var _panel: PanelContainer
var _vbox: VBoxContainer
var _row_panels: Array[PanelContainer] = []   # parallel to _row_defs (null for sections)
var _value_nodes: Array[Control] = []          # parallel to _row_defs (null for sections)
var _hint_label: Label

# --- Bar geometry ---
const BAR_WIDTH: float = 120.0
const BAR_HEIGHT: float = 14.0

signal closed()


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_row_defs()
	_build_ui()
	_hide_menu()


func _init_row_defs() -> void:
	_row_defs = [
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
		{"type": RowType.KEYBIND, "label": "Tactical Menu", "action": "tactical_mode"},
		{"type": RowType.KEYBIND, "label": "Lock-On", "action": "lock_on"},
		{"type": RowType.KEYBIND, "label": "Pause", "action": "pause"},
		{"type": RowType.KEYBIND, "label": "Party Switch", "action": "party_switch"},
		# Gameplay
		{"type": RowType.SECTION, "label": "GAMEPLAY"},
		{"type": RowType.TOGGLE, "label": "Damage Numbers", "key": "show_damage_numbers"},
		{"type": RowType.TOGGLE, "label": "Control Hints", "key": "show_control_hints"},
	]
	_selectable_map.clear()
	for i in _row_defs.size():
		if _row_defs[i]["type"] != RowType.SECTION:
			_selectable_map.append(i)


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
	_overlay.color = OVERLAY_COLOR
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	# Centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = PANEL_BORDER
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(outer_vbox)

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(sep)

	# Scrollable row container
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(480, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

	# Build each row
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

	# Bottom separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(sep2)

	# Hint bar
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", DIMMED_COLOR)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_vbox.add_child(_hint_label)


func _build_section_row(def: Dictionary) -> void:
	var label := Label.new()
	label.text = "── %s ──" % def["label"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", SECTION_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.y = 28
	_vbox.add_child(label)
	_row_panels.append(null)
	_value_nodes.append(null)


func _build_slider_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = def["label"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Slider visual: ◄ [bar] ► value
	var slider_box := HBoxContainer.new()
	slider_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_theme_constant_override("separation", 6)
	hbox.add_child(slider_box)

	var arrow_l := Label.new()
	arrow_l.text = "◄"
	arrow_l.add_theme_font_size_override("font_size", 12)
	arrow_l.add_theme_color_override("font_color", DIMMED_COLOR)
	arrow_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_child(arrow_l)

	# Bar container (fixed size)
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2.ZERO
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.color = BAR_BG
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(0, BAR_HEIGHT)
	bar_fill.color = BAR_FILL
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_fill)

	var arrow_r := Label.new()
	arrow_r.text = "►"
	arrow_r.add_theme_font_size_override("font_size", 12)
	arrow_r.add_theme_color_override("font_color", DIMMED_COLOR)
	arrow_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_child(arrow_r)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = 50
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 14)
	val_label.add_theme_color_override("font_color", VALUE_COLOR)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_box.add_child(val_label)

	_row_panels.append(panel)
	# Store bar_fill and val_label for updates via metadata on a dummy Control
	var meta_holder := Control.new()
	meta_holder.visible = false
	meta_holder.set_meta("bar_fill", bar_fill)
	meta_holder.set_meta("val_label", val_label)
	add_child(meta_holder)
	_value_nodes.append(meta_holder)


func _build_toggle_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = def["label"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = 60
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(val_label)

	_row_panels.append(panel)
	_value_nodes.append(val_label)


func _build_keybind_row(def: Dictionary) -> void:
	var panel := _create_row_panel()
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	var name_label := Label.new()
	name_label.text = def["label"]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var binding_label := Label.new()
	binding_label.custom_minimum_size.x = 160
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	binding_label.add_theme_font_size_override("font_size", 14)
	binding_label.add_theme_color_override("font_color", VALUE_COLOR)
	binding_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(binding_label)

	_row_panels.append(panel)
	_value_nodes.append(binding_label)


func _create_row_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 32)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	return panel


# ──────────────────────────────────────────────
# MENU API
# ──────────────────────────────────────────────

func open_menu() -> void:
	_is_open = true
	_rebinding = false
	_selected = 0
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

	# Cancel / back
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
		return

	# Navigate up/down
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return

	# Adjust left/right (sliders)
	if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		_adjust_value(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		_adjust_value(1)
		get_viewport().set_input_as_handled()
		return

	# Confirm (toggle or start rebind)
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		_confirm_action()
		get_viewport().set_input_as_handled()
		return

	# Reset defaults (Y / interact)
	if event.is_action_pressed(&"interact"):
		_reset_defaults()
		get_viewport().set_input_as_handled()
		return


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
	_refresh_row(_selected)
	_update_hint_text()
	AudioManager.play_sfx_named("menu_confirm")


func _cancel_rebind() -> void:
	_rebinding = false
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
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = HIGHLIGHT_BG if i == _selected else Color(0, 0, 0, 0)


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
	_hint_label.text = "[Esc] Cancel rebind"
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

	var bar_fill: ColorRect = container.get_meta("bar_fill")
	var val_label: Label = container.get_meta("val_label")

	bar_fill.size = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)

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
	label.text = "ON" if current else "OFF"
	label.add_theme_color_override("font_color", VALUE_COLOR if current else DIMMED_COLOR)


func _refresh_keybind(def: Dictionary, label: Label) -> void:
	var action: String = def["action"]
	var kb: String = SettingsManager.get_action_keyboard_text(StringName(action))
	var ctrl: String = SettingsManager.get_action_controller_text(StringName(action))
	label.text = "%s  /  %s" % [kb, ctrl]
	label.add_theme_color_override("font_color", VALUE_COLOR)


func _update_hint_text() -> void:
	if _rebinding:
		_hint_label.text = "[Esc] Cancel rebind"
		return
	if _selected < 0 or _selected >= _selectable_map.size():
		_hint_label.text = "[B/Esc] Back"
		return
	var def_idx: int = _selectable_map[_selected]
	var def: Dictionary = _row_defs[def_idx]
	var row_type: int = def["type"]
	match row_type:
		RowType.SLIDER:
			_hint_label.text = "[←→] Adjust    [Y] Defaults    [B/Esc] Back"
		RowType.TOGGLE:
			_hint_label.text = "[A/Enter] Toggle    [Y] Defaults    [B/Esc] Back"
		RowType.KEYBIND:
			_hint_label.text = "[A/Enter] Rebind    [Y] Defaults    [B/Esc] Back"
		_:
			_hint_label.text = "[B/Esc] Back"


# ──────────────────────────────────────────────
# VISIBILITY
# ──────────────────────────────────────────────

var _menu_tween: Tween = null


func _show_menu() -> void:
	_root.visible = true
	if _menu_tween and _menu_tween.is_running():
		_menu_tween.kill()
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_menu_tween = create_tween()
	_menu_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_menu_tween.set_parallel(true)
	_menu_tween.tween_property(_overlay, "modulate:a", 1.0, 0.15)
	_menu_tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_delay(0.05)


func _hide_menu() -> void:
	_root.visible = false
