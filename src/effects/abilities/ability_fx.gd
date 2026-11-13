## v5 BB: shared helpers for Command Menu ability effects
## (src/effects/abilities/*.gd). Static only; no class_name (preload it).
##
## Effect contract (AbilityData.effect_script): a Node3D script with
##   func setup(caster: Node3D, target: Node3D, ability: AbilityData, aim_dir: Vector3) -> void
## AbilityState adds the node to the current scene, then calls setup(). The
## effect frees itself. Damage goes through EnemyBase's public API only:
## take_damage(amount, source, hit_kind) + add_stagger(amount) (+ launch(vel)
## when it exists). Tweens run in game time, so hit-stop/slow-mo apply.
extends RefCounted

## "Lumina Frost" palette for ability VFX (UIStyle tokens + water/wind tints).
const FROST := UIStyle.CYAN
const WHITE := Color(0.95, 0.99, 1.0)
const WATER := Color(0.25, 0.62, 1.0)
const WIND := Color(0.72, 1.0, 0.86)


## Damage + stagger one enemy. Returns true when it was hit.
static func hit(enemy, amount: float, stagger: float, source: Node3D, kind: StringName = &"") -> bool:
	if not is_alive(enemy):
		return false
	if enemy.has_method(&"take_damage"):
		if enemy.get_method_argument_count(&"take_damage") >= 3:
			enemy.take_damage(amount, source, kind)
		else:
			enemy.take_damage(amount, source)
	if stagger > 0.0 and is_instance_valid(enemy) and enemy.has_method(&"add_stagger"):
		enemy.add_stagger(stagger)
	if is_instance_valid(enemy):
		Events.attack_hit.emit(enemy, amount)
	return true


## Vertical launch through the public API (EnemyBase.launch when present).
static func launch(enemy, up_speed: float) -> void:
	if not is_alive(enemy):
		return
	if enemy.has_method(&"launch"):
		enemy.launch(Vector3(0, up_speed, 0))
	elif enemy is CharacterBody3D:
		# Fallback: EnemyBase never writes velocity.y outside gravity, so an
		# upward velocity arcs it up and back down.
		(enemy as CharacterBody3D).velocity.y = up_speed


## Untyped: callers may pass a freed enemy (freed 0.5s after death); a typed
## Node parameter raises a script error on a freed instance.
static func is_alive(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	return not ("_is_dead" in enemy and enemy._is_dead)


## Living enemies within `radius` of `centre` (flat distance, |dy| <= v_tol).
static func enemies_near(tree: SceneTree, centre: Vector3, radius: float, v_tol: float = 2.5) -> Array:
	var out: Array = []
	if tree == null:
		return out
	for e in tree.get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if not is_alive(n):
			continue
		var d: Vector3 = n.global_position - centre
		if absf(d.y) > v_tol:
			continue
		d.y = 0.0
		if d.length() <= radius:
			out.append(n)
	return out


static func make_mat(color: Color, energy: float = 3.0, alpha: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


## Flat ground ring (torus) child of `parent`, local position `pos`.
static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color, energy: float = 3.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 6
	mi.mesh = torus
	mi.scale = Vector3(radius, 0.2, radius)
	mi.position = pos
	mi.material_override = make_mat(color, energy)
	parent.add_child(mi)
	return mi


## Flat crescent ribbon in the local XZ plane, centred on -Z, spanning
## `arc_deg`, outer radius 1 (scale the node for size). Tapers at both tips.
static func arc_mesh(arc_deg: float = 150.0, width: float = 0.22, segments: int = 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(arc_deg) * 0.5
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	for i in segments + 1:
		var t := float(i) / float(segments)
		var ang := lerpf(-half, half, t)
		var w := width * sin(t * PI)  # taper to points at both ends
		var dir := Vector3(sin(ang), 0.0, -cos(ang))
		var p_out := dir
		var p_in := dir * (1.0 - w)
		if i > 0:
			st.add_vertex(prev_in)
			st.add_vertex(prev_out)
			st.add_vertex(p_out)
			st.add_vertex(prev_in)
			st.add_vertex(p_out)
			st.add_vertex(p_in)
		prev_in = p_in
		prev_out = p_out
	return st.commit()


## Crescent blade child of `parent` (outer radius `radius`, arc `arc_deg`).
static func crescent(parent: Node3D, radius: float, color: Color, arc_deg: float = 150.0, width: float = 0.22) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = arc_mesh(arc_deg, width)
	mi.scale = Vector3.ONE * radius
	mi.material_override = make_mat(color, 4.0)
	parent.add_child(mi)
	return mi


## Fade a material's alpha + emission to 0 on `tween` (parallel-friendly).
static func fade(tween: Tween, mat: StandardMaterial3D, duration: float, from_alpha: float = 0.85) -> void:
	var energy := mat.emission_energy_multiplier
	tween.tween_method(func(a: float) -> void:
			mat.albedo_color.a = a
			mat.emission_energy_multiplier = energy * (a / maxf(from_alpha, 0.01)),
		from_alpha, 0.0, duration)
