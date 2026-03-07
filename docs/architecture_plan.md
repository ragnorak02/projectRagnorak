# Architecture Plan — Project Ragnorak

## Engine & Renderer
- Godot 4.6, Forward+ renderer, 1920x1080, perspective 3D
- MSAA 2x anti-aliasing enabled

## Physics Layers (10 defined)
| Layer | Name | Purpose |
|-------|------|---------|
| 1 | World | Static geometry, floors, walls |
| 2 | PlayerBody | Player CharacterBody3D collision |
| 3 | EnemyBody | Enemy CharacterBody3D collision |
| 4 | PlayerHitbox | Player attack Area3D |
| 5 | EnemyHitbox | Enemy attack Area3D |
| 6 | PlayerHurtbox | Player damage receiver Area3D |
| 7 | EnemyHurtbox | Enemy damage receiver Area3D |
| 8 | LockOnDetection | Lock-on scanning area |
| 9 | Interaction | Interactable objects, NPCs, chests |
| 10 | Navigation | Navigation mesh regions |

## Autoloads (6 total)
1. **Events** — Signal bus (40+ signals across all domains)
2. **GameManager** — Game state enum, time scale priority stack, hit stop
3. **InputManager** — Device detection (controller vs KB/M), movement/camera helpers
4. **AudioManager** — SFX pool (8 players) + music player
5. **SaveManager** — Autosave, 3 manual slots, quicksave (blocked in combat)
6. **DebugFlags** — 8 debug toggles (all default false)

## State Machine Architecture

### Design Decision: Single Machine with Domain Organization
Using a single `StateMachine` node with all states as children, but organized by domain in the file system. This provides the stability of one transition authority while maintaining the organizational clarity of domain separation.

**Why not six separate machines:**
- Velocity ownership conflicts (who controls `velocity` when combat and locomotion both want it?)
- Process order dependencies between machines
- State conflicts require a coordinator anyway, adding complexity without benefit
- The finalfantasy3d reference project proves the single-machine pattern works

**State organization:**
```
src/player/states/
  state.gd              # Base class
  state_machine.gd      # With illegal transition blocking
  idle_state.gd          # Locomotion domain
  run_state.gd           # Locomotion domain
  jump_state.gd          # Locomotion domain
  fall_state.gd          # Locomotion domain
  land_state.gd          # Locomotion domain
  dodge_state.gd         # Combat/Locomotion
  attack_1_state.gd      # Combat domain
  attack_2_state.gd      # Combat domain
  attack_3_state.gd      # Combat domain
  jump_attack_state.gd   # Combat domain
  ability_state.gd       # Combat domain
  flinch_state.gd        # Combat domain
  lock_on_idle_state.gd  # Targeting domain
  lock_on_strafe_state.gd # Targeting domain
  tactical_idle_state.gd # Tactical domain
```

### Illegal Transitions (enforced in StateMachine)
- Ability -> Dodge (spells cannot cancel into dodge)
- Flinch -> TacticalIdle (stunned cannot enter tactical)
- Flinch -> Ability (stunned cannot use abilities)
- Future: Knockdown -> Ability, Dead -> any movement

### State Transition Map
```
Idle <-> Run (movement input)
Idle/Run -> Jump (jump input + grounded)
Jump -> Fall (velocity.y < 0)
Fall -> Land (is_on_floor)
Land -> Idle/Run (timer + input)

Idle/Run -> Attack1 -> Attack2 -> Attack3 -> Idle (combo chain)
Attack1/2/3 -> Dodge (cancel allowed)
Idle/Run -> Dodge -> Idle (cooldown-gated)
Jump/Fall -> JumpAttack -> Land/Fall

Idle/Run -> LockOnIdle <-> LockOnStrafe (lock-on toggle)
LockOnIdle/LockOnStrafe -> Attack1/Dodge/Jump/Ability

Idle/Run/LockOnIdle -> TacticalIdle -> Idle (tactical menu)
Any + hurt signal -> Flinch -> Idle (forced transition)
```

