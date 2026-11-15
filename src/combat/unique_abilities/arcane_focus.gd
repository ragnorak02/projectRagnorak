## Taighe's unique ability (v8): Arcane Focus. Y in battle (R on keyboard).
##
## HOLD to channel: she stands still (player state "Focus"), a frost aura
## gathers around her, she regains MP_PER_SECOND MP, and the focus level rises
## 0 -> 1 over FULL_CHANNEL_S. Releasing (or a dodge) ends the channel; if it
## lasted at least MIN_CHANNEL_S she is FOCUSED: her next EMPOWERED_SHOTS basic
## bolts (X) hit harder (up to +MAX_BONUS damage and stagger at full focus),
## are bigger, and the hold-for-charged-shot threshold drops to
## FOCUSED_HOLD_THRESHOLD_MS (charged shots come out about twice as fast).
## The buff ends after BUFF_DURATION_MS, when the shots are spent, or when
## Battle Mode ends. A hit during the channel interrupts it (no buff; enemies
## may interrupt casting). Channels only from grounded free states.
##
## Unique-ability contract (duck-typed, driven by StanceComponent):
##   setup(player, component), var display_name, var is_channel = true,
##   activate() -> bool (starts the channel), channel_begin(), channel_tick(dt),
##   channel_end(reason), consume_attack_bonus() -> Dictionary,
##   hold_threshold_ms() -> int, clear_focus(),
##   on_enter(), on_exit(reason), on_attack_press(), on_attack_release().
extends Node

const FULL_CHANNEL_S := 1.2
const MIN_CHANNEL_S := 0.25
const MP_PER_SECOND := 6.0
const EMPOWERED_SHOTS := 3
const BUFF_DURATION_MS := 10000
const MAX_BONUS := 0.6
const FOCUSED_HOLD_THRESHOLD_MS := 110
## States the channel may start from (grounded, free to act).
const START_STATES: Array[StringName] = [&"Idle", &"Run", &"Land", &"LockOnIdle", &"LockOnStrafe"]

signal focus_gained(level: float)
signal focus_interrupted

var display_name: String = "ARCANE FOCUS"
var is_channel: bool = true
var player = null  # Player (duck-typed)
var component: Node = null

## Live channel state (public for tests / HUD).
var channeling: bool = false
var level: float = 0.0
var channel_time: float = 0.0
## Buff after a channel.
var charges: int = 0
var power: float = 0.0
var _buff_until_ms: int = 0
var _interrupted: bool = false
var _aura: Node3D = null

## Counters for headless checks.
var channels_started: int = 0
var shots_empowered: int = 0


func setup(p_player, p_component: Node) -> void:
	player = p_player
	component = p_component
	if not Events.player_hurt.is_connected(_on_player_hurt):
		Events.player_hurt.connect(_on_player_hurt)


func _exit_tree() -> void:
	_drop_aura()
	if Events.player_hurt.is_connected(_on_player_hurt):
		Events.player_hurt.disconnect(_on_player_hurt)


func can_activate() -> bool:
	if player == null or channeling:
		return false
	if not player.is_on_floor():
		return false
	var sm: Node = player.get("state_machine")
	if sm == null or sm.get("current_state") == null or not sm.states.has(&"Focus"):
		return false
	return StringName(sm.current_state.name) in START_STATES


## Starts the channel (enters the player's Focus state). Returns true on start.
func activate() -> bool:
	if not can_activate():
		return false
	return player.request_transition(&"Focus", {"ability": self})


func channel_begin() -> void:
	channeling = true
	level = 0.0
	channel_time = 0.0
	_interrupted = false
	channels_started += 1
	if player is Node3D and player.is_inside_tree():
		_aura = StanceAuraVfx.attach(player, StanceAuraVfx.new())
	AudioManager.play_sfx_named("spell_cast")


func channel_tick(delta: float) -> void:
	if not channeling:
		return
	var was_full := level >= 1.0
	channel_time += delta
	level = clampf(channel_time / FULL_CHANNEL_S, 0.0, 1.0)
	if player and player.has_method(&"restore_mp"):
		player.restore_mp(MP_PER_SECOND * delta)
	if level >= 1.0 and not was_full and player is Node3D and player.is_inside_tree():
		StanceAuraVfx.flash(player.get_parent(), player.global_position, true)


## Ends the channel. A long-enough, uninterrupted channel grants the buff.
func channel_end(reason: StringName = &"release") -> void:
	if not channeling:
		return
	channeling = false
	_drop_aura()
	if _interrupted or reason == &"hit":
		_interrupted = false
		level = 0.0
		focus_interrupted.emit()
		return
	if channel_time >= MIN_CHANNEL_S:
		charges = EMPOWERED_SHOTS
		power = level
		_buff_until_ms = Time.get_ticks_msec() + BUFF_DURATION_MS
		focus_gained.emit(power)
		if player is Node3D and player.is_inside_tree():
			StanceAuraVfx.flash(player.get_parent(), player.global_position, false)
	level = 0.0


func is_focused() -> bool:
	if charges <= 0:
		return false
	if Time.get_ticks_msec() > _buff_until_ms:
		charges = 0
		return false
	return true


## Called when a basic bolt starts: spends one charge and returns the bonus
## {damage, stagger, size} multipliers ({} when not focused).
func consume_attack_bonus() -> Dictionary:
	if not is_focused():
		return {}
	charges -= 1
	shots_empowered += 1
	var m := 1.0 + MAX_BONUS * clampf(power, 0.0, 1.0)
	return {"damage": m, "stagger": m, "size": 1.0 + 0.5 * clampf(power, 0.0, 1.0)}


## Heavy (charged shot) hold threshold while focused; -1 = default.
func hold_threshold_ms() -> int:
	return FOCUSED_HOLD_THRESHOLD_MS if is_focused() else -1


func clear_focus() -> void:
	charges = 0
	power = 0.0


func _on_player_hurt(_amount: float, _source: Node3D) -> void:
	if channeling:
		_interrupted = true


func _drop_aura() -> void:
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null


# Stance hooks: a channel never holds a toggle stance.
func on_enter() -> void:
	pass


func on_exit(_reason: StringName) -> void:
	pass


func on_attack_press() -> bool:
	return false


func on_attack_release() -> bool:
	return false
