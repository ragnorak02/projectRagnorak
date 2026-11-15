## Battle Test — walled practice arena (Main Menu > Battle Test).
## 80 x 80 m, stone walls on all sides. Three stations, each marked by a ring of
## light on the floor and a name sign:
##   Training Dummy  (-10, 14)  passive, can be killed, comes back after 3 s.
##   Enemy Spawner   ( 14, -6)  red crystal; keeps 2 hostile enemies alive and
##                              replaces each one 4 s after it dies.
##   Combo Partner   (-18, -24) invincible and passive; wanders inside its 5 m
##                              ring and walks back if knocked out of it.
## This zone never autosaves, so it cannot overwrite story progress / Continue.
##
## Layout (top view, north = -Z):
##   +-----------------------------------------+ z = -40
##   |   (Combo Partner)                       |
##   |        o                [Spawner] *     |
##   |                                         |
##   |      (Dummy) o                          |
##   |                    @ player spawn       |
##   +-----------------------------------------+ z = +40
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
const TrainingEnemyScript := preload("res://src/enemies/training_enemy.gd")
const SpawnPointScript := preload("res://src/world/enemy_spawn_point.gd")
const ZoneBounds := preload("res://src/world/zone_bounds.gd")
const CurtainShader := preload("res://src/world/shaders/glow_curtain.gdshader")

const HOSTILE_MODELS := [
	["Kobold", preload("res://assets/models/characters/kobold_female1.glb")],
	["Goblin", preload("res://assets/models/characters/goblin_male2.glb")],
]
const PartnerModel := preload("res://assets/models/characters/kobold_queen1.glb")

const HALF := 40.0               # arena is 2*HALF square
const WALL_HEIGHT := 3.0
const DUMMY_POS := Vector3(-10, 0, 14)
const SPAWNER_POS := Vector3(14, 0, -6)
const PARTNER_POS := Vector3(-18, 0, -24)
const PARTNER_LEASH := 5.0
const DUMMY_RESPAWN := 3.0

const CYAN := Color("#5FE3F0")
const GOLD := Color("#F2B544")

var dummy: Node3D = null
var partner: Node3D = null
var spawner: Node3D = null
var _hostile_count: int = 0
var _wall_count: int = 0


func _ready() -> void:
	zone_id = "battle_test"
	spawn_position = Vector3(0, 1, 30)
	super._ready()


func _setup_zone() -> void:
	TownBuilder.add_ground_plane(self, HALF * 2.0 + 10.0, Color(0.30, 0.33, 0.30))
	ZoneBounds.create(self, Vector2(-HALF, -HALF), Vector2(HALF, HALF), player, 0.0, false)
	_build_walls()

	# Training dummy
	_add_station_marker(DUMMY_POS, 2.2, CYAN, "Training Dummy", "Does not fight back")
	_spawn_dummy()

	# Hostile spawner
	spawner = Node3D.new()
	spawner.set_script(SpawnPointScript)
	spawner.name = "EnemySpawner"
	spawner.set(&"factory", _make_hostile)
	add_child(spawner)
	spawner.global_position = SPAWNER_POS
	_add_sign(SPAWNER_POS + Vector3(0, 3.0, 0), "Enemy Spawner", Color("#FF5C5C"), "2 hostiles · respawn 4 s")

	# Invincible combo partner
	_add_station_marker(PARTNER_POS, PARTNER_LEASH + 0.6, GOLD, "Combo Partner", "Invincible · stays in this ring")
	partner = _make_training(PartnerModel, "Combo Partner", 1.0e6, true, PARTNER_LEASH)
	add_child(partner)
	partner.global_position = PARTNER_POS + Vector3(0, 1.0, 0)
	partner.set(&"home", PARTNER_POS)


## No autosave in the practice arena (keeps the story save / Continue intact).
func _autosave_on_entry() -> void:
	pass


# ── Enemies ────────────────────────────────────────────────────────────────────

func _make_training(model: PackedScene, label: String, hp: float, invincible: bool,
		leash: float) -> Node3D:
	var e: Node3D = EnemyScene.instantiate()
	e.set_script(TrainingEnemyScript)
	e.display_name = label
	e.max_hp = hp
	e.stagger_max = 100.0
	e.set(&"passive", true)
	e.set(&"invincible", invincible)
	e.set(&"leash_radius", leash)
	if model != null:
		e.rigless_model = model
	return e


