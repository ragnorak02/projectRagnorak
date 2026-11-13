## Light/Heavy mixable combo driver (battle system v3, Package R).
##
## Child of Player ($ComboComponent, reachable as player.combo).
##
## Tap / hold (REAL time, Time.get_ticks_msec — immune to hit-stop 0.01 and
## tactical 0.05):
##   press released before HOLD_THRESHOLD_MS (0.22s)  -> Light, fires on release
##   held to HOLD_THRESHOLD_MS                         -> Heavy, fires at the
##                                                       threshold (no release wait)
##
## The combo string holds up to 3 letters (L/H). Input determined while a strike
## is still before its chain point is BUFFERED (one slot, latest wins) and the
## MeleeStrike state chains into it at its chain point. After a strike ends the
## window stays open CHAIN_GRACE_MS of real time (so a hold that crosses the end
## of a strike still continues the string from Idle). The string resets on:
##   &"timeout"     no input inside the window
##   &"dodge"       dodge (from a strike, or any time the player is in Dodge)
##   &"hit"         Events.player_hurt / Flinch
##   &"mode_change" Events.battle_mode_changed, unless a strike is running (the
##                  opening hit of a fight engages the enemy and must not eat
##                  the string it starts)
##   &"complete"    the step-3 finisher finished
##   &"manual"
## Step 3 is a finisher; see FINISHERS / get_finisher().
##
## v5 DD — AIR COMBO + AIR BUDGET. Jump and Fall are strike entry states too:
## an airborne press is timed exactly like a ground one (L/H mixable, max 3)
## and the MeleeStrike it starts runs in air mode (holds altitude, drifts).
## One air string per airtime: when an airborne string ends for any reason
## (finisher, timeout, dodge, hit) the air combo is SPENT until the player
## lands; further airborne presses are ignored (no re-hover, no ground snap).
## The air dodge budget (one per airtime) lives here too. Both reset on a real
## landing (is_on_floor and not rising), checked in _physics_process.
##   air_combo_available() / is_air_string() / air_hover_active()
##   air_dodge_available() / consume_air_dodge()
##
## Public API (published by Package Q; signatures unchanged):
##   on_attack_pressed() -> StringName   always &"" (the kind is not known on
##                                       press). v5: airborne presses are timed
##                                       too (air combo) and ignored once the
##                                       air combo is spent this airtime
##   on_attack_released() -> StringName  &"MeleeStrike" when a light strike
##                                       should start now (the caller returns
##                                       it; MeleeStrike.enter() pulls the
##                                       pending {kind, step} from here), else &""
##   current_string() -> String          "", "L", "LH", "HHH"
##   reset(reason := &"manual")
## Heavy-at-threshold is started from _process via
## player.request_transition(&"MeleeStrike", msg).
##
## Emits Events.combo_step(step, kind) (kind &"light"/&"heavy") when a strike
## starts and Events.combo_finisher(finisher_kind, radius) when step 3 starts.
## Legacy Events.combo_count_changed(step) / combo_reset are emitted too.
class_name ComboComponent
extends Node

const HOLD_THRESHOLD_MS := 220
## Real-time grace after a strike ends during which the string can continue.
const CHAIN_GRACE_MS := 300
const MAX_STEPS := 3

const KIND_LIGHT := &"light"
const KIND_HEAVY := &"heavy"

## States in which a determined light/heavy may start or chain a strike.
const STRIKE_ENTRY_STATES: Array[StringName] = [
	&"Idle", &"Run", &"LockOnIdle", &"LockOnStrafe", &"Land", &"MeleeStrike",
	&"Jump", &"Fall",
]
## v5 DD air hold: lift above the anchor (m) and correction gain (1/s).
const AIR_LIFT := 0.08
const AIR_HOLD_GAIN := 10.0
## Airborne entry states (v5 DD air combo).
const AIR_ENTRY_STATES: Array[StringName] = [&"Jump", &"Fall"]

## Finisher table (Approved Design). Indexed by finisher kind.
##   mult: damage multiplier on the step-3 strike's base damage
##   radius: blast radius in metres (0 = no blast, single-target slash)
##   stagger: stagger added to every enemy hit by the finisher
##   shake: [intensity, duration] for Events.camera_shake_requested ([] = none)
const FINISHERS := {
	&"triple_slash": {"mult": 1.0, "radius": 0.0, "stagger": 10.0, "shake": []},
	&"strong_slash": {"mult": 1.2, "radius": 0.0, "stagger": 16.0, "shake": []},
	&"blast":        {"mult": 1.6, "radius": 2.5, "stagger": 30.0, "shake": []},
	&"big_blast":    {"mult": 2.2, "radius": 3.5, "stagger": 45.0, "shake": []},
	&"huge_blast":   {"mult": 3.0, "radius": 5.0, "stagger": 70.0, "shake": [0.35, 0.35]},
}

