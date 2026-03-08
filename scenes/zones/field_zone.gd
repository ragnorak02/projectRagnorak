## Field Zone — outdoor area with enemies, chests, and hidden areas.
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")
const HiddenArea := preload("res://src/interaction/hidden_area.gd")


func _ready() -> void:
	zone_id = "field_zone"
	super._ready()


func _setup_zone() -> void:
	# Ground
	_add_ground(Color(0.3, 0.4, 0.15))

	# Enemies — spawn fresh each zone load (item 275: enemy states reset per zone)
	_add_enemy(Vector3(5, 0, -8))
	_add_enemy(Vector3(-6, 0, -12))
	_add_enemy(Vector3(8, 0, -18))

	# Portal back to town
	_add_portal("Return to Town", Vector3(0, 0, 12), "town_hub", Vector3(0, 1, -10))

	# Portal to dungeon (unlocked for now)
	_add_portal("Shrine Entrance", Vector3(0, 0, -25), "dungeon_zone", Vector3(0, 1, 10))

	# Chest with items (exploration reward)
	_add_chest(Vector3(-8, 0, -6))

	# Hidden area in a corner
	_add_hidden_area("field_alcove", Vector3(15, 0, -15), "Discovered: Hidden Alcove!")


func _add_ground(color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 60)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 0.1, 60)
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
		target_pos: Vector3, flag: String = "", locked_msg: String = "") -> void:
	var portal := Area3D.new()
	portal.set_script(ZonePortal)
	portal.interaction_name = portal_name
	portal.target_zone_id = target_zone
	portal.spawn_position = target_pos
	if flag != "":
		portal.required_flag = flag
		portal.locked_message = locked_msg

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 1)
	col.shape = shape
	portal.add_child(col)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 0.3)
	mesh.mesh = box
	mesh.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.3)
	mesh.material_override = mat
	portal.add_child(mesh)

	add_child(portal)
	portal.global_position = pos


func _add_chest(pos: Vector3) -> void:
	if SaveManager.has_flag("chest_field_1"):
		return  # Already opened
	var chest := Area3D.new()
	chest.set_script(ChestInteractable)
	# No actual items for now (placeholder)
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
	mat.albedo_color = Color(0.7, 0.5, 0.2)
	mesh.material_override = mat
	chest.add_child(mesh)

	add_child(chest)
	chest.global_position = pos


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
