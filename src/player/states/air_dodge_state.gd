## v5 DD — Air dodge (movement only). Node: StateMachine/AirDodge.
##
## Entered from Jump / Fall / an air MeleeStrike on `dodge`, once per airtime
## (budget: ComboComponent.consume_air_dodge(), refreshed on landing).
## Direction = stick, camera-relative.
##   Stick back (toward the camera), or no stick while locked on
##     -> BACKFLIP: up-and-back arc (~BACKFLIP_HEIGHT up, ~BACKFLIP_DISTANCE
##        back), facing kept forward, then Fall.
##   Any other stick direction (or no stick, free) -> short AIR DASH along it,
##        altitude held during the dash, then Fall.
## No invulnerability frames (design contract). Committed: no attack / menu
## exits; attack releases are forwarded so a pending hold never strands.
## Animation hooks (played only if present; also sent to a rigless visual's
## play_cue() via player._rigless_cue): air_dodge_back, air_dash. `mode` (&"backflip" / &"dash") and
## `direction` are public for tests and visuals.
extends State

const DodgeVFX = preload("res://src/effects/dodge_vfx.gd")

const MODE_BACKFLIP := &"backflip"
const MODE_DASH := &"dash"

## Backflip arc: apex height (m) above the start, horizontal distance (m)
## covered during the state, and duration (s).
@export var backflip_height: float = 1.5
@export var backflip_distance: float = 4.0
@export var backflip_duration: float = 0.45
## Air dash: peak speed (m/s, decays 1 - p^2) and duration (s).
@export var dash_speed: float = 16.0
@export var dash_duration: float = 0.28
## Horizontal speed carried into Fall (m/s).
@export var exit_carry_speed: float = 1.5
## Stick counts as "back" when its camera-space back component is at least this.
const BACK_THRESHOLD := 0.7

var mode: StringName = MODE_DASH
var direction: Vector3 = Vector3.FORWARD
var _timer: float = 0.0
var _duration: float = 0.3


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	var combo: ComboComponent = player.get(&"combo") as ComboComponent
	if combo:
		combo.consume_air_dodge()
		combo.reset(&"dodge")
	if player.has_method(&"start_dodge_cooldown"):
		player.start_dodge_cooldown()

	var facing: Vector3 = -player.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var input := InputManager.get_movement_vector()
	var stick := _camera_relative(input)
	var stick_back := input.length() > 0.1 and input.normalized().y >= BACK_THRESHOLD
	var no_stick := stick == Vector3.ZERO

	if stick_back or (no_stick and player.is_locked_on):
		mode = MODE_BACKFLIP
		if player.is_locked_on:
			player.face_lock_target(1.0)
			facing = -player.global_basis.z
			facing.y = 0.0
			facing = facing.normalized()
		# Back = the stick direction, or straight away from facing / the target.
		direction = stick if stick_back and not player.is_locked_on else -facing
		if stick_back and not player.is_locked_on:
			# Keep looking forward while flipping backward.
			player.basis = Basis.looking_at(-direction)
		_duration = backflip_duration
		var g: float = float(player.get(&"gravity")) if player.get(&"gravity") != null else 30.0
		# Apex at backflip_height: v0 = sqrt(2 g h) (+ half a frame of gravity,
		# since Player applies gravity before the first move).
		player.velocity.y = sqrt(2.0 * g * backflip_height) + g * get_physics_process_delta_time() * 0.5
		_play_hook(&"air_dodge_back")
	else:
		mode = MODE_DASH
		direction = facing if no_stick else stick
		if not player.is_locked_on:
			player.basis = Basis.looking_at(direction)
		_duration = dash_duration
		player.velocity.y = _hold_vy()
		_play_hook(&"air_dash")

	_apply_horizontal()
	if player.is_inside_tree():
		DodgeVFX.spawn(player.get_parent(), player.global_position, -player.global_basis.z)
	AudioManager.play_sfx_named("dodge")


func exit() -> void:
	player.velocity.x = direction.x * exit_carry_speed
	player.velocity.z = direction.z * exit_carry_speed


func process_physics(_delta: float) -> StringName:
	_timer += _delta
	if _timer >= _duration:
		return &"Land" if player.is_on_floor() else &"Fall"
	if mode == MODE_DASH:
		player.velocity.y = _hold_vy()
	elif player.is_on_floor() and _timer > 0.05:
		return &"Land"
	_apply_horizontal()
	return &""


## Releases go to the components (hold detection needs them); the dodge is
## committed, so their return values are ignored.
func process_input(event: InputEvent) -> StringName:
	if event.is_action_released(&"attack"):
		var st: Node = player.get(&"stance")
		if st:
			st.handle_attack_release()
		var combo: Node = player.get(&"combo")
		if combo:
			combo.on_attack_released()
	return &""


# --- Internals ---

func _apply_horizontal() -> void:
	var speed: float
	if mode == MODE_BACKFLIP:
		speed = backflip_distance / maxf(backflip_duration, 0.01)
	else:
		var p := clampf(_timer / maxf(dash_duration, 0.01), 0.0, 1.0)
		speed = dash_speed * (1.0 - p * p)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed


## Cancels Player's gravity step: net vertical speed 0 during the dash.
func _hold_vy() -> float:
	var g: float = float(player.get(&"gravity")) if player.get(&"gravity") != null else 30.0
	return g * get_physics_process_delta_time()


func _camera_relative(input: Vector2) -> Vector3:
	if input.length() <= 0.1 or not player.is_inside_tree():
		return Vector3.ZERO
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	var dir := forward.normalized() * -input.y + right.normalized() * input.x
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


func _play_hook(hook: StringName) -> void:
	var ap: AnimationPlayer = player.get(&"anim_player") as AnimationPlayer
	if ap and ap.has_animation(hook):
		ap.play(hook, 0.1)
	# v5 EE rigless cue (same names; no-op without a RiglessVisual).
	if player.has_method(&"_rigless_cue"):
		player._rigless_cue(hook)