func _spawn_dummy() -> void:
	dummy = _make_training(null, "Training Dummy", 300.0, false, 0.0)
	add_child(dummy)
	dummy.global_position = DUMMY_POS + Vector3(0, 1.0, 0)
	dummy.set(&"home", DUMMY_POS)
	dummy.tree_exited.connect(_on_dummy_gone, CONNECT_ONE_SHOT)


func _on_dummy_gone() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return  # zone unloading
	# Connection (not await): it is dropped automatically if the zone is freed.
	get_tree().create_timer(DUMMY_RESPAWN).timeout.connect(_respawn_dummy)


func _respawn_dummy() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_spawn_dummy()


## Spawner factory: a normal (hostile) enemy, alternating models.
func _make_hostile() -> Node3D:
	var e: Node3D = EnemyScene.instantiate()
	var pick: Array = HOSTILE_MODELS[_hostile_count % HOSTILE_MODELS.size()]
	_hostile_count += 1
	e.display_name = pick[0]
	e.rigless_model = pick[1]
	return e


# ── Arena dressing ─────────────────────────────────────────────────────────────

## Visible stone walls standing in the outer ZoneBounds collision.
func _build_walls() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.38)
	mat.roughness = 0.95
	var t := 1.0
	var wall_len := HALF * 2.0 + t * 2.0
	for s in [
		[Vector3(0, 0, -HALF - t * 0.5), Vector3(wall_len, WALL_HEIGHT, t)],
		[Vector3(0, 0, HALF + t * 0.5), Vector3(wall_len, WALL_HEIGHT, t)],
		[Vector3(-HALF - t * 0.5, 0, 0), Vector3(t, WALL_HEIGHT, wall_len)],
		[Vector3(HALF + t * 0.5, 0, 0), Vector3(t, WALL_HEIGHT, wall_len)],
	]:
		var mi := MeshInstance3D.new()
		mi.name = "ArenaWall%d" % _wall_count
		_wall_count += 1
		var box := BoxMesh.new()
		box.size = s[1]
		mi.mesh = box
		mi.material_override = mat
		add_child(mi)
		mi.position = (s[0] as Vector3) + Vector3(0, WALL_HEIGHT * 0.5, 0)
	# A cyan trim line along the top of the walls (Lumina accent).
	var trim := StandardMaterial3D.new()
	trim.albedo_color = CYAN
	trim.emission_enabled = true
	trim.emission = CYAN
	trim.emission_energy_multiplier = 0.8
	for s in [
		[Vector3(0, 0, -HALF), Vector3(HALF * 2.0, 0.08, 0.08)],
		[Vector3(0, 0, HALF), Vector3(HALF * 2.0, 0.08, 0.08)],
		[Vector3(-HALF, 0, 0), Vector3(0.08, 0.08, HALF * 2.0)],
		[Vector3(HALF, 0, 0), Vector3(0.08, 0.08, HALF * 2.0)],
	]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s[1]
		mi.mesh = box
		mi.material_override = trim
		add_child(mi)
		mi.position = (s[0] as Vector3) + Vector3(0, WALL_HEIGHT, 0)


## Glowing floor ring + floating name sign for a station.
func _add_station_marker(pos: Vector3, radius: float, color: Color, title: String, sub: String) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Ring_" + title.replace(" ", "")
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = 0.8
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 48
	ring.mesh = tube
	var mat := ShaderMaterial.new()
	mat.shader = CurtainShader
	mat.set_shader_parameter(&"glow_color", color)
	mat.set_shader_parameter(&"far_line_alpha", 0.8)
	mat.set_shader_parameter(&"curtain_alpha", 0.15)
	mat.set_shader_parameter(&"line_width", 0.12)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.position = pos + Vector3(0, 0.4, 0)
	_add_sign(pos + Vector3(0, 3.0, 0) + Vector3(0, 0, -radius * 0.0), title, color, sub)


func _add_sign(pos: Vector3, title: String, color: Color, sub: String) -> void:
	var l := Label3D.new()
	l.name = "Sign_" + title.replace(" ", "")
	l.text = title + "\n" + sub
	l.font = UIStyle.font_header_medium()
	l.font_size = 44
	l.fixed_size = true
	l.pixel_size = 0.0005
	l.modulate = color
	l.outline_modulate = Color(0.0, 0.02, 0.04, 0.85)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.visibility_range_end = 45.0
	l.visibility_range_end_margin = 5.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(l)
	l.position = pos
