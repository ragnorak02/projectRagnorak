## Zone portal — teleports player to another zone on interaction.
## Use progression flags for gating (e.g. require a key or ability).
## v7: the exit area lights up. A glowing floor pad + a low light curtain sized
## from the trigger shape: cyan while idle, bright pulsing gold while the player
## is in range (this is the exit Y/E will use), red while locked. Cosmetic only.
extends "res://src/interaction/interactable.gd"

const PadShader := preload("res://src/world/shaders/glow_pad.gdshader")
const CurtainShader := preload("res://src/world/shaders/glow_curtain.gdshader")

const COLOR_IDLE := Color("#5FE3F0")     # UIStyle.CYAN
const COLOR_FOCUS := Color("#F2B544")    # UIStyle.GOLD
const COLOR_LOCKED := Color("#FF5C5C")   # UIStyle.DANGER
const INTENSITY_IDLE := 0.55
const INTENSITY_FOCUS := 1.15
const CURTAIN_HEIGHT := 2.6
## Extra floor around the trigger box that lights up (the approach area).
const PAD_MARGIN := Vector2(1.0, 2.5)

@export var target_zone_id: String = ""
@export var spawn_position: Vector3 = Vector3.ZERO
@export var required_flag: String = ""  # Progression flag required to use
@export var locked_message: String = "The path is blocked."

signal portal_activated(target_zone: String)

var _focused: bool = false
var _pad_mat: ShaderMaterial = null
var _curtain_mat: ShaderMaterial = null
var _color: Color = COLOR_IDLE
var _intensity: float = INTENSITY_IDLE
var _time: float = 0.0


func _ready() -> void:
	super._ready()
	interactable_type = InteractableType.GENERIC
	interact_priority = 8
	prompt_height = 1.6
	if interaction_name == "Interact":
		interaction_name = "Enter"
	_build_highlight()
	Events.interaction_available.connect(_on_interaction_available)
	Events.interaction_cleared.connect(_on_interaction_cleared)


func get_prompt_text() -> String:
	if is_locked():
		return locked_message
	return interaction_name


func is_locked() -> bool:
	return required_flag != "" and not SaveManager.has_flag(required_flag)


## True while the player's interact target is this exit (read-only, tests).
func is_focused() -> bool:
	return _focused


## Colour the exit glow is heading for right now (read-only, tests).
func get_highlight_color() -> Color:
	if is_locked():
		return COLOR_LOCKED
	return COLOR_FOCUS if _focused else COLOR_IDLE


# --- Highlight (cosmetic) ---

## Pad + curtain fitted to the first CollisionShape3D box child (the trigger).
func _build_highlight() -> void:
	if has_node(^"ExitHighlight"):
		return
	var trigger := Vector3(3, 3, 1)
	for c in get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			trigger = ((c as CollisionShape3D).shape as BoxShape3D).size
			break
	var pad_size := Vector2(trigger.x + PAD_MARGIN.x, trigger.z + PAD_MARGIN.y)

	var root := Node3D.new()
	root.name = "ExitHighlight"
	add_child(root)

	_pad_mat = ShaderMaterial.new()
	_pad_mat.shader = PadShader
	_pad_mat.set_shader_parameter(&"pad_size", pad_size)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	var plane := PlaneMesh.new()
	plane.size = pad_size
	pad.mesh = plane
	pad.material_override = _pad_mat
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.position.y = 0.03  # just above roads (0.01) and the floor
	root.add_child(pad)

	_curtain_mat = ShaderMaterial.new()
	_curtain_mat.shader = CurtainShader
	_curtain_mat.set_shader_parameter(&"use_proximity", false)
	_curtain_mat.set_shader_parameter(&"far_line_alpha", 0.9)
	_curtain_mat.set_shader_parameter(&"curtain_alpha", 0.28)
	var hx := pad_size.x * 0.5
	var hz := pad_size.y * 0.5
	# [position, yaw, width]
	var sides := [
		[Vector3(0, 0, -hz), 0.0, pad_size.x],
		[Vector3(0, 0, hz), PI, pad_size.x],
		[Vector3(-hx, 0, 0), PI * 0.5, pad_size.y],
		[Vector3(hx, 0, 0), -PI * 0.5, pad_size.y],
	]
	for i in sides.size():
		var s: Array = sides[i]
		var mi := MeshInstance3D.new()
		mi.name = "Curtain%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(s[2], CURTAIN_HEIGHT)
		mi.mesh = quad
		mi.material_override = _curtain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector3 = s[0]
		mi.position = Vector3(p.x, CURTAIN_HEIGHT * 0.5 + 0.03, p.z)
		mi.rotation.y = s[1]
		root.add_child(mi)
	_apply_highlight()


func _on_interaction_available(obj: Node3D) -> void:
	_focused = obj == self


func _on_interaction_cleared() -> void:
	_focused = false


func _process(delta: float) -> void:
	if _pad_mat == null:
		return
	_time += delta
	var target_i := INTENSITY_IDLE
	if _focused:
		target_i = INTENSITY_FOCUS + 0.18 * sin(_time * 5.0)
	var k := clampf(delta * 8.0, 0.0, 1.0)
	_intensity = lerpf(_intensity, target_i, k)
	_color = _color.lerp(get_highlight_color(), k)
	_apply_highlight()


func _apply_highlight() -> void:
	for m in [_pad_mat, _curtain_mat]:
		if m:
			m.set_shader_parameter(&"glow_color", _color)
			m.set_shader_parameter(&"intensity", _intensity)


func interact(player: Node) -> void:
	if not _is_active:
		return

	# Check gating
	if required_flag != "" and not SaveManager.has_flag(required_flag):
		Events.save_feedback.emit(locked_message)
		return

	portal_activated.emit(target_zone_id)

	# Save current state before transitioning
	var data := SaveManager.gather_save_data()
	# Override zone_id and position to the target
	data["zone_id"] = target_zone_id
	if data.has("player"):
		data["player"]["position"] = {
			"x": spawn_position.x,
			"y": spawn_position.y,
			"z": spawn_position.z
		}
	SaveManager.autosave(data)

	# Set pending load and transition
	Events.zone_exiting.emit(StringName(SaveManager._get_current_zone_id()))
	SaveManager._pending_load_data = data
	var scene_path := SaveManager._zone_id_to_scene(target_zone_id)
	get_tree().change_scene_to_file(scene_path)
