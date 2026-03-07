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


func enter(msg: Dictionary = {}) -> void:
	_timer = 0.0
	_phase = CastPhase.START
	_effect_spawned = false
	_ability_data = msg.get("ability_data") as AbilityData

	if _ability_data:
		_cast_time = _ability_data.cast_time
		_release_time = _cast_time * 0.7
		_recovery_time = _cast_time * 0.3
	elif msg.has("cast_time"):
		_cast_time = msg["cast_time"]
		_release_time = _cast_time * 0.7
		_recovery_time = _cast_time * 0.3

	player.velocity = Vector3.ZERO

	# Face lock-on target at cast start
	if player.is_locked_on:
		player.face_lock_target(1.0)

	Events.ability_cast_started.emit(_ability_data)

	if DebugFlags.DEBUG_COMBAT:
		var name_str := _ability_data.display_name if _ability_data else "unknown"
		print("AbilityState: Cast started — %s (%.1fs)" % [name_str, _cast_time])


func exit() -> void:
	_ability_data = null
	_effect_spawned = false


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
	if DebugFlags.DEBUG_COMBAT:
		var name_str := _ability_data.display_name if _ability_data else "unknown"
		print("AbilityState: Cast interrupted — %s" % name_str)


func _spawn_effect() -> void:
	if _effect_spawned:
		return
	_effect_spawned = true

	if _ability_data == null:
		return

	if _ability_data.effect_scene == null:
		# No effect scene — apply damage directly for melee/self abilities
		_apply_direct_damage()
		return

	var effect: Node3D = _ability_data.effect_scene.instantiate()
	player.get_tree().current_scene.add_child(effect)

	# Position effect at player, aimed toward target
	effect.global_position = player.global_position + Vector3(0, 1.0, 0)

	if player.is_locked_on and is_instance_valid(player.lock_on_target):
		var dir: Vector3 = (player.lock_on_target.global_position - player.global_position).normalized()
		effect.look_at(effect.global_position + dir)
		if effect.has_method("set_target"):
			effect.set_target(player.lock_on_target)
	else:
		effect.global_basis = player.global_basis

	if effect.has_method("set_damage"):
		effect.set_damage(_ability_data.damage)

	Events.ability_effect_spawned.emit(effect, _ability_data)


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
