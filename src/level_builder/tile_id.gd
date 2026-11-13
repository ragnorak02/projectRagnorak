## Standard logical tile IDs used across all asset packs and level data.
## Packs map these IDs to actual meshes. Levels reference these IDs in JSON.
class_name TileId
extends RefCounted

# --- Floors ---
const FLOOR_STONE := &"floor_stone"
const FLOOR_WOOD := &"floor_wood"
const FLOOR_DIRT := &"floor_dirt"
const FLOOR_GRASS := &"floor_grass"
const FLOOR_TILE := &"floor_tile"
const FLOOR_MARBLE := &"floor_marble"

# --- Walls ---
const WALL_STONE := &"wall_stone"
const WALL_BRICK := &"wall_brick"
const WALL_WOOD := &"wall_wood"
const WALL_PLASTER := &"wall_plaster"
const WALL_HALF := &"wall_half"

# --- Doors / Openings ---
const DOOR_ARCH := &"door_arch"
const DOOR_FRAME := &"door_frame"
const WINDOW_FRAME := &"window_frame"

# --- Stairs / Ramps ---
const STAIRS_STONE := &"stairs_stone"
const STAIRS_WOOD := &"stairs_wood"
const RAMP_STONE := &"ramp_stone"

# --- Pillars / Columns ---
const PILLAR_STONE := &"pillar_stone"
const PILLAR_WOOD := &"pillar_wood"
const PILLAR_CRUMBLED := &"pillar_crumbled"

# --- Ceilings / Roofs ---
const CEILING_STONE := &"ceiling_stone"
const ROOF_TILE := &"roof_tile"

# --- Props / Decorations ---
const PROP_BARREL := &"prop_barrel"
const PROP_CRATE := &"prop_crate"
const PROP_TABLE := &"prop_table"
const PROP_BENCH := &"prop_bench"
const PROP_LANTERN := &"prop_lantern"
const PROP_TORCH := &"prop_torch"
const PROP_TREE := &"prop_tree"
const PROP_BUSH := &"prop_bush"
const PROP_ROCK := &"prop_rock"
const PROP_FENCE := &"prop_fence"

# --- Bridges / Platforms ---
const BRIDGE_WOOD := &"bridge_wood"
const BRIDGE_STONE := &"bridge_stone"
const PLATFORM_STONE := &"platform_stone"
const LEDGE_STONE := &"ledge_stone"

# Tag constants for fallback resolution
const TAG_FLOOR := &"floor"
const TAG_WALL := &"wall"
const TAG_DOOR := &"door"
const TAG_STAIRS := &"stairs"
const TAG_PILLAR := &"pillar"
const TAG_CEILING := &"ceiling"
const TAG_PROP := &"prop"
const TAG_BRIDGE := &"bridge"
