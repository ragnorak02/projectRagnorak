# Ragnorak — World Atlas

## Overview

The world of Ragnorak is a semi-open hub-spoke network of **24 zones** organized around **4 hub towns**. Each hub unlocks 2-5 spoke routes containing fields, dungeons, and reactor facilities. The world progresses through **3 world states**, each transforming tone, enemies, and available zones.

Lumina — the world's energy source — shapes geography. Reactors are built where cooling is abundant: ocean coasts, glacial shelves, and deep underground. Towns grow around this infrastructure. When Ragnorak corrupts Lumina, these same sites become the most dangerous places in the world.

---

## Hub-Spoke Topology

```
STATE 1 — EARLY ERA ("Under Calm Skies")
═══════════════════════════════════════════

                        [Tidewatch Cave]* (traversal: double_jump)
                              │
[Millhaven Shrine]──[Greenhollow Fields]──[Millhaven]──[Tidewatch Road]──[Ironhaven]
  (dungeon)           (field, 8 enemies)   (start hub)   (coastal field)   (hub 2)
                                                                              │
STATE 1→2 BRIDGE                                                              │
═══════════════════════════════════════════                                    │
                                                                              │
    [Ashveil Aerie]* ──[Ashveil Pass]──────────────────────────────────[Ironhaven]
    (traversal gate)    (mountain field)                                   │    │
                                                        [Coastal Approach]─┘    │
                                                              │                 │
                                                     [Seaward Reactor]    [Irondeep Mines]
                                                       (reactor 1)         (dungeon+boss)

STATE 2 — RISING TENSION ("The Iron Mandate")
═══════════════════════════════════════════

    [Submerged Ruins]* ──[Shattered Coast]──[Frostmere]──[Glacier Shelf]──[Glacial Vault]*
    (traversal gate)      (frozen field)     (hub 3)      (frozen field)   (traversal gate)
                                                │
                                        [Abyssal Reactor] ← RAGNORAK TRIGGERS HERE
                                          (reactor 2)

STATE 3 — POST-RAGNORAK ("The Luminous Corruption")
═══════════════════════════════════════════

    [Fallen Ironhaven]──[Veilwatch]──[Corruption Scar]──[Luminous Hollow]
    (transformed city)   (hub 4)      (scarred field)     (crystal dungeon)
                            │
                    [Reactor Core Descent]  ← FINAL DUNGEON
                      (reactor 3 / endgame)

    + Existing zones transform: Greenhollow Corrupted, Millhaven Aftermath

    * = traversal-gated (hidden/optional)
```

---

## Complete Zone Registry

### Hub 1 — Millhaven (State 1: "Under Calm Skies")

Millhaven is a quiet pastoral town at the southern edge of the world. It sits on rolling green hills with a small Lumina relay station that powers the village. The people here live simple lives — farming, trade, local militia. This is home.

#### Zone 1 — Millhaven

| Field | Value |
|-------|-------|
| Zone ID | `town_hub` |
| Type | TOWN |
| Hub | Hub 1 (Start) |
| World State | 1 |
| Connections | Greenhollow Fields, Millhaven Shrine, Tidewatch Road |
| Scene | `res://scenes/zones/town_hub.tscn` (exists) |

**Layout**: Central plaza with fountain, inn (save point), general store, militia barracks, residential quarter, Lumina relay station on east hill.

**NPCs**:
- **Elder Maren** — Quest giver, village leader. Sends Amaro on patrols, later delivers the Northern Warning.
- **Blacksmith Oren** — Weapons/armor vendor. Side quest: "Oren's Order" (fetch ore from Greenhollow).
- **Herbalist Mira** — Consumable vendor. Side quest: "Mira's Remedy" (fetch herbs from fields).
- **Innkeeper Fenn** — Save/rest point. Exposition about Lumina relay.
- **Militia Captain Dael** — Side quest: "Guard Duty" (patrol Greenhollow, kill enemies).
- **Merchant Syla** — Side quest: "Merchant Routes" (deliver supplies to Tidewatch Road outpost).
- **Relay Technician Joss** — Side quest: "Flickering Lights" (investigate relay anomaly in Greenhollow).
- **Taighe** — Found at relay station after Shrine quest. Joins party.

**Services**: Inn (save/rest), General Store (consumables), Blacksmith (weapons/armor), Quest Board.

---

#### Zone 2 — Greenhollow Fields

