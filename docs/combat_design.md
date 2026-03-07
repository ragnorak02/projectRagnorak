# Combat Design Plan — Project Ragnorak

## Combat Identity: FF7R Hybrid

Real-time action combat with tactical slow-time command menu.
ATB gauge gates command execution, fills from basic attacks and time.
No stamina system — basic attacks are unlimited.

## Combat Subsystems

### 1. Basic Attack Combo Chain
- 3-hit chain: Attack1 (0.6s) -> Attack2 (0.6s) -> Attack3 (0.7s)
- Each attack has: forward movement, combo window, recovery
- Input buffering: early presses stored as `buffered_next`
- Soft tracking: player faces locked target on attack enter
- Attacks cancel into dodge (not spells)
- Combo counter emitted via Events signal

### 2. Jump Attack
- Triggered from Jump or Fall states
- Applies downward force for a slam effect
- Has its own hit window and landing recovery
- Available from Phase 1 per design contract

### 3. Dodge System
**CRITICAL: No invulnerability frames.**
- Dodge is purely positional evasion — player physically moves out of hitbox range
- Speed: 15.0 with quadratic decay (1.0 - progress^2)
- Duration: 0.4 seconds
- Cooldown: 0.8 seconds
- Direction: input direction or backward-facing default
- Cancels basic attacks, CANNOT cancel spells/abilities
- This makes dodge about spatial awareness, not frame counting

### 4. ATB System
- ATB fills passively over time (base rate: 5.0/sec)
- ATB fills faster from landing basic attacks (planned)
- ATB fills faster from combo completion (planned)
- Maximum ATB: 100.0
- Each tactical command costs ATB (typically 25.0)
- Zero ATB: menu opens for observation but commands greyed out
- ATB displayed on HUD as segmented bar

### 5. MP System
- Spells cost MP to cast
- MP regenerates slowly (planned)
- Insufficient MP: ability greyed out in tactical menu
- MP persists across battles, replenished at rest points

### 6. Ability/Spell System
- Data-driven via AbilityData resources
- Each ability: type, MP cost, ATB cost, cooldown, cast time, damage, effect scene
- Cast phases: windup (interruptible) -> release (effect spawns) -> recovery
- Player roots in place during cast (velocity = 0)
- Enemies CAN interrupt during cast (forces Flinch state)
- Dodge CANNOT cancel spells (committed casting)
- On interruption: MP still consumed (risk/reward), no ATB refund

### 7. Tactical Mode
- Slows game to 10% speed via Engine.time_scale
- Categories: Abilities, Magic, Items
- Opens with LT (controller) or Q (keyboard)
- Free to open anytime during PLAYING state
- Blocked during: Flinch (stun), future Knockdown, Cutscene
- ATB required to EXECUTE commands, not to VIEW them
- Menu fully navigable with controller (D-pad/stick + A/B)
- On command selection: exits tactical, executes ability
- Time scale restored via priority stack (safe with hit stop)

### 8. Lock-On / Targeting
- RT (controller) or MMB (keyboard) toggles lock-on
- Selects nearest enemy within 20.0 unit range
- Player strafes while locked (LockOnStrafe state)
- Camera shifts toward target
- Target switch via right stick left/right
- Auto-release: target dies, goes out of range (1.5x detection), or becomes invalid
- Lock-on stable before boss implementation

### 9. Camera Combat Behavior
- Free orbit: right stick (controller), mouse (KB/M)
- Lock-on: camera lerps yaw toward target
- SpringArm3D prevents wall clipping
- Vertical clamp: -60 to +40 degrees pitch
- Camera shake via tween-based offset
- Camera reset: R3 snaps behind player

## Damage Pipeline
1. Attack state activates hitbox (Area3D with damage meta)
2. Hitbox enters enemy Hurtbox -> `area_entered` signal
3. Hurtbox reads `damage` meta from hitbox
4. `take_damage()` called on enemy, emits Events signal
5. Hit pause requested (65ms at time_scale 0.0)
6. Camera shake requested
7. Enemy enters Hurt state, plays hit reaction
8. Hitbox deactivated after window closes

## Animation-Driven Combat (Future)
Current: timer-based hitbox windows (works for placeholder capsules).
Future migration when real animations arrive:
1. Replace timer accumulation with AnimationPlayer method call tracks
2. Add keyframes at exact frames for:
   - `_on_hitbox_activate(damage_multiplier)`
   - `_on_hitbox_deactivate()`
   - `_on_combo_window_open()`
   - `_on_combo_window_close()`
3. Attack states become listeners, not timer drivers
4. AnimationTree with StateMachinePlayback for blend transitions
5. Root motion extraction for natural attack displacement

## Vertical Slice Checklist (Pass/Fail)
| Test | Criteria |
|------|----------|
| Movement | 8-directional analog, camera-relative |
| Camera orbit | Right stick smooth, no clipping |
| Camera collision | SpringArm prevents wall penetration |
| 3-hit combo | Attack1->2->3 with timing windows |
| Jump attack | From air, downward slam |
| Dodge | Positional evasion, no i-frames, cooldown |
| Lock-on | Nearest enemy, strafe, camera shift |
| Target switch | Right stick left/right |
| One spell | MP cost, ATB cost, cast time, rooted |
| Spell interrupt | Enemy hit during cast -> Flinch |
| Tactical menu | Opens, slows time, shows commands |
| ATB gating | Commands blocked at zero ATB |
| Enemy takes damage | HP decreases, hit reaction |
| Enemy dies | Removed, lock-on clears |
| Player takes damage | HP decreases, Flinch state |
| Save/load | Position + HP/MP/ATB persists |
| No softlocks | 10-minute play session stable |

## Combat Feel Targets
- Attacks should feel responsive (< 100ms from input to first frame of motion)
- Combo windows should feel generous but require intention (300-550ms)
- Dodge should feel snappy (immediate velocity, quick decay)
- Lock-on should never feel "sticky" (smooth camera transition)
- Tactical mode entry should feel instant (no delay before slowdown)
- Hit feedback should be punchy (hit stop + shake + VFX)
