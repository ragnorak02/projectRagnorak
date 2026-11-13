# Ragnorak — Enemy Bestiary

## Overview

**28 enemy types total**: 8 base military + 4 elite military + 8 corrupted + 7 bosses + 1 existing (Garrison Soldier).

All enemies extend `EnemyBase` (`src/enemies/enemy_base.gd`). Each entry includes stats, AI behavior archetype, elemental properties, and implementation notes.

---

## Enemy Archetypes

Every enemy fits one of these combat roles:

| Archetype | Behavior | Player Counter |
|-----------|----------|----------------|
| Melee Chaser | Closes distance, attacks in range | Dodge timing, spacing |
| Defensive Guard | Blocks/counters, must flank or break guard | Positioning, guard-break abilities |
| Ranged Pressure | Stays at distance, retreats when approached | Close gap quickly, use cover |
| Aerial Harassment | Flies above melee, dive attacks | Magic, jump attacks, lock-on |
| Stagger Brute | Super-armor, slow but devastating | Patience, stagger buildup |
| Support Caster | Heals/buffs allies, avoids combat | Prioritize targeting |
| Hybrid | Mixes melee + ranged/special | Adapt to current mode |
| Commander | Buffs nearby allies, moderate combat | Take out early to weaken group |

---

## Pre-Ragnorak Military Enemies

### Base Military (8 types)

Military enemies appear in States 1 and 2. They are human soldiers, machines, and security systems. No magic, no monsters — the early conflict is grounded and political.

---

#### 1. Garrison Soldier

| Field | Value |
|-------|-------|
| Enemy ID | `garrison_soldier` |
| Archetype | Melee Chaser |
| HP | 50 |
| ATK | 8 |
| DEF | 5 |
| Speed | Normal |
| Stagger Threshold | 30 |
| XP | 15 |
| Gold | 10-20 |
| Zones | Greenhollow, Shrine, Tidewatch, Ironhaven, Irondeep |
| States | 1-2 |
| Status | **EXISTS** (current `EnemyBase` implementation) |

**Behavior**: Approaches player, stops at combat range (5-8 feet), attacks with 2-hit sword combo. Circles between attacks. Retreats briefly after taking damage.

**Elemental Properties**:
- Weaknesses: None
- Resistances: None
- Neutral to all elements

**Drops**: Potion (30%), Soldier's Badge (5%).

**Implementation**: This is the existing enemy. Use as baseline for all other enemy stats and behavior.

---

#### 2. Shield Guard

| Field | Value |
|-------|-------|
| Enemy ID | `shield_guard` |
| Archetype | Defensive Guard |
| HP | 80 |
| ATK | 6 |
| DEF | 12 (frontal), 5 (rear) |
| Speed | Slow |
| Stagger Threshold | 50 |
| XP | 25 |
| Gold | 15-30 |
| Zones | Greenhollow (watchtower), Tidewatch, Ironhaven |
| States | 1-2 |

**Behavior**: Faces player with shield raised. Blocks all frontal attacks (physical only — magic bypasses). Performs shield bash (stun) and spear thrust. Turns slowly — vulnerable from rear and sides. Periodically performs guard stance (immobile, increased block).

**AI Logic**:
- `preferred_combat_radius`: 4 feet (close, behind shield)
- `guard_break_threshold`: 3 hits on shield → brief stagger
- `turn_speed`: 90°/second (exploitable flanking)
- Group behavior: Shield Guards try to face player while other enemies flank

**Elemental Properties**:
- Weakness: Wind (pushes shield aside, creates opening)
- Resistance: Earth (+25%)
- Immune: None

**Drops**: Iron Shield Fragment (20%), Guard Insignia (5%).

**Implementation Notes**: Extend `EnemyBase` with `frontal_block` flag. Override `take_damage()` to check attack direction vs facing. Add `guard_stance` state to AI.

---

#### 3. Military Rifleman

| Field | Value |
|-------|-------|
| Enemy ID | `military_rifleman` |
| Archetype | Ranged Pressure |
| HP | 35 |
| ATK | 10 |
| DEF | 3 |
| Speed | Normal |
| Stagger Threshold | 20 |
| XP | 20 |
| Gold | 10-25 |
| Zones | Greenhollow, Tidewatch, Ironhaven, Ashveil |
| States | 1-2 |

**Behavior**: Maintains 15-20 foot distance from player. Fires 2-round burst (1.5s cooldown). If player closes to 8 feet, performs dodge-roll backward and repositions. Will not melee — always retreats to range.

**AI Logic**:
- `preferred_combat_radius`: 18 feet
- `retreat_distance`: 8 feet (triggers dodge away)
- `fire_cooldown`: 1.5 seconds
- `accuracy`: 70% (leading shots, not hitscan)
- Group behavior: Stays behind melee allies

**Elemental Properties**:
- Weakness: Earth (disrupts footing, reduces accuracy)
- Resistance: None
- Immune: None

**Drops**: Ammunition Box (15%), Scope Lens (3%).

**Implementation Notes**: Needs ranged attack system (projectile spawner). Override AI to maintain distance. Add `retreat_state` to enemy AI.

---

#### 4. Patrol Drone

| Field | Value |
|-------|-------|
| Enemy ID | `patrol_drone` |
| Archetype | Aerial Harassment |
| HP | 30 |
| ATK | 7 |
| DEF | 3 |
| Speed | Fast |
| Stagger Threshold | 15 |
| XP | 20 |
| Gold | 5-15 |
| Zones | Greenhollow, Tidewatch, Coastal Approach, Shattered Coast |
| States | 1-2 |

**Behavior**: Hovers 8-10 feet above ground. Circles player. Performs dive-bomb attack (descends rapidly, hits, returns to altitude). Dive attack has 3s telegraph (glowing charge). Vulnerable during and briefly after dive.

**AI Logic**:
- `hover_height`: 8-10 feet (out of basic melee range)
- `circle_radius`: 12 feet
- `dive_telegraph`: 3.0 seconds (visual + audio cue)
- `dive_recovery`: 1.5 seconds (grounded, vulnerable)
- Group behavior: Stagger dive timing — never dive simultaneously

