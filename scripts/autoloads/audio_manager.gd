## Manages SFX and music playback.
extends Node

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8

var music_volume: float = 1.0
var sfx_volume: float = 1.0


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


func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()


func stop_music(fade_out: float = 0.5) -> void:
	_music_player.stop()


func play_sfx(stream: AudioStream, volume: float = 1.0, pitch: float = 1.0) -> void:
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume * volume)
			player.pitch_scale = pitch
			player.play()
			return
