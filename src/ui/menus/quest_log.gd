## Quest log screen accessible from the pause menu.
## Shows active and completed quests with objectives.
## Navigable by controller and keyboard.
extends CanvasLayer

const BG_COLOR := Color(0.03, 0.06, 0.14, 0.95)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const DIM_COLOR := Color(0.4, 0.45, 0.55)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const COMPLETE_COLOR := Color(0.3, 0.8, 0.3)
const OBJECTIVE_COLOR := Color(0.7, 0.75, 0.85)
const MARKER_COLOR := Color(0.9, 0.7, 0.3)

var _is_open: bool = false
var _selected_index: int = 0
var _quest_entries: Array[Dictionary] = []
var _quest_system: Node = null

var _root: Control
var _overlay: ColorRect
var _panel: PanelContainer
var _header_label: Label
var _list_container: VBoxContainer
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_objectives: VBoxContainer
var _detail_type: Label
var _detail_status: Label
var _hint_label: Label
var _empty_label: Label
var _quest_rows: Array[PanelContainer] = []


func _ready() -> void:
	layer = 16  # Above pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_log()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.8)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	# Main container: horizontal split (list | detail)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 60
	hbox.offset_right = -60
	hbox.offset_top = 40
	hbox.offset_bottom = -40
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hbox)

	# --- Left panel: quest list ---
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.4
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_style := _make_panel_style()
	left_panel.add_theme_stylebox_override("panel", left_style)
	hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_vbox)

	_header_label = Label.new()
	_header_label.text = "QUEST LOG"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.add_theme_color_override("font_color", TITLE_COLOR)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(_header_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 2)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list_container)

	_empty_label = Label.new()
	_empty_label.text = "No quests"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.add_theme_color_override("font_color", DIM_COLOR)
	_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_container.add_child(_empty_label)

	# --- Right panel: quest detail ---
	_detail_panel = PanelContainer.new()
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_stretch_ratio = 0.6
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_style := _make_panel_style()
	_detail_panel.add_theme_stylebox_override("panel", right_style)
	hbox.add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 8)
	detail_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(detail_vbox)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 22)
	_detail_title.add_theme_color_override("font_color", TITLE_COLOR)
	_detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_title)

	_detail_type = Label.new()
	_detail_type.add_theme_font_size_override("font_size", 12)
	_detail_type.add_theme_color_override("font_color", MARKER_COLOR)
	_detail_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_type)

	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(sep2)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 15)
	_detail_desc.add_theme_color_override("font_color", TEXT_COLOR)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_desc)

	var obj_header := Label.new()
	obj_header.text = "Objectives"
	obj_header.add_theme_font_size_override("font_size", 14)
	obj_header.add_theme_color_override("font_color", TITLE_COLOR)
	obj_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(obj_header)

	_detail_objectives = VBoxContainer.new()
	_detail_objectives.add_theme_constant_override("separation", 4)
	_detail_objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_objectives)

	_detail_status = Label.new()
	_detail_status.add_theme_font_size_override("font_size", 13)
	_detail_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_status)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(spacer)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", DIM_COLOR)
	_hint_label.text = "[A/Enter] Track    [B/Esc] Back"
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_hint_label)


func open_log(quest_sys: Node) -> void:
	_quest_system = quest_sys
	_is_open = true
	_refresh_list()
	_show_log()


func close_log() -> void:
	_is_open = false
	_quest_system = null
	_hide_log()


func is_open() -> bool:
	return _is_open


func _refresh_list() -> void:
	# Clear old rows
	for row in _quest_rows:
		row.queue_free()
	_quest_rows.clear()
	_quest_entries.clear()

	if _quest_system == null:
		_empty_label.visible = true
		_clear_detail()
		return

	# Active quests
	var active: Array = _quest_system.get_active_quests()
	for q: Dictionary in active:
		_quest_entries.append({"quest_id": q["quest_id"], "data": q["data"],
			"progress": q["progress"], "current_objective_index": q["current_objective_index"],
			"completed": false})

	# Completed quests
	var completed: Array = _quest_system.get_completed_quests()
	for qid: StringName in completed:
		_quest_entries.append({"quest_id": qid, "data": null, "progress": [],
			"current_objective_index": 0, "completed": true})

	_empty_label.visible = _quest_entries.is_empty()

	for i in _quest_entries.size():
		var entry: Dictionary = _quest_entries[i]
		var row := _create_quest_row(entry, i)
		_list_container.add_child(row)
		_quest_rows.append(row)

	_selected_index = 0
	_update_selection()
	_update_detail()


