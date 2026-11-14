## v5 BB4 — Water Geyser (Taighe, AT_TARGET, no projectile).
## A ring telegraph opens under the target (TELEGRAPH s), then a water column
## erupts: damage + stagger to the target (and anyone standing in the column)
## and a vertical launch through the enemy's public API.
## The column spawns where the target stood when the telegraph opened, so a
## target that dies mid-telegraph still gets a (harmless) eruption.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")

const TELEGRAPH := 0.35
const COLUMN_RADIUS := 1.3
const COLUMN_HEIGHT := 4.2
const LAUNCH_SPEED := 10.0
const COLUMN_TIME := 0.65
## VFX only: dark outline ring sits just outside the bright telegraph ring.
const RING_OUTLINE_SCALE := 1.12
const WALL_HEIGHT := 0.55

var hit_targets: Array = []
var erupted: bool = false
var _caster: Node3D
var _target: Node3D
var _ability: AbilityData


func setup(caster: Node3D, target: Node3D, ability: AbilityData, aim_dir: Vector3) -> void:
	_caster = caster
	_target = target
	_ability = ability
	var centre: Vector3
	if FX.is_alive(target):
		centre = target.global_position
	else:
		# Untargeted (Fire Forward): erupt a few metres along the aim.
		var fwd := aim_dir
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -caster.global_basis.z
		centre = caster.global_position + fwd.normalized() * 5.0
	global_position = centre

	# v6 GG-3 telegraph (VFX only): a dark-outlined, thicker bright ring over a
	# translucent filled disc, so the danger area reads at 10-15 m on grass,
	# cobblestone and pale roofs alike. Same TELEGRAPH timing as v5.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.02
	cyl.radial_segments = 40
	cyl.rings = 1
	disc.mesh = cyl
	disc.position = Vector3(0, 0.04, 0)
	disc.scale = Vector3(0.3, 1.0, 0.3)
	var disc_mat := FX.make_mat(FX.WATER, 2.0, 0.28)
	disc_mat.render_priority = 0
	disc.material_override = disc_mat
	add_child(disc)
	var outline := FX.ring(self, Vector3(0, 0.05, 0), 0.3 * RING_OUTLINE_SCALE, FX.WATER_DEEP, 1.0)
	var outline_mat := outline.material_override as StandardMaterial3D
	outline_mat.albedo_color.a = 0.8
	outline_mat.render_priority = 0
	(outline.mesh as TorusMesh).inner_radius = 0.72
	var ring := FX.ring(self, Vector3(0, 0.07, 0), 0.3, FX.WATER.lerp(FX.WHITE, 0.35), 3.0)
	var ring_mat := ring.material_override as StandardMaterial3D
	ring_mat.albedo_color.a = 0.95
	(ring.mesh as TorusMesh).inner_radius = 0.8
	# Low rising wall at the ring edge: reads at grazing camera angles (10-15 m),
	# where a flat ring collapses to a thin line.
	var wall := MeshInstance3D.new()
	var shell := CylinderMesh.new()
	shell.top_radius = 1.0
	shell.bottom_radius = 1.0
	shell.height = 1.0
	shell.radial_segments = 40
	shell.rings = 1
	shell.cap_top = false
	shell.cap_bottom = false
	wall.mesh = shell
	var wall_mat := FX.make_add_mat(FX.WATER, 2.0, 0.45)
	wall.material_override = wall_mat
	wall.scale = Vector3(0.3, 0.05, 0.3)
	wall.position = Vector3(0, 0.025, 0)
	add_child(wall)
	var tw := create_tween()
	tw.set_parallel(true)
	var r_end := COLUMN_RADIUS + 0.15
	tw.tween_property(wall, "scale", Vector3(r_end, WALL_HEIGHT, r_end), TELEGRAPH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(wall, "position:y", WALL_HEIGHT * 0.5, TELEGRAPH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "scale", Vector3(r_end, 0.35, r_end), TELEGRAPH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(outline, "scale", Vector3(r_end * RING_OUTLINE_SCALE, 0.3, r_end * RING_OUTLINE_SCALE), TELEGRAPH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(disc, "scale", Vector3(r_end, 1.0, r_end), TELEGRAPH) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(false)
	tw.tween_callback(_erupt)
	tw.tween_interval(0.15)
	tw.set_parallel(true)
	FX.fade(tw, ring_mat, 0.3, 0.95)
	FX.fade(tw, outline_mat, 0.3, 0.8)
	FX.fade(tw, disc_mat, 0.25, 0.28)
	FX.fade(tw, wall_mat, 0.2, 0.45)


func _erupt() -> void:
	erupted = true
	# Water column (cylinder) shooting up from the ground.
	var col := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = COLUMN_RADIUS * 0.7
	cyl.bottom_radius = COLUMN_RADIUS
	cyl.height = 1.0
	cyl.radial_segments = 20
	col.mesh = cyl
	var mat := FX.make_mat(FX.WATER, 2.6, 0.7)
	col.material_override = mat
	col.scale = Vector3(1.0, 0.05, 1.0)
	col.position = Vector3(0, 0.025, 0)
	add_child(col)
	var core := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = COLUMN_RADIUS * 0.3
	cyl2.bottom_radius = COLUMN_RADIUS * 0.45
	cyl2.height = 1.0
	core.mesh = cyl2
	var core_mat := FX.make_mat(FX.WHITE, 4.0, 0.8)
	core.material_override = core_mat
	core.scale = col.scale
	add_child(core)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(col, "scale", Vector3(1.0, COLUMN_HEIGHT, 1.0), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(col, "position:y", COLUMN_HEIGHT * 0.5, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(core, "scale", Vector3(1.0, COLUMN_HEIGHT * 1.1, 1.0), 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(core, "position:y", COLUMN_HEIGHT * 0.55, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.chain()
	FX.fade(tw, mat, COLUMN_TIME, 0.7)
	FX.fade(tw, core_mat, COLUMN_TIME * 0.7, 0.8)
	tw.tween_property(col, "scale:x", 0.4, COLUMN_TIME)
	tw.tween_property(col, "scale:z", 0.4, COLUMN_TIME)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
	_splash_vfx()

	# Damage + launch: the chosen target plus anyone inside the column.
	var damage: float = _ability.damage if _ability else 30.0
	var stagger: float = _ability.stagger if _ability else 20.0
	var victims: Array = FX.enemies_near(get_tree(), global_position, COLUMN_RADIUS + 0.2, 2.0)
	if FX.is_alive(_target) and not victims.has(_target):
		var d := _target.global_position - global_position
		d.y = 0.0
		if d.length() <= COLUMN_RADIUS + 1.5:  # stepped slightly during the telegraph
			victims.append(_target)
	for v in victims:
		if FX.hit(v, damage, stagger, _caster, &""):
			hit_targets.append(v)
			FX.launch(v, LAUNCH_SPEED)
	Events.camera_shake_requested.emit(0.12, 0.12)


## v6 GG-3 (VFX only): eruption accents that read from 10-15 m — a ground
## splash ring rushing outward and a white foam crown riding the column top.
func _splash_vfx() -> void:
	var splash := FX.ring(self, Vector3(0, 0.08, 0), COLUMN_RADIUS, FX.WHITE.lerp(FX.WATER, 0.25), 3.0)
	var splash_mat := FX.make_add_mat(FX.WHITE.lerp(FX.WATER, 0.25), 3.0, 0.85)
	splash.material_override = splash_mat
	var crown := FX.ring(self, Vector3(0, 0.3, 0), COLUMN_RADIUS * 0.75, FX.WHITE, 3.0)
	var crown_mat := FX.make_add_mat(FX.WHITE, 3.0, 0.8)
	crown.material_override = crown_mat
	crown.scale = Vector3(COLUMN_RADIUS * 0.75, 0.6, COLUMN_RADIUS * 0.75)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(splash, "scale", Vector3(COLUMN_RADIUS * 2.2, 0.15, COLUMN_RADIUS * 2.2), 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	FX.fade(tw, splash_mat, 0.35, 0.85)
	tw.tween_property(crown, "position:y", COLUMN_HEIGHT, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(crown, "scale", Vector3(COLUMN_RADIUS * 1.2, 0.8, COLUMN_RADIUS * 1.2), 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	FX.fade(tw, crown_mat, 0.45, 0.8)
