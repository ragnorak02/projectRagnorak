## Simple dialogue box UI.
## Shows speaker name + text, advances page by page.
## Supports controller (A) and keyboard (E/Enter) advance.
extends CanvasLayer

## Visuals: "Lumina Frost" lower-third glass panel, speaker name tab and a
## glyph advance indicator (UIStyle widgets). No typewriter effect.
const BG_COLOR := Color(0.03, 0.06, 0.14, 0.92)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.5)
const SPEAKER_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const HINT_COLOR := Color(0.4, 0.5, 0.6)

var _pages: Array[Dictionary] = []
var _current_page: int = 0
var _is_active: bool = false
var _allow_movement: bool = false
## Process frame on which the dialogue opened. Advance input on that same frame
## is ignored so the press that opened the dialogue (contextual A / E interact)
## cannot also skip page 1.
var _opened_frame: int = -1

var _root: Control
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label
var _frame: Control
var _speaker_tab: HeaderTab
var _advance_hint: GlyphHint
var _page_label: Label


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

	# Lower-third frame: speaker tab sits on the panel's top-left edge.
	var frame := VBoxContainer.new()
	frame.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# Lower-third, left of centre so it clears the bottom-right party panel.
	frame.offset_left = 200
	frame.offset_right = -580
	frame.offset_top = -300
	frame.offset_bottom = -56
	frame.add_theme_constant_override("separation", 0)
	frame.alignment = BoxContainer.ALIGNMENT_END
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN   # extra height grows upward
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(frame)
	_frame = frame

	_speaker_tab = HeaderTab.new()
	_speaker_tab.title_size = UIStyle.SIZE_M + 4
	_speaker_tab.title_color = UIStyle.GOLD
	_speaker_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.add_child(_speaker_tab)
	_speaker_label = _speaker_tab.get_title_label()

	var panel := SlantPanel.new()
	panel.padding = 22
	panel.slant_right = true
	panel.custom_minimum_size = Vector2(0, 150)
	frame.add_child(panel)
	_panel = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_text_label = UIStyle.make_label("", UIStyle.SIZE_L - 2, UIStyle.TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Explicit width so the autowrap height is measured at the real line length
	_text_label.custom_minimum_size = Vector2(1040, 0)
	_text_label.add_theme_constant_override("line_spacing", 4)
	vbox.add_child(_text_label)

	# Advance indicator: glyph + verb, bottom-right
	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_END
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint_row)
	_page_label = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_row.add_child(_page_label)
	_advance_hint = GlyphHint.create(&"ui_accept", "Continue", UIStyle.SIZE_S)
	hint_row.add_child(_advance_hint)
	_hint_label = _advance_hint.get_label()


func start_dialogue(pages: Array, allow_movement: bool = false) -> void:
	if pages.is_empty():
		return
	_pages.clear()
	for p in pages:
		_pages.append(p)
	_current_page = 0
	_allow_movement = allow_movement
	var was_active := _is_active
	_is_active = true
	_opened_frame = Engine.get_process_frames()
	_show_page()
	_show_dialogue()
	# Tell HUD listeners (control_bar, interaction_prompt) a dialogue is open.
	# Only on the closed -> open edge so restarts mid-dialogue don't double-emit.
	if not was_active and _is_active:
		Events.dialogue_started.emit()


func is_dialogue_active() -> bool:
	return _is_active


func _show_page() -> void:
	if _current_page >= _pages.size():
		_end_dialogue()
		return
	var page: Dictionary = _pages[_current_page]
	var speaker: String = page.get("speaker", "")
	_speaker_tab.title = speaker
	_speaker_tab.visible = speaker != ""
	_text_label.text = page.get("text", "")
	_page_label.text = "%d / %d" % [_current_page + 1, _pages.size()] if _pages.size() > 1 else ""
	_update_advance_hint()


func _advance() -> void:
	_current_page += 1
	_show_page()


func _end_dialogue() -> void:
	var was_active := _is_active
	_is_active = false
	_pages.clear()
	_hide_dialogue()
	if was_active:
		Events.dialogue_ended.emit()
	Events.interaction_cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Advance on ui_accept (joypad A / Enter / Space) or interact (E key).
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact"):
		# Swallow the opening press (same frame) and key-repeat echoes, but
		# still mark them handled so they don't leak into gameplay.
		if not event.is_echo() and Engine.get_process_frames() != _opened_frame:
			_advance()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _is_active:
		return
	# Update hint glyph if input device changes
	_update_advance_hint()


## Advance glyph: A (ui_accept) on controller, E (interact) on keyboard.
## Enter/Space also advance via ui_accept. Only touches the glyph when it changes.
func _update_advance_hint() -> void:
	var verb := "Continue" if _current_page < _pages.size() - 1 else "Close"
	var want: StringName = &"ui_accept" if InputManager.is_using_controller() else &"interact"
	if _advance_hint.action != want:
		_advance_hint.action = want
	if _advance_hint.text != verb:
		_advance_hint.text = verb


func _show_dialogue() -> void:
	var was_visible := _root.visible
	_root.visible = true
	if not was_visible:
		UIStyle.fade_slide_in(_frame, Vector2.DOWN, 0.16, 12.0)


func _hide_dialogue() -> void:
	_root.visible = false
