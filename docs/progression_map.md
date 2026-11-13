# Ragnorak — Progression Map

## Overview

Ragnorak progresses through **3 world states**, each defined by tone, available zones, enemy composition, and party roster. Progression uses three gate types: **story gates** (flags set by quest completion), **soft gates** (enemy difficulty), and **traversal gates** (party member abilities).

---

## Three World States

### State 1 — Early Era: "Under Calm Skies"

**Tone**: Pastoral, political, industrial. Life is normal. Conflict is military — border tensions, supply disputes, patrol duties. Magic exists but is mundane infrastructure, not mystical.

**Available Zones**:
- Hub 1: Millhaven (start)
- Greenhollow Fields
- Millhaven Shrine
- Tidewatch Road
- Tidewatch Cave (traversal-gated, accessible later)
- Ironhaven (unlocks mid-State 1)

**Enemy Composition**: Military only.
- Garrison Soldiers, Shield Guards, Military Riflemen, Patrol Drones
- No monsters, no magic enemies, no corruption
- Enemies are people — soldiers doing their jobs, security systems protecting infrastructure

**Party**: Amaro alone → Taighe joins after Millhaven Shrine.

**Element Access**: Fire, Ice, Wind, Earth (standard set).

**Key Narrative Beats**:
1. Amaro begins as a village militiaman in Millhaven
2. Patrols Greenhollow, encounters escalating military presence
3. Clears Millhaven Shrine, meets Taighe investigating Lumina anomalies
4. Receives "The Northern Warning" — reports of military buildup and reactor tensions
5. Travels Tidewatch Road to Ironhaven

**Advance Trigger**: Complete "Into the Irondeep" quest (Irondeep Mines boss defeated) → Ashveil Pass opens → State 2 begins.

**Player Level Range**: 1-8

---

### State 2 — Rising Tension: "The Iron Mandate"

**Tone**: Military escalation, supply shortages, civilian fear. Something is wrong at the reactor sites. Commands from central authority grow more aggressive. Rumors of instability. The world is still functioning but straining.

**Available Zones**: All State 1 zones + Hub 2 full spokes + Hub 3 full spokes.
- Ashveil Pass
- Irondeep Mines (if not cleared in State 1)
- Coastal Reactor Approach
- Seaward Reactor
- Ashveil Aerie (traversal-gated)
- Frostmere (hub 3)
- Glacier Shelf Route
- Shattered Coast
- Abyssal Reactor
- Glacial Vault (traversal-gated)
- Submerged Ruins (traversal-gated)

**Enemy Composition**: Elite military + prototype war machines.
- Elite Soldiers, Armored Drones, Heavy Troopers, Tactical Officers
- Reactor Sentinels in reactor zones
- Frost Troopers in northern zones
- Still no monsters or corruption — but foreshadowing events occur (Aurora Whispers quest, strange readings)

**Party**: Kael (Shield Guardian) joins at Frostmere. Sera (Wind Dancer) joins at Ashveil Aerie (sidequest, traversal-gated).

**Element Access**: Same 4 base elements. No Light/Dark.

**Key Narrative Beats**:
1. Ironhaven reveals military anxiety — reactors are behaving strangely
2. Irondeep Mines reveal that miners found something deep underground
3. Seaward Reactor shows first signs of Lumina instability
4. Kael joins at Frostmere, providing ground-level military perspective
5. Abyssal Reactor quest chain reveals the scope of the problem
6. **RAGNORAK triggers** at Abyssal Reactor core — Lumina destabilizes catastrophically

**Advance Trigger**: Enter Abyssal Reactor → Story event → Ragnorak → State 3.

**Player Level Range**: 8-18

---

### State 3 — Post-Ragnorak: "The Luminous Corruption"

**Tone**: Catastrophic. The sky is darkened. Lumina corruption spreads visibly as violet tendrils across the land. Military structure has collapsed. Monsters and spirits emerge where only soldiers existed before. The world is recognizable but transformed. Survival replaces politics.

**Available Zones**: All previous (some transformed) + Hub 4 spokes.
- Veilwatch (hub 4)
- Corruption Scar
- Fallen Ironhaven (Ironhaven transformed)
- Luminous Hollow (optional)
- Reactor Core Descent (final dungeon)
- Greenhollow Corrupted (variant of field_zone)
- Millhaven Aftermath (variant of town_hub)
- All State 1-2 zones remain accessible, some with updated enemy spawns

