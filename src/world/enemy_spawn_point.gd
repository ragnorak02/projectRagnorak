## EnemySpawnPoint (Battle Test) — a Lumina crystal on a stone plinth that
## keeps `max_alive` hostile enemies in the world. When one dies, a new one
## appears here after `respawn_delay` seconds (the crystal flares as it does).
## The zone supplies `factory`: a Callable() -> Node3D that returns a NEW,
## not-yet-added enemy; this node adds it to its own parent at the spawn spot.
## Visual: stone plinth, a floating spinning red crystal and a red ring of light
## on the floor around it (the area enemies come out of).
extends Node3D

const CurtainShader := preload("res://src/world/shaders/glow_curtain.gdshader")
const COLOR := Color("#FF5C5C")  # UIStyle.DANGER: hostile

@export var max_alive: int = 2
@export var respawn_delay: float = 4.0
@export var ring_radius: float = 2.6

var factory: Callable = Callable()
var _alive: Array[Node3D] = []
var _timer: float = 0.0
var _spawned_total: int = 0
var _crystal: MeshInstance3D = null
var _crystal_mat: StandardMaterial3D = null
var _flare: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_build_visual()
	_timer = 0.5  # first wave shortly after the zone loads


func _build_visual() -> void:
	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.95
	cyl.height = 0.8
	plinth.mesh = cyl
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.31, 0.34)
	stone.roughness = 0.9
	plinth.material_override = stone
	plinth.position.y = 0.4
	add_child(plinth)

	# Solid plinth (World layer) so nothing walks through it.
	var body := StaticBody3D.new()
	body.name = "PlinthBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.95
	shape.height = 0.8
	col.shape = shape
	col.position.y = 0.4
	body.add_child(col)
	add_child(body)

	_crystal = MeshInstance3D.new()
	_crystal.name = "Crystal"
	var gem := SphereMesh.new()   # 4 x 2 segments = an octahedron-like crystal
	gem.radius = 0.38
	gem.height = 1.3
	gem.radial_segments = 4
	gem.rings = 2
	_crystal.mesh = gem
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = COLOR
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = COLOR
	_crystal_mat.emission_energy_multiplier = 1.5
	_crystal.material_override = _crystal_mat
	_crystal.position.y = 1.7
	add_child(_crystal)

	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position.y = 1.7
	add_child(light)

	var ring := MeshInstance3D.new()
	ring.name = "SpawnRing"
	var tube := CylinderMesh.new()
	tube.top_radius = ring_radius
	tube.bottom_radius = ring_radius
	tube.height = 1.2
	tube.cap_top = false
	tube.cap_bottom = false
	ring.mesh = tube
	var mat := ShaderMaterial.new()
	mat.shader = CurtainShader
	mat.set_shader_parameter(&"glow_color", COLOR)
	mat.set_shader_parameter(&"far_line_alpha", 0.9)
	mat.set_shader_parameter(&"curtain_alpha", 0.25)
	mat.set_shader_parameter(&"line_width", 0.1)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.6
	add_child(ring)


func _process(delta: float) -> void:
	_time += delta
	_crystal.rotation.y += delta * 1.2
	_crystal.position.y = 1.7 + sin(_time * 2.0) * 0.08
	_flare = maxf(_flare - delta * 2.0, 0.0)
	_crystal_mat.emission_energy_multiplier = 1.5 + _flare * 4.0
	_crystal.scale = Vector3.ONE * (1.0 + _flare * 0.35)


func _physics_process(delta: float) -> void:
	_alive = _alive.filter(func(e: Node3D) -> bool:
		return is_instance_valid(e) and not e.is_queued_for_deletion() \
			and e.get(&"ai_state") != EnemyBase.AIState.DEAD)
	if _alive.size() >= max_alive or not factory.is_valid():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_spawn_one()
	_timer = respawn_delay if _alive.size() >= max_alive else 0.6


func _spawn_one() -> void:
	var e: Node3D = factory.call()
	if e == null:
		return
	# Spread spawns around the plinth (fixed angles, deterministic).
	var ang := float(_spawned_total) * 2.39996
	var offset := Vector3(sin(ang), 0.0, cos(ang)) * (ring_radius - 0.6)
	get_parent().add_child(e)
	e.global_position = global_position + offset + Vector3(0, 1.0, 0)
	_alive.append(e)
	_spawned_total += 1
	_flare = 1.0


## Read-only (tests): hostile enemies from this point that are still alive.
func get_alive() -> Array[Node3D]:
	return _alive


func get_spawned_total() -> int:
	return _spawned_total
