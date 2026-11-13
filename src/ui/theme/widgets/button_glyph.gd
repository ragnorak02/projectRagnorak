## ButtonGlyph — procedural input glyph for an action on the active device.
## Reads SettingsManager.get_action_label(action, controller) and redraws on
## InputManager.device_changed and SettingsManager.settings_changed.
##  - Controller A/B/X/Y: coloured round badges.
##  - LB/RB/LT/RT/View/Start/L3/R3/LS/RS: pills ("View" = joy 4, Xbox naming).  D-pad: a small cross with the
##    pressed direction lit.
##  - Keyboard/mouse: key-cap boxes.
## Multi-binding labels ("D-Up/D-Down") draw up to `max_parts` glyphs side by side.
## Headless-safe: works without a renderer and without the autoloads.
class_name ButtonGlyph
extends Control

enum Device { AUTO, KEYBOARD, CONTROLLER }

signal glyph_changed(label: String)

@export var action: StringName = &"":
	set(v):
		action = v
		refresh()
## AUTO follows InputManager; KEYBOARD/CONTROLLER force one family.
@export var device: Device = Device.AUTO:
	set(v):
		device = v
		refresh()
## If non-empty, shown instead of the action lookup (e.g. "A", "LB", "Esc").
@export var label_override: String = "":
	set(v):
		label_override = v
		refresh()
@export var glyph_height: float = 26.0:
	set(v):
		glyph_height = maxf(v, 8.0)
		refresh()
@export var max_parts: int = 2:
	set(v):
		max_parts = maxi(v, 1)
		refresh()

const _FACE := ["A", "B", "X", "Y"]
const _PART_GAP := 3.0

var _label: String = "---"
var _parts: PackedStringArray = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	var im := _autoload(&"InputManager")
	if im and im.has_signal(&"device_changed") and not im.device_changed.is_connected(_on_device_changed):
		im.device_changed.connect(_on_device_changed)
	var sm := _autoload(&"SettingsManager")
	if sm and sm.has_signal(&"settings_changed") and not sm.settings_changed.is_connected(refresh):
		sm.settings_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	var im := _autoload(&"InputManager")
	if im and im.device_changed.is_connected(_on_device_changed):
		im.device_changed.disconnect(_on_device_changed)
	var sm := _autoload(&"SettingsManager")
	if sm and sm.settings_changed.is_connected(refresh):
		sm.settings_changed.disconnect(refresh)


## Convenience setup; returns self for chaining.
func setup(p_action: StringName, p_device: Device = Device.AUTO) -> ButtonGlyph:
	device = p_device
	action = p_action
	return self


## The current binding label (e.g. "A", "RT", "E", "D-Up/D-Down", "---").
func get_label() -> String:
	return _label


## True when the controller glyph set is being shown.
func is_controller() -> bool:
	match device:
		Device.CONTROLLER:
			return true
		Device.KEYBOARD:
			return false
	var im := _autoload(&"InputManager")
	if im and im.has_method(&"is_using_controller"):
		return im.is_using_controller()
	return false


## Re-read the binding and redraw. Called automatically on device/binding change.
func refresh() -> void:
	var lbl := label_override if label_override != "" else ButtonGlyph.label_for(action, is_controller())
	var changed := lbl != _label
	_label = lbl
	_parts = PackedStringArray()
	var raw := lbl.split("/", false)
	for p in raw:
		var part := p.strip_edges()
		# keypad duplicates ("Kp Enter") add noise next to the main key
		if part.begins_with("Kp ") and raw.size() > 1:
			continue
		if _parts.size() >= max_parts:
			break
		_parts.append(part)
	if _parts.is_empty():
		_parts.append("---")
	update_minimum_size()
	queue_redraw()
	if changed:
		glyph_changed.emit(_label)


## Static lookup used by refresh(); safe without autoloads (returns "---").
static func label_for(p_action: StringName, controller: bool) -> String:
	if p_action == &"":
		return "---"
	var sm := _autoload(&"SettingsManager")
	if sm and sm.has_method(&"get_action_label"):
		return sm.get_action_label(p_action, controller)
	return "---"


static func _autoload(autoload_name: StringName) -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree and ml.root:
		return ml.root.get_node_or_null(NodePath(String(autoload_name)))
	return null