**Enemy Composition**: Corrupted spirits, Lumina monsters, corrupted machines.
- Corrupted Soldiers (former military), Lumina Wraiths, Crystal Stalkers
- Corruption Spewers, Hollow Beasts, Spirit Menders
- Corrupted Automatons, Void Sentinels
- Military enemies largely gone — replaced by corrupted versions

**Party**: Varn (Lumina Engineer) joins at Veilwatch. Lyra (Spirit Channeler) joins at Luminous Hollow (sidequest).

**Element Access**: Light and Dark elements unlock.
- Light unlocks after defeating Corrupted Guardian (Corruption Scar boss)
- Dark unlocks after defeating Corrupted Commander (Fallen Ironhaven boss)
- These elements are specifically effective against corruption enemies
- Their unlock feels earned — a true escalation of power to match escalated threats

**Key Narrative Beats**:
1. Wake in Veilwatch after Ragnorak — world is changed
2. Varn explains what happened: Lumina source destabilized, corruption spreading
3. Resistance forms — must find 3 Lumina Stabilizers to reach the source
4. Corruption Scar reveals the scope of damage, Light element discovered
5. Fallen Ironhaven is an emotional beat — familiar city destroyed
6. Final preparation → Reactor Core Descent → confront the source of corruption

**Advance Trigger**: Collect 3 Lumina Stabilizers → Final gate opens → Endgame.

**Player Level Range**: 18-30

---

## Gate System

### Hard Gates (Story Flags)

Story gates use `SaveManager.progression_flags` — a dictionary of boolean flags persisted in save data. Zone portals check flags via their existing `required_flag` field.

| Gate | Flag | Set By | Opens |
|------|------|--------|-------|
| Ironhaven access | `story_ironhaven_unlocked` | Complete "The Northern Warning" quest | Tidewatch Road → Ironhaven portal |
| Ashveil Pass | `story_ashveil_open` | Complete "Into the Irondeep" quest | Ironhaven → Ashveil portal |
| Frostmere access | `story_frostmere_unlocked` | Complete "The Cooling Depths" quest | Ashveil Pass → Frostmere portal |
| Abyssal Reactor entry | `story_abyssal_clearance` | Complete Frostmere quest chain ("Clearance Denied") | Frostmere → Abyssal portal |
| Post-Ragnorak world | `ragnorak_triggered` | Abyssal Reactor story event | World state 3, all State 3 zones |
| Veilwatch access | `story_veilwatch_found` | Auto-set after Ragnorak cutscene | Veilwatch hub available |
| Reactor Core Descent | `story_final_gate` | Collect 3 Lumina Stabilizers | Veilwatch → Core portal |

**Implementation**: Existing `ZonePortal` already supports `required_flag`. Portals display locked state with tooltip when flag not met. `SaveManager.set_progression_flag(flag_name)` called by quest completion handlers.

### Soft Gates (Level-Based)

No flags needed — enemies in these areas are simply tough. Players can attempt early but will likely fail.

| Location | Recommended Level | Why |
|----------|------------------|-----|
| Watchtower Ruin (Greenhollow) | 5+ | Shield Guards and loot chest — beatable early if skilled |
| Ashveil Pass north section | 12+ | Elite Soldiers and Sniper Drones |
| Shattered Coast deep section | 18+ | Reactor Sentinels and Heavy Troopers |
| Corruption Scar east | 25+ | Void Sentinels and multiple Corruption Spewers |

**Design Note**: Soft gates encourage exploration without blocking it. A skilled player who under-levels can still push through. Rewards scale with difficulty.

### Traversal Gates (Party Member Abilities)

Traversal gates use the existing `PartyMemberData.traversal_flags` system. Areas are physically inaccessible without specific movement abilities granted by party members.

| Area | Ability Required | Party Member | First Available | Reward |
|------|-----------------|--------------|-----------------|--------|
| Tidewatch Cave | `double_jump` | Kael | State 2 (joins at Frostmere) | Equipment, lore |
| Ashveil Aerie | `wall_run` + `glide` | Varn + Sera | State 3 + State 2 sidequest | **Sera** (party member) |
| Glacial Vault | `glide` | Sera | State 2 sidequest | Ancient research, ability upgrade |
| Submerged Ruins | `double_jump` + `wall_run` | Kael + Varn | State 2 + State 3 | Lore, Lumina Stabilizer |

