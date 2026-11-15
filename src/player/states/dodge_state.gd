## v8 ground dodge. Node: StateMachine/Dodge.
##
## Entered from DodgeReady (B released; msg {"direction": Vector3}) or straight
## from an attack/strike cancel (direction = stick, camera-relative; no stick =
## facing). The dodge KIND comes from the direction relative to the body's
## facing (= the way the character was running / looking):
##   ROLL  within 60 deg of facing   fast dash (17 m/s, 0.35 s), faces the dodge
##   SIDE  60..120 deg               sideways dash with a small hop, facing kept
##   BACK  more than 120 deg         BIG backward leap (~1.6 m up, ~6.5 m back),
##                                   facing kept; ends on landing (or -> Fall)
## The LOOK comes from the controlled member (PartyMemberData.dodge_style):
##   &"acrobat" (Amaro): forward roll / cartwheel / backflip
##   &"glide"   (Taighe): ice-trail glide / leaning side glide / floating
##                        back-leap with a spin of light (lower gravity)
## Visuals are cosmetic: only $VisualRoot's transform is rotated around the
## body centre and restored on exit; the body never rotates off its yaw.
## No invulnerability frames (design contract). Committed: attack releases are
## forwarded so a hold that started before the dodge never strands.
extends State

const DodgeVFX = preload("res://src/effects/dodge_vfx.gd")

const KIND_ROLL := &"roll"
const KIND_SIDE := &"side"
const KIND_BACK := &"back"
const STYLE_ACROBAT := &"acrobat"
const STYLE_GLIDE := &"glide"

## dot(direction, facing) thresholds: >= ROLL_DOT roll, <= BACK_DOT back.
const ROLL_DOT := 0.5
const BACK_DOT := -0.5
## Height of the visual pivot (body centre) above the feet.
const PIVOT_HEIGHT := 0.9

@export var dodge_speed: float = 17.0
@export var dodge_duration: float = 0.35
@export var side_speed: float = 14.0
@export var side_duration: float = 0.4
@export var side_hop: float = 3.0
## Backflip (acrobat): apex height (m) and distance (m) for a full arc.
@export var back_height: float = 1.6
@export var back_distance: float = 6.5
## Floating back-leap (glide): apex height and the share of gravity it feels.
@export var glide_back_height: float = 1.8
@export var glide_gravity_scale: float = 0.55
## Safety cap for the airborne back leap (s).
@export var back_max_time: float = 1.3

## Public for tests / visuals.
var kind: StringName = KIND_ROLL
var style: StringName = STYLE_ACROBAT
var direction: Vector3 = Vector3.FORWARD
## +1 = to the body's right, -1 = left (SIDE).
var side_sign: float = 1.0
## Expected time of the visual move (airtime for BACK).
var move_time: float = 0.35

var _timer: float = 0.0
var _back_speed: float = 0.0
var _ghost_timer: float = 0.0
var _left_floor: bool = false


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	_ghost_timer = 0.0
	_left_floor = false
	player.start_dodge_cooldown()
	# v3: dodge resets the light/heavy combo string.
	if player.combo:
		player.combo.reset(&"dodge")

	style = _member_style()
	var facing := _facing()
	direction = msg.get("direction", Vector3.ZERO) as Vector3
	direction.y = 0.0
	if direction.length() < 0.1:
		direction = _stick_direction()
	if direction.length() < 0.1:
		direction = facing
	direction = direction.normalized()
	kind = classify(direction, facing)
	side_sign = signf(facing.cross(direction).y) * -1.0
	if side_sign == 0.0:
		side_sign = 1.0

	match kind:
		KIND_ROLL:
			move_time = dodge_duration
			if not player.is_locked_on:
				player.basis = Basis.looking_at(direction)
		KIND_SIDE:
			move_time = side_duration
			player.velocity.y = side_hop
		KIND_BACK:
			var g := _gravity() * (glide_gravity_scale if style == STYLE_GLIDE else 1.0)
			var h := glide_back_height if style == STYLE_GLIDE else back_height
			var vy := sqrt(2.0 * g * h)
			move_time = 2.0 * vy / g
			_back_speed = back_distance / maxf(move_time, 0.1)
			# + half a frame of gravity (Player applies it before the first move).
			player.velocity.y = vy + _gravity() * get_physics_process_delta_time() * 0.5
			if style == STYLE_GLIDE and player.is_inside_tree():
				StanceAuraVfx.flash(player.get_parent(), player.global_position, true)

	if player.is_inside_tree():
		DodgeVFX.spawn(player.get_parent(), player.global_position, direction)
	AudioManager.play_sfx_named("dodge")
	_apply_horizontal()


func exit() -> void:
	_set_visual(Transform3D.IDENTITY)


## Dodge kind for a world direction relative to the facing (both flat).
static func classify(dir: Vector3, facing: Vector3) -> StringName:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var f := Vector3(facing.x, 0.0, facing.z).normalized()
	var dot := d.dot(f)
	if dot >= ROLL_DOT:
		return KIND_ROLL
	if dot <= BACK_DOT:
		return KIND_BACK
	return KIND_SIDE


