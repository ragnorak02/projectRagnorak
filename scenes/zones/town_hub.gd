## Town Hub — first town with NPCs, quest givers, and zone exits.
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
const NpcInteractable := preload("res://src/interaction/npc_interactable.gd")
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")


func _ready() -> void:
	zone_id = "town_hub"
	super._ready()


func _setup_zone() -> void:
	# Add a ground plane
	_add_ground(Color(0.25, 0.35, 0.2))

	# Quest giver NPC
	_add_npc("Elder Hwan", Vector3(4, 0, -3), [
		{"speaker": "Elder Hwan", "text": "Welcome, traveler. The forest spirits are restless."},
		{"speaker": "Elder Hwan", "text": "Seek the ancient shrine in the field beyond."},
	])

	# Merchant NPC
	_add_npc("Merchant Soo", Vector3(-3, 0, -5), [
		{"speaker": "Merchant Soo", "text": "I have wares if you have coin."},
		{"speaker": "Merchant Soo", "text": "Come back when you find rare materials."},
	])

	# Portal to field zone
	_add_portal("Field Exit", Vector3(0, 0, -12), "field_zone", Vector3(0, 1, 10))

	# Portal to dungeon (requires progression flag)
	_add_portal("Dungeon Gate", Vector3(10, 0, 0), "dungeon_zone", Vector3(0, 1, 10),
		"shrine_activated", "The dungeon gate is sealed.")


func _add_ground(color: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	mesh_inst.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 0.1, 40)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	add_child(body)


func _add_npc(npc_name: String, pos: Vector3, pages: Array) -> void:
	var npc := Area3D.new()
	npc.set_script(NpcInteractable)
	npc.npc_name = npc_name
	npc.dialogue_pages = pages

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	npc.add_child(col)

	# Visual capsule
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.8)
	mesh.material_override = mat
	npc.add_child(mesh)

	npc.global_position = pos
	npc.position.y = 0.0
	add_child(npc)


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

	# Visual marker
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 0.3)
	mesh.mesh = box
	mesh.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	mesh.material_override = mat
	portal.add_child(mesh)

	portal.global_position = pos
	add_child(portal)
