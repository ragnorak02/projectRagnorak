## Data-driven light/heavy melee strike (battle system v3, Package R).
##
## Node: StateMachine/MeleeStrike. Entered via
##   player.request_transition(&"MeleeStrike", {"kind": &"light"|&"heavy", "step": 1..3})
## or returned from a state's process_input (empty msg -> the ComboComponent's
## pending strike, else light step 1).
##
## Per kind: duration / hit window / chain point / lunge / damage / stagger /
## arc VFX (STRIKES). Step 3 runs the finisher table
## (ComboComponent.FINISHERS): slashes use the hitbox; blasts hit every enemy
## in radius once (BlastVFX.detonate) and H-H-H also requests a camera shake
## through Events.camera_shake_requested (camera internals untouched).
##
## v5 DD AIR MODE: a strike entered airborne (an air string, see
## ComboComponent) holds the string's altitude (ComboComponent.air_hold_velocity:
## gravity cancelled + tiny lift, no snap to the ground) and drifts forward at
## AIR_DRIFT_SPEED along the stick (camera-relative) or facing. L/H mix and
## finishers are the same as on the ground. When the strike ends it returns to
## Fall; Fall keeps hovering only while the air string is still alive.
## Animation hooks (played only if the AnimationPlayer has them):
## air_strike_light / air_strike_heavy. Every strike also sends the rigless
## cue &"attack" / &"attack_heavy" (v5 EE; no-op without a RiglessVisual).
##
## v6 HH — MAGE PROFILE. The controlled member's BasicAttackProfile
## (ComboComponent.active_profile()) picks the kit at enter(). Melee (Amaro) runs
## exactly the v5 code below (STRIKES, ComboComponent.FINISHERS, hitbox, arcs).
## Mage (Taighe) keeps every rule of this state (timing from the profile's
## strike table, chain point, buffered input, dodge cancel, air mode) but
## instead of the hitbox it spawns a MageBolt (src/combat/basic_attacks/) that
## charges at the hand and launches at `hit_start`: light = quick bolt, heavy =
## charged shot, step 3 = finisher orb that bursts (radius by heavy count). The
## bolt soft-tracks the lock-on target, else the nearest enemy in a forward
## cone. A strike cancelled before its fire time fizzles the bolt (no damage).
##
## Contract: basic attacks are unlimited (no MP/ATB/stamina) and cancel into
## Dodge at any point. Illegal (player.gd): MeleeStrike -> TacticalIdle,
## Flinch/LedgeGrab/ClimbUp -> MeleeStrike.
extends State

const AttackVFX = preload("res://src/effects/attack_vfx.gd")
const BlastVFX = preload("res://src/effects/blast_vfx.gd")
const MageBolt = preload("res://src/combat/basic_attacks/mage_bolt.gd")

## duration: total strike time (s, game time); hit_start/hit_end: hitbox window;
## chain_at: earliest time a buffered next step starts; lunge: forward speed
## during lunge_time; damage / stagger: per hit.
const STRIKES := {
	&"light": {"duration": 0.35, "hit_start": 0.06, "hit_end": 0.20, "chain_at": 0.17,
		"lunge": 4.0, "lunge_time": 0.10, "damage": 12.0, "stagger": 6.0},
	&"heavy": {"duration": 0.60, "hit_start": 0.18, "hit_end": 0.36, "chain_at": 0.36,
		"lunge": 6.5, "lunge_time": 0.18, "damage": 20.0, "stagger": 18.0},
}
## Finisher strikes run a little longer so the blast reads.
const FINISHER_EXTRA_TIME := 0.15
## Blast centre in front of Amaro (m).
const BLAST_FORWARD := 1.5
## Lunge stops when an enemy is this close ahead (no model overlap).
const LUNGE_STOP_DIST := 1.4
## v5 DD: forward drift speed of an air strike (m/s).
const AIR_DRIFT_SPEED := 2.0

var kind: StringName = &"light"
var step: int = 1
var finisher: StringName = &""
var damage: float = 0.0
var stagger: float = 0.0

var _data: Dictionary = {}
var _timer: float = 0.0
var _duration: float = 0.35
var _hit_active: bool = false
var _hit_done: bool = false
var _blast_fired: bool = false
## Last blast result (for tests / debug): {"radius", "damage", "hits"}.
var last_blast: Dictionary = {}
## v5 DD: true while this strike runs in air mode.
var airborne: bool = false
var _drift_dir: Vector3 = Vector3.ZERO

