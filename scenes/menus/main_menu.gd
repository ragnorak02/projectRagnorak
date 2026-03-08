## Main menu — New Game, Continue, Load Game, Options, Exit.
extends Control

const SaveLoadMenuScript := preload("res://src/ui/menus/save_load_menu.gd")

@onready var new_game_btn: Button = $VBox/NewGame
@onready var continue_btn: Button = $VBox/Continue
@onready var load_btn: Button = $VBox/Load
@onready var options_btn: Button = $VBox/Options
@onready var exit_btn: Button = $VBox/Exit

var _save_load_menu: Node = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.change_state(GameManager.GameState.MAIN_MENU)

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	load_btn.pressed.connect(_on_load)
	options_btn.pressed.connect(_on_options)
	exit_btn.pressed.connect(_on_exit)

	# Enable Continue only if saves exist
	var has_save: bool = SaveManager.has_any_save()
	continue_btn.disabled = not has_save
	load_btn.disabled = not has_save

	new_game_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Xbox A button also confirms menu selections
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton and not (focused as BaseButton).disabled:
			focused.emit_signal(&"pressed")
			get_viewport().set_input_as_handled()


func _on_new_game() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	get_tree().change_scene_to_file("res://scenes/test/test_arena.tscn")


func _on_continue() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	if not SaveManager.continue_game():
		# Fallback if continue fails
		get_tree().change_scene_to_file("res://scenes/test/test_arena.tscn")


func _on_load() -> void:
	AudioManager.play_sfx_named("menu_confirm")
	if _save_load_menu == null:
		_save_load_menu = CanvasLayer.new()
		_save_load_menu.set_script(SaveLoadMenuScript)
		add_child(_save_load_menu)
	_save_load_menu.open_menu(1)  # 1 = Mode.LOAD


func _on_options() -> void:
	pass


func _on_exit() -> void:
	get_tree().quit()
