## Switch puzzle — requires all connected levers to be ON to unlock.
## Connect lever nodes via @export, listens to their lever_toggled signals.
extends Node3D

@export var puzzle_id: String = ""
@export var levers: Array[NodePath] = []
@export var target: NodePath = NodePath("")  # Node to activate when solved

signal puzzle_solved

var _solved: bool = false
var _lever_nodes: Array[Node] = []


func _ready() -> void:
	# Check if already solved
	if puzzle_id != "" and SaveManager.has_flag("puzzle_" + puzzle_id):
		_solved = true
		_activate_target()
		return

	# Connect lever signals
	for path in levers:
		var lever := get_node_or_null(path)
		if lever and lever.has_signal("lever_toggled"):
			_lever_nodes.append(lever)
			lever.lever_toggled.connect(_on_lever_changed)


func _on_lever_changed(_is_on: bool) -> void:
	if _solved:
		return

	# Check if all levers are on
	var all_on := true
	for lever in _lever_nodes:
		if not lever.is_on:
			all_on = false
			break

	if all_on:
		_solved = true
		if puzzle_id != "":
			SaveManager.set_flag("puzzle_" + puzzle_id, true)
		puzzle_solved.emit()
		_activate_target()
		Events.save_feedback.emit("Puzzle solved!")


func _activate_target() -> void:
	var t := get_node_or_null(target)
	if t == null:
		return
	if t.has_method("set_active"):
		t.set_active(true)
	elif t.has_method("try_break"):
		t.try_break(null)
	elif t is Node3D:
		t.visible = true