## v6 HH: the profile this strike runs (null only before the first enter).
var profile: BasicAttackProfile = null
## True when this strike is a mage strike (bolt instead of hitbox).
var mage: bool = false
var _bolt: Node3D = null
var _bolt_fired: bool = false
var _aim_target: Node3D = null
## Last mage bolt fired (for tests / debug): {"kind", "step", "finisher",
## "damage", "stagger", "burst_radius", "target", "node", "airborne"}.
var last_bolt: Dictionary = {}
## Mage: hand offset the bolt charges at (up, forward), metres.
const MAGE_HAND_UP := 1.25
const MAGE_HAND_FORWARD := 0.55


func enter(msg: Dictionary = {}) -> void:
	var combo: ComboComponent = player.combo if "combo" in player else null
	if not msg.has("kind") and combo:
		var pending := combo.take_pending_strike()
		if not pending.is_empty():
			msg = pending
	kind = msg.get("kind", &"light")
	if not STRIKES.has(kind):
		kind = &"light"
	step = clampi(int(msg.get("step", 1)), 1, 3)
	var combo_string: String = msg.get("string", "")
	profile = combo.active_profile() if combo else BasicAttackProfile.for_member(
		player.get_member_data() if player.has_method(&"get_member_data") else null)
	mage = profile != null and profile.is_mage() and not profile.get_strike(kind).is_empty()
	if mage:
		finisher = profile.get_finisher(combo_string) if step == 3 else &""
		_data = profile.get_strike(kind)
	else:
		finisher = ComboComponent.get_finisher(combo_string) if step == 3 else &""
		_data = STRIKES[kind]
	_bolt = null
	_bolt_fired = false
	_aim_target = null
	_timer = 0.0
	_hit_active = false
	_hit_done = false
	_blast_fired = false
	_duration = float(_data["duration"])
	damage = float(_data["damage"])
	stagger = float(_data["stagger"])
	if finisher != &"":
		var fin := _finisher_data()
		damage *= float(fin["mult"])
		stagger = float(fin["stagger"])
		if float(fin["radius"]) > 0.0:
			_duration += FINISHER_EXTRA_TIME
	if combo:
		combo.notify_strike_started()
	airborne = combo != null and combo.is_air_string() and not player.is_on_floor()

	# Attacks softly track toward the lock-on target.
	if player.is_locked_on:
		player.face_lock_target(1.0)

	if airborne:
		_begin_air_strike(combo)
	if player.has_method(&"_rigless_cue"):
		player._rigless_cue(&"attack_heavy" if kind == &"heavy" else &"attack")

	if mage:
		_begin_bolt()
		AudioManager.play_sfx_varied("spell_cast", 0.7 if kind == &"heavy" or finisher != &"" else 0.45)
		return
	_spawn_arc()
	AudioManager.play_sfx_varied("attack_3" if kind == &"heavy" else "attack_1")


func exit() -> void:
	_set_hitbox(false)
	# v6 HH: a mage strike cancelled before its fire time fizzles its bolt.
	if _bolt and is_instance_valid(_bolt) and not _bolt_fired:
		_bolt.fizzle()
	_bolt = null
	var combo: ComboComponent = player.combo if "combo" in player else null
	if combo:
		combo.notify_strike_exited()


## True once the strike has reached its chain point (the next step may start).
func can_chain() -> bool:
	return step < 3 and _timer >= float(_data.get("chain_at", 0.0))


func process_physics(delta: float) -> StringName:
	_timer += delta
	if airborne:
		_apply_air_hold(delta)
	else:
		_apply_lunge(delta)

	var is_blast := not mage and finisher != &"" and float(ComboComponent.get_finisher_data(finisher)["radius"]) > 0.0
	var hit_start := float(_data["hit_start"])
	var hit_end := float(_data["hit_end"])
	if mage:
		if not _bolt_fired:
			if _timer >= hit_start:
				_fire_bolt()
			else:
				_hold_bolt()
	elif is_blast:
		if not _blast_fired and _timer >= hit_start:
			_fire_blast()
	else:
		if _timer >= hit_start and _timer < hit_end:
			if not _hit_active and not _hit_done:
				_set_hitbox(true)
		elif _hit_active:
			_set_hitbox(false)
			_hit_done = true

	var combo: ComboComponent = player.combo if "combo" in player else null
	if combo and can_chain() and combo.has_buffered():
		var next := combo.consume_buffered()
		if next != &"":
			return next

	if _timer >= _duration:
		if combo:
			combo.notify_strike_finished()
		if not player.is_on_floor():
			return &"Fall"
		return &"LockOnIdle" if player.is_locked_on else &"Idle"
	return &""


