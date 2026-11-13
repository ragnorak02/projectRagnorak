## MenuNav — stick/D-pad/key navigation helper for menus (v5, Package AA).
##
## Why: menus used to step on `is_action_pressed` of joypad-motion events. Stick
## noise around the action deadzone fires press/release/press..., so one push
## could move the cursor several rows ("twitch"). MenuNav swallows raw stick
## motion and turns it into clean steps:
##   - Left stick with hysteresis on the dominant axis: engage at |v| >= 0.6,
##     release when the engaged axis drops below 0.35. One push = one step.
##   - Holding the stick repeats: first repeat after 0.35 s, then every 0.11 s.
##   - Unscaled time (Time.get_ticks_usec) unless poll() is given a delta, so
##     tactical slow-time (0.05) or tree pause never changes the feel.
##   - D-pad and keys stay one press = one step (no echo repeats), via the
##     action lists given to the constructor.
##   - If the stick is already deflected when the menu opens (reset()), it must
##     return to neutral before it can step (no carry-over from movement).
##
## Usage (one instance per menu / per list):
##   var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"],
##                           [&"move_left", &"ui_left"], [&"move_right", &"ui_right"])
##   on open:            _nav.reset()
##   _unhandled_input:   if _nav.consume_event(event): set_input_as_handled(); return
##                       var s := _nav.event_step(event)   # D-pad / keys
##                       if s != Vector2i.ZERO: ...; set_input_as_handled(); return
##   _process:           var s := _nav.poll()              # stick steps + repeats
##                       if s.y != 0: move(s.y)   # y: -1 up, +1 down
##                       if s.x != 0: adjust(s.x) # x: -1 left, +1 right
class_name MenuNav
extends RefCounted

const ENGAGE := 0.6
const RELEASE := 0.35
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.11

## Stick axes that drive navigation (left stick).
const NAV_AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
## Stick axes whose raw motion is swallowed by consume_event (both sticks).
## Triggers (LT/RT, axes 4/5) are never swallowed.
const SWALLOW_AXES := [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]

var up_actions: Array = []
var down_actions: Array = []
var left_actions: Array = []
var right_actions: Array = []
## false = vertical-only list: horizontal stick pushes are ignored (still swallowed).
var horizontal: bool = true

var _axis: Vector2 = Vector2.ZERO
var _dir: Vector2i = Vector2i.ZERO      # engaged stick direction
var _timer: float = 0.0                 # time until the next repeat
var _pending: Vector2i = Vector2i.ZERO  # step produced by an engage, delivered by poll()
var _need_release: bool = false
var _last_usec: int = -1


func _init(p_up: Array = [&"ui_up"], p_down: Array = [&"ui_down"],
		p_left: Array = [&"ui_left"], p_right: Array = [&"ui_right"]) -> void:
	up_actions = p_up
	down_actions = p_down
	left_actions = p_left
	right_actions = p_right


## Clear all state (call when the menu opens / a list gains focus). A stick that
## is already deflected must go back to neutral before it can step.
func reset() -> void:
	_dir = Vector2i.ZERO
	_timer = 0.0
	_pending = Vector2i.ZERO
	_last_usec = -1
	_axis = _read_live_stick()
	_need_release = maxf(absf(_axis.x), absf(_axis.y)) >= RELEASE


## Feed every input event here first. Returns true for raw stick motion, which
## the menu must swallow (set_input_as_handled) and must NOT treat as a press.
func consume_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadMotion):
		return false
	var m := event as InputEventJoypadMotion
	if not SWALLOW_AXES.has(m.axis):
		return false
	if m.axis == JOY_AXIS_LEFT_X:
		_axis.x = m.axis_value
		_update_stick()
	elif m.axis == JOY_AXIS_LEFT_Y:
		_axis.y = m.axis_value
		_update_stick()
	return true


## Discrete step from a non-motion event (D-pad button, key). One press = one
## step; echoes and releases give ZERO. x: -1 left / +1 right, y: -1 up / +1 down.
func event_step(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadMotion or not event.is_pressed() or event.is_echo():
		return Vector2i.ZERO
	if _matches(event, up_actions):
		return Vector2i(0, -1)
	if _matches(event, down_actions):
		return Vector2i(0, 1)
	if _matches(event, left_actions):
		return Vector2i(-1, 0)
	if _matches(event, right_actions):
		return Vector2i(1, 0)
	return Vector2i.ZERO


## Call once per frame. Returns the stick step for this frame (ZERO most frames):
## the initial step after an engage, then held repeats. delta_real < 0 measures
## unscaled time itself.
func poll(delta_real: float = -1.0) -> Vector2i:
	var dt := delta_real
	var now := Time.get_ticks_usec()
	if dt < 0.0:
		dt = 0.0 if _last_usec < 0 else float(now - _last_usec) / 1000000.0
	_last_usec = now
	if _pending != Vector2i.ZERO:
		var p := _pending
		_pending = Vector2i.ZERO
		return p
	if _dir == Vector2i.ZERO:
		return Vector2i.ZERO
	_timer -= dt
	if _timer > 0.0:
		return Vector2i.ZERO
	_timer += REPEAT_RATE
	if _timer <= 0.0:
		_timer = REPEAT_RATE   # after a hitch: one step, never a burst
	return _dir


## True while the stick is held past the engage threshold (repeating).
func is_engaged() -> bool:
	return _dir != Vector2i.ZERO


## The last known left-stick vector (from events).
func get_stick() -> Vector2:
	return _axis


# --- internals ---------------------------------------------------------------

func _update_stick() -> void:
	var v := _axis
	if not horizontal:
		v.x = 0.0
	var ax := absf(v.x)
	var ay := absf(v.y)
	if _need_release:
		if maxf(ax, ay) < RELEASE:
			_need_release = false
		return
	if _dir == Vector2i.ZERO:
		if maxf(ax, ay) < ENGAGE:
			return
		if ay >= ax:
			_dir = Vector2i(0, 1 if v.y > 0.0 else -1)
		else:
			_dir = Vector2i(1 if v.x > 0.0 else -1, 0)
		_pending = _dir
		_timer = REPEAT_DELAY
		return
	var along := v.x * _dir.x if _dir.x != 0 else v.y * _dir.y
	if along < RELEASE:
		_dir = Vector2i.ZERO
		_timer = 0.0


func _matches(event: InputEvent, actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			return true
	return false


func _read_live_stick() -> Vector2:
	var pads := Input.get_connected_joypads()
	var best := Vector2.ZERO
	for d in pads:
		var v := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if v.length() > best.length():
			best = v
	return best
