## Battle Mode / Free Roam switch (battle system v3, Package Q; manual toggle v4, Package W).
## Child of Player. Polls the player's read-only engaged-enemy check
## (player._any_enemy_engaged(): any EnemyBase whose ai_state is not IDLE/DEAD)
## about every 0.2s of real time.
##   - Enters Battle immediately when an enemy is engaged.
##   - Exits after `exit_delay_sec` (3.0s) of real time with no engaged enemy.
## Manual toggle (v4, `battle_toggle` = View/Back on pad, F on keyboard; the
## player gates the press, see player.can_toggle_battle()):
##   - Free roam -> toggle_manual(): enter Battle at once, even with no enemy
##     ("weapon drawn"). With no engaged enemy it does NOT time out; it ends on
##     the next press, or 3s after the last enemy disengages once a fight began.
##   - Battle -> toggle_manual(): back to Free Roam at once, even with enemies
##     engaged ("stand down"). Auto-entry is then suppressed until the player
##     deals damage (Events.enemy_hit, ignoring hits whose source is an AI
##     companion), takes damage (Events.player_hurt),
##     or an enemy that was not engaged at toggle time engages. Then auto Battle
##     resumes as in v3 (checked immediately).
## Every change emits the local `changed` signal first (the player uses it to
## drop a carried crate), then Events.battle_mode_changed(in_battle). A manual
## toggle additionally emits Events.battle_mode_manual_toggled(in_battle).
## Real time: Time.get_ticks_msec(), so hit-stop (0.01) and tactical (0.05) time
## scales don't stretch the exit delay. Time spent with the tree paused (pause
## menu) is NOT counted toward the exit delay (per-poll elapsed is capped).
## Never mutates enemy state.
class_name BattleModeComponent
extends Node

signal changed(in_battle: bool)

@export var poll_interval_sec: float = 0.2
@export var exit_delay_sec: float = 3.0
## Cap on real time credited per poll, so a long pause/hitch can't instantly
## expire the exit delay on resume.
const MAX_POLL_CREDIT_MS := 500

var _in_battle: bool = false
## Read-only: true while in Battle Mode.
var in_battle: bool:
	get:
		return _in_battle

## Read-only: true while a manual "stand down" blocks auto-entry.
var is_suppressed: bool:
	get:
		return _suppressed

## Read-only: true while a manual Battle is held open with no fight seen yet
## (no exit timer runs).
var is_manual_hold: bool:
	get:
		return _manual_hold

var _player: Node = null
var _last_poll_ms: int = 0
var _clear_ms: int = 0  # real ms accumulated with no engaged enemy (while in battle)
var _clear_started: bool = false  # first clear poll seen; counting from it
var _manual_hold: bool = false  # manual Battle, no enemy engaged since: never times out
var _suppressed: bool = false  # manual stand-down: auto-entry blocked
## instance_id -> true for enemies engaged at stand-down time (still engaged).
var _suppress_known: Dictionary = {}


func _ready() -> void:
	_player = get_parent()
	_last_poll_ms = Time.get_ticks_msec()
	Events.zone_exiting.connect(_on_zone_exiting)
	Events.enemy_hit.connect(_on_enemy_hit)
	Events.player_hurt.connect(_on_player_hurt)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var elapsed := now - _last_poll_ms
	if elapsed < int(poll_interval_sec * 1000.0):
		return
	_last_poll_ms = now
	_poll(mini(elapsed, MAX_POLL_CREDIT_MS))


## Run one poll right now (tests / callers that just changed enemy state).
## credit_ms = real time to count toward the exit delay (default 0).
func force_check(credit_ms: int = 0) -> void:
	_last_poll_ms = Time.get_ticks_msec()
	_poll(credit_ms)


## Leave Battle Mode immediately (zone exit, cutscene). Re-enters on the next
## poll if an enemy is still engaged. No-op in free roam. Clears a manual hold
## and any manual suppression.
func force_exit(_reason: StringName = &"forced") -> void:
	_clear_ms = 0
	_clear_started = false
	_manual_hold = false
	_clear_suppression()
	_set_in_battle(false)


