## Visual slash effect for melee attacks. Spawns a colored arc that fades out.
extends Node3D

const ATTACK_COLORS: Array[Color] = [
	Color(0.3, 0.7, 1.0),   # Attack 1: cyan/light blue
	Color(0.6, 0.4, 1.0),   # Attack 2: light purple
	Color(1.0, 0.7, 0.2),   # Attack 3: gold/orange (heavy finisher)
	Color(1.0, 1.0, 0.9),   # Jump Attack: white/bright
]

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
