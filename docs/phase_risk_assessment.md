# Phase Risk Assessment — Project Ragnorak

## Phase Complexity Estimates

| Phase | Items | Complexity | Notes |
|-------|-------|-----------|-------|
| 1. Foundation | 1-20 | Medium | Structural setup, InputMap, base scenes |
| 2. Locomotion | 21-40 | Medium | Movement, jump, ledge — well-understood |
| 3. Camera & Lock-On | 41-65 | High | Camera collision is tricky in 3D |
| 4. Basic Combat | 66-95 | High | Combo chains, hitbox timing, dodge |
| 5. Enemy & Damage | 96-120 | High | AI, damage pipeline, death cleanup |
| 6. MP/ATB/Abilities | 121-150 | High | ATB design is core identity |
| 7. Tactical Mode | 151-175 | Medium | Time scale + UI, most logic exists |
| 8. HUD & Menus | 176-200 | Medium | UI work, controller navigation |
| 9. Inventory & Equipment | 201-230 | Very High | 10 slots, visual changes, persistence |
| 10. Quests & NPC | 231-255 | Medium | Self-contained, standard patterns |
| 11. Save System | 256-280 | High | Must serialize all systems |
| 12. World & Traversal | 281-310 | Very High | Level design + systems + content |
| 13. Party System | 311-340 | Very High | AI companion, switching, team mechanics |
| 14. Audio & VFX | 341-365 | Medium | Asset integration, not architectural |
| 15. Polish & QA | 366-400 | Medium | Tuning, testing, regression |

## Top 5 Project Risks

### 1. ATB/Action Hybrid Identity Crisis (CRITICAL)
The core combat system tries to merge real-time action with ATB-gated commands.
If the ATB feels like a cooldown timer, it's not FF7R. If it gates too much, action feels restricted.
**Resolution**: ATB fills from basic attacks (incentivizes melee engagement), costs vary per ability.
Must be resolved completely in Phase 6 before any expansion.

### 2. Party System Retrofit (CRITICAL)
Phase 13 adds a second character with AI, switching, and team attacks.
If Phase 1 builds a monolithic player, this becomes a near-complete rewrite.
**Resolution**: Player built as CharacterBase[0] from day one. InputProvider component swappable.
Camera, HUD, and save system designed for multi-character from start.

### 3. Phase 9 Scope Explosion (HIGH)
Phase 9 contains inventory + equipment (10 slots) + visual changes + item use.
Equipment visuals alone is a content pipeline problem masquerading as code.
**Resolution**: Split into tiers. Tier 1: data model + stats. Tier 2: weapons. Tier 3: body equipment.

### 4. No 3D Art Pipeline (HIGH)
Zero mention of models, rigging, animation production in the design docs.
Every system needs 3D assets. Combat feel cannot be tuned with capsule placeholders.
**Decision needed**: Mixamo animations? Asset store? Custom Blender work?
Each choice has different technical requirements.

### 5. Vertical Slice Gate Too Narrow (MEDIUM)
Gate validates arena combat only — no progression, world transitions, or menu flow.
A project can pass this gate and still have no viable path to a game.
**Resolution**: Expanded gate criteria in combat_design.md. Add menu navigation and save/load checks.

## Hidden Phase Dependencies

| Dependency | Impact |
|-----------|--------|
| Phase 1 -> Phase 13 | Player architecture must be party-aware |
| Phase 1 -> Phase 11 | Save interface contracts needed from start |
| Phase 9 -> Phase 12 | Vendors need town hubs (Phase 12 content) |
| Phase 4 -> Phase 13 | Combat systems must be entity-agnostic |
| Phase 6 -> Phase 7 | ATB must exist before tactical menu can gate commands |

## Recommended Phase Adjustments

1. **Move combat audio/VFX from Phase 14 to Phase 5**: Combat feel requires audio feedback
2. **Split Phase 9**: 9A (inventory + data model), 9B (equipment visuals)
3. **Add art pipeline decision to Phase 1**: Commit to asset source before Phase 2
4. **Move vendors from Phase 10 to Phase 12**: They need town environments
5. **Testing is continuous**: Phase 15 regression should happen incrementally, not terminally

## Expansion Gating Rules (Enforced)
- Party system blocked until single-character combat stable
- Bosses blocked until lock-on/camera/tactical stable
- Traversal expansion blocked until jump/camera/ledge stable
- Additional abilities blocked until one spell pipeline verified
- World expansion blocked until save/load stable
- UI polish blocked until menu navigation stable