**Design Note**: Traversal gates create backtracking incentives. When players gain new party members, previously visited zones offer new content. Tidewatch Cave is the most obvious example — visible from State 1 but unreachable until State 2.

**Ashveil Aerie paradox**: This zone requires Varn (wall_run, State 3) and Sera (glide), but Sera is the *reward* of this zone. Resolution: Ashveil Aerie has a secondary entrance that requires only wall_run to reach the approach platforms, but glide to cross the final gap to the inner sanctum where Sera is. After Sera joins, she teaches glide, and the full Aerie becomes explorable for remaining rewards.

---

## Party Member Join Order

| # | Name | Class | Joins | Zone | State | Traversal Ability | Active/Reserve |
|---|------|-------|-------|------|-------|-------------------|----------------|
| 1 | Amaro | Magic Knight | Game start | Millhaven | 1 | Base movement | Active (permanent) |
| 2 | Taighe | Elemental Mage | After Shrine quest | Millhaven | 1 | Wall Break | Active |
| 3 | Kael | Shield Guardian | Story join | Frostmere | 2 | Double Jump | Active |
| 4 | Sera | Wind Dancer | Sidequest (traversal-gated) | Ashveil Aerie | 2-3 | Glide | Active (pushes earliest to reserve) |
| 5 | Varn | Lumina Engineer | Story join | Veilwatch | 3 | Wall Run | Active (someone moves to reserve) |
| 6 | Lyra | Spirit Channeler | Sidequest | Luminous Hollow | 3 | Light/Dark element mastery | Reserve (or swap in) |

### Party Composition Notes

**3 active + 3 reserve** (per CLAUDE.md design contract).

- State 1: Amaro + Taighe (2 active, no reserve management)
- State 2 early: Amaro + Taighe + Kael (3 active, no reserves yet)
- State 2 with Sera: 4 members → first reserve decision. Player chooses active 3.
- State 3 early: 5 members → 3 active, 2 reserve.
- State 3 with Lyra: Full roster → 3 active, 3 reserve.

**Reserve management becomes meaningful at 4+ members.** This matches the expansion gating rule: party system complexity scales with player experience.

### Party Member Combat Profiles

| Name | Role | Weapon | Elements | Playstyle |
|------|------|--------|----------|-----------|
| Amaro | Magic Knight | Sword | Fire, Wind | Melee combos + magic follow-ups, balanced |
| Taighe | Elemental Mage | Staff | Fire, Ice, Wind, Earth | Ranged elemental caster, support damage |
| Kael | Shield Guardian | Tower Shield + Mace | Earth, Ice | Tank, draws aggro, counter-attacks, slow but tough |
| Sera | Wind Dancer | Dual Daggers | Wind | Fast melee, aerial combos, evasive, low HP |
| Varn | Lumina Engineer | Magitech Gauntlet | Fire, Earth | Turret placement, area denial, buff/debuff |
| Lyra | Spirit Channeler | Crystal Focus | Light, Dark | Hybrid healer/damage, spirit summon assists |

### Traversal Ability Details

| Ability | Granted By | Mechanic | Implementation |
|---------|-----------|----------|----------------|
| Wall Break | Taighe | Destroy cracked walls blocking paths | Interact prompt at tagged walls when Taighe in party |
| Double Jump | Kael | Second jump in air | Extends jump state machine, checks `has_double_jump` flag |
| Glide | Sera | Hold jump in air to glide | New locomotion state, checks `has_glide` flag |
| Wall Run | Varn | Run along tagged wall surfaces | New locomotion state, checks `has_wall_run` flag |

---

## Lumina Stabilizer Locations

Three Lumina Stabilizers are required to open the final gate. They force the player to engage with the full scope of the corrupted world.

| # | Stabilizer | Location | How Obtained |
|---|-----------|----------|--------------|
| 1 | Stabilizer Alpha | Submerged Ruins | Dungeon quest "Submerged Relic" (traversal: double_jump + wall_run) |
| 2 | Stabilizer Beta | Fallen Ironhaven | Reward from Corrupted Commander boss |
| 3 | Stabilizer Gamma | Seaward Reactor (revisit) | Return to corrupted Seaward Reactor, find in damaged containment |

