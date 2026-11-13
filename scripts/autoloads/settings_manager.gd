## Persists and applies user settings (camera, audio, controls, gameplay).
## Saves to user://settings.json. Auto-loads and applies on _ready().
extends Node

const SETTINGS_PATH := "user://settings.json"
## Bump whenever project.godot default bindings change. Saved "bindings" with a
## missing or lower version are discarded on load so stale remaps can't override
## the new defaults. Other settings (camera/audio/gameplay) are always kept.
## v2 = 2026-11-12 controller remap (Command Menu on A, Jump on Y, D-pad fixes).
## v3 = 2026-11-12 controls v2 (Dodge on LB, Interact on B, new Sprint on L3/Ctrl).
## v4 = 2026-11-12 battle system v3 (Jump on A, Interact on Y, Dodge on B,
##      tactical_mode keyboard-only Q, new unique_ability on R; controller
##      Command/Unique access is routed per mode by player.gd).
## v5 = 2026-11-13 battle v4 (new battle_toggle on View/Back + F).
const BINDINGS_VERSION := 5

# --- Camera ---
var mouse_sensitivity: float = 0.002
var controller_sensitivity: float = 1.0
var camera_shake: bool = true

# --- Audio ---
var music_volume: float = 1.0
var sfx_volume: float = 1.0

# --- Gameplay ---
var show_damage_numbers: bool = true
var show_control_hints: bool = true
## v5 Options page: minimap visibility and mode (true = rotates with the camera,
## false = static north-up with the player arrow turning instead).
var show_minimap: bool = true
var minimap_rotate: bool = true

# --- Signals ---
signal settings_changed()

# --- Rebinding storage ---
var _custom_bindings: Dictionary = {}

# --- Actions that can be rebound ---
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"jump", &"attack", &"dodge", &"interact", &"sprint",
	&"tactical_mode", &"unique_ability", &"lock_on", &"pause", &"party_switch",
	&"battle_toggle",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()


# --- Save / Load ---

func save_settings() -> void:
	var data: Dictionary = {
		"camera": {
			"mouse_sensitivity": mouse_sensitivity,
			"controller_sensitivity": controller_sensitivity,
			"camera_shake": camera_shake,
		},
		"audio": {
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
		},
		"gameplay": {
			"show_damage_numbers": show_damage_numbers,
			"show_control_hints": show_control_hints,
			"show_minimap": show_minimap,
			"minimap_rotate": minimap_rotate,
		},
		"bindings_version": BINDINGS_VERSION,
		"bindings": _serialize_bindings(),
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if data is not Dictionary:
		return
	var d: Dictionary = data
	var cam: Dictionary = d.get("camera", {})
	mouse_sensitivity = cam.get("mouse_sensitivity", mouse_sensitivity)
	controller_sensitivity = cam.get("controller_sensitivity", controller_sensitivity)
	camera_shake = cam.get("camera_shake", camera_shake)
	var aud: Dictionary = d.get("audio", {})
	music_volume = aud.get("music_volume", music_volume)
	sfx_volume = aud.get("sfx_volume", sfx_volume)
	var gp: Dictionary = d.get("gameplay", {})
	show_damage_numbers = gp.get("show_damage_numbers", show_damage_numbers)
	show_control_hints = gp.get("show_control_hints", show_control_hints)
	show_minimap = bool(gp.get("show_minimap", show_minimap))
	minimap_rotate = bool(gp.get("minimap_rotate", minimap_rotate))
	var saved_version: int = int(d.get("bindings_version", 0))
	if saved_version < BINDINGS_VERSION:
		# Stale bindings from an older default layout: drop them and keep defaults.
		_custom_bindings.clear()
		if d.has("bindings"):
			push_warning("SettingsManager: discarding saved bindings (version %d < %d)" % [saved_version, BINDINGS_VERSION])
			save_settings()
		return
	var bindings: Dictionary = d.get("bindings", {})
	_deserialize_bindings(bindings)


func apply_settings() -> void:
	InputManager.mouse_sensitivity = mouse_sensitivity
	InputManager.controller_camera_sensitivity = controller_sensitivity
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)
	settings_changed.emit()


func reset_defaults() -> void:
	mouse_sensitivity = 0.002
	controller_sensitivity = 1.0
	camera_shake = true
	music_volume = 1.0
	sfx_volume = 1.0
	show_damage_numbers = true
	show_control_hints = true
	show_minimap = true
	minimap_rotate = true
	InputMap.load_from_project_settings()
	_custom_bindings.clear()
	apply_settings()
	save_settings()


# --- Rebinding ---

