extends State

var _timer: float = 0.0
@export var flinch_duration: float = 0.4


func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	player.disable_hitbox()

	# If we were casting an ability, interrupt it
	var ability_node: Node = player.state_machine.states.get(&"Ability")
	if ability_node and ability_node.has_method("interrupt"):
		ability_node.interrupt()


func process_physics(delta: float) -> StringName:
	_timer += delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)

	if _timer >= flinch_duration:
		if player.is_locked_on:
			return &"LockOnIdle"
		return &"Idle"
	return &""