var player: Node = null

var _string: String = ""
## Press bookkeeping (real ms). _press_ms < 0 = no press being timed.
var _press_ms: int = -1
var _heavy_fired: bool = false
## Strike waiting for the running strike's chain point (&"" = none).
var _buffered_kind: StringName = &""
## {kind, step} for the next MeleeStrike.enter() with an empty msg.
var _pending: Dictionary = {}
## Real ms after which a non-empty string times out (0 = window owned by a strike).
var _window_close_ms: int = 0
var _strike_running: bool = false

## Debug / test counters.
var last_reset_reason: StringName = &""

## v5 DD air budget (reset on landing).
## True while the current string was started airborne.
var _string_airborne: bool = false
var _air_combo_spent: bool = false
var _air_dodge_spent: bool = false
## Altitude (global y) the current air string holds (set when it starts).
var air_anchor_y: float = 0.0


func _ready() -> void:
	player = get_parent()
	Events.player_hurt.connect(_on_player_hurt)
	Events.battle_mode_changed.connect(_on_battle_mode_changed)


## v5 DD: landing refreshes the air budget and drops an unfinished air string
## (an air string never continues on the ground).
func _physics_process(_delta: float) -> void:
	if player == null or not (player is CharacterBody3D):
		return
	if player.is_on_floor() and player.velocity.y <= 0.0:
		if _string_airborne and not _strike_running:
			reset(&"landed")
		_air_combo_spent = false
		_air_dodge_spent = false


func _process(_delta: float) -> void:
	var state := _current_state_name()
	# Leaving the attack flow (Dodge, Flinch, TacticalIdle, Ability...) drops
	# the string and any hold in progress.
	if state != &"" and not (state in STRIKE_ENTRY_STATES):
		if not _string.is_empty() or _press_ms >= 0 or _buffered_kind != &"":
			reset(&"dodge" if state in [&"Dodge", &"AirDodge"] else (&"hit" if state == &"Flinch" else &"manual"))
		return
	var now := Time.get_ticks_msec()
	# Heavy at threshold, without waiting for release.
	if _press_ms >= 0 and not _heavy_fired and now - _press_ms >= HOLD_THRESHOLD_MS:
		_heavy_fired = true
		var next := _queue_step(KIND_HEAVY)
		if next != &"":
			player.request_transition(next, _take_pending())
	# Window timeout while not inside a strike.
	if not _strike_running and not _string.is_empty() and _press_ms < 0 \
			and _window_close_ms > 0 and now > _window_close_ms:
		reset(&"timeout")


# --- Published API ---

func on_attack_pressed() -> StringName:
	if player and player is CharacterBody3D and not player.is_on_floor() \
			and _current_state_name() != &"MeleeStrike":
		# v5 DD: airborne press = air combo, once per airtime.
		if not air_combo_available():
			return &""
	_press_ms = Time.get_ticks_msec()
	_heavy_fired = false
	return &""


func on_attack_released() -> StringName:
	if _press_ms < 0:
		return &""
	var was_heavy := _heavy_fired
	_press_ms = -1
	_heavy_fired = false
	if was_heavy:
		return &""
	return _queue_step(KIND_LIGHT)


func current_string() -> String:
	return _string


func reset(reason: StringName = &"manual") -> void:
	var had := not _string.is_empty()
	# v5 DD: an air string that ends (any reason) spends the air combo until
	# the player lands. Landing itself refreshes the budget right after.
	if had and _string_airborne:
		_air_combo_spent = true
	_string_airborne = false
	_string = ""
	_press_ms = -1
	_heavy_fired = false
	_buffered_kind = &""
	_pending = {}
	_window_close_ms = 0
	last_reset_reason = reason
	if had:
		Events.combo_reset.emit()


# --- MeleeStrike contract (used by melee_strike_state.gd) ---

## Pending {kind, step} for an entry with an empty msg; cleared on read.
func _take_pending() -> Dictionary:
	var p := _pending
	_pending = {}
	return p


func take_pending_strike() -> Dictionary:
	return _take_pending()


## Called by MeleeStrike.enter(): the strike owns the window now.
func notify_strike_started() -> void:
	_strike_running = true
	_window_close_ms = 0


## Called by MeleeStrike when its duration ends (not when cancelled).
func notify_strike_finished() -> void:
	_strike_running = false
	if _string.length() >= MAX_STEPS:
		reset(&"complete")
	else:
		_window_close_ms = Time.get_ticks_msec() + CHAIN_GRACE_MS


## Called by MeleeStrike.exit() on any exit (cancel, flinch, chain).
func notify_strike_exited() -> void:
	_strike_running = false
	if _window_close_ms == 0 and not _string.is_empty():
		_window_close_ms = Time.get_ticks_msec() + CHAIN_GRACE_MS


func has_buffered() -> bool:
	return _buffered_kind != &""


