## Base class for all player states.
class_name State
extends Node

var player: CharacterBody3D


func _ready() -> void:
	set_physics_process(false)
	set_process(false)


func initialize(p: CharacterBody3D) -> void:
	player = p


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func process_physics(_delta: float) -> StringName:
	return &""


func process_frame(_delta: float) -> StringName:
	return &""


func process_input(_event: InputEvent) -> StringName:
	return &""