**Elemental Properties**:
- Weakness: Earth (grounds temporarily, forces vulnerability), Ice (slows rotors)
- Resistance: Wind (+50% — designed for air)
- Immune: None

**Drops**: Drone Parts (20%), Flight Core (3%).

**Implementation Notes**: Needs flying enemy system. Override `NavigationAgent3D` for 3D pathing at height. Jump attacks and magic should be primary counters.

---

#### 5. Heavy Trooper

| Field | Value |
|-------|-------|
| Enemy ID | `heavy_trooper` |
| Archetype | Stagger Brute |
| HP | 120 |
| ATK | 15 |
| DEF | 10 |
| Speed | Slow |
| Stagger Threshold | 80 |
| XP | 40 |
| Gold | 25-50 |
| Zones | Irondeep, Ashveil, Glacier Shelf, Shattered Coast |
| States | 1-2 |

**Behavior**: Slow advance. Super-armor during attack animations (cannot be interrupted by normal attacks). Performs heavy swing (wide arc, 2s telegraph), ground pound (AOE, 2.5s telegraph), charge attack (linear, 1.5s telegraph). All attacks have clear visual/audio telegraphs. Recovery windows after each attack (1-2s vulnerability).

**AI Logic**:
- `preferred_combat_radius`: 6 feet
- `super_armor`: true during attack animations
- `telegraph_times`: { swing: 2.0, pound: 2.5, charge: 1.5 }
- `recovery_times`: { swing: 1.5, pound: 2.0, charge: 1.0 }
- Group behavior: Other enemies stay clear during Heavy Trooper attacks

**Elemental Properties**:
- Weakness: Ice (slows significantly, reduces super-armor effectiveness)
- Resistance: Earth (+25%), Fire (+10%)
- Immune: None

**Drops**: Heavy Plate (15%), Trooper Core (3%).

**Implementation Notes**: Add `super_armor` flag to `EnemyBase`. When true, `take_damage()` still applies damage but does not trigger flinch/stagger states. Stagger buildup still accumulates — when threshold reached, super-armor breaks temporarily.

---

#### 6. Combat Medic

| Field | Value |
|-------|-------|
| Enemy ID | `combat_medic` |
| Archetype | Support Caster |
| HP | 40 |
| ATK | 4 |
| DEF | 4 |
| Speed | Normal |
| Stagger Threshold | 20 |
| XP | 30 |
| Gold | 15-30 |
| Zones | Irondeep, Ashveil, Coastal Approach |
| States | 1-2 |

**Behavior**: Stays behind allies. Heals nearest injured ally every 8 seconds (20 HP heal, green particle effect). If no allies nearby, performs weak ranged attack (low damage support fire). If player approaches within 6 feet, runs away to maintain distance. Priority target for the player — teaches target prioritization.

**AI Logic**:
- `preferred_combat_radius`: 20 feet (far behind allies)
- `heal_interval`: 8.0 seconds
- `heal_amount`: 20 HP
- `flee_distance`: 6 feet (triggers flee if player closer)
- Group behavior: Always positions behind at least one ally

**Elemental Properties**:
- Weakness: Fire (disrupts concentration, interrupts healing), Wind (pushes out of position)
- Resistance: None
- Immune: None

**Drops**: Medic Kit (25%), Healing Crystal (5%).

**Implementation Notes**: Add `heal_ally` behavior to AI. Needs ally detection radius. Healing has visible cast time (1.5s) — interruptible by any attack. Teaches player to prioritize support enemies.

---

#### 7. Security Automaton

| Field | Value |
|-------|-------|
| Enemy ID | `security_automaton` |
| Archetype | Hybrid |
| HP | 70 |
| ATK | 10 |
| DEF | 8 |
| Speed | Normal |
| Stagger Threshold | 40 |
| XP | 30 |
| Gold | 15-35 |
| Zones | Shrine, Irondeep, Seaward Reactor |
| States | 1-2 |

**Behavior**: Alternates between melee mode (extending arm blades, 3-hit combo) and ranged mode (energy burst, 2s charge). Mode switches every 10 seconds or after being staggered. Energy burst has AOE (5 foot radius at impact point).

**AI Logic**:
- `preferred_combat_radius`: 8 feet (medium)
- `mode_switch_interval`: 10.0 seconds
- `melee_combo_length`: 3 hits
- `energy_burst_charge`: 2.0 seconds, 5ft AOE
- Group behavior: Automatons don't coordinate with human enemies — they fight independently

**Elemental Properties**:
- Weakness: Fire (overheats circuits, +50% damage), Ice (slows actuators)
- Resistance: Physical (+25% — metal armor)
- Immune: None

**Drops**: Automaton Gear (20%), Circuit Board (5%), Energy Cell (3%).

**Implementation Notes**: Add `combat_mode` enum { MELEE, RANGED } to AI. Switch triggers animation change. Energy burst uses `AbilityData`-style projectile system.

---

#### 8. Tactical Officer

| Field | Value |
|-------|-------|
| Enemy ID | `tactical_officer` |
| Archetype | Commander |
| HP | 60 |
| ATK | 8 |
| DEF | 6 |
| Speed | Normal |
| Stagger Threshold | 35 |
| XP | 35 |
| Gold | 20-40 |
| Zones | Coastal Approach, Seaward Reactor, Abyssal Reactor |
| States | 2 |

**Behavior**: Stays mid-range. Buffs all allies within 15 feet: +25% attack speed, +10% damage (visible aura effect). Performs moderate sword attacks if engaged directly. Calls reinforcements (spawns 2 Garrison Soldiers) once per encounter when HP drops below 50%.

**AI Logic**:
- `preferred_combat_radius`: 12 feet
- `buff_radius`: 15 feet
- `buff_attack_speed`: 1.25x
- `buff_damage`: 1.1x
- `reinforce_threshold`: 50% HP (one-time)
- `reinforcement_count`: 2 Garrison Soldiers
- Group behavior: Positions centrally among allies to maximize buff coverage

**Elemental Properties**:
- Weakness: Wind (disrupts command aura briefly)
- Resistance: None
- Immune: None

