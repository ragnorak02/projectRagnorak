## Pause menu overlay with Resume, Inventory, Quest Log, Settings, Return to Title.
## Builds UI programmatically — no .tscn needed.
## Toggle with the "pause" action (Escape / Start button).
extends CanvasLayer

const QuestLogScript := preload("res://src/ui/menus/quest_log.gd")
const SaveLoadMenuScript := preload("res://src/ui/menus/save_load_menu.gd")

# --- Colors ---
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const PANEL_BG := Color(0.05, 0.08, 0.15, 0.95)
const PANEL_BORDER := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const DIMMED_COLOR := Color(0.4, 0.4, 0.5)

# --- Menu item definitions ---
enum MenuItem { RESUME, SAVE_GAME, INVENTORY, QUEST_LOG, SETTINGS, RETURN_TO_TITLE }

const MENU_ITEMS: Array[Dictionary] = [
	{ "id": MenuItem.RESUME, "label": "Resume", "available": true },
	{ "id": MenuItem.SAVE_GAME, "label": "Save Game", "available": true },
	{ "id": MenuItem.INVENTORY, "label": "Inventory", "available": false },
	{ "id": MenuItem.QUEST_LOG, "label": "Quest Log", "available": true },
	{ "id": MenuItem.SETTINGS, "label": "Settings", "available": false },
	{ "id": MenuItem.RETURN_TO_TITLE, "label": "Return to Title", "available": true },
]

# --- State ---
var _is_open: bool = false
var _selected_index: int = 0

# --- UI References ---
var _root: Control
var _overlay: ColorRect
var _panel: PanelContainer
var _item_rows: Array[PanelContainer] = []
var _item_labels: Array[Label] = []
var _placeholder_label: Label
var _quest_log: Node = null
var _save_load_menu: Node = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_menu()


func _build_ui() -> void:
	# --- Full-screen root ---
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- Dark semi-transparent overlay ---
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = OVERLAY_COLOR
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	# --- Centered panel ---
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(320, 0)
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

	# --- Vertical layout inside panel ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	# --- "PAUSED" header ---
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# --- Separator ---
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# --- Menu items ---
	_item_rows.clear()
	_item_labels.clear()

	for item: Dictionary in MENU_ITEMS:
		var row := _create_menu_row(item)
		vbox.add_child(row)

	# --- Separator before hint ---
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	sep2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep2)

	# --- Control hint ---
	var hint := Label.new()
	hint.text = "[A/Enter] Select    [B/Esc] Resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", DIMMED_COLOR)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)

	# --- Placeholder "Coming Soon" label (hidden by default) ---
	_placeholder_label = Label.new()
	_placeholder_label.text = "Coming Soon"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.set_anchors_preset(Control.PRESET_CENTER)
	_placeholder_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_placeholder_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_placeholder_label.position.y = 60
	_placeholder_label.add_theme_font_size_override("font_size", 16)
	_placeholder_label.add_theme_color_override("font_color", DIMMED_COLOR)
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder_label.visible = false
	_root.add_child(_placeholder_label)


func _create_menu_row(item: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(280, 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_style.content_margin_left = 12
	row_style.content_margin_right = 12
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", row_style)

	var label := Label.new()
	label.text = item["label"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if item["available"]:
		label.add_theme_color_override("font_color", TEXT_COLOR)
	else:
		label.add_theme_color_override("font_color", DIMMED_COLOR)

	row.add_child(label)

	row.set_meta("item_id", item["id"])
	row.set_meta("available", item["available"])

	_item_rows.append(row)
	_item_labels.append(label)

	return row


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if not _is_open:
		return

	# Navigate up
	if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return

	# Navigate down
	if event.is_action_pressed(&"move_down") or event.is_action_pressed(&"ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
		return

	# Confirm selection
	if event.is_action_pressed(&"attack") or event.is_action_pressed(&"ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return

	# Cancel / back (same as Resume)
	if event.is_action_pressed(&"dodge") or event.is_action_pressed(&"ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()
		return


# --- Menu Toggle ---

func _toggle_menu() -> void:
	if _is_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	# Block pause during states that should not allow it
	if GameManager.current_state == GameManager.GameState.MAIN_MENU:
		return
	if GameManager.current_state == GameManager.GameState.LOADING:
		return
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	_is_open = true
	_selected_index = 0
	_placeholder_label.visible = false
	_update_selection()
	_show_menu()
	GameManager.change_state(GameManager.GameState.PAUSED)
	Events.ui_menu_opened.emit(&"pause_menu")
	AudioManager.play_sfx_named("menu_open")


func _close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_placeholder_label.visible = false
	_hide_menu()
	GameManager.change_state(GameManager.GameState.PLAYING)
	Events.ui_menu_closed.emit(&"pause_menu")
	AudioManager.play_sfx_named("menu_close")


# --- Selection ---

func _move_selection(direction: int) -> void:
	_selected_index = wrapi(_selected_index + direction, 0, _item_rows.size())
	_update_selection()
	AudioManager.play_sfx_named("menu_select")


func _update_selection() -> void:
	for i in _item_rows.size():
		var row: PanelContainer = _item_rows[i]
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		if i == _selected_index:
			style.bg_color = HIGHLIGHT_BG
		else:
			style.bg_color = Color(0, 0, 0, 0)


func _confirm_selection() -> void:
	if _selected_index < 0 or _selected_index >= _item_rows.size():
		return

	var row: PanelContainer = _item_rows[_selected_index]
	var item_id: int = row.get_meta("item_id")
	var available: bool = row.get_meta("available")

	if not available:
		# Show "Coming Soon" briefly
		_show_placeholder()
		return

	AudioManager.play_sfx_named("menu_confirm")
	match item_id:
		MenuItem.RESUME:
			_close_menu()
		MenuItem.SAVE_GAME:
			_open_save_menu()
		MenuItem.QUEST_LOG:
			_open_quest_log()
		MenuItem.RETURN_TO_TITLE:
			_return_to_title()


func _open_save_menu() -> void:
	if _save_load_menu == null:
		_save_load_menu = CanvasLayer.new()
		_save_load_menu.set_script(SaveLoadMenuScript)
		add_child(_save_load_menu)
	_save_load_menu.open_menu(0)  # 0 = Mode.SAVE


func _open_quest_log() -> void:
	# Find player's quest system
	var players := get_tree().get_nodes_in_group(&"player")
	var quest_sys: Node = null
	if not players.is_empty() and players[0].has_node("QuestSystem"):
		quest_sys = players[0].get_node("QuestSystem")

	if _quest_log == null:
		_quest_log = CanvasLayer.new()
		_quest_log.set_script(QuestLogScript)
		add_child(_quest_log)

	_quest_log.open_log(quest_sys)


func _return_to_title() -> void:
	_is_open = false
	_hide_menu()
	# Unpause before changing scene
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	Events.ui_menu_closed.emit(&"pause_menu")
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


# --- Placeholder feedback ---

func _show_placeholder() -> void:
	_placeholder_label.visible = true
	_placeholder_label.modulate.a = 1.0

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_interval(1.0)
	tween.tween_property(_placeholder_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _placeholder_label.visible = false)


# --- Visibility ---

var _menu_tween: Tween = null


func _show_menu() -> void:
	_root.visible = true
	# Fade-in transition
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
