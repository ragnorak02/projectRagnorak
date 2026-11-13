## SlantPanel — Lumina Frost glass container with an angled edge.
## A PanelContainer: add children normally; content margins account for the slant.
## Draws: vertical-gradient glass fill, cyan top light-line, optional selected glow.
class_name SlantPanel
extends PanelContainer

@export var slant: float = UIStyle.SLANT:
	set(v):
		slant = maxf(v, 0.0)
		_update_margins()
		queue_redraw()
@export var slant_left: bool = true:
	set(v):
		slant_left = v
		_update_margins()
		queue_redraw()
@export var slant_right: bool = false:
	set(v):
		slant_right = v
		_update_margins()
		queue_redraw()
@export var padding: float = 12.0:
	set(v):
		padding = v
		_update_margins()
@export var fill_color: Color = UIStyle.GLASS:
	set(v):
		fill_color = v
		queue_redraw()
@export var fill_bottom_color: Color = UIStyle.GLASS_DEEP:
	set(v):
		fill_bottom_color = v
		queue_redraw()
@export var line_color: Color = UIStyle.CYAN:
	set(v):
		line_color = v
		queue_redraw()
@export var show_top_line: bool = true:
	set(v):
		show_top_line = v
		queue_redraw()
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
@export var glow_color: Color = UIStyle.CYAN_GLOW:
	set(v):
		glow_color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_margins()


func _update_margins() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = padding + (slant if slant_left else 0.0)
	sb.content_margin_right = padding + (slant if slant_right else 0.0)
	sb.content_margin_top = padding * 0.75
	sb.content_margin_bottom = padding * 0.75
	add_theme_stylebox_override(&"panel", sb)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var pts := UIStyle.slant_points(rect, slant, slant_left, slant_right)
	var top := fill_color
	var bottom := fill_bottom_color
	if selected:
		top = UIStyle.GLASS_LIGHT
	var cols := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(pts, cols)
	if selected:
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(glow_color, glow_color.a * 0.35), 5.0, true)
		draw_polyline(outline, glow_color, 1.5, true)
	if show_top_line:
		draw_line(pts[0], pts[1], line_color, 2.0, true)
		# faint secondary line for a frosted edge
		draw_line(pts[0] + Vector2(0, 3), pts[1] + Vector2(0, 3), Color(line_color, 0.12), 1.0, true)