**Drops**: Officer's Insignia (15%), Command Baton (3%), Tactical Map (5%).

**Implementation Notes**: Add `aura_buff` system — affects all enemies in radius. Buff removes when Officer dies or is staggered. Reinforcement spawn uses enemy spawn system with brief delay (troops run in from offscreen).

---

### Elite Military (4 types)

Elite variants of base enemies. Tougher stats, enhanced abilities, less common. Appear in harder zones and as mini-bosses.

---

#### E1. Ironclad Sergeant

| Field | Value |
|-------|-------|
| Enemy ID | `ironclad_sergeant` |
| Base | Garrison Soldier (enhanced) |
| HP | 100 |
| ATK | 14 |
| DEF | 10 |
| Speed | Normal |
| Stagger Threshold | 50 |
| XP | 50 |
| Gold | 30-60 |
| Zones | Irondeep Mines (mini-boss) |
| States | 2 |

**Behavior**: Enhanced Garrison Soldier. 4-hit combo (instead of 2). Guard-counter ability (parries player attack, instant counter-strike). Commands nearby soldiers (similar to Tactical Officer but weaker — +10% attack speed to allies within 10 feet).

**Elemental Properties**:
- Weakness: Fire (+25%)
- Resistance: Physical (+15%)

**Drops**: Sergeant's Blade (weapon, 20%), Ironclad Medal (accessory, 5%).

---

#### E2. Sniper Drone

| Field | Value |
|-------|-------|
| Enemy ID | `sniper_drone` |
| Base | Patrol Drone (enhanced) |
| HP | 40 |
| ATK | 18 |
| DEF | 3 |
| Speed | Fast |
| Stagger Threshold | 15 |
| XP | 35 |
| Gold | 15-35 |
| Zones | Ashveil Pass (elevated positions) |
| States | 2 |

**Behavior**: Higher altitude (12-15 feet). No dive attack — instead uses long-range precision shots with laser sight telegraph (red line, 2s warning). Higher damage per hit but longer cooldown (3s). Must be brought down with magic or jump attacks.

**Elemental Properties**:
- Weakness: Earth (+50% — grounds it), Ice (freezes rotors)
- Resistance: Wind (+75%)

**Drops**: Sniper Lens (accessory, 15%), Precision Core (3%).

---

#### E3. Reactor Sentinel

| Field | Value |
|-------|-------|
| Enemy ID | `reactor_sentinel` |
| Base | Security Automaton (enhanced) |
| HP | 90 |
| ATK | 14 |
| DEF | 12 |
| Speed | Normal |
| Stagger Threshold | 55 |
| XP | 45 |
| Gold | 25-50 |
| Zones | Coastal Approach, Seaward Reactor, Abyssal Reactor |
| States | 2 |

**Behavior**: Enhanced Automaton designed for reactor defense. Lumina-charged attacks (energy melee + burst). Self-repair ability (heals 15 HP every 15s if not damaged for 5s). Lumina shield (absorbs one hit every 20s — visual barrier effect).

**Elemental Properties**:
- Weakness: Fire (+40% — overheats Lumina circuits)
- Resistance: Physical (+30%), Ice (+15%)

**Drops**: Lumina Shard (20%), Sentinel Core (5%).

---

#### E4. Frost Trooper

| Field | Value |
|-------|-------|
| Enemy ID | `frost_trooper` |
| Base | Garrison Soldier (cold-specialized) |
| HP | 65 |
| ATK | 12 |
| DEF | 8 |
| Speed | Normal |
| Stagger Threshold | 35 |
| XP | 35 |
| Gold | 20-40 |
| Zones | Frostmere, Glacier Shelf, Shattered Coast |
| States | 2 |

**Behavior**: Cold-weather military specialist. Ice-infused melee attacks (slow player on hit — 20% speed reduction for 3s). Ice grenade (AOE, 2s telegraph, creates ice patch — slippery terrain for 5s). Resistant to cold environments.

**Elemental Properties**:
- Weakness: Fire (+50%)
- Resistance: Ice (+75% — cold-adapted gear)

**Drops**: Frost Blade Fragment (15%), Cold Weather Gear (accessory, 5%).

---

## Post-Ragnorak Corrupted Enemies

### Corrupted Types (8)

These enemies appear only in State 3 (or as rare foreshadowing in State 2 sidequests). They are the result of Lumina corruption — former soldiers twisted, energy given hostile form, machines overloaded with corrupt power.

---

#### C1. Corrupted Soldier

| Field | Value |
|-------|-------|
| Enemy ID | `corrupted_soldier` |
| Archetype | Melee Chaser (corrupted) |
| HP | 65 |
| ATK | 12 |
| DEF | 5 |
| Speed | Erratic |
| Stagger Threshold | 25 |
| XP | 30 |
| Gold | 15-30 |
| Zones | Greenhollow Corrupted, Corruption Scar, Fallen Ironhaven |
| States | 3 |

**Behavior**: Former Garrison Soldiers twisted by corruption. Movement is erratic — sudden lunges, stumbling pauses. Attack pattern is irregular (2-4 hits, unpredictable timing). Periodically screams (1.5s vulnerability window — head drops, fully exposed). More dangerous than base soldiers but with exploitable openings.

**AI Logic**:
- `preferred_combat_radius`: 4-8 feet (variable — erratic)
- `scream_interval`: 12-18 seconds (random)
- `scream_vulnerability`: 1.5 seconds
- `attack_pattern`: Random 2-4 hits (no fixed combo)
- Group behavior: Don't coordinate — they're not sane enough

**Elemental Properties**:
- Weakness: Light (+50%), Fire (+25%)
- Resistance: Dark (+25%)
- Immune: None

**Drops**: Corrupted Badge (20%), Twisted Blade Fragment (5%).

---

#### C2. Lumina Wraith

| Field | Value |
|-------|-------|
| Enemy ID | `lumina_wraith` |
| Archetype | Phase Attacker |
| HP | 45 |
| ATK | 14 |
| DEF | 3 |
| Speed | Fast |
| Stagger Threshold | 15 |
| XP | 35 |
| Gold | 20-35 |
| Zones | Glacier Shelf (foreshadow), Corruption Scar, Reactor Core |
| States | 2 (rare), 3 |

