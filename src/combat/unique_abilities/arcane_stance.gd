## Amaro's unique ability (battle v3, Package S): Arcane Stance.
## While active, X becomes magic:
##   tap X  (released before HOLD_THRESHOLD_MS) -> volley of 3 small orbs,
##          VOLLEY_SPACING_MS apart, toward the lock-on target or along facing.
##   hold X (past the threshold) -> CHARGE_MS charge with a growing orb at the
##          hand, then one large fireball (AoE burst). FIREBALL_COOLDOWN_MS.
##          Releasing during the charge cancels it (fizzle, no shot).
##          While the fireball is on cooldown a hold does not charge; the
##          release fires a normal volley instead, so the stance never goes dead.
## No MP cost (basic attacks are unlimited). All timing is real time
## (Time.get_ticks_msec) so hit-stop (0.01) / tactical (0.05) never stretch it.
##
## Unique-ability contract (duck-typed, driven by StanceComponent):
##   setup(player, component), on_enter(), on_exit(reason),
##   on_attack_press() -> bool, on_attack_release() -> bool, display_name.
extends Node

const ArcaneOrbScript := preload("res://src/effects/arcane_orb.gd")

const HOLD_THRESHOLD_MS := 220    # Same tap/hold split as melee (ComboComponent).
const CHARGE_MS := 400            # Charge after the hold is recognised.
const FIREBALL_COOLDOWN_MS := 1500
const VOLLEY_COUNT := 3
const VOLLEY_SPACING_MS := 60
const ORB_SPREAD := 0.25          # Lateral spawn offset between volley orbs (m).

## States in which stance shots cannot start/continue (charge + queued orbs
## are cancelled). Dodge itself still works; it just cancels the charge.
const BLOCKED_STATES: Array[StringName] = [
	&"Dodge", &"Flinch", &"LedgeGrab", &"ClimbUp", &"TacticalIdle",
	&"Ability", &"Carry", &"ThrowAim",
]

signal projectile_spawned(projectile)
signal charge_started
signal charge_cancelled

var display_name: String = "ARCANE"
var player = null  # Player (untyped: duck-typed fields like lock_on_target).
var component: Node = null

var _active: bool = false
var _press_ms: int = -1           # -1 = attack not held (or press not ours).
var _hold_spent: bool = false     # This hold already fired (or was cancelled).
var _charging: bool = false
var _charge_start_ms: int = 0
var _cooldown_until_ms: int = 0
var _pending_shots: Array[int] = []   # Real-time ms at which each queued orb fires.
var _volley_index: int = 0
var _charge_orb: MeshInstance3D = null

## Counters for headless checks.
var volleys_fired: int = 0
var orbs_fired: int = 0
var fireballs_fired: int = 0


func setup(p_player, p_component: Node) -> void:
	player = p_player
	component = p_component


func on_enter() -> void:
	_active = true
	_reset_input()


func on_exit(_reason: StringName) -> void:
	_active = false
	_reset_input()
	_pending_shots.clear()


## Returns true (consumed) whenever the stance is active.
func on_attack_press() -> bool:
	if not _active:
		return false
	_press_ms = Time.get_ticks_msec()
	_charging = false
	_hold_spent = false
	return true


## Consumed only if the matching press was ours (a press made before the
## stance was entered falls through to the melee combo).
func on_attack_release() -> bool:
	if not _active or _press_ms < 0:
		return false
	var held := Time.get_ticks_msec() - _press_ms
	_press_ms = -1
	if _hold_spent:
		_hold_spent = false   # Fireball already out / hold cancelled by a block.
	elif _charging:
		_cancel_charge()
	elif held < HOLD_THRESHOLD_MS or is_fireball_on_cooldown():
		_queue_volley()
	return true


func is_charging() -> bool:
	return _charging


## 0..1 charge progress (0 when not charging).
func get_charge_progress() -> float:
	if not _charging:
		return 0.0
	return clampf(float(Time.get_ticks_msec() - _charge_start_ms) / CHARGE_MS, 0.0, 1.0)


func is_fireball_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_ms


func get_cooldown_remaining() -> float:
	return maxf(0.0, float(_cooldown_until_ms - Time.get_ticks_msec()) / 1000.0)


func _process(_delta: float) -> void:
	if not _active or player == null:
		return
	var now := Time.get_ticks_msec()

	if not _can_cast():
		if _charging:
			_cancel_charge()
		if _press_ms >= 0:
			_hold_spent = true   # e.g. dodge mid-hold: the release fires nothing.
		_pending_shots.clear()
		return

	# Queued volley orbs.
	while not _pending_shots.is_empty() and now >= _pending_shots[0]:
		_pending_shots.pop_front()
		_fire_orb(_volley_index)
		_volley_index += 1

	# Hold -> charge -> fireball.
	if _press_ms >= 0 and not _charging and not _hold_spent \
			and now - _press_ms >= HOLD_THRESHOLD_MS and not is_fireball_on_cooldown():
		_start_charge(now)
	if _charging:
		var p := get_charge_progress()
		_update_charge_orb(p)
		if p >= 1.0:
			_charging = false
			_hold_spent = true
			_remove_charge_orb()
			_fire_fireball()


