# v6 Plan — Next Session Handoff (Polish, Taighe Attack, Enemy AI, More Models)

Status: PLANNED — new session: read this file first, confirm the list with the user, then wait for "launch the agents"
Created: 2026-11-13
Baseline commit: `b077c49` (v1–v5, the UI kit, placeholder models). 1600/1603 tests pass.

---

## 1. How to start the new session
1. Read this file, `CLAUDE.md` (the INPUT CONTRACT, CORE DESIGN CONTRACT and v5 lines) and `docs/rigless_models.md`.
2. Skim the finished plans for context only: `docs/plans/battle_system_v3_plan.md`, `battle_v4_polish_plan.md`, `v5_party_air_options_plan.md`.
3. Show the user the task list (section 4) with priorities. Ask about new models (section 5). Add any new requests.
4. Write the agent packages into this file (section 6 is a starting point), then **wait for "launch the agents"**.

## 2. The user's working rules
- **Multi-agent workflow.** Head writes a plan in `docs/plans/*.md` with packages and **owned files**. Each agent updates only its own section: Status `NOT STARTED → IN PROGRESS → DONE`, ticks, Handoff Notes. Cross-file needs go through **Cross-Agent Requests**. Head proofs everything: re-runs tests, reviews screenshots, and prints the scene tree for scene changes.
- **The user's "launch the agents" starts work.** Before a plan, summarize the request list and get approval.
- **Head-owned files:** `scripts/autoloads/events.gd`, `src/world/zone_base.gd`, `scenes/test/test_arena.gd`, `CLAUDE.md`, `project_status.json`.
- **CLAUDE.md design-contract lines change only after user approval.** Agents draft them in their Handoff Notes.
- **Commits only with the user's approval.** Commit message attribution: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push unless asked.
- **Godot:** use `Z:/godot/godot.exe` only.
  - Boot: `Z:/godot/godot.exe --path . --headless --quit-after 1`
  - Run a suite: `Z:/godot/godot.exe --path . --headless --scene res://tests/<suite>.tscn`
  - Import: `--headless --import` after a new `class_name` or new assets.
  - Screenshots, windowed: `Z:/godot/godot.exe --path . --resolution 1920x1080 --script res://tools/ui_screenshots.gd` (add `-- v5` for the v5 set).
- **Visual identity** is our own "Lumina Frost". Borrow FF7-Rebirth-style genre conventions (layout, flow) only, never its art or look.
- **Debug flags** default false. The game is controller-first.

## 3. Current state (what exists)
- **Controls:**
  - A = jump in free roam, Command in battle. X = tap light / hold heavy.
  - B = dodge and back one menu layer. Y = interact or Command in free roam, unique ability in battle.
  - View/F = battle toggle. D-pad Up/Down (Tab) = party switch. RT = lock-on. L3 = run.
  - `BINDINGS_VERSION` 5.
- **Combat:**
  - Combos: mixable L/H 3-step combos with blast finishers, plus stagger.
  - Uniques: Arcane Stance (Amaro), Super Jump (Taighe).
  - Abilities: Sword Slash; Water Geyser and Wind Crescent; Plunge Strike and Air Burst (aerial list).
  - Targeting: per-spell ranges with darkened out-of-range rows; the target step always shows Fire Forward.
  - Air: air combos and air dodge/backflip. Lock-on camera framing.
- **UI:**
  - Key code: `UIStyle` kit, MenuNav (`src/ui/menu_nav.gd`).
  - Top-left: mode chip. Bottom-left: hints. Top-right: minimap.
  - Settings › Options page.
- **Party switch** swaps identities, not bodies: the Player node keeps the camera, lock-on and state machine.
- **Models:**
  - `RiglessVisual` (`src/characters/rigless_visual.gd`) gives un-rigged meshes procedural motion and strips metal from generated materials.
  - Taighe = Princess 1 (run-002).
  - Merchant Soo (town NPC) = Pirate Female 1 (run-001).
  - Field and dungeon enemies alternate between Kobold (Kobold Female 1 run-001) and Kobold Queen (Kobold Queen 1 run-001).
  - The files are in `assets/models/characters/`.
  - The test arena keeps capsules.
