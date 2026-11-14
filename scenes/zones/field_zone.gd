## Field Zone — sprawling outdoor area between Millhaven and the northern shrine.
## ~200m x 180m with roads, ruins, camps, farmland, and enemy patrols.
##
## Layout (Z runs south→north, X runs west→east):
##
##                        NORTH (Z = -100)
##                           |
##          [Watchtower Ruin]   [Shrine Entrance]
##               (enemies)    |     (dungeon portal)
##                     [Bridge Ruin]
##                       (chest)
##     [Hidden       [Crossroads]     [Patrol Camp]
##      Alcove]     (waypost shelter)   (enemies)
##       (secret)        |
##          [Old Outpost]    [Merchant Camp]
##            (enemies)       (NPC, wagon)
##                     |
##     [West Fields]  [Main Road]  [East Farmstead]
##      (fences)       |           (barn, chest)
##                     |        [Hilltop Overlook]
##           [South Gate — from Town]  (discovery)
##                        SOUTH (Z = 10)
##
extends "res://src/world/zone_base.gd"

const EnemyScene := preload("res://src/enemies/enemy.tscn")
## v5 placeholder enemy models (un-rigged Hunyuan meshes, RiglessVisual).
## Spawns alternate between them; names match the model.
const ENEMY_MODELS := [
	["Kobold", preload("res://assets/models/characters/kobold_female1.glb")],
	["Kobold Queen", preload("res://assets/models/characters/kobold_queen1.glb")],
	["Goblin", preload("res://assets/models/characters/goblin_male2.glb")],  # v6 JJ-4: goblinMale2 run-002
]
var _enemy_spawn_count: int = 0
const NpcInteractable := preload("res://src/interaction/npc_interactable.gd")
const ChestInteractable := preload("res://src/interaction/chest_interactable.gd")
const ZonePortal := preload("res://src/interaction/zone_portal.gd")
const HiddenArea := preload("res://src/interaction/hidden_area.gd")
const CarryableCrateScene := preload("res://src/interaction/carryable_crate.tscn")



func _ready() -> void:
	zone_id = "field_zone"
	spawn_position = Vector3(0, 1, 8)
	super._ready()


func _setup_zone() -> void:
	_build_terrain()
	_build_roads()
	_build_south_farmland()
	_build_old_outpost()
	_build_crossroads()
	_build_merchant_camp()
	_build_patrol_camp()
	_build_bridge_ruin()
	_build_watchtower_ruin()
	_build_shrine_approach()
	_build_hilltop_overlook()
	_build_hidden_alcove()
	_build_field_boundaries()
	_place_enemies()
	_place_chests()
	_place_carryables()
	_place_hidden_areas()
	_place_npcs()
	_place_portals()


# ══════════════════════════════════════════════════════════════════════════════
# TERRAIN
# ══════════════════════════════════════════════════════════════════════════════

func _build_terrain() -> void:
	# Large rolling grass field
	TownBuilder.add_ground_plane(self, 250.0, Color(0.28, 0.38, 0.18))

	# Boundary walls
	TownBuilder.add_invisible_wall(self, Vector3(0, 3, -110), Vector3(250, 8, 1))   # north
	TownBuilder.add_invisible_wall(self, Vector3(0, 3, 18), Vector3(250, 8, 1))     # south
	TownBuilder.add_invisible_wall(self, Vector3(-80, 3, -50), Vector3(1, 8, 260))  # west
	TownBuilder.add_invisible_wall(self, Vector3(80, 3, -50), Vector3(1, 8, 260))   # east


# ══════════════════════════════════════════════════════════════════════════════
# ROADS & PATHS
# ══════════════════════════════════════════════════════════════════════════════

func _build_roads() -> void:
	# ── Main north-south road (Z=10 down to Z=-100) ──
	TownBuilder.lay_road(self, Vector3(0, 0.01, 10), 56, 3, Vector3.BACK, "Floor_Brick")

	# ── East-west crossroads at Z=-45 ──
	TownBuilder.lay_road(self, Vector3(-40, 0.01, -45), 40, 2, Vector3.RIGHT, "Floor_Brick")

	# ── Path to farmstead (east, Z~0) ──
	TownBuilder.lay_road(self, Vector3(4, 0.01, -2), 15, 2, Vector3.RIGHT, "Floor_UnevenBrick")

	# ── Path to old outpost (west, Z~-30) ──
	TownBuilder.lay_road(self, Vector3(-4, 0.01, -30), 12, 2, Vector3.LEFT, "Floor_UnevenBrick")

	# ── Path to shrine (widens near entrance) ──
	TownBuilder.lay_square(self, Vector3(0, 0.01, -98), 5, 3, "Floor_RedBrick")

	# ── Crossroads plaza ──
	TownBuilder.lay_square(self, Vector3(0, 0.01, -45), 5, 4, "Floor_UnevenBrick")


