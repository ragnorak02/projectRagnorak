## Arcane Stance projectile (battle v3, Package S): small orb or large fireball.
## Extends the Fire Bolt projectile (spell_projectile.gd) through its extension
## hooks. Damage is applied directly (take_damage, then add_stagger when the
## enemy has it), never through the hurtbox "damage" meta, so it lands once.
##
## Usage (before add_child, because _ready builds the mesh/area):
##   var orb = ArcaneOrb.create(ArcaneOrb.Kind.ORB)   # or Kind.FIREBALL
##   orb.source = player
##   parent.add_child(orb)
class_name ArcaneOrb
extends "res://src/effects/spell_projectile.gd"

enum Kind { ORB, FIREBALL }

const ORB_DAMAGE := 6.0
const ORB_STAGGER := 4.0
const FIREBALL_DAMAGE := 25.0
const FIREBALL_STAGGER := 20.0
const FIREBALL_BURST_RADIUS := 2.5

var kind: Kind = Kind.ORB
var stagger_amount: float = ORB_STAGGER
## 0 = single target. > 0 = AoE burst on impact (or on expiry).
var burst_radius: float = 0.0
## Damage source passed to take_damage (the caster).
var source: Node3D = null

## Debug/test counters (read by headless checks).
var hits_applied: int = 0


static func create(p_kind: Kind) -> ArcaneOrb:
	var p := ArcaneOrb.new()
	p.configure(p_kind)
	return p


func configure(p_kind: Kind) -> void:
	kind = p_kind
	use_hurtbox_meta = false
	if kind == Kind.FIREBALL:
		name = "ArcaneFireball"
		_damage = FIREBALL_DAMAGE
		stagger_amount = FIREBALL_STAGGER
		burst_radius = FIREBALL_BURST_RADIUS
		speed = 16.0
		lifetime = 2.0
		homing_strength = 2.5
		hit_radius = 0.6
		visual_radius = 0.45
		core_color = Color(1.0, 0.55, 0.15, 1.0)
		glow_color = Color(1.0, 0.35, 0.05)
		glow_energy = 4.5
	else:
		name = "ArcaneOrb"
		_damage = ORB_DAMAGE
		stagger_amount = ORB_STAGGER
		burst_radius = 0.0
		speed = 28.0
		lifetime = 1.2
		homing_strength = 4.0
		hit_radius = 0.3
		visual_radius = 0.12
		core_color = Color(0.7, 0.95, 1.0, 1.0)
		glow_color = Color(0.3, 0.85, 1.0)
		glow_energy = 3.5


func get_damage() -> float:
	return _damage


func _on_hit(area: Area3D) -> void:
	if _hit:
		return
	var enemy := _enemy_from(area)
	if enemy == null:
		return  # Not an enemy hurtbox (or a dead one): keep flying.
	_hit = true
	_apply_to(enemy)
	if burst_radius > 0.0:
		_burst(global_position, enemy)
	_fade_out()


func _on_expired() -> void:
	if _hit:
		return
	_hit = true
	if burst_radius > 0.0:
		_burst(global_position)
	_fade_out()


## Damage + stagger every other live enemy within burst_radius, once each
## (`exclude` = the directly hit enemy, already damaged).
func _burst(center: Vector3, exclude: Node = null) -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e == exclude or not (e is Node3D) or not _is_live_enemy(e):
			continue
		var aim: Vector3 = (e as Node3D).global_position + Vector3(0, 1.0, 0)
		if aim.distance_to(center) <= burst_radius + 0.5:
			_apply_to(e)
	_spawn_burst_vfx(center)


func _apply_to(enemy: Node) -> void:
	enemy.take_damage(_damage, source)
	if stagger_amount > 0.0 and enemy.has_method("add_stagger"):
		enemy.add_stagger(stagger_amount)
	hits_applied += 1
	if DebugFlags.DEBUG_COMBAT:
		print("ArcaneOrb: %s hit %s for %.0f (stagger %.0f)" % [name, enemy.name, _damage, stagger_amount])


func _enemy_from(area: Area3D) -> Node:
	var n: Node = area
	while n != null:
		if n.is_in_group(&"enemies") and n.has_method("take_damage"):
			return n if _is_live_enemy(n) else null
		n = n.get_parent()
	return null


func _is_live_enemy(e: Node) -> bool:
	if not e.has_method("take_damage"):
		return false
	var dead = e.get("_is_dead")
	return not (dead is bool and dead)


func _fade_out() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.12)
	tween.tween_callback(queue_free)


func _spawn_burst_vfx(center: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := MeshInstance3D.new()
	fx.name = "FireballBurst"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	fx.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 3.0
	fx.material_override = mat
	parent.add_child(fx)
	fx.global_position = center
	fx.scale = Vector3.ONE * 0.2
	var tw := fx.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE * burst_radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(fx.queue_free)
