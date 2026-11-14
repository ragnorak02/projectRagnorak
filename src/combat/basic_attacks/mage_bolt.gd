## v6 HH — mage basic-attack projectile (Taighe's X kit).
##
## One node per strike: quick bolt (light), charged shot (heavy) or the step-3
## finisher orb (burst_radius > 0). Lifecycle:
##   var bolt = MageBolt.create(params)   # before add_child
##   parent.add_child(bolt); bolt.hold_at(hand)   # charging glow (optional)
##   bolt.launch(dir, target)             # at the strike's fire time
##   bolt.fizzle()                        # strike cancelled before launch
##
## Hits are a deterministic distance query over the "enemies" group every
## physics frame (no physics-overlap timing): the nearest live enemy whose
## body column (flat distance <= radius + ENEMY_RADIUS, height within the
## body) contains the bolt. Damage is applied directly (take_damage, then
## add_stagger), exactly once. A finisher orb detonates on impact or at the end
## of its range through BlastVFX.detonate (each enemy in radius once) and may
## request a camera shake via Events.camera_shake_requested.
## Moves in game time: hit-stop and the Command Menu's 0.05 slow it like any
## other projectile; visuals fade with tweens in game time too.
extends Node3D

const BlastVFX = preload("res://src/effects/blast_vfx.gd")

## Approximate enemy body radius / height for the hit column.
const ENEMY_RADIUS := 0.55
const ENEMY_HEIGHT := 2.6
## Aim point above the target's origin.
const AIM_HEIGHT := 1.0

var source: Node3D = null
var target: Node3D = null
var damage: float = 9.0
var stagger: float = 6.0
var speed: float = 30.0
var lifetime: float = 0.6
var homing: float = 6.0
var radius: float = 0.3
## > 0: finisher orb (AoE burst on impact / expiry).
var burst_radius: float = 0.0
var shake: Array = []
var hit_kind: StringName = &""
var core_color: Color = Color(0.85, 0.97, 1.0, 1.0)
var glow_color: Color = Color(0.35, 0.8, 1.0, 1.0)

## Read by tests / debug.
var launched: bool = false
var hits_applied: int = 0
var burst_hits: int = 0
var done: bool = false

var _dir: Vector3 = Vector3.FORWARD
var _timer: float = 0.0
var _pivot: Node3D = null
var _core: MeshInstance3D = null
var _tail: MeshInstance3D = null
var _core_mat: StandardMaterial3D = null


## params: damage, stagger, speed, lifetime, homing, radius, burst_radius,
## shake, hit_kind, core_color, glow_color, source.
static func create(params: Dictionary) -> Node3D:
	var b: Node3D = (load("res://src/combat/basic_attacks/mage_bolt.gd") as GDScript).new()
	b.name = "MageBolt"
	for k in params:
		if k in b:
			b.set(k, params[k])
	return b


func _ready() -> void:
	_build_visual()
	scale = Vector3.ONE * 0.35


## Charging: follow the caster's hand until launch (grows to full size).
func hold_at(pos: Vector3) -> void:
	if launched or done:
		return
	global_position = pos
	scale = scale.lerp(Vector3.ONE, 0.25)


func launch(dir: Vector3, p_target: Node3D) -> void:
	if done:
		return
	launched = true
	target = p_target if _is_live(p_target) else null
	scale = Vector3.ONE
	if target:
		var to := _aim_point(target) - global_position
		if to.length() > 0.05:
			dir = to
	_dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	_orient()


## Cancelled before launch (dodge / flinch): vanish without damage.
func fizzle() -> void:
	if done:
		return
	done = true
	queue_free()


func _physics_process(delta: float) -> void:
	if done or not launched:
		return
	_timer += delta
	if target and _is_live(target):
		var to := (_aim_point(target) - global_position).normalized()
		_dir = _dir.lerp(to, clampf(homing * delta, 0.0, 1.0)).normalized()
	var step := _dir * speed * delta
	# Sub-step so a fast bolt cannot tunnel through a body.
	var n := maxi(1, ceili(step.length() / 0.35))
	for i in n:
		global_position += step / float(n)
		var hit := _find_hit()
		if hit:
			_impact(hit)
			return
	_orient()
	if _timer >= lifetime:
		if burst_radius > 0.0:
			_detonate(global_position, null)
		_fade_out()


# --- Internals ---

func _find_hit() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or not _is_live(n):
			continue
		var dy := global_position.y - n.global_position.y
		if dy < -0.3 or dy > ENEMY_HEIGHT:
			continue
		var flat := Vector2(global_position.x - n.global_position.x, global_position.z - n.global_position.z).length()
		if flat <= radius + ENEMY_RADIUS and flat < best_d:
			best_d = flat
			best = n
	return best


func _impact(enemy: Node3D) -> void:
	if burst_radius > 0.0:
		var centre := enemy.global_position
		centre.y = global_position.y
		_detonate(centre, enemy)
	else:
		_apply(enemy)
		_spawn_spark(global_position, false)
	_fade_out()


func _apply(enemy: Node3D) -> void:
	if not _is_live(enemy):
		return
	if enemy.get_method_argument_count(&"take_damage") >= 3:
		enemy.take_damage(damage, source, hit_kind)
	else:
		enemy.take_damage(damage, source)
	if is_instance_valid(enemy) and stagger > 0.0 and enemy.has_method("add_stagger"):
		enemy.add_stagger(stagger)
	hits_applied += 1
	Events.attack_hit.emit(enemy, damage)