# ══════════════════════════════════════════════════════════════════════════════
# SOUTH — FARMLAND (southeast quadrant)
# ══════════════════════════════════════════════════════════════════════════════

func _build_south_farmland() -> void:
	# ── Farmstead barn (intact small building) ──
	TownBuilder.build_house(self, Vector3(28, 0, -6), 3, 2, 0.0, 3, 0, "plaster", false, false)

	# ── Farmstead storage shed ──
	TownBuilder.build_house(self, Vector3(40, 0, -2), 2, 2, 15.0, 0, 0, "brick", false, false)

	# ── Field fences (livestock pens) ──
	# Northern pen border
	TownBuilder.place_fence_line(self, Vector3(24, 0, -12), 10, Vector3.RIGHT)
	# Southern pen border
	TownBuilder.place_fence_line(self, Vector3(24, 0, 4), 10, Vector3.RIGHT)
	# West pen side
	TownBuilder.place_fence_line(self, Vector3(24, 0, 4), 8, Vector3.BACK)
	# East pen side (partial — gap for entry)
	TownBuilder.place_fence_line(self, Vector3(44, 0, -8), 4, Vector3.BACK)

	# ── Haystacks / crates around barn ──
	TownBuilder.place(self, "Prop_Crate", Vector3(26, 0, -3), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(26.5, 0, -4.5), 30, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(27.2, 1.06, -3.5), 0.0, true)
	TownBuilder.place(self, "Prop_Wagon", Vector3(35, 0, 1), -10, true)

	# ── Low stone walls bordering fields ──
	TownBuilder.build_wall_line(self, Vector3(20, 0, 6), 5, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(50, 0, -14), 3, 90.0, "brick")


# ══════════════════════════════════════════════════════════════════════════════
# WEST — OLD MILITARY OUTPOST (ruins)
# ══════════════════════════════════════════════════════════════════════════════

func _build_old_outpost() -> void:
	# ── Main outpost ruin — L-shaped from two overlapping ruins ──
	# Front building (3 walls standing, open on east side)
	TownBuilder.build_ruin(self, Vector3(-35, 0, -34), 3, 2, 0.0, 0b1101)

	# Back storage (2 walls, rubble)
	TownBuilder.build_ruin(self, Vector3(-35, 0, -26), 2, 2, 0.0, 0b1010)

	# ── Archway at outpost entrance ──
	TownBuilder.build_archway(self, Vector3(-27, 0, -30))

	# ── Outpost perimeter wall fragments ──
	TownBuilder.build_wall_line(self, Vector3(-44, 0, -36), 4, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-44, 0, -36), 3, 90.0, "brick")

	# ── Scattered military debris ──
	TownBuilder.scatter_bricks(self, Vector3(-33, 0, -30), 5.0, 8)
	TownBuilder.place(self, "Prop_Crate", Vector3(-30, 0, -32), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-31, 0, -28), 45, true)

	# ── Vines overgrowing the ruins ──
	TownBuilder.add_vines(self, [
		Vector3(-34, 1.5, -34),
		Vector3(-36, 2.0, -30),
		Vector3(-35, 1.0, -26),
	])


# ══════════════════════════════════════════════════════════════════════════════
# CENTER — CROSSROADS WAYPOST
# ══════════════════════════════════════════════════════════════════════════════

func _build_crossroads() -> void:
	# ── Waypost shelter (lean-to with roof) ──
	TownBuilder.build_lean_to(self, Vector3(5, 0, -44))

	# ── Signpost crates / travel supplies ──
	# (liftable crate placed in _place_carryables)
	TownBuilder.place(self, "Prop_Wagon", Vector3(-6, 0, -48), 15, true)

	# ── Border stones marking the crossroads ──
	TownBuilder.place(self, "Prop_ExteriorBorder_Straight1", Vector3(-8, 0, -43))
	TownBuilder.place(self, "Prop_ExteriorBorder_Straight2", Vector3(8, 0, -43))
	TownBuilder.place(self, "Prop_ExteriorBorder_Corner", Vector3(-8, 0, -47))
	TownBuilder.place(self, "Prop_ExteriorBorder_Corner", Vector3(8, 0, -47))

	# ── Metal fence markers ──
	TownBuilder.place(self, "Prop_MetalFence_Simple", Vector3(-4, 0, -42))
	TownBuilder.place(self, "Prop_MetalFence_Simple", Vector3(4, 0, -48))


