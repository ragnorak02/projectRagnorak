## Gauge — smooth bar with a lagging "damage chip" trail.
## Set `value`/`max_value` (or call set_values). When the value drops, the fill snaps
## down and a light chip segment drains after `chip_delay`. When it rises, the fill
## grows smoothly. Animation uses real (unscaled) time, so it is unaffected by
## tactical slow-time. Headless-safe (pure Control drawing).
class_name Gauge
extends Control

signal low_state_changed(is_low: bool)

@export var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 0.0001)
		_on_target_changed(false)
@export var value: float = 100.0:
	set(v):
		var old := value
		value = v
		_on_target_changed(v < old)
@export var fill_color: Color = UIStyle.HP_START:
	set(v):
		fill_color = v
		queue_redraw()
## End colour of the horizontal fill gradient (set equal to fill_color for flat).
@export var fill_color_end: Color = UIStyle.HP_END:
	set(v):
		fill_color_end = v
		queue_redraw()
@export var back_color: Color = UIStyle.GAUGE_BACK
@export var chip_color: Color = UIStyle.CHIP
## Ratio at/below which the gauge is "low" (fill + edge turn low_color). 0 disables.
@export var low_threshold: float = 0.0:
	set(v):
		low_threshold = v
		_check_low()
		queue_redraw()
@export var low_color: Color = UIStyle.DANGER
@export var slant: float = 6.0
@export var show_label: bool = false:
	set(v):
		show_label = v
		queue_redraw()
## Format for the label: receives [value, max] as ints.
@export var label_format: String = "%d / %d"
@export var label_size: int = UIStyle.SIZE_S
@export var chip_delay: float = 0.35
@export var chip_drain_speed: float = 0.8   # ratio per second
@export var fill_speed: float = 2.5         # ratio per second when increasing

var _display: float = 1.0     # displayed fill ratio
var _chip: float = 1.0        # chip trail ratio
var _chip_wait: float = 0.0
var _last_us: int = 0
var _is_low: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(160, 12)
	set_process(false)


func _ready() -> void:
	snap()


## Convenience: set both value and max. instant=true skips animation.
func set_values(new_value: float, new_max: float, instant: bool = false) -> void:
	max_value = new_max
	value = new_value
	if instant:
		snap()


## Jump the display straight to the current value (no chip, no animation).
func snap() -> void:
	_display = get_target_ratio()
	_chip = _display
	_chip_wait = 0.0
	set_process(false)
	_check_low()
	queue_redraw()


func get_target_ratio() -> float:
	return clampf(value / max_value, 0.0, 1.0)


## Currently displayed (animated) fill ratio.
func get_display_ratio() -> float:
	return _display


func is_low() -> bool:
	return _is_low


func _on_target_changed(dropped: bool) -> void:
	var target := get_target_ratio()
	if dropped or target < _display:
		# fill snaps down, chip holds then drains
		_chip = maxf(_chip, _display)
		_display = target
		_chip_wait = chip_delay
	_check_low()
	_last_us = Time.get_ticks_usec()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	var target := get_target_ratio()
	var done := true
	if _display < target:
		_display = minf(target, _display + fill_speed * dt)
		done = done and is_equal_approx(_display, target)
	if _chip > _display:
		if _chip_wait > 0.0:
			_chip_wait -= dt
		else:
			_chip = maxf(_display, _chip - chip_drain_speed * dt)
		done = done and _chip <= _display + 0.0001
	else:
		_chip = _display
	queue_redraw()
	if done:
		set_process(false)


func _check_low() -> void:
	var low := low_threshold > 0.0 and get_target_ratio() <= low_threshold
	if low != _is_low:
		_is_low = low
		low_state_changed.emit(low)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 1.0:
		return
	var s := minf(slant, r.size.y)
	draw_colored_polygon(UIStyle.slant_points(r, s, true, true), back_color)
	var inner := r.grow(-1.0)
	var w := inner.size.x
	if _chip > _display:
		var chip_rect := Rect2(inner.position + Vector2(w * _display, 0), Vector2(w * (_chip - _display), inner.size.y))
		draw_colored_polygon(UIStyle.slant_points(chip_rect, s, false, true), chip_color)
	if _display > 0.0:
		var fr := Rect2(inner.position, Vector2(w * _display, inner.size.y))
		var c0 := low_color if _is_low else fill_color
		var c1 := low_color.lightened(0.15) if _is_low else fill_color_end
		var pts := UIStyle.slant_points(fr, s, true, true)
		draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
		# top sheen + bright leading edge
		draw_line(pts[0], pts[1], Color(1, 1, 1, 0.25), 1.0)
		var edge := low_color if _is_low else c1.lightened(0.4)
		draw_line(pts[1], pts[2], edge, 2.0, true)
	if show_label:
		var font := UIStyle.font_body_bold()
		var txt := label_format % [int(round(value)), int(round(max_value))] if label_format.count("%") >= 2 else label_format % int(round(value))
		var asc := font.get_ascent(label_size)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var pos := Vector2(r.size.x - tw - s - 4.0, (r.size.y + asc) * 0.5 - 2.0)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 4, UIStyle.SHADOW)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, low_color if _is_low else UIStyle.TEXT)
