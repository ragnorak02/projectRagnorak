## Base class for all enemies.
extends CharacterBody3D
class_name EnemyBase

## Name shown on the target bar and Command Menu target list.
@export var display_name: String = "Reactor Sentry"
@export var max_hp: float = 50.0
@export var attack_damage: float = 10.0
@export var move_speed: float = 4.0
@export var aggro_range: float = 12.0
@export var attack_range: float = 2.0
@export var attack_telegraph: float = 0.4
@export var attack_active: float = 0.2
@export var attack_recovery: float = 0.5
@export var attack_cooldown: float = 1.8
@export var stagger_duration: float = 0.5  # HURT flinch length (not the stagger break)
@export var gravity: float = 20.0

# --- Stagger (battle v3). Duck-typed by src/ui/hud/target_bar.gd:
# stagger_value, stagger_max, is_staggered(), stagger_damage_multiplier.
@export var stagger_max: float = 100.0
## Damage multiplier applied while STAGGERED.
@export var stagger_damage_multiplier: float = 1.6
## Length of the STAGGERED break (game time).
@export var stagger_break_time: float = 4.0
## Seconds without stagger gain before the gauge starts to drain.
@export var stagger_decay_delay: float = 2.5
## Gauge drain per second once decaying (also used after a break ends).
@export var stagger_decay_rate: float = 12.0
## Drain per second right after a break, so the gauge empties visibly.
const STAGGER_RECOVER_RATE := 60.0
var stagger_value: float = 0.0
var _stagger_timer: float = 0.0
var _stagger_idle_timer: float = 0.0
var _stagger_recovering: bool = false
const STAGGER_TINT := Color(1.0, 0.62, 0.3, 1.0)

var current_hp: float

## v5: optional un-rigged model (docs/rigless_models.md). When set, the capsule
## is hidden and a RiglessVisual (procedural bob/lean/cues) shows this mesh.
@export var rigless_model: PackedScene = null
@export var rigless_fit_height: float = 1.7
@export var rigless_yaw_offset_deg: float = 180.0
var _rigless: Node3D = null

# --- v6 (Package II): party targeting + ENEMY COMBAT SPACING RULE ---
## Ring radius (centre to centre) the enemy holds around its target. <= 0 =
## auto: attack_range - 0.2, never below stop_distance (1.8 m by default,
## ~6 ft: inside the 5-10 ft contract band and inside attack reach).
@export var preferred_radius: float = -1.0
## Hard floor: the enemy never moves closer than this to ANY party member.
@export var stop_distance: float = 1.5
## Enemies push apart inside this distance (no dogpiling).
@export var enemy_separation: float = 1.3
## Attack queue: at most this many enemies wind up / strike / recover on the
## same party member at once; the rest hold their ring slot.
@export var max_attackers_per_target: int = 2
const ThreatTableScript := preload("res://src/enemies/threat_table.gd")
## Angular spacing of ring slots (radians). Groups spread over an arc in front
## of their side instead of a full surround, unless they need the room.
const RING_STEP_MAX := PI * 0.5
## Slot arrival tolerance (m) and tangential orbit threshold (radians).
const SLOT_TOLERANCE := 0.2
const ORBIT_ANGLE := 0.35
## Faces the target (instead of the move direction) inside this distance.
const FACE_TARGET_RANGE := 5.0
## Emitted when the chosen party member changes (null = no target).
signal target_changed(enemy: Node3D, new_target: Node3D)
var threat: RefCounted = ThreatTableScript.new()
var _target_key: StringName = &""
var _retarget_timer: float = 0.0
var _hold_timer: float = 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var hurtbox: Area3D = $Hurtbox
@onready var attack_origin: Node3D = $AttackOrigin
@onready var attack_hitbox_shape: CollisionShape3D = $AttackOrigin/AttackHitbox/CollisionShape3D
@onready var aggro_area: Area3D = $AggroArea
@onready var lock_on_point: Marker3D = $LockOnPoint

var _target: Node3D = null
var _is_dead: bool = false
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _hit_active: bool = false
var _original_color: Color