**Behavior**: Spectral entity made of corrupted Lumina energy. Phases in and out of visibility on a cycle (visible 4s → invisible 3s → repeat). While invisible: immune to physical, takes half magic damage. While visible: fully vulnerable, aggressive melee attacks (claw swipes). Teleports short distances (5-8 feet) instead of walking.

**AI Logic**:
- `visibility_cycle`: 4s visible / 3s invisible
- `phase_physical_immunity`: true when invisible
- `teleport_range`: 5-8 feet
- `attack_pattern`: 2-hit claw swipe, fast cooldown (1s)
- Group behavior: Wraiths can phase-attack from different angles simultaneously

**Elemental Properties**:
- Weakness: Light (+75% — dispels corruption)
- Resistance: Dark (+50%), Physical (+25% even when visible)
- Immune: Physical (when invisible)

**Drops**: Wraith Essence (25%), Spectral Shard (5%).

**Implementation Notes**: Needs visibility toggle system. Shader for fade in/out. Override `take_damage()` to check visibility state. Good test of player's target switching and timing.

---

#### C3. Crystal Stalker

| Field | Value |
|-------|-------|
| Enemy ID | `crystal_stalker` |
| Archetype | Fast Chaser |
| HP | 55 |
| ATK | 12 |
| DEF | 6 |
| Speed | Very Fast |
| Stagger Threshold | 20 |
| XP | 30 |
| Gold | 15-30 |
| Zones | Corruption Scar, Luminous Hollow, Reactor Core |
| States | 3 |

**Behavior**: Crystalline quadruped creature. Charges in straight lines (10 foot dash, 1s telegraph — crystals glow). During charge: reflects projectile magic back at caster. After charge: 2s recovery (slides to stop, vulnerable). Between charges: circles player at medium distance, performs swipe attacks.

**AI Logic**:
- `charge_telegraph`: 1.0 seconds (crystal glow + crouching pose)
- `charge_distance`: 10 feet (linear)
- `charge_reflect`: true (projectile magic reflected during dash)
- `charge_recovery`: 2.0 seconds
- `circle_radius`: 10 feet
- Group behavior: Stalkers stagger charge timing

**Elemental Properties**:
- Weakness: Earth (+40% — shatters crystal), Fire (+25%)
- Resistance: Ice (+50% — crystal structure resonates with cold)
- Special: Reflects projectile magic during charge

**Drops**: Crystal Fragment (25%), Stalker Fang (5%).

---

#### C4. Corruption Spewer

| Field | Value |
|-------|-------|
| Enemy ID | `corruption_spewer` |
| Archetype | Ranged AOE |
| HP | 50 |
| ATK | 8 (DOT) |
| DEF | 5 |
| Speed | Stationary |
| Stagger Threshold | 30 |
| XP | 30 |
| Gold | 15-30 |
| Zones | Greenhollow Corrupted, Corruption Scar, Reactor Core |
| States | 3 |

**Behavior**: Stationary corruption growth rooted in the ground. Lobs corruption globules in arcs (3s interval, 6ft AOE on impact). Impact creates DOT pool lasting 5s (3 damage/second to anything standing in it). Cannot move but rotates to track player. If melee attacked, releases burst (4ft AOE, knockback).

**AI Logic**:
- `attack_interval`: 3.0 seconds
- `lob_range`: 20 feet
- `impact_aoe`: 6 feet
- `dot_damage`: 3/second for 5s
- `melee_burst_aoe`: 4 feet (defensive)
- Group behavior: Multiple Spewers create overlapping DOT zones

**Elemental Properties**:
- Weakness: Fire (+50% — burns corruption), Dark (+25%)
- Resistance: Earth (+25% — rooted/grounded), Ice (+25%)
- Immune: None

**Drops**: Corruption Residue (30%), Spewer Core (5%).

---

#### C5. Hollow Beast

| Field | Value |
|-------|-------|
| Enemy ID | `hollow_beast` |
| Archetype | Stagger Brute (corrupted) |
| HP | 150 |
| ATK | 18 |
| DEF | 12 |
| Speed | Slow |
| Stagger Threshold | 90 |
| XP | 60 |
| Gold | 40-70 |
| Zones | Fallen Ironhaven, Corruption Scar (east), Reactor Core |
| States | 3 |

**Behavior**: Large corrupted beast — former draft animal or machine warped by Lumina. Has breakable parts: crystal growths on shoulders (2, each with 40 HP). Breaking a crystal growth: reduces DEF by 4, reduces stagger threshold by 20. At 30% HP: enrages — speed doubles, attack speed +50%, no longer flinches from any attack (permanent super-armor).

**AI Logic**:
- `preferred_combat_radius`: 5 feet
- `super_armor`: true during attacks (always)
- `breakable_parts`: [left_crystal: 40HP, right_crystal: 40HP]
- `enrage_threshold`: 30% HP
- `enrage_speed_multiplier`: 2.0x
- `enrage_attack_speed`: 1.5x
- Group behavior: Other enemies give Hollow Beast wide berth

**Elemental Properties**:
- Weakness: Light (+40%), Fire (+25%)
- Resistance: Dark (+25%), Physical (+15%)
- Immune: None
- Crystal growths: Weak to Ice (+75%)

**Drops**: Beast Hide (20%), Hollow Core (5%), Crystal Growth (from breakable parts, 100%).

**Implementation Notes**: First enemy with breakable parts system. Each crystal growth is a separate hurtbox with its own HP. Extend `EnemyBase` with `breakable_parts` array. Enrage state modifies stats at threshold.

---

#### C6. Spirit Mender

| Field | Value |
|-------|-------|
| Enemy ID | `spirit_mender` |
| Archetype | Support (corrupted) |
| HP | 35 |
| ATK | 5 |
| DEF | 3 |
| Speed | Fast |
| Stagger Threshold | 12 |
| XP | 35 |
| Gold | 20-35 |
| Zones | Corruption Scar, Fallen Ironhaven, Reactor Core |
| States | 3 |

