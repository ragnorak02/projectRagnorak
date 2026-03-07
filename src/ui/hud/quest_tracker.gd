## Quest tracker placeholder HUD element.
## Displays current quest objective text in the top-right corner.
## Will be connected to the QuestSystem once Phase 10 is implemented.
extends CanvasLayer

const BG_COLOR := Color(0.02, 0.04, 0.12, 0.7)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.3)
const HEADER_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.8, 0.85, 0.95)
const DIM_COLOR := Color(0.4, 0.45, 0.55)

var _root: Control
var _panel: PanelContainer
var _header_label: Label
var _objective_label: Label
var _no_quest_label: Label


func _ready() -> void:
	layer = 9
	_build_ui()
	_connect_signals()
	_show_placeholder()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-280, 20)
	_panel.custom_minimum_size = Vector2(260, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.border_color = BORDER_COLOR
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_header_label = Label.new()
	_header_label.text = "QUEST"
	_header_label.add_theme_font_size_override("font_size", 12)
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_header_label)

	_objective_label = Label.new()
	_objective_label.text = ""
	_objective_label.add_theme_font_size_override("font_size", 14)
	_objective_label.add_theme_color_override("font_color", TEXT_COLOR)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_objective_label)

	_no_quest_label = Label.new()
	_no_quest_label.text = "No active quest"
	_no_quest_label.add_theme_font_size_override("font_size", 13)
	_no_quest_label.add_theme_color_override("font_color", DIM_COLOR)
	_no_quest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_no_quest_label)


func _connect_signals() -> void:
	if Events.has_signal(&"quest_objective_updated"):
		Events.quest_objective_updated.connect(_on_objective_updated)
	if Events.has_signal(&"quest_completed"):
		Events.quest_completed.connect(_on_quest_completed)


func _show_placeholder() -> void:
	_objective_label.visible = false
	_no_quest_label.visible = true


func set_quest(quest_name: String, objective_text: String) -> void:
	_header_label.text = quest_name
	_objective_label.text = objective_text
	_objective_label.visible = true
	_no_quest_label.visible = false


func clear_quest() -> void:
	_header_label.text = "QUEST"
	_show_placeholder()


func _on_objective_updated(quest_id: StringName, _objective_index: int) -> void:
	_header_label.text = String(quest_id)


func _on_quest_completed(_quest_id: StringName) -> void:
	clear_quest()