- **Tests (all suites):**

  | Suite | Tests |
  |---|---|
  | runner | 35 |
  | phase6 | 111 |
  | phase7 | 23 |
  | phase8 | 65 |
  | phase9 | 56 |
  | phase10 | 72 |
  | phase11 | 63 |
  | phase12 | 65 |
  | phase13 | 64 |
  | phase14 | 67 |
  | phase15 | 68 |
  | performance | 65 |
  | battle | 136 |
  | carry | 80 |
  | controls | 236 |
  | ui_style | 141 |
  | v4 | 96 |
  | v5 | 160 |

  **Known failures (predate v3):**
  - phase8: New Game loads town_hub, not test_arena.
  - phase12: return portals.
  - performance: expects 7 autoloads (there are 8 with AssetRegistry).

## 4. Task list for v6 (the user asked for these; confirm priorities)
**Priority 1 — polish the user called out**
1. **Sword Slash VFX:** the big opaque yellow ring hides the target. Make it a translucent additive crescent sweep with a short trail and a fast fade, and keep the target readable. Reference: `docs/ui_screenshots/v5_04_sword_slash.png`. Code: `src/effects/abilities/sword_slash.gd`, `ability_fx.gd`.
2. **Wind Crescent VFX:** the blades are small and faint at about 8 m. Make them bigger with brighter emission, add an outline or trail, and show a clear hit flash on each of the 3 hits. Reference: `v5_06_wind_crescent.png`.
3. **Water Geyser:** check readability; the telegraph ring and column should read at 10–15 m. Reference: `v5_05`.
4. **"OUT OF RANGE" label and dimmed target bar:** the label is tiny at 10 m, and the dimmed bar is hard to read over bright roofs. Make the label larger and keep the bar's backing panel dark while dimming only its content (`lock_on_indicator.gd`, `target_bar.gd`).
5. **Taighe basic attack:** when the player controls her, she currently uses Amaro's sword combo. Give her a mage basic attack: X tap = a quick magic bolt or short-range wind/water burst, hold = a charged shot. It must be data-driven per member (e.g. `PartyMemberData.basic_attack_kind` or a combo profile), and her AI should use the same kit. Mixing with the 3-step combo/finisher system is optional; propose a design.

**Priority 2 — behaviour gaps**

6. **Enemies target the AI member too.** Right now enemies only attack the controlled player, so the AI member is never hit. Add threat/target selection among `party_members` that keeps the ENEMY COMBAT SPACING RULE (no overlap; ring slotting). The companion needs a hurt/flinch/downed path.
7. **Amaro's idle/AI pose:** the red knight T-poses when idle and when AI-controlled; only a walking animation exists in `public/assets/fbx/redKnight/`. Options:
   - play the walk animation paused/slowed at idle;
   - layer RiglessVisual idle motion on top;
   - or ask the user for an idle FBX.
8. **NPC facing:** Merchant Soo (pirate) faces away from the approach path. Face NPCs toward the street or player spawn, and optionally turn toward the player during dialogue.

**Priority 3 — stability**

9. **Exit-time leak:** town/field scenes print "7 resources still in use at exit": ui_style, slant_panel, button_glyph, glyph_hint, header_tab, menu_row, town_builder.
   - Breaking `GlyphHint.create()`'s self-reference did NOT fix it.
   - Suspects:
     - `TownBuilder`'s `static var _aabb_cache`, which may hold a resource;
     - UIStyle font caching;
     - lambdas connected to autoload signals from HUD/menu nodes.
   - Find the cause with `--verbose` plus bisecting the HUD scripts in `zone_base._spawn_hud`.
