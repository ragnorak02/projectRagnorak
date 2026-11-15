## WorldPrompt (v7) — FF7 Rebirth-style floating button prompt.
## When the player can interact with something, the interact button (Y on pad,
## E on keyboard, follows rebinding via ButtonGlyph) floats next to the object
## inside a round ring, with the verb on a small glass pill beside it.
##  - Hold interactions (Interactable.requires_hold()) read "Hold · <verb>" and
##    the ring fills gold while the button is held
##    (Events.interaction_hold_progress).
##  - Other interactables within MARKER_RANGE get a small cyan diamond so you
##    notice them before you are in range.
## Hidden (visual only, same rules as InteractionPrompt) in dialogue, tactical
## mode, any UI menu and Battle Mode. While carrying, the bottom pill
## (InteractionPrompt) shows Put Down / Throw instead.
## Read-only listener: never touches the player or the interactables.
extends CanvasLayer

const MARKER_RANGE := 10.0
const MAX_MARKERS := 8
const RING_SIZE := 46.0
const GLYPH_HEIGHT := 28.0
const LABEL_FONT_SIZE := 20
const SCREEN_MARGIN := 24.0


## Round ring around the glyph; doubles as the hold-progress meter.
class Ring extends Control:
	var progress: float = 0.0     # 0..1 hold fill
	var hold: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r, Color(UIStyle.GLASS_DEEP, 0.7))
		draw_arc(c, r, 0.0, TAU, 48, Color(UIStyle.TEXT, 0.55 if not hold else 0.35), 2.0, true)
		if hold and progress > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UIStyle.GOLD, 4.0, true)


## Full-screen layer that draws the "something is nearby" diamonds.
class Markers extends Control:
	var points: PackedVector2Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for p in points:
			var s := 6.0
			var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
			draw_colored_polygon(pts, Color(UIStyle.CYAN, 0.55))
			pts.append(pts[0])
			draw_polyline(pts, Color(UIStyle.GLASS_DEEP, 0.8), 1.5, true)


var _root: Control
var _prompt: Control          # moves to the projected anchor
var _ring: Ring
var _glyph: ButtonGlyph
var _pill: PanelContainer
var _label: Label
var _markers: Markers

var _target: Node3D = null    # focused interactable (or carryable crate)
var _carrying: bool = false
var _hold_progress: float = 0.0
var _camera: Camera3D = null
var _pop: float = 1.0         # 0 -> 1 scale-in on a new target

# Suppression (visual only; mirrors InteractionPrompt).
var _dialogue_open: bool = false
var _tactical_open: bool = false
var _open_menus: Dictionary = {}
var _in_battle: bool = false


func _ready() -> void:
	layer = 9  # under the bottom pill / menus (10+)
	_build_ui()
	_connect_signals()
	_tactical_open = GameManager.current_state == GameManager.GameState.TACTICAL_MODE
	_prompt.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "WorldPromptRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_markers = Markers.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_markers)

	_prompt = Control.new()
	_prompt.name = "Prompt"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)

	# Ring centred on the anchor point; the pill hangs to its right.
	_ring = Ring.new()
	_ring.size = Vector2(RING_SIZE, RING_SIZE)
	_ring.position = -_ring.size * 0.5
	_prompt.add_child(_ring)

	_glyph = ButtonGlyph.new().setup(&"interact")
	_glyph.glyph_height = GLYPH_HEIGHT
	_ring.add_child(_glyph)

	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.GLASS, UIStyle.CYAN_DIM, 12.0, 4.0))
	_prompt.add_child(_pill)
	_label = UIStyle.make_label("", LABEL_FONT_SIZE, UIStyle.TEXT)
	_pill.add_child(_label)


func _connect_signals() -> void:
	Events.interaction_available.connect(_on_interaction_available)
	Events.interaction_cleared.connect(_on_interaction_cleared)
	Events.carryable_in_range.connect(_on_carryable_in_range)
	Events.carry_started.connect(func(_o: Node3D) -> void: _carrying = true)
	Events.carry_ended.connect(func(_o: Node3D, _r: StringName) -> void: _carrying = false)
	Events.interaction_hold_progress.connect(_on_hold_progress)
	Events.dialogue_started.connect(func() -> void: _dialogue_open = true)
	Events.dialogue_ended.connect(func() -> void: _dialogue_open = false)
	Events.tactical_mode_entered.connect(func() -> void: _tactical_open = true)
	Events.tactical_mode_exited.connect(func() -> void: _tactical_open = false)
	Events.ui_menu_opened.connect(func(n: StringName) -> void: _open_menus[n] = true)
	Events.ui_menu_closed.connect(func(n: StringName) -> void: _open_menus.erase(n))
	Events.battle_mode_changed.connect(func(b: bool) -> void: _in_battle = b)


