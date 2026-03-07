## Test arena — spawns player, camera, enemies, and HUD for testing.
extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")
const CameraScene := preload("res://src/camera/camera_rig.tscn")
const EnemyScene := preload("res://src/enemies/enemy.tscn")
const CombatHudScript := preload("res://src/ui/hud/combat_hud.gd")
const ControlBarScript := preload("res://src/ui/hud/control_bar.gd")
const TacticalMenuScript := preload("res://src/ui/hud/tactical_menu.gd")
const LockOnIndicatorScript := preload("res://src/ui/hud/lock_on_indicator.gd")
const InteractionPromptScript := preload("res://src/ui/hud/interaction_prompt.gd")
const QuestTrackerScript := preload("res://src/ui/hud/quest_tracker.gd")
const PauseMenuScript := preload("res://src/ui/menus/pause_menu.gd")

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

	# Add combat HUD
	var hud := CanvasLayer.new()
	hud.set_script(CombatHudScript)
	add_child(hud)

	# Add control bar
	var control_bar := CanvasLayer.new()
	control_bar.set_script(ControlBarScript)
	add_child(control_bar)

	# Add tactical menu overlay
	var tactical_menu := CanvasLayer.new()
	tactical_menu.set_script(TacticalMenuScript)
	add_child(tactical_menu)

	# Add lock-on target indicator
	var lock_indicator := CanvasLayer.new()
	lock_indicator.set_script(LockOnIndicatorScript)
	add_child(lock_indicator)

	# Add interaction prompt
	var interact_prompt := CanvasLayer.new()
	interact_prompt.set_script(InteractionPromptScript)
	add_child(interact_prompt)

	# Add quest tracker placeholder
	var quest_tracker := CanvasLayer.new()
	quest_tracker.set_script(QuestTrackerScript)
	add_child(quest_tracker)

	# Add pause menu
	var pause_menu := CanvasLayer.new()
	pause_menu.set_script(PauseMenuScript)
	add_child(pause_menu)

	# Emit initial values so HUD updates
	Events.player_hp_changed.emit(player_inst.current_hp, player_inst.max_hp)
	Events.player_mp_changed.emit(player_inst.current_mp, player_inst.max_mp)
	Events.player_atb_changed.emit(player_inst.current_atb, player_inst.max_atb)

	GameManager.change_state(GameManager.GameState.PLAYING)
