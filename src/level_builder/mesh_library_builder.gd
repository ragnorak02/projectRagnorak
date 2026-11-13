## Generates a GridMap MeshLibrary from resolved tile data at runtime.
## MeshLibrary is built in memory (never saved to disk) so asset packs can be swapped freely.
class_name MeshLibraryBuilder
extends RefCounted

# GridMap orientation integers for Y-axis rotations.
# These encode a 3x3 orthogonal basis matrix as a single int.
const ORIENTATION_0   := 0   # 0°
const ORIENTATION_90  := 16  # 90° clockwise
const ORIENTATION_180 := 10  # 180°
const ORIENTATION_270 := 22  # 270° clockwise


## Build a MeshLibrary from a list of tile IDs, resolving each through AssetRegistry.
## Returns { "library": MeshLibrary, "id_map": Dictionary<String, int> }
static func build(tile_ids: PackedStringArray, zone_tags: PackedStringArray) -> Dictionary:
	var lib := MeshLibrary.new()
	var id_map := {}
	var index := 0

	# Sort tile IDs for deterministic index assignment
	var sorted_ids := Array(tile_ids)
	sorted_ids.sort()

	for tile_id: String in sorted_ids:
		var resolved: Dictionary = AssetRegistry.resolve_tile(StringName(tile_id), zone_tags)
		if resolved.is_empty():
			continue

		lib.create_item(index)

		var mesh: Mesh = resolved.get("mesh")
		if mesh != null:
			lib.set_item_mesh(index, mesh)

		lib.set_item_name(index, tile_id)

		# Collision shapes: MeshLibrary expects Array of [Shape3D, Transform3D] pairs
		var collision: Shape3D = resolved.get("collision")
		if collision != null:
			var shapes: Array = []
			shapes.append(collision)
			shapes.append(Transform3D.IDENTITY)
			lib.set_item_shapes(index, shapes)

		id_map[tile_id] = index
		index += 1

	return {"library": lib, "id_map": id_map}


## Convert a 0-3 rotation value to a GridMap orientation integer.
static func rotation_to_orientation(rotation: int) -> int:
	match rotation % 4:
		0:
			return ORIENTATION_0
		1:
			return ORIENTATION_90
		2:
			return ORIENTATION_180
		3:
			return ORIENTATION_270
	return ORIENTATION_0