# ══════════════════════════════════════════════════════════════════════════════
# EAST — MERCHANT CAMP
# ══════════════════════════════════════════════════════════════════════════════

func _build_merchant_camp() -> void:
	# ── Merchant's lean-to shelter ──
	TownBuilder.build_lean_to(self, Vector3(38, 0, -42), 20)

	# ── Merchant wagon (larger, prominent) ──
	TownBuilder.place(self, "Prop_Wagon", Vector3(42, 0, -38), -30, true)

	# ── Stacked trade goods ──
	TownBuilder.place(self, "Prop_Crate", Vector3(36, 0, -40), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(37, 0, -41), 20, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(36.5, 1.06, -40.5), 45, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(44, 0, -40), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(44, 0, -42), 60, true)

	# ── Camp fencing ──
	TownBuilder.place_fence_line(self, Vector3(34, 0, -36), 6, Vector3.RIGHT)
	TownBuilder.place_fence_line(self, Vector3(34, 0, -46), 6, Vector3.RIGHT)


# ══════════════════════════════════════════════════════════════════════════════
# NORTHEAST — ENEMY PATROL CAMP
# ══════════════════════════════════════════════════════════════════════════════

func _build_patrol_camp() -> void:
	# ── Guard post structure (small brick, open front) ──
	TownBuilder.build_ruin(self, Vector3(30, 0, -68), 2, 2, 0.0, 0b1110)

	# ── Perimeter fences ──
	TownBuilder.place_fence_line(self, Vector3(26, 0, -64), 6, Vector3.RIGHT)
	TownBuilder.place_fence_line(self, Vector3(26, 0, -74), 6, Vector3.RIGHT)
	TownBuilder.place_fence_line(self, Vector3(26, 0, -74), 5, Vector3.BACK)

	# ── Patrol supplies ──
	TownBuilder.place(self, "Prop_Crate", Vector3(33, 0, -70), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(35, 0, -66), 15, true)
	TownBuilder.place(self, "Prop_Wagon", Vector3(28, 0, -72), 40, true)

	# ── Metal fences (military style) ──
	TownBuilder.place(self, "Prop_MetalFence_Ornament", Vector3(38, 0, -68))
	TownBuilder.place(self, "Prop_MetalFence_Simple", Vector3(38, 0, -72))


# ══════════════════════════════════════════════════════════════════════════════
# NORTHWEST — BRIDGE RUIN
# ══════════════════════════════════════════════════════════════════════════════

func _build_bridge_ruin() -> void:
	# ── Two archways forming broken bridge supports ──
	TownBuilder.build_archway(self, Vector3(-20, 0, -65), 0)
	TownBuilder.build_archway(self, Vector3(-20, 0, -72), 0)

	# ── Connecting wall fragments (bridge remains) ──
	TownBuilder.build_wall_line(self, Vector3(-24, 0, -65), 2, 90.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-16, 0, -65), 2, 90.0, "brick")

	# ── Rubble between arches ──
	TownBuilder.scatter_bricks(self, Vector3(-20, 0, -68), 4.0, 10)

	# ── Crumbled floor remnants ──
	TownBuilder.place(self, "Floor_UnevenBrick", Vector3(-20, 0.3, -67))
	TownBuilder.place(self, "Floor_UnevenBrick", Vector3(-20, 0.2, -69))
	TownBuilder.place(self, "Floor_UnevenBrick", Vector3(-18, 0.15, -68))

	# ── Vines reclaiming the bridge ──
	TownBuilder.add_vines(self, [
		Vector3(-19, 1.5, -66),
		Vector3(-21, 2.0, -72),
		Vector3(-20, 0.5, -69),
	])


# ══════════════════════════════════════════════════════════════════════════════
# FAR NORTH — WATCHTOWER RUIN (enemy stronghold)
# ══════════════════════════════════════════════════════════════════════════════

