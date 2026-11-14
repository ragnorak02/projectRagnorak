## v5 BB5 — Wind Crescent (Taighe, AT_TARGET, no projectile).
## Three crescent air blades appear above/around the target, then slash
## through it in sequence: one hit each (multi-hit), light stagger per hit.
## Blades follow the target while it is alive; afterwards they keep its last
## position.
## VFX (v6 GG-2): blades ~2x bigger with a dark teal outline (contrast over sky
## and roofs), a bright core and an additive white rim; each slash leaves fading
## afterimages and every landed hit pops a hit flash on the target. Timing,
## damage and hit radius are unchanged from v5.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")

const BLADES := 3
const APPEAR := 0.22          # blades fade in above the target
const INTERVAL := 0.14        # between slashes
const SLASH_TIME := 0.12      # one blade crossing the target
const ORBIT_RADIUS := 1.7
const ORBIT_HEIGHT := 2.4
const HIT_RADIUS := 1.4

# --- VFX only (no gameplay effect) ---
const BLADE_SCALE := 1.9      # v5 was 0.95
const VFX_ORBIT_RADIUS := 2.3 # bigger blades sit a little wider/higher
const VFX_ORBIT_HEIGHT := 2.9
const CORE_ALPHA := 0.95
const AFTERIMAGES := 2
const FLASH_DELAY := 0.07     # the blade reaches the body ~60% into SLASH_TIME

var hit_count: int = 0
var hit_log: Array = []       # [enemy, ...] one entry per landed hit
var _caster: Node3D
var _target: Node3D
var _ability: AbilityData
var _centre: Vector3
var _blades: Array = []       # Node3D blade roots (never typed: 4.6 leak rule)
var _blade_mats: Array = []   # [[core_mat, outline_mat, rim_mat], ...] per blade


func setup(caster: Node3D, target: Node3D, ability: AbilityData, aim_dir: Vector3) -> void:
	_caster = caster
	_target = target
	_ability = ability
	if FX.is_alive(target):
		_centre = target.global_position
	else:
		var fwd := aim_dir
		fwd.y = 0.0
		if fwd.length_squared() < 0.001:
			fwd = -caster.global_basis.z
		_centre = caster.global_position + fwd.normalized() * 5.0
	global_position = _centre

	var tw := create_tween()
	for i in BLADES:
		var ang := TAU * float(i) / float(BLADES) + 0.4
		var start := Vector3(cos(ang) * VFX_ORBIT_RADIUS, VFX_ORBIT_HEIGHT + 0.3 * i, sin(ang) * VFX_ORBIT_RADIUS)
		var blade := _make_blade()
		blade.position = start
		# Face the blade's concave side toward the target's chest.
		blade.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)
		blade.scale = Vector3.ONE * 0.2 * BLADE_SCALE
		var mats: Array = _blade_mats[_blade_mats.size() - 1]
		var t_appear := create_tween()
		t_appear.set_parallel(true)
		t_appear.tween_property(blade, "scale", Vector3.ONE * BLADE_SCALE, APPEAR).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t_appear.tween_method(_set_blade_alpha.bind(mats), 0.0, 1.0, APPEAR)
	tw.tween_interval(APPEAR)
	for i in BLADES:
		tw.tween_callback(_slash.bind(i))
		tw.tween_interval(INTERVAL)
	tw.tween_interval(SLASH_TIME + 0.1)
	tw.tween_callback(queue_free)


