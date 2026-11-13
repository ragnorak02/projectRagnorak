# Ragnorak — Quest Registry

## Overview

**49 total quests**: 18 main story + 16 side quests + 7 exploration quests + 8 dungeon quests.

All quests use the existing `QuestData` resource format (`.tres` files in `resources/quests/`). Each quest has a unique `quest_id`, objectives tracked via `QuestManager`, and rewards distributed on completion.

---

## Main Story Quests (18)

The critical path from Millhaven to the Reactor Core. These quests must be completed in order. Each advances the story and unlocks new zones.

### State 1 Arc — "Under Calm Skies" (5 quests)

---

#### MSQ-01: A Soldier's Dawn

| Field | Value |
|-------|-------|
| Quest ID | `msq_soldiers_dawn` |
| Zone | Millhaven |
| State | 1 |
| Level | 1 |
| Type | Tutorial |
| Giver | Militia Captain Dael |
| Prerequisite | None (game start) |

**Summary**: Amaro reports for militia duty. Tutorial quest — teaches movement, combat basics, and interacting with NPCs.

**Objectives**:
1. Report to Militia Captain Dael at the barracks
2. Equip the issued sword (tutorial: equipment)
3. Defeat the training dummy (tutorial: attack combo)
4. Practice dodge (tutorial: dodge timing)
5. Speak with Dael for patrol assignment

**Rewards**: Starting sword, 50 gold, patrol assignment → next quest.

**Sets Flag**: `msq_tutorial_complete`

---

#### MSQ-02: Greenhollow Patrol

| Field | Value |
|-------|-------|
| Quest ID | `msq_greenhollow_patrol` |
| Zone | Greenhollow Fields |
| State | 1 |
| Level | 2-3 |
| Type | Combat |
| Giver | Militia Captain Dael |
| Prerequisite | `msq_tutorial_complete` |

**Summary**: Patrol Greenhollow Fields. Increased military presence near the village — investigate and clear hostiles.

**Objectives**:
1. Travel to Greenhollow Fields
2. Defeat soldier patrol near the stream (3 Garrison Soldiers)
3. Investigate the old outpost (find military supply cache)
4. Defeat soldier patrol near shrine path (2 Garrison Soldiers + 1 Shield Guard)
5. Return to Dael

**Rewards**: Fire Bolt ability scroll (teaches first spell), 100 gold, consumables.

**Sets Flag**: `msq_greenhollow_cleared`

---

#### MSQ-03: Whispers in the Shrine

| Field | Value |
|-------|-------|
| Quest ID | `msq_shrine_whispers` |
| Zone | Millhaven Shrine |
| State | 1 |
| Level | 3-5 |
| Type | Dungeon |
| Giver | Elder Maren |
| Prerequisite | `msq_greenhollow_cleared` |

**Summary**: Strange energy readings from the old shrine. Elder Maren asks Amaro to investigate. Inside, Amaro meets Taighe, a mage investigating Lumina anomalies.

**Objectives**:
1. Enter the Millhaven Shrine
2. Clear the entry hall (2 Garrison Soldiers)
3. Solve the crystal pillar puzzle (activate 3 pillars in order)
4. Defeat the Security Automaton in the sanctum
5. Meet Taighe at the Lumina crystal
6. Return to Millhaven with Taighe

**Rewards**: **Taighe joins party**. Ice Shard ability for Taighe. 150 gold.

**Sets Flag**: `msq_taighe_joined`

---

#### MSQ-04: The Northern Warning

| Field | Value |
|-------|-------|
| Quest ID | `msq_northern_warning` |
| Zone | Millhaven |
| State | 1 |
| Level | 5-6 |
| Type | Story |
| Giver | Elder Maren |
| Prerequisite | `msq_taighe_joined` |

**Summary**: A messenger arrives from the north — military tensions escalating near Ironhaven. Elder Maren asks Amaro and Taighe to investigate. This quest is primarily dialogue and preparation.

**Objectives**:
1. Speak with the messenger at the inn
2. Prepare supplies (buy/equip from vendors — soft tutorial for shopping)
3. Speak with Elder Maren for final briefing
4. Head to Tidewatch Road

**Rewards**: Travel supplies, 100 gold.

**Sets Flag**: `story_ironhaven_unlocked` (opens Tidewatch Road → Ironhaven portal)

---

#### MSQ-05: Road to Ironhaven

| Field | Value |
|-------|-------|
| Quest ID | `msq_road_to_ironhaven` |
| Zone | Tidewatch Road |
| State | 1 |
| Level | 5-7 |
| Type | Combat + Travel |
| Giver | Auto (triggered on entering Tidewatch Road) |
| Prerequisite | `story_ironhaven_unlocked` |

**Summary**: Travel the coastal road to Ironhaven. Military ambush midway tests combat readiness.

