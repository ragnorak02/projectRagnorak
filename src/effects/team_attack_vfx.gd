## Visual effect for team attacks. Spawns an expanding burst ring at the attacker position.
extends Node3D

const BURST_COLOR := Color(1.0, 0.7, 0.2, 0.9)
const EFFECT_DURATION := 0.5
const MAX_SCALE := 4.0


static func spawn(parent: Node3D, pos: Vector3) -> void:
	## Spawns an expanding golden burst ring for team attack feedback.
	var effect := Node3D.new()
	effect.name = "TeamAttackVFX"
	parent.add_child(effect)
	effect.global_position = pos

	# Create expanding ring (flattened torus)
	var mesh_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.2
	torus.rings = 24
	torus.ring_segments = 16
	mesh_inst.mesh = torus
	mesh_inst.rotation_degrees.x = 90.0
	mesh_inst.scale = Vector3(1.0, 0.1, 1.0)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = BURST_COLOR
	mat.emission_enabled = true
	mat.emission = Color(BURST_COLOR.r, BURST_COLOR.g, BURST_COLOR.b)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 2
	mesh_inst.material_override = mat
	effect.add_child(mesh_inst)

	# Expand outward and fade
	effect.scale = Vector3.ONE * 0.5
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * MAX_SCALE, EFFECT_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(effect):
				mat.albedo_color.a = alpha
				mat.emission_energy_multiplier = 5.0 * alpha,
		BURST_COLOR.a,
		0.0,
		EFFECT_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
