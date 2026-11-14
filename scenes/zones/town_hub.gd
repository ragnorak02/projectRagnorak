## Town Hub — Starting village built from medieval village megakit assets.
## Layout: Main road running south→north, town square in the center,
## buildings on both sides, guard tower at the north gate.
extends "res://src/world/zone_base.gd"

const NpcInteractable := preload("res://src/interaction/npc_interactable.gd")
## v5 placeholder NPC model (un-rigged Hunyuan mesh, RiglessVisual).
const PirateModel := preload("res://assets/models/characters/pirate_female1.glb")
## v6 JJ-4 NPC models (Hunyuan runs picked by the user, RiglessVisual).
const TeacherModel := preload("res://assets/models/characters/teacher_female2.glb")      # teacherFemale2 run-002
const AlchemistModel := preload("res://assets/models/characters/alchemist_female1.glb")  # alchemistFemale1 run-002
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")
const CarryableCrateScene := preload("res://src/interaction/carryable_crate.tscn")



func _ready() -> void:
	zone_id = "town_hub"
	spawn_position = Vector3(0, 1, 8)
	super._ready()


func _setup_zone() -> void:
	_build_terrain()
	_build_roads()
	_build_structures()
	_build_props()
	_place_npcs()
	_place_portals()


# ── Terrain ────────────────────────────────────────────────────────────────────

func _build_terrain() -> void:
	# Large grass ground plane
	TownBuilder.add_ground_plane(self, 100.0, Color(0.22, 0.32, 0.15))

	# Invisible boundary walls so player doesn't walk off the map
	TownBuilder.add_invisible_wall(self, Vector3(0, 2, -55), Vector3(100, 6, 1))   # north
	TownBuilder.add_invisible_wall(self, Vector3(0, 2, 15), Vector3(100, 6, 1))    # south
	TownBuilder.add_invisible_wall(self, Vector3(-30, 2, -20), Vector3(1, 6, 80))  # west
	TownBuilder.add_invisible_wall(self, Vector3(30, 2, -20), Vector3(1, 6, 80))   # east


# ── Roads & Paths ──────────────────────────────────────────────────────────────

func _build_roads() -> void:
	# Main road running south (Z=8) to north (Z=-48), 3 tiles wide (6m)
	TownBuilder.lay_road(self, Vector3(0, 0.01, 8), 30, 3, Vector3.BACK, "Floor_Brick")

	# Town square — wider paved area around Z=-20
	TownBuilder.lay_square(self, Vector3(0, 0.01, -20), 8, 6, "Floor_UnevenBrick")

	# East side path toward dungeon gate
	TownBuilder.lay_road(self, Vector3(4, 0.01, -8), 8, 2, Vector3.RIGHT, "Floor_Brick")

	# West path to residential area
	TownBuilder.lay_road(self, Vector3(-4, 0.01, -12), 5, 2, Vector3.LEFT, "Floor_Brick")


# ── Structures ─────────────────────────────────────────────────────────────────

