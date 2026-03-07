# World Design Plan — Project Ragnorak

## World Structure
Semi-open connected zones. Not fully open-world — discrete zones connected by portals/transitions.

## Core Game Loop
Town hub -> Explore zones -> Fight enemies -> Obtain gear -> Complete quests -> Unlock traversal -> Access new areas -> Repeat

## Zone Transition Tiers

### Tier 1 — Seamless (within a region)
- Adjacent small zones loaded simultaneously
- Visibility/physics toggled via Area3D boundaries
- No loading screen, no fade
- Use for: town districts, small connected areas

### Tier 2 — Quick Fade (between zones)
- 0.3-0.5s fade-to-black overlay
- Zone scene swapped as child of ZoneContainer
- ResourceLoader.load_threaded_request() during fade
- Use for: town to wilderness, dungeon rooms

### Tier 3 — Full Loading Screen (major regions)
- Full loading screen with progress bar
- Complete scene rebuild
- Use for: overworld to dungeon complex, fast travel

## Scene Management Architecture

### Hybrid Approach
- Persistent `GameWorld` shell: player, camera, HUD, environment
- Zone scenes loaded as children of `ZoneContainer: Node3D`
- Player node survives zone transitions (no re-instantiation)
- For Tier 3: serialize player state to autoload, full rebuild, restore

### WorldManager Autoload (future)
- `current_zone_id: StringName`
- `previous_zone_id: StringName`
- `zone_states: Dictionary` — per-zone persistence
- `unlocked_traversals: Array[StringName]`
- `discovered_zones: Array[StringName]`

### ZoneBase Class (future)
- `zone_id: StringName` — unique identifier
- `zone_type: ZoneType` (TOWN, WILDERNESS, DUNGEON, HIDDEN)
- `spawn_points: Array[Marker3D]`
- `portals: Array[ZonePortal]`
- `_on_zone_entered()` / `_on_zone_exiting()`

### ZonePortal Component (future)
```
ZonePortal extends Area3D:
  target_zone_id: StringName
  target_spawn_id: StringName
  transition_type: TransitionType
  required_traversal: StringName
  auto_trigger: bool
```

## Town Hub Requirements
1. Weapon/Armor Shop — buy/sell equipment
2. Inn/Rest Point — heal, save, manage party
3. Quest Board — accept/review quests
4. Traversal Trainer — unlock abilities
5. Zone Exits — portals to wilderness/dungeons

## Dungeon Design Patterns

### Room Types
- **Combat Arena**: Open space, doors lock on entry, enemies spawn, doors unlock on clear
- **Corridor/Gauntlet**: Linear, enemies along path, no door locking
- **Puzzle Room**: Minimal combat, switches/plates/blocks
- **Boss Room**: Large arena, sealed entry, unique geometry
- **Treasure Room**: Small, hidden, reward chests

### Dungeon State Persistence
- Track killed enemies, opened chests, puzzle states, unlocked doors
- State persists within a "run" (retreat and return = same state)
- Full reset on zone reload or new game

## Traversal Abilities
| Ability | Source | World Gate |
|---------|--------|-----------|
| Jump | Base | Low ledges |
| Ledge Grab | Base | Medium ledges |
| Climb | Base (refined) | Marked surfaces |
| Double Jump | Party member | High gaps |
| Wall Break | Party member | Breakable walls |
| (Future) | Items/Story | Various |

## Missing Specifications (Need Design Decisions)
1. **Zone connectivity map** — which zones connect to which, traversal requirements
2. **Dungeon count and themes** — how many, what environments
3. **Puzzle vocabulary** — 3-5 puzzle archetypes and rules
4. **Death/respawn rules** — where does the player respawn? penalties?
5. **Fast travel system** — waypoints? unlock conditions?
6. **Difficulty scaling** — fixed zone difficulty or level scaling?
7. **NPC placement** — which NPCs where, shop inventories

## Scalability Considerations
- Per-zone NavigationRegion3D (not one global navmesh)
- MultiMeshInstance3D for repeated geometry
- Entity pooling over queue_free/new cycles
- VisibilityRange (LOD) on significant 3D objects
- OccluderInstance3D in dungeons
- Max active entity count per zone
- Predictive loading of adjacent zones
- Zone-local signals for internal communication
