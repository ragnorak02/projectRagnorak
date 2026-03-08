## Simple dialogue box UI.
## Shows speaker name + text, advances page by page.
## Supports controller (A) and keyboard (E/Enter) advance.
extends CanvasLayer

const BG_COLOR := Color(0.03, 0.06, 0.14, 0.92)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.5)
const SPEAKER_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const HINT_COLOR := Color(0.4, 0.5, 0.6)

var _pages: Array[Dictionary] = []
var _current_page: int = 0
var _is_active: bool = false
var _allow_movement: bool = false

var _root: Control
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 12  # Above gameplay HUD, below pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"dialogue_ui")
	_build_ui()
	_hide_dialogue()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -160
	_panel.offset_bottom = -20
	_panel.offset_left = 80
	_panel.offset_right = -80
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 16)
	_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
	_speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", TEXT_COLOR)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint_label)


func start_dialogue(pages: Array, allow_movement: bool = false) -> void:
	if pages.is_empty():
		return
	_pages.clear()
	for p in pages:
		_pages.append(p)
	_current_page = 0
	_allow_movement = allow_movement
	_is_active = true
	_show_page()
	_show_dialogue()


func is_dialogue_active() -> bool:
	return _is_active


func _show_page() -> void:
	if _current_page >= _pages.size():
		_end_dialogue()
		return
	var page: Dictionary = _pages[_current_page]
	_speaker_label.text = page.get("speaker", "")
	_text_label.text = page.get("text", "")

	if InputManager.is_using_controller():
		_hint_label.text = "[A] Continue" if _current_page < _pages.size() - 1 else "[A] Close"
	else:
		_hint_label.text = "[E / Enter] Continue" if _current_page < _pages.size() - 1 else "[E / Enter] Close"


func _advance() -> void:
	_current_page += 1
	_show_page()


func _end_dialogue() -> void:
	_is_active = false
	_pages.clear()
	_hide_dialogue()
	Events.interaction_cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Advance on interact, jump (A on controller), or ui_accept
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") \
			or event.is_action_pressed(&"ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _is_active:
		return
	# Update hint text if input device changes
	if InputManager.is_using_controller():
		_hint_label.text = "[A] Continue" if _current_page < _pages.size() - 1 else "[A] Close"
	else:
		_hint_label.text = "[E / Enter] Continue" if _current_page < _pages.size() - 1 else "[E / Enter] Close"


func _show_dialogue() -> void:
	_root.visible = true


func _hide_dialogue() -> void:
	_root.visible = false
