## Quest log screen accessible from the pause menu.
## Shows active and completed quests with objectives.
## Navigable by controller and keyboard.
## Visuals: "Lumina Frost" menu shell — header tab, glass list + detail panels,
## footer glyph bar (UIStyle widgets).
extends CanvasLayer

# Legacy palette (the visual pass uses UIStyle colours)
const BG_COLOR := Color(0.03, 0.06, 0.14, 0.95)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const DIM_COLOR := Color(0.4, 0.45, 0.55)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const COMPLETE_COLOR := Color(0.3, 0.8, 0.3)
const OBJECTIVE_COLOR := Color(0.7, 0.75, 0.85)
const MARKER_COLOR := Color(0.9, 0.7, 0.3)

const DONE_COLOR := Color("#5FD38A")   # objective/quest complete (fits the frost palette)
const MARGIN_X := 96.0
const CONTENT_TOP := 168.0
const LIST_WIDTH := 600.0
const FOOTER_H := 64.0

var _is_open: bool = false
var _selected_index: int = 0
var _quest_entries: Array[Dictionary] = []
var _quest_system: Node = null

var _root: Control
var _overlay: ColorRect
var _panel: Control
var _header: HeaderTab
var _header_label: Label
var _scroll: ScrollContainer
var _list_container: VBoxContainer
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_objectives: VBoxContainer
var _detail_type: Label
var _detail_status: Label
var _hint_label: Label
var _empty_label: Label
var _quest_rows: Array = []      # MenuRow per entry (plain Array: see UI kit notes)
var _tracked_id: StringName = &""
## Stick/D-pad/key navigation (v5 AA): one push = one step, hold = steady repeat.
var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"], [], [])


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
	_overlay.color = Color(UIStyle.DIM_SCREEN, 0.94)   # full screen: hide the menu beneath
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	# --- Header tab ---
	_header = HeaderTab.new().setup("Quest Log", "")
	_header.title_size = UIStyle.SIZE_L
	_header.position = Vector2(MARGIN_X, 72)
	_panel.add_child(_header)
	_header_label = _header.get_title_label()

	var rule := ColorRect.new()
	rule.color = UIStyle.CYAN_DIM
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.anchor_right = 1.0
	rule.offset_left = MARGIN_X
	rule.offset_right = -MARGIN_X
	rule.offset_top = 138
	rule.offset_bottom = 139
	_panel.add_child(rule)

	# --- Left panel: quest list ---
	var left_panel := SlantPanel.new()
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = MARGIN_X
	left_panel.offset_right = MARGIN_X + LIST_WIDTH
	left_panel.offset_top = CONTENT_TOP
	left_panel.offset_bottom = -(FOOTER_H + 48)
	left_panel.padding = 16
	_panel.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_vbox)

	left_vbox.add_child(UIStyle.make_label("QUESTS", UIStyle.SIZE_M, UIStyle.GOLD, true))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 6)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list_container)

	_empty_label = UIStyle.make_label("No quests yet. Talk to people around town.", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_list_container.add_child(_empty_label)

	# --- Right panel: quest detail ---
	_detail_panel = SlantPanel.new()
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_bottom = 1.0
	_detail_panel.offset_left = MARGIN_X + LIST_WIDTH + 32
	_detail_panel.offset_right = -MARGIN_X
	_detail_panel.offset_top = CONTENT_TOP
	_detail_panel.offset_bottom = -(FOOTER_H + 48)
	(_detail_panel as SlantPanel).slant_left = false
	(_detail_panel as SlantPanel).slant_right = true
	(_detail_panel as SlantPanel).padding = 24
	_panel.add_child(_detail_panel)

	var detail_vbox := VBoxContainer.new()
	detail_vbox.add_theme_constant_override("separation", 12)
	detail_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.add_child(detail_vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 16)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(title_row)

	_detail_title = UIStyle.make_label("", UIStyle.SIZE_L + 6, UIStyle.TEXT, true)
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(_detail_title)

	_detail_status = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.GOLD, true)
	_detail_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_detail_status)

	_detail_type = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.GOLD, true)
	_detail_type.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_detail_type.add_theme_stylebox_override("normal", UIStyle.pill(UIStyle.GLASS_DEEP, UIStyle.GOLD_DIM, 12, 2))
	detail_vbox.add_child(_detail_type)

	_detail_desc = UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.TEXT)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_vbox.add_child(_detail_desc)

	var obj_gap := Control.new()
	obj_gap.custom_minimum_size.y = 6
	obj_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(obj_gap)

	var obj_header := UIStyle.make_label("OBJECTIVES", UIStyle.SIZE_M, UIStyle.GOLD, true)
	detail_vbox.add_child(obj_header)

	_detail_objectives = VBoxContainer.new()
	_detail_objectives.add_theme_constant_override("separation", 8)
	_detail_objectives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_vbox.add_child(_detail_objectives)

	# --- Footer: status + glyph hints ---
	var footer := PanelContainer.new()
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -FOOTER_H - 24
	footer.offset_bottom = -24
	footer.offset_left = MARGIN_X
	footer.offset_right = -MARGIN_X
	footer.add_theme_stylebox_override("panel", UIStyle.glass_panel(12))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(footer)

	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override("separation", 28)
	fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(fbox)

	_hint_label = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fbox.add_child(_hint_label)
	fbox.add_child(GlyphHint.create(&"ui_up", "Select", UIStyle.SIZE_S))
	fbox.add_child(GlyphHint.create(&"ui_accept", "Track", UIStyle.SIZE_S))
	fbox.add_child(GlyphHint.create(&"ui_cancel", "Back", UIStyle.SIZE_S))