| Field | Value |
|-------|-------|
| Zone ID | `field_zone` |
| Type | FIELD |
| Hub | Hub 1 |
| World State | 1 (variant in State 3) |
| Connections | Millhaven, Millhaven Shrine |
| Scene | `res://scenes/zones/field_zone.tscn` (exists) |

**Layout**: Wide rolling grasslands with scattered trees, a ruined watchtower (soft gate — tough enemies), rocky outcrops, stream running east-west, path north to Shrine entrance.

**Enemies**: Garrison Soldier (x4 patrols), Shield Guard (x2 at watchtower), Military Rifleman (x2 roaming). Total: ~8 enemy placements.

**Points of Interest**:
- Watchtower Ruin — Soft gate (level 5+ recommended). Contains chest with early-game equipment.
- Old Outpost — Exploration quest: "Old Outpost Records" (find military logs hinting at northern tensions).
- Stream Crossing — Scenic rest spot, lore stone about Lumina relay network.

**State 3 Variant — Greenhollow Corrupted**: Same scene with overlay. Grass withered, stream glows faintly purple, corrupted enemies replace soldiers, watchtower partially collapsed. Corruption Spewer spawns at stream.

---

#### Zone 3 — Millhaven Shrine

| Field | Value |
|-------|-------|
| Zone ID | `dungeon_zone` |
| Type | DUNGEON |
| Hub | Hub 1 |
| World State | 1 |
| Connections | Greenhollow Fields |
| Scene | `res://scenes/zones/dungeon_zone.tscn` (exists) |

**Layout**: Ancient stone shrine built into hillside. 3 rooms: entry hall, puzzle chamber, inner sanctum. Lumina crystals light the walls. Short dungeon — tutorial difficulty.

**Enemies**: Garrison Soldier (x2 entry), Security Automaton (x1 puzzle room), Garrison Soldier (x2 sanctum).

**Puzzle**: Activate 3 Lumina crystal pillars in correct order (visual cue from wall engravings). Simple — tutorial-level.

**Boss**: None (mini-boss: stronger Security Automaton in sanctum).

**Reward**: Taighe joins party after completion. Fire Bolt ability scroll.

**Dungeon Quest**: "Shrine's Second Secret" — After clearing, a hidden alcove opens on revisit with lore tablet about ancient Lumina usage.

---

#### Zone 4 — Tidewatch Road

| Field | Value |
|-------|-------|
| Zone ID | `tidewatch_road` |
| Type | FIELD |
| Hub | Hub 1 |
| World State | 1 |
| Connections | Millhaven, Ironhaven, Tidewatch Cave (traversal gate) |

**Layout**: Coastal cliff road winding northeast. Ocean visible below. Military checkpoint halfway. Cave entrance visible on high cliff (needs double_jump to reach). Outpost at far end before Ironhaven.

**Enemies**: Garrison Soldier (x3 checkpoint), Patrol Drone (x2 coastal), Shield Guard (x1 outpost). Ambush encounter during main quest "Road to Ironhaven" adds x4 soldiers.

**Points of Interest**:
- Military Checkpoint — Story interaction point. Guards initially block passage until quest flag.
- Cliff Overlook — Scenic point, lore about coastal Lumina infrastructure.
- Supply Outpost — Merchant Syla's delivery destination (side quest).
- Tidewatch Cave entrance — Visible but unreachable without double_jump. Glowing Lumina crystals mark it.

**Exploration Quest**: "Cliff's Edge Cache" — Find hidden supply crate on narrow ledge (basic platforming).

---

#### Zone 5 — Tidewatch Cave

| Field | Value |
|-------|-------|
| Zone ID | `tidewatch_cave` |
| Type | DUNGEON (optional) |
| Hub | Hub 1 |
| World State | 1 |
| Connections | Tidewatch Road (requires double_jump) |
| Traversal Gate | `double_jump` |

**Layout**: Small sea cave with Lumina crystal formations. 2 rooms: entry grotto, crystal chamber. Waves crash below. Luminescent pools.

**Enemies**: Security Automaton (x2), Patrol Drone (x1).

**Reward**: Rare early-game equipment (weapon or accessory). Lore tablet about underwater reactor sites.

**Design Note**: This is the first traversal-gated content players encounter. It's visible from Tidewatch Road early, but inaccessible until Kael joins (State 2) and grants double_jump. Rewards returning to old areas.

