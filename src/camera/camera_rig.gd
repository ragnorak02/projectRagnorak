## Third-person camera rig with free orbit, lock-on framing, and collision avoidance.
extends Node3D

@export var follow_target: Node3D
@export var follow_speed: float = 12.0
@export var yaw_speed: float = 4.0
@export var pitch_speed: float = 2.5
@export var min_pitch: float = -60.0
@export var max_pitch: float = 40.0
@export var default_distance: float = 5.0
@export var lock_on_yaw_speed: float = 10.0
@export var lock_on_pitch_speed: float = 4.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D

var _yaw: float = 0.0
var _pitch: float = -15.0
var _is_locked_on: bool = false
var _lock_target: Node3D = null


func _ready() -> void:
	spring_arm.spring_length = default_distance
	spring_arm.margin = 0.3  # Smoother collision avoidance
	Events.lock_on_target_acquired.connect(_on_lock_on_acquired)
	Events.lock_on_target_lost.connect(_on_lock_on_lost)
	Events.lock_on_target_switched.connect(_on_lock_on_switched)
	Events.camera_shake_requested.connect(_on_shake_requested)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_reset"):
		_reset_camera()


func _physics_process(_delta: float) -> void:
	if follow_target == null:
		return

	# Use unscaled delta so camera stays responsive during tactical slow-time
	var real_delta := _delta if Engine.time_scale == 0.0 else _delta / Engine.time_scale

	# Smooth follow with frame-rate independent exponential decay
	var t := 1.0 - exp(-follow_speed * real_delta)
	global_position = global_position.lerp(follow_target.global_position, t)

	# Controller camera input
	var cam_input := InputManager.get_camera_vector()
	var in_tactical: bool = GameManager.current_state == GameManager.GameState.TACTICAL_MODE

	# During tactical mode, camera is always free orbit even if a target is highlighted
	if not _is_locked_on or in_tactical:
		_yaw -= cam_input.x * yaw_speed * real_delta
	_pitch -= cam_input.y * pitch_speed * real_delta
	_pitch = clampf(_pitch, min_pitch, max_pitch)

	if _is_locked_on and is_instance_valid(_lock_target) and not in_tactical:
		# Calculate the yaw that places the camera BEHIND the player, looking toward target
		var dir_to_target := (_lock_target.global_position - follow_target.global_position)
		dir_to_target.y = 0.0
		if dir_to_target.length() > 0.1:
			dir_to_target = dir_to_target.normalized()
			# Camera behind player: yaw = direction player faces (toward target)
			var desired_yaw := atan2(-dir_to_target.x, -dir_to_target.z)
			var yaw_factor := clampf(lock_on_yaw_speed * real_delta, 0.0, 1.0)
			_yaw = lerp_angle(_yaw, desired_yaw, yaw_factor)

		# Gently hold pitch at a comfortable combat angle (slightly above)
		var desired_pitch := -15.0
		var pitch_factor := clampf(lock_on_pitch_speed * real_delta, 0.0, 1.0)
		_pitch = lerpf(_pitch, desired_pitch, pitch_factor)

	yaw_pivot.rotation_degrees.y = rad_to_deg(_yaw)
	pitch_pivot.rotation_degrees.x = _pitch


func _reset_camera() -> void:
	if follow_target:
		_yaw = follow_target.global_rotation.y
		_pitch = -15.0


func _on_lock_on_acquired(target: Node3D) -> void:
	_is_locked_on = true
	_lock_target = target


func _on_lock_on_switched(new_target: Node3D) -> void:
	_lock_target = new_target


func _on_lock_on_lost() -> void:
	_is_locked_on = false
	_lock_target = null


func _on_shake_requested(intensity: float, duration: float) -> void:
	var tween := create_tween()
	var original_offset := camera.position
	for i in 4:
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0.0
		)
		tween.tween_property(camera, "position", original_offset + offset, duration / 8.0)
		tween.tween_property(camera, "position", original_offset, duration / 8.0)
