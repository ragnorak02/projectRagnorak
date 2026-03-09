## Tracks active input device and provides movement helpers.
extends Node

enum DeviceType { KEYBOARD_MOUSE, CONTROLLER }

var active_device: DeviceType = DeviceType.KEYBOARD_MOUSE
var mouse_sensitivity: float = 0.002
var controller_camera_sensitivity: float = 1.0

signal device_changed(new_device: DeviceType)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if active_device != DeviceType.CONTROLLER:
			active_device = DeviceType.CONTROLLER
			device_changed.emit(active_device)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		if active_device != DeviceType.KEYBOARD_MOUSE:
			active_device = DeviceType.KEYBOARD_MOUSE
			device_changed.emit(active_device)


func is_using_controller() -> bool:
	return active_device == DeviceType.CONTROLLER


func get_movement_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func get_camera_vector() -> Vector2:
	return Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