# Health bar (overhead billboard)
var _health_bar_root: Node3D = null
var _health_bar_fill: MeshInstance3D = null
var _health_bar_bg: MeshInstance3D = null
var _health_bar_visible: bool = false
var _stagger_bar_fill: MeshInstance3D = null
const HEALTH_BAR_WIDTH: float = 1.2
const HEALTH_BAR_HEIGHT: float = 0.05
const HEALTH_BAR_BORDER: float = 0.03
const STAGGER_BAR_HEIGHT: float = 0.025
const HEALTH_BAR_Y_OFFSET: float = 2.4

# STAGGERED is appended so existing values (IDLE..DEAD) keep their indices.
enum AIState { IDLE, CHASE, ATTACK_TELEGRAPH, ATTACK_STRIKE, ATTACK_RECOVERY, HURT, DEAD, STAGGERED }
var ai_state: AIState = AIState.IDLE


func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	aggro_area.body_entered.connect(_on_aggro_body_entered)

	var mesh: MeshInstance3D = visual_root.get_node("MeshInstance3D")
	if mesh and mesh.material_override:
		# Per-instance copy: the scene's sub-resource material is shared by every
		# enemy instance, so a flash / stagger tint would otherwise recolour all.
		mesh.material_override = mesh.material_override.duplicate()
		_original_color = mesh.material_override.albedo_color

	_setup_rigless()
	_build_health_bar()
	# Party switch swaps identities between bodies: re-resolve the body of the
	# member this enemy is fighting (threat is keyed by member id).
	Events.party_member_switched.connect(_on_party_member_switched)
	Events.party_member_downed.connect(_on_party_member_downed)
	Events.enemy_spawned.emit(self)


func _setup_rigless() -> void:
	if rigless_model == null or visual_root == null:
		return
	var script: GDScript = load("res://src/characters/rigless_visual.gd")
	if script == null:
		return
	for c in visual_root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
	_rigless = script.new()
	_rigless.name = "RiglessVisual"
	_rigless.set(&"model_scene", rigless_model)
	_rigless.set(&"fit_height", rigless_fit_height)
	_rigless.set(&"model_yaw_offset_deg", rigless_yaw_offset_deg)
	visual_root.add_child(_rigless)


func _rigless_cue(cue: StringName) -> void:
	if _rigless and is_instance_valid(_rigless) and _rigless.has_method(&"play_cue"):
		_rigless.play_cue(cue)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Attack cooldown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	_update_stagger_decay(delta)
	threat.decay(delta)
	if _hold_timer > 0.0:
		_hold_timer -= delta

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK_TELEGRAPH:
			_process_attack_telegraph(delta)
		AIState.ATTACK_STRIKE:
			_process_attack_strike(delta)
		AIState.ATTACK_RECOVERY:
			_process_attack_recovery(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.STAGGERED:
			_process_staggered(delta)

	move_and_slide()


## hit_kind (optional, battle v3): &"blast" / &"finisher" colour the damage
## number gold. While STAGGERED, damage is multiplied by stagger_damage_multiplier.
## v5: knock the enemy into the air (Water Geyser). Sets velocity; gravity
## stays on and the normal AI resumes on landing. Ignored when dead.
func launch(vel: Vector3) -> void:
	if _is_dead:
		return
	velocity = vel


func take_damage(amount: float, source: Node3D = null, hit_kind: StringName = &"") -> void:
	if _is_dead:
		return
	var staggered := is_staggered()
	if staggered:
		amount *= stagger_damage_multiplier
	current_hp = maxf(current_hp - amount, 0.0)
	_add_damage_threat(amount, source)
	Events.enemy_damaged.emit(self, amount)
	Events.enemy_hit.emit(self, amount, source)
	_rigless_cue(&"hit")

	# Visual feedback
	_show_health_bar()
	_update_health_bar()
	_spawn_damage_number(amount, hit_kind, staggered)

	# Hit stop feedback
	GameManager.hit_stop(40.0)

	if current_hp <= 0.0:
		die()
	else:
		if staggered:
			# A break is not interrupted by flinches; just flash.
			_flash_color(Color(1.0, 0.85, 0.6, 1.0), 0.1)
		else:
			_enter_hurt()
		AudioManager.play_sfx_varied("enemy_hurt")


# --- Stagger ---

func is_staggered() -> bool:
	return ai_state == AIState.STAGGERED


## Build stagger. At stagger_max the enemy breaks: STAGGERED for
## stagger_break_time (can't act), then the gauge drains. Ignored while already
## staggered or dead.
func add_stagger(amount: float) -> void:
	if _is_dead or amount <= 0.0 or is_staggered():
		return
	_stagger_recovering = false
	_stagger_idle_timer = 0.0
	stagger_value = minf(stagger_value + amount, stagger_max)
	_update_stagger_bar()
	if stagger_value >= stagger_max:
		_enter_staggered()


func _enter_staggered() -> void:
	_disable_attack_hitbox()
	ai_state = AIState.STAGGERED
	_stagger_timer = 0.0
	stagger_value = stagger_max
	velocity.x = 0.0
	velocity.z = 0.0
	_show_health_bar()
	_set_body_color(STAGGER_TINT)
	if visual_root:
		visual_root.rotation.x = deg_to_rad(-12.0)
	Events.enemy_staggered.emit(self)


func _process_staggered(delta: float) -> void:
	_stagger_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if _stagger_timer >= stagger_break_time:
		_exit_staggered()


func _exit_staggered() -> void:
	_stagger_recovering = true
	_stagger_idle_timer = 0.0
	if visual_root:
		visual_root.rotation.x = 0.0
	_set_body_color(_original_color)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer, attack_cooldown * 0.5)
	ai_state = AIState.CHASE