**Behavior**: Spectral support entity. Heals corrupted allies (25 HP every 6s). Buffs one ally with corruption shield (absorbs 30 damage, purple barrier visual). If player approaches within 8 feet, teleports away (10-15 foot teleport, 4s cooldown). Weak in direct combat — priority kill target.

**AI Logic**:
- `heal_interval`: 6.0 seconds
- `heal_amount`: 25 HP
- `shield_interval`: 12.0 seconds
- `shield_absorb`: 30 damage
- `teleport_trigger_distance`: 8 feet
- `teleport_range`: 10-15 feet
- `teleport_cooldown`: 4.0 seconds
- Group behavior: Stays as far from player as possible while within heal range of allies

**Elemental Properties**:
- Weakness: Light (+75% — disrupts spirit form)
- Resistance: Dark (+50%)
- Immune: None

**Drops**: Spirit Dust (25%), Mending Crystal (5%).

---

#### C7. Corrupted Automaton

| Field | Value |
|-------|-------|
| Enemy ID | `corrupted_automaton` |
| Archetype | Hybrid (corrupted) |
| HP | 90 |
| ATK | 14 |
| DEF | 10 |
| Speed | Normal |
| Stagger Threshold | 45 |
| XP | 45 |
| Gold | 25-50 |
| Zones | Fallen Ironhaven, Reactor Core |
| States | 3 |

**Behavior**: Security Automaton overloaded with corrupt Lumina. Melee attacks apply corruption DOT (2 damage/second for 4s). Ranged energy burst now corrupted (larger AOE: 7ft, leaves DOT pool 3s). Unique mechanic: overloads every 20s — sparks wildly for 2s (damages everything nearby, 5ft AOE, including allies), then stunned for 3s (fully vulnerable).

**AI Logic**:
- `melee_dot`: 2 damage/s for 4s
- `burst_aoe`: 7 feet + DOT pool (3s)
- `overload_interval`: 20 seconds
- `overload_aoe`: 5 feet (hurts allies too)
- `overload_stun`: 3.0 seconds
- Group behavior: Other enemies avoid being near Corrupted Automaton during overload

**Elemental Properties**:
- Weakness: Ice (+40% — counters overheated circuits), Light (+25%)
- Resistance: Physical (+30% — metal body)
- Immune: None

**Drops**: Corrupted Circuit (20%), Overloaded Core (5%).

---

#### C8. Void Sentinel

| Field | Value |
|-------|-------|
| Enemy ID | `void_sentinel` |
| Archetype | Tank AOE |
| HP | 130 |
| ATK | 16 |
| DEF | 14 |
| Speed | Slow |
| Stagger Threshold | 70 |
| XP | 55 |
| Gold | 35-60 |
| Zones | Corruption Scar (east), Reactor Core |
| States | 3 |

**Behavior**: Massive dark-energy construct. Projects Darkness Field (10ft AOE around itself — all players inside take 2 damage/second and have -15% accuracy). Heavy melee swings (wide arc, 2.5s telegraph). Periodically plants Void Anchor (immobile dark crystal that extends Darkness Field by 8ft — has 30 HP, destroyable).

**AI Logic**:
- `darkness_field_radius`: 10 feet
- `field_dot`: 2 damage/s
- `field_debuff`: -15% accuracy
- `void_anchor_hp`: 30
- `void_anchor_interval`: 15 seconds
- `void_anchor_extension`: 8 feet
- `attack_telegraph`: 2.5 seconds
- Group behavior: Other corrupted enemies benefit from Darkness Field (take reduced Light damage inside it)

**Elemental Properties**:
- Weakness: Light (+75% — directly opposes Dark energy)
- Resistance: Physical (+25%), Fire (+15%)
- Immune: Dark (absorbs Dark damage as healing)

**Drops**: Void Fragment (20%), Dark Crystal (5%).

**Implementation Notes**: Area-effect enemy. Darkness Field is a persistent Area3D with visual shader. Void Anchors are destructible spawned objects. Teaching player to use Light element and destroy anchors to control the battlefield.

---

## Boss Encounters (7)

Bosses are unique, multi-phase encounters with specific mechanics. Each tests different player skills and systems.

### Boss Design Principles
- All bosses have **2+ phases** with distinct behavior shifts
- Phase transitions trigger at HP thresholds
- Each boss has at least one **exploitable weakness window**
- Boss stagger creates **bonus damage windows** (not just interrupts)
- All bosses respect the **enemy spacing rule** (never overlap player)
- Boss lock-on uses **priority lock-on point** (stays centered)
- Boss arenas have defined boundaries
- Boss music triggers on encounter start

---

### Boss 1: Mine Overseer Grendl

| Field | Value |
|-------|-------|
| Boss ID | `boss_grendl` |
| Zone | Irondeep Mines |
| HP | 500 |
| ATK | 15 |
| DEF | 10 |
| Phases | 2 |
| Level | 9-10 |
| State | 2 |
| Reward | Rare weapon, story progression |

**Lore**: Former mine overseer fused with industrial equipment by Lumina exposure. First boss — tests basic combat mastery.

**Phase 1 (100-50% HP) — "The Drill"**:
- Primary attack: Drill arm thrust (linear, 8ft range, 1.5s telegraph)
- Secondary: Sweeping drill spin (360°, 5ft range, 2s telegraph)
- Breakable part: Drill arm (100 HP — when broken, phase 2 triggers early)
- Adds: Summons 2 Garrison Soldiers every 30s (max 4 on field)
- Weakness window: After drill spin — 2s recovery

**Phase 2 (50-0% HP or drill broken) — "The Hammer"**:
- Drill arm broken → switches to mining hammer
- Primary: Overhead slam (AOE circle, 6ft, 2s telegraph)
- Secondary: Explosive charge throw (arcing projectile, 4ft AOE on impact)
- No more adds — Grendl fights alone
- Faster attack cadence (1.5x)
- Weakness window: After overhead slam — 1.5s recovery, hammer stuck in ground

