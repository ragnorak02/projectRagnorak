## Third-person camera rig with free orbit, lock-on framing, and collision avoidance.
##
## v5 DD lock-on framing: the target must never sit on the camera->player line
## (reticle drawn over Amaro's head) nor between the camera and the player.
## The rig keeps a horizontal angular separation of at least
## FRAME_MIN_SEPARATION_DEG between player and target as seen from the camera:
##   theta = signed flat angle between the camera's forward and player->target
##   theta_req(d) = a + asin(min(1, L sin(a) / d))   (a = min separation,
##                  L = current arm length, d = flat player->target distance)
##   Locked on (not tactical): yaw follows the target at side * theta_req
##     (player foreground, target beside him, both in view).
##   Tactical (free orbit with a highlighted / locked target): the orbit stays
##     free but is pushed out of the overlap cone (|theta| < theta_req) and
##     pulled back in view if the target is behind / beside the camera
##     (|theta| > FRAME_MAX_VIEW_DEG).
## The side (+1 / -1) is chosen from the current camera position when a target
## is acquired or switched (smallest move) and is sticky while it stays valid,
## so there is no left/right flip jitter. All smoothing uses unscaled time.
extends Node3D

## v5 DD framing constants (degrees).
const FRAME_MIN_SEPARATION_DEG := 18.0
const FRAME_MAX_OFFSET_DEG := 60.0
const FRAME_MAX_VIEW_DEG := 55.0
## Smoothing (1/s, unscaled) for the tactical push-out.
const FRAME_TACTICAL_SPEED := 6.0

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
## v5 DD framing side (+1 / -1), sticky per target.
var frame_side: float = 1.0
var _side_dirty: bool = true


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

	# Controller camera input (scaled by user sensitivity multiplier)
	var cam_input := InputManager.get_camera_vector()
	var sens: float = InputManager.controller_camera_sensitivity
	var in_tactical: bool = GameManager.current_state == GameManager.GameState.TACTICAL_MODE

	# During tactical mode, camera is always free orbit even if a target is highlighted
	if not _is_locked_on or in_tactical:
		_yaw -= cam_input.x * yaw_speed * sens * real_delta
	_pitch -= cam_input.y * pitch_speed * sens * real_delta
	_pitch = clampf(_pitch, min_pitch, max_pitch)

	if _is_locked_on and is_instance_valid(_lock_target) and in_tactical:
		# v5 DD: free orbit, but never with the target over / behind the player.
		var clamped := get_framed_yaw(_yaw, true)
		_yaw = lerp_angle(_yaw, clamped, clampf(FRAME_TACTICAL_SPEED * real_delta, 0.0, 1.0))

	if _is_locked_on and is_instance_valid(_lock_target) and not in_tactical:
		# Camera behind the player looking toward the target, offset sideways by
		# the framing angle so the target is beside (not behind) the player.
		var dir_to_target := (_lock_target.global_position - follow_target.global_position)
		dir_to_target.y = 0.0
		if dir_to_target.length() > 0.1:
			var desired_yaw := get_framed_yaw(_yaw, false)
			var yaw_factor := clampf(lock_on_yaw_speed * real_delta, 0.0, 1.0)
			_yaw = lerp_angle(_yaw, desired_yaw, yaw_factor)

		# Gently hold pitch at a comfortable combat angle (slightly above)
		var desired_pitch := -15.0
		var pitch_factor := clampf(lock_on_pitch_speed * real_delta, 0.0, 1.0)
		_pitch = lerpf(_pitch, desired_pitch, pitch_factor)

	yaw_pivot.rotation_degrees.y = rad_to_deg(_yaw)
	pitch_pivot.rotation_degrees.x = _pitch


# --- v5 DD lock-on framing (public, read-only helpers) ---

## Yaw whose flat forward points along player->target.
func _target_yaw() -> float:
	var d := _lock_target.global_position - follow_target.global_position
	return atan2(-d.x, -d.z)


## Required |theta| (radians) for the current target distance and arm length.
func get_required_offset() -> float:
	if follow_target == null or not is_instance_valid(_lock_target):
		return 0.0
	var d := _lock_target.global_position - follow_target.global_position
	d.y = 0.0
	var dist := maxf(d.length(), 0.1)
	var arm := maxf(spring_arm.get_hit_length() if spring_arm else default_distance, 1.0)
	var a := deg_to_rad(FRAME_MIN_SEPARATION_DEG)
	var theta := a + asin(minf(1.0, arm * sin(a) / dist))
	return minf(theta, deg_to_rad(FRAME_MAX_OFFSET_DEG))


## Signed flat angle (radians) between the camera forward for `yaw` and the
## player->target direction (0 = target directly behind the player on screen).
func get_frame_angle(yaw: float) -> float:
	if follow_target == null or not is_instance_valid(_lock_target):
		return 0.0
	return wrapf(yaw - _target_yaw(), -PI, PI)


## Framed yaw for the current target. lock mode: exactly side * theta_req.
## tactical_clamp: `yaw` itself, pushed out of the overlap cone and kept in
## view (|theta| in [theta_req, FRAME_MAX_VIEW_DEG]).
func get_framed_yaw(yaw: float, tactical_clamp: bool) -> float:
	if follow_target == null or not is_instance_valid(_lock_target):
		return yaw
	var d := _lock_target.global_position - follow_target.global_position
	d.y = 0.0
	if d.length() < 0.1:
		return yaw
	var theta := get_frame_angle(yaw)
	if _side_dirty:
		if absf(theta) > deg_to_rad(2.0):
			frame_side = signf(theta)
		_side_dirty = false
	var req := get_required_offset()
	var base := _target_yaw()
	if not tactical_clamp:
		return base + frame_side * req
	var max_view := maxf(deg_to_rad(FRAME_MAX_VIEW_DEG), req)
	var mag := absf(theta)
	var side := signf(theta) if mag > deg_to_rad(2.0) else frame_side
	if mag < req:
		return base + side * req
	if mag > max_view:
		return base + side * max_view
	return yaw


func _reset_camera() -> void:
	if follow_target:
		_yaw = follow_target.global_rotation.y
		_pitch = -15.0


func _on_lock_on_acquired(target: Node3D) -> void:
	if target != _lock_target:
		_side_dirty = true
	_is_locked_on = true
	_lock_target = target


func _on_lock_on_switched(new_target: Node3D) -> void:
	if new_target != _lock_target:
		_side_dirty = true
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