func _update_stagger_decay(delta: float) -> void:
	if is_staggered() or stagger_value <= 0.0:
		return
	if _stagger_recovering:
		stagger_value = maxf(stagger_value - STAGGER_RECOVER_RATE * delta, 0.0)
	else:
		_stagger_idle_timer += delta
		if _stagger_idle_timer < stagger_decay_delay:
			return
		stagger_value = maxf(stagger_value - stagger_decay_rate * delta, 0.0)
	if stagger_value <= 0.0:
		_stagger_recovering = false
	_update_stagger_bar()


func die() -> void:
	_is_dead = true
	ai_state = AIState.DEAD
	_disable_attack_hitbox()
	_hide_health_bar()
	AudioManager.play_sfx_named("enemy_die")

	# Disable collisions so player/lock-on clean up
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	aggro_area.set_deferred("monitoring", false)

	Events.enemy_died.emit(self)

	# Death shrink then cleanup
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(queue_free)


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		var kind: StringName = area.get_meta("hit_kind", &"")
		take_damage(area.get_meta("damage"), area.get_parent(), kind)
		if area.has_meta("stagger") and not _is_dead:
			add_stagger(float(area.get_meta("stagger")))


func _on_aggro_body_entered(body: Node3D) -> void:
	# v6: any targetable party body (the Player node or an AI companion) aggros.
	if not (body.is_in_group(&"player") or body.is_in_group(&"party_members")):
		return
	if not _is_targetable(body):
		return
	var key := _key_for_body(body)
	threat.add(key, ThreatTableScript.ENGAGE_THREAT)
	if _target == null or not is_instance_valid(_target) or ai_state == AIState.IDLE:
		_set_target(body, key)
	if ai_state == AIState.IDLE:
		ai_state = AIState.CHASE
		_retarget_timer = ThreatTableScript.RETARGET_INTERVAL
		_show_health_bar()
		Events.enemy_aggro_triggered.emit(self)


# --- v6 Party targeting (threat) ---

## The party member body this enemy is currently fighting (null = none).
func get_target() -> Node3D:
	return _target if _target != null and is_instance_valid(_target) else null


## Member id of the current target (threat key).
func get_target_key() -> StringName:
	return _target_key


## Ring radius actually used (see preferred_radius).
func get_preferred_radius() -> float:
	if preferred_radius > 0.0:
		return maxf(preferred_radius, stop_distance)
	return maxf(attack_range - 0.2, stop_distance)


## True while this enemy occupies an attack slot (wind-up / strike / recovery).
func is_attacking() -> bool:
	return ai_state == AIState.ATTACK_TELEGRAPH or ai_state == AIState.ATTACK_STRIKE \
		or ai_state == AIState.ATTACK_RECOVERY


