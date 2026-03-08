## Manages save/load with autosave, manual, and quicksave slots.
## Supports data versioning, metadata, progression flags, and zone state.
extends Node

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1
const MAX_MANUAL_SLOTS := 3

signal save_started(slot: int)
signal save_finished(slot: int)
signal load_started(slot: int)
signal load_finished(slot: int)

# Progression flags — global state that persists across zones
# e.g. {"boss_defeated_forest": true, "door_unlocked_temple": true}
var progression_flags: Dictionary = {}

# Pending load data — set before changing scene, applied after scene loads
var _pending_load_data: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# --- Slot Path Resolution ---

func _get_slot_path(slot: int) -> String:
	match slot:
		-1: return SAVE_DIR + "autosave.json"
		0: return SAVE_DIR + "quicksave.json"
		_: return SAVE_DIR + "slot_%d.json" % slot


# --- Save Existence Checks ---

func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot))


func has_any_save() -> bool:
	# Check autosave, quicksave, and manual slots
	if save_exists(-1) or save_exists(0):
		return true
	for i in range(1, MAX_MANUAL_SLOTS + 1):
		if save_exists(i):
			return true
	return false


# --- Core Save/Load ---

func save_game(slot: int, data: Dictionary) -> bool:
	save_started.emit(slot)
	var path := _get_slot_path(slot)
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Failed to open %s for writing" % path)
		return false
	file.store_string(json)
	file.close()
	save_finished.emit(slot)
	Events.save_completed.emit(slot)
	return true


func load_game(slot: int) -> Dictionary:
	load_started.emit(slot)
	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveManager: Corrupted save at %s" % path)
		return {}
	# Version migration hook
	parsed = _migrate_save(parsed)
	load_finished.emit(slot)
	Events.load_completed.emit(slot)
	return parsed


func delete_save(slot: int) -> bool:
	var path := _get_slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false


# --- Gather / Apply (Full Game State) ---

func gather_save_data() -> Dictionary:
	var player := _get_player()
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"zone_id": _get_current_zone_id(),
		"player": player.get_save_data() if player else {},
		"progression_flags": progression_flags.duplicate(),
	}
	return data


func apply_load_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	# Restore progression flags
	if data.has("progression_flags"):
		progression_flags = data["progression_flags"].duplicate()

	# Restore player state
	var player := _get_player()
	if player and data.has("player"):
		player.load_save_data(data["player"])


# --- Convenience Shortcuts ---

func autosave(data: Dictionary = {}) -> bool:
	if data.is_empty():
		data = gather_save_data()
	return save_game(-1, data)


func quicksave(data: Dictionary = {}) -> bool:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		Events.save_feedback.emit("Cannot save right now")
		return false
	if data.is_empty():
		data = gather_save_data()
	var result := save_game(0, data)
	if result:
		Events.save_feedback.emit("Quicksave complete")
	return result


func manual_save(slot: int) -> bool:
	if slot < 1 or slot > MAX_MANUAL_SLOTS:
		return false
	var data := gather_save_data()
	return save_game(slot, data)


# --- Continue / Load Flow ---

func get_most_recent_slot() -> int:
	## Returns the slot with the newest timestamp, or -99 if none.
	var best_slot := -99
	var best_time := ""
	var slots_to_check: Array[int] = [-1, 0, 1, 2, 3]
	for slot in slots_to_check:
		var meta := get_save_metadata(slot)
		if meta.is_empty():
			continue
		if meta["timestamp"] > best_time:
			best_time = meta["timestamp"]
			best_slot = slot
	return best_slot


func continue_game() -> bool:
	## Load most recent save and transition to its zone.
	var slot := get_most_recent_slot()
	if slot == -99:
		return false
	return load_and_apply(slot)


func load_and_apply(slot: int) -> bool:
	## Load a save slot, store pending data, and change to the saved zone scene.
	var data := load_game(slot)
	if data.is_empty():
		return false

	# Restore progression flags immediately
	if data.has("progression_flags"):
		progression_flags = data["progression_flags"].duplicate()

	# Store pending data for the scene to apply after load
	_pending_load_data = data

	# Determine target scene
	var zone_id: String = data.get("zone_id", "test_arena")
	var scene_path := _zone_id_to_scene(zone_id)
	get_tree().change_scene_to_file(scene_path)
	return true


func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()


func consume_pending_load() -> Dictionary:
	## Called by the loaded scene to get and clear pending data.
	var data := _pending_load_data
	_pending_load_data = {}
	return data


# --- Metadata ---

func get_save_metadata(slot: int) -> Dictionary:
	## Returns lightweight metadata without loading full save.
	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json)
	if parsed == null or not (parsed is Dictionary):
		return {}
	var player_data: Dictionary = parsed.get("player", {})
	return {
		"slot": slot,
		"timestamp": parsed.get("timestamp", "Unknown"),
		"zone_id": parsed.get("zone_id", "unknown"),
		"version": parsed.get("version", 0),
		"hp": player_data.get("hp", 0),
		"max_hp": player_data.get("hp", 100),
	}


func get_all_slot_metadata() -> Array[Dictionary]:
	## Returns metadata for all slots (for save/load UI).
	var result: Array[Dictionary] = []
	var slots: Array[int] = [-1, 0, 1, 2, 3]
	for slot in slots:
		var meta := get_save_metadata(slot)
		if meta.is_empty():
			result.append({"slot": slot, "empty": true})
		else:
			meta["empty"] = false
			result.append(meta)
	return result


# --- Progression Flags ---

func set_flag(flag_name: String, value: Variant = true) -> void:
	progression_flags[flag_name] = value


func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return progression_flags.get(flag_name, default)


func has_flag(flag_name: String) -> bool:
	return progression_flags.has(flag_name)


# --- Quicksave Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quicksave"):
		quicksave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quickload"):
		if save_exists(0):
			load_and_apply(0)
			get_viewport().set_input_as_handled()


# --- Version Migration ---

func _migrate_save(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 0)
	if version < 1:
		# Pre-versioning saves: add missing fields
		if not data.has("version"):
			data["version"] = SAVE_VERSION
		if not data.has("timestamp"):
			data["timestamp"] = "unknown"
		if not data.has("zone_id"):
			data["zone_id"] = "test_arena"
		if not data.has("progression_flags"):
			data["progression_flags"] = {}
	# Future migrations: if version < 2: ...
	return data


# --- Helpers ---

func _get_player() -> Node:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		return null
	return players[0]


func _get_current_zone_id() -> String:
	# Derive zone ID from current scene filename
	var scene := get_tree().current_scene
	if scene == null:
		return "unknown"
	var path: String = scene.scene_file_path
	if path.is_empty():
		return "unknown"
	return path.get_file().get_basename()


func _zone_id_to_scene(zone_id: String) -> String:
	# Map zone IDs to scene paths
	match zone_id:
		"main_menu":
			return "res://scenes/menus/main_menu.tscn"
		"test_arena":
			return "res://scenes/test/test_arena.tscn"
		_:
			# Future zones: res://scenes/zones/{zone_id}.tscn
			var zone_path := "res://scenes/zones/%s.tscn" % zone_id
			if ResourceLoader.exists(zone_path):
				return zone_path
			return "res://scenes/test/test_arena.tscn"
