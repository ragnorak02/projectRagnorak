## Lock-on target indicator. Shows a reticle over the locked-on enemy.
## Builds a simple diamond/crosshair shape programmatically.
extends CanvasLayer

var _indicator: Control
var _target: Node3D = null
var _camera: Camera3D = null


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

	_indicator = Control.new()
	_indicator.custom_minimum_size = Vector2(48, 48)
	_indicator.size = Vector2(48, 48)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_indicator)

	# Build diamond reticle from 4 small rectangles
	var arm_length: float = 18.0
	var arm_thickness: float = 2.0
	var gap: float = 8.0
	var center := Vector2(24, 24)

	# Top arm
	_add_arm(center + Vector2(-arm_thickness / 2, -gap - arm_length),
		Vector2(arm_thickness, arm_length))
	# Bottom arm
	_add_arm(center + Vector2(-arm_thickness / 2, gap),
		Vector2(arm_thickness, arm_length))
	# Left arm
	_add_arm(center + Vector2(-gap - arm_length, -arm_thickness / 2),
		Vector2(arm_length, arm_thickness))
	# Right arm
	_add_arm(center + Vector2(gap, -arm_thickness / 2),
		Vector2(arm_length, arm_thickness))

	# Small diamond in center
	var diamond := ColorRect.new()
	diamond.color = Color(1.0, 0.85, 0.3, 0.9)
	diamond.size = Vector2(4, 4)
	diamond.position = center - Vector2(2, 2)
	diamond.rotation = deg_to_rad(45)
	diamond.pivot_offset = Vector2(2, 2)
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.add_child(diamond)


func _add_arm(pos: Vector2, arm_size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = Color(1.0, 0.85, 0.3, 0.8)
	rect.position = pos
	rect.size = arm_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.add_child(rect)


func _connect_signals() -> void:
	Events.lock_on_target_acquired.connect(_on_target_acquired)
	Events.lock_on_target_switched.connect(_on_target_switched)
	Events.lock_on_target_lost.connect(_on_target_lost)


var _pulse_tween: Tween = null


func _on_target_acquired(target: Node3D) -> void:
	_target = target
	_indicator.visible = true

	# Scale pulse on acquire
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	_indicator.scale = Vector2(1.5, 1.5)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_indicator, "scale", Vector2.ONE, 0.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_target_switched(new_target: Node3D) -> void:
	_target = new_target
	# Pulse on switch for clear feedback
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	_indicator.scale = Vector2(1.3, 1.3)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_indicator, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_target_lost() -> void:
	_target = null
	_indicator.visible = false


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
		_indicator.position = screen_pos - Vector2(24, 24)
		_indicator.visible = true
	else:
		_indicator.visible = false
