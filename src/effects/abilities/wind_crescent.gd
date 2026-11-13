## v5 BB5 — Wind Crescent (Taighe, AT_TARGET, no projectile).
## Three crescent air blades appear above/around the target, then slash
## through it in sequence: one hit each (multi-hit), light stagger per hit.
## Blades follow the target while it is alive; afterwards they keep its last
## position.
extends Node3D

const FX := preload("res://src/effects/abilities/ability_fx.gd")

const BLADES := 3
const APPEAR := 0.22          # blades fade in above the target
const INTERVAL := 0.14        # between slashes
const SLASH_TIME := 0.12      # one blade crossing the target
const ORBIT_RADIUS := 1.7
const ORBIT_HEIGHT := 2.4
const HIT_RADIUS := 1.4

var hit_count: int = 0
var hit_log: Array = []       # [enemy, ...] one entry per landed hit
var _caster: Node3D
var _target: Node3D
var _ability: AbilityData
var _centre: Vector3
var _blades: Array = []       # MeshInstance3D (never typed: 4.6 leak rule)


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
		var start := Vector3(cos(ang) * ORBIT_RADIUS, ORBIT_HEIGHT + 0.25 * i, sin(ang) * ORBIT_RADIUS)
		var blade := FX.crescent(self, 0.95, FX.WIND, 140.0, 0.3)
		blade.position = start
		# Face the blade's concave side toward the target's chest.
		blade.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)
		blade.scale = Vector3.ONE * 0.2
		var mat := blade.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.0
		_blades.append(blade)
		var t_appear := create_tween()
		t_appear.set_parallel(true)
		t_appear.tween_property(blade, "scale", Vector3.ONE * 0.95, APPEAR).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t_appear.tween_property(mat, "albedo_color:a", 0.85, APPEAR)
	tw.tween_interval(APPEAR)
	for i in BLADES:
		tw.tween_callback(_slash.bind(i))
		tw.tween_interval(INTERVAL)
	tw.tween_interval(SLASH_TIME + 0.1)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	# Track the live target so blades land where it is now.
	if FX.is_alive(_target):
		_centre = _target.global_position
		global_position = _centre


func _slash(i: int) -> void:
	if i >= _blades.size():
		return
	var blade: MeshInstance3D = _blades[i]
	if not is_instance_valid(blade):
		return
	var start: Vector3 = blade.position
	var through := Vector3(-start.x, 0.3, -start.z)  # cut down through the body
	var mat := blade.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(blade, "position", through, SLASH_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(blade, "scale", Vector3.ONE * 1.3, SLASH_TIME)
	tw.chain()
	FX.fade(tw, mat, 0.15)

	var damage: float = (_ability.damage if _ability else 24.0) / float(BLADES)
	var stagger: float = _ability.stagger if _ability else 6.0
	var victims: Array = FX.enemies_near(get_tree(), _centre, HIT_RADIUS, 2.5)
	if FX.is_alive(_target) and not victims.has(_target):
		victims.append(_target)
	for v in victims:
		if FX.hit(v, damage, stagger, _caster, &""):
			hit_count += 1
			hit_log.append(v)