## Consume the buffered input at the strike's chain point. Returns
## &"MeleeStrike" (pending msg set) or &"".
func consume_buffered() -> StringName:
	if _buffered_kind == &"":
		return &""
	var k := _buffered_kind
	_buffered_kind = &""
	return _append_and_prepare(k)


## True while a press is being timed (hold not yet resolved).
func is_hold_pending() -> bool:
	return _press_ms >= 0 and not _heavy_fired


# --- v5 DD air budget ---

## True if an airborne press may start / continue an air string right now.
func air_combo_available() -> bool:
	return not _air_combo_spent


## True while the running string was started airborne.
func is_air_string() -> bool:
	return _string_airborne and not _string.is_empty()


## True while an air string is alive between strikes (press being timed or
## chain grace window open): Fall holds the altitude so the air hits stay level.
func air_hover_active() -> bool:
	if not is_air_string() or _string.length() >= MAX_STEPS:
		return false
	if _press_ms >= 0:
		return true
	return _window_close_ms > 0 and Time.get_ticks_msec() <= _window_close_ms


## Vertical velocity that holds the air string's altitude (anchor + a tiny
## lift). Player._physics_process subtracts gravity * delta BEFORE moving (the
## Player node processes before its StateMachine child), so the gravity term
## here cancels it and the net vertical speed is the small correction only.
func air_hold_velocity(delta: float) -> float:
	var g: float = float(player.get(&"gravity")) if player and player.get(&"gravity") != null else 30.0
	var target := air_anchor_y + AIR_LIFT
	var correction := clampf((target - player.global_position.y) * AIR_HOLD_GAIN, -2.0, 2.0)
	return g * delta + correction


func air_dodge_available() -> bool:
	return not _air_dodge_spent


## Spend the air dodge for this airtime. Returns false if already spent.
func consume_air_dodge() -> bool:
	if _air_dodge_spent:
		return false
	_air_dodge_spent = true
	return true


## Finisher kind for a full 3-letter string ending in `last` (&"" if step < 3).
static func get_finisher(combo_string: String) -> StringName:
	if combo_string.length() < MAX_STEPS:
		return &""
	var heavies := combo_string.count("H")
	if combo_string.ends_with("H"):
		match heavies:
			1: return &"blast"
			2: return &"big_blast"
			_: return &"huge_blast"
	return &"triple_slash" if heavies == 0 else &"strong_slash"


static func get_finisher_data(finisher: StringName) -> Dictionary:
	return FINISHERS.get(finisher, {})


# --- Internals ---

func _current_state_name() -> StringName:
	if player == null or not ("state_machine" in player) or player.state_machine == null:
		return &""
	var cur: Node = player.state_machine.current_state
	return StringName(cur.name) if cur else &""


## A light/heavy has been determined. Start it now (returns &"MeleeStrike" with
## the pending msg set), buffer it behind the running strike, or drop it.
func _queue_step(kind: StringName) -> StringName:
	var state := _current_state_name()
	if not (state in STRIKE_ENTRY_STATES):
		return &""
	if state == &"MeleeStrike":
		var strike: Node = player.state_machine.current_state
		if _string.length() >= MAX_STEPS:
			return &""  # finisher running: ignore until it ends
		if strike.has_method("can_chain") and strike.can_chain():
			return _append_and_prepare(kind)
		_buffered_kind = kind
		return &""
	var airborne := state in AIR_ENTRY_STATES
	if airborne and not air_combo_available():
		return &""
	# From locomotion: continue the string inside the window, else start fresh.
	# v5 DD: a ground string never continues in the air (and vice versa).
	if not _string.is_empty() and (_string.length() >= MAX_STEPS \
			or (_window_close_ms > 0 and Time.get_ticks_msec() > _window_close_ms) \
			or _string_airborne != airborne):
		reset(&"timeout")
	if _string.is_empty():
		_string_airborne = airborne
		if airborne:
			air_anchor_y = player.global_position.y
	return _append_and_prepare(kind)


func _append_and_prepare(kind: StringName) -> StringName:
	if _string.length() >= MAX_STEPS:
		reset(&"complete")
	_string += "H" if kind == KIND_HEAVY else "L"
	var step := _string.length()
	_pending = {"kind": kind, "step": step, "string": _string}
	_window_close_ms = 0
	Events.combo_step.emit(step, kind)
	Events.combo_count_changed.emit(step)
	if step == MAX_STEPS:
		var fin := get_finisher(_string)
		Events.combo_finisher.emit(fin, float(FINISHERS[fin]["radius"]))
	return &"MeleeStrike"


func _on_player_hurt(_amount: float, _source: Node3D) -> void:
	reset(&"hit")


func _on_battle_mode_changed(_in_battle: bool) -> void:
	if _strike_running or _press_ms >= 0:
		return
	reset(&"mode_change")
