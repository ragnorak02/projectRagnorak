## Dungeon Zone — indoor area with puzzles and enemies.
## Features switch puzzles using the lever + switch_puzzle framework.
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
## v5 placeholder enemy models (un-rigged Hunyuan meshes, RiglessVisual).
## Spawns alternate between them; names match the model.
const ENEMY_MODELS := [
	["Kobold", preload("res://assets/models/characters/kobold_female1.glb")],
	["Kobold Queen", preload("res://assets/models/characters/kobold_queen1.glb")],
	["Goblin", preload("res://assets/models/characters/goblin_male2.glb")],  # v6 JJ-4: goblinMale2 run-002
]
## v6 JJ-4: dungeon elite / brute (goblinchiefMale1 run-001), fitted to 2.4 m.
const GoblinChiefModel := preload("res://assets/models/characters/goblinchief_male1.glb")
const ELITE_HEIGHT := 2.4
var _enemy_spawn_count: int = 0
const LeverInteractable := preload("res://src/interaction/lever_interactable.gd")
const SwitchPuzzle := preload("res://src/interaction/switch_puzzle.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const HiddenArea := preload("res://src/interaction/hidden_area.gd")
const CarryableCrateScene := preload("res://src/interaction/carryable_crate.tscn")
const ZoneBounds := preload("res://src/world/zone_bounds.gd")
## v7: dungeon floor, now 32 x 48 so the reward chest (z = -20) and the secret
## chamber are inside the edge instead of on the lip of a 30 x 40 slab.
const FLOOR_SIZE := Vector2(32, 48)


func _ready() -> void:
	zone_id = "dungeon_zone"
	super._ready()


func _setup_zone() -> void:
	# Dark floor
	_add_ground(Color(0.15, 0.12, 0.1))
	# Zone edge (v7): the dungeon had no walls at all, so you could walk off.
	ZoneBounds.create(self, Vector2(-15.0, -23.0), Vector2(15.0, 15.0), player)

	# Enemies
	_add_enemy(Vector3(5, 0, -5))
	_add_enemy(Vector3(-4, 0, -15))
	_add_enemy(Vector3(-7, 0, -6))  # 3rd spawn -> Goblin in the rotation

	# Elite brute guarding the reward chest
	_add_elite(Vector3(3, 0, -16))

	# Portal back to field
	_add_portal("Exit to Field", Vector3(0, 0, 12), "field_zone", Vector3(0, 1, -23))

	# Switch puzzle — two levers unlock a reward chest
	_add_switch_puzzle()

	# Liftable crates (Package H): throw them at the enemies
	_add_carryable_crate(Vector3(2, 0, 6))
	_add_carryable_crate(Vector3(-2, 0, -4), 20)

	# Hidden area deeper in dungeon
	_add_hidden_area("dungeon_secret", Vector3(12, 0, -20), "Discovered: Secret Chamber!")


func _add_ground(color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = FLOOR_SIZE
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(FLOOR_SIZE.x, 0.1, FLOOR_SIZE.y)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	add_child(body)


func _add_enemy(pos: Vector3) -> void:
	var enemy := EnemyScene.instantiate()
	var pick: Array = ENEMY_MODELS[_enemy_spawn_count % ENEMY_MODELS.size()]
	_enemy_spawn_count += 1
	enemy.display_name = pick[0]
	enemy.rigless_model = pick[1]
	add_child(enemy)
	enemy.global_position = pos
	enemy.global_position.y = 1.0


## Goblin Chief elite: tougher stats via EnemyBase exports, a 2.4 m model, and
## the body's collision / hurtbox / lock-on point / health bar scaled to match
## (per-spawn copies of the shapes; enemy.tscn's shared shapes stay untouched).
func _add_elite(pos: Vector3) -> Node3D:
	var enemy := EnemyScene.instantiate()
	enemy.display_name = "Goblin Chief"
	enemy.rigless_model = GoblinChiefModel
	enemy.rigless_fit_height = ELITE_HEIGHT
	enemy.max_hp = 140.0
	enemy.attack_damage = 16.0
	enemy.move_speed = 3.2
	enemy.attack_range = 2.4
	enemy.stagger_max = 180.0
	_scale_enemy_body(enemy, ELITE_HEIGHT)
	add_child(enemy)
	enemy.global_position = pos
	enemy.global_position.y = 1.0
	var bar := enemy.get_node_or_null(^"HealthBar") as Node3D
	if bar:
		bar.position.y = ELITE_HEIGHT + 0.45
	return enemy


## Resize an enemy.tscn body (authored for 1.6 m) to `height` before _ready.
static func _scale_enemy_body(enemy: Node, height: float) -> void:
	var k := height / 1.6
	var col := enemy.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius = 0.4 * minf(k, 1.4)
		cap.height = height
		col.shape = cap
		col.position.y = height * 0.5
	var hurt := enemy.get_node_or_null(^"Hurtbox") as Node3D
	if hurt:
		hurt.position.y = height * 0.5
		var hcol := hurt.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
		if hcol and hcol.shape is SphereShape3D:
			var sph := (hcol.shape as SphereShape3D).duplicate() as SphereShape3D
			sph.radius = 0.5 * k
			hcol.shape = sph
	var lock := enemy.get_node_or_null(^"LockOnPoint") as Node3D
	if lock:
		lock.position.y = 1.2 * k
	var atk := enemy.get_node_or_null(^"AttackOrigin") as Node3D
	if atk:
		atk.position = Vector3(0.0, 1.0 * k, -0.8 * minf(k, 1.4))


func _add_portal(portal_name: String, pos: Vector3, target_zone: String,
		target_pos: Vector3) -> void:
	var portal := Area3D.new()
	portal.set_script(ZonePortal)
	portal.interaction_name = portal_name
	portal.target_zone_id = target_zone
	portal.spawn_position = target_pos

	var pcol := CollisionShape3D.new()
	var pshape := BoxShape3D.new()
	pshape.size = Vector3(3, 3, 1)
	pcol.shape = pshape
	portal.add_child(pcol)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 0.3)
	mesh.mesh = box
	mesh.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2)
	mesh.material_override = mat
	portal.add_child(mesh)

	add_child(portal)
	portal.global_position = pos


