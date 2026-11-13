## Loading/transition screen — fade to "Lumina Frost" dark and back.
## Used during zone transitions to hide scene swaps. Shows a "LOADING" header
## with a thin cyan light-line and an indeterminate progress sweep. All motion
## runs in unscaled time and while paused.
extends CanvasLayer

const BG_COLOR := Color(0.016, 0.031, 0.05, 1.0)
const LINE_WIDTH := 280.0
const SWEEP_WIDTH := 70.0
const SWEEP_PERIOD := 1.1   # seconds per sweep (real time)

var _overlay: ColorRect
var _label: Label
var _track: ColorRect
var _sweep: ColorRect
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
	_overlay.color = BG_COLOR
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Centre block: header + thin progress line, slightly below centre.
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override(&"separation", 10)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_label = UIStyle.make_label("Loading...", UIStyle.SIZE_M, UIStyle.CYAN, true)
	_label.uppercase = true
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_constant_override(&"outline_size", 0)
	center.add_child(_label)

	_track = ColorRect.new()
	_track.custom_minimum_size = Vector2(LINE_WIDTH, 2)
	_track.color = UIStyle.CYAN_DIM
	_track.clip_contents = true
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_track)

	_sweep = ColorRect.new()
	_sweep.color = UIStyle.CYAN
	_sweep.size = Vector2(SWEEP_WIDTH, 2)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(_sweep)


func _process(_delta: float) -> void:
	if not _overlay.visible:
		return
	# Indeterminate sweep driven by real time (ignores Engine.time_scale).
	var t := fmod(Time.get_ticks_msec() / 1000.0, SWEEP_PERIOD) / SWEEP_PERIOD
	_sweep.position.x = lerpf(-SWEEP_WIDTH, LINE_WIDTH, t)


func fade_out(duration: float = 0.3) -> void:
	if _is_fading:
		return
	_is_fading = true
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
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
	tween.set_ignore_time_scale(true)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	tween.tween_callback(func():
		_is_fading = false
		_overlay.visible = false
		fade_in_complete.emit()
	)
