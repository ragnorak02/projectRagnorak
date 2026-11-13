## Taighe's unique ability (v5, Package CC): Super Jump.
## Y in battle (R on keyboard): a vertical launch to ~HEIGHT_MULTIPLIER x the
## normal jump apex with a slight forward carry. The player enters Jump (then
## Fall -> Land as usual), so lock-on is kept and the Command Menu opened in the
## air shows the aerial list (Package BB's airborne rule).
## Instant ability: StanceComponent calls activate() instead of entering a
## stance (no aura, no stance tag). Cooldown in real time.
##
## Unique-ability contract (duck-typed, driven by StanceComponent):
##   setup(player, component), var display_name, var is_instant = true,
##   activate() -> bool, on_enter(), on_exit(reason),
##   on_attack_press() -> bool, on_attack_release() -> bool.
extends Node

const HEIGHT_MULTIPLIER := 5.0   # apex = 5 x (jump_force^2 / 2g)
const FORWARD_CARRY := 2.5       # m/s added along facing at takeoff
const COOLDOWN_MS := 3000
## States the launch may start from (grounded, free to act).
const START_STATES: Array[StringName] = [&"Idle", &"Run", &"Land", &"LockOnIdle", &"LockOnStrafe"]

signal launched(velocity_y: float)

var display_name: String = "SUPER JUMP"
var is_instant: bool = true
var player = null  # Player (duck-typed)
var component: Node = null

var _cooldown_until_ms: int = 0
## Counter for headless checks.
var jumps_fired: int = 0


func setup(p_player, p_component: Node) -> void:
	player = p_player
	component = p_component


## Launch velocity for the configured height multiplier: v = jump_force * sqrt(k).
func get_launch_velocity() -> float:
	return float(player.jump_force) * sqrt(HEIGHT_MULTIPLIER)


func is_on_cooldown() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_ms


func get_cooldown_remaining() -> float:
	return maxf(0.0, float(_cooldown_until_ms - Time.get_ticks_msec()) / 1000.0)


func can_activate() -> bool:
	if player == null or is_on_cooldown():
		return false
	if not player.is_on_floor():
		return false
	var sm: Node = player.get("state_machine")
	if sm == null or sm.get("current_state") == null:
		return false
	return StringName(sm.current_state.name) in START_STATES


## Fires the jump. Returns true on launch.
func activate() -> bool:
	if not can_activate():
		return false
	var vy := get_launch_velocity()
	if not player.launch_jump(vy, FORWARD_CARRY):
		return false
	_cooldown_until_ms = Time.get_ticks_msec() + COOLDOWN_MS
	jumps_fired += 1
	if player.is_inside_tree():
		StanceAuraVfx.flash(player.get_parent(), player.global_position, true)
	AudioManager.play_sfx_named("jump")
	launched.emit(vy)
	return true


# Stance hooks: an instant ability never holds a stance.
func on_enter() -> void:
	pass


func on_exit(_reason: StringName) -> void:
	pass


func on_attack_press() -> bool:
	return false


func on_attack_release() -> bool:
	return false