func _add_switch_puzzle() -> void:
	if SaveManager.has_flag("puzzle_dungeon_gate"):
		# Puzzle already solved — just show the reward chest
		_add_reward_chest(Vector3(0, 0, -20))
		return

	# Lever 1
	var lever1 := Area3D.new()
	lever1.set_script(LeverInteractable)
	lever1.name = "Lever1"
	var l1col := CollisionShape3D.new()
	var l1shape := SphereShape3D.new()
	l1shape.radius = 2.0
	l1col.shape = l1shape
	lever1.add_child(l1col)
	_add_lever_visual(lever1)
	add_child(lever1)
	lever1.global_position = Vector3(-5, 0, -10)

	# Lever 2
	var lever2 := Area3D.new()
	lever2.set_script(LeverInteractable)
	lever2.name = "Lever2"
	var l2col := CollisionShape3D.new()
	var l2shape := SphereShape3D.new()
	l2shape.radius = 2.0
	l2col.shape = l2shape
	lever2.add_child(l2col)
	_add_lever_visual(lever2)
	add_child(lever2)
	lever2.global_position = Vector3(5, 0, -10)

	# Reward chest (hidden until puzzle solved)
	var chest := _create_chest(Vector3(0, 0, -20))
	chest.visible = false
	chest.set_active(false)

	# Puzzle controller
	var puzzle := Node3D.new()
	puzzle.set_script(SwitchPuzzle)
	puzzle.puzzle_id = "dungeon_gate"
	# Typed array: assigning an untyped [] literal to Array[NodePath] errors at runtime.
	var lever_paths: Array[NodePath] = [NodePath("../Lever1"), NodePath("../Lever2")]
	puzzle.levers = lever_paths
	puzzle.target = NodePath("../RewardChest")
	puzzle.name = "DungeonPuzzle"
	add_child(puzzle)

	# Connect lever paths properly after tree is built
	puzzle.levers = lever_paths


func _add_lever_visual(lever: Node) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.15
	cyl.height = 1.0
	mesh.mesh = cyl
	mesh.position.y = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.3)
	mesh.material_override = mat
	lever.add_child(mesh)


func _create_chest(pos: Vector3) -> Node:
	var chest := Area3D.new()
	chest.set_script(ChestInteractable)
	chest.name = "RewardChest"
	# (contents left at the typed default; assigning an untyped [] errors at runtime)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	col.shape = shape
	chest.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.6, 0.6)
	mesh.mesh = box
	mesh.position.y = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.1)
	mesh.material_override = mat
	chest.add_child(mesh)

	add_child(chest)
	chest.global_position = pos
	return chest


func _add_reward_chest(pos: Vector3) -> void:
	if SaveManager.has_flag("chest_dungeon_reward"):
		return
	_create_chest(pos)


func _add_hidden_area(area_id: String, pos: Vector3, message: String) -> void:
	var area := Area3D.new()
	area.set_script(HiddenArea)
	area.area_id = area_id
	area.discovery_message = message

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	area.add_child(col)

	add_child(area)
	area.global_position = pos


## Liftable crate (Package H). Single, ground-level crates only.
func _add_carryable_crate(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var crate: Node3D = CarryableCrateScene.instantiate()
	add_child(crate)
	crate.global_position = pos
	crate.rotation.y = deg_to_rad(rot_y)
	return crate
