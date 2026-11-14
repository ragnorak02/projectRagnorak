## Assembles medieval village buildings from the Quaternius megakit glTF pieces.
## Grid: 2m wall segments, 3m wall height, 2m floor tiles.
class_name TownBuilder

const ASSET_PATH := "res://public/assets/medieval_village_megakitstandard/glTF/"
const WALL_W := 2.0  # wall segment width (meters)
const WALL_H := 3.0  # one story height
const TILE := 2.0     # floor tile size


# ── Asset Loading ──────────────────────────────────────────────────────────────

## Per-asset merged mesh AABB cache (local to the asset root), used by solid props.
## Kept as Engine metadata (AABB values only), NOT a `static var`: a script with
## static vars is pinned by GDScript's static cache and was one of the scripts
## reported "still in use at exit" (v6 KK-1). See _aabb_cache().
const _AABB_CACHE_META := &"_town_builder_aabb_cache"


static func _aabb_cache() -> Dictionary:
	if not Engine.has_meta(_AABB_CACHE_META):
		Engine.set_meta(_AABB_CACHE_META, {})
	return Engine.get_meta(_AABB_CACHE_META)


static func place(parent: Node3D, asset_name: String, pos: Vector3, rot_y: float = 0.0,
		solid: bool = false) -> Node3D:
	## Place a single kit asset. rot_y in degrees.
	## solid = true adds a StaticBody3D (World layer) with one BoxShape3D fitted to the
	## merged mesh AABB, so the player can collide with and stand on it. Use it for
	## crates, wagons and other chunky props, not for walls, floors, decals or clutter.
	var path := ASSET_PATH + asset_name + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("TownBuilder: missing asset '%s'" % asset_name)
		return _placeholder(parent, pos)
	var scene: PackedScene = load(path)
	var inst := scene.instantiate()
	inst.position = pos
	if rot_y != 0.0:
		inst.rotation.y = deg_to_rad(rot_y)
	if solid:
		_add_aabb_collision(inst, asset_name)
	parent.add_child(inst)
	return inst


static func _add_aabb_collision(inst: Node3D, cache_key: String) -> void:
	var aabb: AABB
	var cache := _aabb_cache()
	if cache.has(cache_key):
		aabb = cache[cache_key]
	else:
		aabb = merged_mesh_aabb(inst)
		cache[cache_key] = aabb
	if aabb.size.length_squared() < 0.0001:
		return
	var body := StaticBody3D.new()
	body.name = "SolidCollision"
	body.collision_layer = 1  # World
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = aabb.size
	col.shape = shape
	col.position = aabb.get_center()
	body.add_child(col)
	inst.add_child(body)


static func merged_mesh_aabb(root: Node3D) -> AABB:
	## Merge the AABBs of every MeshInstance3D under root, in root's local space.
	## Works before root is in the tree (walks local transforms).
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xf: Transform3D = entry[1]
		for child in node.get_children():
			if not (child is Node3D):
				continue
			var cxf: Transform3D = xf * (child as Node3D).transform
			if child is MeshInstance3D and (child as MeshInstance3D).mesh:
				var box: AABB = cxf * (child as MeshInstance3D).mesh.get_aabb()
				if first:
					result = box
					first = false
				else:
					result = result.merge(box)
			stack.append([child, cxf])
	return result


static func _placeholder(parent: Node3D, pos: Vector3) -> Node3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 1)  # neon pink = missing
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# ── Building Assembly ──────────────────────────────────────────────────────────

