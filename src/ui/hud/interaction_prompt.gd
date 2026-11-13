## Shows the interact prompt ([Y] Talk / Press [E] to Interact) when the
## player is near an interactable, plus carry prompts (Controls v2/v3).
## v3: the glyph is ButtonGlyph(interact) = Y on pad / E on keyboard. In Battle
## Mode Y/E is the unique ability and interacting is routed off, so the pill
## hides (visual only, like the other suppressions) and returns on exit.
## Listens to Events signals for show/hide. Binding labels come from
## SettingsManager.get_action_label(&"interact", controller) so they follow
## the real (possibly rebound) InputMap.
##
## Carry prompt contract (Package I emits these; this UI only listens):
##   Events.carryable_in_range(obj)   -> obj != null: show [Y] Pick Up.
##                                       obj == null: clear that prompt.
##   Events.carry_started(obj)        -> show [Y] Put Down / Hold [Y] Throw
##                                       until carry_ended. Overrides every
##                                       other prompt while carrying.
##   Events.carry_ended(obj, reason)  -> remove the carry prompt and restore
##                                       the last interactable prompt (if any).
## A liftable crate that goes through the normal interactable path
## (interaction_available + get_prompt_text() == "Pick Up") also shows
## [Y] Pick Up without needing carryable_in_range.
extends CanvasLayer

const CARRY_PICK_UP_TEXT := "Pick Up"

const PROMPT_FONT_SIZE := 20
## Distance of the pill's bottom edge from the screen bottom (px @1080p).
const PROMPT_BOTTOM_OFFSET := 236.0

var _prompt_label: Label           # verb text next to the glyph
var _bg_panel: PanelContainer
var _glyph: ButtonGlyph
var _hold_label: Label             # carry: "Hold"
var _hold_glyph: ButtonGlyph       # carry: second interact glyph
var _hold_verb_label: Label        # carry: "Throw"
var _visible_state: bool = false

# Last interactable prompt (from interaction_available). Kept while carrying
# so it can be restored when the carry ends.
var _interactable: Node3D = null
var _custom_text: String = ""
var _has_interaction: bool = false

# Carry state (driven by Events.carry_* signals).
var _carryable: Node3D = null
var _carrying: bool = false

var _pulse_tween: Tween = null

# Mode suppression (visual only, CAR-P2): the pill hides while a dialogue,
# tactical mode or any UI menu is open, because B means something else there
# (advance / Back). The prompt state above is kept, so get_prompt_text() is
# unaffected and the pill comes back on its own when the mode closes.
var _dialogue_open: bool = false
var _tactical_open: bool = false
var _open_menus: Dictionary = {}   # menu_name -> true (from ui_menu_opened/closed)
# v3 Battle Mode: Y/E is the unique ability there, so an interact glyph would lie.
var _in_battle: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_tactical_open = GameManager.current_state == GameManager.GameState.TACTICAL_MODE
	_hide_prompt()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Small Lumina Frost glass pill, bottom-centre, above the party/command
	# panels. Anchored at the centre so it stays centred as the verb changes.
	_bg_panel = PanelContainer.new()
	_bg_panel.anchor_left = 0.5
	_bg_panel.anchor_right = 0.5
	_bg_panel.anchor_top = 1.0
	_bg_panel.anchor_bottom = 1.0
	_bg_panel.offset_top = -PROMPT_BOTTOM_OFFSET
	_bg_panel.offset_bottom = -PROMPT_BOTTOM_OFFSET
	_bg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bg_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.pill(UIStyle.GLASS, UIStyle.CYAN_DIM, 16.0, 6.0)
	_bg_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_bg_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(row)

	# [glyph] verb  (carry adds:  Hold [glyph] Throw)
	_glyph = ButtonGlyph.new().setup(&"interact")
	_glyph.glyph_height = 28.0
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glyph)

	_prompt_label = UIStyle.make_label("", PROMPT_FONT_SIZE, UIStyle.TEXT)
	_prompt_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_prompt_label)

	_hold_label = UIStyle.make_label("  ·  Hold", PROMPT_FONT_SIZE, UIStyle.TEXT_DIM)
	_hold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hold_label)

	_hold_glyph = ButtonGlyph.new().setup(&"interact")
	_hold_glyph.glyph_height = 28.0
	_hold_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hold_glyph)

	_hold_verb_label = UIStyle.make_label("Throw", PROMPT_FONT_SIZE, UIStyle.TEXT)
	_hold_verb_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hold_verb_label)


func _connect_signals() -> void:
	Events.interaction_available.connect(_on_interaction_available)
	Events.interaction_cleared.connect(_on_interaction_cleared)
	# Carry signals: connected defensively so this UI keeps working whether or
	# not the carry system (Package I) is present / emitting yet.
	_connect_if_present(&"carryable_in_range", _on_carryable_in_range)
	_connect_if_present(&"carry_started", _on_carry_started)
	_connect_if_present(&"carry_ended", _on_carry_ended)
	# Mode suppression (visual only)
	Events.dialogue_started.connect(_on_dialogue_started)
	Events.dialogue_ended.connect(_on_dialogue_ended)
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)
	Events.ui_menu_opened.connect(_on_menu_opened)
	Events.ui_menu_closed.connect(_on_menu_closed)
	_connect_if_present(&"battle_mode_changed", _on_battle_mode_changed)


func _connect_if_present(signal_name: StringName, callable: Callable) -> void:
	if Events.has_signal(signal_name) and not Events.is_connected(signal_name, callable):
		Events.connect(signal_name, callable)


# --- Interactable prompts ---

