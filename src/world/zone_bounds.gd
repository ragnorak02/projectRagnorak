## ZoneBounds — the edge of a zone's walkable area (v7).
## Builds four tall collision walls just outside an axis-aligned XZ rectangle,
## so nothing (walking, dodging, Super Jump ~12 m) can leave the ground, plus a
## subtle visual: a thin cyan line along the ground at the edge, and a soft
## energy curtain that only fades in within ~7 m of the player.
## Purely world geometry: it reads the follow target's position for the shader
## and never writes to it. Falling recovery lives on the Player (owner of its
## own movement), see Player.fall_reset_y.
extends Node3D

const CurtainShader := preload("res://src/world/shaders/glow_curtain.gdshader")

const WALL_HEIGHT := 80.0       # far above any jump (Super Jump apex ~12 m)
const WALL_THICKNESS := 2.0     # thick enough that a fast dash cannot tunnel
const CURTAIN_HEIGHT := 2.4
const REVEAL_DISTANCE := 7.0
const COLOR := Color("#5FE3F0")  # UIStyle.CYAN (Lumina accent)

## Walkable rectangle in world XZ (x = world X, y = world Z).
@export var rect_min: Vector2 = Vector2(-10, -10)
@export var rect_max: Vector2 = Vector2(10, 10)
@export var floor_y: float = 0.0
## false = collision walls only (no edge line / curtain), e.g. when the zone
## draws its own visible walls (Battle Test arena).
@export var show_edge: bool = true

## Node whose position reveals the curtain (the Player). Optional.
var follow_target: Node3D = null
var _material: ShaderMaterial = null


## Convenience: create, configure and add a ZoneBounds under `parent`.
static func create(parent: Node, p_min: Vector2, p_max: Vector2, target: Node3D = null,
		p_floor_y: float = 0.0, p_show_edge: bool = true) -> Node3D:
	var b: Node3D = (load("res://src/world/zone_bounds.gd") as GDScript).new()
	b.name = "ZoneBounds"
	b.rect_min = p_min
	b.rect_max = p_max
	b.floor_y = p_floor_y
	b.follow_target = target
	b.show_edge = p_show_edge
	parent.add_child(b)
	return b


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = CurtainShader
	_material.set_shader_parameter(&"glow_color", COLOR)
	_material.set_shader_parameter(&"use_proximity", true)
	_material.set_shader_parameter(&"reveal_distance", REVEAL_DISTANCE)
	_build()


func _build() -> void:
	var cx := (rect_min.x + rect_max.x) * 0.5
	var cz := (rect_min.y + rect_max.y) * 0.5
	var w := rect_max.x - rect_min.x
	var d := rect_max.y - rect_min.y
	var t := WALL_THICKNESS
	var y := floor_y + WALL_HEIGHT * 0.5 - 1.0  # 1 m below the floor too
	# name, wall centre, wall size, curtain centre, curtain yaw, curtain width
	var sides := [
		["North", Vector3(cx, y, rect_min.y - t * 0.5), Vector3(w + t * 2.0, WALL_HEIGHT, t),
			Vector3(cx, 0, rect_min.y), 0.0, w],
		["South", Vector3(cx, y, rect_max.y + t * 0.5), Vector3(w + t * 2.0, WALL_HEIGHT, t),
			Vector3(cx, 0, rect_max.y), PI, w],
		["West", Vector3(rect_min.x - t * 0.5, y, cz), Vector3(t, WALL_HEIGHT, d + t * 2.0),
			Vector3(rect_min.x, 0, cz), PI * 0.5, d],
		["East", Vector3(rect_max.x + t * 0.5, y, cz), Vector3(t, WALL_HEIGHT, d + t * 2.0),
			Vector3(rect_max.x, 0, cz), -PI * 0.5, d],
	]
	for s in sides:
		var body := StaticBody3D.new()
		body.name = "Wall" + s[0]
		body.collision_layer = 1  # World (same as the old invisible walls)
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[2]
		col.shape = box
		body.add_child(col)
		add_child(body)
		body.position = s[1]
		if not show_edge:
			continue

		var mi := MeshInstance3D.new()
		mi.name = "Edge" + s[0]
		var quad := QuadMesh.new()
		quad.size = Vector2(s[5], CURTAIN_HEIGHT)
		mi.mesh = quad
		mi.material_override = _material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var cpos: Vector3 = s[3]
		mi.position = Vector3(cpos.x, floor_y + CURTAIN_HEIGHT * 0.5 + 0.02, cpos.z)
		mi.rotation.y = s[4]


func _process(_delta: float) -> void:
	if _material == null:
		return
	if follow_target != null and is_instance_valid(follow_target):
		_material.set_shader_parameter(&"player_pos", follow_target.global_position)


## True when an XZ point is inside the walkable rectangle (tests / tools).
func contains_xz(p: Vector3) -> bool:
	return p.x >= rect_min.x and p.x <= rect_max.x and p.z >= rect_min.y and p.z <= rect_max.y
