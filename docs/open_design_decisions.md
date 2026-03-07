# Open Design Decisions — Project Ragnorak

Decisions that need resolution before or during implementation.

## RESOLVED

### Camera Type
**Decision**: Perspective third-person (NOT isometric/orthographic)
**Rationale**: FF7R uses close third-person perspective. Orthographic compresses depth, making range estimation harder for melee combat.

### Dodge Invulnerability
**Decision**: NO invulnerability frames
**Rationale**: Dodge is purely positional evasion. Player avoids attacks by physically moving out of hitbox range.

### Spell Canceling
**Decision**: Spells CANNOT cancel into dodge
**Rationale**: Committed casting creates risk/reward. Enemies punish poorly-timed spells (FF7R pattern).

### Time Scale Conflicts
**Decision**: Priority stack system in GameManager
**Rationale**: Prevents hit stop (scale=0.0) and tactical mode (scale=0.1) from corrupting each other.

## UNRESOLVED — Need Answers

### 1. Sprint Input
**Problem**: No sprint button defined. LT is Tactical Menu. The finalfantasy3d reference had sprint on LT/Shift.
**Options**:
- A) No sprint — run speed is the only ground speed
- B) Auto-sprint after holding movement for N seconds
- C) Double-tap movement direction to sprint
- D) Assign sprint to another button (e.g., Left Stick Click / L3)
**Impact**: Affects world traversal pacing and level design distances.

### 2. Y-Button Context Collision
**Problem**: Y is mapped to Interact. In combat near an interactable (NPC, chest), pressing Y could misfire.
**Options**:
- A) Context-based: Y interacts when interactable is in range and NOT in combat state; otherwise ignored
- B) Interact only works when InteractionAnchor detects an overlapping interactable AND player is in Idle/Run state (not combat states)
- C) Add a visual prompt that only appears when interaction is valid
**Recommendation**: Option B — state-aware interaction. Combat states never process interact input.

### 3. Death / Game Over / Respawn
**Problem**: Not specified anywhere in the design docs.
**Options**:
- A) Respawn at last checkpoint / save point with full HP
- B) Respawn at zone entrance with HP penalty
- C) Game Over screen -> reload last save
- D) Respawn at nearest rest point, enemies reset
**Impact**: Affects save system (checkpoint data), world design (rest point placement), difficulty curve.
**Recommendation**: Option C for now (simplest). Game Over -> Load Last Save. Can add checkpoints later.

### 4. Damage Formula
**Problem**: No damage calculation formula specified.
**Options**:
- A) Simple: `damage = attacker.attack - defender.defense` (minimum 1)
- B) Multiplier: `damage = attacker.attack * multiplier / (1 + defender.defense / 100)`
- C) FF-style: `damage = (attacker.attack * ability_power / 16) * (1 - defender.defense / (defender.defense + 100))`
**Recommendation**: Start with Option A, tune later. Keep damage formula in a single utility function for easy swapping.

### 5. ATB Fill Rate Design
**Problem**: ATB fills passively (5.0/sec base). Should basic attacks also fill ATB?
**FF7R Reference**: ATB fills from dealing and receiving damage. Basic attacks are the primary fill source.
**Options**:
- A) Passive only (current implementation)
- B) Passive + bonus on basic attack hit
- C) No passive fill — only from attacks (forces aggression)
**Recommendation**: Option B — passive provides a baseline, attacks accelerate. This incentivizes melee engagement before opening tactical menu.
**Values to tune**: passive_rate=2.0/sec, per_hit_bonus=8.0, combo_finisher_bonus=15.0

### 6. Art Pipeline Source
**Problem**: No 3D models, animations, or textures. Everything is capsule placeholders.
**Options**:
- A) Mixamo — free rigged characters + animations, retargeting needed
- B) Asset store — Synty, KayKit, etc. stylized packs
- C) Custom Blender — highest quality, highest cost
- D) Hybrid — Mixamo animations on asset store characters
**Impact**: Affects skeleton bone naming, animation retargeting, equipment visual pipeline.
**Recommendation**: Decision needed before Phase 2 (locomotion animations).

### 7. Heavy Attack / Combo Branching
**Problem**: FF7R has heavy attacks that branch from combos. Current design has 3-hit chain only.
**Options**:
- A) Add Heavy Finisher (Y button during combo) — branches from Attack1 or Attack2
- B) Hold attack button for charged heavy
- C) No heavy attack — differentiate through abilities only
**Note**: Y is Interact, so Option A conflicts with decision #2. If heavy attack is desired, it needs a different input.
**Possible**: Use a combo of attack + direction (back + attack = heavy)

### 8. Enemy Respawn Behavior
**Design doc says**: "Enemy states reset per zone"
**Clarification needed**: Does this mean:
- A) Enemies respawn every time the player re-enters the zone
- B) Enemies respawn only on game load (save/load cycle)
- C) Enemies respawn after N minutes real-time
**Recommendation**: Option A — simplest, provides farming opportunities, matches design doc wording.

### 9. Fast Travel
**Problem**: Semi-open world may become tedious without fast travel.
**Options**:
- A) No fast travel — world is small enough to traverse
- B) Waypoints discovered in each zone, fast travel between discovered waypoints
- C) Town-only teleport items
**Recommendation**: Defer to Phase 12. Design zones to be walkable without it first.

### 10. Knockdown State
**Referenced in**: Illegal transitions (Knockdown cannot execute abilities, cannot enter tactical)
**Not defined**: What triggers knockdown? How long? Can enemies be knocked down? Animation?
**Recommendation**: Define as a heavier version of Flinch. Trigger: specific enemy attacks or threshold damage. Duration: 1.0-1.5s (longer than Flinch's 0.4s). Player on ground, must stand up. Both player and enemies can be knocked down.