**Elemental Properties**:
- Weakness: Fire (+30% — overheats machinery), Wind (+20% — disrupts charges)
- Resistance: Earth (+25% — underground/grounded)
- Drill arm: Weakness Fire (+50%)

**Arena**: Circular mining chamber, ~30ft diameter. Rubble pillars for cover (destructible after 2 hits). Dim lighting with Lumina veins on walls.

---

### Boss 2: Reactor Warden Aquos

| Field | Value |
|-------|-------|
| Boss ID | `boss_aquos` |
| Zone | Seaward Reactor |
| HP | 700 |
| ATK | 18 |
| DEF | 12 |
| Phases | 2 |
| Level | 12-13 |
| State | 2 |
| Reward | Reactor keycard, rare equipment, Frostmere access |

**Lore**: Lumina-powered aquatic defense system. Designed to protect the reactor core from intruders. Operates in concert with the reactor's water systems.

**Phase 1 (100-40% HP) — "Pressure Control"**:
- Primary: Water pressure lance (straight beam, 15ft range, sweeps 90°, 2s charge)
- Secondary: Hydro bomb (lobbed water sphere, 6ft AOE, creates slippery zone 5s)
- Environmental: Periodically floods sections of arena (3 of 6 sectors fill with water every 20s, rotate — forces repositioning)
- Barrier shell: Transparent water barrier absorbs first 50 damage of any attack, regenerates every 15s
- Weakness window: Immediately after barrier breaks — 3s vulnerability

**Phase 2 (40-0% HP) — "Rising Tide"**:
- Arena water level rises — safe area shrinks to 60% of original
- Water jet dash: Rapid movement through flooded areas (Aquos gains speed in water)
- Pressure burst: Close-range AOE (8ft, used after dashing near player)
- Water prison: Targets one player, creates water sphere (3s — mash to escape, allies can attack sphere to free faster)
- Faster attack cadence
- Weakness window: After water prison (whether player escapes or sphere is broken) — 2s recovery

**Elemental Properties**:
- Weakness: Ice (+40% — freezes water attacks, creates openings), Earth (+25% — grounds water)
- Resistance: Fire (+25% — water environment), Wind (+15%)
- Immune: None
- Barrier: Weak to Ice (+100% — freezes and shatters instantly)

**Arena**: Hexagonal reactor chamber, ~40ft diameter. 6 sectors divided by low walls. Water inlet channels on 3 sides. Elevated safe platform in center (small, ~8ft).

---

### Boss 3: Frostmere Colossus (Optional)

| Field | Value |
|-------|-------|
| Boss ID | `boss_colossus` |
| Zone | Glacier Shelf Route |
| HP | 600 |
| ATK | 20 |
| DEF | 14 |
| Phases | 2 |
| Level | 15-17 |
| State | 2 |
| Optional | Yes |
| Reward | Rare ice equipment, crafting materials |

**Lore**: Ancient Lumina construct frozen in the glacier, awakened by destabilizing energy. Not hostile by nature — awakened in confusion and pain.

**Phase 1 (100-40% HP) — "Frozen Wrath"**:
- Primary: Ice slam (one fist, 8ft AOE, 2.5s telegraph — arm raises high)
- Secondary: Ice wall (creates ice barrier across arena, blocks movement, destructible — 60 HP each)
- Frost breath: Cone attack (12ft range, 60° arc, 3s channel — dodge sideways)
- Creates ice patches on ground (slippery terrain, 8s duration)
- Weakness window: After ice slam — fist stuck in ground 2s

**Phase 2 (40-0% HP) — "Shattered Rage"**:
- Enrage: Attack speed +40%, moves faster
- Ice spike eruption: Ground spikes in line toward player (10ft range, 1.5s telegraph — ground cracks visible)
- Double slam: Both fists (12ft AOE, devastating but 3s telegraph)
- No more ice walls — too enraged for strategy
- Weakness window: After double slam — both fists stuck 2.5s (biggest opening in fight)

**Elemental Properties**:
- Weakness: Fire (+50%)
- Resistance: Wind (+25%)
- Immune: Ice (heals from Ice attacks)

**Arena**: Open glacier platform, ~45ft diameter. Ice-covered ground (baseline slippery — reduced traction). Mountain backdrop. Northern lights above.

---

### Boss 4: Corrupted Guardian

| Field | Value |
|-------|-------|
| Boss ID | `boss_corrupted_guardian` |
| Zone | Corruption Scar |
| HP | 800 |
| ATK | 20 |
| DEF | 10 |
| Phases | 3 |
| Level | 21-22 |
| State | 3 |
| Reward | Light element unlock, Light equipment |

**Lore**: Former Lumina construct twisted into a corruption nexus. The first truly corrupted boss — marks the tonal shift of State 3 combat.

**Phase 1 (100-60% HP) — "Corruption Beams"**:
- Primary: Corruption beam (straight line, 20ft, sweeps slowly — dodge through or behind)
- Secondary: Corruption orb volley (3 orbs, arcing, 4ft AOE each)
- Summons Wraith adds (2 Lumina Wraiths every 45s)
- Weakness window: After beam sweep completes — 2s cooldown

