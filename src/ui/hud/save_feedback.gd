## Brief on-screen feedback for save/load events (quicksave, blocked, etc.).
extends CanvasLayer

var _label: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Events.save_feedback.connect(_show_feedback)


func _build_ui() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_left = -300
	_label.offset_top = -60
	_label.offset_right = -20
	_label.offset_bottom = -20
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_label.visible = false
	add_child(_label)


func _show_feedback(message: String) -> void:
	_label.text = message
	_label.visible = true
	_label.modulate.a = 1.0

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_interval(1.5)
	tween.tween_property(_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _label.visible = false)
