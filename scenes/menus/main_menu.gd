## Main menu — navigates to test arena or exits.
extends Control

@onready var new_game_btn: Button = $VBox/NewGame
@onready var continue_btn: Button = $VBox/Continue
@onready var options_btn: Button = $VBox/Options
@onready var exit_btn: Button = $VBox/Exit


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	exit_btn.pressed.connect(_on_exit)

	# Give focus to first button for controller navigation
	new_game_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Xbox A button (mapped to jump) also confirms menu selections
	if event.is_action_pressed(&"jump") or event.is_action_pressed(&"interact"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton:
			focused.emit_signal(&"pressed")
			get_viewport().set_input_as_handled()


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/test/test_arena.tscn")


func _on_continue() -> void:
	# Placeholder — load save when save system is ready
	get_tree().change_scene_to_file("res://scenes/test/test_arena.tscn")


func _on_exit() -> void:
	get_tree().quit()