static func build_house(parent: Node3D, pos: Vector3, segs_w: int, segs_d: int,
		rot_y: float = 0.0, door_side: int = 0, door_seg: int = 0,
		style: String = "plaster", has_chimney: bool = false,
		has_balcony: bool = false) -> Node3D:
	## Build a rectangular 1-story building.
	## segs_w / segs_d = wall segments (each 2m). So segs_w=2 = 4m wide.
	## door_side: 0=front(-Z), 1=right(+X), 2=back(+Z), 3=left(-X)
	## door_seg: which segment on that side gets the door (0-based from left/front).
	var bld := Node3D.new()
	bld.name = "Building_%dx%d" % [segs_w * 2, segs_d * 2]
	parent.add_child(bld)
	bld.position = pos
	if rot_y != 0.0:
		bld.rotation.y = deg_to_rad(rot_y)

	var w := float(segs_w) * WALL_W
	var d := float(segs_d) * WALL_W

	# Pick wall/corner assets by style
	var wall: String = "Wall_Plaster_Straight" if style == "plaster" else "Wall_UnevenBrick_Straight"
	var wall_door: String = "Wall_Plaster_Door_Flat" if style == "plaster" else "Wall_UnevenBrick_Door_Flat"
	var wall_win: String = "Wall_Plaster_Window_Wide_Flat" if style == "plaster" else "Wall_UnevenBrick_Window_Wide_Flat"
	var corner: String = "Corner_Exterior_Wood" if style == "plaster" else "Corner_Exterior_Brick"

	# ── Walls ──
	# Front (faces -Z, at Z=0)
	for i in segs_w:
		var x := float(i) * WALL_W + WALL_W * 0.5
		var asset := wall
		if door_side == 0 and i == door_seg:
			asset = wall_door
		elif segs_w > 1 and i != door_seg:
			asset = wall_win
		place(bld, asset, Vector3(x, 0, 0), 0)
		# Add door frame + door for door segment
		if door_side == 0 and i == door_seg:
			place(bld, "DoorFrame_Flat_Brick", Vector3(x, 0, 0), 0)
			place(bld, "Door_1_Flat", Vector3(x, 0, 0), 0)

	# Back (faces +Z, at Z=depth)
	for i in segs_w:
		var x := w - float(i) * WALL_W - WALL_W * 0.5
		var asset := wall
		if door_side == 2 and i == door_seg:
			asset = wall_door
			place(bld, "DoorFrame_Flat_Brick", Vector3(x, 0, d), 180)
			place(bld, "Door_1_Flat", Vector3(x, 0, d), 180)
		elif segs_w > 2 and i % 2 == 1:
			asset = wall_win
		place(bld, asset, Vector3(x, 0, d), 180)

	# Left (faces -X, at X=0)
	for i in segs_d:
		var z := d - float(i) * WALL_W - WALL_W * 0.5
		var asset := wall
		if door_side == 3 and i == door_seg:
			asset = wall_door
			place(bld, "DoorFrame_Flat_Brick", Vector3(0, 0, z), 90)
			place(bld, "Door_1_Flat", Vector3(0, 0, z), 90)
		elif segs_d > 2:
			asset = wall_win
		place(bld, asset, Vector3(0, 0, z), 90)

	# Right (faces +X, at X=width)
	for i in segs_d:
		var z := float(i) * WALL_W + WALL_W * 0.5
		var asset := wall
		if door_side == 1 and i == door_seg:
			asset = wall_door
			place(bld, "DoorFrame_Flat_Brick", Vector3(w, 0, z), -90)
			place(bld, "Door_1_Flat", Vector3(w, 0, z), -90)
		elif segs_d > 2:
			asset = wall_win
		place(bld, asset, Vector3(w, 0, z), -90)

	# ── Corners ──
	place(bld, corner, Vector3(0, 0, 0), 0)
	place(bld, corner, Vector3(w, 0, 0), -90)
	place(bld, corner, Vector3(w, 0, d), 180)
	place(bld, corner, Vector3(0, 0, d), 90)

	# ── Floor ──
	for ix in segs_w:
		for iz in segs_d:
			var fx := float(ix) * TILE + TILE * 0.5
			var fz := float(iz) * TILE + TILE * 0.5
			place(bld, "Floor_WoodDark", Vector3(fx, 0.02, fz))

	# ── Roof ──
	var roof_name := _pick_roof(segs_w * 2, segs_d * 2)
	place(bld, roof_name, Vector3(w * 0.5, WALL_H, d * 0.5))

	# ── Optional chimney ──
	if has_chimney:
		place(bld, "Prop_Chimney", Vector3(w * 0.3, WALL_H + 0.5, d * 0.3))

	# ── Optional balcony (front, second segment if available) ──
	if has_balcony and segs_w >= 2:
		var bx := WALL_W * 1.5 if segs_w >= 2 else WALL_W * 0.5
		place(bld, "Balcony_Simple_Straight", Vector3(bx, WALL_H * 0.66, -0.2))

	# ── Collision ──
	_add_building_collision(bld, Vector3(w, WALL_H + 2.0, d))

	return bld


