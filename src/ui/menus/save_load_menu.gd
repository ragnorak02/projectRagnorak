## Save/Load slot selection menu overlay.
## Builds UI programmatically — shows slot metadata, supports save and load modes.
## Visuals: "Lumina Frost" menu shell (header tab, glass slot cards, footer glyphs).
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
## Stick/D-pad/key navigation (v5 AA): one push = one step, hold = steady repeat.
var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"], [], [])

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
var _header: HeaderTab
var _accept_hint: GlyphHint

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
	_nav.reset()
	_refresh_slots()
	_update_title()
	_update_selection()
	_confirm_panel.visible = false
	_feedback_label.visible = false
	_root.visible = true
	_play_open_transition()


func close_menu() -> void:
	_is_open = false
	_confirming_overwrite = false
	_root.visible = false
	menu_closed.emit()


func _play_open_transition() -> void:
	_overlay.modulate.a = 0.0
	var tw := UIStyle.ui_tween(_overlay)
	if tw:
		tw.tween_property(_overlay, "modulate:a", 1.0, UIStyle.ANIM_TIME)
	else:
		_overlay.modulate.a = 1.0
	_panel.modulate.a = 0.0
	var tp := UIStyle.ui_tween(_panel)
	if tp:
		tp.tween_property(_panel, "modulate:a", 1.0, 0.16)
	else:
		_panel.modulate.a = 1.0


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if _confirming_overwrite:
		if event.is_action_pressed(&"ui_accept"):
			_execute_save(_slot_ids[_selected_index])
			_confirming_overwrite = false
			_confirm_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"ui_cancel"):
			_confirming_overwrite = false
			_confirm_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		# Block all other input during confirm (stick still tracked, never steps)
		_nav.consume_event(event)
		get_viewport().set_input_as_handled()
		return

	# Raw stick motion -> MenuNav (stepped in _process); D-pad / keys step here.
	if _nav.consume_event(event):
		get_viewport().set_input_as_handled()
		return
	var step := _nav.event_step(event)
	if step.y != 0:
		_move_selection(step.y)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		_confirm_slot()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _is_open:
		return
	var nav_step := _nav.poll()
	if _confirming_overwrite:
		return   # the overwrite prompt blocks navigation
	if nav_step.y != 0:
		_move_selection(nav_step.y)


# --- Selection ---

func _move_selection(direction: int) -> void:
	_selected_index = wrapi(_selected_index + direction, 0, _slot_rows.size())
	_update_selection()


func _update_selection() -> void:
	for i in _slot_rows.size():
		var row: SlantPanel = _slot_rows[i]
		var is_sel := i == _selected_index
		row.selected = is_sel
		var accent: ColorRect = row.get_meta("accent")
		accent.color = UIStyle.CYAN if is_sel else Color(0, 0, 0, 0)
		var idx_label: Label = row.get_meta("index_label")
		idx_label.add_theme_color_override("font_color", UIStyle.GOLD if is_sel else UIStyle.GOLD_DIM)


func _confirm_slot() -> void:
	var slot_id := _slot_ids[_selected_index]
	if _mode == Mode.SAVE:
		if SaveManager.save_exists(slot_id):
			# Ask overwrite confirmation
			_confirming_overwrite = true
			_confirm_panel.visible = true
			_confirm_label.text = "Overwrite Slot %d?" % slot_id
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
		var row: Control = _slot_rows[i]
		var label: Label = row.get_meta("zone_label")
		var sub: Label = row.get_meta("time_label")
		var meta: Dictionary = _slot_metadata[i]
		if meta.get("empty", true):
			label.text = "Empty Slot"
			label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
			sub.text = "No data"
			sub.add_theme_color_override("font_color", UIStyle.TEXT_DISABLED)
		else:
			var ts: String = meta.get("timestamp", "Unknown")
			# Format timestamp for display
			if ts.length() > 16:
				ts = ts.substr(0, 16).replace("T", "  ")
			var zone: String = meta.get("zone_id", "?").replace("_", " ").capitalize()
			label.text = zone
			label.add_theme_color_override("font_color", UIStyle.TEXT)
			sub.text = ts
			sub.add_theme_color_override("font_color", UIStyle.TEXT_DIM)


func _update_title() -> void:
	_header.title = "Save Game" if _mode == Mode.SAVE else "Load Game"
	_header.subtitle = "Choose a slot"
	_title_label.text = _header.get_title_label().text
	if _accept_hint:
		_accept_hint.text = "Save" if _mode == Mode.SAVE else "Load"


# --- Feedback ---

