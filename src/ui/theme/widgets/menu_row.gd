## MenuRow — selectable slanted row (a Button, so focus/pressed/disabled work as usual).
## States: normal, selected (`selected = true` OR keyboard/controller focus) and
## greyed (`disabled` OR `unavailable`). `unavailable` rows stay selectable so a
## cursor can rest on them and show `unavailable_reason` on a description line.
## Optional right-side cost widgets: ATB pips (gold cells), MP cost (violet), text.
## The selected row gets a soft pulse on its accent bar (unscaled time).
class_name MenuRow
extends Button

signal selected_changed(is_selected: bool)

@export var selected: bool = false:
	set(v):
		if selected == v:
			return
		selected = v
		_refresh_state()
		selected_changed.emit(v)
## Greyed but still highlightable (e.g. not enough ATB/MP).
@export var unavailable: bool = false:
	set(v):
		unavailable = v
		_refresh_state()
@export var unavailable_reason: String = ""
## Free-form description for the description line (not drawn by the row).
@export var description: String = ""
## ATB cells this command costs (0 = none).
@export var atb_cost: int = 0:
	set(v):
		atb_cost = maxi(v, 0)
		_refresh_state()
## MP cost (-1 = none shown).
@export var mp_cost: int = -1:
	set(v):
		mp_cost = v
		_refresh_state()
## Extra right-aligned text (e.g. "x3", "72%").
@export var right_text: String = "":
	set(v):
		right_text = v
		_refresh_state()
@export var row_font_size: int = UIStyle.SIZE_M:
	set(v):
		row_font_size = v
		_refresh_state()

const PIP_W := 14.0
const PIP_H := 8.0
const PIP_GAP := 3.0
const RIGHT_PAD := 16.0

var _glow: float = 0.0
var _pulse_tween: Tween


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	custom_minimum_size.y = 40.0
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_lost)
	_refresh_state()


func _enter_tree() -> void:
	_refresh_state()


func _exit_tree() -> void:
	_stop_pulse()


func _on_focus_changed() -> void:
	# Focus is also lost while the tree is being torn down; skip restyling then.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_refresh_state()


func _on_focus_lost() -> void:
	# Deferred: focus is also dropped during app shutdown, when text shaping is unsafe.
	_on_focus_changed.call_deferred()


## Convenience: configure a command row in one call; returns self.
func setup(p_text: String, p_atb_cost: int = 0, p_mp_cost: int = -1, p_unavailable: bool = false, p_reason: String = "") -> MenuRow:
	text = p_text
	atb_cost = p_atb_cost
	mp_cost = p_mp_cost
	unavailable = p_unavailable
	unavailable_reason = p_reason
	return self


## True when drawn as selected (explicit `selected` or focused).
func is_highlighted() -> bool:
	return selected or has_focus()


func is_greyed() -> bool:
	return disabled or unavailable


func _right_width() -> float:
	var w := 0.0
	var f := UIStyle.font_body_bold()
	var fs := int(row_font_size * 0.8)
	if atb_cost > 0:
		w += atb_cost * PIP_W + (atb_cost - 1) * PIP_GAP + 10.0
	if mp_cost >= 0:
		w += f.get_string_size("%d MP" % mp_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
	if right_text != "":
		w += f.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
	return w


func _refresh_state() -> void:
	var hl := is_highlighted()
	var greyed := is_greyed()
	var state := "selected" if hl else ("disabled" if greyed else "normal")
	var sb := UIStyle.slant_row(state)
	if hl and greyed:
		sb.bg_color = Color(UIStyle.TEXT_DISABLED, 0.25)
		sb.border_color = UIStyle.TEXT_DIM
		sb.shadow_size = 0
	sb.content_margin_right += _right_width()
	for st in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		add_theme_stylebox_override(st, sb if st != &"focus" else StyleBoxEmpty.new())
	add_theme_font_override(&"font", UIStyle.font_body_bold() if hl else UIStyle.font_body())
	add_theme_font_size_override(&"font_size", row_font_size)
	var col := UIStyle.TEXT_DISABLED if greyed else (Color.WHITE if hl else UIStyle.TEXT)
	if hl and greyed:
		col = UIStyle.TEXT_DIM
	for c in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_disabled_color"]:
		add_theme_color_override(c, col)
	if hl:
		_start_pulse()
	else:
		_stop_pulse()
	queue_redraw()


func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = UIStyle.ui_tween(self)
	if _pulse_tween == null:
		_glow = 1.0
		return
	_pulse_tween.set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_method(_set_glow, 0.35, 1.0, 0.55)
	_pulse_tween.tween_method(_set_glow, 1.0, 0.35, 0.55)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_glow = 0.0


func _set_glow(v: float) -> void:
	_glow = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hl := is_highlighted()
	var greyed := is_greyed()
	if hl:
		# pulsing accent bar on the left edge
		var accent := UIStyle.TEXT_DIM if greyed else UIStyle.CYAN
		draw_rect(Rect2(2, 4, 3, r.size.y - 8), Color(accent, 0.5 + 0.5 * _glow))
		draw_rect(Rect2(0, 2, 7, r.size.y - 4), Color(accent, 0.15 * _glow))
	# right-side cost widgets, laid out right-to-left
	var x := r.size.x - RIGHT_PAD
	var f := UIStyle.font_body_bold()
	var fs := int(row_font_size * 0.8)
	var base_y := (r.size.y + f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	if right_text != "":
		var tw := f.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= tw
		draw_string(f, Vector2(x, base_y), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT_DISABLED if greyed else UIStyle.TEXT_DIM)
		x -= 10.0
	if mp_cost >= 0:
		var mt := "%d MP" % mp_cost
		var mw := f.get_string_size(mt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= mw
		draw_string(f, Vector2(x, base_y), mt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.TEXT_DISABLED if greyed else UIStyle.MP)
		x -= 10.0
	if atb_cost > 0:
		var py := (r.size.y - PIP_H) * 0.5
		for i in atb_cost:
			x -= PIP_W
			var pr := Rect2(x, py, PIP_W, PIP_H)
			draw_colored_polygon(UIStyle.slant_points(pr, 4.0, true, true), UIStyle.TEXT_DISABLED if greyed else UIStyle.ATB)
			x -= PIP_GAP