## A party body can be targeted: alive, not downed, damageable.
func _is_targetable(n: Node) -> bool:
	if n == null or not is_instance_valid(n) or not (n is Node3D) or not n.is_inside_tree():
		return false
	if not n.has_method("take_damage"):
		return false
	if n.has_method("is_downed") and n.is_downed():
		return false
	if "current_hp" in n and float(n.get(&"current_hp")) <= 0.0:
		return false
	return true


func _find_party_system() -> Node:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not ("party_system" in player):
		return null
	var ps: Node = player.get(&"party_system")
	if ps == null or not is_instance_valid(ps) or not ("members" in ps):
		return null
	return ps


## Every party body (targetable or not) as [{key, node}], in a stable order:
## PartySystem member order, else the "player" group then "party_members".
func _party_bodies() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var ps := _find_party_system()
	if ps != null and ps.members.size() > 0:
		for m in ps.members:
			var n = m.get("node")
			if n is Node3D and is_instance_valid(n) and n.is_inside_tree():
				out.append({"key": StringName(m.get("id", &"")), "node": n})
		return out
	var seen: Dictionary = {}
	for g in [&"player", &"party_members"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and not seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				out.append({"key": _fallback_key(n), "node": n})
	return out


func _party_candidates() -> Array:
	var out: Array = []
	for c in _party_bodies():
		if _is_targetable(c["node"]):
			out.append(c)
	return out


func _fallback_key(n: Node) -> StringName:
	var data: Resource = null
	if n.has_method("get_member_data"):
		data = n.get_member_data()
	elif "member_data" in n:
		data = n.get(&"member_data")
	if data != null and "member_id" in data and StringName(data.member_id) != &"":
		return StringName(data.member_id)
	return StringName("node_%d" % n.get_instance_id())


func _key_for_body(body: Node) -> StringName:
	for c in _party_bodies():
		if c["node"] == body:
			return c["key"]
	return _fallback_key(body)


func _body_for_key(key: StringName) -> Node3D:
	for c in _party_bodies():
		if c["key"] == key:
			return c["node"]
	return null


## Who dealt this hit: the party body that is (or owns) `source`. Projectiles
## and effects that live outside their caster expose it as `source`/`caster`
## (property or meta). No source / unknown source = the controlled Player body
## (same rule as BattleModeComponent: only companions are told apart).
func _attribute_source(source: Node) -> Dictionary:
	var bodies := _party_bodies()
	if bodies.is_empty():
		return {}
	var n: Node = source
	var guard := 0
	while n != null and is_instance_valid(n) and guard < 32:
		guard += 1
		for c in bodies:
			if c["node"] == n:
				return c
		n = _owner_of(n)
	for c in bodies:
		if (c["node"] as Node).is_in_group(&"player"):
			return c
	return {}


## Next node up the ownership chain: an explicit caster/source (meta first,
## then property) if it names another node, else the scene-tree parent.
static func _owner_of(n: Node) -> Node:
	for prop in [&"caster", &"source"]:
		var ref: Variant = null
		if n.has_meta(prop):
			ref = n.get_meta(prop)
		elif prop in n:
			ref = n.get(prop)
		if ref is Node and is_instance_valid(ref) and ref != n:
			return ref
	return n.get_parent()


func _add_damage_threat(amount: float, source: Node) -> void:
	var c := _attribute_source(source)
	if c.is_empty():
		return
	threat.add(c["key"], amount)
	# Hit while unengaged (e.g. from range): engage the attacker if it is in reach.
	if (_target == null or not is_instance_valid(_target)) and _is_targetable(c["node"]):
		if global_position.distance_to((c["node"] as Node3D).global_position) <= aggro_range * 1.5:
			_set_target(c["node"], c["key"])
			_retarget_timer = ThreatTableScript.RETARGET_INTERVAL


func _set_target(body: Node3D, key: StringName) -> void:
	var changed := body != _target or key != _target_key
	_target = body
	_target_key = key
	if changed:
		_hold_timer = ThreatTableScript.MIN_HOLD
		target_changed.emit(self, body)


## Number of OTHER live enemies currently targeting `body` (optionally only
## those holding an attack slot).
func _count_on_target(body: Node3D, attackers_only: bool = false) -> int:
	var n := 0
	if body == null or not is_inside_tree():
		return 0
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e == self or not (e is EnemyBase) or not is_instance_valid(e):
			continue
		var eb := e as EnemyBase
		if eb._is_dead or eb.get_target() != body:
			continue
		if attackers_only and not eb.is_attacking():
			continue
		n += 1
	return n


## Re-evaluate the target. `forced` = the current one became invalid (downed,
## dead, freed): switch at once, ignoring hold/interval. Returns false when no
## party member can be targeted.
func _evaluate_target(forced: bool) -> bool:
	var cands := _party_candidates()
	if cands.is_empty():
		if _target != null:
			_target = null
			_target_key = &""
			target_changed.emit(self, null)
		return false
	var current_ok := _target != null and is_instance_valid(_target) and _is_targetable(_target)
	if current_ok and not forced and _hold_timer > 0.0:
		return true
	var rows: Array = []
	for c in cands:
		var node: Node3D = c["node"]
		rows.append({"key": c["key"],
			"dist": global_position.distance_to(node.global_position),
			"crowd": _count_on_target(node)})
	var idx: int = threat.pick(rows, _target_key if current_ok else &"", aggro_range)
	if idx < 0:
		return false
	_set_target(cands[idx]["node"], cands[idx]["key"])
	return true


func _on_party_member_switched(_old_id: StringName, _new_id: StringName) -> void:
	if _is_dead or _target_key == &"":
		return
	var body := _body_for_key(_target_key)
	if body != null and body != _target:
		# Same member, new body: not a voluntary switch (hold timer untouched).
		_target = body
		target_changed.emit(self, body)


func _on_party_member_downed(member_id: StringName) -> void:
	if _is_dead or member_id != _target_key:
		return
	_retarget_timer = ThreatTableScript.RETARGET_INTERVAL
	# A wind-up on the downed member is dropped; a strike already out finishes
	# harmlessly (the downed hurtbox is off). The target switches at once in
	# every state, so no enemy keeps a downed member as its target.
	if ai_state == AIState.ATTACK_TELEGRAPH:
		ai_state = AIState.CHASE
	if not _evaluate_target(true):
		_target = null
		_target_key = &""


# --- AI States ---

func _process_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _process_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		ai_state = AIState.IDLE
		return

	# Target selection: forced when the current member is no longer targetable,
	# otherwise on a fixed interval (game time, so tactical mode slows it too).
	if not _is_targetable(_target):
		if not _evaluate_target(true):
			ai_state = AIState.IDLE
			velocity.x = 0.0
			velocity.z = 0.0
			return
	else:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = ThreatTableScript.RETARGET_INTERVAL
			_evaluate_target(false)

	var dist := global_position.distance_to(_target.global_position)

	# Lost interest in this member: fall back to the nearest member in aggro
	# range (party order breaks ties), else give up.
	if dist > aggro_range * 1.5:
		var nearest: Dictionary = {}
		var best := aggro_range
		for c in _party_candidates():
			var d := global_position.distance_to((c["node"] as Node3D).global_position)
			if d <= best and c["node"] != _target:
				best = d
				nearest = c
		if not nearest.is_empty():
			_set_target(nearest["node"], nearest["key"])
			return
		_target = null
		_target_key = &""
		threat.clear()
		target_changed.emit(self, null)
		ai_state = AIState.IDLE
		return

	# In attack range, cooldown ready and an attack slot free on this target.
	if dist < attack_range and _attack_cooldown_timer <= 0.0 \
			and _count_on_target(_target, true) < max_attackers_per_target:
		_enter_attack_telegraph()
		return

	_steer_spacing(delta, dist)


# --- v6 Spacing (ENEMY COMBAT SPACING RULE) ---

## Ring slot angle (radians, atan2(x, z) around the target) for this enemy.
## Every enemy on the same target computes the same assignment: the group is
## sorted by its current angle around the target relative to the group's mean
## direction (order never swaps, so no crossing), then spread RING_STEP_MAX
## apart (or TAU/N when they need a full ring), centred on the mean direction.
func get_ring_slot_angle() -> float:
	var t := get_target()
	if t == null:
		return 0.0
	var group: Array = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is EnemyBase) or not is_instance_valid(e):
			continue
		var eb := e as EnemyBase
		if eb._is_dead or eb.get_target() != t:
			continue
		group.append(eb)
	var own := _angle_around(t.global_position, global_position)
	if group.size() <= 1:
		return own
	var sx := 0.0
	var sz := 0.0
	for eb in group:
		var a := _angle_around(t.global_position, (eb as Node3D).global_position)
		sx += sin(a)
		sz += cos(a)
	var mean: float
	if Vector2(sx, sz).length() < 0.2 * group.size():
		# Balanced surround: anchor on the lowest instance id (deterministic).
		var anchor: EnemyBase = group[0]
		for eb in group:
			if (eb as Object).get_instance_id() < anchor.get_instance_id():
				anchor = eb
		mean = _angle_around(t.global_position, anchor.global_position)
	else:
		mean = atan2(sx, sz)
	var rel: Array = []
	for eb in group:
		var a := _angle_around(t.global_position, (eb as Node3D).global_position)
		rel.append([wrapf(a - mean, -PI, PI), (eb as Object).get_instance_id(), eb])
	rel.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var n := rel.size()
	var step := minf(RING_STEP_MAX, TAU / float(n))
	for i in n:
		if rel[i][2] == self:
			return mean + (float(i) - float(n - 1) * 0.5) * step
	return own