func _show_feedback(msg: String) -> void:
	_feedback_label.text = msg
	_feedback_label.visible = true
	_feedback_label.modulate.a = 1.0
	var bad := msg.contains("fail") or msg.contains("empty")
	_feedback_label.add_theme_color_override("font_color", UIStyle.DANGER if bad else UIStyle.CYAN)
	_feedback_label.add_theme_stylebox_override("normal",
		UIStyle.pill(UIStyle.GLASS_DEEP, UIStyle.DANGER if bad else UIStyle.CYAN_DIM, 20, 6))
	var tween := UIStyle.ui_tween(_feedback_label)
	if tween == null:
		return
	tween.tween_interval(1.5)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _feedback_label.visible = false)


# --- Build UI ---

const SHELL_WIDTH := 880.0


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

	# Centered shell: header tab + glass content + footer glyph bar
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(SHELL_WIDTH, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(_panel)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 0)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(shell)

	_header = HeaderTab.new().setup("Save Game", "Choose a slot")
	_header.title_size = UIStyle.SIZE_L
	_header.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	shell.add_child(_header)
	_title_label = Label.new()   # legacy handle; HeaderTab renders the title
	_title_label.text = "SAVE GAME"
	_title_label.visible = false
	shell.add_child(_title_label)

	var content := SlantPanel.new()
	content.padding = 20
	shell.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(vbox)

	# Slot rows
	_slot_rows.clear()
	for i in _slot_ids.size():
		var row := _create_slot_row(i)
		vbox.add_child(row)

	# Footer glyph bar
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UIStyle.glass_panel(10))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(footer)
	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override("separation", 28)
	fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(fbox)
	_hint_label = UIStyle.make_label("Manual slots", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fbox.add_child(_hint_label)
	fbox.add_child(GlyphHint.create(&"ui_up", "Select", UIStyle.SIZE_S))
	_accept_hint = GlyphHint.create(&"ui_accept", "Save", UIStyle.SIZE_S)
	fbox.add_child(_accept_hint)
	fbox.add_child(GlyphHint.create(&"ui_cancel", "Back", UIStyle.SIZE_S))

	# Overwrite confirm panel (hidden)
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm_panel.custom_minimum_size = Vector2(560, 0)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_panel.visible = false

	var cs := UIStyle.glass_panel_selected(22)
	cs.bg_color = Color(UIStyle.GLASS_DEEP, 0.97)
	cs.border_color = OVERWRITE_COLOR
	cs.shadow_color = Color(0, 0, 0, 0.6)
	cs.shadow_size = 24
	_confirm_panel.add_theme_stylebox_override("panel", cs)

	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 16)
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_panel.add_child(cbox)
	_confirm_label = UIStyle.make_label("Overwrite?", UIStyle.SIZE_L, OVERWRITE_COLOR, true)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(_confirm_label)
	var csub := UIStyle.make_label("The existing save in this slot will be replaced.", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	csub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(csub)
	var chints := HBoxContainer.new()
	chints.alignment = BoxContainer.ALIGNMENT_CENTER
	chints.add_theme_constant_override("separation", 36)
	chints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chints.add_child(GlyphHint.create(&"ui_accept", "Yes", UIStyle.SIZE_M))
	chints.add_child(GlyphHint.create(&"ui_cancel", "No", UIStyle.SIZE_M))
	cbox.add_child(chints)
	_root.add_child(_confirm_panel)

	# Feedback toast
	_feedback_label = UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.CYAN, true)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.anchor_left = 0.5
	_feedback_label.anchor_right = 0.5
	_feedback_label.anchor_top = 1.0
	_feedback_label.anchor_bottom = 1.0
	_feedback_label.offset_left = -240
	_feedback_label.offset_right = 240
	_feedback_label.offset_top = -200
	_feedback_label.offset_bottom = -160
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.visible = false
	_root.add_child(_feedback_label)


func _create_slot_row(index: int) -> PanelContainer:
	var row := SlantPanel.new()
	row.custom_minimum_size = Vector2(SHELL_WIDTH - 60, 92)
	row.padding = 14
	row.show_top_line = false
	row.fill_color = Color(UIStyle.GLASS.r, UIStyle.GLASS.g, UIStyle.GLASS.b, 0.55)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 22)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.color = Color(0, 0, 0, 0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(accent)

	var idx_label := UIStyle.make_label("%02d" % _slot_ids[index], UIStyle.SIZE_XL, UIStyle.GOLD_DIM, true)
	idx_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	idx_label.custom_minimum_size.x = 70
	hbox.add_child(idx_label)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)

	var label := UIStyle.make_label("Slot %d  —  Empty" % _slot_ids[index], UIStyle.SIZE_L, EMPTY_COLOR, true)
	info.add_child(label)
	var sub := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	info.add_child(sub)

	var slot_tag := UIStyle.make_label("SLOT %d" % _slot_ids[index], UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	slot_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(slot_tag)

	row.set_meta("accent", accent)
	row.set_meta("index_label", idx_label)
	row.set_meta("zone_label", label)
	row.set_meta("time_label", sub)

	_slot_rows.append(row)
	return row