func open_log(quest_sys: Node) -> void:
	_quest_system = quest_sys
	_is_open = true
	_nav.reset()
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
		_update_header_counts()
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
	_update_header_counts()


func _create_quest_row(entry: Dictionary, _idx: int) -> Control:
	var row := MenuRow.new()
	row.focus_mode = Control.FOCUS_NONE   # cursor-driven (see _update_selection)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.row_font_size = UIStyle.SIZE_M
	row.custom_minimum_size = Vector2(0, 48)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if entry["completed"]:
		row.text = String(entry["quest_id"]).replace("_", " ").capitalize()
		row.right_text = "DONE"
		row.unavailable = true   # greyed but still selectable for review
	elif entry["data"] != null:
		row.text = entry["data"].title
	else:
		row.text = String(entry["quest_id"])
		row.unavailable = true

	row.set_meta("quest_id", entry["quest_id"])
	return row


func _update_selection() -> void:
	for i in _quest_rows.size():
		var row: MenuRow = _quest_rows[i]
		row.selected = i == _selected_index
	if _selected_index >= 0 and _selected_index < _quest_rows.size() and _scroll:
		_scroll.ensure_control_visible(_quest_rows[_selected_index])
	_update_tracked_marks()


func _update_detail() -> void:
	if _quest_entries.is_empty() or _selected_index >= _quest_entries.size():
		_clear_detail()
		return

	var entry: Dictionary = _quest_entries[_selected_index]

	if entry["completed"]:
		_detail_title.text = String(entry["quest_id"]).replace("_", " ").capitalize()
		_detail_type.text = ""
		_detail_type.visible = false
		_detail_desc.text = ""
		_detail_status.text = "COMPLETED"
		_detail_status.add_theme_color_override("font_color", DONE_COLOR)
		_clear_objectives()
		return

	var data: Resource = entry["data"]
	if data == null:
		_clear_detail()
		return

	_detail_title.text = data.title
	_detail_desc.text = data.description

	var type_names := ["Story", "Side", "Exploration"]
	_detail_type.text = (type_names[data.quest_type] if data.quest_type < type_names.size() else "Quest").to_upper()
	_detail_type.visible = true

	_detail_status.text = "IN PROGRESS"
	_detail_status.add_theme_color_override("font_color", UIStyle.CYAN)

	# Objectives
	_clear_objectives()
	var progress: Array = entry["progress"]
	var current_idx: int = entry.get("current_objective_index", 0)
	for i in data.objectives.size():
		var obj: Resource = data.objectives[i]
		var current: int = progress[i] if i < progress.size() else 0
		var done: bool = current >= obj.target_count
		var text := ""
		if obj.target_count > 1:
			text = "%s  (%d/%d)" % [obj.description, current, obj.target_count]
		else:
			text = "%s  %s" % [obj.description, "- Done" if done else ""]
		_detail_objectives.add_child(_make_objective_line(text.strip_edges(), done, i == current_idx and not done))


