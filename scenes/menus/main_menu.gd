## Main menu — Battle Test, New Game, Continue, Load Game, Options, Exit.
## Battle Test (v7) loads the walled practice arena (scenes/zones/battle_test).
## Visuals: "Lumina Frost" title treatment, slanted buttons (UIStyle.style_button
## keeps each Button's signals and focus), frost backdrop and a footer glyph bar.
extends Control

## Frost backdrop: deep navy gradient, a cold Lumina glow on the right and faint
## horizontal bands. Static (no animation).
const BACKDROP_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.020, 0.040, 0.070);
	vec3 bottom = vec3(0.008, 0.016, 0.030);
	vec3 c = mix(top, bottom, uv.y);
	float glow = smoothstep(0.75, 0.0, distance(uv * vec2(1.78, 1.0), vec2(1.30, 0.42)));
	c += vec3(0.10, 0.36, 0.42) * glow * 0.55;
	float horizon = exp(-pow((uv.y - 0.62) * 9.0, 2.0)) * smoothstep(0.2, 1.0, uv.x);
	c += vec3(0.20, 0.55, 0.60) * horizon * 0.12;
	float bands = step(0.5, fract(uv.y * 180.0)) * 0.012;
	c += vec3(bands);
	float vig = smoothstep(1.15, 0.35, distance(uv, vec2(0.55, 0.5)));
	c *= mix(0.55, 1.0, vig);
	COLOR = vec4(c, 1.0);
}
"""

const SaveLoadMenuScript := preload("res://src/ui/menus/save_load_menu.gd")
const SettingsMenuScript := preload("res://src/ui/menus/settings_menu.gd")

@onready var battle_test_btn: Button = $VBox/BattleTest
@onready var new_game_btn: Button = $VBox/NewGame
@onready var continue_btn: Button = $VBox/Continue
@onready var load_btn: Button = $VBox/Load
@onready var options_btn: Button = $VBox/Options
@onready var exit_btn: Button = $VBox/Exit

var _save_load_menu: Node = null
var _settings_menu: Node = null
## v5 (AA): stick navigation. Raw stick motion is swallowed in _input (before the
## GUI focus system sees it) and turned into one step per push / steady repeat.
## D-pad and keys keep using Godot's focus navigation (one press = one step).
var _nav := MenuNav.new([&"ui_up"], [&"ui_down"], [], [])


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.change_state(GameManager.GameState.MAIN_MENU)

	battle_test_btn.pressed.connect(_on_battle_test)
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	load_btn.pressed.connect(_on_load)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)

	# Enable Continue only if saves exist
	var has_save: bool = SaveManager.has_any_save()
	continue_btn.disabled = not has_save
	load_btn.disabled = not has_save

	_apply_style()
	battle_test_btn.grab_focus()  # top option
	_nav.horizontal = false
	_nav.reset()


func _sub_menu_open() -> bool:
	for m in [_save_load_menu, _settings_menu]:
		if m != null and is_instance_valid(m) and m.get("_is_open") == true:
			return true
	return false


func _input(event: InputEvent) -> void:
	# Sub-menus run their own MenuNav; only the button list is handled here.
	if _sub_menu_open():
		return
	if _nav.consume_event(event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _sub_menu_open():
		_nav.reset()
		return
	var step := _nav.poll()
	if step.y != 0:
		_step_focus(step.y)


## Moves focus to the next/previous enabled button (wraps), like the D-pad.
func _step_focus(direction: int) -> void:
	var buttons: Array = []
	for b in [battle_test_btn, new_game_btn, continue_btn, load_btn, options_btn, exit_btn]:
		if is_instance_valid(b) and b.visible and not b.disabled:
			buttons.append(b)
	if buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var idx := buttons.find(focused)
	idx = 0 if idx < 0 else wrapi(idx + direction, 0, buttons.size())
	(buttons[idx] as Button).grab_focus()
	AudioManager.play_sfx_named("menu_select")


func _unhandled_input(event: InputEvent) -> void:
	# Confirm uses ui_accept only (joypad A / Enter / Space). A focused Button
	# already consumes ui_accept in its own _gui_input, so this only runs as a
	# fallback (e.g. focus was lost to a mouse click on empty space).
	if event.is_action_pressed(&"ui_accept"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and not (focused as BaseButton).disabled:
			focused.emit_signal(&"pressed")
		elif focused == null:
			battle_test_btn.grab_focus()
		get_viewport().set_input_as_handled()


func _on_battle_test() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	get_tree().change_scene_to_file("res://scenes/zones/battle_test.tscn")


func _on_new_game() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	get_tree().change_scene_to_file("res://scenes/zones/town_hub.tscn")


func _on_continue() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	if not SaveManager.continue_game():
		# Fallback if continue fails
		get_tree().change_scene_to_file("res://scenes/zones/town_hub.tscn")


func _on_load() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	if _save_load_menu == null:
		_save_load_menu = CanvasLayer.new()
		_save_load_menu.set_script(SaveLoadMenuScript)
		add_child(_save_load_menu)
		_save_load_menu.menu_closed.connect(_restore_focus.bind(load_btn))
	# Release focus so the focused Button does not consume ui_accept (joypad A /
	# Enter) meant for the sub-menu and re-trigger itself.
	get_viewport().gui_release_focus()
	_save_load_menu.open_menu(1)  # 1 = Mode.LOAD


func _on_options() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	if _settings_menu == null:
		_settings_menu = CanvasLayer.new()
		_settings_menu.set_script(SettingsMenuScript)
		add_child(_settings_menu)
		_settings_menu.closed.connect(_restore_focus.bind(options_btn))
	get_viewport().gui_release_focus()
	_settings_menu.open_menu()


func _restore_focus(btn: Button) -> void:
	if is_instance_valid(btn) and btn.is_inside_tree():
		btn.grab_focus()


func _on_exit() -> void:
	get_tree().quit()


# --- Visuals ---

func _apply_style() -> void:
	var bg := get_node_or_null(^"Background") as ColorRect
	if bg:
		var shader := Shader.new()
		shader.code = BACKDROP_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		bg.material = mat

	var vbox := $VBox as VBoxContainer
	var title := $VBox/Title as Label

	# Small cyan caption above the title
	var caption := UIStyle.make_label("PROJECT", UIStyle.SIZE_M, UIStyle.CYAN, true)
	caption.add_theme_constant_override(&"outline_size", 0)
	vbox.add_child(caption)
	vbox.move_child(caption, title.get_index())

	UIStyle.style_label(title, 112, UIStyle.TEXT, true)
	title.add_theme_color_override(&"font_shadow_color", Color(UIStyle.CYAN, 0.25))
	title.add_theme_constant_override(&"shadow_offset_x", 0)
	title.add_theme_constant_override(&"shadow_offset_y", 0)
	title.add_theme_constant_override(&"shadow_outline_size", 14)

	# Cyan light-line under the title
	var line := ColorRect.new()
	line.color = UIStyle.CYAN
	line.custom_minimum_size = Vector2(420, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(line)
	vbox.move_child(line, title.get_index() + 1)
	var glow := ColorRect.new()
	glow.color = Color(UIStyle.CYAN, 0.15)
	glow.custom_minimum_size = Vector2(280, 1)
	glow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(glow)
	vbox.move_child(glow, line.get_index() + 1)

	for btn: Button in [battle_test_btn, new_game_btn, continue_btn, load_btn, options_btn, exit_btn]:
		UIStyle.style_button(btn, 28)
		btn.custom_minimum_size = Vector2(440, 56)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	# Footer glyph bar
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override(&"panel", UIStyle.glass_panel(12))
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 96
	footer.offset_right = -96
	footer.offset_top = -88
	footer.offset_bottom = -24
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override(&"separation", 28)
	fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(fbox)
	var note := UIStyle.make_label("Prototype build", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fbox.add_child(note)
	fbox.add_child(GlyphHint.create(&"ui_up", "Navigate", UIStyle.SIZE_S))
	fbox.add_child(GlyphHint.create(&"ui_accept", "Select", UIStyle.SIZE_S))

	UIStyle.fade_slide_in(vbox, Vector2.LEFT, 0.2, 12.0)
