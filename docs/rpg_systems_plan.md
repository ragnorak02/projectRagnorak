# RPG Systems Plan — Project Ragnorak

## Inventory System (Phase 9)

### Data Model
- **ItemData** (Resource base): item_id, display_name, description, category, rarity, icon, gold_value, stackable, max_stack
- **ConsumableData** (extends ItemData): effect_type, heal_amount, mp_amount, buff_duration, target_mode (SELF, ALLY)
- **EquipmentData** (extends ItemData): slot_type, stat_modifiers, mesh_override, required_level
- **KeyItemData** (extends ItemData): quest_id, is_permanent

### Runtime Instances
Two-layer architecture:
- **Definition layer**: `.tres` Resource files (read-only templates)
- **Instance layer**: Dictionaries with `{template_id, uid, quantity, equipped_slot}`
- Save files serialize only the instance layer
- On load, instances look up templates from ItemDatabase

### Categories
1. Consumables — stackable, usable on allies only
2. Equipment — 10 slots, stat modifiers, visual changes
3. Key Items — quest-related, non-consumable

## Equipment System (Phase 9)

### 10 Slots
| Slot | Visual Type | Implementation Tier |
|------|------------|-------------------|
| Right Hand | Mesh attachment | Tier 1 (early) |
| Left Hand | Mesh attachment | Tier 1 (early) |
| Head | Mesh attachment | Tier 2 |
| Cape | Mesh attachment + cloth sim | Tier 3 (late) |
| Chest | Material/texture swap | Tier 2 |
| Pants | Material/texture swap | Tier 3 |
| Shoes | Material/texture swap | Tier 3 |
| Gloves | Material/texture swap | Tier 3 |
| Accessory 1 | No visual (stats only) | Tier 1 |
| Accessory 2 | No visual (stats only) | Tier 1 |

### Stat Modification
- StatsComponent aggregates base stats + all equipment modifiers
- `equipment_modifiers: Dictionary` keyed by slot name
- Stats recalculated on equip/unequip
- Signals: `equipment_changed(slot, old_item, new_item)`

### Visual Implementation (Tiered)
- Tier 1: Weapons (Right/Left Hand) + Accessories (stats only)
- Tier 2: Head + Chest (BoneAttachment3D on Skeleton3D)
- Tier 3: Full body (material swaps, Cape cloth sim)
- Requires rigged character model with named bone attachment points

## Quest System (Phase 10)

### Data Model
- **QuestData** (Resource): quest_id, title, description, quest_type, objectives[], prerequisite_quests[], rewards
- **QuestObjective**: objective_id, description, target_id, target_count, marker_position
- **QuestInstance** (runtime): wraps QuestData + current_objective_index, progress, status

### Quest Types
1. Story — main progression, sequential
2. Side — optional, various rewards
3. Exploration — discovery-driven, traversal-gated

### Quest Manager (Autoload)
- Tracks: available, active, completed quests
- Listens to Events for objective updates
- Manages map marker hooks
- Serializable for save/load

## Save System (Phase 11)

### Slot Structure
- Slot -1: Autosave
- Slot 0: Quicksave
- Slots 1-3: Manual saves

### Serialization Schema
```json
{
  "version": 1,
  "timestamp": "ISO8601",
  "player": {
    "position": {"x": 0, "y": 0, "z": 0},
    "rotation_y": 0,
    "hp": 100, "mp": 50, "atb": 0
  },
  "zone_id": "starting_town",
  "inventory": [...],
  "equipment": {...},
  "quests": {...},
  "party": [...],
  "team_meter": 0,
  "progression_flags": {...},
  "play_time": 0
}
```

### Rules
- Quicksave blocked during combat (GameState != PLAYING)
- Enemy states NOT saved (reset per zone on load)
- Autosave triggers: zone transition, rest point, quest completion
- Resume exact player position or nearest checkpoint

## Party System (Phase 13)

### Architecture Decision: Build Player as PartyMember[0]
The player character must be designed from Phase 1 as the first entry in a party roster, not as a unique singleton. This prevents Phase 13 from being a rewrite.

### Key Abstractions Needed Early
- `CharacterBase` — shared base for player and companion CharacterBody3D
- `InputProvider` — swappable component: human input vs AI input
- `StatsComponent` — already character-agnostic
- `EquipmentManager` — per-character, not global

### Party Features (Phase 13)
- Second party member with AI companion logic
- Character switching in and out of battle
- Shared team attack meter (fills from combat actions)
- Team attack abilities (consume meter)
- Party members grant traversal abilities
- Inactive members AI-controlled (utility AI)
- Downed state + revival mechanics

### AI Companion Design
Utility AI over behavior trees:
- Each action scored: attack nearest, heal player, follow, use team attack, revive
- Highest-utility action selected every 0.2-0.5s
- Simpler to tune than behavior trees, more emergent behavior

## Scope Risk Assessment

### HIGHEST RISK: Equipment Visuals
10 slots with visible mesh changes requires:
- Rigged Skeleton3D with named bones
- BoneAttachment3D per visible slot
- Meshes authored to fit skeleton proportions
- Cape needs cloth physics (no built-in Godot cloth sim)
- Must work for EVERY party member
**Mitigation**: Implement in tiers, start with weapons only.

### HIGH RISK: Save System Serialization
Every system must expose serialize()/deserialize() from day one.
Adding save support retroactively is extremely costly.
**Mitigation**: Define the interface contract before building any system. Player already has get_save_data()/load_save_data().

### HIGH RISK: Party System Retrofit
If Phase 1 builds a monolithic Player, Phase 13 becomes a rewrite.
**Mitigation**: Player built as CharacterBase from start. Input routing decoupled from character node.

### MEDIUM RISK: Traversal Gating
Metroidvania-style ability gates require careful world design coordination.
**Mitigation**: Build TraversalAbilityRegistry early, wire into state machine transitions.
