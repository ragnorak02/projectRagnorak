## Visual afterimage/ghost effect for dodge. Spawns a transparent copy at the dodge start position.
extends Node3D

const GHOST_COLOR := Color(0.4, 0.6, 1.0, 0.5)
const FADE_DURATION := 0.35

var _material: StandardMaterial3D


static func spawn(parent: Node3D, pos: Vector3, facing: Vector3) -> void:
	## Spawns a translucent ghost silhouette at the dodge start position.
	var effect := Node3D.new()
	effect.name = "DodgeVFX"
	parent.add_child(effect)
	effect.global_position = pos

	# Orient toward dodge direction
	if facing.length_squared() > 0.001:
		var look_target := pos + facing.normalized()
		var up_vec := Vector3.UP
		if absf(facing.normalized().dot(Vector3.UP)) > 0.95:
			up_vec = Vector3.FORWARD
		effect.look_at(look_target, up_vec)

	# Create ghost capsule mesh (same shape as player)
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	mesh_inst.mesh = capsule
	mesh_inst.position.y = 0.8

	# Transparent emissive material
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = GHOST_COLOR
	mat.emission_enabled = true
	mat.emission = Color(GHOST_COLOR.r, GHOST_COLOR.g, GHOST_COLOR.b)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mesh_inst.material_override = mat
	effect.add_child(mesh_inst)

	# Fade out and destroy
	var tween := effect.create_tween()
	tween.tween_method(
		func(alpha: float) -> void:
			if is_instance_valid(effect):
				mat.albedo_color.a = alpha
				mat.emission_energy_multiplier = 2.0 * alpha,
		GHOST_COLOR.a,
		0.0,
		FADE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(effect.queue_free)
