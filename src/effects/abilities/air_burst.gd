## v5 BB6 — Air Burst (Taighe, aerial-only).
## A radial wind pulse centred on Taighe: an expanding sphere shell + two
## crossed rings. Every living enemy within RADIUS (3D distance, so it works
## from mid-air) takes damage + stagger once.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")

const RADIUS := 5.0
const DURATION := 0.4

var hit_targets: Array = []


func setup(caster: Node3D, _target: Node3D, ability: AbilityData, _aim_dir: Vector3) -> void:
	global_position = caster.global_position + Vector3(0, 1.0, 0)
	var damage: float = ability.damage if ability else 22.0
	var stagger: float = ability.stagger if ability else 20.0
	var reach: float = maxf(RADIUS, AbilitySystem.range_of(ability))

	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if FX.is_alive(n) and n.global_position.distance_to(caster.global_position) <= reach + 0.01:
			hit_targets.append(n)
	for n in hit_targets:
		FX.hit(n, damage, stagger, caster, &"")

	# VFX: sphere shell + horizontal and tilted rings expanding to the radius.
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	var shell_mat := FX.make_mat(FX.WIND, 2.0, 0.35)
	shell.material_override = shell_mat
	shell.scale = Vector3.ONE * 0.3
	add_child(shell)
	var ring_a := FX.ring(self, Vector3.ZERO, 0.3, FX.WHITE, 4.0)
	var ring_b := FX.ring(self, Vector3.ZERO, 0.3, FX.WIND, 3.0)
	ring_b.rotation_degrees = Vector3(70, 0, 20)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(shell, "scale", Vector3.ONE * reach, DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring_a, "scale", Vector3(reach, 0.3, reach), DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring_b, "scale", Vector3(reach * 0.8, 0.3, reach * 0.8), DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	FX.fade(tw, shell_mat, DURATION, 0.35)
	FX.fade(tw, ring_a.material_override as StandardMaterial3D, DURATION)
	FX.fade(tw, ring_b.material_override as StandardMaterial3D, DURATION)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
	Events.camera_shake_requested.emit(0.15, 0.12)