func _build_watchtower_ruin() -> void:
	# ── Tower base (partially collapsed) ──
	TownBuilder.build_ruin(self, Vector3(-40, 0, -85), 2, 2, 0.0, 0b1111)

	# ── Remnant tower roof on top of ruin (tilted/collapsed feel) ──
	TownBuilder.place(self, "Roof_Tower_RoundTiles", Vector3(-38, 3.0, -83))

	# ── Adjacent wall remains ──
	TownBuilder.build_wall_line(self, Vector3(-48, 0, -88), 3, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-48, 0, -88), 4, 90.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-34, 0, -82), 2, 0.0, "brick")

	# ── Heavy rubble ──
	TownBuilder.scatter_bricks(self, Vector3(-40, 0, -86), 6.0, 12)
	TownBuilder.scatter_bricks(self, Vector3(-46, 0, -88), 3.0, 6)

	# ── Military supplies (enemy camp) ──
	TownBuilder.place(self, "Prop_Crate", Vector3(-37, 0, -84), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-38, 0, -86), 25, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-42, 0, -83), 0.0, true)
	TownBuilder.place(self, "Prop_Wagon", Vector3(-45, 0, -82), -20, true)

	# ── Overgrown vines ──
	TownBuilder.add_vines(self, [
		Vector3(-39, 1.5, -85),
		Vector3(-41, 2.5, -87),
		Vector3(-48, 1.0, -88),
		Vector3(-40, 0.5, -83),
	])


# ══════════════════════════════════════════════════════════════════════════════
# NORTH CENTER — SHRINE APPROACH
# ══════════════════════════════════════════════════════════════════════════════

func _build_shrine_approach() -> void:
	# ── Ceremonial archway before shrine ──
	TownBuilder.build_archway(self, Vector3(0, 0, -90), 0)

	# ── Flanking wall fragments (ancient stonework) ──
	TownBuilder.build_wall_line(self, Vector3(-8, 0, -95), 3, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(4, 0, -95), 3, 0.0, "brick")

	# ── Stone border leading to shrine ──
	for i in 5:
		var z := -80.0 - float(i) * 4.0
		TownBuilder.place(self, "Prop_ExteriorBorder_Straight1", Vector3(-5, 0, z))
		TownBuilder.place(self, "Prop_ExteriorBorder_Straight2", Vector3(5, 0, z))

	# ── Scattered ancient rubble ──
	TownBuilder.scatter_bricks(self, Vector3(-3, 0, -92), 3.0, 5)
	TownBuilder.scatter_bricks(self, Vector3(3, 0, -94), 2.0, 4)

	# ── Vines on shrine walls ──
	TownBuilder.add_vines(self, [
		Vector3(-7, 1.5, -95),
		Vector3(5, 2.0, -96),
	])


# ══════════════════════════════════════════════════════════════════════════════
# FAR EAST — HILLTOP OVERLOOK (elevated platform)
# ══════════════════════════════════════════════════════════════════════════════

func _build_hilltop_overlook() -> void:
	# ── Elevated stone platform ──
	TownBuilder.build_elevated_platform(self, Vector3(52, 0, -15), 3, 3, 1.0)

	# ── Low boundary walls on the platform edge ──
	TownBuilder.place_fence_line(self, Vector3(54, 1.0, -14), 3, Vector3.RIGHT)

	# ── Scenic props ──
	TownBuilder.place(self, "Prop_Crate", Vector3(56, 1.0, -12), 0.0, true)
	TownBuilder.place(self, "Prop_ExteriorBorder_Corner", Vector3(52, 1.0, -20))


# ══════════════════════════════════════════════════════════════════════════════
# FAR WEST — HIDDEN ALCOVE (behind ruins)
# ══════════════════════════════════════════════════════════════════════════════

func _build_hidden_alcove() -> void:
	# ── Concealing ruin walls forming a pocket ──
	# Three walls creating an L-shaped enclosure
	TownBuilder.build_wall_line(self, Vector3(-62, 0, -50), 4, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-62, 0, -50), 3, 90.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-54, 0, -56), 3, 90.0, "brick")

	# ── Rubble and overgrowth ──
	TownBuilder.scatter_bricks(self, Vector3(-58, 0, -53), 3.0, 6)
	TownBuilder.add_vines(self, [
		Vector3(-61, 1.5, -51),
		Vector3(-63, 2.0, -53),
	])


# ══════════════════════════════════════════════════════════════════════════════
# FIELD BOUNDARIES & SCATTERED FEATURES
# ══════════════════════════════════════════════════════════════════════════════