**Design Note**: Stabilizer 1 requires traversal abilities (backtracking to State 2 zone). Stabilizer 2 requires a boss fight. Stabilizer 3 requires revisiting a familiar zone in its corrupted state. This mix ensures variety in the endgame preparation.

---

## Level Curve

| Level | Zone / Activity | State |
|-------|----------------|-------|
| 1-2 | Millhaven, tutorial quests | 1 |
| 3-4 | Greenhollow Fields, patrols | 1 |
| 4-5 | Millhaven Shrine | 1 |
| 5-6 | Tidewatch Road, ambush | 1 |
| 7-8 | Ironhaven, city quests | 1-2 |
| 8-10 | Irondeep Mines, boss | 2 |
| 10-12 | Ashveil Pass | 2 |
| 11-13 | Coastal Approach, Seaward Reactor | 2 |
| 13-15 | Frostmere, Glacier Shelf | 2 |
| 14-16 | Shattered Coast, sidequests | 2 |
| 16-18 | Abyssal Reactor, Ragnorak | 2 |
| 18-20 | Veilwatch, initial State 3 | 3 |
| 20-22 | Corruption Scar, Fallen Ironhaven | 3 |
| 22-25 | Stabilizer hunting, optional dungeons | 3 |
| 25-28 | Luminous Hollow, endgame prep | 3 |
| 28-30 | Reactor Core Descent, final boss | 3 |

---

## Progression Flow Diagram

```
STATE 1                          STATE 2                          STATE 3
─────────────────────────────    ─────────────────────────────    ─────────────────────────────

Millhaven                        Irondeep Mines                   Veilwatch
  │ tutorial                       │ BOSS: Grendl                   │ Varn joins
  ▼                                ▼                                ▼
Greenhollow ──► Shrine           Ashveil Pass                    Corruption Scar
  │               │ Taighe joins   │ (Sera sidequest ──►)          │ BOSS → Light element
  ▼               ▼               ▼                                ▼
Northern Warning                 Coastal → Seaward Reactor       Fallen Ironhaven
  │                                │ BOSS: Aquos                    │ BOSS → Dark element
  ▼                                ▼                                ▼
Tidewatch Road                   Frostmere                       Stabilizer Hunt
  │                                │ Kael joins                     │ (3 locations)
  ▼                                ▼                                ▼
Ironhaven ─────────────────►     Glacier/Coast sidequests        Luminous Hollow (optional)
  [story_ironhaven_unlocked]       │                                │ Lyra joins
                                   ▼                                ▼
                                 Abyssal Reactor                 Reactor Core Descent
                                   │ ══ RAGNORAK ══                 │ FINAL BOSS
                                   ▼                                ▼
                                 [ragnorak_triggered]            Game Complete
```

---

## Implementation Integration Points

### SaveManager Additions
```
# New progression flags (added to existing progression_flags dict)
story_ironhaven_unlocked: bool
story_ashveil_open: bool
story_frostmere_unlocked: bool
story_abyssal_clearance: bool
ragnorak_triggered: bool
story_veilwatch_found: bool
story_final_gate: bool

# New data
lumina_stabilizers_collected: int  # 0-3
world_state: int  # 1, 2, or 3
```

### Zone Script Pattern (State 3 variants)
```gdscript
func _setup_zone():
    var save = SaveManager.get_save_data()
    if save.get("ragnorak_triggered", false):
        _apply_corruption_overlay()
        _swap_enemy_spawns()
        _update_npc_dialogue()
```

### ZonePortal Usage
```gdscript
# Existing pattern — just add new flags
portal.required_flag = "story_ironhaven_unlocked"
portal.locked_message = "The northern road is blocked. Speak with Elder Maren."
```

### Traversal Gate Check
```gdscript
# Existing PartyMemberData.traversal_flags system
func can_access_area(required_abilities: Array) -> bool:
    for ability in required_abilities:
        if not PartyManager.has_traversal_ability(ability):
            return false
    return true
```

---

## Naming Fix Required

Per locked naming rules in CLAUDE.md:
- Current companion "Yuna" (member_id `"companion"`) → rename to **"Taighe"** (member_id `"taighe"`)
- Current hero display_name "Hero" → rename to **"Amaro"**
- Update `resources/characters/companion.tres` and `resources/characters/hero.tres`
