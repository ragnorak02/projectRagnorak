## Base script for all zone scenes (towns, fields, dungeons).
## Handles player/camera/HUD spawning, party system, save data loading, autosave.
## Extend this in specific zone scripts and override _setup_zone() for custom content.
extends Node3D

const PlayerScene := preload("res://src/player/player.tscn")
const CameraScene := preload("res://src/camera/camera_rig.tscn")
const CombatHudScript := preload("res://src/ui/hud/combat_hud.gd")
const ControlBarScript := preload("res://src/ui/hud/control_bar.gd")
const TacticalMenuScript := preload("res://src/ui/hud/tactical_menu.gd")
const LockOnIndicatorScript := preload("res://src/ui/hud/lock_on_indicator.gd")
const InteractionPromptScript := preload("res://src/ui/hud/interaction_prompt.gd")
const QuestTrackerScript := preload("res://src/ui/hud/quest_tracker.gd")
const PauseMenuScript := preload("res://src/ui/menus/pause_menu.gd")
const DialogueUiScript := preload("res://src/ui/dialogue/dialogue_ui.gd")
const SaveFeedbackScript := preload("res://src/ui/hud/save_feedback.gd")
const LoadingScreenScript := preload("res://src/ui/hud/loading_screen.gd")
const PartySystemScript := preload("res://src/party/party_system.gd")

@export var zone_id: String = ""
@export var spawn_position: Vector3 = Vector3(0, 1, 0)
@export var spawn_companion: bool = true

var player: CharacterBody3D = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Spawn player
	player = PlayerScene.instantiate()
	add_child(player)

	# Determine spawn position (use marker if available)
	var spawn_node := get_node_or_null("PlayerSpawn")
	if spawn_node:
		player.global_position = spawn_node.global_position
	else:
		player.global_position = spawn_position

	# Spawn camera
	var camera := CameraScene.instantiate()
	add_child(camera)
	camera.follow_target = player.camera_anchor

	# Setup party system
	_setup_party()

	# Setup zone-specific content (enemies, NPCs, etc.)
	_setup_zone()

	# Spawn HUD layers
	_spawn_hud()

	# Apply pending save data if loading from a save
	if SaveManager.has_pending_load():
		var data := SaveManager.consume_pending_load()
		SaveManager.apply_load_data(data)
	else:
		Events.player_hp_changed.emit(player.current_hp, player.max_hp)
		Events.player_mp_changed.emit(player.current_mp, player.max_mp)
		Events.player_atb_changed.emit(player.current_atb, player.max_atb)

	GameManager.change_state(GameManager.GameState.PLAYING)
	Events.zone_entered.emit(StringName(zone_id))

	# Apply party traversal flags
	if player.party_system:
		player.party_system.apply_traversal_flags()

	# Autosave on zone entry
	call_deferred("_autosave_on_entry")


func _setup_party() -> void:
	var party := Node.new()
	party.set_script(PartySystemScript)
	add_child(party)
	player.party_system = party

	var companion_data := load("res://resources/characters/companion.tres")
	if companion_data and spawn_companion:
		party.initialize(player, companion_data)
	else:
		party.initialize(player)


func _setup_zone() -> void:
	# Override in subclasses to add enemies, NPCs, interactables
	pass


func _spawn_hud() -> void:
	var hud_scripts: Array = [
		CombatHudScript, ControlBarScript, TacticalMenuScript,
		LockOnIndicatorScript, InteractionPromptScript, QuestTrackerScript,
		DialogueUiScript, PauseMenuScript, SaveFeedbackScript, LoadingScreenScript,
	]
	for script in hud_scripts:
		var layer := CanvasLayer.new()
		layer.set_script(script)
		add_child(layer)


func _autosave_on_entry() -> void:
	await get_tree().create_timer(0.5).timeout
	if GameManager.current_state == GameManager.GameState.PLAYING:
		SaveManager.autosave()
