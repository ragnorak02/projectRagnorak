extends State

## Full ability cast state with start/release/recovery phases.
## Player is rooted in place during cast. Dodge cancel is blocked
## per design contract (illegal transition enforced in state machine).

enum CastPhase { START, RELEASE, RECOVERY }

var _timer: float = 0.0
var _cast_time: float = 1.0
var _release_time: float = 0.7  # Cast releases effect at 70% of cast time
var _recovery_time: float = 0.3
var _phase: CastPhase = CastPhase.START
var _ability_data: AbilityData = null
var _effect_spawned: bool = false
var _explicit_target: Node3D = null  # Target selected in tactical menu
## v4 X: "Fire Forward" from the Command Menu — ignore lock-on, aim along the
## camera's flat forward. Set by aim_forward() right after enter(); cleared on exit.
var _forward_aim: bool = false
## v5 BB6: Plunge Strike dive (AbilityData.CasterMotion.PLUNGE).
const PLUNGE_SPEED := 28.0
const PLUNGE_MAX_CARRY := 14.0   # m/s horizontal toward a chosen target
const PLUNGE_TIMEOUT := 1.5
var _plunging: bool = false
var _plunge_velocity: Vector3 = Vector3.ZERO
var _plunge_timer: float = 0.0
## v5 BB: last effect_script node spawned (read by tests/HUD; may be freed).
var last_effect: Node3D = null


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	_phase = CastPhase.START
	_effect_spawned = false
	_forward_aim = false
	_plunging = false
	_plunge_timer = 0.0
	_ability_data = msg.get("ability_data") as AbilityData
	_explicit_target = msg.get("target") as Node3D

	if _ability_data:
		_cast_time = _ability_data.cast_time
		_release_time = _cast_time * 0.7
		_recovery_time = _cast_time * 0.3
	elif msg.has("cast_time"):
		_cast_time = msg["cast_time"]
		_release_time = _cast_time * 0.7
		_recovery_time = _cast_time * 0.3

	player.velocity = Vector3.ZERO

	# Face the target at cast start. Untargeted (no explicit target, not locked
	# on — e.g. an offensive spell cast with no enemies): aim along the camera's
	# flat forward on controller, otherwise keep the player's current facing.
	var aim_target := _get_aim_target()
	if aim_target and is_instance_valid(aim_target) and aim_target != player:
		var dir := (aim_target.global_position - player.global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			player.basis = Basis.looking_at(dir.normalized())
	elif aim_target == null and InputManager.is_using_controller():
		var cam := player.get_viewport().get_camera_3d()
		if cam:
			var fwd := -cam.global_basis.z
			fwd.y = 0.0
			if fwd.length() > 0.1:
				player.basis = Basis.looking_at(fwd.normalized())

	Events.ability_cast_started.emit(_ability_data)
	AudioManager.play_sfx_named("spell_cast")
	# v5 EE: cosmetic RiglessVisual cue (no-op without one / before CC's helper).
	if player.has_method(&"_rigless_cue"):
		player._rigless_cue(&"cast")

	if DebugFlags.DEBUG_COMBAT:
		var name_str := _ability_data.display_name if _ability_data else "unknown"
		var target_str: String = aim_target.name if aim_target else "none"
		print("AbilityState: Cast started — %s → %s (%.1fs)" % [name_str, target_str, _cast_time])


func exit() -> void:
	_ability_data = null
	_effect_spawned = false
	_explicit_target = null
	_forward_aim = false
	_plunging = false


## v4 X: Command Menu "Fire Forward". Called by TacticalIdleState right after a
## successful untargeted request (this state has already entered). Drops any
## explicit/lock-on aim for this cast and faces the camera's flat forward on
## every device; the projectile then flies along the player's facing.
func aim_forward() -> void:
	_forward_aim = true
	_explicit_target = null
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	if cam:
		var fwd := -cam.global_basis.z
		fwd.y = 0.0
		if fwd.length() > 0.1:
			player.basis = Basis.looking_at(fwd.normalized())


func process_physics(delta: float) -> StringName:
	_timer += delta
	if _plunging:
		return _process_plunge(delta)
	player.velocity = Vector3.ZERO

	match _phase:
		CastPhase.START:
			if _timer >= _release_time:
				_phase = CastPhase.RELEASE
				_spawn_effect()
				_timer = 0.0

		CastPhase.RELEASE:
			if _timer >= _recovery_time:
				_phase = CastPhase.RECOVERY
				Events.ability_cast_completed.emit(_ability_data)
				if DebugFlags.DEBUG_COMBAT:
					var name_str := _ability_data.display_name if _ability_data else "unknown"
					print("AbilityState: Cast completed — %s" % name_str)
				return _follow_up_state()

	return &""


## After the cast: still airborne (v5 aerial casts) -> Fall, else as before.
func _follow_up_state() -> StringName:
	if not player.is_on_floor():
		return &"Fall"
	if player.is_locked_on:
		return &"LockOnIdle"
	return &"Idle"


## v5 BB6 Plunge Strike: dive until landing (or timeout), then the impact
## effect, then the normal completion (signal + follow-up state).
func _start_plunge() -> void:
	_plunging = true
	_plunge_timer = 0.0
	var carry := Vector3.ZERO
	var t := _get_aim_target()
	if t and is_instance_valid(t) and t != player:
		var flat := t.global_position - player.global_position
		flat.y = 0.0
		var height := maxf(player.global_position.y - t.global_position.y, 0.5)
		var fall_time := height / PLUNGE_SPEED
		carry = flat / maxf(fall_time, 0.05)
		if carry.length() > PLUNGE_MAX_CARRY:
			carry = carry.normalized() * PLUNGE_MAX_CARRY
	_plunge_velocity = Vector3(carry.x, -PLUNGE_SPEED, carry.z)
	player.velocity = _plunge_velocity


func _process_plunge(delta: float) -> StringName:
	_plunge_timer += delta
	if player.is_on_floor() or _plunge_timer >= PLUNGE_TIMEOUT:
		_plunging = false
		player.velocity = Vector3.ZERO
		_spawn_script_effect()
		_phase = CastPhase.RECOVERY
		Events.ability_cast_completed.emit(_ability_data)
		return _follow_up_state()
	player.velocity = _plunge_velocity
	return &""


func process_input(_event: InputEvent) -> StringName:
	## No dodge cancel allowed during spell cast (enforced by illegal transition too).
	## No other actions during casting.
	return &""


func interrupt() -> void:
	Events.ability_cast_interrupted.emit(_ability_data)
	AudioManager.play_sfx_named("spell_interrupt")
	if DebugFlags.DEBUG_COMBAT:
		var name_str := _ability_data.display_name if _ability_data else "unknown"
		print("AbilityState: Cast interrupted — %s" % name_str)


func _get_aim_target() -> Node3D:
	# Priority: Fire Forward (none) > explicit target > lock-on target > null
	if _forward_aim:
		return null
	if _explicit_target and is_instance_valid(_explicit_target):
		return _explicit_target
	if player.is_locked_on and is_instance_valid(player.lock_on_target):
		return player.lock_on_target
	return null


func _spawn_effect() -> void:
	if _effect_spawned:
		return
	_effect_spawned = true
	AudioManager.play_sfx_named("spell_release")

	if _ability_data == null:
		return

	# Handle heal abilities — no projectile, direct HP restore
	if _ability_data.ability_type == AbilityData.AbilityType.HEAL:
		_apply_heal()
		return

	# v5 BB6: caster dive first (impact spawns on landing).
	if _ability_data.caster_motion == AbilityData.CasterMotion.PLUNGE:
		_start_plunge()
		return

	# v5 BB: AT_TARGET / caster-centred effects (src/effects/abilities/*.gd).
	if _ability_data.effect_script != null:
		_spawn_script_effect()
		return

	if _ability_data.effect_scene == null:
		# No effect scene — apply damage directly for melee/self abilities
		_apply_direct_damage()
		return

	var effect: Node3D = _ability_data.effect_scene.instantiate()

	# Build the spawn transform BEFORE add_child: projectiles read their travel
	# direction from global_basis in _ready(). Previously the basis was set after
	# add_child, so _ready() saw identity and untargeted spells always flew
	# world -Z regardless of facing.
	var origin: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var aim_target := _get_aim_target()
	var aim_valid: bool = aim_target != null and is_instance_valid(aim_target)
	var dir: Vector3
	if aim_valid:
		dir = aim_target.global_position + Vector3(0, 1.0, 0) - origin
	else:
		dir = -player.global_basis.z  # Untargeted: player's facing
	if dir.length() < 0.01:
		dir = -player.global_basis.z
	var spawn_xform := Transform3D(Basis.looking_at(dir.normalized()), origin)

	var parent: Node = player.get_tree().current_scene
	if parent == null:
		parent = player.get_parent()
	var parent_xform: Transform3D = (parent as Node3D).global_transform if parent is Node3D else Transform3D.IDENTITY
	effect.transform = parent_xform.affine_inverse() * spawn_xform
	parent.add_child(effect)

	if aim_valid and effect.has_method("set_target"):
		effect.set_target(aim_target)

	if effect.has_method("set_damage"):
		effect.set_damage(_ability_data.damage)

	Events.ability_effect_spawned.emit(effect, _ability_data)


## v5 BB: instantiate AbilityData.effect_script (Node3D) in the current scene
## and hand it caster / target / ability / aim direction (see ability_fx.gd).
func _spawn_script_effect() -> void:
	if _ability_data == null or _ability_data.effect_script == null:
		return
	var aim_target := _get_aim_target()
	var aim_valid: bool = aim_target != null and is_instance_valid(aim_target) and aim_target != player
	var aim_dir: Vector3 = -player.global_basis.z
	if aim_valid:
		aim_dir = aim_target.global_position - player.global_position
	var effect := Node3D.new()
	effect.name = "AbilityFX_%s" % String(_ability_data.ability_id)
	effect.set_script(_ability_data.effect_script)
	var parent: Node = player.get_tree().current_scene
	if parent == null:
		parent = player.get_parent()
	parent.add_child(effect)
	if effect.has_method(&"setup"):
		effect.setup(player, aim_target if aim_valid else null, _ability_data, aim_dir)
	last_effect = effect
	Events.ability_effect_spawned.emit(effect, _ability_data)


func _apply_heal() -> void:
	var target := _get_aim_target()
	if target == null:
		target = player  # Default to self

	var heal_amount: float = _ability_data.damage  # "damage" field doubles as heal amount

	if target == player:
		player.heal(heal_amount)
	elif target.has_method("heal"):
		target.heal(heal_amount)

	# Green healing VFX burst at target
	_spawn_heal_vfx(target)

	if DebugFlags.DEBUG_COMBAT:
		print("AbilityState: Healed %s for %.0f HP" % [target.name, heal_amount])


func _spawn_heal_vfx(target: Node3D) -> void:
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	vfx.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.3, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vfx.material_override = mat

	target.get_parent().add_child(vfx)
	vfx.global_position = target.global_position + Vector3(0, 1.0, 0)

	var tween := vfx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(vfx, "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(vfx.queue_free)


func _apply_direct_damage() -> void:
	if _ability_data == null:
		return
	# For melee/AOE abilities without a projectile, check hitbox overlap
	if _ability_data.ability_type == AbilityData.AbilityType.MELEE:
		player.enable_hitbox(_ability_data.damage)
		# Auto-disable after a short window
		player.get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(player):
				player.disable_hitbox()
		)
