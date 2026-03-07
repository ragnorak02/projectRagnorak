## Global debug flags. All default false.
extends Node

var DEBUG_COMBAT: bool = false
var DEBUG_AI: bool = false
var DEBUG_PLAYER: bool = false
var DEBUG_CAMERA: bool = false
var DEBUG_INVENTORY: bool = false
var DEBUG_QUESTS: bool = false
var DEBUG_SAVE: bool = false
var DEBUG_PARTY: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