static func _angle_around(center: Vector3, p: Vector3) -> float:
	return atan2(p.x - center.x, p.z - center.z)


## Move to this enemy's ring slot around the target, orbiting (not cutting
## through) the target, separated from other enemies, and never closer than
## stop_distance to ANY party member. Faces the target when close.
func _steer_spacing(delta: float, dist: float) -> void:
	var tp := _target.global_position
	var radius := get_preferred_radius()
	var slot := get_ring_slot_angle()
	var rel := global_position - tp
	rel.y = 0.0
	var outward := rel.normalized() if rel.length() > 0.01 else -global_basis.z
	var cur_ang := atan2(rel.x, rel.z)
	var dang := wrapf(slot - cur_ang, -PI, PI)

	var desired := Vector3.ZERO
	var speed := move_speed
	if dist > radius + 1.0:
		# Approach: head for the slot point.
		var slot_point := tp + Vector3(sin(slot), 0.0, cos(slot)) * radius
		var to_slot := slot_point - global_position
		to_slot.y = 0.0
		desired = to_slot.normalized()
	else:
		# On the ring: correct the radius, orbit toward the slot angle.
		var radial := clampf((radius - dist) * 2.0, -1.0, 1.0)
		desired = outward * radial
		if absf(dang) > ORBIT_ANGLE * 0.25:
			var tangent := Vector3(cos(cur_ang), 0.0, -sin(cur_ang)) * signf(dang)
			desired += tangent * clampf(absf(dang) / ORBIT_ANGLE, 0.0, 1.0)
		var off := Vector2(radius - dist, absf(dang) * radius).length()
		if off < SLOT_TOLERANCE:
			desired = Vector3.ZERO
		speed = move_speed * clampf(off / 0.8, 0.35, 1.0)

	# Separation from other enemies (local, symmetric).
	var sep := Vector3.ZERO
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e == self or not (e is EnemyBase) or not is_instance_valid(e) or (e as EnemyBase)._is_dead:
			continue
		var d := global_position - (e as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l < enemy_separation:
			sep += (d / maxf(l, 0.05)) * (enemy_separation - l) / enemy_separation
	desired += sep * 1.5

	if desired.length() > 1.0:
		desired = desired.normalized()
	var v := desired * speed
	v = _clamp_member_overlap(v, delta)
	velocity.x = v.x
	velocity.z = v.z

	# Facing: the target when close (attacks read from range), else movement.
	var face: Vector3 = -rel if dist <= FACE_TARGET_RANGE else Vector3(v.x, 0.0, v.z)
	if face.length() > 0.1:
		basis = basis.slerp(Basis.looking_at(face.normalized()), clampf(8.0 * delta, 0.0, 1.0))


## No overlap with ANY party member (targeted or not, downed included): inside
## stop_distance the enemy backs out; otherwise the inward velocity component
## that would cross stop_distance this frame is removed (enemies collide with
## the world only, so this is what keeps them out of member colliders).
func _clamp_member_overlap(v: Vector3, delta: float) -> Vector3:
	for c in _party_bodies():
		var node: Node3D = c["node"]
		var d := global_position - node.global_position
		d.y = 0.0
		var l := d.length()
		if l < 0.001:
			d = -global_basis.z
			l = 0.001
		var n := d / l
		var radial := v.dot(n)  # > 0 = moving away
		if l < stop_distance:
			# Too close: back out at no less than 60% of move speed.
			var out_speed := maxf(radial, move_speed * 0.6)
			v += n * (out_speed - radial)
		elif radial < 0.0:
			var max_in := (l - stop_distance) / maxf(delta, 0.0001)
			if -radial > max_in:
				v += n * (-radial - max_in)
	return v


func _enter_attack_telegraph() -> void:
	ai_state = AIState.ATTACK_TELEGRAPH
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _process_attack_telegraph(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	# Face the target during wind-up
	if _target and is_instance_valid(_target):
		var dir: Vector3 = (_target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			basis = basis.slerp(Basis.looking_at(dir.normalized()), clampf(12.0 * delta, 0.0, 1.0))

	if _state_timer >= attack_telegraph:
		_enter_attack_strike()


func _enter_attack_strike() -> void:
	_rigless_cue(&"attack")
	ai_state = AIState.ATTACK_STRIKE
	_state_timer = 0.0
	_enable_attack_hitbox()


func _process_attack_strike(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_active:
		_disable_attack_hitbox()
		ai_state = AIState.ATTACK_RECOVERY
		_state_timer = 0.0


func _process_attack_recovery(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_recovery:
		_attack_cooldown_timer = attack_cooldown
		ai_state = AIState.CHASE


func _enter_hurt() -> void:
	_disable_attack_hitbox()
	ai_state = AIState.HURT
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	# Flash red on hit
	_flash_color(Color(1.0, 0.5, 0.5, 1.0), 0.15)


func _process_hurt(delta: float) -> void:
	_state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	if _state_timer >= stagger_duration:
		ai_state = AIState.CHASE


# --- Attack Hitbox ---

func _enable_attack_hitbox() -> void:
	attack_hitbox_shape.disabled = false
	var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
	hitbox_area.set_meta("damage", attack_damage)
	_hit_active = true


func _disable_attack_hitbox() -> void:
	if _hit_active:
		attack_hitbox_shape.set_deferred("disabled", true)
		var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
		if hitbox_area.has_meta("damage"):
			hitbox_area.remove_meta("damage")
		_hit_active = false


# --- Visual Feedback ---

func _flash_color(color: Color, duration: float) -> void:
	var mesh: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D")
	if mesh == null or mesh.material_override == null:
		return
	mesh.material_override.albedo_color = color
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(mesh) and mesh.material_override:
			mesh.material_override.albedo_color = STAGGER_TINT if is_staggered() else _original_color
	)


func _set_body_color(color: Color) -> void:
	var mesh: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D") if visual_root else null
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = color


# --- Overhead Health Bar (Lumina Frost style, R5b) ---
# A thin cyan->red HP strip on a dark glass backing, plus a hairline orange
# stagger strip under it. All quads billboard; fills shrink from the right via
# QuadMesh.center_offset (applied in billboard space, so it stays left-aligned
# from any camera angle).

func _make_bar_quad(width: float, height: float, color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = priority
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_health_bar() -> void:
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBar"
	_health_bar_root.position = Vector3(0, HEALTH_BAR_Y_OFFSET, 0)
	add_child(_health_bar_root)

	# Dark glass backing (covers HP + stagger strips, with a small border).
	var back_h := HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT + HEALTH_BAR_BORDER * 2.0 + 0.01
	_health_bar_bg = _make_bar_quad(HEALTH_BAR_WIDTH + HEALTH_BAR_BORDER * 2.0, back_h,
		UIStyle.GLASS_DEEP, 1)
	var bg_quad: QuadMesh = _health_bar_bg.mesh
	bg_quad.center_offset = Vector3(0, -(STAGGER_BAR_HEIGHT + 0.01) * 0.5, 0)
	_health_bar_root.add_child(_health_bar_bg)

	# HP fill.
	_health_bar_fill = _make_bar_quad(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT, UIStyle.CYAN, 2)
	_health_bar_root.add_child(_health_bar_fill)

	# Stagger fill (orange hairline under the HP strip). Empty = invisible.
	_stagger_bar_fill = _make_bar_quad(HEALTH_BAR_WIDTH, STAGGER_BAR_HEIGHT, UIStyle.STAGGER, 2)
	var st_quad: QuadMesh = _stagger_bar_fill.mesh
	st_quad.center_offset = Vector3(0, -(HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT) * 0.5 - 0.01, 0)
	_stagger_bar_fill.visible = false
	_health_bar_root.add_child(_stagger_bar_fill)

	# Start hidden — shows when enemy aggros or is hit
	_health_bar_root.visible = false


func _show_health_bar() -> void:
	if _health_bar_root and not _health_bar_visible:
		_health_bar_visible = true
		_health_bar_root.visible = true
		_update_health_bar()
		_update_stagger_bar()


func _hide_health_bar() -> void:
	if _health_bar_root:
		_health_bar_visible = false
		_health_bar_root.visible = false


## Cyan at full HP -> stagger orange at half -> danger red when low.
static func hp_bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return UIStyle.STAGGER.lerp(UIStyle.CYAN, (ratio - 0.5) * 2.0)
	if ratio > 0.25:
		return UIStyle.DANGER.lerp(UIStyle.STAGGER, (ratio - 0.25) * 4.0)
	return UIStyle.DANGER


func _set_bar_fill(bar: MeshInstance3D, ratio: float, height: float, base_y: float) -> void:
	var quad: QuadMesh = bar.mesh as QuadMesh
	var w: float = maxf(HEALTH_BAR_WIDTH * ratio, 0.001)
	quad.size = Vector2(w, height)
	quad.center_offset = Vector3((w - HEALTH_BAR_WIDTH) * 0.5, base_y, 0)


func _update_health_bar() -> void:
	if _health_bar_fill == null or not _health_bar_visible:
		return
	var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	_set_bar_fill(_health_bar_fill, ratio, HEALTH_BAR_HEIGHT, 0.0)
	var fill_mat: StandardMaterial3D = _health_bar_fill.material_override
	var c := hp_bar_color(ratio)
	fill_mat.albedo_color = Color(c.r, c.g, c.b, 0.95)


func _update_stagger_bar() -> void:
	if _stagger_bar_fill == null or not _health_bar_visible:
		return
	var ratio := clampf(stagger_value / maxf(stagger_max, 1.0), 0.0, 1.0)
	_stagger_bar_fill.visible = ratio > 0.001
	if not _stagger_bar_fill.visible:
		return
	_set_bar_fill(_stagger_bar_fill, ratio, STAGGER_BAR_HEIGHT,
		-(HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT) * 0.5 - 0.01)
	var mat: StandardMaterial3D = _stagger_bar_fill.material_override
	mat.albedo_color = UIStyle.ATB_FULL if is_staggered() else UIStyle.STAGGER


# --- Floating Damage Numbers (UIStyle body font, R5b) ---
# White with a dark outline; gold for blasts / finishers; orange while staggered.

const DMG_COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)

func _spawn_damage_number(amount: float, hit_kind: StringName = &"", staggered: bool = false) -> void:
	if not SettingsManager.show_damage_numbers:
		return

	var big := hit_kind == &"blast" or hit_kind == &"finisher"
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.font = UIStyle.font_body_bold()
	label.font_size = 60 if big else 48
	label.outline_size = 12
	if big:
		label.modulate = UIStyle.GOLD
	elif staggered:
		label.modulate = UIStyle.STAGGER
	else:
		label.modulate = DMG_COLOR_NORMAL
	label.outline_modulate = Color(0.02, 0.04, 0.07, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 5
	label.pixel_size = 0.01

	# Spawn slightly above the enemy with random horizontal offset
	var spawn_offset := Vector3(
		randf_range(-0.3, 0.3),
		HEALTH_BAR_Y_OFFSET + 0.3,
		randf_range(-0.1, 0.1)
	)
	# Add to scene root (not enemy child — survives enemy death briefly).
	# Must be in the tree before global_position can be set.
	if not is_inside_tree() or get_tree().current_scene == null:
		label.free()
		return
	get_tree().current_scene.add_child(label)
	label.global_position = global_position + spawn_offset

	# Animate: float up, scale pop, then fade out
	label.scale = Vector3(0.5, 0.5, 0.5)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "scale", Vector3.ONE * (1.25 if big else 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