## Manual Battle / Free Roam switch (v4). Flips the mode at once and returns the
## new in_battle value. Gating (menus, dialogue, carrying, dead, cutscene) is the
## caller's job (player.can_toggle_battle()).
func toggle_manual() -> bool:
	if _in_battle:
		# Stand down: suppress auto-entry until damage dealt/taken or a new
		# enemy engages.
		_manual_hold = false
		_suppressed = true
		_suppress_known = _engaged_ids()
		_set_in_battle(false)
	else:
		_clear_suppression()
		_set_in_battle(true)
		# Hold open only while nothing is engaged; with a live fight the normal
		# 3s-after-disengage rule applies.
		_manual_hold = not _is_engaged()
	_last_poll_ms = Time.get_ticks_msec()
	Events.battle_mode_manual_toggled.emit(_in_battle)
	return _in_battle


## Real seconds left before Battle Mode ends (0 if engaged, held, or free roam).
func get_exit_time_remaining() -> float:
	if not _in_battle or _clear_ms <= 0:
		return 0.0
	return maxf(exit_delay_sec - _clear_ms / 1000.0, 0.0)


func _poll(credit_ms: int) -> void:
	var engaged := _is_engaged()
	if _suppressed:
		_update_suppression()
		if _suppressed:
			return
	if engaged:
		_clear_ms = 0
		_clear_started = false
		_manual_hold = false  # a fight began: exit follows the v3 timer
		_set_in_battle(true)
		return
	if not _in_battle or _manual_hold:
		return
	# Count from the first poll that sees no engaged enemy, so the exit is
	# never earlier than exit_delay_sec after the disengage was observed.
	if _clear_started:
		_clear_ms += credit_ms
	_clear_started = true
	if _clear_ms >= int(exit_delay_sec * 1000.0):
		_clear_ms = 0
		_clear_started = false
		_set_in_battle(false)


## While suppressed: forget stand-down enemies that disengaged, and lift the
## suppression if any engaged enemy was not engaged at stand-down time.
func _update_suppression() -> void:
	var now_ids := _engaged_ids()
	for id in _suppress_known.keys():
		if not now_ids.has(id):
			_suppress_known.erase(id)
	for id in now_ids:
		if not _suppress_known.has(id):
			_clear_suppression()
			return


func _clear_suppression() -> void:
	_suppressed = false
	_suppress_known.clear()


## Resume auto Battle: drop the suppression and re-check right away.
func _resume_auto(_reason: StringName) -> void:
	if not _suppressed:
		return
	_clear_suppression()
	if is_inside_tree():
		force_check(0)


func _on_enemy_hit(_enemy: Node3D, _damage: float, source: Node3D) -> void:
	if not _suppressed or _is_companion_source(source):
		return
	_resume_auto(&"dealt_damage")


## True when the hit came from an AI companion (the source is, or sits under, a
## party member other than the player). Everything else — the player's hitbox,
## orbs, spells, blasts, thrown crates — counts as the player's damage.
func _is_companion_source(source: Node3D) -> bool:
	var n: Node = source
	while n != null and is_instance_valid(n):
		if n == _player:
			return false
		if n.is_in_group(&"party_members"):
			return true
		n = n.get_parent()
	return false


func _on_player_hurt(_damage: float, _source: Node3D) -> void:
	_resume_auto(&"took_damage")


func _is_engaged() -> bool:
	if _player and _player.has_method("_any_enemy_engaged"):
		return _player._any_enemy_engaged()
	return false


## instance_id -> true for every engaged enemy (same rule as _any_enemy_engaged).
func _engaged_ids() -> Dictionary:
	var out: Dictionary = {}
	if not is_inside_tree():
		return out
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var e := enemy as EnemyBase
		if e == null or not is_instance_valid(e):
			continue
		if e.ai_state != EnemyBase.AIState.IDLE and e.ai_state != EnemyBase.AIState.DEAD:
			out[e.get_instance_id()] = true
	return out


func _set_in_battle(value: bool) -> void:
	if value == _in_battle:
		return
	_in_battle = value
	_clear_ms = 0
	_clear_started = false
	changed.emit(value)
	Events.battle_mode_changed.emit(value)


func _on_zone_exiting(_zone_id: StringName) -> void:
	force_exit(&"zone_exit")
