## Bottom-screen control bar showing available inputs with active highlighting.
## Builds UI programmatically — no .tscn needed.
extends CanvasLayer

# Control definition: { action: StringName, name: String, kb: String, pad: String }
const CONTROLS: Array[Dictionary] = [
	{ "action": &"move_up", "name": "MOVE", "kb": "WASD", "pad": "LS" },
	{ "action": &"jump", "name": "JUMP", "kb": "Space", "pad": "A" },
	{ "action": &"attack", "name": "ATTACK", "kb": "LMB", "pad": "X" },
	{ "action": &"dodge", "name": "DODGE", "kb": "Shift", "pad": "B" },
	{ "action": &"lock_on", "name": "LOCK-ON", "kb": "MMB", "pad": "RT" },
	{ "action": &"tactical_mode", "name": "TACTICAL", "kb": "Q", "pad": "LT" },
	{ "action": &"interact", "name": "INTERACT", "kb": "E", "pad": "Y" },
	{ "action": &"pause", "name": "PAUSE", "kb": "Esc", "pad": "Start" },
]

# Movement sub-actions checked when highlighting the MOVE entry.
const MOVE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
]

# Colors
const COLOR_INACTIVE: Color = Color(0.7, 0.7, 0.7)
const COLOR_ACTIVE: Color = Color(1.0, 0.8, 0.2)
const COLOR_BG: Color = Color(0.05, 0.05, 0.1, 0.85)

# References to the name labels so _process can recolor them.
var _name_labels: Array[Label] = []
# Parallel array of keybind labels for consistent styling.
var _bind_labels: Array[Label] = []


func _ready() -> void:
	layer = 11
	_build_ui()


func _build_ui() -> void:
	# Root control — full-rect, ignores mouse.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# PanelContainer anchored to the bottom of the screen.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.custom_minimum_size = Vector2(0, 50)
	panel.offset_top = -50
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark semi-transparent background.
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BG
	panel.add_theme_stylebox_override("panel", bg_style)
	root.add_child(panel)

	# HBoxContainer that holds every control item.
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	for ctrl: Dictionary in CONTROLS:
		var item := _create_control_item(ctrl)
		hbox.add_child(item)


func _create_control_item(ctrl: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_stretch_ratio = 1.0
	vbox.add_theme_constant_override("separation", 1)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Action name label (e.g. "ATTACK").
	var name_label := Label.new()
	name_label.text = ctrl["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COLOR_INACTIVE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Keybind label (e.g. "[LMB/X]").
	var bind_label := Label.new()
	bind_label.text = "[%s/%s]" % [ctrl["kb"], ctrl["pad"]]
	bind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bind_label.add_theme_font_size_override("font_size", 11)
	bind_label.add_theme_color_override("font_color", COLOR_INACTIVE)
	bind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bind_label)

	_name_labels.append(name_label)
	_bind_labels.append(bind_label)

	return vbox


func _process(_delta: float) -> void:
	for i in CONTROLS.size():
		var ctrl: Dictionary = CONTROLS[i]
		var pressed := _is_control_active(ctrl)
		var color := COLOR_ACTIVE if pressed else COLOR_INACTIVE
		_name_labels[i].add_theme_color_override("font_color", color)
		_bind_labels[i].add_theme_color_override("font_color", color)


func _is_control_active(ctrl: Dictionary) -> bool:
	# MOVE is special — any directional input counts.
	if ctrl["name"] == "MOVE":
		for action: StringName in MOVE_ACTIONS:
			if Input.is_action_pressed(action):
				return true
		return false
	return Input.is_action_pressed(ctrl["action"])
