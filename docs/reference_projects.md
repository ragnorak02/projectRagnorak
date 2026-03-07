# Reference Projects — Patterns to Reuse

Projects in Z:\Development\lumina\ that inform Project Ragnorak's architecture.

## finalfantasy3d (Primary Reference)
**Path**: Z:\Development\lumina\finalfantasy3d\
**Type**: Korean Fantasy Isometric ARPG (Godot 4.6)
**Status**: Phase 1 complete — 61 scripts, 36 scenes, 15 player states

### Key Files to Study
| File | What to Learn |
|------|--------------|
| `src/player/states/state_machine.gd` | State machine pattern (node-based, flat) |
| `src/player/states/state.gd` | State base class interface |
| `src/autoloads/events.gd` | Signal bus pattern (45+ signals) |
| `src/autoloads/game_manager.gd` | Game state enum, time_scale, hit_stop |
| `src/player/player.gd` | Component-based player controller |
| `src/player/player.tscn` | Scene tree hierarchy |
| `src/camera/camera_rig.gd` | Camera with orbit, lock-on, SpringArm |
| `src/player/components/combat_component.gd` | Combo chain data, input buffering |
| `src/player/components/lock_on_component.gd` | Target acquisition, switching |
| `src/player/player_model_builder.gd` | Procedural model + real model dual path |
| `resources/ability_data.gd` | AbilityData resource pattern |
| `resources/player_stats_data.gd` | Stats resource pattern |
| `src/ui/tactical/tactical_menu.gd` | Tactical menu with ability cards |
| `game.config.json` | LUMINA dashboard integration format |

### Architectural Differences from Ragnorak
| Aspect | finalfantasy3d | Ragnorak |
|--------|---------------|---------|
| Camera | Isometric orthographic, 90deg snaps | Perspective third-person, free orbit |
| Dodge | Has i-frames | NO i-frames (positional only) |
| Ability cancel | Dodge cancels spells | Spells committed (no cancel) |
| ATB | Not implemented | Required from Phase 6 |
| Tactical access | Idle/LockOnIdle only | Free to open from most states |
| Time scale | Direct assignment | Priority stack |

### Known Issues in finalfantasy3d to Avoid
- Hit stop + tactical mode can corrupt each other (no stack) — FIXED in Ragnorak
- Dodge has i-frames contradicting design doc — FIXED in Ragnorak
- AbilityState allows dodge cancel — FIXED in Ragnorak
- Tactical mode only opens from 2 states — FIXED in Ragnorak (more states)

## diablo (Secondary Reference)
**Path**: Z:\Development\lumina\diablo\
**Type**: Extraction RPG (Godot 4.6)
**Status**: 41 scripts, 78 tests

### Key Files to Study
| File | What to Learn |
|------|--------------|
| `scripts/autoload/item_database.gd` | Dictionary-based item registry |
| `scripts/autoload/game_manager.gd` | player_data Dictionary persistence |
| `scripts/ui/inventory_screen.gd` | Inventory UI pattern |
| `scripts/dungeon/dungeon_generator.gd` | Room-based level construction, MultiMeshInstance3D batching |
| `scripts/environment/interaction_zone.gd` | Area-based interaction trigger |
| `scripts/town/town.gd` | Town hub with shops and portals |
| `scripts/dungeon/floor_manager.gd` | Multi-floor dungeon management |

### Patterns to Adopt
- Dictionary-based runtime item instances (not Resource instances)
- InteractionZone component for world triggers
- Town-to-dungeon scene transition flow

## dungeonCrawler (Tertiary Reference)
**Path**: Z:\Development\lumina\dungeonCrawler\
**Type**: Dungeon crawler

### Key Files
| File | What to Learn |
|------|--------------|
| `scripts/autoload/dungeon_manager.gd` | Zone state persistence (floor_memory, seed tracking) |

## lastFantasy (Tertiary Reference)
**Path**: Z:\Development\lumina\lastFantasy\
**Type**: Turn-based RPG

### Key Files
| File | What to Learn |
|------|--------------|
| `src/autoloads/game_manager.gd` | has_save_data() checking user://save_data.json |
| `src/battle/party_member.gd` | PartyMember wrapping CharacterData Resource |

## LUMINA Studio Templates
| File | Purpose |
|------|---------|
| `Z:\Development\lumina\CLAUDE_TEMPLATE.md` | Standard CLAUDE.md template with placeholders |
| `Z:\Development\lumina\docs\portfolio_schema.md` | project_status.json schema (v1) |

## Godot-Specific Implementation Notes

### Process Order
Godot processes `_physics_process` in scene tree order. With components as children of the player:
- StateMachine processes after Player (child processes after parent)
- Set `process_priority` if specific order is needed between siblings
- Recommended: Input -> Targeting -> Locomotion -> Combat -> Camera

### SpringArm3D Pitfalls
- SpringArm only checks along its local -Z axis
- Margin property (default 0.01) should be 0.1-0.2 to prevent near-clip issues
- Does not handle lateral camera-target obstruction (player behind pillar)
- For edge cases, supplement with raycasts from camera to player

### AnimationTree Strategy (Future)
When real animations arrive:
1. StateMachinePlayback as root tree node
2. Blend transitions between attack states (0.05s cross-fade)
3. BlendSpace1D for directional dodge animations
4. OneShot node for ability casts overlaid on movement
5. Root motion extraction via AnimationTree for natural attack displacement

### Resource Serialization Pitfalls
- Resources loaded from disk are SHARED by default
- Must `duplicate()` resources for runtime instances
- Circular references cause serialization loops
- Solution: two-layer architecture (templates read-only, instances are Dictionaries)
