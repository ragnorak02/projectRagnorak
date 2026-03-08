## Shows "Press [E/Y] to Interact" when player is near an interactable object.
## Listens to Events signals for show/hide.
extends CanvasLayer

var _prompt_label: Label
var _bg_panel: PanelContainer
var _visible_state: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_hide_prompt()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bg_panel = PanelContainer.new()
	_bg_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bg_panel.position = Vector2(-120, -110)
	_bg_panel.custom_minimum_size = Vector2(240, 36)
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.85)
	style.border_color = Color(0.3, 0.5, 0.9, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_bg_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_bg_panel)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 15)
	_prompt_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.add_child(_prompt_label)


func _connect_signals() -> void:
	Events.interaction_available.connect(_on_interaction_available)
	Events.interaction_cleared.connect(_on_interaction_cleared)


func _on_interaction_available(interactable: Node3D) -> void:
	var custom_text: String = ""
	if interactable != null and interactable.has_method("get_prompt_text"):
		custom_text = interactable.get_prompt_text()
	_show_prompt(custom_text)


func _on_interaction_cleared() -> void:
	_hide_prompt()


var _custom_text: String = ""


var _pulse_tween: Tween = null


func _show_prompt(custom: String = "") -> void:
	_visible_state = true
	_custom_text = custom
	_update_prompt_text()
	_bg_panel.visible = true
	AudioManager.play_sfx_named("interaction_prompt")

	# Subtle pulse animation on show
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	_bg_panel.modulate = Color(1.2, 1.2, 1.3, 1.0)
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(_bg_panel, "modulate", Color.WHITE, 0.3)


func _update_prompt_text() -> void:
	var key_hint: String = "[Y]" if InputManager.is_using_controller() else "[E]"
	if _custom_text != "":
		_prompt_label.text = "%s %s" % [key_hint, _custom_text]
	else:
		_prompt_label.text = "Press %s to Interact" % key_hint


func _hide_prompt() -> void:
	_visible_state = false
	_bg_panel.visible = false


func _process(_delta: float) -> void:
	if not _visible_state:
		return
	_update_prompt_text()
