## Brief on-screen feedback for save/load events (quicksave, blocked, etc.).
## Lumina Frost toast: a small glass pill that slides in at the top-right with a
## coloured status dot (cyan = info/success, red = blocked/failed), holds, then
## fades out. Runs in unscaled time and while paused.
extends CanvasLayer

const HOLD_TIME := 1.5
const FADE_TIME := 0.5
const NEGATIVE_WORDS: Array[String] = ["cannot", "can't", "blocked", "fail", "error", "unavailable", "no save", "disabled", "not "]

var _toast: PanelContainer
var _dot: Panel
var _label: Label
var _tween: Tween = null
var _serial: int = 0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Events.save_feedback.connect(_show_feedback)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_toast = PanelContainer.new()
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.0
	_toast.anchor_bottom = 0.0
	_toast.offset_left = -24.0
	_toast.offset_right = -24.0
	_toast.offset_top = 28.0
	_toast.offset_bottom = 28.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.grow_vertical = Control.GROW_DIRECTION_END
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.GLASS, UIStyle.CYAN_DIM, 16.0, 8.0))
	_toast.visible = false
	root.add_child(_toast)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(row)

	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(10, 10)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_dot)
	_set_dot_color(UIStyle.CYAN)

	_label = UIStyle.make_label("", UIStyle.SIZE_S + 2, UIStyle.TEXT)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)


func _set_dot_color(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(5)
	sb.shadow_color = Color(color, 0.5)
	sb.shadow_size = 4
	sb.anti_aliasing = true
	_dot.add_theme_stylebox_override("panel", sb)


func _is_negative(message: String) -> bool:
	var m := message.to_lower()
	for w in NEGATIVE_WORDS:
		if m.contains(w):
			return true
	return false


func _show_feedback(message: String) -> void:
	_label.text = message
	_set_dot_color(UIStyle.DANGER if _is_negative(message) else UIStyle.CYAN)
	if _tween and _tween.is_valid():
		_tween.kill()
	_serial += 1
	var serial := _serial
	if not _toast.visible:
		_toast.modulate.a = 0.0
	_toast.visible = true
	if not is_inside_tree():
		_toast.modulate.a = 1.0
		return
	# Wait one frame so the pill's minimum size matches the new text, then
	# re-anchor it to the top-right corner and slide it in from the right.
	await get_tree().process_frame
	if serial != _serial:
		return
	if _toast.has_meta(&"_ui_home"):
		_toast.remove_meta(&"_ui_home")
	_toast.offset_left = -24.0
	_toast.offset_right = -24.0
	_toast.offset_top = 28.0
	_toast.offset_bottom = 28.0
	UIStyle.fade_slide_in(_toast, Vector2.RIGHT, 0.16, 16.0)

	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_callback(func() -> void: UIStyle.fade_out(_toast, FADE_TIME))
