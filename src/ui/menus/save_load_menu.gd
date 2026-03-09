## Save/Load slot selection menu overlay.
## Builds UI programmatically — shows slot metadata, supports save and load modes.
extends CanvasLayer

# --- Colors ---
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const PANEL_BG := Color(0.05, 0.08, 0.15, 0.95)
const PANEL_BORDER := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const DIMMED_COLOR := Color(0.4, 0.4, 0.5)
const EMPTY_COLOR := Color(0.3, 0.3, 0.4)
const OVERWRITE_COLOR := Color(0.9, 0.5, 0.3)

enum Mode { SAVE, LOAD }

var _mode: Mode = Mode.SAVE
var _is_open: bool = false
var _selected_index: int = 0
var _confirming_overwrite: bool = false

# Slot order: manual 1, 2, 3 (no autosave/quicksave in manual UI)
var _slot_ids: Array[int] = [1, 2, 3]
var _slot_metadata: Array[Dictionary] = []

# --- UI References ---
var _root: Control
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _slot_rows: Array[PanelContainer] = []
var _hint_label: Label
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _feedback_label: Label

signal menu_closed


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func open_menu(mode: Mode) -> void:
	_mode = mode
	_is_open = true
	_selected_index = 0
	_confirming_overwrite = false
	_refresh_slots()
	_update_title()
	_update_selection()
	_confirm_panel.visible = false
	_feedback_label.visible = false
	_root.visible = true


func close_menu() -> void:
	_is_open = false
	_confirming_overwrite = false
	_root.visible = false
	menu_closed.emit()


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if _confirming_overwrite:
		if event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
			_execute_save(_slot_ids[_selected_index])
			_confirming_overwrite = false
			_confirm_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
			_confirming_overwrite = false
			_confirm_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		# Block all other input during confirm
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		_confirm_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


# --- Selection ---

func _move_selection(direction: int) -> void:
	_selected_index = wrapi(_selected_index + direction, 0, _slot_rows.size())
	_update_selection()


func _update_selection() -> void:
	for i in _slot_rows.size():
		var style := _slot_rows[i].get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = HIGHLIGHT_BG if i == _selected_index else Color(0, 0, 0, 0)


func _confirm_slot() -> void:
	var slot_id := _slot_ids[_selected_index]
	if _mode == Mode.SAVE:
		if SaveManager.save_exists(slot_id):
			# Ask overwrite confirmation
			_confirming_overwrite = true
			_confirm_panel.visible = true
			_confirm_label.text = "Overwrite Slot %d? [A/Enter] Yes  [B/Esc] No" % slot_id
		else:
			_execute_save(slot_id)
	else:
		# Load mode
		if not SaveManager.save_exists(slot_id):
			_show_feedback("Slot is empty")
			return
		_execute_load(slot_id)


func _execute_save(slot_id: int) -> void:
	var success := SaveManager.manual_save(slot_id)
	if success:
		_show_feedback("Saved to Slot %d" % slot_id)
		_refresh_slots()
	else:
		_show_feedback("Save failed!")


func _execute_load(slot_id: int) -> void:
	close_menu()
	SaveManager.load_and_apply(slot_id)


# --- Refresh ---

func _refresh_slots() -> void:
	_slot_metadata.clear()
	for slot_id in _slot_ids:
		var meta := SaveManager.get_save_metadata(slot_id)
		if meta.is_empty():
			_slot_metadata.append({"slot": slot_id, "empty": true})
		else:
			meta["empty"] = false
			_slot_metadata.append(meta)

	# Update row labels
	for i in _slot_rows.size():
		var label: Label = _slot_rows[i].get_child(0)
		var meta: Dictionary = _slot_metadata[i]
		if meta.get("empty", true):
			label.text = "Slot %d  —  Empty" % _slot_ids[i]
			label.add_theme_color_override("font_color", EMPTY_COLOR)
		else:
			var ts: String = meta.get("timestamp", "Unknown")
			# Format timestamp for display
			if ts.length() > 16:
				ts = ts.substr(0, 16).replace("T", "  ")
			var zone: String = meta.get("zone_id", "?").replace("_", " ").capitalize()
			label.text = "Slot %d  |  %s  |  %s" % [_slot_ids[i], zone, ts]
			label.add_theme_color_override("font_color", TEXT_COLOR)


func _update_title() -> void:
	_title_label.text = "SAVE GAME" if _mode == Mode.SAVE else "LOAD GAME"


# --- Feedback ---

func _show_feedback(msg: String) -> void:
	_feedback_label.text = msg
	_feedback_label.visible = true
	_feedback_label.modulate.a = 1.0
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_interval(1.5)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _feedback_label.visible = false)


# --- Build UI ---

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

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(500, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ps := StyleBoxFlat.new()
	ps.bg_color = PANEL_BG
	ps.border_color = PANEL_BORDER
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_width_top = 2
	ps.border_width_bottom = 2
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6
	ps.corner_radius_bottom_right = 6
	ps.content_margin_left = 24
	ps.content_margin_right = 24
	ps.content_margin_top = 16
	ps.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", ps)
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "SAVE GAME"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Slot rows
	_slot_rows.clear()
	for i in _slot_ids.size():
		var row := _create_slot_row(i)
		vbox.add_child(row)

	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep2)

	# Hint
	_hint_label = Label.new()
	_hint_label.text = "[A/Enter] Select    [B/Esc] Back"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", DIMMED_COLOR)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint_label)

	# Overwrite confirm panel (hidden)
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm_panel.position.y = 80
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_panel.visible = false

	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.15, 0.08, 0.05, 0.95)
	cs.border_color = OVERWRITE_COLOR
	cs.border_width_left = 2
	cs.border_width_right = 2
	cs.border_width_top = 2
	cs.border_width_bottom = 2
	cs.corner_radius_top_left = 4
	cs.corner_radius_top_right = 4
	cs.corner_radius_bottom_left = 4
	cs.corner_radius_bottom_right = 4
	cs.content_margin_left = 16
	cs.content_margin_right = 16
	cs.content_margin_top = 10
	cs.content_margin_bottom = 10
	_confirm_panel.add_theme_stylebox_override("panel", cs)

	_confirm_label = Label.new()
	_confirm_label.text = "Overwrite?"
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_font_size_override("font_size", 14)
	_confirm_label.add_theme_color_override("font_color", OVERWRITE_COLOR)
	_confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_panel.add_child(_confirm_label)
	_root.add_child(_confirm_panel)

	# Feedback label
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.set_anchors_preset(Control.PRESET_CENTER)
	_feedback_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_feedback_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_feedback_label.position.y = 120
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.visible = false
	_root.add_child(_feedback_label)


func _create_slot_row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(450, 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.corner_radius_top_left = 4
	rs.corner_radius_top_right = 4
	rs.corner_radius_bottom_left = 4
	rs.corner_radius_bottom_right = 4
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rs.content_margin_top = 6
	rs.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", rs)

	var label := Label.new()
	label.text = "Slot %d  —  Empty" % _slot_ids[index]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", EMPTY_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	_slot_rows.append(row)
	return row