func _build_structures() -> void:
	# ── SOUTH AREA (near spawn) ──

	# House A — small residential, east of road
	# 4x4m (2 segs × 2 segs), door faces west toward road
	TownBuilder.build_house(self, Vector3(6, 0, 2), 2, 2, 0.0, 3, 0,
		"plaster", true, false)

	# House B — small residential, west of road
	# 4x4m, door faces east toward road
	TownBuilder.build_house(self, Vector3(-10, 0, 2), 2, 2, 0.0, 1, 0,
		"plaster", false, false)

	# ── SOUTH-CENTER AREA ──

	# General Store — medium, east side
	# 4x6m (2w × 3d), door faces west
	TownBuilder.build_house(self, Vector3(6, 0, -10), 2, 3, 0.0, 3, 1,
		"plaster", false, true)

	# House C — west side
	# 4x4m, door faces east
	TownBuilder.build_house(self, Vector3(-10, 0, -10), 2, 2, 0.0, 1, 0,
		"brick", true, false)

	# ── TOWN SQUARE AREA (Z = -20) ──

	# Tavern / Inn — large building, west side of square
	# 6x8m (3w × 4d), door faces east toward square
	TownBuilder.build_house(self, Vector3(-18, 0, -26), 3, 4, 0.0, 1, 1,
		"plaster", true, true)

	# Weapon Shop — medium, east side of square
	# 4x6m (2w × 3d), door faces west toward square
	TownBuilder.build_house(self, Vector3(8, 0, -24), 2, 3, 0.0, 3, 1,
		"brick", false, false)

	# ── NORTH AREA ──

	# Elder's House — medium, prominent building east of road
	# 4x6m (2w × 3d), door faces west, has balcony
	TownBuilder.build_house(self, Vector3(6, 0, -38), 2, 3, 0.0, 3, 0,
		"plaster", true, true)

	# House D — small, west of road
	TownBuilder.build_house(self, Vector3(-10, 0, -36), 2, 2, 0.0, 1, 0,
		"plaster", false, false)

	# Guard Tower — near north gate, brick
	TownBuilder.build_tower(self, Vector3(8, 0, -46))

	# House E — small, further west
	TownBuilder.build_house(self, Vector3(-10, 0, -46), 2, 2, 0.0, 1, 0,
		"brick", false, false)


# ── Props & Decoration ─────────────────────────────────────────────────────────

func _build_props() -> void:
	# Town square decorations
	TownBuilder.place(self, "Prop_Wagon", Vector3(-3, 0, -19), 25, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(3, 0, -18), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(3.5, 0, -19.2), 45, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(2.5, 1.06, -18.5), 15, true)  # stacked

	# Liftable crates (single, ground level). The stack above stays static.
	_add_carryable_crate(Vector3(2, 0, 3))      # near spawn
	_add_carryable_crate(Vector3(1.5, 0, -14))  # square, south edge

	# Scattered bricks near construction / elder's house
	TownBuilder.place(self, "Prop_Brick1", Vector3(5, 0, -35))
	TownBuilder.place(self, "Prop_Brick2", Vector3(5.5, 0, -35.3), 30)
	TownBuilder.place(self, "Prop_Brick3", Vector3(4.8, 0, -34.5), 60)

	# Wooden fences along paths
	# East side of south road
	TownBuilder.place_fence_line(self, Vector3(4, 0, 4), 4, Vector3.BACK)
	# West side of south road
	TownBuilder.place_fence_line(self, Vector3(-4, 0, 4), 4, Vector3.BACK)
	# Around town square edges
	TownBuilder.place_fence_line(self, Vector3(-8, 0, -16), 3, Vector3.BACK)
	TownBuilder.place_fence_line(self, Vector3(6, 0, -16), 3, Vector3.BACK)

	# Metal fences near guard tower
	TownBuilder.place(self, "Prop_MetalFence_Ornament", Vector3(6, 0, -44))
	TownBuilder.place(self, "Prop_MetalFence_Ornament", Vector3(14, 0, -44))

	# Vines on some buildings
	TownBuilder.add_vines(self, [
		Vector3(-17, 1.5, -24),   # tavern wall
		Vector3(-17, 2.0, -28),   # tavern wall higher
		Vector3(7, 1.5, -37),     # elder's house
	])

	# Exterior stairs at tavern entrance
	TownBuilder.place(self, "Stairs_Exterior_Platform", Vector3(-12, 0, -22))

	# Support beams at weapon shop
	TownBuilder.place(self, "Prop_Support", Vector3(8, 0, -22))

	# Exterior border stones along square
	TownBuilder.place(self, "Prop_ExteriorBorder_Straight1", Vector3(-6, 0, -16))
	TownBuilder.place(self, "Prop_ExteriorBorder_Straight2", Vector3(4, 0, -16))
	TownBuilder.place(self, "Prop_ExteriorBorder_Corner", Vector3(-6, 0, -24))


# ── NPCs ───────────────────────────────────────────────────────────────────────