**Objectives**:
1. Travel along Tidewatch Road
2. Pass the military checkpoint (dialogue — guards let you through with warning)
3. Survive the ambush (4 Garrison Soldiers + 1 Shield Guard — scripted encounter)
4. Reach the Ironhaven outpost
5. Enter Ironhaven

**Rewards**: 200 gold, equipment from ambush drops.

**Sets Flag**: `msq_reached_ironhaven`

---

### State 1→2 Arc — "The Iron Mandate" (4 quests)

---

#### MSQ-06: Under Iron Skies

| Field | Value |
|-------|-------|
| Quest ID | `msq_under_iron_skies` |
| Zone | Ironhaven |
| State | 1-2 |
| Level | 7-8 |
| Type | Story + Hub |
| Giver | Commander Thane |
| Prerequisite | `msq_reached_ironhaven` |

**Summary**: Arrive in Ironhaven. Commander Thane briefs Amaro on the situation: mines producing strange readings, reactor supply disruptions, military on edge.

**Objectives**:
1. Report to Commander Thane at military HQ
2. Tour the city (visit forge, harbor, market — introduces hub services)
3. Speak with Forgemaster Kelda about ore shortages
4. Return to Thane for Irondeep assignment

**Rewards**: Access to Ironhaven services, 150 gold.

**Sets Flag**: `msq_ironhaven_briefed`

---

#### MSQ-07: Into the Irondeep

| Field | Value |
|-------|-------|
| Quest ID | `msq_into_irondeep` |
| Zone | Irondeep Mines |
| State | 2 |
| Level | 8-10 |
| Type | Dungeon + Boss |
| Giver | Commander Thane |
| Prerequisite | `msq_ironhaven_briefed` |

**Summary**: Investigate the Irondeep Mines. Something is wrong underground. First major boss encounter.

**Objectives**:
1. Enter the Irondeep Mines
2. Clear the entrance shaft (4 Garrison Soldiers)
3. Navigate the ore processing level (Heavy Troopers + Automatons)
4. Solve the mine cart puzzle (redirect cart to clear tunnel)
5. Defeat the Ironclad Sergeant (mini-boss)
6. **BOSS: Mine Overseer Grendl** (500 HP, 2 phases)
7. Report findings to Commander Thane

**Rewards**: Rare weapon, 300 gold, key story item (ore sample with Lumina corruption traces).

**Sets Flag**: `story_ashveil_open` (opens Ashveil Pass)

---

#### MSQ-08: Seaward Orders

| Field | Value |
|-------|-------|
| Quest ID | `msq_seaward_orders` |
| Zone | Ironhaven → Coastal Reactor Approach |
| State | 2 |
| Level | 10-12 |
| Type | Travel + Combat |
| Giver | Commander Thane |
| Prerequisite | `story_ashveil_open` |

**Summary**: The ore corruption traces point to reactor instability. Thane orders inspection of the Seaward Reactor. Travel through Coastal Approach.

