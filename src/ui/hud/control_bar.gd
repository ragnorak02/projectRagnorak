## Context hint stack (UI modernization, Package N).
## Replaces the old full-width bottom control bar with a compact "Lumina Frost"
## glass panel on the left edge (lower-middle) holding 3–5 GlyphHints chosen from
## the player's current state and mode (Battle System v3, Package U):
##   Free roam : Jump / Attack / Dodge / Command (pad Y = Interact while a prompt
##               is active, else Command; keyboard adds E Interact next to Q)
##   Battle    : Command / Attack (hold Heavy) / <Unique> / Dodge
##   Stance    : Command / Orbs (hold Fireball) / Exit Stance / Dodge
##   (v4) Free / Battle / Stance end with the battle_toggle hint:
##        "Back  Battle" in free roam, "Back  Free Roam" in battle/stance
##   Carrying  : Put Down / Hold Throw / Jump
##   ThrowAim  : Throw / Release Cancel
##   Tactical, dialogue, open menus : hidden (they show their own hints)
## Routed glyphs: on controller the Command Menu and the unique ability have no
## InputMap binding (they ride on A / Y per mode), so those hints draw the
## physical button through ButtonGlyph.label_override (see routed_label()).
## Respects SettingsManager.show_control_hints. Read-only: it only reads public
## getters (player.state_machine.current_state, CarryComponent.is_carrying) and
## Events signals, and never mutates gameplay state.
## Builds UI programmatically — no .tscn needed.
extends CanvasLayer

# Full control reference (kept for tests/tools). Binding labels come from
# SettingsManager.get_action_label() so hints follow the real (possibly rebound)
# InputMap. pad_visible=false would hide an entry in the controller view.
# Controls v2: every entry is visible on both devices.
# Order follows the v2 controller layout: MOVE, ATTACK (X), DODGE (LB),
# JUMP (Y), COMMAND (A), INTERACT (B), RUN (L3), LOCK-ON (RT), PAUSE.
const CONTROLS: Array[Dictionary] = [
	{ "action": &"move_up", "name": "MOVE", "pad_visible": true },
	{ "action": &"attack", "name": "ATTACK", "pad_visible": true },
	{ "action": &"dodge", "name": "DODGE", "pad_visible": true },
	{ "action": &"jump", "name": "JUMP", "pad_visible": true },
	{ "action": &"tactical_mode", "name": "COMMAND", "pad_visible": true },
	{ "action": &"interact", "name": "INTERACT", "pad_visible": true },
	{ "action": &"sprint", "name": "RUN", "pad_visible": true },
	{ "action": &"lock_on", "name": "LOCK-ON", "pad_visible": true },
	{ "action": &"pause", "name": "PAUSE", "pad_visible": true },
]

# Movement sub-actions (used when composing the MOVE label).
const MOVE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
]

enum Context { FREE, CARRY, AIM, HIDDEN, BATTLE, STANCE }

## Gap between the hint panel and the bottom screen edge.
const BOTTOM_MARGIN := 28.0

# Routed roles (v3): the pad glyph comes from the mode, not from the InputMap.
const ROLE_COMMAND := &"command"
const ROLE_UNIQUE := &"unique"

# Context hint sets: [action, text] or [action, text, role]. "%s" in a unique
# hint's text is replaced by the active member's unique ability name.
const HINTS_FREE: Array = [
	[&"jump", "Jump"],
	[&"attack", "Attack"],
	[&"dodge", "Dodge"],
	[&"tactical_mode", "Command", &"command"],
]
const HINT_INTERACT: Array = [&"interact", "Interact"]
const HINTS_BATTLE: Array = [
	[&"tactical_mode", "Command", &"command"],
	[&"attack", "Attack · Hold Heavy"],
	[&"unique_ability", "%s", &"unique"],
	[&"dodge", "Dodge"],
]
const HINTS_STANCE: Array = [
	[&"tactical_mode", "Command", &"command"],
	[&"attack", "Orbs · Hold Fireball"],
	[&"unique_ability", "Exit Stance", &"unique"],
	[&"dodge", "Dodge"],
]
const HINTS_CARRY: Array = [
	[&"interact", "Put Down"],
	[&"interact", "Hold to Throw"],
	[&"jump", "Jump"],
]
# v4 (Package W): manual mode switch, appended last in Free / Battle / Stance.
const HINT_TO_BATTLE: Array = [&"battle_toggle", "Battle"]
const HINT_TO_FREE_ROAM: Array = [&"battle_toggle", "Free Roam"]
const HINTS_AIM: Array = [
	[&"attack", "Throw"],
	[&"interact", "Release to Cancel"],
]

