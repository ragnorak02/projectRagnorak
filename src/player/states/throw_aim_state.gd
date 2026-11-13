extends State

## Aiming a carried crate (controls v2, Package I). Entered from Carry by
## holding Y (`interact`, v3; was B in v2) for 0.25s.
##   - Rooted: horizontal velocity is zeroed every frame.
##   - Aim yaw = camera flat forward. The right stick / mouse orbit the camera
##     as usual (CameraRig owns that); this state only READS the camera basis.
##   - X (`attack`) throws along the previewed arc -> Idle.
##   - Releasing B without throwing -> back to Carry.

@export var turn_speed: float = 14.0

var _carry: Node = null
var _arc: Node = null


func initialize(p: CharacterBody3D) -> void:
	super.initialize(p)
	_carry = p.get_node_or_null("CarryComponent")
	_arc = p.get_node_or_null("ThrowArc")


func enter(_msg: Dictionary = {}) -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.set_sprinting(false)
	player.play_animation(&"idle")
	if _arc and _arc.has_method("show_arc"):
		_arc.show_arc()
	_update_arc()


func exit() -> void:
	if _arc and _arc.has_method("hide_arc"):
		_arc.hide_arc()
	if _carry and not _carry.consume_handoff() and _carry.is_carrying:
		_carry.drop(&"forced")


func process_physics(delta: float) -> StringName:
	if _carry == null or not _carry.is_carrying:
		return &"Idle" if player.is_on_floor() else &"Fall"
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	var aim := get_aim_direction()
	player.basis = player.basis.slerp(Basis.looking_at(aim), clampf(turn_speed * delta, 0.0, 1.0)).orthonormalized()
	_update_arc()
	return &""


func process_frame(_delta: float) -> StringName:
	# Release of B (polled so a release eaten elsewhere can't strand us here).
	if not Input.is_action_pressed(&"interact"):
		return _cancel_to_carry()
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"attack"):
		player.get_viewport().set_input_as_handled()
		if _carry and _carry.throw(get_aim_direction()):
			return &"Idle"
		return &""
	if event.is_action_released(&"interact"):
		player.get_viewport().set_input_as_handled()
		return _cancel_to_carry()
	# jump / dodge / tactical / lock-on: blocked while aiming.
	return &""


## Flat aim direction: camera forward, or player facing without a camera.
func get_aim_direction() -> Vector3:
	var cam := player.get_viewport().get_camera_3d()
	var f: Vector3
	if cam:
		f = -cam.global_basis.z
	else:
		f = -player.global_basis.z
	f.y = 0.0
	if f.length() < 0.01:
		f = -player.global_basis.z
		f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _cancel_to_carry() -> StringName:
	if _carry and _carry.is_carrying:
		_carry.mark_handoff()
		return &"Carry"
	return &"Idle"


func _update_arc() -> void:
	if _arc == null or not _arc.has_method("update_arc") or _carry == null or not _carry.is_carrying:
		return
	var crate: Node3D = _carry.held_object
	var exclude: Array[RID] = [player.get_rid()]
	if crate is CollisionObject3D:
		exclude.append((crate as CollisionObject3D).get_rid())
	_arc.update_arc(crate.global_position, _carry.get_launch_velocity(get_aim_direction()),
		_carry.get_held_gravity(), exclude)