func _build_field_boundaries() -> void:
	# ── South entry — fences flanking the road from town ──
	TownBuilder.place_fence_line(self, Vector3(5, 0, 8), 4, Vector3.BACK)
	TownBuilder.place_fence_line(self, Vector3(-5, 0, 8), 4, Vector3.BACK)

	# ── West field boundary walls (old farm borders) ──
	TownBuilder.build_wall_line(self, Vector3(-25, 0, -10), 6, 0.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-25, 0, -10), 5, 90.0, "brick")

	# ── Scattered fence lines across the fields ──
	TownBuilder.place_fence_line(self, Vector3(-15, 0, 2), 5, Vector3.RIGHT)
	TownBuilder.place_fence_line(self, Vector3(15, 0, -20), 6, Vector3.BACK)
	TownBuilder.place_fence_line(self, Vector3(-20, 0, -55), 5, Vector3.RIGHT)

	# ── Lone wagons along routes ──
	TownBuilder.place(self, "Prop_Wagon", Vector3(-12, 0, -15), 5, true)
	TownBuilder.place(self, "Prop_Wagon", Vector3(18, 0, -55), -25, true)

	# ── Scattered crate clusters (abandoned supply drops) ──
	# (liftable crate placed in _place_carryables)
	TownBuilder.place(self, "Prop_Crate", Vector3(13, 0, -26), 30, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-18, 0, -70), 0.0, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-17, 0, -71), 50, true)
	TownBuilder.place(self, "Prop_Crate", Vector3(-17.5, 1.06, -70.5), 0.0, true)

	# ── Stone borders along main road at intervals ──
	for i in 8:
		var z := 0.0 - float(i) * 12.0
		TownBuilder.place(self, "Prop_ExteriorBorder_Straight1", Vector3(-5, 0, z))
		TownBuilder.place(self, "Prop_ExteriorBorder_Straight2", Vector3(5, 0, z))

	# ── Ruined wall fragments dotted across the landscape ──
	TownBuilder.build_wall_line(self, Vector3(20, 0, -35), 2, 30.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(-10, 0, -78), 3, -15.0, "brick")
	TownBuilder.build_wall_line(self, Vector3(50, 0, -55), 2, 45.0, "brick")

	# ── Metal fences near military areas ──
	TownBuilder.place(self, "Prop_MetalFence_Ornament", Vector3(-26, 0, -30))
	TownBuilder.place(self, "Prop_MetalFence_Simple", Vector3(-28, 0, -30))


# ══════════════════════════════════════════════════════════════════════════════
# ENEMIES (8 total, spread across the zone)
# ══════════════════════════════════════════════════════════════════════════════

func _place_enemies() -> void:
	# South patrol (near farmland)
	_add_enemy(Vector3(15, 0, -5))
	_add_enemy(Vector3(22, 0, -10))

	# Old outpost guards (west)
	_add_enemy(Vector3(-30, 0, -28))
	_add_enemy(Vector3(-38, 0, -32))

	# Patrol camp (northeast)
	_add_enemy(Vector3(32, 0, -66))
	_add_enemy(Vector3(36, 0, -70))

	# Bridge ruin lurker
	_add_enemy(Vector3(-18, 0, -68))

	# Watchtower ruin elite (tougher position)
	_add_enemy(Vector3(-42, 0, -84))


# ══════════════════════════════════════════════════════════════════════════════
# CHESTS
# ══════════════════════════════════════════════════════════════════════════════

func _place_carryables() -> void:
	# Near spawn, for testing carry/throw
	_add_carryable_crate(Vector3(2, 0, 4))
	# Signpost supply crate at the crossroads
	_add_carryable_crate(Vector3(3, 0, -42))
	# Supply-drop cluster near the first enemies
	_add_carryable_crate(Vector3(12, 0, -25))


func _place_chests() -> void:
	# Farmstead barn chest
	_add_chest(Vector3(32, 0, -4), "chest_field_barn")

	# Hidden alcove chest (behind ruin walls)
	_add_chest(Vector3(-58, 0, -53), "chest_field_alcove")

	# Watchtower supply chest
	_add_chest(Vector3(-43, 0, -85), "chest_field_watchtower")

	# Bridge ruin chest (in the rubble)
	_add_chest(Vector3(-20, 0, -68), "chest_field_bridge")


# ══════════════════════════════════════════════════════════════════════════════
# HIDDEN AREAS / DISCOVERIES
# ══════════════════════════════════════════════════════════════════════════════