## System Ownership Rules
Each system owns its domain and communicates via Events signals:
- **PlayerController** — movement input, velocity calculation
- **CombatSystem** — combo flow, hitbox activation, damage calculation
- **AbilitySystem** — spell/skill execution, MP/ATB gating
- **TargetingSystem** (LockOnComponent) — target acquisition, switching, release
- **CameraRig** — orbit, collision avoidance, lock-on framing
- **TacticalMenu** — slow-time, ability selection UI
- **EnemyBrain** (EnemyBase AI states) — aggro, pursuit, attack patterns

**Signal vs Direct Access rule:**
- Commands (cause side effects) -> use Events signals
- Queries (read-only) -> direct property access is acceptable
- Example: `player.is_locked_on` is a read; `Events.lock_on_target_acquired.emit()` is a command

## Scene Tree Discipline

### Player Scene Tree
```
Player (CharacterBody3D)
  +-- CollisionShape3D (CapsuleShape3D, r=0.4, h=1.8)
  +-- VisualRoot (Node3D)
  |     +-- MeshInstance3D (placeholder capsule)
  +-- HitboxAnchor (Node3D)
  |     +-- Hitbox (Area3D + CollisionShape3D)
  +-- Hurtbox (Area3D + CollisionShape3D)
  +-- CameraAnchor (Marker3D)
  +-- InteractionAnchor (Area3D + CollisionShape3D)
  +-- LockOnComponent (Node)
  +-- StatsComponent (Node)
  +-- StateMachine (Node)
        +-- Idle (State)
        +-- Run (State)
        +-- Jump (State)
        +-- Fall (State)
        +-- Land (State)
        +-- Dodge (State)
        +-- Attack1 (State)
        +-- Attack2 (State)
        +-- Attack3 (State)
        +-- JumpAttack (State)
        +-- Ability (State)
        +-- Flinch (State)
        +-- LockOnIdle (State)
        +-- LockOnStrafe (State)
        +-- TacticalIdle (State)
```

### Enemy Scene Tree
```
Enemy (CharacterBody3D)
  +-- CollisionShape3D (CapsuleShape3D)
  +-- NavigationAgent3D
  +-- VisualRoot (Node3D)
  |     +-- MeshInstance3D (placeholder)
  +-- Hurtbox (Area3D + CollisionShape3D)
  +-- AttackOrigin (Marker3D)
  +-- AggroArea (Area3D + CollisionShape3D, sphere r=12)
  +-- LockOnPoint (Marker3D)
```

### Camera Rig Scene Tree
```
CameraRig (Node3D)
  +-- YawPivot (Node3D)
        +-- PitchPivot (Node3D)
              +-- SpringArm3D (length=5.0)
                    +-- Camera3D (perspective, fov=60)
```

## Time Scale Priority Stack
GameManager uses a stack-based time scale system to prevent conflicts:
- Normal gameplay: stack empty -> `time_scale = 1.0`
- Tactical mode: pushes `{"id": "tactical", "scale": 0.1}`
- Hit stop: pushes `{"id": "hit_stop", "scale": 0.0}`
- Stack resolves to the top entry; popping restores previous
- This prevents tactical mode and hit stop from corrupting each other

## Input Architecture
- All inputs defined in `project.godot` InputMap with dual bindings
- LT/RT mapped as JoypadMotion (analog axes) with 0.5 deadzone
- R3 (camera reset) as JoypadButton index 8
- InputManager detects device type via last event type
- `get_movement_vector()` and `get_camera_vector()` helpers
- Mouse captured via `Input.MOUSE_MODE_CAPTURED`

## Data Architecture
- **Resource files (.tres)** for definitions: abilities, items, equipment, quests, characters
- **Dictionaries** for runtime state: inventory instances, save data, quest progress
- **RefCounted classes** for stateful wrappers: QuestInstance, InventorySlot
- **JSON** only for LUMINA dashboard files (game.config.json, project_status.json)

## Key Risks
1. Camera collision with SpringArm3D may need custom raycasting for edge cases
2. LT/RT as analog axes need careful deadzone tuning to prevent accidental triggers
3. R3 press during right stick camera can misfire — consider hold threshold
4. Animation-driven combat requires migrating from timer-based to AnimationPlayer method tracks when real animations arrive