func process_input(event: InputEvent) -> StringName:
	var combo: ComboComponent = player.combo if "combo" in player else null
	# Contract: basic attacks cancel into dodge.
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		# v5 DD: an air strike cancels into the air dodge (once per airtime).
		if airborne and player.state_machine.states.has(&"AirDodge"):
			if combo and not combo.air_dodge_available():
				return &""
			return &"AirDodge"
		if combo:
			combo.reset(&"dodge")
		return &"Dodge"
	if event.is_action_pressed(&"attack"):
		var st: Node = player.stance if "stance" in player else null
		if st and player.in_battle and st.is_active() and st.handle_attack_press():
			return &""
		if combo:
			return combo.on_attack_pressed()
	elif event.is_action_released(&"attack"):
		var st2: Node = player.stance if "stance" in player else null
		if st2 and player.in_battle and st2.is_active() and st2.handle_attack_release():
			return &""
		if combo:
			return combo.on_attack_released()
	return &""


# --- Internals ---

## v5 DD: air strike setup: drift direction (stick, else facing) and the
## altitude hold from the first frame.
func _begin_air_strike(combo: ComboComponent) -> void:
	_drift_dir = _stick_direction()
	if _drift_dir == Vector3.ZERO or player.is_locked_on:
		_drift_dir = -player.global_basis.z
		_drift_dir.y = 0.0
		_drift_dir = _drift_dir.normalized()
	elif _drift_dir.length() > 0.1:
		player.basis = Basis.looking_at(_drift_dir)
	player.velocity.y = combo.air_hold_velocity(get_physics_process_delta_time())
	_play_hook(&"air_strike_heavy" if kind == &"heavy" else &"air_strike_light")


func _apply_air_hold(delta: float) -> void:
	var combo: ComboComponent = player.combo if "combo" in player else null
	if combo:
		player.velocity.y = combo.air_hold_velocity(delta)
	var speed := 0.0 if _enemy_too_close(_drift_dir) else AIR_DRIFT_SPEED
	player.velocity.x = _drift_dir.x * speed
	player.velocity.z = _drift_dir.z * speed


## Camera-relative flat stick direction (ZERO under the deadzone).
func _stick_direction() -> Vector3:
	var input := InputManager.get_movement_vector()
	if input.length() <= 0.1:
		return Vector3.ZERO
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	if cam == null:
		return Vector3.ZERO
	var forward := -cam.global_basis.z
	forward.y = 0.0
	var right := cam.global_basis.x
	right.y = 0.0
	var dir := forward.normalized() * -input.y + right.normalized() * input.x
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO


## Named animation hook: plays only if the AnimationPlayer has it.
func _play_hook(hook: StringName) -> void:
	var ap: AnimationPlayer = player.get(&"anim_player") as AnimationPlayer
	if ap and ap.has_animation(hook):
		ap.play(hook, 0.1)

func _apply_lunge(delta: float) -> void:
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if _timer < float(_data["lunge_time"]) and not _enemy_too_close(fwd):
		var speed := float(_data["lunge"])
		player.velocity.x = fwd.x * speed
		player.velocity.z = fwd.z * speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 35.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 35.0 * delta)


func _enemy_too_close(fwd: Vector3) -> bool:
	if not player.is_inside_tree():
		return false
	for e in player.get_tree().get_nodes_in_group(&"enemies"):
		var n := e as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var to: Vector3 = n.global_position - player.global_position
		to.y = 0.0
		if to.length() < LUNGE_STOP_DIST and to.normalized().dot(fwd) > 0.3:
			return true
	return false


func _set_hitbox(on: bool) -> void:
	var hb: Area3D = player.hitbox if "hitbox" in player else null
	if on:
		player.enable_hitbox(damage)
		if hb:
			hb.set_meta("stagger", stagger)
			hb.set_meta("hit_kind", &"finisher" if finisher != &"" else kind)
		_hit_active = true
	else:
		if _hit_active:
			player.disable_hitbox()
		if hb:
			if hb.has_meta("stagger"):
				hb.remove_meta("stagger")
			if hb.has_meta("hit_kind"):
				hb.remove_meta("hit_kind")
		_hit_active = false