func _place_npcs() -> void:
	# Elder Hwan — near his house
	_add_npc("Elder Hwan", Vector3(4, 0, -36), Color(0.7, 0.5, 0.2), [
		{"speaker": "Elder Hwan", "text": "Welcome to Millhaven, traveler. Times grow uncertain."},
		{"speaker": "Elder Hwan", "text": "The Lumina reactors hum louder each day. Something stirs."},
		{"speaker": "Elder Hwan", "text": "Seek the ancient shrine beyond the northern gate."},
	])

	# Merchant Soo — at the general store
	_add_npc("Merchant Soo", Vector3(4, 0, -8), Color(0.2, 0.6, 0.4), [
		{"speaker": "Merchant Soo", "text": "Welcome! I deal in provisions and curiosities."},
		{"speaker": "Merchant Soo", "text": "Bring me rare materials from the wilds."},
	], PirateModel)

	# Innkeeper — at the tavern entrance
	_add_npc("Innkeeper Mira", Vector3(-12, 0, -22), Color(0.6, 0.3, 0.3), [
		{"speaker": "Innkeeper Mira", "text": "Rest here and recover your strength."},
		{"speaker": "Innkeeper Mira", "text": "Soldiers passed through this morning. Headed north."},
	])

	# Blacksmith — at weapon shop
	_add_npc("Smith Oren", Vector3(6, 0, -22), Color(0.4, 0.3, 0.25), [
		{"speaker": "Smith Oren", "text": "Need a blade sharpened? I'm your man."},
		{"speaker": "Smith Oren", "text": "Bring me ores and I'll forge something worthy."},
	])

	# Guard — near the north gate / tower
	_add_npc("Guard Captain", Vector3(4, 0, -46), Color(0.35, 0.35, 0.45), [
		{"speaker": "Guard Captain", "text": "The northern fields are dangerous. Stay alert."},
		{"speaker": "Guard Captain", "text": "Report any monster sightings to me."},
	])

	# Villager — walking in the square
	_add_npc("Villager", Vector3(-2, 0, -20), Color(0.5, 0.45, 0.35), [
		{"speaker": "Villager", "text": "Have you seen the lights from the reactor at night?"},
		{"speaker": "Villager", "text": "They say the coastal facility is the biggest one yet."},
	])

	# v6 JJ-4: Scholar Yeun (Teacher Female 2) — quest giver on the north edge
	# of the square. Dialogue only: no quest system hook yet.
	_add_npc("Scholar Yeun", Vector3(-4, 0, -27), Color(0.45, 0.4, 0.6), [
		{"speaker": "Scholar Yeun", "text": "Ah, a new face. I teach the village children their letters, and their Lumina lore."},
		{"speaker": "Scholar Yeun", "text": "The shrine beyond the northern fields holds glyphs older than any reactor."},
		{"speaker": "Scholar Yeun", "text": "If you venture there, bring me word of what is carved inside. I will make it worth your while."},
	], TeacherModel)

	# v6 JJ-4: Alchemist Ines (Alchemist Female 1) — vendor at the west path.
	# Dialogue only: no shop UI hook yet.
	_add_npc("Alchemist Ines", Vector3(-7, 0, -14.5), Color(0.3, 0.55, 0.45), [
		{"speaker": "Alchemist Ines", "text": "Tonics, salves, a little chilled Lumina dust. Mind the fumes."},
		{"speaker": "Alchemist Ines", "text": "Bring me herbs and monster parts from the wilds and I'll brew you something strong."},
	], AlchemistModel)


# ── Portals ────────────────────────────────────────────────────────────────────

func _place_portals() -> void:
	# North gate → field zone
	_add_portal("Northern Gate", Vector3(0, 0, -50), "field_zone", Vector3(0, 1, 10))

	# East path → dungeon zone
	_add_portal("Dungeon Entrance", Vector3(20, 0, -8), "dungeon_zone", Vector3(0, 1, 10))


# ── NPC / Portal Helpers (unchanged from original) ────────────────────────────

