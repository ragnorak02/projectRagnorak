## SegmentGauge — N slanted cells with partial fill (ATB: 2 cells x 50).
## `value` ranges 0..(segments * per_segment). Full cells glow brighter.
## Smooths toward the target using real (unscaled) time. Headless-safe.
class_name SegmentGauge
extends Control

signal segment_filled(index: int)

@export var segments: int = 2:
	set(v):
		segments = maxi(v, 1)
		queue_redraw()
@export var per_segment: float = 50.0:
	set(v):
		per_segment = maxf(v, 0.0001)
		queue_redraw()
@export var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, get_max_value())
		_last_us = Time.get_ticks_usec()
		set_process(true)
@export var fill_color: Color = UIStyle.ATB
@export var full_color: Color = UIStyle.ATB_FULL
@export var back_color: Color = UIStyle.GAUGE_BACK
@export var gap: float = 4.0
@export var slant: float = 6.0
@export var smooth_speed: float = 120.0   # value units per second

var _display: float = 0.0
var _last_us: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(120, 8)
	set_process(false)


func get_max_value() -> float:
	return segments * per_segment


## Set the value; instant=true skips smoothing.
func set_value(v: float, instant: bool = false) -> void:
	value = v
	if instant:
		snap()


func snap() -> void:
	_display = value
	set_process(false)
	queue_redraw()


## Number of completely filled cells (e.g. ATB charges available).
func get_full_segments() -> int:
	return int(floor(value / per_segment + 0.0001))


func get_display_value() -> float:
	return _display


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now
	var before := int(floor(_display / per_segment + 0.0001))
	_display = move_toward(_display, value, smooth_speed * dt)
	var after := int(floor(_display / per_segment + 0.0001))
	if after > before:
		for i in range(before, after):
			segment_filled.emit(i)
	queue_redraw()
	if is_equal_approx(_display, value):
		_display = value
		set_process(false)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 4.0 or r.size.y < 1.0:
		return
	var n := segments
	var cell_w := (r.size.x - gap * (n - 1)) / n
	var s := minf(slant, r.size.y)
	for i in n:
		var cr := Rect2(Vector2(i * (cell_w + gap), 0), Vector2(cell_w, r.size.y))
		draw_colored_polygon(UIStyle.slant_points(cr, s, true, true), back_color)
		var frac := clampf((_display - i * per_segment) / per_segment, 0.0, 1.0)
		if frac <= 0.0:
			continue
		var fr := Rect2(cr.position, Vector2(cell_w * frac, cr.size.y)).grow(-1.0)
		if fr.size.x <= 0.0:
			continue
		var full := frac >= 1.0
		var col := full_color if full else Color(fill_color, 0.8)
		draw_colored_polygon(UIStyle.slant_points(fr, s, true, true), col)
		if full:
			var outline := UIStyle.slant_points(cr, s, true, true)
			outline.append(outline[0])
			draw_polyline(outline, Color(full_color, 0.45), 2.0, true)