## Blade = dark outline crescent behind a bright core, plus a thin additive rim.
func _make_blade() -> Node3D:
	var root := Node3D.new()
	root.name = "WindBlade"
	add_child(root)
	var outline := FX.crescent(root, 1.06, FX.WIND_DEEP, 150.0, 0.42)
	var outline_mat := outline.material_override as StandardMaterial3D
	outline_mat.render_priority = 0
	outline.position = Vector3(0, -0.01, 0)
	var core := FX.crescent(root, 1.0, FX.WIND, 140.0, 0.3)
	var core_mat := core.material_override as StandardMaterial3D
	core_mat.emission_energy_multiplier = 6.0
	var rim := MeshInstance3D.new()
	rim.mesh = FX.arc_mesh(130.0, 0.07)
	rim.scale = Vector3.ONE * 1.005
	rim.position = Vector3(0, 0.01, 0)
	var rim_mat := FX.make_add_mat(FX.WHITE, 3.0, 0.9)
	rim.material_override = rim_mat
	root.add_child(rim)
	_blades.append(root)
	_blade_mats.append([core_mat, outline_mat, rim_mat])
	_set_blade_alpha(0.0, _blade_mats[_blade_mats.size() - 1])
	return root


func _set_blade_alpha(k: float, mats: Array) -> void:
	(mats[0] as StandardMaterial3D).albedo_color.a = CORE_ALPHA * k
	(mats[1] as StandardMaterial3D).albedo_color.a = 0.7 * k
	(mats[2] as StandardMaterial3D).albedo_color.a = 0.9 * k


func _process(_delta: float) -> void:
	# Track the live target so blades land where it is now.
	if FX.is_alive(_target):
		_centre = _target.global_position
		global_position = _centre


func _slash(i: int) -> void:
	if i >= _blades.size():
		return
	var blade: Node3D = _blades[i]
	if not is_instance_valid(blade):
		return
	var start: Vector3 = blade.position
	var through := Vector3(-start.x * 0.75, 0.3, -start.z * 0.75)  # cut down through the body
	var mats: Array = _blade_mats[i]
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(blade, "position", through, SLASH_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(blade, "scale", Vector3.ONE * BLADE_SCALE * 1.25, SLASH_TIME)
	tw.chain()
	tw.tween_method(_set_blade_alpha.bind(mats), 1.0, 0.0, 0.15)
	# Afterimages along the cut (the trail).
	for k in AFTERIMAGES:
		var tk := create_tween()
		tk.tween_interval(SLASH_TIME * float(k + 1) / float(AFTERIMAGES + 1))
		tk.tween_callback(_afterimage.bind(blade, k))

	var damage: float = (_ability.damage if _ability else 24.0) / float(BLADES)
	var stagger: float = _ability.stagger if _ability else 6.0
	var victims: Array = FX.enemies_near(get_tree(), _centre, HIT_RADIUS, 2.5)
	if FX.is_alive(_target) and not victims.has(_target):
		victims.append(_target)
	var flash_at: Array = []  # chest positions at hit time (flash even on a kill)
	for v in victims:
		var chest: Vector3 = (v as Node3D).global_position + Vector3(0, 1.0, 0) if FX.is_alive(v) else Vector3.ZERO
		if FX.hit(v, damage, stagger, _caster, &""):
			hit_count += 1
			hit_log.append(v)
			flash_at.append(chest)
	if not flash_at.is_empty():
		var cut := (through - start)
		var tf := create_tween()
		tf.tween_interval(FLASH_DELAY)
		tf.tween_callback(_flash.bind(flash_at, cut))


## A ghost copy of the blade at its current pose that fades quickly.
func _afterimage(blade: Node3D, k: int) -> void:
	if not is_instance_valid(blade) or not is_inside_tree():
		return
	var ghost := MeshInstance3D.new()
	ghost.mesh = FX.arc_mesh(140.0, 0.3)
	var mat := FX.make_add_mat(FX.WIND, 2.0, 0.45 - 0.12 * k)
	ghost.material_override = mat
	add_child(ghost)
	ghost.transform = blade.transform
	var tw := ghost.create_tween()
	FX.fade(tw, mat, 0.12, mat.albedo_color.a)
	tw.tween_callback(ghost.queue_free)


func _flash(points: Array, cut: Vector3) -> void:
	for p in points:
		FX.hit_flash(get_parent(), p, FX.WIND, 1.3, cut)