func rebind_action(action: StringName, new_event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	var is_controller := new_event is InputEventJoypadButton or new_event is InputEventJoypadMotion
	# Remove old event of same input type (keyboard/mouse vs controller)
	for old_event in events:
		var old_is_controller := old_event is InputEventJoypadButton or old_event is InputEventJoypadMotion
		if old_is_controller == is_controller:
			InputMap.action_erase_event(action, old_event)
			break
	InputMap.action_add_event(action, new_event)
	_custom_bindings[String(action)] = _serialize_action_events(action)
	# v5: glyphs / control hints listen to settings_changed, so refresh them now.
	settings_changed.emit()


func get_action_keyboard_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "---"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var kc: int = event.keycode
			if kc != 0:
				return OS.get_keycode_string(kc)
			return "Key"
		if event is InputEventMouseButton:
			return _mouse_button_name(event.button_index)
	return "---"


func get_action_controller_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "---"
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return _joy_button_name(event.button_index)
		if event is InputEventJoypadMotion:
			return _joy_axis_name(event.axis, event.axis_value)
	return "---"


## Returns the binding label(s) for an action on one device family.
## controller=true -> joypad buttons/axes (e.g. "A", "RT", "D-Up/D-Down").
## controller=false -> keyboard/mouse (e.g. "Q", "LMB").
## Multiple distinct events are joined with "/". Returns "---" if unbound.
func get_action_label(action: StringName, controller: bool) -> String:
	if not InputMap.has_action(action):
		return "---"
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var label := ""
		if controller:
			if event is InputEventJoypadButton:
				label = _joy_button_name(event.button_index)
			elif event is InputEventJoypadMotion:
				label = _joy_axis_name(event.axis, event.axis_value)
		else:
			if event is InputEventKey:
				var kc: int = event.keycode
				if kc == 0:
					kc = event.physical_keycode
				label = _short_key_name(OS.get_keycode_string(kc)) if kc != 0 else "Key"
			elif event is InputEventMouseButton:
				label = _mouse_button_name(event.button_index)
		if label != "" and not labels.has(label):
			labels.append(label)
	if labels.is_empty():
		return "---"
	return "/".join(labels)


# --- Display helpers ---

func _short_key_name(key_name: String) -> String:
	match key_name:
		"Escape": return "Esc"
		"BracketLeft": return "["
		"BracketRight": return "]"
		_: return key_name


func _mouse_button_name(index: int) -> String:
	match index:
		1: return "LMB"
		2: return "RMB"
		3: return "MMB"
		4: return "Wheel Up"
		5: return "Wheel Down"
		_: return "Mouse %d" % index


func _joy_button_name(index: int) -> String:
	match index:
		0: return "A"
		1: return "B"
		2: return "X"
		3: return "Y"
		4: return "View"   # Xbox naming (Back on older pads)
		5: return "Guide"
		6: return "Start"
		7: return "L3"  # left stick click
		8: return "R3"  # right stick click
		9: return "LB"
		10: return "RB"
		11: return "D-Up"
		12: return "D-Down"
		13: return "D-Left"
		14: return "D-Right"
		_: return "Btn %d" % index


func _joy_axis_name(axis: int, value: float) -> String:
	match axis:
		4: return "LT"
		5: return "RT"
		0, 1: return "LS"
		2, 3: return "RS"
		_:
			var dir := "+" if value > 0 else "-"
			return "Axis%d%s" % [axis, dir]


# --- Serialization ---

func _serialize_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action_str: String in _custom_bindings:
		result[action_str] = _custom_bindings[action_str]
	return result


func _serialize_action_events(action: StringName) -> Array:
	var result: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append({"type": "key", "keycode": event.keycode})
		elif event is InputEventMouseButton:
			result.append({"type": "mouse", "button": event.button_index})
		elif event is InputEventJoypadButton:
			result.append({"type": "joy_button", "button": event.button_index})
		elif event is InputEventJoypadMotion:
			result.append({"type": "joy_axis", "axis": event.axis, "value": event.axis_value})
	return result


func _deserialize_bindings(bindings: Dictionary) -> void:
	_custom_bindings = bindings.duplicate()
	for action_str: String in bindings:
		var action := StringName(action_str)
		if not InputMap.has_action(action):
			continue
		var events_data: Variant = bindings[action_str]
		if events_data is not Array:
			continue
		InputMap.action_erase_events(action)
		for event_data: Variant in events_data:
			if event_data is not Dictionary:
				continue
			var event := _deserialize_event(event_data as Dictionary)
			if event:
				InputMap.action_add_event(action, event)


func _deserialize_event(data: Dictionary) -> InputEvent:
	var event_type: String = data.get("type", "")
	match event_type:
		"key":
			var event := InputEventKey.new()
			event.keycode = int(data.get("keycode", 0))
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = int(data.get("button", 1)) as MouseButton
			return event
		"joy_button":
			var event := InputEventJoypadButton.new()
			event.button_index = int(data.get("button", 0)) as JoyButton
			return event
		"joy_axis":
			var event := InputEventJoypadMotion.new()
			event.axis = int(data.get("axis", 0)) as JoyAxis
			event.axis_value = float(data.get("value", 1.0))
			return event
	return null