func _on_interaction_available(interactable: Node3D) -> void:
	_interactable = interactable
	_custom_text = ""
	if interactable != null and interactable.has_method("get_prompt_text"):
		_custom_text = interactable.get_prompt_text()
	_has_interaction = true
	# Drop any remembered crate. (Handler order varies: the crate's InteractArea
	# may re-emit carryable_in_range before or after this; either way the pill
	# shows the interactable's "Pick Up" text via _has_interaction.)
	_carryable = null
	_refresh(true)


func _on_interaction_cleared() -> void:
	_interactable = null
	_custom_text = ""
	_has_interaction = false
	# Out of range of everything, crates included. Without this the "Pick Up"
	# pill stayed up after walking away (only a pick-up ever cleared it).
	_carryable = null
	_refresh(false)


# --- Carry prompts ---

func _on_carryable_in_range(obj: Node3D) -> void:
	var changed := obj != _carryable
	_carryable = obj
	_refresh(changed and obj != null)


func _on_carry_started(_obj: Node3D) -> void:
	_carrying = true
	_carryable = null
	_refresh(true)


func _on_carry_ended(_obj: Node3D, _reason: StringName) -> void:
	_carrying = false
	# Restore the remembered interactable prompt only if it still exists.
	if _has_interaction and _interactable != null and not is_instance_valid(_interactable):
		_on_interaction_cleared()
		return
	_refresh(false)


# --- Mode suppression ---

func _on_dialogue_started() -> void:
	_set_suppression(func() -> void: _dialogue_open = true)


func _on_dialogue_ended() -> void:
	_set_suppression(func() -> void: _dialogue_open = false)


func _on_tactical_entered() -> void:
	_set_suppression(func() -> void: _tactical_open = true)


func _on_tactical_exited() -> void:
	_set_suppression(func() -> void: _tactical_open = false)


func _on_menu_opened(menu_name: StringName) -> void:
	_set_suppression(func() -> void: _open_menus[menu_name] = true)


func _on_menu_closed(menu_name: StringName) -> void:
	_set_suppression(func() -> void: _open_menus.erase(menu_name))


func _on_battle_mode_changed(in_battle: bool) -> void:
	_set_suppression(func() -> void: _in_battle = in_battle)


## Applies a suppression flag change and re-evaluates the pill only when the
## overall suppressed state flips (restoring plays the normal show feedback).
func _set_suppression(change: Callable) -> void:
	var was := is_suppressed()
	change.call()
	if was != is_suppressed():
		_refresh(true)


## True while a dialogue, tactical mode, a UI menu or Battle Mode hides the pill.
func is_suppressed() -> bool:
	return _dialogue_open or _tactical_open or not _open_menus.is_empty() or _in_battle


# --- Display ---

## Decides which prompt (if any) is visible. Priority:
## carrying > interactable prompt > carryable_in_range.
## While suppressed the pill stays hidden but the prompt state is kept.
func _refresh(play_feedback: bool) -> void:
	if (_carrying or _has_interaction or _has_valid_carryable()) and not is_suppressed():
		_show_prompt(play_feedback)
	else:
		_hide_prompt()


func _has_valid_carryable() -> bool:
	return _carryable != null and is_instance_valid(_carryable)


func _show_prompt(play_feedback: bool = true) -> void:
	var was_visible := _visible_state
	_visible_state = true
	_update_prompt_text()
	_bg_panel.visible = true
	if not play_feedback and was_visible:
		return
	AudioManager.play_sfx_named("interaction_prompt")

	# Subtle pulse animation on show
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	# Brief brightness flash plus a short rise, in unscaled time.
	_bg_panel.modulate = Color(1.25, 1.25, 1.35, 0.0)
	_pulse_tween = create_tween()
	_pulse_tween.set_ignore_time_scale(true)
	_pulse_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_bg_panel, "modulate", Color(1.25, 1.25, 1.35, 1.0), UIStyle.ANIM_TIME)
	_pulse_tween.tween_property(_bg_panel, "modulate", Color.WHITE, 0.3)


## Current interact binding label for the active device, e.g. [Y] / [E].
func get_key_hint() -> String:
	return "[%s]" % SettingsManager.get_action_label(&"interact", InputManager.is_using_controller())


## Text the prompt shows right now (exposed for tests).
func get_prompt_text() -> String:
	var key_hint := get_key_hint()
	if _carrying:
		return "%s Put Down / Hold %s Throw" % [key_hint, key_hint]
	if _has_interaction:
		if _custom_text != "":
			return "%s %s" % [key_hint, _custom_text]
		return "Press %s to Interact" % key_hint
	if _has_valid_carryable():
		return "%s %s" % [key_hint, CARRY_PICK_UP_TEXT]
	return ""


## Verb shown next to the glyph (the prompt text without the key hint).
func get_prompt_verb() -> String:
	if _carrying:
		return "Put Down"
	if _has_interaction:
		return _custom_text if _custom_text != "" else "Interact"
	if _has_valid_carryable():
		return CARRY_PICK_UP_TEXT
	return ""


func _update_prompt_text() -> void:
	# get_prompt_text() is the canonical text (tests); the pill shows it as
	# glyph + verb, with a second "Hold [glyph] Throw" group while carrying.
	_prompt_label.text = get_prompt_verb()
	_hold_label.visible = _carrying
	_hold_glyph.visible = _carrying
	_hold_verb_label.visible = _carrying


func _hide_prompt() -> void:
	_visible_state = false
	_bg_panel.visible = false


func _process(_delta: float) -> void:
	if not _visible_state:
		return
	# Drop a carryable that was freed without a clearing signal.
	if not _carrying and not _has_interaction and _carryable != null and not is_instance_valid(_carryable):
		_carryable = null
		_hide_prompt()
		return
	_update_prompt_text()
