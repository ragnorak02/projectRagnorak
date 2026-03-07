# Vertical Slice Gate — Detailed Pass/Fail Criteria

## MUST PASS (20 items — all required to advance past Phase 7)

| ID | Criterion | Test Method |
|----|-----------|-------------|
| VS-01 | Player moves in 8 directions with analog stick, speed proportional to input magnitude | Manual: verify with gamepad |
| VS-02 | Camera follows player without clipping through arena geometry | Manual: push player into walls and corners |
| VS-03 | Camera collision prevents view through walls (SpringArm3D) | Manual: force camera into geometry from all angles |
| VS-04 | 3-hit combo chain executes with timing window between hits | Automated: state test Idle->Attack1->Attack2->Attack3 |
| VS-05 | Combo resets to hit 1 if timing window expires | Automated: insert delay > window, verify Idle return |
| VS-06 | Dodge is purely positional (no invulnerability frames) | Automated: spawn damage during dodge, verify damage taken |
| VS-07 | Dodge has cooldown that prevents spam | Automated: rapid dodge inputs, verify cooldown blocking |
| VS-08 | Lock-on snaps camera to target enemy | Manual: verify camera behavior with gamepad |
| VS-09 | Lock-on persists across dodge and attack states | Automated: lock on, dodge, verify still locked |
| VS-10 | At least one spell casts, hits enemy, deals damage | Automated: cast spell at target, verify HP change |
| VS-11 | ATB bar fills over time and gates spell usage | Automated: verify spell fails with zero ATB, succeeds with full |
| VS-12 | Tactical menu opens, time slows to 10%, player selects ability, time resumes | Manual: full flow with gamepad |
| VS-13 | Enemy takes damage, plays hit reaction, dies at 0 HP | Automated: damage enemy to 0, verify death/cleanup |
| VS-14 | Enemy attacks player, player takes damage, HUD reflects HP change | Automated: let enemy attack, verify HP bar |
| VS-15 | Save game writes file to disk with player state | Automated: save, verify file exists with expected keys |
| VS-16 | Load game restores player state from file | Automated: save, modify state, load, verify restoration |
| VS-17 | Jump has gravity, landing state, and floor collision | Automated: jump, verify Y arc, verify landing |
| VS-18 | Jump attack triggers from air and applies downward force | Manual: jump, press attack, verify slam |
| VS-19 | No crash during 10-minute continuous play session | Manual: play for 10 minutes |
| VS-20 | All automated tests pass (headless boot + test runner) | Automated: exit code 0 |

## SHOULD PASS (Quality Indicators — non-blocking)

| ID | Criterion |
|----|-----------|
| VS-21 | Controller hint bar visible with correct button prompts |
| VS-22 | Pause menu opens and closes without state corruption |
| VS-23 | Enemy AI enters aggro state when player approaches |
| VS-24 | Frame rate stays above 30 FPS throughout arena play |
| VS-25 | Lock-on target switching works with right stick |
| VS-26 | All menu navigation works on controller (no keyboard required) |
| VS-27 | Spell cannot cancel into dodge (committed casting verified) |
| VS-28 | Enemy can interrupt spell cast (flinch during cast verified) |

## Gate Decision Rule

All 20 MUST PASS items must be green.
Any single failure blocks advancement past Phase 7 into Phase 8+.
SHOULD PASS items are tracked but non-blocking.

## What the Gate Does NOT Test (intentionally deferred)

- Inventory / equipment system
- Quest progression
- World zone transitions
- Party mechanics
- Boss encounters
- Audio/VFX polish
- NPC dialogue
- Save slot UI