func process_physics(delta: float) -> StringName:
	_timer += delta
	if kind == KIND_BACK:
		if style == STYLE_GLIDE:
			# Floaty: cancel part of the Player's gravity step.
			player.velocity.y += _gravity() * (1.0 - glide_gravity_scale) * delta
		if not player.is_on_floor():
			_left_floor = true
		if (_left_floor or _timer > 0.25) and player.is_on_floor() and _timer > 0.1:
			return _end_state()
		if _timer >= back_max_time:
			return &"Fall"
	elif _timer >= move_time:
		return _end_state() if player.is_on_floor() or kind == KIND_ROLL else &"Fall"

	_apply_horizontal()
	_update_visual()
	_update_trail(delta)
	return &""


## Releases go to BOTH components (hold detection needs them), so a hold that
## started before the dodge never strands a pending charge. The dodge is
## committed: any state they return is ignored (the combo was reset on enter).
func process_input(event: InputEvent) -> StringName:
	if event.is_action_released(&"attack"):
		if player.stance:
			player.stance.handle_attack_release()
		if player.combo:
			player.combo.on_attack_released()
	return &""


# --- Movement ---

func _apply_horizontal() -> void:
	var speed: float
	match kind:
		KIND_BACK:
			speed = _back_speed
		KIND_SIDE:
			var ps := clampf(_timer / maxf(side_duration, 0.01), 0.0, 1.0)
			speed = side_speed * (1.0 - ps * ps * 0.8)
		_:
			var p := clampf(_timer / maxf(dodge_duration, 0.01), 0.0, 1.0)
			speed = dodge_speed * (1.0 - p * p)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed


func _end_state() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if kind == KIND_BACK:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
	return &"LockOnIdle" if player.is_locked_on else &"Idle"


# --- Visuals (cosmetic: $VisualRoot only) ---

## 0..1 progress of the visual move.
func progress() -> float:
	return clampf(_timer / maxf(move_time, 0.01), 0.0, 1.0)


func _update_visual() -> void:
	var t := progress()
	var e := _ease_in_out(t)
	var rot := Basis.IDENTITY
	var lift := 0.0
	if style == STYLE_GLIDE:
		match kind:
			KIND_ROLL:
				rot = Basis(Vector3.RIGHT, deg_to_rad(-16.0) * sin(PI * t))
				lift = 0.25 * sin(PI * t)
			KIND_SIDE:
				rot = Basis(Vector3.BACK, deg_to_rad(-22.0) * side_sign * sin(PI * t))
				lift = 0.2 * sin(PI * t)
			KIND_BACK:
				rot = Basis(Vector3.UP, TAU * e) * Basis(Vector3.RIGHT, deg_to_rad(12.0) * sin(PI * t))
	else:
		match kind:
			KIND_ROLL:
				# Forward somersault: head travels forward (-X rotation, model faces -Z).
				rot = Basis(Vector3.RIGHT, -TAU * e)
				lift = -0.25 * sin(PI * t)
			KIND_SIDE:
				# Cartwheel around the facing axis, head leading toward the travel side.
				rot = Basis(Vector3.BACK, -TAU * e * side_sign)
			KIND_BACK:
				# Backflip: head travels backward (+X rotation).
				rot = Basis(Vector3.RIGHT, TAU * e)
	var pivot := Vector3(0.0, PIVOT_HEIGHT, 0.0)
	_set_visual(Transform3D(rot, pivot - rot * pivot + Vector3(0.0, lift, 0.0)))


func _set_visual(xf: Transform3D) -> void:
	var vr: Node3D = player.get(&"visual_root") as Node3D if player else null
	if vr:
		vr.transform = xf


## Glide style leaves an ice trail of fading afterimages.
func _update_trail(delta: float) -> void:
	if style != STYLE_GLIDE or not player.is_inside_tree():
		return
	_ghost_timer += delta
	if _ghost_timer >= 0.07:
		_ghost_timer = 0.0
		DodgeVFX.spawn(player.get_parent(), player.global_position, direction)


static func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# --- Helpers ---

func _member_style() -> StringName:
	var data: Resource = player.get_member_data() if player.has_method(&"get_member_data") else null
	if data and "dodge_style" in data and data.dodge_style != &"":
		return data.dodge_style
	return STYLE_ACROBAT


func _facing() -> Vector3:
	var f: Vector3 = -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _gravity() -> float:
	var g = player.get(&"gravity")
	return float(g) if g != null else 30.0


func _stick_direction() -> Vector3:
	return stick_to_world(player, InputManager.get_movement_vector())


## Camera-relative flat world direction for a stick vector (ZERO if neutral).
static func stick_to_world(p: Node3D, input: Vector2) -> Vector3:
	if input.length() <= 0.1 or p == null or not p.is_inside_tree():
		return Vector3.ZERO
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	var dir := forward.normalized() * -input.y + right.normalized() * input.x
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
