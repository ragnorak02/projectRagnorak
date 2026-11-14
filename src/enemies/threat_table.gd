## Per-enemy threat table (v6 Package II): deterministic target selection
## among the party bodies.
##
## Threat is keyed by MEMBER id (PartySystem members[i]["id"]), not by body:
## a party switch swaps identities between bodies, so an enemy that was
## fighting Amaro keeps fighting Amaro (now in the other body) instead of
## chasing the Player node across the arena.
##
## Score per candidate (higher wins):
##   threat[key]                               (damage dealt, decays over time)
## + PROXIMITY_WEIGHT * (1 - dist / range)     (closer = more interesting)
## + STICKY_BONUS                if current    (hysteresis against flapping)
## - CROWD_PENALTY * crowd                     (other enemies already on it:
##                                              spreads groups over the party)
## Ties keep the current target, then the lowest candidate index (party order).
## The owner only calls pick() on a fixed interval, and never sooner than
## MIN_HOLD after a voluntary switch, so the target cannot flap per frame.
extends RefCounted

const DAMAGE_WEIGHT := 1.0
## Threat given to the member whose body triggered the aggro area.
const ENGAGE_THREAT := 5.0
const PROXIMITY_WEIGHT := 15.0
const STICKY_BONUS := 10.0
const CROWD_PENALTY := 6.0
## Fraction of stored threat lost per second (game time).
const DECAY_PER_SEC := 0.1
## Seconds between voluntary re-evaluations.
const RETARGET_INTERVAL := 0.5
## Minimum seconds on a target before a voluntary switch.
const MIN_HOLD := 2.0

var _threat: Dictionary = {}  # StringName key -> float


func add(key: StringName, amount: float) -> void:
	if amount <= 0.0 or key == &"":
		return
	_threat[key] = float(_threat.get(key, 0.0)) + amount * DAMAGE_WEIGHT


func get_threat(key: StringName) -> float:
	return float(_threat.get(key, 0.0))


func decay(delta: float) -> void:
	if _threat.is_empty():
		return
	var k := maxf(0.0, 1.0 - DECAY_PER_SEC * delta)
	for key in _threat.keys():
		_threat[key] = float(_threat[key]) * k


func clear() -> void:
	_threat.clear()


func score(key: StringName, dist: float, proximity_range: float, is_current: bool, crowd: int) -> float:
	var s := get_threat(key)
	if proximity_range > 0.0:
		s += PROXIMITY_WEIGHT * clampf(1.0 - dist / proximity_range, 0.0, 1.0)
	if is_current:
		s += STICKY_BONUS
	s -= CROWD_PENALTY * float(crowd)
	return s


## candidates: Array of {key: StringName, dist: float, crowd: int} in a stable
## order (party order). Returns the chosen index, or -1 when empty.
func pick(candidates: Array, current_key: StringName, proximity_range: float) -> int:
	var best := -1
	var best_score := -INF
	var best_is_current := false
	for i in candidates.size():
		var c: Dictionary = candidates[i]
		var cur: bool = c["key"] == current_key
		var s := score(c["key"], float(c["dist"]), proximity_range, cur, int(c["crowd"]))
		# Strictly greater wins; on an exact tie the current target is kept.
		if s > best_score or (is_equal_approx(s, best_score) and cur and not best_is_current):
			best = i
			best_score = s
			best_is_current = cur
	return best
