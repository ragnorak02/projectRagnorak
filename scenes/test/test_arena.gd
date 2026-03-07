## Test arena — spawns player and camera rig for locomotion testing.
extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")
const CameraScene := preload("res://src/camera/camera_rig.tscn")

@onready var player_spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var player_inst := PlayerScene.instantiate()
	add_child(player_inst)
	player_inst.global_position = player_spawn.global_position

	var camera_inst := CameraScene.instantiate()
	add_child(camera_inst)
	camera_inst.follow_target = player_inst.camera_anchor

	GameManager.change_state(GameManager.GameState.PLAYING)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