static func build_tower(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	## 4x4m guard tower: brick walls, 2 stories, tower roof.
	var tower := Node3D.new()
	tower.name = "Tower"
	parent.add_child(tower)
	tower.position = pos
	if rot_y != 0.0:
		tower.rotation.y = deg_to_rad(rot_y)

	var wall := "Wall_Plaster_Straight"
	var wall_win := "Wall_Plaster_Window_Wide_Flat"
	var corner := "Corner_Exterior_Brick"

	# Two stories of walls
	for story in 2:
		var y := float(story) * WALL_H
		# 4 sides, 2 segments each
		for i in 2:
			var seg_offset := float(i) * WALL_W + WALL_W * 0.5
			var asset := wall if story == 0 else wall_win
			# Door on ground floor, front, first segment
			if story == 0 and i == 0:
				place(tower, "Wall_Plaster_Door_Flat", Vector3(seg_offset, y, 0), 0)
				place(tower, "DoorFrame_Flat_Brick", Vector3(seg_offset, y, 0), 0)
				place(tower, "Door_1_Flat", Vector3(seg_offset, y, 0), 0)
			else:
				place(tower, asset, Vector3(seg_offset, y, 0), 0)  # front
			place(tower, asset, Vector3(4.0 - seg_offset + WALL_W, y, 4), 180)  # back
			place(tower, asset, Vector3(0, y, 4.0 - seg_offset + WALL_W), 90)   # left
			place(tower, asset, Vector3(4, y, seg_offset), -90)                  # right

		# Corners
		place(tower, corner, Vector3(0, y, 0), 0)
		place(tower, corner, Vector3(4, y, 0), -90)
		place(tower, corner, Vector3(4, y, 4), 180)
		place(tower, corner, Vector3(0, y, 4), 90)

	# Tower roof at 2-story height
	place(tower, "Roof_Tower_RoundTiles", Vector3(2, WALL_H * 2, 2))

	# Floor tiles
	for ix in 2:
		for iz in 2:
			place(tower, "Floor_Brick", Vector3(float(ix) * TILE + 1, 0.02, float(iz) * TILE + 1))

	_add_building_collision(tower, Vector3(4, WALL_H * 2 + 3, 4))
	return tower


# ── Ground & Roads ─────────────────────────────────────────────────────────────

static func lay_road(parent: Node3D, start: Vector3, length_segs: int,
		width_segs: int = 3, direction: Vector3 = Vector3.BACK,
		tile_name: String = "Floor_Brick") -> void:
	## Lay a road strip. direction should be a unit vector (BACK = -Z, RIGHT = +X).
	var lateral: Vector3
	if abs(direction.z) > 0.5:
		lateral = Vector3.RIGHT
	else:
		lateral = Vector3.BACK
	var half_w := float(width_segs) / 2.0
	for seg in length_segs:
		for w_i in width_segs:
			var offset_l := (float(w_i) - half_w + 0.5) * TILE
			var p := start + direction * float(seg) * TILE + lateral * offset_l
			place(parent, tile_name, p)


static func lay_square(parent: Node3D, center: Vector3, tiles_x: int, tiles_z: int,
		tile_name: String = "Floor_UnevenBrick") -> void:
	## Lay a rectangular area of floor tiles centered on center.
	var half_x := float(tiles_x) / 2.0
	var half_z := float(tiles_z) / 2.0
	for ix in tiles_x:
		for iz in tiles_z:
			var x := (float(ix) - half_x + 0.5) * TILE
			var z := (float(iz) - half_z + 0.5) * TILE
			place(parent, tile_name, center + Vector3(x, 0, z))


# ── Props ──────────────────────────────────────────────────────────────────────

static func place_fence_line(parent: Node3D, start: Vector3, count: int,
		direction: Vector3 = Vector3.RIGHT) -> void:
	## Place a line of wooden fence segments.
	var rot_y := 0.0
	if abs(direction.z) > 0.5:
		rot_y = 90.0
	for i in count:
		var p := start + direction * float(i) * WALL_W
		place(parent, "Prop_WoodenFence_Single", p, rot_y)


static func add_vines(building: Node3D, positions: Array) -> void:
	## Add vine decorations to a building. positions = Array[Vector3].
	var vine_assets := ["Prop_Vine1", "Prop_Vine2", "Prop_Vine4", "Prop_Vine5"]
	for i in positions.size():
		var vine_name: String = vine_assets[i % vine_assets.size()]
		place(building, vine_name, positions[i])


# ── Collision Helpers ──────────────────────────────────────────────────────────

static func _add_building_collision(building: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	body.add_child(col)
	building.add_child(body)


static func add_ground_plane(parent: Node3D, size: float = 80.0, color: Color = Color(0.22, 0.32, 0.15)) -> void:
	## Large grass ground plane as base terrain.
	var mi := MeshInstance3D.new()
	mi.name = "GroundPlane"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size, 0.1, size)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	parent.add_child(body)


static func add_invisible_wall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	## Invisible collision barrier (town boundary, etc.).
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


# ── Ruins & Field Structures ───────────────────────────────────────────────────

static func build_ruin(parent: Node3D, pos: Vector3, segs_w: int, segs_d: int,
		rot_y: float = 0.0, walls_mask: int = 0b1111) -> Node3D:
	## Partial building ruin — walls only (no roof), scattered bricks.
	## walls_mask: bit 0=front, 1=right, 2=back, 3=left. e.g. 0b1010 = front+back only.
	var ruin := Node3D.new()
	ruin.name = "Ruin_%dx%d" % [segs_w * 2, segs_d * 2]
	parent.add_child(ruin)
	ruin.position = pos
	if rot_y != 0.0:
		ruin.rotation.y = deg_to_rad(rot_y)

	var w := float(segs_w) * WALL_W
	var d := float(segs_d) * WALL_W
	var wall := "Wall_UnevenBrick_Straight"
	var wall_win := "Wall_UnevenBrick_Window_Wide_Flat"
	var corner := "Corner_Exterior_Brick"

	# Front
	if walls_mask & 1:
		for i in segs_w:
			var x := float(i) * WALL_W + WALL_W * 0.5
			var asset := wall if i % 2 == 0 else wall_win
			place(ruin, asset, Vector3(x, 0, 0), 0)
	# Right
	if walls_mask & 2:
		for i in segs_d:
			var z := float(i) * WALL_W + WALL_W * 0.5
			place(ruin, wall, Vector3(w, 0, z), -90)
	# Back
	if walls_mask & 4:
		for i in segs_w:
			var x := w - float(i) * WALL_W - WALL_W * 0.5
			place(ruin, wall, Vector3(x, 0, d), 180)
	# Left
	if walls_mask & 8:
		for i in segs_d:
			var z := d - float(i) * WALL_W - WALL_W * 0.5
			place(ruin, wall, Vector3(0, 0, z), 90)

	# Corners where two walls meet
	if walls_mask & 1 and walls_mask & 8:
		place(ruin, corner, Vector3(0, 0, 0), 0)
	if walls_mask & 1 and walls_mask & 2:
		place(ruin, corner, Vector3(w, 0, 0), -90)
	if walls_mask & 4 and walls_mask & 2:
		place(ruin, corner, Vector3(w, 0, d), 180)
	if walls_mask & 4 and walls_mask & 8:
		place(ruin, corner, Vector3(0, 0, d), 90)

	# Scattered bricks for rubble
	var brick_assets := ["Prop_Brick1", "Prop_Brick2", "Prop_Brick3", "Prop_Brick4"]
	for i in (segs_w + segs_d):
		var bx: float = randf_range(0.5, w - 0.5) if w > 1 else 0.5
		var bz: float = randf_range(0.5, d - 0.5) if d > 1 else 0.5
		place(ruin, brick_assets[i % brick_assets.size()],
			Vector3(bx, 0, bz), float(i * 53 % 360))

	# Floor tiles (broken stone)
	for ix in segs_w:
		for iz in segs_d:
			place(ruin, "Floor_UnevenBrick",
				Vector3(float(ix) * TILE + 1, 0.01, float(iz) * TILE + 1))

	_add_building_collision(ruin, Vector3(w, WALL_H, d))
	return ruin


static func build_archway(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	## Freestanding stone archway using Wall_Arch.
	var arch := Node3D.new()
	arch.name = "Archway"
	parent.add_child(arch)
	arch.position = pos
	if rot_y != 0.0:
		arch.rotation.y = deg_to_rad(rot_y)
	place(arch, "Wall_Arch", Vector3.ZERO, 0)
	# Flanking wall segments for visual weight
	place(arch, "Wall_UnevenBrick_Straight", Vector3(-2, 0, 0), 0)
	place(arch, "Wall_UnevenBrick_Straight", Vector3(2, 0, 0), 0)
	place(arch, "Corner_Exterior_Brick", Vector3(-3, 0, 0), 0)
	place(arch, "Corner_Exterior_Brick", Vector3(3, 0, 0), -90)
	return arch


static func build_wall_line(parent: Node3D, start: Vector3, count: int,
		rot_y: float = 0.0, style: String = "brick") -> Node3D:
	## Freestanding wall line (boundary wall, field divider, ruin remains).
	var line := Node3D.new()
	line.name = "WallLine_%d" % count
	parent.add_child(line)
	line.position = start
	if rot_y != 0.0:
		line.rotation.y = deg_to_rad(rot_y)
	var wall := "Wall_UnevenBrick_Straight" if style == "brick" else "Wall_Plaster_Straight"
	var corner := "Corner_Exterior_Brick" if style == "brick" else "Corner_Exterior_Wood"
	# End cap
	place(line, corner, Vector3(0, 0, 0), 0)
	for i in count:
		place(line, wall, Vector3(float(i) * WALL_W + WALL_W * 0.5, 0, 0), 0)
	place(line, corner, Vector3(float(count) * WALL_W, 0, 0), -90)

	# Collision for the whole line
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var total_w := float(count) * WALL_W
	shape.size = Vector3(total_w, WALL_H, 0.4)
	col.shape = shape
	col.position = Vector3(total_w * 0.5, WALL_H * 0.5, 0)
	body.add_child(col)
	line.add_child(body)
	return line


static func build_lean_to(parent: Node3D, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	## Simple shelter — roof on supports, open sides. Good for camps/wayposts.
	var shelter := Node3D.new()
	shelter.name = "LeanTo"
	parent.add_child(shelter)
	shelter.position = pos
	if rot_y != 0.0:
		shelter.rotation.y = deg_to_rad(rot_y)
	# Four support posts
	place(shelter, "Prop_Support", Vector3(-1.5, 0, -1.5))
	place(shelter, "Prop_Support", Vector3(1.5, 0, -1.5))
	place(shelter, "Prop_Support", Vector3(-1.5, 0, 1.5))
	place(shelter, "Prop_Support", Vector3(1.5, 0, 1.5))
	# Small roof
	place(shelter, "Roof_RoundTiles_4x4", Vector3(0, 2.5, 0))
	# Floor
	place(shelter, "Floor_WoodDark", Vector3(0, 0.02, 0))
	return shelter


static func build_elevated_platform(parent: Node3D, pos: Vector3,
		tiles_x: int, tiles_z: int, height: float = 1.0) -> Node3D:
	## Raised ground platform with stairs. Uses wall segments as retaining walls.
	var plat := Node3D.new()
	plat.name = "Platform"
	parent.add_child(plat)
	plat.position = pos
	var w := float(tiles_x) * TILE
	var d := float(tiles_z) * TILE

	# Retaining walls (half-height using Wall_BottomCover)
	for i in tiles_x:
		place(plat, "Wall_BottomCover", Vector3(float(i) * TILE + 1, 0, 0), 0)
		place(plat, "Wall_BottomCover", Vector3(w - float(i) * TILE - 1, 0, d), 180)
	for i in tiles_z:
		place(plat, "Wall_BottomCover", Vector3(0, 0, d - float(i) * TILE - 1), 90)
		place(plat, "Wall_BottomCover", Vector3(w, 0, float(i) * TILE + 1), -90)

	# Floor surface on top
	for ix in tiles_x:
		for iz in tiles_z:
			place(plat, "Floor_Brick",
				Vector3(float(ix) * TILE + 1, height, float(iz) * TILE + 1))

	# Stairs on one side
	place(plat, "Stairs_Exterior_Platform", Vector3(w * 0.5, 0, -0.5))

	# Collision for the platform body
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, height, d)
	col.shape = shape
	col.position = Vector3(w * 0.5, height * 0.5, d * 0.5)
	body.add_child(col)
	plat.add_child(body)
	return plat


static func scatter_bricks(parent: Node3D, center: Vector3, radius: float, count: int) -> void:
	## Scatter loose brick props in a radius around a center point.
	var bricks := ["Prop_Brick1", "Prop_Brick2", "Prop_Brick3", "Prop_Brick4"]
	for i in count:
		var angle := float(i) / float(count) * TAU + float(i) * 1.7
		var dist: float = radius * (0.3 + 0.7 * absf(sin(float(i) * 2.3)))
		var p := center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		place(parent, bricks[i % bricks.size()], p, float(i * 67 % 360))


# ── Internals ──────────────────────────────────────────────────────────────────

static func _pick_roof(width_m: int, depth_m: int) -> String:
	# Available roof sizes from the kit
	var valid := ["4x4", "4x6", "4x8", "6x4", "6x6", "6x8", "6x10", "6x12", "6x14",
		"8x8", "8x10", "8x12", "8x14"]
	var key := "%dx%d" % [width_m, depth_m]
	if key in valid:
		return "Roof_RoundTiles_" + key
	var swapped := "%dx%d" % [depth_m, width_m]
	if swapped in valid:
		return "Roof_RoundTiles_" + swapped
	# Closest: pick smallest roof that fits
	return "Roof_RoundTiles_4x4"