---

### Hub 2 — Ironhaven (State 1-2: Transition Hub)

Ironhaven is a fortified port city built around heavy industry and military infrastructure. Iron foundries, shipyards, and a garrison headquarters dominate the skyline. The Lumina supply lines from the southern relay feed the city's forges. Tension is already high here — military buildup, civilian unease, whispers of something wrong at the northern reactor sites.

#### Zone 6 — Ironhaven

| Field | Value |
|-------|-------|
| Zone ID | `ironhaven` |
| Type | TOWN |
| Hub | Hub 2 |
| World State | 1-2 |
| Connections | Tidewatch Road, Ashveil Pass, Irondeep Mines, Coastal Reactor Approach |
| Gate | `story_ironhaven_unlocked` (complete "The Northern Warning" in Millhaven) |

**Layout**: Large multi-district city. Harbor district (docks, shipyard), Forge district (smiths, workshops), Military quarter (garrison HQ, barracks), Market square (vendors, inn), Upper terrace (commander's office, overlook).

**NPCs**:
- **Commander Thane** — Military leader. Main quest giver for Irondeep and Coastal missions.
- **Forgemaster Kelda** — Advanced weapons/armor vendor. Side quest: "Forgemaster's Challenge" (fetch rare ore from Irondeep + defeat elite enemy).
- **Dockmaster Bryn** — Harbor logistics. Side quest: "Harbor Rats" (clear smugglers from warehouse).
- **Lieutenant Vassar** — Intelligence officer. Side quest: "Deserter's Trail" (investigate missing soldiers in Ashveil direction).
- **Engineer Petra** — Prototype gear. Side quest: "Field Test" (test experimental equipment in combat).
- **Innkeeper Aldric** — Save/rest, rumors about northern cold.
- **Kael** — Seen briefly in State 1 as garrison sergeant. Joins party at Frostmere in State 2.

**Services**: Inn, Advanced Blacksmith, Armorer, General Store, Military Requisitions (special vendor after story progress).

**State 3 — Fallen Ironhaven**: See Zone 20.

---

#### Zone 7 — Ashveil Pass

| Field | Value |
|-------|-------|
| Zone ID | `ashveil_pass` |
| Type | FIELD |
| Hub | Hub 2 |
| World State | 2 |
| Connections | Ironhaven, Frostmere, Ashveil Aerie (traversal gate) |
| Gate | `story_ashveil_open` (complete Irondeep Mines main quest) |

**Layout**: Mountain pass with steep cliffs, narrow switchbacks, alpine vegetation thinning to snow. Wind effects. Ashveil Aerie visible high above on a rocky spire (needs wall_run + glide). Military supply carts along route.

**Enemies**: Elite Soldier (x3 patrol), Sniper Drone (x2 cliff positions), Heavy Trooper (x1 chokepoint), Military Rifleman (x2 roaming).

**Points of Interest**:
- Abandoned Supply Camp — Loot and lore about military losses.
- Cliff Face — Wall with visible handholds leading to Ashveil Aerie. Requires wall_run + glide.
- Mountain Shrine — Small rest point with lore stone about ancient mountain settlements.

**Exploration Quest**: "Ashveil Remnants" — Find scattered military equipment from a failed expedition.

---

#### Zone 8 — Irondeep Mines

| Field | Value |
|-------|-------|
| Zone ID | `irondeep_mines` |
| Type | DUNGEON |
| Hub | Hub 2 |
| World State | 1-2 |
| Connections | Ironhaven |

**Layout**: Industrial mine complex descending underground. 4 sections: entrance shaft, ore processing level, deep excavation, overseer's chamber. Mine carts on rails, Lumina-powered machinery, unstable supports.

**Enemies**: Garrison Soldier (x4), Heavy Trooper (x2), Security Automaton (x3), Combat Medic (x1). Elite: Ironclad Sergeant (x1 mini-boss before boss).

**Puzzle**: Redirect mine cart to clear collapsed tunnel (lever puzzle, 3 switches).

**BOSS — Mine Overseer Grendl**:
- HP: 500 | Phases: 2
- Phase 1: Drill arm attacks (breakable part), summons 2 soldier adds every 30s.
- Phase 2 (50% HP): Drill arm breaks, switches to hammer + explosive charges. Faster, more aggressive.
- Weakness: Fire (drill arm), Wind (phase 2 charges scatter in wind).
- Reward: Unlocks Ashveil Pass. Key story item.

**Dungeon Quest**: "Irondeep Collapse" — Find trapped miners in side tunnel, clear rubble.

---

#### Zone 9 — Coastal Reactor Approach

| Field | Value |
|-------|-------|
| Zone ID | `coastal_approach` |
| Type | FIELD |
| Hub | Hub 2 |
| World State | 2 |
| Connections | Ironhaven, Seaward Reactor |

**Layout**: Rocky coastal path descending toward the ocean. Lumina conduits run along the ground toward the reactor. Crashing waves, sea spray effects. Military security perimeter with checkpoints.

**Enemies**: Reactor Sentinel (x2 at perimeter), Patrol Drone (x3 coastal), Military Rifleman (x2), Tactical Officer (x1 with soldier squad of x3).

**Points of Interest**:
- Observation Platform — Overlooking the reactor's surface structure. Lore about cooling systems.
- Security Perimeter — Story checkpoint, requires clearance from Commander Thane.
- Tidal Pools — Small area with Lumina-infused water, ambient visual interest.

---

#### Zone 10 — Seaward Reactor

| Field | Value |
|-------|-------|
| Zone ID | `seaward_reactor` |
| Type | REACTOR |
| Hub | Hub 2 |
| World State | 2 |
| Connections | Coastal Reactor Approach |

**Layout**: Partially submerged industrial reactor complex. Upper gantries above water, lower sections flooded or pressurized. 4 sections: surface platform, cooling intake (partially submerged), core access corridor, reactor chamber. First reactor player enters — establishes what Lumina infrastructure looks and feels like.

**Enemies**: Reactor Sentinel (x3), Security Automaton (x4), Patrol Drone (x2). Elite: Reactor Sentinel (enhanced, x1 before boss).

**Environmental Hazard**: Steam vents (periodic damage zones), pressurized doors (timed traversal).

**BOSS — Reactor Warden Aquos**:
- HP: 700 | Phases: 2
- Phase 1: Water pressure attacks, floods sections of arena periodically (forces repositioning). Barrier shell.
- Phase 2 (40% HP): Rising water — arena shrinks. Warden becomes faster, uses water jet dashes.
- Weakness: Ice (freezes water attacks temporarily), Earth (grounds barrier).
- Reward: Unlocks Frostmere route. Reactor keycard (used later).

**Dungeon Quest**: "Seaward Logs" — Find chief engineer's logs revealing concerns about Abyssal Reactor.

**Reactor Lore**: The Seaward Reactor uses ocean water for cooling. Lumina core sits below the waterline. Conduits run back to Ironhaven, powering the forge district. This is a mid-sized civilian/military reactor — the Abyssal is far larger.

---

#### Zone 11 — Ashveil Aerie

| Field | Value |
|-------|-------|
| Zone ID | `ashveil_aerie` |
| Type | DUNGEON (optional) |
| Hub | Hub 2 |
| World State | 2 |
| Connections | Ashveil Pass (requires wall_run + glide) |
| Traversal Gate | `wall_run` + `glide` |

**Layout**: Ancient aerie built into a mountain spire. Open-air platforms connected by narrow bridges and wind currents. 2 sections: approach platforms (wind puzzles), inner sanctum.

**Enemies**: Sniper Drone (x3 on platforms), Patrol Drone (x2), Military Rifleman (x2 — deserters hiding here).

**Puzzle**: Navigate wind currents using glide. Activate wind crystals to create air bridges.

**Reward**: **Sera joins the party**. Rare wind-element equipment. Sera was sheltering here after fleeing military service — she's a wind specialist who can teach glide techniques.

**Design Note**: This is a sidequest-gated party member. Players who explore thoroughly and have the right traversal abilities get rewarded with a 4th party member earlier than expected.

---

### Hub 3 — Frostmere (State 2: "The Iron Mandate")

Frostmere is a harbor town built on the edge of a glacial bay. The water is dark and cold. The Abyssal Reactor sits beneath the bay — the largest and most powerful Lumina reactor in the world. The town exists because the reactor exists. Everything here serves the reactor: supply chains, worker housing, security. The mood is tense — military lockdown, supply shortages, civilian fear.

#### Zone 12 — Frostmere

| Field | Value |
|-------|-------|
| Zone ID | `frostmere` |
| Type | TOWN |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Ashveil Pass, Glacier Shelf Route, Shattered Coast, Abyssal Reactor |
| Gate | `story_frostmere_unlocked` (complete Seaward Reactor main quest) |

**Layout**: Frost-covered harbor town. Docks district (frozen piers, icebreaker ships), Reactor district (worker housing, supply depot), Market quarter (vendors under heated canopies), Command center (military HQ, restricted), Residential quarter (civilian homes, worry and cold).

**NPCs**:
- **Admiral Renne** — Military commander of Abyssal Reactor security. Main quest giver.
- **Researcher Lumi** — Reactor scientist. Side quest: "Frozen Findings" (collect crystal samples from Glacier Shelf). Provides lore about Lumina cooling.
- **Captain Voss** — Search and rescue. Side quest: "Lost Expedition" (investigate lost survey team on Shattered Coast).
- **Healer Yrel** — Consumable vendor, advanced healing items. Side quest: "Cracking the Ice" (help civilians whose homes are losing Lumina heat).
- **Diver Ashwin** — Side quest: "Aurora Whispers" (investigate ghostly sightings near glacier — wraith encounter foreshadowing Ragnorak).
- **Kael** — Stationed here as garrison sergeant. Joins party when Amaro arrives. Kael has been stationed at Frostmere for months and knows the area.

**Services**: Inn, Advanced General Store, Equipment Upgrade Station, Reactor Requisitions (military vendor).

---

#### Zone 13 — Glacier Shelf Route

| Field | Value |
|-------|-------|
| Zone ID | `glacier_shelf` |
| Type | FIELD |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Frostmere, Glacial Vault (traversal gate) |

**Layout**: Frozen coastal shelf. Ice formations, crevasses, glacial caves. Northern lights shimmer above. Path winds along glacier edge with drops into dark water below. Glacial Vault entrance visible across a wide gap (needs glide).

**Enemies**: Frost Trooper (x3 patrol), Heavy Trooper (x1 chokepoint), Patrol Drone (x2), Sniper Drone (x1 elevated).

**OPTIONAL BOSS — Frostmere Colossus**:
- HP: 600 | Phases: 2
- Phase 1: Ice slam attacks, creates ice wall barriers in arena.
- Phase 2 (40% HP): Enrage — faster attacks, ice spikes erupt from ground periodically.
- Weakness: Fire. Resist: Ice (immune).
- Reward: Rare ice-element equipment, crafting materials.
- Found in a glacial arena off the main path. Optional encounter.

**Exploration Quest**: "Aurora Catcher" — Photograph (interact with) 3 aurora reflection points for Researcher Lumi.

---

#### Zone 14 — Shattered Coast

| Field | Value |
|-------|-------|
| Zone ID | `shattered_coast` |
| Type | FIELD |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Frostmere, Submerged Ruins (traversal gate) |

**Layout**: Broken coastline — ice shelves have fractured into floating platforms, frozen shipwrecks, exposed seabed. Deep section (level 18+ soft gate) has tougher enemies. Submerged Ruins entrance beneath a collapsed ice shelf (needs double_jump + wall_run).

**Enemies**: Frost Trooper (x2), Security Automaton (x2), Tactical Officer (x1 with squad). Deep section: Reactor Sentinel (x2), Heavy Trooper (x1).

**Points of Interest**:
- Frozen Shipwreck — Lore about Lumina transport vessels. Loot.
- Collapsed Ice Shelf — Marks Submerged Ruins entrance. Visible early, inaccessible without traversal.
- Deep Tidal Zone — Soft gate area with tougher enemies and better loot.

**Exploration Quest**: "Frozen Salvage" — Recover cargo from 3 frozen shipwrecks.

---

#### Zone 15 — Abyssal Reactor

| Field | Value |
|-------|-------|
| Zone ID | `abyssal_reactor` |
| Type | REACTOR |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Frostmere |
| Gate | `story_abyssal_clearance` (complete Frostmere quest chain) |

**Layout**: Massive underwater reactor accessed via elevator from Frostmere docks. 5 sections: descent elevator, pressure corridor, cooling chamber (vast open space with Lumina core visible), containment ring, core access (story climax room). This is the largest Lumina facility in the world. The scale should feel overwhelming.

**Enemies**: Reactor Sentinel (x4), Security Automaton (x6), Patrol Drone (x3), Tactical Officer (x1 with elite squad).

**Environmental Hazard**: Pressure fluctuations (screen effects, periodic damage zones), Lumina surge zones (high damage if stood in during pulse).

**RAGNORAK EVENT**: At the core access point, the story event triggers. The Lumina core destabilizes. Corruption erupts. The world changes. This is not a boss fight — it's a narrative event with escape sequence.

**Dungeon Quest**: "Abyssal Containment" — Before the event, find containment breach reports in side rooms. Foreshadows the corruption.

**Reactor Lore**: The Abyssal Reactor is built deep beneath the glacial bay. Ocean pressure and glacial meltwater provide extreme cooling, allowing the reactor to run at maximum output. It powers half the northern territory. Its Lumina core is the largest ever constructed — and the most unstable.

---

#### Zone 16 — Glacial Vault

| Field | Value |
|-------|-------|
| Zone ID | `glacial_vault` |
| Type | DUNGEON (optional) |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Glacier Shelf Route (requires glide) |
| Traversal Gate | `glide` |

**Layout**: Ancient research facility frozen inside a glacier. 3 rooms: frozen entry, research lab (old Lumina experiments), vault chamber. Ice crystals and ancient technology.

**Enemies**: Security Automaton (x3), Frost Trooper (x2).

**Puzzle**: Restore power to frozen consoles by redirecting Lumina flow (circuit puzzle).

**Reward**: Ancient Lumina research data (lore), ability upgrade item (enhances one character's ability tree). Rare equipment.

---

#### Zone 17 — Submerged Ruins

| Field | Value |
|-------|-------|
| Zone ID | `submerged_ruins` |
| Type | DUNGEON (optional) |
| Hub | Hub 3 |
| World State | 2 |
| Connections | Shattered Coast (requires double_jump + wall_run) |
| Traversal Gate | `double_jump` + `wall_run` |

**Layout**: Partially flooded ancient ruins beneath the coast. 3 rooms: tidal entry (water rises/falls on timer), archive hall, sealed chamber. Pre-reactor era Lumina site — hints that Lumina has been used far longer than modern civilization knows.

**Enemies**: Security Automaton (x2), Reactor Sentinel (x2 — ancient models).

**Puzzle**: Navigate tidal cycle (timed traversal — water rises and falls, opening/closing paths).

**Reward**: Endgame key item (one of 3 Lumina Stabilizers needed for final quest). Major lore about Lumina's true origin.

**Dungeon Quest**: "Submerged Relic" — Find the stabilizer core and extract it.

---

### Hub 4 — Veilwatch (State 3: "The Luminous Corruption")

Veilwatch is a makeshift resistance settlement built in the aftermath of Ragnorak. It occupies a defensible highland position with views of the corrupted landscape below. The sky is permanently darkened. Lumina corruption spreads across the land as visible tendrils of violet light. Military structure has collapsed — survivors from all regions have gathered here. This is the last hub.

#### Zone 18 — Veilwatch

| Field | Value |
|-------|-------|
| Zone ID | `veilwatch` |
| Type | TOWN |
| Hub | Hub 4 |
| World State | 3 |
| Connections | Corruption Scar, Reactor Core Descent, Fallen Ironhaven |
| Gate | `story_veilwatch_found` (auto after Ragnorak cutscene) |

**Layout**: Highland camp on rocky plateau. Watch towers (perimeter defense), Central tent cluster (command, vendors, rest), Workshop (Varn's engineering station), Overlook (view of corrupted world below — dramatic vista). Improvised, military-camp aesthetic. Lumina ward crystals keep corruption at bay.

**NPCs**:
- **Varn** — Lumina engineer. Joins party. Understands reactor systems, knows how to build ward technology. Main quest giver for stabilizer hunt.
- **Commander Thane** (returned) — Survived Ragnorak, leads resistance. Coordinates main quest.
- **Healer Yrel** (returned) — Fled Frostmere, now treats corrupted wounds. Advanced consumable vendor.
- **Scout Maren** (Elder Maren's relative) — Side quest: "Ward the Perimeter" (repair 5 spirit wards around camp).
- **Archivist Seren** — Side quest: "Echoes of the Fallen" (find memory fragments from fallen soldiers).
- **Refugee Leader Aldric** (Ironhaven innkeeper, survived) — Side quest: "Gathering the Lost" (find 3 groups of scattered survivors).

**Services**: Inn (tent rest), Scavenger Vendor (equipment from salvage), Ward Workshop (Varn upgrades), Field Medic.

---

#### Zone 19 — Corruption Scar

| Field | Value |
|-------|-------|
| Zone ID | `corruption_scar` |
| Type | FIELD |
| Hub | Hub 4 |
| World State | 3 |
| Connections | Veilwatch, Luminous Hollow |

**Layout**: Scarred landscape — the ground is cracked, violet Lumina corruption seeps from fissures, dead trees glow faintly. Visibility reduced by corruption haze. The terrain itself is hostile. East section (level 25+ soft gate) has the worst corruption.

**Enemies**: Corrupted Soldier (x3), Lumina Wraith (x2), Crystal Stalker (x2), Corruption Spewer (x1), Void Sentinel (x1 east section).

**BOSS — Corrupted Guardian**:
- HP: 800 | Phases: 3
- Phase 1: Corruption beam sweeps, summons Wraith adds (x2 every 45s).
- Phase 2 (60% HP): Arena starts shrinking — corruption closes in from edges.
- Phase 3 (30% HP): Guardian splits into 2 fragments. Must defeat both within 30s or they reform.
- Weakness: Light (newly unlocked). Resist: Dark.
- Reward: **Light element unlocks** for party. Light-element equipment.

**Exploration Quest**: "Charting the Scar" — Map 5 corruption hotspots for Varn's research.

---

#### Zone 20 — Fallen Ironhaven

| Field | Value |
|-------|-------|
| Zone ID | `fallen_ironhaven` |
| Type | FIELD (ruined city) |
| Hub | Hub 4 |
| World State | 3 |
| Connections | Veilwatch |

**Layout**: Ironhaven destroyed. Buildings collapsed, forges cold, harbor frozen and corrupted. The familiar streets are twisted — recognizable but wrong. Corrupted soldiers (former garrison) roam the ruins. The forge district glows with corrupt Lumina. Emotional beat — returning to a place the player knows.

**Enemies**: Corrupted Soldier (x4), Corrupted Automaton (x2), Hollow Beast (x1 forge district), Spirit Mender (x1).

**BOSS — Corrupted Commander**:
- HP: 900 | Phases: 2
- Phase 1: Military tactics — commands corrupted soldier adds, uses disciplined attack patterns. Still recognizably human.
- Phase 2 (50% HP): Corruption takes over — transforms into corrupted hybrid. Loses strategy, gains raw power and corruption AOE attacks.
- Weakness: Light (phase 2). Physical attacks effective in phase 1.
- Reward: **Dark element unlocks** for party. Dark-element equipment. Lumina Stabilizer #2.

---

#### Zone 21 — Luminous Hollow

| Field | Value |
|-------|-------|
| Zone ID | `luminous_hollow` |
| Type | DUNGEON (optional) |
| Hub | Hub 4 |
| World State | 3 |
| Connections | Corruption Scar |

**Layout**: Crystal cavern beneath the Corruption Scar. Lumina corruption has crystallized into beautiful but dangerous formations. 4 rooms: crystal descent, resonance chamber, split paths (party must divide — party coordination puzzle), heart chamber.

**Enemies**: Crystal Stalker (x3), Lumina Wraith (x2), Corruption Spewer (x2), Void Sentinel (x1).

**BOSS — Hollow Guardian**:
- HP: 750 | Phases: 2
- Phase 1: Standard attacks, crystal projectiles.
- Phase 2 (50% HP): Splits into 3 smaller guardians. Party must coordinate to defeat all 3 — they share HP but attack independently. Tests party system.
- Weakness: Light + Fire. Resist: Dark + Ice.
- Reward: **Lyra joins the party**. Spirit channeler who can communicate with Lumina directly. Lyra was trapped here, sustained by the crystals.

**Dungeon Quest**: "Luminous Heart" — Find Lyra and free her from the crystal resonance. Lyra's recruitment quest.

---

#### Zone 22 — Reactor Core Descent

| Field | Value |
|-------|-------|
| Zone ID | `reactor_core` |
| Type | REACTOR (Final Dungeon) |
| Hub | Hub 4 |
| World State | 3 |
| Connections | Veilwatch |
| Gate | `story_final_gate` (complete all 3 resistance prep quests / collect 3 Lumina Stabilizers) |

**Layout**: The original Lumina source — deep underground, far older than any modern reactor. 6 sections: descent shaft, ancient corridor, first seal chamber, corruption nexus, purification bridge, core chamber. The environment shifts from industrial to ancient to otherworldly. This is the longest dungeon — the final test.

**Enemies**: All corrupted enemy types appear. Corrupted Soldier (x4), Crystal Stalker (x3), Void Sentinel (x2), Hollow Beast (x2), Spirit Mender (x2), Corruption Spewer (x3), Lumina Wraith (x4).

**Environmental Hazards**: Corruption fields (DOT zones), gravity anomalies (in core chamber), Lumina surges (high damage pulses).

**FINAL BOSS — Ragnorak Avatar**:
- HP: 2000 | Phases: 4
- Phase 1: Elemental rotation — cycles Fire/Ice/Wind/Earth attacks. Must exploit weakness windows.
- Phase 2 (75% HP): Gravity shifts — arena rotates, forcing repositioning. Adds corruption field zones.
- Phase 3 (50% HP): Light/Dark split — avatar splits into Light and Dark halves. Must damage both.
- Phase 4 (25% HP): All elements at once. Full party coordination required. Uses all enemy mechanics seen throughout game. Ultimate test.
- Weakness: Rotates with phases. Light effective in phase 3 Dark half. Dark effective in phase 3 Light half.
- Reward: Game completion. Lumina stabilized (or transformed — story resolution).

**Dungeon Quest**: "Core Fragments" — Find 3 ancient core fragments in side rooms to weaken the Avatar's defenses before the final fight.

**Reactor Lore**: This is not a reactor — it's the source. Lumina originates here. The modern reactors are just taps into this deeper system. Ragnorak happened because the Abyssal Reactor's core breach reached deep enough to destabilize the source. The corruption is Lumina itself, destabilized and lashing out.

---

#### Zone 23 — Greenhollow Corrupted (Variant)

| Field | Value |
|-------|-------|
| Zone ID | `field_zone` (same scene, state 3 overlay) |
| Type | FIELD |
| World State | 3 |
| Connections | Millhaven Aftermath |

**Implementation**: Same `field_zone.tscn` scene. Zone script checks `ragnorak_triggered` flag in `_setup_zone()`. If true: swap enemy spawns (Corrupted Soldier replaces Garrison Soldier, add Corruption Spewer at stream), apply visual overlay (darkened sky, withered grass shader, purple-tinted water), update NPC dialogue if any remain.

**Enemies**: Corrupted Soldier (x3), Corruption Spewer (x2), Lumina Wraith (x1).

---

#### Zone 24 — Millhaven Aftermath (Variant)

| Field | Value |
|-------|-------|
| Zone ID | `town_hub` (same scene, state 3 overlay) |
| Type | TOWN |
| World State | 3 |
| Connections | Greenhollow Corrupted |

**Implementation**: Same `town_hub.tscn` scene. State 3 overlay: damaged buildings, Lumina relay cracked and flickering, some NPCs gone (fled to Veilwatch), remaining NPCs have updated dialogue about the catastrophe. Inn still functions (save point). Vendor inventory reduced.

**Remaining NPCs**: Innkeeper Fenn (stayed behind), Relay Technician Joss (trying to stabilize relay), 2-3 refugees.

**Enemies**: None inside town (ward still partially works). Corrupted Soldier patrol (x2) at town edge.

---

## Reactor Location Summary

All reactor placements follow the Lumina cooling lore:

| Reactor | Cooling Method | Location | State |
|---------|---------------|----------|-------|
| Seaward Reactor | Ocean water intake | Coastal, partially submerged | 2 |
| Abyssal Reactor | Deep ocean + glacial meltwater | Beneath glacial bay | 2 |
| Reactor Core (Source) | Deep underground geothermal | Far underground | 3 |

The progression mirrors increasing depth and power:
1. Surface-level coastal reactor (introduction)
2. Deep underwater glacial reactor (mid-game climax)
3. Ancient underground source (endgame)

---

## Zone Summary Statistics

| Category | Count |
|----------|-------|
| Towns | 4 hubs + 2 variants = 6 |
| Fields | 8 |
| Dungeons | 8 (3 traversal-gated optional) |
| Reactors | 3 |
| **Total Zones** | **24** (22 unique + 2 variants) |
| Boss Zones | 7 |
| Traversal Gates | 4 |
| World States | 3 |
