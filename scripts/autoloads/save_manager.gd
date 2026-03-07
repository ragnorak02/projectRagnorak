## Manages save/load with autosave, manual, and quicksave slots.
extends Node

const SAVE_DIR := "user://saves/"
const AUTOSAVE_PATH := SAVE_DIR + "autosave.tres"
const QUICKSAVE_PATH := SAVE_DIR + "quicksave.tres"
const SLOT_PREFIX := SAVE_DIR + "slot_"

signal save_started(slot: int)
signal save_finished(slot: int)
signal load_started(slot: int)
signal load_finished(slot: int)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func get_slot_path(slot: int) -> String:
	match slot:
		-1: return AUTOSAVE_PATH
		0: return QUICKSAVE_PATH
		_: return SLOT_PREFIX + str(slot) + ".tres"


func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func save_game(slot: int, data: Dictionary) -> bool:
	save_started.emit(slot)
	var path := get_slot_path(slot)
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(path.replace(".tres", ".json"), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	file.close()
	save_finished.emit(slot)
	Events.save_completed.emit(slot)
	return true


func load_game(slot: int) -> Dictionary:
	load_started.emit(slot)
	var path := get_slot_path(slot).replace(".tres", ".json")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json)
	load_finished.emit(slot)
	Events.load_completed.emit(slot)
	return parsed if parsed is Dictionary else {}


func autosave(data: Dictionary) -> bool:
	return save_game(-1, data)


func quicksave(data: Dictionary) -> bool:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	return save_game(0, data)