func _detonate(centre: Vector3, _direct: Node3D) -> void:
	var src: Node3D = source if source and is_instance_valid(source) and source.is_inside_tree() else self
	burst_hits = BlastVFX.detonate(src, centre, burst_radius, damage, stagger)
	hits_applied += burst_hits
	_spawn_spark(centre, true)
	if shake.size() == 2:
		Events.camera_shake_requested.emit(float(shake[0]), float(shake[1]))


func _fade_out() -> void:
	done = true
	if _tail:
		_tail.visible = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.1)
	tw.tween_callback(queue_free)


func _is_live(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not n.has_method("take_damage"):
		return false
	if not (n as Node3D) or not (n as Node3D).is_inside_tree():
		return false
	var dead = n.get("_is_dead")
	return not (dead is bool and dead)


func _aim_point(n: Node3D) -> Vector3:
	return n.global_position + Vector3(0, AIM_HEIGHT, 0)


func _orient() -> void:
	if _dir.length() < 0.01 or not is_inside_tree():
		return
	var up := Vector3.UP if absf(_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	# The root is never rotated (only scaled), so the pivot's local basis is
	# its world orientation.
	if _pivot:
		_pivot.basis = Basis.looking_at(_dir, up)


func _build_visual() -> void:
	var size := radius
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_core_mat = _make_mat(core_color, glow_color, 4.0 if burst_radius <= 0.0 else 6.0, 1.0)
	_core = MeshInstance3D.new()
	_core.name = "Core"
	var sphere := SphereMesh.new()
	sphere.radius = size * 0.6
	sphere.height = size * 1.2
	sphere.radial_segments = 16
	sphere.rings = 8
	_core.mesh = sphere
	_core.material_override = _core_mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_core)
	# Glow shell (additive, larger, faint).
	var shell := MeshInstance3D.new()
	shell.name = "Glow"
	var s2 := SphereMesh.new()
	s2.radius = size
	s2.height = size * 2.0
	s2.radial_segments = 16
	s2.rings = 8
	shell.mesh = s2
	shell.material_override = _make_mat(glow_color, glow_color, 2.5, 0.35)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(shell)
	# Tail streak behind the bolt (+Z is "behind" when facing -Z).
	_tail = MeshInstance3D.new()
	_tail.name = "Tail"
	var cyl := CylinderMesh.new()
	cyl.top_radius = size * 0.05
	cyl.bottom_radius = size * 0.45
	cyl.height = size * 5.0
	cyl.radial_segments = 8
	_tail.mesh = cyl
	_tail.rotation_degrees = Vector3(-90, 0, 0)
	_tail.position = Vector3(0, 0, size * 2.5)
	_tail.material_override = _make_mat(glow_color, glow_color, 2.0, 0.45)
	_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_tail)


## Impact spark (bolt) or burst ring + flash (finisher). Freed automatically.
func _spawn_spark(pos: Vector3, big: bool) -> void:
	var parent := get_parent()
	if parent == null or not parent.is_inside_tree():
		return
	var fx := Node3D.new()
	fx.name = "MageBoltImpact"
	parent.add_child(fx)
	fx.global_position = pos
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	flash.mesh = sm
	# Translucent additive flash (finisher: faint and glow-tinted so the target
	# stays readable through it).
	var fmat := _make_mat(glow_color if big else core_color, glow_color, 1.2 if big else 4.0, 0.22 if big else 0.7)
	flash.material_override = fmat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r := (burst_radius * 0.3) if big else maxf(radius * 1.6, 0.35)
	flash.scale = Vector3.ONE * r * 0.3
	fx.add_child(flash)
	var dur := 0.35 + (burst_radius * 0.05 if big else 0.0)
	var tw := fx.create_tween()
	# Impact flash fades in real time so it can't linger ~7 s over the target
	# while the Command Menu slows time to 5% (v6 LL finding).
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * r, dur * 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(fmat, "albedo_color:a", 0.0, dur)
	if big:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.88
		torus.outer_radius = 1.0
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.position = Vector3(0, -0.8, 0)
		ring.scale = Vector3(0.2, 0.3, 0.2)
		var rmat := _make_mat(glow_color, glow_color, 4.0, 0.85)
		ring.material_override = rmat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx.add_child(ring)
		tw.tween_property(ring, "scale", Vector3(burst_radius, 0.3, burst_radius), dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(rmat, "albedo_color:a", 0.0, dur)
	tw.set_parallel(false)
	tw.tween_callback(fx.queue_free)


static func _make_mat(albedo: Color, emission: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


## Soft aim: the lock-on target when `caster` is locked on, else the nearest live
## enemy inside the forward cone (dot >= min_dot) within max_range. Deterministic
## (nearest wins; ties keep group order). null = fire straight ahead.
static func pick_target(caster: Node3D, max_range: float, min_dot: float) -> Node3D:
	if caster == null or not caster.is_inside_tree():
		return null
	if bool(caster.get(&"is_locked_on")):
		var lt = caster.get(&"lock_on_target")
		if lt is Node3D and is_instance_valid(lt):
			return lt
	var fwd := -caster.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var best: Node3D = null
	var best_d := INF
	for e in caster.get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or not is_instance_valid(n) or not n.has_method("take_damage"):
			continue
		var dead = n.get("_is_dead")
		if dead is bool and dead:
			continue
		var to := n.global_position - caster.global_position
		to.y = 0.0
		var d := to.length()
		if d > max_range or d < 0.01:
			continue
		if to.normalized().dot(fwd) < min_dot:
			continue
		if d < best_d:
			best_d = d
			best = n
	return best