const HINT_FONT_SIZE := 18
const HINT_GLYPH_HEIGHT := 26.0

var _root: Control
var _panel: SlantPanel
var _stack: VBoxContainer
# Current GlyphHint widgets (plain Control array — see Package K gotchas).
var _hints: Array[Control] = []
var _hint_actions: Array[StringName] = []   # action each hint represents
var _hint_press: Array[StringName] = []     # physical action polled for the held highlight
var _hint_pressed: Array[bool] = []
var _built_interact: bool = false           # FREE set was built with a prompt active
var _built_controller: bool = false

var _context: int = -1
var _has_interaction: bool = false
var _tactical_open: bool = false
var _dialogue_open: bool = false
var _open_menus: Dictionary = {}
var _player: Node = null
var _show_serial: int = 0


func _ready() -> void:
	layer = 11
	_build_ui()
	InputManager.device_changed.connect(_on_device_changed)
	SettingsManager.settings_changed.connect(refresh_labels)
	Events.tactical_mode_entered.connect(func() -> void: _tactical_open = true)
	Events.tactical_mode_exited.connect(func() -> void: _tactical_open = false)
	Events.dialogue_started.connect(func() -> void: _dialogue_open = true)
	Events.dialogue_ended.connect(func() -> void: _dialogue_open = false)
	Events.ui_menu_opened.connect(_on_menu_opened)
	Events.ui_menu_closed.connect(_on_menu_closed)
	Events.interaction_available.connect(_on_interaction_available)
	Events.interaction_cleared.connect(_on_interaction_cleared)
	# Mode / stance changes are also polled each frame; the signals just make
	# the swap land on the same frame.
	Events.battle_mode_changed.connect(func(_b: bool) -> void: _update_context())
	Events.stance_changed.connect(func(_m: StringName, _s: StringName) -> void: _update_context())
	# v5: the Y label follows the controlled member (Arcane Stance / Super Jump).
	Events.party_member_switched.connect(func(_o: StringName, _n: StringName) -> void: _update_context(true))
	refresh_labels()


func _on_device_changed(_new_device: int) -> void:
	refresh_labels()


func _on_menu_opened(menu_name: StringName) -> void:
	_open_menus[menu_name] = true


func _on_menu_closed(menu_name: StringName) -> void:
	_open_menus.erase(menu_name)


func _on_interaction_available(_interactable: Node3D) -> void:
	_has_interaction = true


func _on_interaction_cleared() -> void:
	_has_interaction = false


## Re-reads binding labels (glyphs) for the active input device and re-applies
## the show_control_hints setting. Call after a rebind (rebind_action does not
## emit settings_changed).
func refresh_labels() -> void:
	for c in _hints:
		var h := c as GlyphHint
		if h != null and is_instance_valid(h):
			h.get_glyph().refresh()
	_update_context(true)


## Binding text for CONTROLS[index] on the given device (e.g. "X", "LMB", "WASD").
func get_control_label(index: int, controller: bool) -> String:
	if index < 0 or index >= CONTROLS.size():
		return ""
	return _get_bind_text(CONTROLS[index], controller)


