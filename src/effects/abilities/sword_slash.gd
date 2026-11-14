## v5 BB3 — Sword Slash (Amaro, 0 MP, 1 ATB segment).
## A wide frontal energy crescent toward the target (~3.5 m reach). Hits every
## living enemy inside the frontal arc once (the chosen target is always
## included when within reach). Moderate damage, good stagger.
## VFX (v6 GG-1): a translucent ADDITIVE crescent sweep (unshaded, additive
## blend, no depth write) with a fading trail, plus a thin white core near the
## blade and a quick hit flash on each enemy hit. Everything fades out within
## FX_FADE (<= 0.25 s). No opaque ring: the target stays readable through it.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")

const REACH := 3.5
## Half-angle of the frontal arc (degrees).
const HALF_ARC_DEG := 75.0
const VERTICAL_TOLERANCE := 2.0
## Lifetime of the effect node (unchanged from v5; tests read hit_targets
## until the Ability state ends). The visuals are gone after FX_FADE.
const DURATION := 0.42

# --- VFX only (no gameplay effect) ---
const FX_FADE := 0.24          # all visuals fully faded by this time
const SWEEP_TIME := 0.11       # head travels from left to right
const TRAIL_ARC_DEG := 120.0   # visible ribbon length (tail fades to 0)
const SWEEP_FROM_DEG := -55.0  # head angle at start (negative = left of aim)
const SWEEP_TO_DEG := 50.0     # head angle at end (wider swings toward the camera)
const ROLL_DEG := -8.0         # slight diagonal cut
const FLASH_DELAY := 0.05

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

	_build_vfx(reach, fwd)


func _build_vfx(reach: float, fwd: Vector3) -> void:
	# Sweep pivot: rotating it by -angle advances the ribbon head toward +angle
	# (right of the aim), see FX.trail_arc_mesh.
	var sweep := Node3D.new()
	sweep.name = "Sweep"
	sweep.rotation.z = deg_to_rad(ROLL_DEG)
	add_child(sweep)
	var half := TRAIL_ARC_DEG * 0.5
	var phi_from := deg_to_rad(half - SWEEP_FROM_DEG)
	var phi_to := deg_to_rad(half - SWEEP_TO_DEG)

	var arm := Node3D.new()
	arm.rotation.y = phi_from
	sweep.add_child(arm)

	# Outer crescent: wide Frost ribbon out to ~reach (passes through the target).
	var outer := MeshInstance3D.new()
	outer.name = "SlashTrail"
	outer.mesh = FX.trail_arc_mesh(TRAIL_ARC_DEG, 0.16)
	outer.scale = Vector3.ONE * reach * 0.62
	var outer_mat := FX.make_add_mat(FX.FROST, 2.4, 0.6, true)
	outer.material_override = outer_mat
	arm.add_child(outer)
	# Bright thin edge on the outer rim (the "blade" of the crescent).
	var edge := MeshInstance3D.new()
	edge.name = "SlashEdge"
	edge.mesh = FX.trail_arc_mesh(TRAIL_ARC_DEG * 0.8, 0.035)
	edge.scale = outer.scale * 1.005
	edge.rotation.y = -deg_to_rad(TRAIL_ARC_DEG * 0.1)  # align heads
	var edge_mat := FX.make_add_mat(FX.WHITE, 3.0, 0.9, true)
	edge.material_override = edge_mat
	arm.add_child(edge)
	# Inner core near the sword: short white ribbon.
	var core := MeshInstance3D.new()
	core.name = "SlashCore"
	core.mesh = FX.trail_arc_mesh(TRAIL_ARC_DEG * 0.7, 0.12)
	core.scale = Vector3.ONE * 1.5
	core.rotation.y = -deg_to_rad(TRAIL_ARC_DEG * 0.15)
	var core_mat := FX.make_add_mat(FX.WHITE.lerp(FX.FROST, 0.4), 2.0, 0.6, true)
	core.material_override = core_mat
	arm.add_child(core)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(arm, "rotation:y", phi_to, SWEEP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(outer, "scale", Vector3.ONE * reach * 0.9, SWEEP_TIME * 1.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(edge, "scale", Vector3.ONE * reach * 0.9 * 1.005, SWEEP_TIME * 1.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Hold full brightness through the sweep, then fade out by FX_FADE.
	var tail := FX_FADE - SWEEP_TIME * 0.8
	tw.tween_method(_fade_mats.bind([outer_mat, edge_mat, core_mat], [0.6, 0.9, 0.6]),
		1.0, 0.0, tail).set_delay(SWEEP_TIME * 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(sweep.queue_free).set_delay(FX_FADE + 0.01)
	tw.set_parallel(false)
	tw.tween_interval(maxf(0.0, DURATION - FX_FADE - 0.01))
	tw.tween_callback(queue_free)

	# A quick flash on each enemy hit, as the head crosses it.
	if not hit_targets.is_empty():
		var t2 := create_tween()
		t2.tween_interval(FLASH_DELAY)
		t2.tween_callback(_flash_hits.bind(fwd))


func _fade_mats(k: float, mats: Array, alphas: Array) -> void:
	for i in mats.size():
		var m: StandardMaterial3D = mats[i]
		m.albedo_color.a = float(alphas[i]) * k


func _flash_hits(fwd: Vector3) -> void:
	var across := fwd.cross(Vector3.UP).normalized()  # aim-right: the sweep direction
	for n in hit_targets:
		if not FX.is_alive(n):
			continue
		var p: Vector3 = (n as Node3D).global_position + Vector3(0, 1.0, 0)
		FX.hit_flash(get_parent(), p, FX.FROST, 1.0, across + Vector3(0, -0.15, 0))
