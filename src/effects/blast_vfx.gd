## Combo blast finisher (battle system v3, Package R).
##
## spawn(): visual only — an expanding flat ring on the ground plus a sphere
## flash at the impact point, gold to white, sized by the blast radius.
## detonate(): damage + stagger to every living enemy within `radius` of the
## centre, exactly once each (distance query over the "enemies" group).
## Tweens run in game time so hit-stop / tactical slow-mo slow them too.
extends Node3D

const GOLD := Color(1.0, 0.72, 0.22)
const WHITE := Color(1.0, 0.97, 0.88)
## Enemies further than this above/below the centre are not hit.
const VERTICAL_TOLERANCE := 2.5


## Apply blast damage. Returns the number of enemies hit.
static func detonate(source: Node3D, centre: Vector3, radius: float, damage: float, stagger: float) -> int:
	if source == null or not source.is_inside_tree():
		return 0
	var hit := 0
	# Snapshot first: take_damage may kill (and free) enemies mid-loop.
	var targets: Array = []
	for e in source.get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or not is_instance_valid(n):
			continue
		if "_is_dead" in n and n._is_dead:
			continue
		var d: Vector3 = n.global_position - centre
		if absf(d.y) > VERTICAL_TOLERANCE:
			continue
		d.y = 0.0
		if d.length() <= radius:
			targets.append(n)
	for n in targets:
		if not is_instance_valid(n):
			continue
		if n.has_method("take_damage"):
			if n.get_method_argument_count(&"take_damage") >= 3:
				n.take_damage(damage, source, &"blast")
			else:
				n.take_damage(damage, source)
			hit += 1
		if n.has_method("add_stagger") and is_instance_valid(n):
			n.add_stagger(stagger)
	if hit > 0:
		Events.attack_hit.emit(targets[0], damage)
	return hit


## Spawn the ring + flash. Returns the effect root (freed automatically).
static func spawn(parent: Node, pos: Vector3, radius: float) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var effect := Node3D.new()
	effect.name = "BlastVFX"
	parent.add_child(effect)
	effect.global_position = pos

	var big := radius >= 4.5
	var duration := 0.45 + radius * 0.05

	# Expanding ground ring (flat torus), outer radius grows to `radius`.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.scale = Vector3(0.2, 0.25, 0.2)
	ring.position = Vector3(0, -0.5, 0)
	var ring_mat := _make_mat(GOLD, 4.0)
	ring.material_override = ring_mat
	effect.add_child(ring)

	# Sphere flash at the impact point.
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	flash.mesh = sphere
	flash.scale = Vector3.ONE * 0.2
	var flash_mat := _make_mat(WHITE, 6.0)
	flash.material_override = flash_mat
	effect.add_child(flash)

	var flash_size := radius * (0.45 if big else 0.35)
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.25, radius), duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(t: float) -> void:
			ring_mat.albedo_color = GOLD.lerp(WHITE, t)
			ring_mat.albedo_color.a = 0.9 * (1.0 - t)
			ring_mat.emission = GOLD.lerp(WHITE, t)
			ring_mat.emission_energy_multiplier = 4.0 * (1.0 - t),
		0.0, 1.0, duration)
	tween.tween_property(flash, "scale", Vector3.ONE * flash_size, duration * 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_method(
		func(t: float) -> void:
			flash_mat.albedo_color = WHITE.lerp(GOLD, t)
			flash_mat.albedo_color.a = 0.85 * (1.0 - t)
			flash_mat.emission_energy_multiplier = 6.0 * (1.0 - t),
		0.0, 1.0, duration * 0.7)
	if big:
		# H-H-H: a second, slower shock ring.
		var ring2 := ring.duplicate() as MeshInstance3D
		var ring2_mat := _make_mat(WHITE, 3.0)
		ring2.material_override = ring2_mat
		effect.add_child(ring2)
		tween.tween_property(ring2, "scale", Vector3(radius * 1.15, 0.4, radius * 1.15), duration * 1.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(ring2_mat, "albedo_color:a", 0.0, duration * 1.3)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
	return effect


static func _make_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 1
	return mat