## Finisher data from the strike's profile (melee = ComboComponent.FINISHERS).
func _finisher_data() -> Dictionary:
	if mage and profile:
		return profile.get_finisher_data(finisher)
	return ComboComponent.get_finisher_data(finisher)


# --- v6 HH mage strike ---

func _hand_position() -> Vector3:
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	return player.global_position + Vector3(0, MAGE_HAND_UP, 0) + fwd * MAGE_HAND_FORWARD


## Pick the soft-aim target, face it (ground strikes; air strikes keep their
## drift facing unless locked on) and spawn the charging bolt at the hand.
func _begin_bolt() -> void:
	_aim_target = MageBolt.pick_target(player, BasicAttackProfile.SOFT_AIM_RANGE, BasicAttackProfile.SOFT_AIM_DOT)
	if _aim_target and not player.is_locked_on and not airborne:
		var to: Vector3 = _aim_target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.1:
			player.basis = Basis.looking_at(to.normalized())
	var parent: Node = player.get_parent()
	if parent == null or not player.is_inside_tree():
		return
	var params := _bolt_params()
	_bolt = MageBolt.create(params)
	parent.add_child(_bolt)
	_bolt.global_position = _hand_position()


func _bolt_params() -> Dictionary:
	var p := {
		"damage": damage, "stagger": stagger, "source": player,
		"speed": float(_data.get("speed", 30.0)), "lifetime": float(_data.get("lifetime", 0.6)),
		"homing": float(_data.get("homing", 6.0)), "radius": float(_data.get("radius", 0.3)),
		"hit_kind": kind, "burst_radius": 0.0, "shake": [],
		"core_color": profile.core_color, "glow_color": profile.glow_color,
	}
	if finisher != &"":
		var fin := _finisher_data()
		p["burst_radius"] = float(fin.get("radius", 0.0))
		p["shake"] = fin.get("shake", [])
		p["speed"] = float(fin.get("speed", p["speed"]))
		p["lifetime"] = float(fin.get("lifetime", p["lifetime"]))
		p["homing"] = float(fin.get("homing", p["homing"]))
		p["radius"] = float(fin.get("size", p["radius"]))
		p["hit_kind"] = &"finisher"
	return p


func _hold_bolt() -> void:
	if player.is_locked_on:
		player.face_lock_target(get_physics_process_delta_time())
	if _bolt and is_instance_valid(_bolt):
		_bolt.hold_at(_hand_position())


func _fire_bolt() -> void:
	_bolt_fired = true
	if _aim_target == null or not is_instance_valid(_aim_target):
		_aim_target = MageBolt.pick_target(player, BasicAttackProfile.SOFT_AIM_RANGE, BasicAttackProfile.SOFT_AIM_DOT)
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	if _bolt and is_instance_valid(_bolt):
		_bolt.hold_at(_hand_position())
		_bolt.launch(fwd, _aim_target)
	last_bolt = {
		"kind": kind, "step": step, "finisher": finisher, "damage": damage,
		"stagger": stagger, "burst_radius": float(_finisher_data().get("radius", 0.0)) if finisher != &"" else 0.0,
		"target": _aim_target, "node": _bolt, "airborne": airborne,
	}


func _fire_blast() -> void:
	_blast_fired = true
	var fin := ComboComponent.get_finisher_data(finisher)
	var radius := float(fin["radius"])
	var fwd: Vector3 = -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var centre: Vector3 = player.global_position + fwd * BLAST_FORWARD
	var parent: Node = player.get_parent()
	var hits := BlastVFX.detonate(player, centre, radius, damage, stagger)
	if parent:
		BlastVFX.spawn(parent, centre + Vector3(0, 0.6, 0), radius)
	last_blast = {"radius": radius, "damage": damage, "hits": hits, "finisher": finisher}
	var shake: Array = fin["shake"]
	if shake.size() == 2:
		Events.camera_shake_requested.emit(float(shake[0]), float(shake[1]))


func _spawn_arc() -> void:
	var parent: Node = player.get_parent()
	if parent == null:
		return
	var origin: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var fwd: Vector3 = -player.global_basis.z
	if finisher == &"triple_slash":
		# Three quick pale arcs, alternating tilt.
		for i in 3:
			AttackVFX.spawn_strike(parent, origin, fwd, &"light", step, i * 0.07, (-1.0 if i % 2 else 1.0) * 30.0)
		return
	AttackVFX.spawn_strike(parent, origin, fwd, kind, step, 0.0, 0.0)
