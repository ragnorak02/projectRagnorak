## Test arena — spawns player, camera, and enemies for testing.
extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")
const CameraScene := preload("res://src/camera/camera_rig.tscn")
const EnemyScene := preload("res://src/enemies/enemy.tscn")

@onready var player_spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var player_inst := PlayerScene.instantiate()
	add_child(player_inst)
	player_inst.global_position = player_spawn.global_position

	var camera_inst := CameraScene.instantiate()
	add_child(camera_inst)
	camera_inst.follow_target = player_inst.camera_anchor

	# Spawn enemies at markers
	for marker in [&"EnemySpawn1", &"EnemySpawn2", &"EnemySpawn3"]:
		var spawn_node := get_node_or_null(NodePath(marker))
		if spawn_node:
			var enemy := EnemyScene.instantiate()
			add_child(enemy)
			enemy.global_position = spawn_node.global_position

	GameManager.change_state(GameManager.GameState.PLAYING)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
