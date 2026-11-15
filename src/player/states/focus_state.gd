## v8 channel state (Taighe's Arcane Focus). Node: StateMachine/Focus.
## Entered by a channel unique ability (msg {"ability": node}) while Y / R is
## held in battle. Rooted (no movement), faces the lock-on target, ticks the
## ability each physics frame. Ends when the button is released, Battle Mode
## ends or the player leaves the floor; a dodge press breaks the channel into
## DodgeReady (whatever focus was gathered still counts). A hit forces Flinch
## (Player.take_damage) and the ability treats that as an interrupt.
extends State

## Release is polled after this long (a press/release in one frame still channels).
const MIN_HOLD_S := 0.05

var ability: Node = null
var elapsed: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	ability = msg.get("ability") as Node
	elapsed = 0.0
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if ability and ability.has_method(&"channel_begin"):
		ability.channel_begin()
	if player.has_method(&"_rigless_cue"):
		player._rigless_cue(&"cast")


func exit() -> void:
	if ability and is_instance_valid(ability) and ability.has_method(&"channel_end"):
		ability.channel_end(&"release")
	ability = null


func process_physics(delta: float) -> StringName:
	elapsed += delta
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if ability == null or not is_instance_valid(ability):
		return _neutral()
	if not player.is_on_floor():
		return &"Fall"
	if not player.in_battle:
		return _neutral()
	if player.is_locked_on:
		player.face_lock_target(delta)
	ability.channel_tick(delta)
	if elapsed >= MIN_HOLD_S and not player.is_unique_held():
		return _neutral()
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"dodge") and player.dodge_ready:
		return &"DodgeReady"
	return &""


func _neutral() -> StringName:
	return &"LockOnIdle" if player.is_locked_on else &"Idle"