## `model`: optional un-rigged NPC model (RiglessVisual). `face_point`: where the
## NPC looks by default; INF = the main road (x = 0) a few metres toward the
## south approach, so NPCs face the street the player arrives on (v6 JJ-2).
func _add_npc(npc_name: String, pos: Vector3, color: Color, pages: Array, model: PackedScene = null,
		face_point: Vector3 = Vector3.INF) -> void:
	var npc := Area3D.new()
	npc.set_script(NpcInteractable)
	npc.npc_name = npc_name
	npc.dialogue_pages.assign(pages)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	col.shape = shape
	npc.add_child(col)

	# Visual capsule (placeholder until character models)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	mesh.mesh = capsule
	mesh.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	npc.add_child(mesh)
	if model != null:
		# Un-rigged model replaces the capsule; idle bob only (NPCs don't move).
		mesh.visible = false
		var rv: Node3D = load("res://src/characters/rigless_visual.gd").new()
		rv.name = "RiglessVisual"
		rv.set(&"model_scene", model)
		rv.set(&"fit_height", 1.7)
		rv.set(&"model_yaw_offset_deg", 180.0)
		rv.set(&"face_speaker_in_dialogue", true)
		npc.add_child(rv)

	# Floating name label
	# Name plate (UI Package N): fixed on-screen size (~24px tall at any distance,
	# so it can never fill the screen when the camera is close), style-kit font,
	# dim text with an outline, and a self-fade between 18m and 22m.
	var label_3d := Label3D.new()
	label_3d.text = npc_name
	label_3d.position.y = 2.1
	label_3d.font = UIStyle.font_body_bold()
	label_3d.font_size = 48
	label_3d.fixed_size = true
	label_3d.pixel_size = 0.00052
	label_3d.modulate = UIStyle.TEXT.lerp(UIStyle.TEXT_DIM, 0.35)
	label_3d.outline_modulate = Color(0.0, 0.02, 0.04, 0.85)
	label_3d.outline_size = 12
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.visibility_range_begin = 0.6
	label_3d.visibility_range_begin_margin = 0.6
	label_3d.visibility_range_end = 22.0
	label_3d.visibility_range_end_margin = 4.0
	label_3d.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	npc.add_child(label_3d)

	# Facing is set before entering the tree so the visual starts on it.
	npc.rotation.y = npc_face_yaw(pos, face_point)
	add_child(npc)
	npc.global_position = pos


## Yaw that points an NPC at `face_point` (INF = the street default above).
static func npc_face_yaw(pos: Vector3, face_point: Vector3 = Vector3.INF) -> float:
	var target := face_point if face_point.is_finite() else Vector3(0.0, pos.y, pos.z + 4.0)
	var d := target - pos
	d.y = 0.0
	if d.length() < 0.1:
		return 0.0
	return atan2(-d.x, -d.z)


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
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(3, 3, 1)
	col.shape = box_shape
	portal.add_child(col)

	# Visual arch marker
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 0.3)
	mesh.mesh = box
	mesh.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	mesh.material_override = mat
	portal.add_child(mesh)

	# Portal label
	# Portal plate (UI Package N): fixed on-screen size, header font, gold text,
	# self-fade beyond ~30m so far gates don't clutter the view.
	var label_3d := Label3D.new()
	label_3d.text = portal_name
	label_3d.position.y = 3.3
	label_3d.font = UIStyle.font_header_medium()
	label_3d.font_size = 48
	label_3d.fixed_size = true
	label_3d.pixel_size = 0.00058
	label_3d.modulate = UIStyle.GOLD
	label_3d.outline_modulate = Color(0.0, 0.02, 0.04, 0.85)
	label_3d.outline_size = 12
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.visibility_range_begin = 0.6
	label_3d.visibility_range_begin_margin = 0.6
	label_3d.visibility_range_end = 30.0
	label_3d.visibility_range_end_margin = 5.0
	label_3d.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	portal.add_child(label_3d)

	add_child(portal)
	portal.global_position = pos


## Liftable crate (Package H). Single, ground-level crates only.
func _add_carryable_crate(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var crate: Node3D = CarryableCrateScene.instantiate()
	add_child(crate)
	crate.global_position = pos
	crate.rotation.y = deg_to_rad(rot_y)
	return crate
