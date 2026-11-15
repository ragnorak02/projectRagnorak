## TrainingEnemy (Battle Test) — an EnemyBase that never fights back.
## Applied to an enemy.tscn instance with set_script() before add_child, so the
## body, hurtbox, stagger, health bar and damage numbers are the real ones.
##  - passive: never aggros and never attacks. Hits still flinch it and stagger
##    still breaks it, so combos, Battle Mode and stagger windows all work.
##  - invincible: HP is topped back up after every hit (damage numbers still
##    show the real value); it can never die.
##  - leash_radius > 0: wanders slowly inside that radius around `home` and
##    walks back whenever it is knocked out of it. 0 = stands on `home` and only
##    walks back if pushed more than 1.5 m away.
extends EnemyBase

var passive: bool = true
var invincible: bool = false
## Centre of its area. INF = take the position on the first physics frame.
var home: Vector3 = Vector3.INF
var leash_radius: float = 0.0
var wander_speed: float = 1.4

var _wander_target: Vector3 = Vector3.INF
var _wander_wait: float = 0.0
var _wander_step: int = 0


func _ready() -> void:
	super._ready()
	# The AI companion ignores these (companion_ai._find_nearest_enemy).
	add_to_group(&"training_targets")
	# Model-less training targets (the dummy) get a straw colour instead of
	# the red enemy capsule, so they don't read as hostile.
	if rigless_model == null and passive:
		_original_color = Color(0.76, 0.62, 0.38)
		_set_body_color(_original_color)


func take_damage(amount: float, source: Node3D = null, hit_kind: StringName = &"") -> void:
	if invincible:
		# Never let a single hit reach 0 HP, then refill after the hit lands.
		current_hp = max_hp
		amount = minf(amount, max_hp - 1.0)
	super.take_damage(amount, source, hit_kind)
	if invincible and not _is_dead:
		current_hp = max_hp
		_update_health_bar()


func _on_aggro_body_entered(body: Node3D) -> void:
	if passive:
		return
	super._on_aggro_body_entered(body)


func _enter_attack_telegraph() -> void:
	if passive:
		ai_state = AIState.IDLE
		return
	super._enter_attack_telegraph()


func _process_chase(delta: float) -> void:
	# HURT and STAGGERED hand over to CHASE when they end; a passive enemy
	# goes back to idling (and wandering) instead.
	if passive:
		ai_state = AIState.IDLE
		_wander_wait = 0.8
		return
	super._process_chase(delta)


func _process_idle(delta: float) -> void:
	if not passive:
		super._process_idle(delta)
		return
	if not home.is_finite():
		home = global_position
	var to_home := home - global_position
	to_home.y = 0.0
	var max_dist := leash_radius if leash_radius > 0.0 else 1.5
	if to_home.length() > max_dist:
		_move_toward(home, delta)
		_wander_target = Vector3.INF
		return
	if leash_radius <= 0.0:
		_stop()
		return
	# Wander: pick points around home in a fixed order (deterministic).
	if _wander_wait > 0.0:
		_wander_wait -= delta
		_stop()
		return
	if not _wander_target.is_finite():
		var ang := float(_wander_step) * 2.39996  # golden angle
		var r := leash_radius * (0.35 + 0.6 * fposmod(float(_wander_step) * 0.618, 1.0))
		_wander_target = home + Vector3(sin(ang) * r, 0.0, cos(ang) * r)
		_wander_step += 1
	var flat := _wander_target - global_position
	flat.y = 0.0
	if flat.length() < 0.4:
		_wander_target = Vector3.INF
		_wander_wait = 1.2
		_stop()
		return
	_move_toward(_wander_target, delta)


func _move_toward(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_stop()
		return
	dir = dir.normalized()
	velocity.x = dir.x * wander_speed
	velocity.z = dir.z * wander_speed
	basis = basis.slerp(Basis.looking_at(dir), clampf(6.0 * delta, 0.0, 1.0)).orthonormalized()


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


## Distance (XZ) from home, for tests/tools.
func distance_from_home() -> float:
	if not home.is_finite():
		return 0.0
	var d := global_position - home
	d.y = 0.0
	return d.length()
