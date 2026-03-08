## Manages SFX and music playback with named registry and zone-based music.
## Gracefully handles missing audio assets (no crash if streams are null).
extends Node

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8

var music_volume: float = 1.0
var sfx_volume: float = 1.0

# --- SFX Registry ---
# Maps named SFX keys to AudioStream resources (null until real assets are added).
var _sfx_registry: Dictionary = {}

# --- Music State ---
var _current_music_key: String = ""
var _music_registry: Dictionary = {}
var _battle_music_active: bool = false
var _pre_battle_music_key: String = ""

# --- Tactical audio ---
var _tactical_active: bool = false
var _original_pitch: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)

	for i in _sfx_pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)

	# Register default SFX keys (null streams — replaced when assets are loaded)
	_register_default_sfx()
	_register_default_music()

	# Connect signals
	Events.zone_entered.connect(_on_zone_entered)
	Events.combat_started.connect(_on_combat_started)
	Events.combat_ended.connect(_on_combat_ended)
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)


func _register_default_sfx() -> void:
	## Register all SFX keys with null streams as placeholders.
	## Replace with real AudioStream resources when audio assets are available.
	var keys: Array[String] = [
		# Combat
		"attack_1", "attack_2", "attack_3", "jump_attack",
		"dodge", "hit_react", "player_hurt", "enemy_hurt", "enemy_die",
		# Abilities
		"spell_cast", "spell_release", "spell_interrupt",
		# Menu
		"menu_select", "menu_confirm", "menu_back", "menu_open", "menu_close",
		# UI
		"save_confirm", "quest_complete", "quest_accept", "item_pickup",
		"interaction_prompt",
		# Party
		"party_switch", "team_attack", "party_member_down", "party_member_revive",
	]
	for key in keys:
		_sfx_registry[key] = null


func _register_default_music() -> void:
	## Register zone-to-music mappings (null streams until assets exist).
	_music_registry = {
		"town_hub": null,
		"field_zone": null,
		"dungeon_zone": null,
		"test_arena": null,
		"battle": null,
		"main_menu": null,
	}


# --- SFX API ---

func register_sfx(key: String, stream: AudioStream) -> void:
	_sfx_registry[key] = stream


func play_sfx(stream: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume * volume)
			player.pitch_scale = pitch
			player.play()
			return


func play_sfx_named(key: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	## Play SFX by registered name. Silently does nothing if key is missing or stream is null.
	var stream: AudioStream = _sfx_registry.get(key)
	if stream == null:
		return
	play_sfx(stream, volume, pitch)


func play_sfx_varied(key: String, volume: float = 1.0, pitch_min: float = 0.9, pitch_max: float = 1.1) -> void:
	## Play SFX with slight pitch variation for natural feel.
	play_sfx_named(key, volume, randf_range(pitch_min, pitch_max))


func has_sfx(key: String) -> bool:
	return _sfx_registry.has(key) and _sfx_registry[key] != null


# --- Music API ---

func register_music(key: String, stream: AudioStream) -> void:
	_music_registry[key] = stream


func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	if _music_player.playing and fade_in > 0:
		_crossfade_music(stream, fade_in)
	else:
		_music_player.stream = stream
		_music_player.volume_db = linear_to_db(music_volume)
		_music_player.play()


func play_music_named(key: String, fade_in: float = 0.5) -> void:
	var stream: AudioStream = _music_registry.get(key)
	if stream == null:
		return
	_current_music_key = key
	play_music(stream, fade_in)


func stop_music(fade_out: float = 0.5) -> void:
	if not _music_player.playing:
		return
	if fade_out > 0:
		var tween := create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(_music_player, "volume_db", -60.0, fade_out)
		tween.tween_callback(func():
			_music_player.stop()
			_music_player.volume_db = linear_to_db(music_volume)
		)
	else:
		_music_player.stop()


func _crossfade_music(new_stream: AudioStream, duration: float) -> void:
	var old_vol: float = _music_player.volume_db
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_music_player, "volume_db", -60.0, duration * 0.5)
	tween.tween_callback(func():
		_music_player.stream = new_stream
		_music_player.volume_db = old_vol
		_music_player.play()
	)


func get_current_music_key() -> String:
	return _current_music_key


# --- Volume Controls ---

func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)


# --- Signal Handlers ---

func _on_zone_entered(zone_id: StringName) -> void:
	## Play zone-appropriate music on entry.
	if _battle_music_active:
		_pre_battle_music_key = String(zone_id)
		return
	play_music_named(String(zone_id))


func _on_combat_started() -> void:
	if not _battle_music_active:
		_pre_battle_music_key = _current_music_key
		_battle_music_active = true
		play_music_named("battle", 0.3)


func _on_combat_ended() -> void:
	if _battle_music_active:
		_battle_music_active = false
		if _pre_battle_music_key != "":
			play_music_named(_pre_battle_music_key, 0.8)


func _on_tactical_entered() -> void:
	_tactical_active = true
	# Slow music pitch to match tactical slow-time
	_original_pitch = _music_player.pitch_scale
	_music_player.pitch_scale = 0.5


func _on_tactical_exited() -> void:
	_tactical_active = false
	_music_player.pitch_scale = _original_pitch
