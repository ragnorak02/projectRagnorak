## Throw arc preview (controls v2, Package I).
## A top-level MeshInstance3D that draws the predicted ballistic path of a
## thrown crate as a line strip plus a landing ring. Pure presentation: it only
## reads physics (raycasts) and never touches gameplay state.
extends MeshInstance3D

@export var step_time: float = 0.04
@export var max_steps: int = 90
@export var collision_mask: int = 1 | 4  # World | EnemyBody
@export var arc_color: Color = Color(0.373, 0.890, 0.941, 0.9)  # Lumina cyan (UIStyle.CYAN)
@export var landing_color: Color = Color(0.949, 0.710, 0.267, 1.0)  # ember gold (UIStyle.GOLD)

var landing_point: Vector3 = Vector3.ZERO
var has_landing: bool = false

var _imesh: ImmediateMesh


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat
	visible = false


## Recompute and redraw the arc. `exclude` = RIDs the arc must not hit.
func update_arc(origin: Vector3, launch_velocity: Vector3, gravity: float, exclude: Array[RID] = []) -> void:
	global_transform = Transform3D.IDENTITY
	_imesh.clear_surfaces()
	has_landing = false
	var points: PackedVector3Array = [origin]
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var pos := origin
	var vel := launch_velocity
	for i in max_steps:
		var next := pos + vel * step_time
		vel.y -= gravity * step_time
		if space:
			var q := PhysicsRayQueryParameters3D.create(pos, next, collision_mask)
			q.exclude = exclude
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				points.append(hit.position)
				landing_point = hit.position
				has_landing = true
				break
		points.append(next)
		pos = next
	if not has_landing:
		landing_point = pos

	_imesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in points.size():
		var c := arc_color
		c.a = lerpf(arc_color.a, 0.35, float(i) / maxf(points.size() - 1, 1))
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(points[i])
	_imesh.surface_end()

	if has_landing:
		_imesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		var r := 0.55
		for s in 25:
			var a := TAU * float(s) / 24.0
			_imesh.surface_set_color(landing_color)
			_imesh.surface_add_vertex(landing_point + Vector3(cos(a) * r, 0.05, sin(a) * r))
		_imesh.surface_end()


func show_arc() -> void:
	visible = true


func hide_arc() -> void:
	visible = false
	if _imesh:
		_imesh.clear_surfaces()
