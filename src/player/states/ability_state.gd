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


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	_phase = CastPhase.START
	_effect_spawned = false
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

	# Face the target at cast start
	var aim_target := _get_aim_target()
	if aim_target and is_instance_valid(aim_target) and aim_target != player:
		var dir := (aim_target.global_position - player.global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			player.basis = Basis.looking_at(dir.normalized())

	Events.ability_cast_started.emit(_ability_data)
	AudioManager.play_sfx_named("spell_cast")

	if DebugFlags.DEBUG_COMBAT:
		var name_str := _ability_data.display_name if _ability_data else "unknown"
		var target_str: String = aim_target.name if aim_target else "none"
		print("AbilityState: Cast started — %s → %s (%.1fs)" % [name_str, target_str, _cast_time])


func exit() -> void:
	_ability_data = null
	_effect_spawned = false
	_explicit_target = null


func process_physics(delta: float) -> StringName:
	_timer += delta
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
				if player.is_locked_on:
					return &"LockOnIdle"
				return &"Idle"

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
	# Priority: explicit target > lock-on target > null
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

	if _ability_data.effect_scene == null:
		# No effect scene — apply damage directly for melee/self abilities
		_apply_direct_damage()
		return

	var effect: Node3D = _ability_data.effect_scene.instantiate()
	player.get_tree().current_scene.add_child(effect)

	# Position effect at player, aimed toward target
	effect.global_position = player.global_position + Vector3(0, 1.0, 0)

	var aim_target := _get_aim_target()
	if aim_target and is_instance_valid(aim_target):
		var dir: Vector3 = (aim_target.global_position + Vector3(0, 1.0, 0) - effect.global_position).normalized()
		effect.look_at(effect.global_position + dir)
		if effect.has_method("set_target"):
			effect.set_target(aim_target)
	else:
		# Fallback: fire in player's facing direction
		effect.global_basis = player.global_basis

	if effect.has_method("set_damage"):
		effect.set_damage(_ability_data.damage)

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
