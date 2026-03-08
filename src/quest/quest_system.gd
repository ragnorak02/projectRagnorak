## Tracks quest state: available, active, completed.
## Attach as a child node of the player (like InventorySystem).
extends Node

var _active_quests: Dictionary = {}   # quest_id -> {data, progress[], current_idx}
var _completed_quests: Array[StringName] = []
var _tracked_quest_id: StringName = &""


func accept_quest(quest_data: Resource) -> bool:
	if quest_data == null:
		return false
	var qid: StringName = quest_data.quest_id
	if _active_quests.has(qid) or _completed_quests.has(qid):
		return false

	# Check prerequisites
	for prereq: StringName in quest_data.prerequisite_quests:
		if not _completed_quests.has(prereq):
			return false

	var progress: Array[int] = []
	for i in quest_data.objectives.size():
		progress.append(0)

	_active_quests[qid] = {
		"data": quest_data,
		"progress": progress,
		"current_objective_index": 0,
	}

	# Auto-track first accepted quest if none tracked
	if _tracked_quest_id == &"":
		_tracked_quest_id = qid

	Events.quest_accepted.emit(qid)
	_emit_tracker_update(qid)
	return true


func advance_objective(quest_id: StringName, objective_id: StringName, amount: int = 1) -> void:
	if not _active_quests.has(quest_id):
		return
	var quest: Dictionary = _active_quests[quest_id]
	var data: Resource = quest["data"]
	var progress: Array = quest["progress"]

	for i in data.objectives.size():
		var obj: Resource = data.objectives[i]
		if obj.objective_id == objective_id:
			progress[i] = mini(progress[i] + amount, obj.target_count)
			Events.quest_objective_updated.emit(quest_id, i)

			# Check if this objective is complete and advance index
			if progress[i] >= obj.target_count:
				if quest["current_objective_index"] == i:
					quest["current_objective_index"] = i + 1

			# Check if all objectives complete
			if _all_objectives_complete(quest_id):
				complete_quest(quest_id)
			else:
				_emit_tracker_update(quest_id)
			return


func complete_quest(quest_id: StringName) -> bool:
	if not _active_quests.has(quest_id):
		return false
	_active_quests.erase(quest_id)
	_completed_quests.append(quest_id)

	if _tracked_quest_id == quest_id:
		_tracked_quest_id = &""
		# Auto-track next active quest
		if not _active_quests.is_empty():
			_tracked_quest_id = _active_quests.keys()[0]

	Events.quest_completed.emit(quest_id)
	return true


func get_active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for qid: StringName in _active_quests:
		var quest: Dictionary = _active_quests[qid]
		result.append({
			"quest_id": qid,
			"data": quest["data"],
			"progress": quest["progress"],
			"current_objective_index": quest["current_objective_index"],
		})
	return result


func get_completed_quests() -> Array[StringName]:
	return _completed_quests.duplicate()


func is_quest_active(quest_id: StringName) -> bool:
	return _active_quests.has(quest_id)


func is_quest_completed(quest_id: StringName) -> bool:
	return _completed_quests.has(quest_id)


func get_tracked_quest() -> Dictionary:
	if _tracked_quest_id == &"" or not _active_quests.has(_tracked_quest_id):
		return {}
	var quest: Dictionary = _active_quests[_tracked_quest_id]
	return {
		"quest_id": _tracked_quest_id,
		"data": quest["data"],
		"progress": quest["progress"],
		"current_objective_index": quest["current_objective_index"],
	}


func set_tracked_quest(quest_id: StringName) -> void:
	if _active_quests.has(quest_id):
		_tracked_quest_id = quest_id
		_emit_tracker_update(quest_id)


func get_quest_count() -> int:
	return _active_quests.size()


func _all_objectives_complete(quest_id: StringName) -> bool:
	if not _active_quests.has(quest_id):
		return false
	var quest: Dictionary = _active_quests[quest_id]
	var data: Resource = quest["data"]
	var progress: Array = quest["progress"]
	for i in data.objectives.size():
		if progress[i] < data.objectives[i].target_count:
			return false
	return true


func _emit_tracker_update(quest_id: StringName) -> void:
	if quest_id != _tracked_quest_id:
		return
	if not _active_quests.has(quest_id):
		return
	var quest: Dictionary = _active_quests[quest_id]
	var idx: int = quest["current_objective_index"]
	Events.quest_objective_updated.emit(quest_id, idx)


# --- Save / Load ---

func get_save_data() -> Dictionary:
	var active: Dictionary = {}
	for qid: StringName in _active_quests:
		var quest: Dictionary = _active_quests[qid]
		var data: Resource = quest["data"]
		active[String(qid)] = {
			"resource_path": data.resource_path if data.resource_path != "" else "",
			"progress": quest["progress"].duplicate(),
			"current_objective_index": quest["current_objective_index"],
		}

	var completed: Array[String] = []
	for qid: StringName in _completed_quests:
		completed.append(String(qid))

	return {
		"active": active,
		"completed": completed,
		"tracked": String(_tracked_quest_id),
	}


func load_save_data(data: Dictionary) -> void:
	_active_quests.clear()
	_completed_quests.clear()
	_tracked_quest_id = &""

	if data.has("completed"):
		for qid_str in data["completed"]:
			_completed_quests.append(StringName(qid_str))

	if data.has("active"):
		for qid_str: String in data["active"]:
			var entry: Dictionary = data["active"][qid_str]
			var res_path: String = entry.get("resource_path", "")
			if res_path == "":
				continue
			var quest_res: Resource = load(res_path)
			if quest_res == null:
				continue
			var progress: Array[int] = []
			for val in entry.get("progress", []):
				progress.append(int(val))
			_active_quests[StringName(qid_str)] = {
				"data": quest_res,
				"progress": progress,
				"current_objective_index": int(entry.get("current_objective_index", 0)),
			}

	if data.has("tracked"):
		_tracked_quest_id = StringName(data["tracked"])
