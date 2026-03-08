## Dungeon Zone — indoor area with puzzles and enemies.
## Features switch puzzles using the lever + switch_puzzle framework.
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
const LeverInteractable := preload("res://src/interaction/lever_interactable.gd")
const SwitchPuzzle := preload("res://src/interaction/switch_puzzle.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const HiddenArea := preload("res://src/interaction/hidden_area.gd")


func _ready() -> void:
	zone_id = "dungeon_zone"
	super._ready()


func _setup_zone() -> void:
	# Dark floor
	_add_ground(Color(0.15, 0.12, 0.1))

	# Enemies
	_add_enemy(Vector3(5, 0, -5))
	_add_enemy(Vector3(-4, 0, -15))

	# Portal back to field
	_add_portal("Exit to Field", Vector3(0, 0, 12), "field_zone", Vector3(0, 1, -23))

	# Switch puzzle — two levers unlock a reward chest
	_add_switch_puzzle()

	# Hidden area deeper in dungeon
	_add_hidden_area("dungeon_secret", Vector3(12, 0, -20), "Discovered: Secret Chamber!")


func _add_ground(color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 40)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 0.1, 40)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	add_child(body)


func _add_enemy(pos: Vector3) -> void:
	var enemy := EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.global_position.y = 1.0


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
	puzzle.levers = [
		puzzle.get_path_to(lever1) if false else NodePath("../Lever1"),
		NodePath("../Lever2"),
	]
	puzzle.target = NodePath("../RewardChest")
	puzzle.name = "DungeonPuzzle"
	add_child(puzzle)

	# Connect lever paths properly after tree is built
	puzzle.levers = [NodePath("../Lever1"), NodePath("../Lever2")]


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
	chest.contents = []

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