func _on_interaction_available(obj: Node3D) -> void:
	if obj != _target:
		_pop = 0.0
		_hold_progress = 0.0
	_target = obj


func _on_interaction_cleared() -> void:
	_target = null
	_hold_progress = 0.0


func _on_carryable_in_range(obj: Node3D) -> void:
	# A crate's own InteractArea is the interactable; only take a bare crate
	# when nothing else is focused.
	if obj != null and _target == null:
		_pop = 0.0
		_target = obj


func _on_hold_progress(obj: Node3D, ratio: float) -> void:
	if obj == _target:
		_hold_progress = maxf(ratio, 0.0)


## True while a dialogue, tactical mode, a menu or Battle Mode hides prompts.
func is_suppressed() -> bool:
	return _dialogue_open or _tactical_open or not _open_menus.is_empty() or _in_battle or _carrying


## Read-only for tests: the node the prompt is showing for (null = none).
func get_target() -> Node3D:
	return _target if _target != null and is_instance_valid(_target) else null


## Read-only for tests: text on the pill right now.
func get_label_text() -> String:
	return _label.text


func is_prompt_visible() -> bool:
	return _prompt.visible


func _target_needs_hold() -> bool:
	var t := get_target()
	return t != null and t.has_method("requires_hold") and t.requires_hold()


func _verb_for(t: Node3D) -> String:
	if t.has_method("get_prompt_text"):
		var s: String = t.get_prompt_text()
		if s != "":
			return s
	return "Interact"


func _anchor_for(t: Node3D) -> Vector3:
	if t.has_method("get_prompt_anchor"):
		return t.get_prompt_anchor()
	return t.global_position + Vector3(0.0, 1.2, 0.0)


func _active(t: Node) -> bool:
	if not is_instance_valid(t) or not (t is Node3D) or not (t as Node3D).is_visible_in_tree():
		return false
	return not t.has_method("is_active") or t.is_active()


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	var t := get_target()
	if t == null and _target != null:
		_target = null  # freed without a clear
	if _camera == null or is_suppressed():
		_prompt.visible = false
		_set_markers(PackedVector2Array())
		return
	_update_prompt(t, delta)
	_update_markers(t)


func _update_prompt(t: Node3D, delta: float) -> void:
	if t == null or not _active(t):
		_prompt.visible = false
		return
	var world := _anchor_for(t)
	if _camera.is_position_behind(world):
		_prompt.visible = false
		return
	var screen := _camera.unproject_position(world)
	var rect := _root.get_rect().grow(-SCREEN_MARGIN)
	if not rect.has_point(screen):
		_prompt.visible = false
		return

	var hold := _target_needs_hold()
	var verb := _verb_for(t)
	_label.text = ("Hold  ·  " + verb) if hold else verb
	_ring.hold = hold
	_ring.progress = _hold_progress if hold else 0.0
	_ring.queue_redraw()
	# Centre the glyph in the ring and hang the pill to the right.
	_glyph.position = (_ring.size - _glyph.size) * 0.5
	_pill.reset_size()
	_pill.position = Vector2(RING_SIZE * 0.5 + 6.0, -_pill.size.y * 0.5)

	_pop = minf(_pop + delta / UIStyle.ANIM_TIME, 1.0)
	var s := lerpf(0.75, 1.0, ease(_pop, 0.4))
	_prompt.scale = Vector2(s, s)
	_prompt.modulate.a = _pop
	_prompt.position = screen.round()
	_prompt.visible = true


func _update_markers(focused: Node3D) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		_set_markers(PackedVector2Array())
		return
	var pts := PackedVector2Array()
	var rect := _root.get_rect()
	var r2 := MARKER_RANGE * MARKER_RANGE
	for n in get_tree().get_nodes_in_group(&"interactable"):
		if pts.size() >= MAX_MARKERS:
			break
		if n == focused or not _active(n):
			continue
		var n3 := n as Node3D
		if n3.global_position.distance_squared_to(player.global_position) > r2:
			continue
		var world := _anchor_for(n3)
		if _camera.is_position_behind(world):
			continue
		var sp := _camera.unproject_position(world)
		if rect.has_point(sp):
			pts.append(sp.round())
	_set_markers(pts)


func _set_markers(pts: PackedVector2Array) -> void:
	if pts == _markers.points:
		return
	_markers.points = pts
	_markers.queue_redraw()
