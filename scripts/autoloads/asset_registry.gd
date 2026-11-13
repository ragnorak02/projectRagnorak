## Scans asset packs, resolves logical tile/prefab IDs to actual meshes.
## Handles fallback chain: bound pack → tag match → any pack → fallback → placeholder.
extends Node

signal pack_changed(pack_id: StringName)
signal registry_ready

# Parsed pack manifests keyed by pack_id
var _packs: Dictionary = {}
# zone_tag -> pack_id binding
var _zone_pack_bindings: Dictionary = {}
# Default pack when no binding matches
var _default_pack: String = "_fallback"
# Cache: "pack_id/tile_id" -> resolved mesh data dict
var _resolve_cache: Dictionary = {}

const PACKS_DIR := "res://asset_packs/"
const BINDINGS_PATH := "res://data/pack_bindings.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bindings()
	_scan_packs()
	registry_ready.emit()


# --- Pack Scanning ---

func _scan_packs() -> void:
	_packs.clear()
	var dir := DirAccess.open(PACKS_DIR)
	if dir == null:
		push_warning("AssetRegistry: Cannot open %s" % PACKS_DIR)
		return

	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			var manifest_path: String = PACKS_DIR + folder + "/pack_manifest.json"
			if FileAccess.file_exists(manifest_path):
				var pack := _parse_manifest(manifest_path, folder)
				if not pack.is_empty():
					_packs[pack["pack_id"]] = pack
		folder = dir.get_next()
	dir.list_dir_end()