10. **test_ui_style segfaults on exit** (exit code 139) after reporting results. It's probably the same cause as 9.
11. **Optionally fix the 3 known failures** (or retire their assertions with the user's agreement):
    - phase8 New Game target;
    - phase12 return portals ("Return to Millhaven" rename);
    - the performance autoload count of 8.

## 5. Adding more models (procedure: proven on 4 models)
The user picks models in the **Lumina dashboard → Pipeline → Models**. Each lives in `Z:\Development\lumina\pipeline\concepts\generated\<id>\`, which holds `concept.png`, `asset.json` and `runs/run-00N/model.glb`. The user names the run. For each model:
1. Copy `runs/<run>/model.glb` to `assets/models/characters/<snake_id>.glb`.
2. Run `--headless --import`.
3. **Fix the mislabelled textures.** Hunyuan embeds JPEG base-colour images that Godot extracts as `<name>_0.png`. Convert them in place (`python` + PIL: `Image.open(f).convert('RGB').save(f, 'PNG')`), then re-import. Expect PNG decode errors on the first import until this is done.
4. Wire up by role:
   - **Party member:** `resources/characters/<member>.tres`: `model_scene = ExtResource(...)` plus `rigless = true`. Keep `model_yaw_offset_deg` at 180.
   - **Enemy:** add `[display_name, preload(glb)]` to `ENEMY_MODELS` in `scenes/zones/field_zone.gd` / `dungeon_zone.gd`, or set `enemy.rigless_model` per spawn. `EnemyBase.rigless_model` / `rigless_fit_height` / `rigless_yaw_offset_deg` are exports.
   - **NPC:** pass `model` as the last argument of `_add_npc(...)` in `scenes/zones/town_hub.gd` (other zones need the same optional parameter added).
5. Metal stripping happens automatically (`RiglessVisual.fix_generated_materials`).
6. Verify with a windowed screenshot. In a temp SceneTree harness, load zones with `change_scene_to_file` (not `add_child`), or the party system can't spawn the companion.
7. Don't edit Lumina's `asset.json` (status/games). Approval in the dashboard is the user's action.

Models already used: princess1 (run-002), pirateFemale1 (run-001), koboldFemale1 (run-001), koboldQueen1 (run-001). Other good candidates the user mentioned in the dashboard: Teacher Female 2, Alchemist Female 1, Goblinchief Male 1, Goblin Male 2. **Ask** which runs and roles before adding them.

## 6. Suggested packages (adjust after the user confirms)
- **GG — Ability VFX polish** (items 1–4). Owns:
  - `src/effects/abilities/*`
  - `lock_on_indicator.gd`, `target_bar.gd`
- **HH — Taighe basic attack** (item 5). Owns:
  - `combo_component.gd`, `melee_strike_state.gd`
  - a new `src/combat/basic_attacks/*`
  - `party_member_data.gd`, `companion.tres` (non-ability fields)
  - `companion_ai.gd` (attack use)
- **II — Enemy party targeting + companion damage** (item 6). Owns:
  - `enemy_base.gd`
  - `companion_ai.gd` (hurt/downed path). This needs ordering with HH, so give the whole of `companion_ai.gd` to one package or sequence them.
- **JJ — Character presentation** (items 7–8, plus new models from section 5). Owns:
  - `player.gd` visual setup
  - `rigless_visual.gd`
  - zone NPC/enemy model wiring
  - `assets/models/characters/*`
- **KK — Stability** (items 9–11). Owns:
  - `town_builder.gd`, `ui_style.gd`, the widgets
  - any test files for the 3 known failures
- **LL — QA** (after all are DONE). Owns:
  - `tests/*`, including a new `tests/test_v6.gd`
  - `tools/ui_screenshots.gd`
  - the full suite run, screenshots, and a CLAUDE.md draft

## 7. Head review checklist (fill in per run)
- [ ] R-1. Signals and registrations requested by agents added.
- [ ] R-2. Diffs reviewed: ownership respected, no camera mutation outside the camera owner, UIStyle only, no new exit leaks.
- [ ] R-3. Boot and full suite reproduced by Head.
- [ ] R-4. Scene trees printed; signals verified.
- [ ] R-5. Screenshots reviewed.
- [ ] R-6. CLAUDE.md lines applied after user approval, then the controller test, `project_status.json`, and a commit with approval.