func _on_device_changed(_d) -> void:
	refresh()


# --- Layout / drawing --------------------------------------------------------

func _get_minimum_size() -> Vector2:
	var w := 0.0
	for i in _parts.size():
		w += _part_width(_parts[i])
		if i > 0:
			w += _PART_GAP
	return Vector2(w, glyph_height)


func _font_size() -> int:
	return int(glyph_height * 0.58)


func _kind(part: String) -> String:
	if _FACE.has(part):
		return "face"
	if part.begins_with("D-"):
		return "dpad"
	if part in ["LB", "RB", "LT", "RT", "View", "Back", "Start", "Guide", "L3", "R3", "LS", "RS"]:
		return "pill"
	return "key"


func _part_width(part: String) -> float:
	var h := glyph_height
	match _kind(part):
		"face", "dpad":
			return h
		_:
			var f := UIStyle.font_header()
			var tw := f.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x
			return maxf(h, tw + h * 0.6)


func _draw() -> void:
	var x := 0.0
	# vertically centre if the control is taller than the glyph
	var y := maxf(0.0, (size.y - glyph_height) * 0.5)
	for part in _parts:
		var w := _part_width(part)
		_draw_part(part, Rect2(x, y, w, glyph_height))
		x += w + _PART_GAP


func _draw_part(part: String, r: Rect2) -> void:
	var h := r.size.y
	var c := r.get_center()
	match _kind(part):
		"face":
			var col: Color = {"A": UIStyle.GLYPH_A, "B": UIStyle.GLYPH_B, "X": UIStyle.GLYPH_X, "Y": UIStyle.GLYPH_Y}[part]
			draw_circle(c, h * 0.5, Color(0, 0, 0, 0.45))
			draw_circle(c, h * 0.5 - 1.0, col.darkened(0.35))
			draw_circle(c, h * 0.5 - 3.0, col)
			_draw_text_centered(part, c, Color(0.04, 0.06, 0.08), _font_size())
		"pill":
			_draw_round_box(r, h * 0.5, UIStyle.GLYPH_PILL, Color(UIStyle.TEXT_DIM, 0.8))
			_draw_text_centered(part, c, UIStyle.TEXT, int(_font_size() * 0.85))
		"dpad":
			_draw_dpad(part, r)
		_:
			# key-cap: body + darker base lip
			var base := Rect2(r.position, r.size)
			_draw_round_box(base, 4.0, UIStyle.KEYCAP_EDGE.darkened(0.5), Color(0, 0, 0, 0))
			var top := Rect2(r.position, Vector2(r.size.x, r.size.y - 3.0))
			_draw_round_box(top, 4.0, UIStyle.KEYCAP_FILL, UIStyle.KEYCAP_EDGE)
			_draw_text_centered(part, top.get_center(), UIStyle.TEXT, int(_font_size() * (0.85 if part.length() > 2 else 1.0)))


func _draw_round_box(r: Rect2, radius: float, fill: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	draw_style_box(sb, r)


func _draw_dpad(part: String, r: Rect2) -> void:
	var c := r.get_center()
	var arm := r.size.y * 0.30
	var arm_len := r.size.y * 0.5 - 1.0
	var dim := UIStyle.GLYPH_PILL.lightened(0.15)
	var lit := UIStyle.TEXT
	var dir := part.substr(2)
	var rects := {
		"Up": Rect2(c.x - arm * 0.5, c.y - arm_len, arm, arm_len),
		"Down": Rect2(c.x - arm * 0.5, c.y, arm, arm_len),
		"Left": Rect2(c.x - arm_len, c.y - arm * 0.5, arm_len, arm),
		"Right": Rect2(c.x, c.y - arm * 0.5, arm_len, arm),
	}
	for k in rects:
		draw_rect(rects[k], dim)
	draw_rect(Rect2(c.x - arm * 0.5, c.y - arm * 0.5, arm, arm), dim)
	if rects.has(dir):
		draw_rect(rects[dir], lit)


func _draw_text_centered(text: String, center: Vector2, color: Color, font_size: int) -> void:
	var f := UIStyle.font_header()
	var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var asc := f.get_ascent(font_size)
	var desc := f.get_descent(font_size)
	var pos := Vector2(center.x - ts.x * 0.5, center.y + (asc - desc) * 0.5)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
