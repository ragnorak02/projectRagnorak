## v8 hold-to-aim dodge. Node: StateMachine/DodgeReady.
##
## Entered on a `dodge` (B / Shift) press from Idle / Run / LockOnIdle /
## LockOnStrafe. The character keeps the momentum it had at the press (no
## steering, facing kept) while the left stick aims; releasing the button fires
## the Dodge toward the stick (neutral stick = straight along the facing). A
## quick tap therefore dodges on release, as soon as the button comes up.
## After AIM_SHOW_S a small cyan chevron on the ground shows the aim; holding
## past AUTO_FIRE_S fires the dodge anyway (never stuck in this state).
## Dodge picks roll / side / back from the aim vs the facing (DodgeState).
## Leaving the floor drops the queued dodge (-> Fall). A hit flinches as usual.
extends State

const DodgeStateScript := preload("res://src/player/states/dodge_state.gd")

## Seconds of hold after which the aim marker appears (taps never show it).
const AIM_SHOW_S := 0.12
## Holding this long fires the dodge on its own.
const AUTO_FIRE_S := 1.0
## Polled-release fallback (a missed release event) only after this long.
const POLL_RELEASE_AFTER_S := 0.1

## Public for tests / HUD.
var aim: Vector3 = Vector3.FORWARD
var momentum: Vector3 = Vector3.ZERO
var held_time: float = 0.0

var _marker: MeshInstance3D = null
var _fired: bool = false


func enter(_msg: Dictionary = {}) -> void:
	held_time = 0.0
	_fired = false
	momentum = Vector3(player.velocity.x, 0.0, player.velocity.z)
	aim = _facing()
	_update_aim()


func exit() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null


func process_physics(delta: float) -> StringName:
	held_time += delta
	if not player.is_on_floor():
		return &"Fall"
	# Keep the momentum of the press; the stick only aims.
	player.velocity.x = momentum.x
	player.velocity.z = momentum.z
	_update_aim()
	_update_marker()
	if held_time >= AUTO_FIRE_S:
		return _fire()
	if held_time >= POLL_RELEASE_AFTER_S and not Input.is_action_pressed(&"dodge"):
		return _fire()
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_released(&"dodge"):
		_update_aim()
		return _fire()
	# Hold detection of a press that started before the dodge must not strand.
	if event.is_action_released(&"attack"):
		if player.stance:
			player.stance.handle_attack_release()
		if player.combo:
			player.combo.on_attack_released()
	return &""


func _fire() -> StringName:
	if _fired:
		return &""
	_fired = true
	player.request_transition(&"Dodge", {"direction": aim})
	return &""


func _update_aim() -> void:
	var stick: Vector3 = DodgeStateScript.stick_to_world(player, InputManager.get_movement_vector())
	aim = stick if stick != Vector3.ZERO else _facing()


func _facing() -> Vector3:
	var f: Vector3 = -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## Kind the dodge would be if released now (&"roll" / &"side" / &"back").
func pending_kind() -> StringName:
	return DodgeStateScript.classify(aim, _facing())


# --- Aim marker (cosmetic) ---

func _update_marker() -> void:
	if held_time < AIM_SHOW_S or not player.is_inside_tree():
		return
	if _marker == null or not is_instance_valid(_marker):
		_marker = _make_marker()
		player.get_parent().add_child(_marker)
	var base: Vector3 = player.global_position + aim * 1.4
	base.y = player.global_position.y + 0.06
	_marker.global_transform = Transform3D(Basis.looking_at(aim), base)
	var mat := _marker.material_override as StandardMaterial3D
	if mat:
		var back := pending_kind() == DodgeStateScript.KIND_BACK
		mat.albedo_color = (Color("#F2B544") if back else Color("#5FE3F0")) * Color(1, 1, 1, 0.85)


static func _make_marker() -> MeshInstance3D:
	# Flat chevron pointing along -Z (looking_at forward).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		Vector3(0.0, 0.0, -0.45), Vector3(0.35, 0.0, 0.1), Vector3(0.0, 0.0, -0.15),
		Vector3(0.0, 0.0, -0.45), Vector3(0.0, 0.0, -0.15), Vector3(-0.35, 0.0, 0.1),
	]
	for p in pts:
		st.set_normal(Vector3.UP)
		st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "DodgeAimMarker"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.albedo_color = Color(0.37, 0.89, 0.94, 0.85)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
