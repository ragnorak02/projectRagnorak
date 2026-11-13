## Visual slash effect for melee attacks. Spawns a colored arc that fades out.
extends Node3D

const ATTACK_COLORS: Array[Color] = [
	Color(0.3, 0.7, 1.0),   # Attack 1: cyan/light blue
	Color(0.6, 0.4, 1.0),   # Attack 2: light purple
	Color(1.0, 0.7, 0.2),   # Attack 3: gold/orange (heavy finisher)
	Color(1.0, 0.86, 0.55), # Jump Attack: pale gold (v3: matches the heavy family)
]

# Battle v3 light/heavy strikes (spawn_strike). Light = thin pale cyan, heavy = wide gold.
const LIGHT_COLOR := Color(0.62, 0.93, 1.0)
const HEAVY_COLOR := Color(1.0, 0.74, 0.25)
## [inner_radius, outer_radius, depth_scale, size_mult] per kind.
const STRIKE_SHAPES := {
	&"light": [0.42, 0.55, 0.08, 1.0],
	&"heavy": [0.30, 0.68, 0.22, 1.35],
}

const ATTACK_SCALES: Array[float] = [
	1.0,   # Attack 1: standard
	1.1,   # Attack 2: slightly larger
	1.4,   # Attack 3: heavy finisher, noticeably bigger
	1.2,   # Jump Attack: medium-large
]

const FORWARD_OFFSET: float = 0.8
const EFFECT_DURATION: float = 0.3
const SCALE_IN_DURATION: float = 0.1

var _material: StandardMaterial3D


static func spawn(parent: Node3D, attack_index: int, pos: Vector3, forward: Vector3) -> void:
	## Creates a Node3D with a MeshInstance3D child showing a slash arc.
	## attack_index: 1 = first slash, 2 = second, 3 = heavy finisher, 4 = jump attack.
	## pos: world position to spawn at (typically player position + vertical offset).
	## forward: the direction the slash faces (typically -player.global_basis.z).

	var idx := clampi(attack_index - 1, 0, ATTACK_COLORS.size() - 1)
	var color: Color = ATTACK_COLORS[idx]
	var size_mult: float = ATTACK_SCALES[idx]

	var effect := Node3D.new()
	effect.name = "AttackVFX"
	parent.add_child(effect)

	# Position the effect at the given location, offset forward
	var spawn_pos := pos + forward.normalized() * FORWARD_OFFSET
	effect.global_position = spawn_pos

	# Orient the effect to face the forward direction
	if forward.length_squared() > 0.001:
		var look_target := spawn_pos + forward.normalized()
		# Avoid look_at degeneracy when forward is straight up/down
		var up_vec := Vector3.UP
		if absf(forward.normalized().dot(Vector3.UP)) > 0.95:
			up_vec = Vector3.FORWARD
		effect.look_at(look_target, up_vec)

	# Create the slash arc mesh (flattened torus)
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35 * size_mult
	torus.outer_radius = 0.6 * size_mult
	torus.rings = 16
	torus.ring_segments = 12
	mesh_inst.mesh = torus
	# Rotate the mesh so the torus ring stands upright like a vertical slash
	mesh_inst.rotation_degrees.x = 90.0
	# Flatten the torus along its depth to look like a thin arc
	mesh_inst.scale = Vector3(1.0, 0.15, 1.0) * size_mult

	# Create glowing transparent material
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 1
	mesh_inst.material_override = mat

	effect.add_child(mesh_inst)

	# Store material reference on the effect so the tween can access it
	effect.set_meta("vfx_material", mat)

	# Start small and scale up, then fade out
	var initial_scale := Vector3.ONE * 0.3
	var final_scale := Vector3.ONE
	effect.scale = initial_scale

	var tween := effect.create_tween()
	tween.set_parallel(true)

	# Scale in over SCALE_IN_DURATION
	tween.tween_property(effect, "scale", final_scale, SCALE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Fade alpha from full to 0 over EFFECT_DURATION
	tween.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(effect) and effect.has_meta("vfx_material"):
				var m: StandardMaterial3D = effect.get_meta("vfx_material")
				m.albedo_color.a = alpha
				m.emission_energy_multiplier = 3.5 * alpha,
		0.85,
		0.0,
		EFFECT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Slight rotation during the slash for visual dynamism
	var end_rotation := effect.rotation.y + deg_to_rad(25.0)
	tween.tween_property(effect, "rotation:y", end_rotation, EFFECT_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)

	# Destroy after the effect is done
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)


## Battle v3 strike arc. kind: &"light" (thin pale cyan) or &"heavy" (wide gold).
## step 1..3 grows the arc slightly; delay (s) staggers multi-arc finishers;
## tilt_deg rolls the arc so consecutive slashes read as different cuts.
static func spawn_strike(parent: Node, pos: Vector3, forward: Vector3, kind: StringName,
		step: int = 1, delay: float = 0.0, tilt_deg: float = 0.0) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var shape: Array = STRIKE_SHAPES.get(kind, STRIKE_SHAPES[&"light"])
	var color: Color = HEAVY_COLOR if kind == &"heavy" else LIGHT_COLOR
	var size_mult: float = float(shape[3]) * (1.0 + 0.08 * float(clampi(step, 1, 3) - 1))

	var effect := Node3D.new()
	effect.name = "StrikeVFX"
	parent.add_child(effect)
	var fwd := forward
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var spawn_pos := pos + fwd * FORWARD_OFFSET * (1.15 if kind == &"heavy" else 1.0)
	effect.global_position = spawn_pos
	effect.look_at(spawn_pos + fwd, Vector3.UP)
	effect.rotate_object_local(Vector3.FORWARD, deg_to_rad(tilt_deg))

	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = float(shape[0]) * size_mult
	torus.outer_radius = float(shape[1]) * size_mult
	torus.rings = 20
	torus.ring_segments = 8
	mesh_inst.mesh = torus
	mesh_inst.rotation_degrees.x = 90.0
	mesh_inst.scale = Vector3(1.0, float(shape[2]), 1.0)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.0 if delay > 0.0 else 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0 if kind == &"heavy" else 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 1
	mesh_inst.material_override = mat
	effect.add_child(mesh_inst)

	var duration := 0.38 if kind == &"heavy" else 0.24
	var energy := mat.emission_energy_multiplier
	effect.scale = Vector3.ONE * 0.35
	var tween := effect.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void: mat.albedo_color.a = 0.85)
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE, SCALE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(
		func(alpha: float) -> void:
			mat.albedo_color.a = alpha
			mat.emission_energy_multiplier = energy * alpha,
		0.85, 0.0, duration
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Sweep across the front (heavy sweeps wider).
	tween.tween_property(effect, "rotation:y",
		effect.rotation.y + deg_to_rad(40.0 if kind == &"heavy" else 25.0), duration)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
	return effect