func _parse_manifest(path: String, folder_name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("AssetRegistry: Empty manifest at %s" % path)
		return {}

	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_warning("AssetRegistry: Invalid JSON in %s" % path)
		return {}

	var manifest: Dictionary = data
	manifest["_folder"] = folder_name
	manifest["_base_path"] = PACKS_DIR + folder_name + "/"

	if not manifest.has("pack_id"):
		manifest["pack_id"] = folder_name
	if not manifest.has("tiles"):
		manifest["tiles"] = {}
	if not manifest.has("prefabs"):
		manifest["prefabs"] = {}
	if not manifest.has("cell_size"):
		manifest["cell_size"] = [2.0, 2.0, 2.0]
	if not manifest.has("tags"):
		manifest["tags"] = []

	return manifest


func _load_bindings() -> void:
	if not FileAccess.file_exists(BINDINGS_PATH):
		return

	var text := FileAccess.get_file_as_string(BINDINGS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		return

	var bindings_data: Dictionary = data
	if bindings_data.has("bindings"):
		var bindings: Dictionary = bindings_data["bindings"]
		for tag: String in bindings:
			_zone_pack_bindings[tag] = bindings[tag]

	if bindings_data.has("default_pack"):
		_default_pack = bindings_data["default_pack"]


# --- Pack Management ---

func get_pack_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key: String in _packs:
		ids.append(key)
	return ids


func get_pack_info(pack_id: String) -> Dictionary:
	return _packs.get(pack_id, {})


func bind_zone_tag(zone_tag: String, pack_id: String) -> void:
	_zone_pack_bindings[zone_tag] = pack_id
	_resolve_cache.clear()
	pack_changed.emit(StringName(pack_id))


func get_bound_pack(zone_tag: String) -> String:
	return _zone_pack_bindings.get(zone_tag, _default_pack)


func get_cell_size() -> Vector3:
	# Use fallback pack cell size as the global standard
	var fallback: Dictionary = _packs.get("_fallback", {})
	var cs: Array = fallback.get("cell_size", [2.0, 2.0, 2.0])
	return Vector3(cs[0], cs[1], cs[2])


# --- Tile Resolution ---

func resolve_tile(tile_id: StringName, zone_tags: PackedStringArray) -> Dictionary:
	# Check cache
	var cache_key: String = str(zone_tags) + "/" + tile_id
	if _resolve_cache.has(cache_key):
		return _resolve_cache[cache_key]

	var result := _resolve_tile_uncached(tile_id, zone_tags)
	_resolve_cache[cache_key] = result
	return result


func _resolve_tile_uncached(tile_id: StringName, zone_tags: PackedStringArray) -> Dictionary:
	# 1. Check bound packs for zone tags (exact tile ID)
	for tag in zone_tags:
		var pack_id: String = _zone_pack_bindings.get(tag, "")
		if pack_id != "" and _packs.has(pack_id):
			var pack: Dictionary = _packs[pack_id]
			var tiles: Dictionary = pack.get("tiles", {})
			if tiles.has(String(tile_id)):
				return _build_tile_result(pack, tiles[String(tile_id)], tile_id)

	# 2. Check bound packs for tag-based match
	var tile_tags := _extract_tile_tags(tile_id)
	for tag in zone_tags:
		var pack_id: String = _zone_pack_bindings.get(tag, "")
		if pack_id != "" and _packs.has(pack_id):
			var match_result := _find_by_tags(pack_id, tile_tags)
			if not match_result.is_empty():
				return match_result

	# 3. Check any loaded pack (exact match)
	for pack_id: String in _packs:
		if pack_id == "_fallback":
			continue
		var pack: Dictionary = _packs[pack_id]
		var tiles: Dictionary = pack.get("tiles", {})
		if tiles.has(String(tile_id)):
			return _build_tile_result(pack, tiles[String(tile_id)], tile_id)

	# 4. Fallback pack
	if _packs.has("_fallback"):
		var fallback: Dictionary = _packs["_fallback"]
		var tiles: Dictionary = fallback.get("tiles", {})
		if tiles.has(String(tile_id)):
			return _build_tile_result(fallback, tiles[String(tile_id)], tile_id)

	# 5. Procedural placeholder (neon pink = missing)
	push_warning("AssetRegistry: No tile found for '%s', using placeholder" % tile_id)
	return _build_placeholder(tile_id)


func _extract_tile_tags(tile_id: StringName) -> PackedStringArray:
	# Derive tags from tile ID (e.g., "floor_stone" -> ["floor", "stone"])
	return PackedStringArray(String(tile_id).split("_"))


func _find_by_tags(pack_id: String, target_tags: PackedStringArray) -> Dictionary:
	if not _packs.has(pack_id):
		return {}
	var pack: Dictionary = _packs[pack_id]
	var tiles: Dictionary = pack.get("tiles", {})

	var best_id := ""
	var best_score := 0

	for tid: String in tiles:
		var tile_def: Dictionary = tiles[tid]
		var tile_tags: Array = tile_def.get("tags", [])
		var score := 0
		for tag in target_tags:
			if tile_tags.has(tag):
				score += 1
		if score > best_score:
			best_score = score
			best_id = tid

	if best_score >= 1 and best_id != "":
		return _build_tile_result(pack, tiles[best_id], StringName(best_id))

	return {}


# --- Mesh Building ---

func _build_tile_result(pack: Dictionary, tile_def: Dictionary, tile_id: StringName) -> Dictionary:
	var result := {}
	result["tile_id"] = tile_id
	result["pack_id"] = pack.get("pack_id", "_fallback")

	var tile_type: String = tile_def.get("type", "procedural")

	if tile_type == "procedural":
		result["mesh"] = _generate_procedural_mesh(tile_def)
	else:
		# Load mesh from file
		var mesh_path: String = pack.get("_base_path", "") + tile_def.get("mesh", "")
		if ResourceLoader.exists(mesh_path):
			result["mesh"] = load(mesh_path)
		else:
			push_warning("AssetRegistry: Mesh not found at %s" % mesh_path)
			result["mesh"] = _generate_procedural_mesh(tile_def)

	# Collision
	var collision_mode: String = tile_def.get("collision", "auto")
	if collision_mode == "auto":
		result["collision"] = _generate_collision(tile_def, result.get("mesh"))
	elif collision_mode == "none":
		result["collision"] = null
	else:
		# Custom collision — load from file
		var col_path: String = pack.get("_base_path", "") + tile_def.get("collision_shape", "")
		if ResourceLoader.exists(col_path):
			result["collision"] = load(col_path)
		else:
			result["collision"] = _generate_collision(tile_def, result.get("mesh"))

	return result


func _generate_procedural_mesh(tile_def: Dictionary) -> Mesh:
	var shape_type: String = tile_def.get("shape", "box")
	var size: Array = tile_def.get("size", [1.0, 1.0, 1.0])
	var color: Array = tile_def.get("color", [1.0, 0.0, 1.0, 1.0])

	var mesh: Mesh
	match shape_type:
		"plane":
			var plane := PlaneMesh.new()
			plane.size = Vector2(size[0], size[1]) if size.size() >= 2 else Vector2(2.0, 2.0)
			mesh = plane
		"box":
			var box := BoxMesh.new()
			box.size = Vector3(size[0], size[1], size[2]) if size.size() >= 3 else Vector3(1.0, 1.0, 1.0)
			mesh = box
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size[0] if size.size() >= 1 else 0.5
			cyl.bottom_radius = size[0] if size.size() >= 1 else 0.5
			cyl.height = size[1] if size.size() >= 2 else 1.0
			mesh = cyl
		"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = size[0] if size.size() >= 1 else 0.5
			cap.height = size[1] if size.size() >= 2 else 1.0
			mesh = cap
		_:
			var box := BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			mesh = box

	# Apply material with color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color[0], color[1], color[2], color[3] if color.size() >= 4 else 1.0)
	mesh.material = mat

	return mesh


func _generate_collision(tile_def: Dictionary, mesh: Mesh) -> Shape3D:
	var shape_type: String = tile_def.get("shape", "box")
	var size: Array = tile_def.get("size", [1.0, 1.0, 1.0])

	match shape_type:
		"plane":
			var shape := BoxShape3D.new()
			var sx: float = size[0] if size.size() >= 1 else 2.0
			var sz: float = size[1] if size.size() >= 2 else 2.0
			shape.size = Vector3(sx, 0.05, sz)
			return shape
		"box":
			var shape := BoxShape3D.new()
			var sx: float = size[0] if size.size() >= 1 else 1.0
			var sy: float = size[1] if size.size() >= 2 else 1.0
			var sz: float = size[2] if size.size() >= 3 else 1.0
			shape.size = Vector3(sx, sy, sz)
			return shape
		"cylinder":
			var shape := CylinderShape3D.new()
			shape.radius = size[0] if size.size() >= 1 else 0.5
			shape.height = size[1] if size.size() >= 2 else 1.0
			return shape
		"capsule":
			var shape := CapsuleShape3D.new()
			shape.radius = size[0] if size.size() >= 1 else 0.5
			shape.height = size[1] if size.size() >= 2 else 1.0
			return shape

	# Fallback: try to create from mesh
	if mesh != null:
		return mesh.create_trimesh_shape()
	var fallback := BoxShape3D.new()
	fallback.size = Vector3(1.0, 1.0, 1.0)
	return fallback


func _build_placeholder(tile_id: StringName) -> Dictionary:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 1.0, 1.0)  # Neon pink = missing
	box.material = mat

	var col := BoxShape3D.new()
	col.size = Vector3(1.0, 1.0, 1.0)

	return {
		"tile_id": tile_id,
		"pack_id": "_placeholder",
		"mesh": box,
		"collision": col,
	}


# --- Prefab Resolution ---

func resolve_prefab(prefab_type: StringName, zone_tags: PackedStringArray) -> Dictionary:
	# 1. Check bound packs
	for tag in zone_tags:
		var pack_id: String = _zone_pack_bindings.get(tag, "")
		if pack_id != "" and _packs.has(pack_id):
			var pack: Dictionary = _packs[pack_id]
			var prefabs: Dictionary = pack.get("prefabs", {})
			if prefabs.has(String(prefab_type)):
				return _build_prefab_result(pack, prefabs[String(prefab_type)], prefab_type)

	# 2. Any pack
	for pack_id: String in _packs:
		if pack_id == "_fallback":
			continue
		var pack: Dictionary = _packs[pack_id]
		var prefabs: Dictionary = pack.get("prefabs", {})
		if prefabs.has(String(prefab_type)):
			return _build_prefab_result(pack, prefabs[String(prefab_type)], prefab_type)

	# 3. Fallback
	if _packs.has("_fallback"):
		var fallback: Dictionary = _packs["_fallback"]
		var prefabs: Dictionary = fallback.get("prefabs", {})
		if prefabs.has(String(prefab_type)):
			return _build_prefab_result(fallback, prefabs[String(prefab_type)], prefab_type)

	# 4. Placeholder
	return _build_placeholder(prefab_type)


func _build_prefab_result(pack: Dictionary, prefab_def: Dictionary, prefab_type: StringName) -> Dictionary:
	var result := {}
	result["prefab_type"] = prefab_type
	result["pack_id"] = pack.get("pack_id", "_fallback")

	var ptype: String = prefab_def.get("type", "procedural")
	if ptype == "procedural":
		result["mesh"] = _generate_procedural_mesh(prefab_def)
	else:
		var scene_path: String = pack.get("_base_path", "") + prefab_def.get("scene", "")
		if ResourceLoader.exists(scene_path):
			result["scene"] = load(scene_path)
		else:
			result["mesh"] = _generate_procedural_mesh(prefab_def)

	var offset: Array = prefab_def.get("anchor_offset", [0.0, 0.0, 0.0])
	result["anchor_offset"] = Vector3(offset[0], offset[1], offset[2]) if offset.size() >= 3 else Vector3.ZERO

	return result


# --- Utility ---

func clear_cache() -> void:
	_resolve_cache.clear()


func reload_packs() -> void:
	_resolve_cache.clear()
	_packs.clear()
	_scan_packs()
	registry_ready.emit()