**Phase 2 (60-30% HP) — "Closing In"**:
- Arena shrinking: Corruption closes in from edges (10ft lost every 30s until 60% original size)
- Enhanced beam: Now sweeps 270° (must get behind Guardian)
- Corruption pulse: AOE around Guardian (8ft, 3s telegraph — ground glows)
- Wraith adds continue (more aggressive — 2 every 30s)
- Weakness window: After corruption pulse — 3s recovery (Guardian's core exposed)

**Phase 3 (30-0% HP) — "Split"**:
- Guardian splits into 2 fragments (400 HP each, shared remaining HP pool)
- Each fragment uses half the moveset (one beams, one pulses)
- If one fragment dies, the other heals 50 HP and enrages
- Must defeat both within 30s of each other (or they reform at 30% HP)
- Weakness window: When both fragments use their attacks simultaneously — brief period where both are recovering

**Elemental Properties**:
- Weakness: Light (+60% — first boss where Light matters)
- Resistance: Dark (+50%), Physical (+15%)
- Immune: None

**Arena**: Corruption crater, ~35ft diameter. Edges are corruption wall (damaging). Ground has scattered corruption pools (DOT zones). Central platform is safe ground.

---

### Boss 5: Corrupted Commander

| Field | Value |
|-------|-------|
| Boss ID | `boss_corrupted_commander` |
| Zone | Fallen Ironhaven |
| HP | 900 |
| ATK | 22 |
| DEF | 12 |
| Phases | 2 |
| Level | 23-24 |
| State | 3 |
| Reward | Dark element unlock, Dark equipment, Stabilizer Beta |

**Lore**: Former military commander of Ironhaven garrison. Corruption has twisted but not fully consumed — recognizable as human in Phase 1. Emotional encounter — this was an ally.

**Phase 1 (100-50% HP) — "The Officer"**:
- Still recognizably human. Military fighting style.
- Primary: 4-hit sword combo (disciplined, telegraphed)
- Secondary: Command shout (buffs self: +20% speed for 10s)
- Summons corrupted soldier adds (3 Corrupted Soldiers, once at 80% HP and once at 60% HP)
- Uses cover and tactical positioning (retreats behind pillars)
- Weakness window: After 4-hit combo — 2s recovery (military discipline means predictable patterns)

**Phase 2 (50-0% HP) — "The Corruption"**:
- Transformation cutscene — corruption fully takes over. Grows larger, sword becomes corruption blade.
- Loses military discipline — gains raw power
- Primary: Wide corruption slash (180° arc, 10ft range, 1.5s telegraph)
- Secondary: Corruption ground pound (12ft AOE, 2s telegraph)
- Corruption charge: Linear dash (15ft, fast — 1s telegraph)
- No more adds — fight becomes 1v1
- Loses tactical positioning — charges mindlessly
- Weakness window: After corruption charge — slides and stumbles 2s

**Elemental Properties**:
- Phase 1: Weakness Fire (+25%), Light (+15%). Resistance: None.
- Phase 2: Weakness Light (+50%). Resistance: Physical (+20%), Fire (+10%). Dark heals.

**Arena**: Ironhaven military HQ courtyard, ~40ft. Destroyed pillars (partial cover, destructible). Corrupted Lumina veins on walls. Familiar location — player was here in State 1.

---

### Boss 6: Hollow Guardian (Optional)

| Field | Value |
|-------|-------|
| Boss ID | `boss_hollow_guardian` |
| Zone | Luminous Hollow |
| HP | 750 |
| ATK | 18 |
| DEF | 10 |
| Phases | 2 |
| Level | 25-26 |
| State | 3 |
| Optional | Yes |
| Reward | Lyra joins party |

**Lore**: Crystal entity guarding/imprisoning Lyra. Not purely malevolent — it's protecting the crystal resonance from disruption. Defeating it frees Lyra.

**Phase 1 (100-50% HP) — "Crystal Defense"**:
- Primary: Crystal projectile barrage (5 crystals in spread, 15ft range, 2s charge)
- Secondary: Crystal wall (blocks area, 80 HP per wall, creates arena segments)
- Crystal beam: Reflected off crystal walls (bounces — positioning matters)
- Resonance pulse: AOE hum (10ft, 2s telegraph — screen distortion visual)
- Weakness window: After crystal barrage — 2s before next attack

**Phase 2 (50-0% HP) — "Shattered Guardian"**:
- Splits into 3 smaller crystal entities (250 HP each, share remaining HP pool)
- Each entity uses one attack type (projectiles / walls / beam)
- Must defeat all 3 — tests party coordination (switch targets)
- Entities periodically reconnect (every 20s, brief heal of 25 HP each, then split again)
- Weakness window: During reconnection — all 3 merge into one target for 3s

**Elemental Properties**:
- Weakness: Light (+40%), Fire (+30%)
- Resistance: Dark (+40%), Ice (+30%)
- Crystal walls: Neutral to all elements

**Arena**: Crystal cavern, ~35ft diameter. Crystal formations create partial cover. Luminescent — beautiful but dangerous. Lyra's crystal prison visible in background.

---

### Boss 7: Ragnorak Avatar (Final Boss)

| Field | Value |
|-------|-------|
| Boss ID | `boss_ragnorak_avatar` |
| Zone | Reactor Core Descent |
| HP | 2000 |
| ATK | 25 |
| DEF | 15 |
| Phases | 4 |
| Level | 29-30 |
| State | 3 |
| Reward | Game completion |

**Lore**: The manifestation of destabilized Lumina itself. Not a creature — a force of nature given hostile form. The culmination of every combat system the player has learned.

**Phase 1 (100-75% HP) — "Elemental Rotation"**:
- Cycles through 4 elements every 15s: Fire → Ice → Wind → Earth
- Each element phase uses different attacks:
  - Fire: Flame pillars (3 locations, 6ft AOE each, 2s telegraph)
  - Ice: Ice wave (expanding ring, must jump over, 1.5s telegraph)
  - Wind: Tornado pull (draws player toward Avatar, strong suction 3s)
  - Earth: Ground eruption (tracking, follows player path, 2s delay)
- Player must exploit elemental weakness of current phase
- Weakness window: During element transition — 3s of no attacks

**Phase 2 (75-50% HP) — "Gravity Shift"**:
- Arena rotates — gravity shifts direction (visual: entire room tilts 90°)
- New surfaces become floor — repositioning required
- Corruption field zones appear on old surfaces
- Avatar attacks: Gravity slam (pulls then pushes, 12ft AOE), Lumina lance (straight line, 25ft)
- Gravity shifts every 30s — new floor each time
- Weakness window: During gravity shift — Avatar anchors itself, immobile 4s

**Phase 3 (50-25% HP) — "Light and Dark Split"**:
- Avatar splits into Light half and Dark half
- Light half: Uses Light-element attacks (beams, flash AOE). Weak to Dark. Heals from Light.
- Dark half: Uses Dark-element attacks (shadow field, void bolts). Weak to Light. Heals from Dark.
- Must damage both — if one dies 15s before the other, it reforms at 10% HP
- Both halves attack simultaneously — party management critical
- Weakness window: When halves' attacks collide (Light beam meets Dark bolt — explosion stuns both 2s)

**Phase 4 (25-0% HP) — "All as One"**:
- Halves reform into complete Avatar — now uses ALL elements
- Attack pattern: Rapid-fire mix of all 6 elements (no rotation, random selection)
- Corruption cascade: Arena slowly fills with corruption from edges (DPS check — can't stall forever)
- Avatar uses enhanced versions of all previous phase mechanics
- Enrage at 10% HP: Attack speed doubles for final push
- Weakness window: Every 20s, Avatar channels a massive attack (5s charge — vulnerable during charge, but devastating if not interrupted or killed)

**Elemental Properties**:
- Phase 1: Weak to opposite of current element cycle (Fire→Ice, Ice→Fire, Wind→Earth, Earth→Wind) +40%
- Phase 2: Neutral to all, slightly weak to Light/Dark (+20% each)
- Phase 3 Light half: Weak to Dark (+60%), Immune to Light
- Phase 3 Dark half: Weak to Light (+60%), Immune to Dark
- Phase 4: Rotates weaknesses rapidly. All elements deal normal damage. Light+Dark most consistent (+25% each)

**Arena**: Ancient Lumina source chamber, ~50ft diameter. Largest arena. Lumina core visible in center (environmental feature, not targetable). Ancient architecture. Gravity-capable surfaces on walls/ceiling for Phase 2.

---

## Elemental Weakness Summary Table

### Pre-Ragnorak Enemies

| Enemy | Fire | Ice | Wind | Earth | Light | Dark |
|-------|------|-----|------|-------|-------|------|
| Garrison Soldier | — | — | — | — | N/A | N/A |
| Shield Guard | — | — | **W** | R | N/A | N/A |
| Military Rifleman | — | — | — | **W** | N/A | N/A |
| Patrol Drone | — | W | R | **W** | N/A | N/A |
| Heavy Trooper | R | **W** | — | R | N/A | N/A |
| Combat Medic | **W** | — | W | — | N/A | N/A |
| Security Automaton | **W** | W | — | — | N/A | N/A |
| Tactical Officer | — | — | **W** | — | N/A | N/A |
| Ironclad Sergeant | **W** | — | — | — | N/A | N/A |
| Sniper Drone | — | W | R | **W** | N/A | N/A |
| Reactor Sentinel | **W** | R | — | — | N/A | N/A |
| Frost Trooper | **W** | R | — | — | N/A | N/A |

**W** = Weakness, **R** = Resistance, — = Neutral, N/A = Not available in this state

### Post-Ragnorak Enemies

| Enemy | Fire | Ice | Wind | Earth | Light | Dark |
|-------|------|-----|------|-------|-------|------|
| Corrupted Soldier | W | — | — | — | **W** | R |
| Lumina Wraith | — | — | — | — | **W** | R |
| Crystal Stalker | W | R | — | **W** | — | — |
| Corruption Spewer | **W** | R | — | R | — | W |
| Hollow Beast | W | — | — | — | **W** | R |
| Spirit Mender | — | — | — | — | **W** | R |
| Corrupted Automaton | — | **W** | — | — | W | — |
| Void Sentinel | R | — | — | — | **W** | I |

**W** = Weakness, **R** = Resistance, **I** = Immune (heals from)

### Design Intent
- Pre-Ragnorak: Fire and Earth are the most broadly useful elements (military/machine enemies)
- Post-Ragnorak: Light is king against corruption (designed reward for unlocking it)
- Dark is niche but powerful against specific targets
- No enemy is immune to everything — always a viable approach
- Elemental variety encourages party diversity (different characters access different elements)

---

## Enemy Count Summary

| Category | Count |
|----------|-------|
| Base Military | 8 |
| Elite Military | 4 |
| Corrupted | 8 |
| Bosses | 7 |
| **Total** | **27** |

### Enemies by Zone Density

| Zone Type | Enemy Placement Range | Notes |
|-----------|----------------------|-------|
| Field zones | 6-10 enemy placements | Patrols, static guards, roamers |
| Dungeons | 8-15 enemy placements | Denser, room-based encounters |
| Reactor dungeons | 10-18 enemy placements | Highest density, restricted spaces |
| Towns | 0 (State 1-2), 2-4 (State 3 variants) | Safe havens, corrupted edges |
| Boss arenas | Boss + 0-4 adds | Focused encounters |

---

## Implementation Notes

### Extending EnemyBase

New enemy types extend `EnemyBase` with these additional systems:

```
# Systems needed for full bestiary
- Ranged attack (projectile spawner) — Rifleman, Drone, Spewer, bosses
- Frontal block / directional defense — Shield Guard
- Flying enemy movement — Drones (patrol, sniper)
- Super-armor (no flinch during attacks) — Heavy Trooper, Hollow Beast
- Heal/buff ally behavior — Combat Medic, Spirit Mender, Tactical Officer
- Mode switching (melee/ranged) — Automatons
- Breakable parts (sub-hurtboxes) — Hollow Beast, Grendl
- Visibility phasing — Lumina Wraith
- DOT attacks / ground pools — Spewer, Corrupted Automaton
- Enrage state (stat changes at HP threshold) — Hollow Beast, Colossus
- Reinforcement spawning — Tactical Officer, bosses
- Area effects (darkness field, buff aura) — Void Sentinel, Tactical Officer
```

### Enemy AI Priority

1. **Garrison Soldier** — Already exists. Baseline.
2. **Shield Guard** — Teaches flanking and elemental weakness.
3. **Military Rifleman** — Teaches gap closing and target priority.
4. **Patrol Drone** — Teaches aerial combat and magic usage.
5. **Heavy Trooper** — Teaches patience and stagger system.
6. **Combat Medic** — Teaches target prioritization.
7. **Security Automaton** — Teaches mode adaptation.
8. **Tactical Officer** — Teaches commander targeting.

Each enemy teaches a combat lesson. Together they prepare the player for corrupted enemies and bosses.