func _can_cast() -> bool:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if "current_hp" in player and player.current_hp <= 0.0:
		return false
	var sm: Node = player.get("state_machine")
	if sm and sm.get("current_state") != null:
		if StringName(sm.current_state.name) in BLOCKED_STATES:
			return false
	return true


func _reset_input() -> void:
	_press_ms = -1
	_hold_spent = false
	if _charging:
		_cancel_charge()
	_remove_charge_orb()


func _queue_volley() -> void:
	if not _pending_shots.is_empty():
		return  # Previous volley still releasing; the tap is swallowed.
	var now := Time.get_ticks_msec()
	_volley_index = 0
	for i in VOLLEY_COUNT:
		_pending_shots.append(now + i * VOLLEY_SPACING_MS)
	volleys_fired += 1
	# Fire the first orb this frame for responsiveness.
	if _can_cast():
		_pending_shots.pop_front()
		_fire_orb(0)
		_volley_index = 1


func _start_charge(now: int) -> void:
	_charging = true
	_charge_start_ms = now
	_ensure_charge_orb()
	AudioManager.play_sfx_named("spell_cast")
	charge_started.emit()


func _cancel_charge() -> void:
	_charging = false
	_remove_charge_orb()
	charge_cancelled.emit()


# --- Spawning ---------------------------------------------------------------

func _fire_orb(index: int) -> void:
	# Orbs fan out left / centre / right of the hand.
	var lateral := float(index - 1) * ORB_SPREAD
	var orb = ArcaneOrbScript.create(ArcaneOrbScript.Kind.ORB)
	_launch(orb, lateral)
	orbs_fired += 1
	AudioManager.play_sfx_varied("spell_release", 0.6, 1.15, 1.35)


func _fire_fireball() -> void:
	var fb = ArcaneOrbScript.create(ArcaneOrbScript.Kind.FIREBALL)
	_launch(fb, 0.0)
	fireballs_fired += 1
	_cooldown_until_ms = Time.get_ticks_msec() + FIREBALL_COOLDOWN_MS
	AudioManager.play_sfx_named("spell_release")


func _launch(proj, lateral: float) -> void:
	proj.source = player
	var forward := _facing()
	var right := forward.cross(Vector3.UP).normalized()
	var origin: Vector3 = player.global_position + Vector3(0, 1.2, 0) + forward * 0.6 + right * lateral
	var target := _aim_target()
	var dir: Vector3 = forward
	if target:
		dir = target.global_position + Vector3(0, 1.0, 0) - origin
		if dir.length() < 0.05:
			dir = forward
	var spawn_xform := Transform3D(Basis.looking_at(dir.normalized()), origin)

	# Same parenting/transform rule as AbilityState (basis before add_child,
	# because the projectile reads its travel direction in _ready).
	var parent: Node = player.get_tree().current_scene
	if parent == null or not (parent is Node3D) or not parent.is_ancestor_of(player):
		parent = player.get_parent()
	var parent_xform: Transform3D = (parent as Node3D).global_transform if parent is Node3D else Transform3D.IDENTITY
	proj.transform = parent_xform.affine_inverse() * spawn_xform
	parent.add_child(proj)
	if target:
		proj.set_target(target)
	projectile_spawned.emit(proj)


func _facing() -> Vector3:
	var f: Vector3 = -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _aim_target() -> Node3D:
	if player.get("is_locked_on") and is_instance_valid(player.get("lock_on_target")):
		return player.lock_on_target
	return null


# --- Charge orb (growing orb at the hand) -----------------------------------

func _ensure_charge_orb() -> void:
	if _charge_orb and is_instance_valid(_charge_orb):
		return
	_charge_orb = MeshInstance3D.new()
	_charge_orb.name = "ArcaneChargeOrb"
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	_charge_orb.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 3.5
	_charge_orb.material_override = mat
	_charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(_charge_orb)
	# Local space: player forward is -Z; hand sits front-right at chest height.
	_charge_orb.position = Vector3(0.3, 1.2, -0.6)
	_charge_orb.scale = Vector3.ONE * 0.15


func _update_charge_orb(progress: float) -> void:
	if _charge_orb and is_instance_valid(_charge_orb):
		_charge_orb.scale = Vector3.ONE * lerpf(0.15, 1.0, progress)


func _remove_charge_orb() -> void:
	if _charge_orb and is_instance_valid(_charge_orb):
		_charge_orb.queue_free()
	_charge_orb = null