func _make_objective_line(text: String, done: bool, is_current: bool) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bullet: a small diamond-ish square, coloured by state
	var bullet := ColorRect.new()
	bullet.custom_minimum_size = Vector2(10, 10)
	bullet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bullet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bullet.color = DONE_COLOR if done else (UIStyle.CYAN if is_current else UIStyle.TEXT_DISABLED)
	line.add_child(bullet)
	var col := DONE_COLOR if done else (UIStyle.TEXT if is_current else UIStyle.TEXT_DIM)
	var obj_label := UIStyle.make_label(text, UIStyle.SIZE_M, col)
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(obj_label)
	return line


func _clear_objectives() -> void:
	for child in _detail_objectives.get_children():
		child.queue_free()


func _clear_detail() -> void:
	_detail_title.text = ""
	_detail_type.text = ""
	_detail_type.visible = false
	_detail_desc.text = "Select a quest"
	_detail_status.text = ""
	_clear_objectives()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Raw stick motion -> MenuNav (stepped in _process); D-pad / keys step here.
	if _nav.consume_event(event):
		get_viewport().set_input_as_handled()
		return
	var step := _nav.event_step(event)
	if step.y != 0:
		_move_selection(step.y)
		get_viewport().set_input_as_handled()
		return

	# Track quest
	if event.is_action_pressed(&"ui_accept"):
		_track_selected()
		get_viewport().set_input_as_handled()
		return

	# Back
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
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


# --- Visual helpers ---

## Poll the tracked quest (read-only) so the "TRACKED" tag follows A presses.
func _process(_delta: float) -> void:
	if not _is_open:
		return
	var nav_step := _nav.poll()
	if nav_step.y != 0:
		_move_selection(nav_step.y)
	if _quest_system == null:
		return
	if _current_tracked_id() != _tracked_id:
		_update_tracked_marks()


func _current_tracked_id() -> StringName:
	if _quest_system == null or not _quest_system.has_method("get_tracked_quest"):
		return &""
	var t: Dictionary = _quest_system.get_tracked_quest()
	return t.get("quest_id", &"")


func _update_tracked_marks() -> void:
	_tracked_id = _current_tracked_id()
	var tracked_title := ""
	for i in _quest_rows.size():
		var row: MenuRow = _quest_rows[i]
		var entry: Dictionary = _quest_entries[i] if i < _quest_entries.size() else {}
		if entry.get("completed", false):
			continue
		var is_tracked: bool = _tracked_id != &"" and row.get_meta("quest_id", &"") == _tracked_id
		row.right_text = "TRACKED" if is_tracked else ""
		if is_tracked:
			tracked_title = row.text
	if _hint_label:
		_hint_label.text = ("Tracking:  %s" % tracked_title) if tracked_title != "" else "No quest tracked"


func _update_header_counts() -> void:
	var active := 0
	var done := 0
	for e: Dictionary in _quest_entries:
		if e["completed"]:
			done += 1
		else:
			active += 1
	_header.subtitle = "%d active  ·  %d completed" % [active, done]


func _make_panel_style() -> StyleBoxFlat:
	return UIStyle.glass_panel(14)


func _show_log() -> void:
	_root.visible = true
	_overlay.modulate.a = 0.0
	var tw := UIStyle.ui_tween(_overlay)
	if tw:
		tw.tween_property(_overlay, "modulate:a", 1.0, UIStyle.ANIM_TIME)
	else:
		_overlay.modulate.a = 1.0
	UIStyle.fade_slide_in(_panel, Vector2.RIGHT, 0.16, 12.0)


func _hide_log() -> void:
	_root.visible = false
