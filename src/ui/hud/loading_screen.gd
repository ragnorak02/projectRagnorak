## Simple loading/transition screen — fade to black and back.
## Used during zone transitions to hide scene swaps.
extends CanvasLayer

var _overlay: ColorRect
var _label: Label
var _is_fading: bool = false

signal fade_out_complete
signal fade_in_complete


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.02, 0.05, 1.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = "Loading..."
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_label)


func fade_out(duration: float = 0.3) -> void:
	if _is_fading:
		return
	_is_fading = true
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	tween.tween_callback(func():
		_is_fading = false
		fade_out_complete.emit()
	)


func fade_in(duration: float = 0.3) -> void:
	if _is_fading:
		return
	_is_fading = true
	_overlay.visible = true
	_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	tween.tween_callback(func():
		_is_fading = false
		_overlay.visible = false
		fade_in_complete.emit()
	)