**Objectives**:
1. Receive orders from Commander Thane
2. Travel to Coastal Reactor Approach
3. Pass the security perimeter (requires Thane's clearance letter)
4. Defeat the perimeter patrol (Reactor Sentinels + Tactical Officer squad)
5. Reach the Seaward Reactor entrance

**Rewards**: Reactor access clearance, 200 gold, consumables.

**Sets Flag**: `msq_seaward_access`

---

#### MSQ-09: The Cooling Depths

| Field | Value |
|-------|-------|
| Quest ID | `msq_cooling_depths` |
| Zone | Seaward Reactor |
| State | 2 |
| Level | 11-13 |
| Type | Dungeon + Boss |
| Giver | Auto (continues from MSQ-08) |
| Prerequisite | `msq_seaward_access` |

**Summary**: Explore the Seaward Reactor. The cooling systems are fluctuating. The Reactor Warden — a Lumina-powered defense system — has gone aggressive.

**Objectives**:
1. Navigate the surface platform
2. Descend to the cooling intake (avoid steam vents)
3. Access the core corridor (clear Security Automatons)
4. **BOSS: Reactor Warden Aquos** (700 HP, 2 phases — water mechanics)
5. Stabilize the reactor console (post-boss interaction)
6. Report to Commander Thane (or proceed to Frostmere)

**Rewards**: Reactor keycard, rare equipment, 400 gold.

**Sets Flag**: `story_frostmere_unlocked` (opens path to Frostmere)

---

### State 2 Arc — "Frozen Tensions" (4 quests)

---

#### MSQ-10: The Frozen Harbor

| Field | Value |
|-------|-------|
| Quest ID | `msq_frozen_harbor` |
| Zone | Frostmere |
| State | 2 |
| Level | 13-15 |
| Type | Story + Hub |
| Giver | Admiral Renne |
| Prerequisite | `story_frostmere_unlocked` |

**Summary**: Arrive at Frostmere. The garrison here guards the Abyssal Reactor — the largest Lumina facility. Kael, stationed here, joins the party.

**Objectives**:
1. Arrive at Frostmere
2. Report to Admiral Renne
3. Meet Kael at the garrison (he's been expecting reinforcements)
4. Tour Frostmere (introduces services, reactor district)
5. Speak with Researcher Lumi about reactor readings

**Rewards**: **Kael joins party** (grants double_jump traversal). Access to Frostmere services. 300 gold.

**Sets Flag**: `msq_kael_joined`, `has_double_jump`

---

#### MSQ-11: Shelf of Silence

| Field | Value |
|-------|-------|
| Quest ID | `msq_shelf_of_silence` |
| Zone | Glacier Shelf Route |
| State | 2 |
| Level | 14-16 |
| Type | Investigation + Combat |
| Giver | Researcher Lumi |
| Prerequisite | `msq_kael_joined` |

**Summary**: Anomalous readings detected from the Glacier Shelf. Researcher Lumi needs field data. The party encounters increasing military presence and strange energy signatures.

**Objectives**:
1. Travel to Glacier Shelf Route
2. Collect 3 energy readings at marked locations
3. Defeat Frost Trooper patrol (3 Frost Troopers)
4. Investigate the anomaly source (find Lumina fissure — foreshadowing)
5. Return readings to Researcher Lumi

**Rewards**: 300 gold, ice-element equipment, Lumina research notes (lore).

**Sets Flag**: `msq_shelf_surveyed`

---

#### MSQ-12: Clearance Denied

| Field | Value |
|-------|-------|
| Quest ID | `msq_clearance_denied` |
| Zone | Frostmere |
| State | 2 |
| Level | 15-17 |
| Type | Story + Investigation |
| Giver | Admiral Renne |
| Prerequisite | `msq_shelf_surveyed` |

**Summary**: Lumi's data confirms the Abyssal Reactor is destabilizing. But Admiral Renne's clearance request to central command is denied — the military wants the reactor running at full power. Amaro must find another way in.

**Objectives**:
1. Present evidence to Admiral Renne
2. Request official access (denied)
3. Speak with Kael about alternative entry (he knows maintenance tunnels)
4. Find the maintenance access codes (investigation in reactor district — 3 NPCs with clues)
5. Present codes to Kael

**Rewards**: Abyssal access via maintenance route, 200 gold.

**Sets Flag**: `story_abyssal_clearance` (opens Abyssal Reactor)

---

#### MSQ-13: Into the Abyss

| Field | Value |
|-------|-------|
| Quest ID | `msq_into_the_abyss` |
| Zone | Abyssal Reactor |
| State | 2 → 3 |
| Level | 16-18 |
| Type | Dungeon + Story Event |
| Giver | Auto (continues from MSQ-12) |
| Prerequisite | `story_abyssal_clearance` |

**Summary**: Enter the Abyssal Reactor via maintenance tunnels. The deepest Lumina facility — massive scale, overwhelming power. At the core, the instability reaches critical mass. **RAGNORAK TRIGGERS.**

**Objectives**:
1. Descend via maintenance elevator
2. Navigate the pressure corridor (environmental hazards)
3. Cross the cooling chamber (vast open space, Lumina core visible — awe moment)
4. Reach the containment ring (clear Reactor Sentinels + Automatons)
5. Access the core — **RAGNORAK EVENT TRIGGERS** (narrative cutscene)
6. Escape sequence (timed traversal, collapsing infrastructure)
7. Wake in Veilwatch (State 3 begins)

**Rewards**: State 3 begins. World transforms.

**Sets Flag**: `ragnorak_triggered`, `story_veilwatch_found`

**Note**: No boss fight here — the event itself is the climax. The reactor's Lumina core destabilizes beyond containment. Corruption erupts. The escape sequence is intense but not a combat encounter.

---

### State 3 Arc — "The Luminous Corruption" (5 quests)

---

#### MSQ-14: The World Unmade

| Field | Value |
|-------|-------|
| Quest ID | `msq_world_unmade` |
| Zone | Veilwatch |
| State | 3 |
| Level | 18-20 |
| Type | Story + Hub |
| Giver | Varn |
| Prerequisite | `ragnorak_triggered` |

**Summary**: Amaro wakes in Veilwatch — a highland resistance camp. Varn, a Lumina engineer, explains: the Lumina source has destabilized, corruption is spreading, military structure has collapsed. The party must find a way to reach the source and stabilize it.

**Objectives**:
1. Wake in Veilwatch (narrative moment — world has changed)
2. Speak with Varn (explains corruption mechanics, introduces plan)
3. Meet Commander Thane (survived, leads resistance)
4. Explore Veilwatch (services, NPCs, resistance camp)
5. Receive briefing: need 3 Lumina Stabilizers to open path to the source

**Rewards**: **Varn joins party** (grants wall_run traversal). Access to Veilwatch services. 400 gold.

**Sets Flag**: `msq_varn_joined`, `has_wall_run`

---

#### MSQ-15: Scar Reconnaissance

| Field | Value |
|-------|-------|
| Quest ID | `msq_scar_recon` |
| Zone | Corruption Scar |
| State | 3 |
| Level | 20-22 |
| Type | Boss + Element Unlock |
| Giver | Varn |
| Prerequisite | `msq_varn_joined` |

**Summary**: Scout the Corruption Scar — the epicenter of surface corruption. A massive Corrupted Guardian blocks the path to Luminous Hollow. Defeating it reveals the Light element.

**Objectives**:
1. Travel to Corruption Scar
2. Map 3 corruption hotspots (investigation points)
3. Encounter first corrupted enemies (Corrupted Soldiers, Wraiths)
4. **BOSS: Corrupted Guardian** (800 HP, 3 phases — corruption beams, shrinking arena, splits)
5. Absorb Light element from defeated Guardian's crystal

**Rewards**: **Light element unlocks** for all party members. Light-element equipment. 500 gold. Lumina Stabilizer hint.

**Sets Flag**: `msq_light_unlocked`, `element_light_available`

---

#### MSQ-16: Ironhaven's Ghost

| Field | Value |
|-------|-------|
| Quest ID | `msq_ironhavens_ghost` |
| Zone | Fallen Ironhaven |
| State | 3 |
| Level | 22-24 |
| Type | Boss + Element Unlock |
| Giver | Commander Thane |
| Prerequisite | `msq_light_unlocked` |

**Summary**: Return to Ironhaven — now in ruins. The former military commander has been corrupted. An emotional confrontation. Defeating them reveals the Dark element.

**Objectives**:
1. Travel to Fallen Ironhaven
2. Navigate the ruined city (corrupted enemies, familiar locations destroyed)
3. Find the forge district (Corrupted Automatons, Hollow Beast)
4. Reach the military HQ
5. **BOSS: Corrupted Commander** (900 HP, 2 phases — military tactics → corruption transformation)
6. Absorb Dark element from the corruption's residue

**Rewards**: **Dark element unlocks**. Dark-element equipment. 500 gold. **Lumina Stabilizer #2**.

**Sets Flag**: `msq_dark_unlocked`, `element_dark_available`, `stabilizer_beta_collected`

---

#### MSQ-17: The Last Light

| Field | Value |
|-------|-------|
| Quest ID | `msq_last_light` |
| Zone | Multiple (Submerged Ruins, Fallen Ironhaven, Seaward Reactor revisit) |
| State | 3 |
| Level | 24-27 |
| Type | Collection + Exploration |
| Giver | Varn |
| Prerequisite | `msq_dark_unlocked` |

**Summary**: Collect 3 Lumina Stabilizers to open the path to the Reactor Core. Each stabilizer is in a different location, requiring different approaches.

**Objectives**:
1. Collect Stabilizer Alpha from Submerged Ruins (traversal: double_jump + wall_run)
2. Stabilizer Beta already collected (Fallen Ironhaven boss reward)
3. Collect Stabilizer Gamma from corrupted Seaward Reactor (revisit)
4. Return all 3 to Varn at Veilwatch
5. Varn constructs the Lumina Key

**Rewards**: Lumina Key (opens Reactor Core). 600 gold. Endgame preparation items.

**Sets Flag**: `story_final_gate` (all 3 stabilizers + Lumina Key)

**Note**: Stabilizer Beta is already collected from MSQ-16. This quest tracks all 3 and requires visiting/revisiting two other locations.

---

#### MSQ-18: Into the Heart of Lumina

| Field | Value |
|-------|-------|
| Quest ID | `msq_heart_of_lumina` |
| Zone | Reactor Core Descent |
| State | 3 |
| Level | 28-30 |
| Type | Final Dungeon + Final Boss |
| Giver | Auto (triggered by entering Reactor Core) |
| Prerequisite | `story_final_gate` |

**Summary**: The final quest. Descend into the original Lumina source — older than any modern reactor. Confront the Ragnorak Avatar, the manifestation of destabilized Lumina.

**Objectives**:
1. Descend the shaft into the ancient facility
2. Navigate the ancient corridor (all corrupted enemy types)
3. Break the first seal (combat encounter + puzzle)
4. Cross the corruption nexus (environmental hazard gauntlet)
5. Cross the purification bridge (Stabilizers activate, clearing a path)
6. **FINAL BOSS: Ragnorak Avatar** (2000 HP, 4 phases)
7. Stabilize the Lumina core (post-boss interaction)
8. Ending cutscene

**Rewards**: Game completion. Ending narrative.

**Sets Flag**: `msq_game_complete`

---

## Side Quests (16)

Side quests are optional but provide meaningful rewards: equipment, gold, abilities, lore, and preparation for tougher content.

### Millhaven Side Quests (5)

---

#### SQ-01: Mira's Remedy

| Field | Value |
|-------|-------|
| Quest ID | `sq_miras_remedy` |
| Zone | Greenhollow Fields |
| Level | 2-3 |
| Giver | Herbalist Mira (Millhaven) |
| Type | Fetch |

**Objectives**: Collect 5 healing herbs from Greenhollow Fields (scattered at gather points).

**Rewards**: 3 Hi-Potions, 75 gold, discount at Mira's shop.

---

#### SQ-02: Oren's Order

| Field | Value |
|-------|-------|
| Quest ID | `sq_orens_order` |
| Zone | Greenhollow Fields |
| Level | 3-4 |
| Giver | Blacksmith Oren (Millhaven) |
| Type | Fetch |

**Objectives**: Collect 3 iron ore from rocky outcrops in Greenhollow Fields.

**Rewards**: Weapon upgrade (current sword +5 attack), 100 gold.

---

#### SQ-03: Guard Duty

| Field | Value |
|-------|-------|
| Quest ID | `sq_guard_duty` |
| Zone | Greenhollow Fields |
| Level | 3-5 |
| Giver | Militia Captain Dael (Millhaven) |
| Type | Kill |

**Objectives**: Defeat 8 enemies in Greenhollow Fields (any type).

**Rewards**: 150 gold, militia insignia (accessory: +5% XP).

---

#### SQ-04: Flickering Lights

| Field | Value |
|-------|-------|
| Quest ID | `sq_flickering_lights` |
| Zone | Greenhollow Fields |
| Level | 4-5 |
| Giver | Relay Technician Joss (Millhaven) |
| Type | Investigation |

**Objectives**: Investigate 3 Lumina relay nodes in Greenhollow (interact points). One is malfunctioning — defeat the Security Automaton guarding it. Report findings.

**Rewards**: 100 gold, Lumina Lens (accessory: reveals hidden items in current zone).

---

#### SQ-05: Merchant Routes

| Field | Value |
|-------|-------|
| Quest ID | `sq_merchant_routes` |
| Zone | Tidewatch Road |
| Level | 5-6 |
| Giver | Merchant Syla (Millhaven) |
| Type | Delivery |

**Objectives**: Deliver supply package to the outpost at the far end of Tidewatch Road. Return with confirmation.

**Rewards**: 200 gold, rare consumable, Syla's Trade Card (10% vendor discount in Millhaven).

---

### Ironhaven Side Quests (4)

---

#### SQ-06: Deserter's Trail

| Field | Value |
|-------|-------|
| Quest ID | `sq_deserters_trail` |
| Zone | Ashveil Pass |
| Level | 10-12 |
| Giver | Lieutenant Vassar (Ironhaven) |
| Type | Investigation |

**Objectives**: Find 3 deserter camp sites along Ashveil Pass. Investigate final camp — find a journal revealing soldiers fled due to strange sightings. Optional: defeat the deserters (or talk them down — dialogue choice).

**Rewards**: 250 gold, deserter's journal (lore about pre-Ragnorak signs), equipment.

---

#### SQ-07: Forgemaster's Challenge

| Field | Value |
|-------|-------|
| Quest ID | `sq_forgemasters_challenge` |
| Zone | Irondeep Mines |
| Level | 9-11 |
| Giver | Forgemaster Kelda (Ironhaven) |
| Type | Fetch + Mini-boss |

**Objectives**: Retrieve rare deep-ore from Irondeep Mines (specific node in deep section). Defeat the Ironclad Sergeant guarding it.

**Rewards**: Advanced weapon crafted by Kelda (significant upgrade), 300 gold.

---

#### SQ-08: Harbor Rats

| Field | Value |
|-------|-------|
| Quest ID | `sq_harbor_rats` |
| Zone | Ironhaven (harbor district) |
| Level | 8-9 |
| Giver | Dockmaster Bryn (Ironhaven) |
| Type | Kill |

**Objectives**: Clear smugglers from harbor warehouse (6 Garrison Soldiers in interior encounter). Find smuggled goods.

**Rewards**: 200 gold, smuggled goods (sellable items), harbor access (shortcut).

---

#### SQ-09: Field Test

| Field | Value |
|-------|-------|
| Quest ID | `sq_field_test` |
| Zone | Greenhollow Fields (or Ashveil Pass) |
| Level | 8-10 |
| Giver | Engineer Petra (Ironhaven) |
| Type | Combat (special conditions) |

**Objectives**: Equip Petra's prototype weapon. Defeat 5 enemies with it (weapon has special mechanic — charges up on hit). Return with combat data.

**Rewards**: Keep the prototype weapon (unique), 200 gold, Petra becomes available for weapon augmentation.

---

### Frostmere Side Quests (4)

---

#### SQ-10: Frozen Findings

| Field | Value |
|-------|-------|
| Quest ID | `sq_frozen_findings` |
| Zone | Glacier Shelf Route |
| Level | 14-16 |
| Giver | Researcher Lumi (Frostmere) |
| Type | Fetch |

**Objectives**: Collect 5 Lumina crystal samples from the Glacier Shelf (gather points near ice formations).

**Rewards**: 300 gold, ice-element accessory, research notes (lore about Lumina crystallization).

---

#### SQ-11: Lost Expedition

| Field | Value |
|-------|-------|
| Quest ID | `sq_lost_expedition` |
| Zone | Shattered Coast |
| Level | 15-17 |
| Giver | Captain Voss (Frostmere) |
| Type | Investigation + Combat |

**Objectives**: Find 3 expedition markers on the Shattered Coast. At the final marker, find survivors pinned by enemies (Frost Troopers + Security Automaton). Defeat enemies, escort survivors.

**Rewards**: 350 gold, expedition journal (lore), rare armor piece.

---

#### SQ-12: Aurora Whispers

| Field | Value |
|-------|-------|
| Quest ID | `sq_aurora_whispers` |
| Zone | Glacier Shelf Route |
| Level | 15-17 |
| Giver | Diver Ashwin (Frostmere) |
| Type | Investigation + Kill (Wraith) |

**Objectives**: Investigate 3 aurora anomaly points on the Glacier Shelf. At the final point, encounter a Lumina Wraith (pre-Ragnorak foreshadowing — this shouldn't exist yet). Defeat it.

**Rewards**: 300 gold, spirit-touched accessory (foreshadows Light element), Ashwin's log (lore).

**Narrative Note**: This is deliberate foreshadowing. The wraith shouldn't be here — it's a sign the Lumina source is already destabilizing before Ragnorak.

---

#### SQ-13: Cracking the Ice

| Field | Value |
|-------|-------|
| Quest ID | `sq_cracking_the_ice` |
| Zone | Frostmere |
| Level | 14-15 |
| Giver | Healer Yrel (Frostmere) |
| Type | Aid |

**Objectives**: Help 3 civilian households whose Lumina heating has failed. Fix relay nodes (interact points), deliver warm supplies, report to Yrel.

**Rewards**: 250 gold, advanced healing items, Yrel's Blessing (accessory: +10% healing received).

---

### Veilwatch Side Quests (3)

---

#### SQ-14: Ward the Perimeter

| Field | Value |
|-------|-------|
| Quest ID | `sq_ward_perimeter` |
| Zone | Veilwatch (surroundings) |
| Level | 19-21 |
| Giver | Scout Maren (Veilwatch) |
| Type | Repair + Combat |

**Objectives**: Repair 5 spirit wards around Veilwatch perimeter. Each ward site has corrupted enemies that must be cleared first (Corrupted Soldiers, Lumina Wraiths).

**Rewards**: 400 gold, ward-stone accessory (reduces corruption damage), Veilwatch defense bonus (fewer ambient enemy spawns near camp).

---

#### SQ-15: Echoes of the Fallen

| Field | Value |
|-------|-------|
| Quest ID | `sq_echoes_fallen` |
| Zone | Corruption Scar |
| Level | 20-22 |
| Giver | Archivist Seren (Veilwatch) |
| Type | Collection |

**Objectives**: Find 5 memory fragments from fallen soldiers in the Corruption Scar (glowing items near enemy encounters). Each fragment plays a brief audio/text memory of the soldier's last moments.

**Rewards**: 400 gold, fallen soldier's weapon (strong equipment), memorial built in Veilwatch (visual change).

---

#### SQ-16: Gathering the Lost

| Field | Value |
|-------|-------|
| Quest ID | `sq_gathering_lost` |
| Zone | Multiple (Greenhollow Corrupted, Tidewatch Road, Ashveil Pass) |
| Level | 21-23 |
| Giver | Refugee Leader Aldric (Veilwatch) |
| Type | Rescue |

**Objectives**: Find 3 groups of scattered survivors in previously visited zones (now corrupted). Each group is surrounded by corrupted enemies. Clear enemies, speak with survivors, direct them to Veilwatch.

**Rewards**: 500 gold, gratitude items from survivors, Veilwatch population increases (more vendors/services).

---

## Exploration Quests (7)

Exploration quests are found in the field, not given by NPCs. They reward players who explore thoroughly. Marked by environmental cues (glowing markers, unusual objects, visible-but-hard-to-reach spots).

---

#### EQ-01: Old Outpost Records

| Field | Value |
|-------|-------|
| Quest ID | `eq_outpost_records` |
| Zone | Greenhollow Fields |
| Level | 3 |
| Trigger | Interact with old outpost |

**Objectives**: Find 3 military log entries in the old outpost (search containers). Logs reveal early signs of northern military tension.

**Rewards**: 75 gold, lore entries, outpost map (reveals hidden gather points in Greenhollow).

---

#### EQ-02: Tower's Last Watch

| Field | Value |
|-------|-------|
| Quest ID | `eq_towers_last_watch` |
| Zone | Greenhollow Fields |
| Level | 5 |
| Trigger | Reach top of Watchtower Ruin (soft gate area) |

**Objectives**: Reach the watchtower top. Find the last watchman's journal. Survey the land from above (interact with 3 vista points).

**Rewards**: 100 gold, rare accessory, unlocks map markers for nearby zones.

---

#### EQ-03: Cliff's Edge Cache

| Field | Value |
|-------|-------|
| Quest ID | `eq_cliffs_edge_cache` |
| Zone | Tidewatch Road |
| Level | 5-6 |
| Trigger | Find the hidden ledge path along the cliff |

**Objectives**: Navigate a narrow cliff ledge to reach a hidden supply cache (basic platforming — no special traversal needed, just careful jumping).

**Rewards**: 150 gold, rare consumables, coastal trinket (accessory).

---

#### EQ-04: Ashveil Remnants

| Field | Value |
|-------|-------|
| Quest ID | `eq_ashveil_remnants` |
| Zone | Ashveil Pass |
| Level | 10-12 |
| Trigger | Find first scattered equipment piece |

**Objectives**: Collect 4 pieces of scattered military equipment from a failed mountain expedition. Each is off the main path.

**Rewards**: 200 gold, assembled equipment set piece (armor), expedition leader's letter (lore about what they were searching for in the mountains).

---

#### EQ-05: Aurora Catcher

| Field | Value |
|-------|-------|
| Quest ID | `eq_aurora_catcher` |
| Zone | Glacier Shelf Route |
| Level | 14-15 |
| Trigger | Interact with first aurora reflection point |

**Objectives**: Find and interact with 3 aurora reflection points on the Glacier Shelf. Beautiful locations with special visual effects.

**Rewards**: 200 gold, aurora lens (accessory: Lumina resistance), photograph items (collectibles).

---

#### EQ-06: Frozen Salvage

| Field | Value |
|-------|-------|
| Quest ID | `eq_frozen_salvage` |
| Zone | Shattered Coast |
| Level | 15-17 |
| Trigger | Search first frozen shipwreck |

**Objectives**: Recover cargo from 3 frozen shipwrecks along the Shattered Coast. Each wreck requires navigating ice platforms.

**Rewards**: 300 gold, salvaged equipment (weapon or armor), captain's log (lore about Lumina shipping routes).

---

#### EQ-07: Charting the Scar

| Field | Value |
|-------|-------|
| Quest ID | `eq_charting_scar` |
| Zone | Corruption Scar |
| Level | 20-22 |
| Trigger | Auto-available for Varn's research |

**Objectives**: Map 5 corruption hotspots in the Corruption Scar (interact with survey equipment at marked locations). Some are in enemy-dense areas.

**Rewards**: 400 gold, Varn's analysis data (unlocks corruption resistance upgrade at Veilwatch workshop), survey tool (accessory: reveals corruption density on minimap).

---

## Dungeon Quests (8)

One quest per dungeon — found inside the dungeon, rewards thorough exploration beyond the main path.

---

#### DQ-01: Shrine's Second Secret

| Field | Value |
|-------|-------|
| Quest ID | `dq_shrine_second_secret` |
| Zone | Millhaven Shrine |
| Level | 5 (revisit) |
| Trigger | Revisit shrine after initial clear — hidden alcove opens |

**Objectives**: Enter the hidden alcove. Find the lore tablet about ancient Lumina usage (pre-reactor era).

**Rewards**: 100 gold, ancient knowledge (lore), Lumina Charm (accessory: +5 MP regen).

---

#### DQ-02: Irondeep Collapse

| Field | Value |
|-------|-------|
| Quest ID | `dq_irondeep_collapse` |
| Zone | Irondeep Mines |
| Level | 9-10 |
| Trigger | Find trapped miners in side tunnel |

**Objectives**: Locate the collapsed side tunnel. Clear rubble (interact). Defeat enemies in tunnel (Security Automatons). Lead miners to exit.

**Rewards**: 200 gold, miners' gratitude reward (rare crafting material), mine map (reveals hidden ore nodes).

---

#### DQ-03: Seaward Logs

| Field | Value |
|-------|-------|
| Quest ID | `dq_seaward_logs` |
| Zone | Seaward Reactor |
| Level | 12-13 |
| Trigger | Find first engineer's log terminal |

**Objectives**: Access 3 engineer log terminals scattered in the reactor. Logs reveal growing concerns about the Abyssal Reactor's stability. Foreshadows Ragnorak.

**Rewards**: 200 gold, chief engineer's keycard (opens supply room with equipment), critical lore.

---

#### DQ-04: Abyssal Containment

| Field | Value |
|-------|-------|
| Quest ID | `dq_abyssal_containment` |
| Zone | Abyssal Reactor |
| Level | 17-18 |
| Trigger | Find first containment breach report |

**Objectives**: Find 3 containment breach reports in side rooms of the Abyssal Reactor. Each reveals a different system failure. Together they paint a picture of inevitable collapse.

**Rewards**: 300 gold, containment badge (accessory: Lumina damage resistance), heavy foreshadowing.

---

#### DQ-05: Glacial Experiment

| Field | Value |
|-------|-------|
| Quest ID | `dq_glacial_experiment` |
| Zone | Glacial Vault |
| Level | 15-17 |
| Trigger | Find first research console |

**Objectives**: Activate 3 ancient research consoles. Each reveals data about pre-modern Lumina experiments (ancient civilization used Lumina differently). Solve the power circuit puzzle.

**Rewards**: 250 gold, ancient Lumina technique (ability upgrade for one character), research data (lore).

---

#### DQ-06: Submerged Relic

| Field | Value |
|-------|-------|
| Quest ID | `dq_submerged_relic` |
| Zone | Submerged Ruins |
| Level | 16-18 |
| Trigger | Main purpose of entering |

**Objectives**: Navigate the tidal cycle. Find the stabilizer core in the sealed chamber. Extract it (interaction sequence — ancient security system test).

**Rewards**: **Lumina Stabilizer Alpha** (required for final quest). Major lore about Lumina's true origin. 400 gold.

---

#### DQ-07: Luminous Heart

| Field | Value |
|-------|-------|
| Quest ID | `dq_luminous_heart` |
| Zone | Luminous Hollow |
| Level | 24-26 |
| Trigger | Enter Luminous Hollow |

**Objectives**: Navigate the crystal cavern. Solve the party split puzzle (party divides between two paths — both paths must be cleared). Defeat the Hollow Guardian. Free Lyra from crystal resonance.

**Rewards**: **Lyra joins party** (Spirit Channeler, Light/Dark mastery). Crystal equipment. 500 gold.

---

#### DQ-08: Core Fragments

| Field | Value |
|-------|-------|
| Quest ID | `dq_core_fragments` |
| Zone | Reactor Core Descent |
| Level | 28-30 |
| Trigger | Find first fragment chamber |

**Objectives**: Find 3 ancient core fragments in side rooms of the final dungeon. Each fragment weakens the Ragnorak Avatar's defenses (reduces boss phase HP thresholds by 5% each — 15% total if all found).

**Rewards**: Tactical advantage for final boss, 500 gold, final lore entries about the Lumina source's origin.

---

## Quest Summary

| Category | Count | Level Range |
|----------|-------|-------------|
| Main Story | 18 | 1-30 |
| Side Quests | 16 | 2-23 |
| Exploration | 7 | 3-22 |
| Dungeon | 8 | 5-30 |
| **Total** | **49** | **1-30** |

### Quests by Zone

| Zone | Main | Side | Explore | Dungeon | Total |
|------|------|------|---------|---------|-------|
| Millhaven | 3 | 5 | — | — | 8 |
| Greenhollow | 1 | 2* | 2 | — | 5 |
| Shrine | 1 | — | — | 1 | 2 |
| Tidewatch Road | 1 | 1* | 1 | — | 3 |
| Ironhaven | 2 | 4 | — | — | 6 |
| Irondeep Mines | 1 | 1* | — | 1 | 3 |
| Ashveil Pass | — | 1* | 1 | — | 2 |
| Coastal Approach | 1 | — | — | — | 1 |
| Seaward Reactor | 1 | — | — | 1 | 2 |
| Frostmere | 2 | 4 | — | — | 6 |
| Glacier Shelf | 1 | 1* | 1 | — | 3 |
| Shattered Coast | — | 1* | 1 | — | 2 |
| Abyssal Reactor | 1 | — | — | 1 | 2 |
| Glacial Vault | — | — | — | 1 | 1 |
| Submerged Ruins | — | — | — | 1 | 1 |
| Veilwatch | 1 | 3 | — | — | 4 |
| Corruption Scar | 1 | 1* | 1 | — | 3 |
| Fallen Ironhaven | 1 | — | — | — | 1 |
| Luminous Hollow | — | — | — | 1 | 1 |
| Reactor Core | 1 | — | — | 1 | 2 |
| Multiple zones | 1 | 1 | — | — | 2 |

*Some side quests are given in hub towns but completed in field/dungeon zones. Counted at completion zone.
