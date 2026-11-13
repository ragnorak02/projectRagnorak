## Lock-on target indicator — "Lumina Frost" reticle over the locked-on target.
## A thin, slowly rotating cyan diamond with corner ticks and a centre dot, plus a
## small "LOCKED ON" label underneath ("TARGET" while tactical target-selecting).
## Drawn procedurally; rotation and tweens use unscaled time (tactical = 0.1x).
extends CanvasLayer

const RETICLE_SIZE := 56.0
const ROTATE_SPEED := 0.9  # radians per second (real time)

var _indicator: Control
var _reticle: Control
var _label: Label
var _target: Node3D = null
var _camera: Camera3D = null
var _tactical: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_indicator.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# _indicator is positioned so its origin sits on the target's screen point.
	_indicator = Control.new()
	_indicator.name = "LockOnIndicator"
	_indicator.size = Vector2.ZERO
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_indicator)

	_reticle = Control.new()
	_reticle.name = "Reticle"
	_reticle.size = Vector2(RETICLE_SIZE, RETICLE_SIZE)
	_reticle.position = -_reticle.size * 0.5
	_reticle.pivot_offset = _reticle.size * 0.5
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	_indicator.add_child(_reticle)

	_label = UIStyle.make_label("LOCKED ON", 13, UIStyle.CYAN, true)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", UIStyle.SHADOW)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(120, 18)
	_label.position = Vector2(-60, RETICLE_SIZE * 0.5 + 6)
	_indicator.add_child(_label)


## Diamond outline + inner diamond + centre dot, in the reticle's local space.
func _draw_reticle() -> void:
	var c := _reticle.size * 0.5
	var r := RETICLE_SIZE * 0.42
	var t := float(Time.get_ticks_msec()) / 1000.0
	var a := t * ROTATE_SPEED
	var outer := PackedVector2Array()
	for i in 4:
		var ang := a + i * PI * 0.5
		outer.append(c + Vector2(cos(ang), sin(ang)) * r)
	# Broken diamond: draw each edge as two segments with a gap in the middle.
	for i in 4:
		var p0 := outer[i]
		var p1 := outer[(i + 1) % 4]
		var mid := p0.lerp(p1, 0.5)
		_reticle.draw_line(p0, p0.lerp(mid, 0.72), Color(UIStyle.CYAN, 0.25), 5.0, true)
		_reticle.draw_line(p1, p1.lerp(mid, 0.72), Color(UIStyle.CYAN, 0.25), 5.0, true)
		_reticle.draw_line(p0, p0.lerp(mid, 0.72), UIStyle.CYAN, 1.6, true)
		_reticle.draw_line(p1, p1.lerp(mid, 0.72), UIStyle.CYAN, 1.6, true)
	# Counter-rotating inner diamond
	var inner := PackedVector2Array()
	var ri := r * 0.38
	for i in 5:
		var ang2 := -a * 0.6 + PI * 0.25 + i * PI * 0.5
		inner.append(c + Vector2(cos(ang2), sin(ang2)) * ri)
	_reticle.draw_polyline(inner, Color(UIStyle.TEXT, 0.85), 1.2, true)
	_reticle.draw_circle(c, 2.2, UIStyle.CYAN)


func _connect_signals() -> void:
	Events.lock_on_target_acquired.connect(_on_target_acquired)
	Events.lock_on_target_switched.connect(_on_target_switched)
	Events.lock_on_target_lost.connect(_on_target_lost)
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)
	Events.tactical_target_reach.connect(_on_target_reach)
	Events.lock_on_target_lost.connect(_clear_reach)
	Events.tactical_mode_exited.connect(_clear_reach)


var _pulse_tween: Tween = null


func _on_target_acquired(target: Node3D) -> void:
	_target = target
	_indicator.visible = true

	# Scale pulse on acquire (unscaled so it is not slowed by tactical mode)
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	_reticle.scale = Vector2(1.5, 1.5)
	_pulse_tween = create_tween().set_ignore_time_scale(true)
	_pulse_tween.tween_property(_reticle, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_target_switched(new_target: Node3D) -> void:
	_target = new_target
	# Pulse on switch for clear feedback
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	_reticle.scale = Vector2(1.3, 1.3)
	_pulse_tween = create_tween().set_ignore_time_scale(true)
	_pulse_tween.tween_property(_reticle, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_target_lost() -> void:
	_target = null
	_indicator.visible = false


func _on_tactical_entered() -> void:
	_tactical = true
	_label.text = "TARGET"
	_label.add_theme_color_override("font_color", UIStyle.GOLD)


func _on_tactical_exited() -> void:
	_tactical = false
	_label.text = "LOCKED ON"
	_label.add_theme_color_override("font_color", UIStyle.CYAN)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_indicator.visible = false
		return

	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return

	# Get lock-on point (elevated above enemy center)
	var world_pos: Vector3 = _target.global_position + Vector3(0, 1.2, 0)
	if _target.has_node("LockOnPoint"):
		world_pos = _target.get_node("LockOnPoint").global_position

	# Check if target is in front of camera
	if not _camera.is_position_behind(world_pos):
		var screen_pos: Vector2 = _camera.unproject_position(world_pos)
		_indicator.position = screen_pos
		_indicator.visible = true
		_reticle.queue_redraw()
	else:
		_indicator.visible = false


# --- v5: out-of-range dimming (Events.tactical_target_reach) -------------------

const OUT_OF_RANGE_TINT := Color(UIStyle.TEXT_DISABLED, 0.55)
var _out_of_range: bool = false


func _on_target_reach(target: Node3D, in_range: bool) -> void:
	_set_out_of_range(not in_range and target != null and target == _target)


func _clear_reach(_a = null) -> void:
	_set_out_of_range(false)


## True while the shown target is dimmed as out of range.
func is_out_of_range() -> bool:
	return _out_of_range


func _set_out_of_range(dim: bool) -> void:
	_out_of_range = dim
	_indicator.modulate = OUT_OF_RANGE_TINT if dim else Color.WHITE
	if dim:
		_label.text = "OUT OF RANGE"
		_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	elif _tactical:
		_label.text = "TARGET"
		_label.add_theme_color_override("font_color", UIStyle.GOLD)
	else:
		_label.text = "LOCKED ON"
		_label.add_theme_color_override("font_color", UIStyle.CYAN)