func _get_bind_text(ctrl: Dictionary, controller: bool) -> String:
	if ctrl["name"] == "MOVE":
		if controller:
			return SettingsManager.get_action_label(&"move_up", true)
		# Composite: first key of each direction -> "WASD".
		var keys := ""
		for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
			keys += SettingsManager.get_action_label(action, false).get_slice("/", 0)
		return keys
	return SettingsManager.get_action_label(ctrl["action"], controller)


## Glyph label for a routed role (ROLE_COMMAND / ROLE_UNIQUE) on a device.
## Keyboard: the real binding (tactical_mode = Q, unique_ability = R).
## Controller: Command = jump's button (A) in battle, interact's button (Y) in
## free roam; Unique = interact's button (Y). Follows rebinds of jump/interact.
static func routed_label(role: StringName, in_battle: bool, controller: bool) -> String:
	return ButtonGlyph.label_for(routed_action(role, in_battle, controller), controller)


## The InputMap action that actually fires a routed role on a device.
static func routed_action(role: StringName, in_battle: bool, controller: bool) -> StringName:
	if role == ROLE_UNIQUE:
		return &"interact" if controller else &"unique_ability"
	if not controller:
		return &"tactical_mode"
	return &"jump" if in_battle else &"interact"


## Current hints as [glyph label, text] pairs, e.g. [["A", "Command"], ...].
func get_hint_entries() -> Array:
	var out: Array = []
	for c in _hints:
		var h := c as GlyphHint
		if h != null and is_instance_valid(h):
			out.append([h.get_glyph().get_label(), h.text])
	return out