func _create_quest_row(entry: Dictionary, _idx: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_left = 3
	row_style.corner_radius_bottom_right = 3
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", row_style)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if entry["completed"]:
		label.text = "[Done] %s" % String(entry["quest_id"])
		label.add_theme_color_override("font_color", COMPLETE_COLOR)
	elif entry["data"] != null:
		label.text = entry["data"].title
		label.add_theme_color_override("font_color", TEXT_COLOR)
	else:
		label.text = String(entry["quest_id"])
		label.add_theme_color_override("font_color", DIM_COLOR)

	row.add_child(label)
	return row


func _update_selection() -> void:
	for i in _quest_rows.size():
		var row: PanelContainer = _quest_rows[i]
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		if i == _selected_index:
			style.bg_color = HIGHLIGHT_BG
		else:
			style.bg_color = Color(0, 0, 0, 0)


func _update_detail() -> void:
	if _quest_entries.is_empty() or _selected_index >= _quest_entries.size():
		_clear_detail()
		return

	var entry: Dictionary = _quest_entries[_selected_index]

	if entry["completed"]:
		_detail_title.text = String(entry["quest_id"])
		_detail_type.text = ""
		_detail_desc.text = ""
		_detail_status.text = "COMPLETED"
		_detail_status.add_theme_color_override("font_color", COMPLETE_COLOR)
		_clear_objectives()
		return

	var data: Resource = entry["data"]
	if data == null:
		_clear_detail()
		return

	_detail_title.text = data.title
	_detail_desc.text = data.description

	var type_names := ["Story", "Side", "Exploration"]
	_detail_type.text = type_names[data.quest_type] if data.quest_type < type_names.size() else "Quest"

	_detail_status.text = "IN PROGRESS"
	_detail_status.add_theme_color_override("font_color", MARKER_COLOR)

	# Objectives
	_clear_objectives()
	var progress: Array = entry["progress"]
	for i in data.objectives.size():
		var obj: Resource = data.objectives[i]
		var current: int = progress[i] if i < progress.size() else 0
		var done: bool = current >= obj.target_count
		var obj_label := Label.new()
		obj_label.add_theme_font_size_override("font_size", 14)
		obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if obj.target_count > 1:
			obj_label.text = "%s  (%d/%d)" % [obj.description, current, obj.target_count]
		else:
			obj_label.text = "%s  %s" % [obj.description, "- Done" if done else ""]

		if done:
			obj_label.add_theme_color_override("font_color", COMPLETE_COLOR)
		else:
			obj_label.add_theme_color_override("font_color", OBJECTIVE_COLOR)
		_detail_objectives.add_child(obj_label)


func _clear_objectives() -> void:
	for child in _detail_objectives.get_children():
		child.queue_free()


func _clear_detail() -> void:
	_detail_title.text = ""
	_detail_type.text = ""
	_detail_desc.text = "Select a quest"
	_detail_status.text = ""
	_clear_objectives()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return

	# Track quest
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		_track_selected()
		get_viewport().set_input_as_handled()
		return

	# Back
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"pause"):
		close_log()
		get_viewport().set_input_as_handled()
		return


func _move_selection(direction: int) -> void:
	if _quest_entries.is_empty():
		return
	_selected_index = wrapi(_selected_index + direction, 0, _quest_entries.size())
	_update_selection()
	_update_detail()


func _track_selected() -> void:
	if _quest_entries.is_empty() or _selected_index >= _quest_entries.size():
		return
	var entry: Dictionary = _quest_entries[_selected_index]
	if entry["completed"] or _quest_system == null:
		return
	_quest_system.set_tracked_quest(entry["quest_id"])


func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_COLOR
	s.border_color = BORDER_COLOR
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _show_log() -> void:
	_root.visible = true


func _hide_log() -> void:
	_root.visible = false