func _place_hidden_areas() -> void:
	# Hilltop overlook
	_add_hidden_area("field_overlook", Vector3(56, 1.0, -16),
		"Discovered: Hilltop Overlook — the whole valley stretches before you.")

	# Behind the bridge ruin
	_add_hidden_area("field_bridge_hollow", Vector3(-22, 0, -70),
		"Discovered: Bridge Hollow — something was buried here long ago.")

	# Watchtower cellar entrance
	_add_hidden_area("field_tower_cellar", Vector3(-40, 0, -88),
		"Discovered: Watchtower Foundation — old tunnels run beneath.")

	# Hidden alcove
	_add_hidden_area("field_alcove", Vector3(-58, 0, -52),
		"Discovered: Hidden Alcove — a forgotten cache behind crumbling walls.")


# ══════════════════════════════════════════════════════════════════════════════
# NPCs
# ══════════════════════════════════════════════════════════════════════════════

func _place_npcs() -> void:
	# Traveling merchant at camp
	_add_npc("Trader Voss", Vector3(40, 0, -43), Color(0.5, 0.4, 0.25), [
		{"speaker": "Trader Voss", "text": "Careful on the roads. Soldiers have been restless lately."},
		{"speaker": "Trader Voss", "text": "I trade in field supplies — potions, tools, rope."},
		{"speaker": "Trader Voss", "text": "The old outpost to the west? Abandoned years ago. Bandits now."},
	])

	# Farmer near farmstead
	_add_npc("Farmer Lenn", Vector3(26, 0, -8), Color(0.45, 0.35, 0.2), [
		{"speaker": "Farmer Lenn", "text": "These fields used to be peaceful. Now I hear swords clashing at night."},
		{"speaker": "Farmer Lenn", "text": "The shrine to the north... the elders say it predates the reactors."},
	])

	# Wounded soldier near crossroads
	_add_npc("Wounded Scout", Vector3(-2, 0, -43), Color(0.4, 0.35, 0.4), [
		{"speaker": "Wounded Scout", "text": "Ambushed... on the bridge road. They came from the watchtower."},
		{"speaker": "Wounded Scout", "text": "Be careful if you go northwest. There's more of them up there."},
	])


# ══════════════════════════════════════════════════════════════════════════════
# PORTALS
# ══════════════════════════════════════════════════════════════════════════════

func _place_portals() -> void:
	# South — back to Millhaven
	_add_portal("Return to Millhaven", Vector3(0, 0, 14), "town_hub", Vector3(0, 1, -48))

	# North — shrine entrance (dungeon)
	_add_portal("Shrine Entrance", Vector3(0, 0, -100), "dungeon_zone", Vector3(0, 1, 10))


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _add_enemy(pos: Vector3) -> void:
	var enemy := EnemyScene.instantiate()
	var pick: Array = ENEMY_MODELS[_enemy_spawn_count % ENEMY_MODELS.size()]
	_enemy_spawn_count += 1
	enemy.display_name = pick[0]
	enemy.rigless_model = pick[1]
	add_child(enemy)
	enemy.global_position = pos
	enemy.global_position.y = 1.0


## `model`: optional un-rigged NPC model (RiglessVisual, v6 JJ-3). `face_point`:
## where the NPC looks by default; INF = the main road (x = 0) a few metres
## toward the south approach (v6 JJ-2).
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

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 0.3)
	mesh.mesh = box
	mesh.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.3)
	mesh.material_override = mat
	portal.add_child(mesh)

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


func _add_chest(pos: Vector3, chest_flag: String = "chest_field_1") -> void:
	if SaveManager.has_flag(chest_flag):
		return
	var chest := Area3D.new()
	chest.set_script(ChestInteractable)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	col.shape = shape
	chest.add_child(col)

	# Use a crate model as chest visual
	var crate_path := "res://public/assets/medieval_village_megakitstandard/glTF/Prop_Crate.gltf"
	if ResourceLoader.exists(crate_path):
		var crate_scene: PackedScene = load(crate_path)
		var crate := crate_scene.instantiate()
		chest.add_child(crate)
	else:
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


## Liftable crate (Package H). Single, ground-level crates only.
func _add_carryable_crate(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var crate: Node3D = CarryableCrateScene.instantiate()
	add_child(crate)
	crate.global_position = pos
	crate.rotation.y = deg_to_rad(rot_y)
	return crate
