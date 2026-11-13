## v5 BB3 — Sword Slash (Amaro, 0 MP, 1 ATB segment).
## A wide frontal energy crescent toward the target (~3.5 m reach). Hits every
## living enemy inside the frontal arc once (the chosen target is always
## included when within reach). Moderate damage, good stagger.
## VFX: AttackVFX heavy strike arcs + one big flat Frost crescent sweeping out.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")
const AttackVFX := preload("res://src/effects/attack_vfx.gd")

const REACH := 3.5
## Half-angle of the frontal arc (degrees).
const HALF_ARC_DEG := 75.0
const VERTICAL_TOLERANCE := 2.0
const DURATION := 0.42

var hit_targets: Array = []


func setup(caster: Node3D, target: Node3D, ability: AbilityData, aim_dir: Vector3) -> void:
	var origin: Vector3 = caster.global_position
	var fwd := aim_dir
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = -caster.global_basis.z
		fwd.y = 0.0
	fwd = fwd.normalized()
	var reach: float = maxf(REACH, AbilitySystem.range_of(ability))
	var damage: float = ability.damage if ability else 30.0
	var stagger: float = ability.stagger if ability else 30.0

	global_position = origin + Vector3(0, 1.0, 0)
	look_at(global_position + fwd, Vector3.UP)
	_build_vfx(reach)
	var parent := get_parent()
	AttackVFX.spawn_strike(parent, origin + Vector3(0, 1.0, 0), fwd, &"heavy", 3, 0.0, -18.0)
	AttackVFX.spawn_strike(parent, origin + Vector3(0, 1.1, 0), fwd, &"heavy", 3, 0.06, 14.0)

	# Damage: frontal arc, once per enemy.
	var cos_half := cos(deg_to_rad(HALF_ARC_DEG))
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if not FX.is_alive(n):
			continue
		var d: Vector3 = n.global_position - origin
		if absf(d.y) > VERTICAL_TOLERANCE:
			continue
		d.y = 0.0
		var dist := d.length()
		var in_arc := dist <= reach and (dist < 0.6 or d.normalized().dot(fwd) >= cos_half)
		if in_arc or (n == target and dist <= reach + 0.5):
			hit_targets.append(n)
	for n in hit_targets:
		FX.hit(n, damage, stagger, caster, &"")
	Events.camera_shake_requested.emit(0.18, 0.15)


func _build_vfx(reach: float) -> void:
	# One wide horizontal crescent: starts at the blade, sweeps out to `reach`.
	var blade := FX.crescent(self, 1.0, FX.FROST, HALF_ARC_DEG * 2.0, 0.28)
	blade.scale = Vector3.ONE * 0.5
	var mat := blade.material_override as StandardMaterial3D
	var core := FX.crescent(self, 1.0, FX.WHITE, HALF_ARC_DEG * 1.6, 0.12)
	core.scale = Vector3.ONE * 0.45
	core.position = Vector3(0, 0.02, 0)
	var core_mat := core.material_override as StandardMaterial3D
	rotation.z = deg_to_rad(-8.0)  # slight diagonal cut

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(blade, "scale", Vector3.ONE * reach, DURATION * 0.55) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(core, "scale", Vector3.ONE * reach * 0.95, DURATION * 0.5) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "rotation:y", rotation.y + deg_to_rad(20.0), DURATION)
	FX.fade(tw, mat, DURATION)
	FX.fade(tw, core_mat, DURATION * 0.8)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