# --- Build -----------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Flush with the left screen edge, slanted on the right, anchored to the
	# bottom-left corner and growing upward. The bottom-left Command Menu never
	# overlaps it: the hints hide while the menu is open (Context.HIDDEN).
	_panel = SlantPanel.new()
	_panel.slant_left = false
	_panel.slant_right = true
	_panel.slant = 14.0
	_panel.padding = 10
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 0.0
	_panel.offset_top = -BOTTOM_MARGIN
	_panel.offset_bottom = -BOTTOM_MARGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(_panel)

	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override(&"separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_stack)
	_panel.visible = false


func _hint_set_for(ctx: int) -> Array:
	match ctx:
		Context.CARRY:
			return HINTS_CARRY
		Context.AIM:
			return HINTS_AIM
		Context.FREE:
			var hints: Array = HINTS_FREE.duplicate()
			if _has_interaction:
				if _is_controller():
					# Pad Y interacts while a prompt shows (Command needs no prompt).
					hints[hints.size() - 1] = HINT_INTERACT
				else:
					hints.append(HINT_INTERACT)
			hints.append(HINT_TO_BATTLE)
			return hints
		Context.BATTLE:
			var bh: Array = HINTS_BATTLE
			if _unique_name() == "":
				bh = HINTS_BATTLE.filter(func(e: Array) -> bool: return e.size() < 3 or e[2] != ROLE_UNIQUE)
			return bh + [HINT_TO_FREE_ROAM]
		Context.STANCE:
			return HINTS_STANCE + [HINT_TO_FREE_ROAM]
	return []


func _is_controller() -> bool:
	return InputManager.is_using_controller()


## Display name of the active member's unique ability ("Arcane Stance"), or "".
func _unique_name() -> String:
	var p := _get_player()
	var st: Node = p.get(&"stance") if p != null else null
	if st == null or not (&"ability_id" in st):
		return ""
	var id: StringName = st.ability_id
	if id == &"" or st.get(&"ability") == null:
		return ""
	return String(id).capitalize()


func _rebuild_hints(ctx: int) -> void:
	for h in _hints:
		if is_instance_valid(h):
			_stack.remove_child(h)
			h.queue_free()
	_hints.clear()
	_hint_actions.clear()
	_hint_press.clear()
	_hint_pressed.clear()
	var pad := _is_controller()
	var battle := ctx == Context.BATTLE or ctx == Context.STANCE
	_built_interact = _has_interaction
	_built_controller = pad
	for entry: Array in _hint_set_for(ctx):
		var text: String = entry[1]
		if text.contains("%s"):
			text = text % _unique_name()
		var hint := GlyphHint.create(entry[0], text, HINT_FONT_SIZE)
		hint.glyph_height = HINT_GLYPH_HEIGHT
		hint.text_color = UIStyle.TEXT
		var press: StringName = entry[0]
		if entry.size() >= 3:
			# Routed: draw the physical button so "---" never shows on pad.
			hint.get_glyph().label_override = routed_label(entry[2], battle, pad)
			press = routed_action(entry[2], battle, pad)
		_stack.add_child(hint)
		_hints.append(hint)
		_hint_actions.append(entry[0])
		_hint_press.append(press)
		_hint_pressed.append(false)


# --- State -----------------------------------------------------------------

func _get_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = null
	if is_inside_tree():
		var players := get_tree().get_nodes_in_group(&"player")
		if not players.is_empty():
			_player = players[0]
	return _player


func _compute_context() -> int:
	if not SettingsManager.show_control_hints:
		return Context.HIDDEN
	if _tactical_open or _dialogue_open or not _open_menus.is_empty():
		return Context.HIDDEN
	if GameManager.current_state == GameManager.GameState.TACTICAL_MODE:
		return Context.HIDDEN
	var p := _get_player()
	if p == null:
		return Context.HIDDEN
	var state_name := &""
	var sm: Node = p.get(&"state_machine")
	if sm != null and sm.get(&"current_state") != null:
		state_name = sm.current_state.name
	if state_name == &"ThrowAim":
		return Context.AIM
	var carry: Node = p.get_node_or_null(^"CarryComponent")
	if state_name == &"Carry" or (carry != null and carry.get(&"is_carrying") == true):
		return Context.CARRY
	if p.get(&"in_battle") == true:
		var st: Node = p.get(&"stance")
		if st != null and st.has_method(&"is_active") and st.is_active():
			return Context.STANCE
		return Context.BATTLE
	return Context.FREE


func _update_context(force: bool = false) -> void:
	var ctx := _compute_context()
	var interact_changed := ctx == Context.FREE and _built_interact != _has_interaction
	var device_changed := ctx != Context.HIDDEN and _built_controller != _is_controller()
	if not force and ctx == _context and not interact_changed and not device_changed:
		return
	var was_hidden := _context == Context.HIDDEN or _context == -1
	var ctx_changed := ctx != _context
	_context = ctx
	if ctx == Context.HIDDEN:
		_panel.visible = false
		return
	_rebuild_hints(ctx)
	_show_panel(was_hidden or ctx_changed)


## Shows the panel once the new hints have been laid out (one frame later, so
## the container's minimum size is current), re-anchoring it to the left edge
## first so it never keeps a stale size/position. Slides in on context changes.
func _show_panel(slide: bool) -> void:
	_show_serial += 1
	var serial := _show_serial
	if not _panel.visible:
		_panel.modulate.a = 0.0
	_panel.visible = true
	if not is_inside_tree():
		_panel.modulate.a = 1.0
		return
	await get_tree().process_frame
	if serial != _show_serial or _context == Context.HIDDEN or not is_instance_valid(_panel):
		return
	if _panel.has_meta(&"_ui_home"):
		_panel.remove_meta(&"_ui_home")
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = -BOTTOM_MARGIN
	_panel.offset_bottom = -BOTTOM_MARGIN
	if slide or _panel.modulate.a < 1.0:
		UIStyle.fade_slide_in(_panel, Vector2.LEFT if slide else Vector2.ZERO)


func _process(_delta: float) -> void:
	_update_context()
	if not _panel.visible:
		return
	# Light up a hint while its action is held.
	for i in _hints.size():
		var pressed := Input.is_action_pressed(_hint_press[i])
		if pressed != _hint_pressed[i]:
			_hint_pressed[i] = pressed
			var h := _hints[i] as GlyphHint
			if h != null:
				h.text_color = UIStyle.GOLD if pressed else UIStyle.TEXT
