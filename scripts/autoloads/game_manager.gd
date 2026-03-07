## Manages global game state, time scale, and hit stop.
extends Node

enum GameState { MAIN_MENU, LOADING, PLAYING, PAUSED, TACTICAL_MODE, CUTSCENE, GAME_OVER }

var current_state: GameState = GameState.MAIN_MENU
var previous_state: GameState = GameState.MAIN_MENU

var _time_scale_stack: Array[Dictionary] = []
var _base_time_scale: float = 1.0

signal game_state_changed(old_state: GameState, new_state: GameState)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	game_state_changed.emit(previous_state, current_state)

	match current_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.TACTICAL_MODE:
			_push_time_scale("tactical", 0.1)
		_:
			if previous_state == GameState.PAUSED:
				get_tree().paused = false
			if previous_state == GameState.TACTICAL_MODE:
				_pop_time_scale("tactical")


func enter_tactical_mode() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.TACTICAL_MODE)


func exit_tactical_mode() -> void:
	if current_state == GameState.TACTICAL_MODE:
		change_state(GameState.PLAYING)


func hit_stop(duration_ms: float = 65.0) -> void:
	_push_time_scale("hit_stop", 0.0)
	await get_tree().create_timer(duration_ms / 1000.0, true, false, true).timeout
	_pop_time_scale("hit_stop")


func _push_time_scale(id: String, scale: float) -> void:
	_time_scale_stack.push_back({"id": id, "scale": scale})
	_apply_time_scale()


func _pop_time_scale(id: String) -> void:
	for i in range(_time_scale_stack.size() - 1, -1, -1):
		if _time_scale_stack[i]["id"] == id:
			_time_scale_stack.remove_at(i)
			break
	_apply_time_scale()


func _apply_time_scale() -> void:
	if _time_scale_stack.is_empty():
		Engine.time_scale = _base_time_scale
	else:
		Engine.time_scale = _time_scale_stack.back()["scale"]
