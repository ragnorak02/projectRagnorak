## Node-based state machine with illegal transition protection.
class_name StateMachine
extends Node

@export var initial_state_name: StringName = &"Idle"

var current_state: Node
var states: Dictionary = {}

## Transitions that are explicitly blocked: { "FromState": ["ToState1", "ToState2"] }
var illegal_transitions: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child.has_method("process_physics"):
			states[child.name] = child

	if states.has(initial_state_name):
		current_state = states[initial_state_name]
		current_state.enter()


func initialize(player: CharacterBody3D) -> void:
	for state in states.values():
		state.initialize(player)


func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	var next: StringName = current_state.process_physics(delta)
	if next != &"":
		_transition(next)


func _process(delta: float) -> void:
	if current_state == null:
		return
	var next: StringName = current_state.process_frame(delta)
	if next != &"":
		_transition(next)


func _unhandled_input(event: InputEvent) -> void:
	if current_state == null:
		return
	var next: StringName = current_state.process_input(event)
	if next != &"":
		_transition(next)


func _transition(target_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(target_name):
		push_warning("StateMachine: State '%s' not found" % target_name)
		return

	if _is_illegal_transition(current_state.name, target_name):
		if DebugFlags.DEBUG_PLAYER:
			print("StateMachine: BLOCKED illegal transition %s -> %s" % [current_state.name, target_name])
		return

	current_state.exit()
	current_state = states[target_name]
	current_state.enter(msg)

	if DebugFlags.DEBUG_PLAYER:
		print("StateMachine: %s -> %s" % [current_state.name, target_name])


func force_transition(target_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(target_name):
		push_warning("StateMachine: State '%s' not found" % target_name)
		return
	current_state.exit()
	current_state = states[target_name]
	current_state.enter(msg)


func _is_illegal_transition(from: StringName, to: StringName) -> bool:
	if illegal_transitions.has(from):
		return to in illegal_transitions[from]
	return false


func add_illegal_transition(from: StringName, to: StringName) -> void:
	if not illegal_transitions.has(from):
		illegal_transitions[from] = []
	if to not in illegal_transitions[from]:
		illegal_transitions[from].append(to)
