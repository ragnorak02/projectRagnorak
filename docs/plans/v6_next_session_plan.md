# v6 Plan — Next Session Handoff (Polish, Taighe Attack, Enemy AI, More Models)

Status: COMPLETE 2026-11-14 — all packages DONE, Head proof passed (1781/1781), CLAUDE.md lines approved and applied, committed
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

## 6. Agent packages (confirmed with the user 2026-11-13)

### 6.0 User decisions
- All 11 items in section 4 are in scope, at the priorities shown.
- **New models: all four.** Roles (the user accepted the suggested split):
  - Teacher Female 2 (`teacherFemale2`): town NPC, quest giver.
  - Alchemist Female 1 (`alchemistFemale1`): town vendor or NPC.
  - Goblin Male 2 (`goblinMale2`): field and dungeon enemy, rotates with the kobolds in `ENEMY_MODELS`.
  - Goblinchief Male 1 (`goblinchiefMale1`): elite/brute enemy in the dungeon, `rigless_fit_height` about 2.4 m, collision to match.
- **Runs (picked by the user):** Teacher Female 2 **run-002**, Alchemist Female 1 **run-002**, Goblin Male 2 **run-002**, Goblinchief Male 1 **run-001**.
- **Amaro idle:** pause the walk animation on a neutral frame at idle (and when AI-controlled while standing), and layer RiglessVisual idle bob/lean on top. No new FBX.
- **Known failures:** update the tests to match the game (New Game → town_hub, the "Return to Millhaven" rename, 8 autoloads including AssetRegistry).
- **Taighe basic attack:** a full 3-step mage combo. Tap = bolt, hold = charged shot, mixable L/H, step 3 = ranged finisher burst that scales with heavies. It reuses the combo and stagger plumbing.

### 6.1 Ordering
- GG, HH, JJ and KK start in parallel.
- II starts on `enemy_base.gd` right away, but touches `companion_ai.gd` only after HH is **DONE** (HH owns it first, then hands it to II).
- LL starts after GG, HH, II, JJ and KK are all **DONE**.
- Shared files nobody owns (`events.gd`, `zone_base.gd`, `test_arena.gd`, `CLAUDE.md`, `project_status.json`) belong to the Head. Request changes to them under Cross-Agent Requests.

---

### GG — Ability VFX polish (items 1–4)
Status: DONE
Owns:
- `src/effects/abilities/*` (`ability_fx.gd`, `sword_slash.gd`, `wind_crescent.gd`, `water_geyser.gd`, `air_burst.gd`, `plunge_impact.gd`)
- `src/ui/hud/lock_on_indicator.gd`, `src/ui/hud/target_bar.gd`

Tasks:
- [x] GG-1. Sword Slash: a translucent additive crescent sweep (unshaded, additive blend, no depth write), a short trail, and a fade in ≤0.25 s. The target must stay readable through it. Remove the opaque ring.
- [x] GG-2. Wind Crescent: blades about 2× bigger, brighter emission, a trail or rim, and a hit flash on each of the 3 hits. Readable at 8 m.
- [x] GG-3. Water Geyser: the telegraph ring and column must read at 10–15 m. Raise contrast or size as needed.
- [x] GG-4. "OUT OF RANGE": a larger label, readable at 10 m. The target bar keeps a dark backing panel and dims only its content (name, HP, stagger).
- [x] GG-5. Theme tokens/UIStyle only, no new exit leaks, no gameplay timing changes (VFX only). Run the battle and v5 suites.
- [x] GG-6. Windowed screenshots of each effect and the out-of-range bar over a bright roof.

Handoff Notes (GG, 2026-11-13):
- **Files changed:** `src/effects/abilities/ability_fx.gd`, `sword_slash.gd`, `wind_crescent.gd`, `water_geyser.gd`, `src/ui/hud/lock_on_indicator.gd`, `src/ui/hud/target_bar.gd`. No new files, no new `class_name`. `air_burst.gd` and `plunge_impact.gd` are untouched.
- **Cause of the opaque ring:** it was not Sword Slash's own crescent. The two `AttackVFX.spawn_strike(..., &"heavy")` calls drew gold tori with `no_depth_test`. Sword Slash no longer calls AttackVFX. The combo's heavy strikes still use it (not GG-owned).
- **ability_fx.gd (shared helpers):**
  - `make_add_mat()`: additive blend, unshaded, `DEPTH_DRAW_DISABLED`, optional vertex-alpha.
  - `trail_arc_mesh()`: a ribbon whose vertex alpha and width ramp from tail to head.
  - `hit_flash()`: an additive puff drawn over the target, plus a streak. Frees itself after about 0.16 s.
  - New tints: `WATER_DEEP`, `WIND_DEEP`. All per-instance materials; no statics or caches.
- **GG-1 Sword Slash:**
  - The effect is an additive Frost ribbon that sweeps left to right in 0.11 s and reaches about 0.9 × reach. It has a white rim edge, a short white core near the blade, and a fading tail (the trail).
  - Every visual is gone by `FX_FADE` = 0.24 s. Each enemy hit gets a flash with a streak along the sweep.
  - The node still lives `DURATION` = 0.42 s, as in v5, because the tests read `hit_targets`. Damage, arc and stagger logic are unchanged.
- **GG-2 Wind Crescent:**
  - Blades are scaled 0.95 → 1.9. Each has a dark-teal outline crescent (contrast over sky and roofs), a brighter core, and an additive white rim.
  - Each slash leaves 2 fading afterimages.
  - Every landed hit pops a white hit flash on the target, 0.07 s after the hit, as the blade crosses. If the hit kills the target, the flash still plays at the stored chest position.
  - The visual orbit is a little wider and higher (`VFX_ORBIT_*`). `APPEAR`/`INTERVAL`/`SLASH_TIME`/`HIT_RADIUS` and damage are unchanged.
- **GG-3 Water Geyser:**
  - The telegraph now has 4 layers: a translucent filled disc, a dark outline ring, a thicker bright ring, and a low additive wall (0.55 m) at the edge. The wall keeps it readable at grazing angles from 10–15 m.
  - The eruption adds a ground splash ring that rushes outward and a white foam crown that rides the column top.
  - `TELEGRAPH`, `COLUMN_*` and launch values are unchanged.
- **GG-4 OUT OF RANGE:**
  - Reticle: only the reticle dims. The label is `SIZE_S + 4` (20 px), DANGER-coloured, on a dark `GLASS_DEEP` pill with a DANGER border, centred under the reticle.
  - Target bar: the slant panel stays and turns darker (`GLASS_DEEP` at 95%). Only the name, HP number, HP gauge and stagger row dim. An undimmed "OUT OF RANGE" pill appears in the top row, and the top line turns TEXT_DIM.
  - `is_out_of_range()` is kept on both.
  - UI colours use UIStyle tokens only (`Color(UIStyle.X, a)`). 3D colours use the FX constants.
- **GG-5 tests** (final code, run while other agents' work was also in the tree):

  | Suite | Result |
  |---|---|
  | test_v5 | 160/160 |
  | test_battle | 136/136 |
  | test_v4 | 96/96 |
  | test_phase14 | 67/67 |
  | test_ui_style | 140/141, then exit 139 |
  | test_performance | 64/65 |

  - test_ui_style fails "Target bar name uses enemy display_name — KOBOLD A". The field enemies are now named Kobold by model wiring; GG did not change `target_display_name`. The exit-139 crash is KK's known item.
  - test_performance fails only on the known autoload-count item (KK-4).
  - Boot is clean.
  - `--verbose` exit leaks in test_battle list only threat_table, ui_style, enemy_base, basic_attack_profile and combo_component. No GG files leak.
- **GG-6 screenshots:**
  - `docs/ui_screenshots/v6_gg_01_out_of_range_bar.png` (bar over the roof plus the reticle label at 10 m)
  - `v6_gg_02_sword_slash_sweep.png`
  - `v6_gg_03_sword_slash_trail.png`
  - `v6_gg_04_water_geyser_telegraph_12m.png`
  - `v6_gg_05_water_geyser_column_12m.png`
  - `v6_gg_06_wind_crescent_blades_8m.png`
  - `v6_gg_07_wind_crescent_hit_flash_8m.png`
  - They were taken with a temporary harness that extended `tools/ui_screenshots.gd`. The harness has been deleted.
- **Note for the Head:**
  - In shots 01–03, a pale capsule-shaped shell shows on the near dummy before any cast. It is not from GG. It looks like an enemy or companion overlay from II/HH's in-progress work.
  - The controlled body in Taighe shots shows the red-knight model (JJ/HH area).
- **CLAUDE.md contract draft:** "Ability VFX are translucent additive (unshaded, no depth write) and fade within 0.25 s (Sword Slash); multi-hit spells show a hit flash per hit; the target stays readable through every effect. Out-of-range: the reticle dims while the 'OUT OF RANGE' label stays large on a dark pill; the target bar keeps its dark panel and dims only its content."

---

### HH — Taighe mage basic attack (item 5)
Status: DONE
Owns:
- `src/combat/combo_component.gd`
- `src/player/states/melee_strike_state.gd`, plus a new `src/player/states/mage_strike_state.gd` if needed
- new `src/combat/basic_attacks/*` (e.g. `basic_attack_profile.gd`, `mage_bolt.gd`, `mage_charged_shot.gd`, `mage_finisher_burst.gd`)
- `resources/characters/party_member_data.gd`, plus the non-ability fields of `hero.tres` / `companion.tres`
- `src/party/companion_ai.gd` (**until DONE**, then it passes to II)

Tasks:
- [x] HH-1. Data-driven basic-attack profile per member (e.g. `PartyMemberData.basic_attack_profile: BasicAttackProfile`; Amaro = melee, the current behaviour, Taighe = mage). An identity swap switches the profile.
- [x] HH-2. Taighe's kit: tap = a quick bolt that soft-tracks the lock-on target; hold = a charged shot. Mixable L/H 3-step, with step 3 a ranged finisher burst that scales with heavies. Builds stagger. 0 MP.
- [x] HH-3. Keep the contracts: X tap/hold timing is unchanged; basic attacks cancel into dodge; combo state survives the Command Menu; it works airborne under the air combo rules (or is explicitly limited; document which).
- [x] HH-4. Companion AI uses the same profile when Taighe (or Amaro) is AI-controlled.
- [x] HH-5. Amaro's melee combo is bit-identical: the battle, v4 and v5 suites must still pass.
- [x] HH-6. Draft a CLAUDE.md contract line in your Handoff Notes. If `player.gd` needs changes (state registration), send them as a Cross-Agent Request to JJ.

Handoff Notes (HH, 2026-11-13):
- **Design.**
  - `BasicAttackProfile` (`class_name`, `src/combat/basic_attacks/basic_attack_profile.gd`) is set per member through `PartyMemberData.basic_attack_profile`: `hero.tres` uses `melee_profile.tres` and `companion.tres` uses `mage_profile.tres`. A null profile means melee.
  - The profile is resolved from `player.get_member_data()` at every strike (`ComboComponent.active_profile()`), so an identity swap switches it. `import_member_state` already resets the combo.
  - X timing (tap/hold 0.22 s real time), the L/H string, the chain window and buffering, dodge cancel, resets and the air budget all stay in `ComboComponent` and are shared by every member.
  - **No new state.** The `MeleeStrike` state branches on `profile.is_mage()`, so `player.gd` needs no change (no request to JJ).
  - **Melee path (Amaro)** is the v5 code, untouched: `STRIKES`, `ComboComponent.FINISHERS`, hitbox and arcs.
  - **Mage path (Taighe).** Every step spawns a `MageBolt` (`mage_bolt.gd`). It charges at the hand and launches at `hit_start`:
    - light = quick bolt: 9 dmg, 6 stagger, 32 m/s, about 19 m.
    - heavy = charged shot: 17 dmg, 18 stagger, fires 0.20 s into the strike.
    - Step 3 = a finisher orb that bursts on impact or at max range. The heavy count picks it: `arcane_burst` 2.0 m ×1.4 / `frost_burst` 2.6 m ×1.7 / `frost_nova` 3.4 m ×2.2 / `lumina_nova` 4.5 m ×3.0 plus a camera shake through `Events.camera_shake_requested`.
    - The bolt soft-tracks the lock-on target. Without lock-on it tracks the nearest enemy inside a forward cone (dot ≥ 0.82, ≤ 18 m), and a ground strike turns to face that enemy.
    - Hits use a deterministic distance query over the `enemies` group, sub-stepped against tunnelling. They call `take_damage` + `add_stagger` once each. The burst goes through `BlastVFX.detonate`.
    - Moves in game time, so hit-stop and the 0.05 Command Menu slow it.
    - A strike cancelled before fire time (dodge, flinch) fizzles its bolt: no damage.
    - 0 MP.
    - `Events.combo_finisher` carries the mage finisher names and radii. The HUD falls back to "FROST NOVA" etc. GG/KK may add them to `combat_hud.FINISHER_NAMES` if they want custom labels.
  - **Air.** Supported under the v5 rules: the same air string budget (≤3 strikes, once per airtime), altitude hold and drift. The bolt aims at the target below.
  - **Companion AI** (`companion_ai.gd`) reads the same profile (`attack_profile`, re-applied in `initialize` and `import_member_state`) and plays `profile.ai_pattern` (`"LLH"`) with that kit's timings and damage:
    - Melee AI hits the target in reach with `MeleeStrike.STRIKES`; step 3 is the ComboComponent finisher (blasts through `BlastVFX`).
    - Mage AI attacks from 9 m, backs off when an enemy is within 4 m between strings, and fires `MageBolt`s.
    - There is a cooldown between strings (`ai_string_cooldown`: melee 2.0 s, mage 2.2 s).
    - `_do_attack` / `_process_attack` / `attack_damage` / `attack_cooldown` names are kept (phase13 source checks).
  - **Tuning note:** AI DPS rose compared with the old flat 12-dmg poke every 2 s. Tune `ai_string_cooldown` / `ai_pattern` in the .tres if needed.
- **Files changed:**
  - `src/combat/combo_component.gd`: `active_profile()`, profile-aware finisher signal.
  - `src/player/states/melee_strike_state.gd`: the mage branch.
  - `src/party/companion_ai.gd`
  - `resources/characters/party_member_data.gd`: `basic_attack_profile`.
  - `resources/characters/hero.tres`, `companion.tres`: the profile ext_resource only.
  - New: `src/combat/basic_attacks/basic_attack_profile.gd`, `mage_bolt.gd`, `melee_profile.tres`, `mage_profile.tres`.
  - Import was run for the new `class_name`.
- **Tests (headless, after the changes):**

  | Suite | Result |
  |---|---|
  | battle | 136/136 |
  | v4 | 96/96 |
  | v5 | 160/160 |
  | controls | 236/236 |
  | phase13 | 64/64 |
  | phase7 | 23/23 |
  | phase6 | 111/111 |
  | runner | 35/35 |
  | phase15 | 68/68 |
  | performance | 64/65 (the known 7-vs-8 autoload failure, KK's) |

  Boot is clean. A temp harness (deleted) passed 33/33. It covered:
  - profiles per .tres, and the finisher names and radii by heavy count;
  - Amaro still melee;
  - after the switch, the player is mage and the companion body is melee;
  - the tap bolt soft-aims and hits an 8 m target once;
  - the charged shot does more damage and builds stagger;
  - LLL/LLH/LHH/HHH: damage order, the HHH burst reaches a side enemy at 3.5 m, LLL's does not, each enemy is hit once;
  - a locked-on bolt tracks an off-axis target;
  - B cancels a charged shot into Dodge, the string resets, and the bolt fizzles;
  - a bolt in flight is slowed at time_scale 0.05 and lands afterwards;
  - airborne X gives an air mage strike that holds altitude (±0.25 m) and hits;
  - after the switch back, the Taighe AI fires an LLH string of bolts at 7 m and keeps its distance.
- **Tests for LL (`test_v6`):** the harness cases above, through the real input path in town_hub. Freeze the companion (`set_physics_process(false)`) for the player cases. Note that `Events.enemy_hit`'s source for melee hitbox hits is `HitboxAnchor`, not the player.
- **Screenshots:** `docs/ui_screenshots/v6_hh_01_quick_bolt.png`, `v6_hh_02_charged_shot_charging.png`, `v6_hh_03_charged_shot_flight.png`, `v6_hh_04_lumina_nova_burst.png` (the burst flash is translucent and additive; the target stays readable).
- **CLAUDE.md contract-line draft:** `- [ ] Basic attack is data-driven per member (PartyMemberData.basic_attack_profile): Amaro = sword combo; Taighe = mage bolts (tap = quick bolt, hold = charged shot, soft-track lock-on, 0 MP, builds stagger), mixable L/H 3-step whose step 3 is a ranged burst scaling with heavies (Arcane Burst 2 m -> Lumina Nova 4.5 m); same timing, dodge-cancel and air-combo rules as melee; AI-controlled members use the same profile`
- **`companion_ai.gd` released to II.**

---

### II — Enemies target the party + companion damage (item 6)
Status: DONE
Owns:
- `src/enemies/enemy_base.gd` (from the start)
- `src/party/companion_ai.gd` (**only after HH is DONE**)
- new `src/enemies/threat_table.gd` if needed

Tasks:
- [x] II-1. Threat/target selection over `PartyManager` party members (damage dealt, proximity, current target stickiness). Deterministic, no per-frame target flapping.
- [x] II-2. Keep the ENEMY COMBAT SPACING RULE against any target: preferred radius, stop distance, ring slotting around the targeted member, no overlap with any member.
- [x] II-3. The companion's hurt path: damage, flinch, downed (no AI actions while downed), and HP shown on the HUD party panel (send a request if the HUD needs a signal).
- [x] II-4. Party switch onto a downed member is blocked (contract: blocked when dead). The camera and lock-on stay on the Player node.
- [x] II-5. Verify 1v1, 1v2 and 1v3 spacing against the player and the companion, lock-on during reposition, and tactical mode while enemies retarget.
- [x] II-6. Request new signals (e.g. `party_member_damaged`, `party_member_downed`) from the Head via Cross-Agent Requests.

Handoff Notes:
- **Design: threat** (`src/enemies/threat_table.gd`, no `class_name`, preloaded by `enemy_base.gd`; no import needed).
  - Threat is keyed by **member id** (`PartySystem.members[i].id`), not by body. After a party switch the enemy keeps fighting the same member in its new body (`Events.party_member_switched` re-resolves the body). It does not chase the Player node across the arena.
  - Score = stored threat (damage dealt × 1.0, decays 10 %/s) + proximity (15 at 0 m, falling to 0 at `aggro_range`) + 10 stickiness for the current target − 6 per other enemy already on that member. The crowd term spreads groups over the party.
  - Ties keep the current target, then go to party order. The target is re-evaluated every 0.5 s (game time) in CHASE only, and a voluntary switch waits until 2.0 s after the last switch. Result: at most one voluntary switch per 2 s, no per-frame flapping.
  - A forced switch happens at once in every state when the target is downed (`Events.party_member_downed`), dead (`current_hp <= 0`) or freed. A wind-up on a downed member is dropped.
  - Aggro: the "player" group and the "party_members" group both trigger the `AggroArea` (a downed member does not). Being hit while unengaged engages the attacker if it is within `aggro_range × 1.5`. When the target leaves `aggro_range × 1.5`, the enemy falls back to the nearest member in `aggro_range`, otherwise IDLE.
  - Damage is attributed by walking from the `take_damage` source to a party body: scene parents, plus any `caster`/`source` property or meta (HH's `MageBolt` passes `source` = its body). An unknown or null source counts as the Player body's damage, the same rule as `BattleModeComponent`.
  - "CHASE with no target goes IDLE" is unchanged (tests depend on it).
  - API: `get_target()`, `get_target_key()`, `get_preferred_radius()`, `is_attacking()`, `get_ring_slot_angle()`, `threat`, and the local signal `target_changed(enemy, new_target)`.
- **Design: spacing** (`enemy_base._steer_spacing` / `_clamp_member_overlap`).
  - New exports:
    - `preferred_radius`: auto = `attack_range - 0.2` = **1.8 m (~6 ft)**.
    - `stop_distance`: **1.5 m (5 ft)**.
    - `enemy_separation`: 1.3 m.
    - `max_attackers_per_target`: 2. This is the attack queue: other enemies hold their slot until a slot frees up.
  - **Ring slots.** Every enemy on the same member computes the same assignment. Enemies are sorted by angle around the target relative to the group's mean direction, so their order never swaps and they don't cross paths. Slots are spaced 90° apart (TAU/N when N >= 5) and centred on the mean direction. A balanced surround anchors on the lowest instance id. Enemies orbit tangentially on the ring instead of cutting through the target.
  - **No overlap with any member**, the target or not, downed included. Inside `stop_distance` the enemy backs out at >= 60 % speed. Otherwise the inward velocity that would cross `stop_distance` this frame is removed. Enemies collide with the world only (mask 1), so this clamp is what keeps them out of member colliders.
  - Enemies face the target within 5 m. They attack when within `attack_range` (2.0 m), with cooldown ready and an attack slot free. The hitbox reaches 1.55 m + a 0.5 m hurtbox, so strikes land from the ring.
  - Enemy scripts never touch the camera or lock-on.
- **Companion hurt path** (`companion_ai.gd`):
  - **Hurtbox.** A `Hurtbox` Area3D (layer 32 PlayerHurtbox, mask 16 EnemyHitbox, sphere r 0.5 at y 0.9), the same as the Player body's. Enemy strikes damage it through the normal hitbox meta path.
  - **Flinch.** `take_damage` → new `AIState.FLINCH` (appended, so indices are kept) for 0.45 s of game time. It interrupts the running AI string (no cooldown), plays the rigless `hit` cue / capsule flash, and the AI takes no actions until it ends.
  - **Downed.** At 0 HP: the existing DOWNED path, plus the hurtbox is turned off. Revive and `import_member_state` turn it back on.
  - `is_flinching()` added.
  - If `Events.party_member_damaged` exists, it is emitted (dynamic `has_signal`, so no hard dependency).
  - HUD: `combat_hud` already polls the ally's `current_hp` and listens to `party_member_downed`/`revived`, so the party panel shows companion HP and DOWNED with no HUD change.
- **II-4.** `PartySystem.switch_member()` already skips downed members ("No other members available"). Verified: the switch returns false and `active_index` is unchanged. The camera and lock-on live on the Player node and are untouched.
- **Files changed:** `src/enemies/enemy_base.gd`, `src/party/companion_ai.gd`. New: `src/enemies/threat_table.gd`. Temp harness `tools/tmp_ii_spacing.*` deleted; a copy for LL is kept at `C:\Users\nick\AppData\Local\Temp\claude\de72464e2d5e7768\4c1353b1-3d19-47da-9f69-12cb911de85e\scratchpad\ii_spacing_harness.gd`.
- **Tests (headless, after all changes):**

  | Suite | Result |
  |---|---|
  | battle | 136/136 |
  | v4 | 96/96 |
  | v5 | 160/160 |
  | controls | 236/236 |
  | phase13 | 64/64 |
  | performance | 65/65 |
  | phase15 | 68/68 |
  | runner | 35/35 |
  | phase6 | 111/111 |
  | phase7 | 23/23 |
  | phase12 | 65/65 |
  | phase14 | 67/67 |
  | carry | 80/80 |

  - Boot is clean.
  - One earlier v4 run (concurrent with other agents' runs) failed once ("Target step harness: Command Menu opens on Y"). Re-runs gave 96/96 twice. Treat it as flaky; LL should watch it.
- **Spacing verification** (temp harness 55/55; real `enemy.tscn`, `player.tscn` and `PartySystem` with the companion; 8 s per case; minimum distance is centre to centre, horizontal):
  - **vs player:**
    - 1v1: min 1.99 m.
    - 1v2: min 1.93 m, enemy-enemy 2.48 m, slots about 80° apart.
    - 1v3: min 1.92 m, enemy-enemy 2.65 m, slots at about -179°/-93°/96°.
    - Strikes landed through the hurtbox (30/60/80 damage).
    - At most 1 `target_changed` per enemy (the initial acquire).
  - **vs companion:** the same numbers. Damage landed through the new hurtbox, and the companion entered FLINCH.
  - **Mixed** (members 4 m apart, 3 enemies; the companion hit one enemy): the split was player 1 / companion 2, the victim targeted the companion, min member distance 1.83 m, enemy-enemy 1.74 m, at most 2 target changes.
  - **Lock-on during reposition:** the player moved 3.6 m mid-fight and the locked target moved 3.46 m; the lock was held for 3 s, then through a tactical open/close.
  - **Tactical (0.05):** heavy companion threat retargeted an enemy after the hold. Min spacing was 1.58 m during the retarget, and the time scale was restored to 1.0 on exit.
  - **Downed:** 0 HP → downed; no enemy kept the downed member as its target; min distance afterwards was 1.81 m (no overlap with the downed body either); the party switch was blocked.
- **Tests for LL (`test_v6`):** port the harness cases above:
  - Freeze the companion with `set_physics_process(false)` and park the off member 60 m away for the single-target cases.
  - Measure game time as real time × `Engine.time_scale`.
  - Also:
    - source checks for the `threat_table.gd` constants;
    - `target_changed` fires once per acquire;
    - the companion `Hurtbox` layer is 32 and its mask is 16;
    - `FLINCH` is the last enum value.
- **Requests:** Head, `events.gd`: `party_member_damaged` (optional; see the table). JJ's optional `body_height` request: not done in v6. The `_scale_enemy_body` helper is compatible with the spacing code: Chief capsule r 0.56 + member 0.4 < `stop_distance` 1.5, and its AttackOrigin -1.12 + a 0.75 half-box + a 0.5 hurtbox reaches 2.37 m >= the 1.8 m ring.
- **Open:**
  - The mage companion kites at about 4 m from an enemy that targets it (`ai_keep_distance` 4 > ring 1.8). This is intended FF7-style behaviour, but tune it if it looks like running away.
  - The player body has no downed state (`player_died` only). Enemies stop targeting it at `current_hp <= 0`.
- **CLAUDE.md drafts:**
  - `- [ ] Enemies pick a target among the party by threat (damage dealt, proximity, stickiness, crowd spread), keyed by member id so a party switch keeps the enemy on the same member; re-evaluated every 0.5 s, voluntary switches at most once per 2 s; downed/dead members are dropped at once`
  - `- [ ] Spacing around ANY targeted member: ring slots at preferred radius (attack_range - 0.2, 1.8 m), stop distance 1.5 m from every party member (downed included), enemy separation 1.3 m, at most 2 simultaneous attackers per member`
  - `- [ ] AI companion has a Hurtbox (same layers as the Player): hits flinch it (0.45 s, no actions, string interrupted); 0 HP = downed (no actions, not targetable, hurtbox off, switch onto it blocked)`

---

### JJ — Character presentation + new models (items 7–8, section 5)
Status: DONE
Owns:
- `src/player/player.gd` (visual setup, plus state registration on HH's request)
- `src/characters/rigless_visual.gd`
- model wiring in `scenes/zones/town_hub.gd`, `field_zone.gd`, `dungeon_zone.gd` (`ENEMY_MODELS`, `_add_npc`)
- `assets/models/characters/*`

Tasks:
- [x] JJ-1. Amaro idle: the paused walk frame (neutral pose) at idle and in AI-standing, with RiglessVisual-style bob/lean layered on top. No T-pose in any state (player-controlled, AI, Command Menu).
- [x] JJ-2. NPC facing: NPCs face the street or the approach path by default. Optionally turn toward the player in dialogue, then turn back.
- [x] JJ-3. Add the optional `model` parameter to `_add_npc` in the other zones where it's missing.
- [x] JJ-4. New models per section 5 (copy → import → PNG texture fix → re-import → wire), using the runs from 6.0:
  - Teacher Female 2 → town quest-giver NPC
  - Alchemist Female 1 → town vendor/NPC
  - Goblin Male 2 → `ENEMY_MODELS` in field + dungeon
  - Goblinchief Male 1 → dungeon elite, fit about 2.4 m
- [x] JJ-5. Don't edit Lumina's `asset.json`. Windowed screenshots of each model in place, plus Amaro idle.

Handoff Notes:
- **Files changed:** `src/player/player.gd`, `src/characters/rigless_visual.gd`, `scenes/zones/town_hub.gd`, `scenes/zones/field_zone.gd`, `scenes/zones/dungeon_zone.gd`, plus new files in `assets/models/characters/`. The temporary harnesses (`tools/tmp_jj_*.gd`) are deleted.
- **JJ-1 Amaro idle** (`player._setup_model`):
  - The red knight's own clip, the T-pose rest, is kept as `"tpose"` and never played.
  - `"idle"` is a static one-key pose (`build_idle_pose`). It averages the walk's two "passing" frames (0.025 and 0.525 of the cycle: feet together, arms down), zeroes the hips' X/Z and drops the hips 4 cm. Both ankles measure 0.143–0.148 m against the 0.141 m rest, so the feet are on the ground.
  - Because the pose is static, it holds at `time_scale` 0.05. The AI body (`companion_ai._update_animation` plays `&"idle"`/`&"walk"`) gets it with no change to `companion_ai.gd`.
  - `"walk"` is now in place and loops (`make_in_place_loop`). The clip moved the hips about 2 m per cycle and did not loop, so the knight drifted ahead of the body and froze after 1 s.
  - The knight is wrapped in a cosmetic `RiglessVisual` named **`IdleLayer`**: `auto_fit=false`, `yaw_mode=NONE`, 2 cm idle bob, lean up to 7°, light squash.
  - It is not named `RiglessVisual`, so `_rigless_cue` (dodge spin, hit shake) stays off for the rigged knight, and the v5 cue test still finds its own node.
  - The layer travels with the identity on a party swap.
  - Verified: Idle → `idle`; Command Menu (`TacticalIdle`, ts 0.05) → `idle`; Amaro AI-standing after a switch → `idle`.
- **`rigless_visual.gd` additions** (all default to the old behaviour):
  - `auto_fit` export (false = keep the authored scale, no grounding).
  - `YawMode.NONE` now tracks the parent yaw, so lean uses the real facing.
  - `face_speaker_in_dialogue` + `speaker_turn_rate`: on `Events.dialogue_started`, if the player's current interactable is this node's NPC, the visual turns toward the player. On `dialogue_ended` it eases back. Cosmetic only; it connects to its own methods (no lambdas).
  - `get_look_target()`.
- **`player.gd`:** new read-only `get_current_interactable()` getter, used by the facing feature above.
- **JJ-2 NPC facing** (town + field `_add_npc`):
  - New optional `face_point` parameter. The default (INF) faces the main road (x = 0) 4 m toward the south approach.
  - The rotation is set before `add_child`, so there is no spin on load. Helper: static `npc_face_yaw(pos, face_point)`.
  - Merchant Soo now faces SW toward the road and spawn.
  - Every model NPC has `face_speaker_in_dialogue = true`. Verified: Ines `look_target = Player`, `yaw_local` −1.92 rad during dialogue, then null / 0.00 after.
- **JJ-3:** `field_zone._add_npc(..., model: PackedScene = null, face_point := INF)` now has the same RiglessVisual path as town. The dungeon has no NPCs.
- **JJ-4 models** (copied, not linked; imported; `_0.png` JPEG→PNG converted with PIL; re-imported with 0 errors; Lumina `asset.json` untouched):

  | Model | Run | File | Role |
  |---|---|---|---|
  | Teacher Female 2 | run-002 | `assets/models/characters/teacher_female2.glb` | Town NPC **Scholar Yeun** at (-4, 0, -27), quest-giver dialogue. No quest hook exists, so it is dialogue only. |
  | Alchemist Female 1 | run-002 | `assets/models/characters/alchemist_female1.glb` | Town NPC **Alchemist Ines** at (-7, 0, -14.5), vendor dialogue. No shop UI exists, so it is dialogue only. |
  | Goblin Male 2 | run-002 | `assets/models/characters/goblin_male2.glb` | Third entry of `ENEMY_MODELS` ("Goblin") in field + dungeon. Field enemies are now Kobold 3, Kobold Queen 3, Goblin 2. The dungeon gained a third regular spawn at (-7, 0, -6) so a Goblin appears. |
  | Goblinchief Male 1 | run-001 | `assets/models/characters/goblinchief_male1.glb` | Dungeon elite **Goblin Chief** at (3, 0, -16), via `dungeon_zone._add_elite()`. |

  - Goblin Chief details:
    - `rigless_fit_height` 2.4; fitted height measured at 2.4.
    - Exports: HP 140, damage 16, speed 3.2, attack_range 2.4, stagger_max 180.
    - `_scale_enemy_body()` sets per-spawn copies: capsule h 2.4 / r 0.56, hurtbox r 0.75 at y 1.2, LockOnPoint y 1.8, AttackOrigin scaled. `HealthBar` is moved to y 2.85.
    - `enemy_base.gd` is untouched. See the optional request to II.
- **JJ-5 screenshots** (windowed 1920x1080, zones loaded with `change_scene_to_file`):
  - `docs/ui_screenshots/v6_jj_01_amaro_idle.png`
  - `v6_jj_02_amaro_command_menu.png`
  - `v6_jj_03_amaro_ai_standing.png`
  - `v6_jj_04_town_merchant_soo_facing.png`
  - `v6_jj_05_town_scholar_yeun.png`
  - `v6_jj_06_town_alchemist_ines.png`
  - `v6_jj_07_town_dialogue_face_speaker.png`
  - `v6_jj_08_field_goblin.png`
  - `v6_jj_09_dungeon_goblin_chief.png`
  - In 08/09 the harness froze the enemies and turned them toward the camera, for the showcase only.
- **Tests (with GG/HH/II/KK work in progress in the tree):** 1729/1734.

  | Result | Suites |
  |---|---|
  | All pass | runner 35, phase6 111, phase7 23, phase9 56, phase10 72, phase11 63, phase13 64, phase14 67, phase15 68, battle 136, carry 80, controls 236, v4 96, v5 160 |
  | 1 failure each | phase8 64/65, phase12 64/65, performance 64/65 (the 3 known failures, KK) |
  | 1 failure + exit 139 | ui_style 140/141 |

  - The ui_style failure is "Target bar name uses enemy display_name": the test expects "reactor sentry", but since v5 the first field enemy is a Kobold. The same assertion exists at `b077c49`, so it predates JJ (for LL/KK). The exit 139 is KK's item.
- **Requests:**
  - HH filed none to JJ (MeleeStrike branches on the profile, so `player.gd` needs no change).
  - One optional request to II (`body_height` export) is in the table.
- **GG's note** ("red knight on the controlled body in Taighe shots"): in JJ's town harness, a party switch shows the Taighe model on the controlled body (shot 03). GG's shots likely set Taighe's data without a PartySystem visual swap. JJ did not reproduce it.
- **Wanted tests (for LL, `test_v6`):**
  - `anim_player` has `idle`/`walk`/`tpose`, and `idle` is the current animation in Idle, TacticalIdle (ts 0.05) and on the AI body after `switch_member()` (never `tpose`).
  - `idle` has 1 key per track; the hips X/Z are 0.
  - In `walk`, the hips' Z drift from the first to the last key is under 0.05 m and it loops.
  - The VisualRoot child is `IdleLayer` for Amaro, and the layer never changes the body's transform or velocity.
  - Merchant Soo's `rotation.y` equals `npc_face_yaw(Vector3(4, 0, -8))` and is non-zero.
  - Dialogue with a model NPC sets `get_look_target()` to the player; it is null after `dialogue_ended`.
  - Field and dungeon `ENEMY_MODELS` have 3 entries including "Goblin".
  - The dungeon has a "Goblin Chief" with a fit of 2.4, a capsule height of 2.4 and a LockOnPoint y > 1.6.
  - Scholar Yeun and Alchemist Ines exist with a RiglessVisual child.
- **CLAUDE.md contract drafts:**
  - "Rigged models never show a T-pose: Amaro's idle is a held walk pose (passing frames averaged) with a cosmetic IdleLayer bob/lean; the walk is in place and loops; this holds when AI-controlled and in the Command Menu."
  - "NPCs face the street/approach path by default (`_add_npc` `face_point`); model NPCs turn toward the player during dialogue and back after (cosmetic, RiglessVisual)."
  - "Dungeon elite Goblin Chief: 2.4 m rigless model, with the body (capsule/hurtbox/lock-on/health bar) scaled to match."

---

### KK — Stability (items 9–11)
Status: DONE (Head applied the stance_component.gd request; verified)
Owns:
- `src/world/town_builder.gd`, `src/ui/theme/ui_style.gd`, `src/ui/theme/widgets/*`
- `tests/test_phase8.gd`, `tests/test_phase12.gd`, `tests/test_performance.gd`, `tests/test_ui_style.gd` (exit-crash only)

Tasks:
- [x] KK-1. Find the cause of "7 resources still in use at exit" (`--verbose`, bisect the HUD scripts in `zone_base._spawn_hud` by asking the Head for a temporary toggle, or use a local harness). Suspects: the `TownBuilder._aabb_cache` static, UIStyle font cache, lambdas connected to autoload signals.
- [x] KK-2. Fix it so town and field exit clean (0 leaked resources). *Verified in a patched copy; the live tree needs the Head request applied.*
- [x] KK-3. `test_ui_style` exits with code 0 (no 139). *No crash and no leak once the request is applied. It exits 1, not 0, because of 1 test failure that already fails at b077c49 (see notes).*
- [x] KK-4. Update the 3 known-failure assertions to match reality: New Game → town_hub, "Return to Millhaven", 8 autoloads.
- [x] KK-5. Full suite: the known failures go from 3 to 0.

Handoff Notes:
- **Root cause.** None of the suspects (UIStyle fonts, autoload lambdas, the HUD scripts) causes it. I bisected with temp harnesses (deleted) on a `git archive HEAD` copy:
  - Player in tree: leaks. Player minus `StanceComponent`: no leak. `StanceComponent` with the runtime `load(REGISTRY[ability_id])` removed: no leak.
  - So the trigger is in `src/combat/stance_component.gd` `refresh_ability()`: it `load()`s `arcane_stance.gd` at runtime during the player's `_ready`.
  - After that load, Godot 4.6's exit cleanup (`GDScriptLanguage::finish`) no longer breaks the cycles of scripts loaded before it. A probe script that references itself leaks when loaded before the player's `_ready` and is freed when loaded after it. I did not pin down the exact C++ mechanism; it behaves like an engine bug.
  - Only self-referencing `class_name` scripts are victims:
    - `-> MenuRow` / `-> HeaderTab` / `-> ButtonGlyph` / `-> GlyphHint` return types, `ButtonGlyph.label_for`, and `GlyphHint.new()` inside `create()`;
    - `UIStyle` and `SlantPanel` leak because those scripts hold them;
    - `TownBuilder`, because of its `static var`.
  - The same mechanism makes `test_ui_style` segfault (139) at exit. With the fix it no longer crashes.
- **Fix (request to Head, see Cross-Agent Requests):** preload the unique-ability scripts in `StanceComponent.REGISTRY`. Verified on a copy of the live tree (including other agents' work in progress):
  - town, field, dungeon and test_arena exit with 0 leaked resources (`--quit-after 60`, exit 0);
  - the extra cycles from II (`threat_table.gd`↔`enemy_base.gd`) and HH (`basic_attack_profile.gd`↔`combo_component.gd`) are cleared too.
- **Owned-file change (defense in depth):** `src/world/town_builder.gd` replaces `static var _aabb_cache` with an Engine-meta dictionary (`_aabb_cache()`). Same caching, no visual change. TownBuilder no longer leaks even without the request.
- No UIStyle/widget changes. Removing the self-typed returns would also stop those leaks, but it would weaken the typed API every HUD/menu caller uses, so I left them as they are.
- **Tests changed:**
  - `tests/test_phase8.gd`: `town_hub.tscn`, "New Game loads town hub scene";
  - `tests/test_phase12.gd`: "Return to Millhaven";
  - `tests/test_performance.gd`: 8 autoloads.
- **Full suite (2026-11-13), live tree vs patched copy (live + stance request):**

  | Suite | Live pass/total | Live exit | Patched pass/total | Patched exit | Exit leak (live / patched) |
  |---|---|---|---|---|---|
  | runner | 35/35 | 0 | 35/35 | 0 | yes / yes* |
  | phase6 | 111/111 | 0 | 111/111 | 0 | no / no |
  | phase7 | 23/23 | 0 | 23/23 | 0 | no / no |
  | phase8 | 65/65 | 0 | 65/65 | 0 | no / no |
  | phase9 | 56/56 | 0 | 56/56 | 0 | no / no |
  | phase10 | 72/72 | 0 | 72/72 | 0 | no / no |
  | phase11 | 63/63 | 0 | 63/63 | 0 | no / no |
  | phase12 | 65/65 | 0 | 65/65 | 0 | no / no |
  | phase13 | 64/64 | 0 | 64/64 | 0 | no / no |
  | phase14 | 67/67 | 0 | 67/67 | 0 | no / no |
  | phase15 | 68/68 | 0 | 68/68 | 0 | no / no |
  | performance | 65/65 | 0 | 65/65 | 0 | yes / yes* |
  | battle | 136/136 | 0 | 136/136 | 0 | yes / no |
  | carry | 80/80 | 0 | 80/80 | 0 | yes / no |
  | controls | 236/236 | 0 | 236/236 | 0 | yes / no |
  | ui_style | 140/141 | 1 (139 on other runs) | 140/141 | 1 | yes / no |
  | v4 | 96/96 | 0 | 96/96 | 0 | yes / no |
  | v5 | 160/160 | 0 | 160/160 | 0 | no / no |

  Total: 1601/1602 live and patched. Known failures 3 → 0.
- **Open:**
  - (a) `test_ui_style` "Target bar name uses enemy display_name": it expects "reactor sentry", but field enemies are now named "Kobold A". It already fails at b077c49 in a clean HEAD copy. It is a test-expectation mismatch, not mine to change (`test_ui_style.gd` is exit-crash only for KK); suggest LL or the Head update it.
  - (b) *runner and performance still leak after the fix (`ui_style`, `arcane_orb`, `spell_projectile`, `enemy_base`, `threat_table`, `combo_component`, `basic_attack_profile`). Those suites `load()` scripts at runtime themselves, which is the same trigger. Not a game exit; left as is.
  - (c) Any new runtime `load()` of a `.gd` during gameplay can bring the leak back. Prefer `preload` for scripts.


---

### LL — QA (after all packages are DONE)
Status: DONE
Owns:
- `tests/*` (except KK's files), including a new `tests/test_v6.gd` + `.tscn`
- `tools/ui_screenshots.gd` (add a `-- v6` set)

Tasks:
- [x] LL-1. `test_v6`: the Taighe profile and combo, enemy retargeting and spacing against the companion, the companion downed path, the switch block on a downed member, Amaro has no T-pose, NPC facing, model wiring.
- [x] LL-2. Full suite run and a table of results (target: everything passes).
- [x] LL-3. A v6 screenshot set.
- [x] LL-4. Collect the CLAUDE.md contract drafts from all Handoff Notes into one list for the Head and user to approve.

Handoff Notes (LL, 2026-11-13):
- **Files changed:** new `tests/test_v6.gd` + `tests/test_v6.tscn` (no `class_name`; import run); `tests/test_ui_style.gd` (one assertion); `tools/ui_screenshots.gd` (`-- v6` set). No game code touched. No temp files left in the project (scratch only).
- **test_v6: 178/178, exit 0, no leak lines.** Sections:
  - *Contract (30):* hero/companion profiles (melee/mage), light 9/6, heavy 17/18, finisher by heavy count (Arcane Burst 2.0 / Frost Burst 2.6 / Frost Nova 3.4 / Lumina Nova 4.5, mult 1.4/1.7/2.2/3.0, order-free), Taighe AI kit (LLH, 9 m, keep 4 m); Amaro `STRIKES` unchanged; hold threshold 220 ms; ThreatTable constants + `pick()` (tie keeps current, crowd spreads, damage beats proximity); EnemyBase stop 1.5 / ring 1.8 / separation 1.3 / max 2 attackers; companion `FLINCH` last enum value, 0.45 s; `Events.party_member_damaged`; field + dungeon `ENEMY_MODELS` = Kobold / Kobold Queen / Goblin; field `_add_npc` model param; 4 new models import; **leak guard**: `StanceComponent.REGISTRY` values are `GDScript` (preloaded), no `load(REGISTRY` in the source.
  - *Bare world (II harness port, real player.tscn / enemy.tscn / PartySystem; 81):* Taighe AI body fires MageBolts in an LLH string (9, 9, Frost Burst 28.9) and never melees; after `switch_member()` the AI body (Amaro) runs melee (range 2.5) and the Player resolves mage, and back. 1v1/1v2/1v3 vs player and vs companion: every enemy targets that member, min distance to any member >= 1.45 m, enemies don't stack, 1 acquire per enemy, **<= 2 simultaneous attackers per member (per-frame count)**, strikes land through the hurtbox; companion: `party_member_damaged(companion, amount, source)` emitted, hit -> FLINCH with the string dropped, no actions while flinching; Hurtbox layer 32 / mask 16. Mixed: enemies split, companion damage draws its victim, **retargets of one enemy >= 2 s apart (game time)**, tactical 0.05 retarget with spacing held, time scale restored. Downed: DOWNED, hurtbox off, enemies drop it at once, no strikes/movement, no overlap with the downed body, no further damage, `switch_member()` and D-pad switch blocked, revive re-enables the hurtbox.
  - *Town (real input; 58):* Amaro anim has idle/walk/tpose, Idle plays `idle`, idle 1 key per track + hips X/Z 0, walk loops in place (< 5 cm), IdleLayer (no auto-fit, yaw NONE) bound to the Player body, moving plays `walk`, Command Menu (0.05) holds `idle`; NPCs: Soo faces `npc_face_yaw` (non-zero), every NPC faces the street, Yeun/Ines/Soo model paths + `face_speaker_in_dialogue`, Ines looks at the player in dialogue and lets go; **model check** (below); Taighe tap bolt (soft-aims the 8 m enemy, one hit of 9, one MageBolt, source = Player body), hold = charged shot (17, stagger exactly 18, 0 MP); LLL -> Arcane Burst: 9, 9, 12.6 and the side enemy at 3.5 m untouched; HHH -> Lumina Nova: 17, 17, 51 and the side enemy hit once for 51; B while the charged shot charges -> Dodge, bolt never launches, string reset, no damage; bolt in flight at 0.05 moves < 1.5 m in 0.3 s real and still lands; Amaro melee after switching back: light hits once for 12 via the hitbox, no MageBolts; Sword Slash: additive/unshaded/no depth write, `Sweep` visuals gone <= 0.27 s game time, hits only the 2.5 m enemy; out-of-range: bar content dimmed, panel modulate white + dark near-opaque fill + undimmed OUT OF RANGE pill, reticle dims but indicator root doesn't, label "OUT OF RANGE" >= 20 px on a StyleBoxFlat pill, all restored back in range.
  - *Dungeon (9):* Goblin (goblin_male2.glb) and Goblin Chief (goblinchief_male1.glb, fitted 2.4 m, capsule 2.4, LockOnPoint > 1.6, HealthBar > 2.6, HP 140, reach 2.4); enemy.tscn's shared capsule stays 1.6.
- **Model-mismatch verdict: no mismatch.** Real D-pad switch, both ways: before = Player shows Amaro (IdleLayer), AI body shows Taighe (RiglessVisual princess1.glb); after Up = Player shows Taighe, AI body Amaro, Taighe's RiglessVisual re-bound to the Player body and `player.model` updated; after Down = reversed again (6 asserts + the screenshot run's note "member=Taighe player shows RiglessVisual (princess1.glb), AI body shows Amaro (IdleLayer)"). Explanation of the suspicious shots: `tools/ui_screenshots.gd _place()` parks the AI body 2.2 m right / 2.6 m **behind** the player, i.e. between the player and the camera, so in GG's shots the Taighe AI body is the big figure in the foreground and the controlled Amaro (red knight) stands further in. The HUD (AMARO active) was right.
- **"Pale capsule-shaped shell" identified:** it is a **MageBolt impact flash** (`MageBoltImpact`, additive sphere, scale ~0.47 m, alpha 0.7) from the **Taighe AI's** quick bolts (the "9" damage numbers in GG's 01-03) hitting the near dummy. Its fade tween runs in game time (0.35 s), so under the Command Menu slow (0.05) it hangs on the dummy for ~7 s real — that's why GG saw it "before any cast", with the menu open. Reproduced in `v6_ll_06_pale_shell_repro.png` (note: impact at (0.6, 1.03, -3.94), 3 additive meshes within 1.5 m of the dummy's chest); with the companion parked (`v6_ll_05`) the shell is gone. Not a gameplay bug. Over the dark dungeon floor the same flash reads as an opaque white blob (seen in a first take of shot 11). Optional cosmetic request to Head/HH in the table.
- **test_ui_style fix:** "Target bar name uses enemy display_name" now compares the label against the locked enemy's own `display_name` (case-insensitive) instead of "reactor sentry". 141/141.
- **Full suite (sequential, headless, 2026-11-13, current tree):**

  | Suite | Pass/total | Exit | Leak lines at exit |
  |---|---|---|---|
  | runner | 35/35 | 0 | yes: "ObjectDB instances leaked" + "7 resources still in use" (KK open item b: the suite load()s scripts at runtime) |
  | phase6 | 111/111 | 0 | no |
  | phase7 | 23/23 | 0 | no |
  | phase8 | 65/65 | 0 | no |
  | phase9 | 56/56 | 0 | no |
  | phase10 | 72/72 | 0 | no |
  | phase11 | 63/63 | 0 | no |
  | phase12 | 65/65 | 0 | no |
  | phase13 | 64/64 | 0 | no |
  | phase14 | 67/67 | 0 | no |
  | phase15 | 68/68 | 0 | no |
  | performance | 65/65 | 0 | yes: same as runner (KK item b) |
  | battle | 136/136 | 0 | no |
  | carry | 80/80 | 0 | "ObjectDB instances leaked" only; `--verbose`: one `SceneTreeTimer` still pending at quit (a test timer), **no resources** in use. Harness-only. |
  | controls | 236/236 | 0 | no |
  | ui_style | 141/141 | 0 | no (no 139 crash) |
  | v4 | 96/96 (x4 runs) | 0 | no |
  | v5 | 160/160 | 0 | no |
  | v6 | 178/178 | 0 | no |

  **Total 1781/1781, every exit code 0.** Boot (`--headless --quit-after 1`) clean.
  - **v4 flake:** 4 sequential runs (1 in the full pass + 3 dedicated), 96/96 each; "Target step harness: Command Menu opens on Y" did not fail. It was seen once by II while other agents ran Godot concurrently; likely CPU-contention timing. Not reproduced.
- **v6 screenshots** (windowed 1920x1080, `--script res://tools/ui_screenshots.gd -- v6`, 11 shots, exit 0), `docs/ui_screenshots/`:
  - `v6_ll_01_amaro_idle.png` — Amaro from the front in Idle (anim `idle`), standing pose, no T-pose; Taighe beside.
  - `v6_ll_02_npc_scholar_yeun.png`, `v6_ll_03_npc_alchemist_ines.png` — at each NPC with the "Talk to Scholar Yeun / Alchemist Ines" prompt; **the NPC model is mostly hidden behind Amaro** (camera directly behind the player). JJ's `v6_jj_05`/`v6_jj_06` show the models clearly.
  - `v6_ll_04_sword_slash.png` — mid-sweep (Sweep node alive).
  - `v6_ll_05_out_of_range.png` — dark target bar panel, dimmed content, OUT OF RANGE pill, large reticle label; no shell on the near dummy.
  - `v6_ll_06_pale_shell_repro.png` — the shell repro (see above).
  - `v6_ll_07_enemies_ring_companion.png` — 3 enemies at 1.99/1.92/1.95 m around Taighe (AI body, frozen for the shot), all targeting her; the third is behind her from this angle.
  - `v6_ll_08_companion_downed.png` — Taighe downed (squashed), HUD panel "DOWNED", all 3 enemies retargeted to the Player.
  - `v6_ll_09_taighe_quick_bolt.png` — after a real D-pad switch: Player shows Taighe, bolt at the hand/in flight; the frozen Amaro AI body is caught mid-walk (harness freeze, not a T-pose).
  - `v6_ll_10_taighe_lumina_nova.png` — HHH burst: 51 on the target and 51 on the side enemy, "LUMINA NOVA COMBO H H H" banner; target readable through the translucent burst.
  - `v6_ll_11_dungeon_goblin_and_chief.png` — Goblin Chief (right) and Kobold Queen (back) visible, the Goblin at the left edge (cut off); dungeon lighting is very dark.
- **Other observations (not fixed, no game edits):**
  - `MageBolt.create()` does a runtime `load("res://src/combat/basic_attacks/mage_bolt.gd")` (KK rule c). No leak shows in any suite (callers preload it, so it's a cache hit). Noted in the table; no change advised.
  - The Kobold Queen model stands arms-out (authored mesh pose, rigless) — reads T-pose-like at distance; not a v6 regression.
- **CLAUDE.md contract-line drafts — consolidated and deduplicated (for user approval; CLAUDE.md not edited):**
  1. `- [ ] Basic attack is data-driven per member (PartyMemberData.basic_attack_profile): Amaro = sword combo; Taighe = mage bolts (tap = quick bolt, hold = charged shot, soft-track lock-on, 0 MP, builds stagger), mixable L/H 3-step whose step 3 is a ranged burst scaling with heavies (Arcane Burst 2 m -> Lumina Nova 4.5 m); same timing, dodge-cancel and air-combo rules as melee; AI-controlled members use the same profile` (HH)
  2. `- [ ] Enemies pick a target among the party by threat (damage dealt, proximity, stickiness, crowd spread), keyed by member id so a party switch keeps the enemy on the same member; re-evaluated every 0.5 s, voluntary switches at most once per 2 s; downed/dead members are dropped at once` (II)
  3. `- [ ] Spacing around ANY targeted member: ring slots at preferred radius (attack_range - 0.2, 1.8 m), stop distance 1.5 m from every party member (downed included), enemy separation 1.3 m, at most 2 simultaneous attackers per member` (II)
  4. `- [ ] AI companion has a Hurtbox (same layers as the Player): hits flinch it (0.45 s, no actions, string interrupted); 0 HP = downed (no actions, not targetable, hurtbox off, switch onto it blocked)` (II)
  5. `- [ ] Rigged models never show a T-pose: Amaro's idle is a held walk pose (passing frames averaged) with a cosmetic IdleLayer bob/lean; the walk is in place and loops; this holds when AI-controlled and in the Command Menu` (JJ)
  6. `- [ ] NPCs face the street/approach path by default (_add_npc face_point); model NPCs turn toward the player during dialogue and back after (cosmetic, RiglessVisual)` (JJ)
  7. `- [ ] Dungeon elite Goblin Chief: 2.4 m rigless model, with the body (capsule/hurtbox/lock-on/health bar) scaled to match` (JJ)
  8. `- [ ] Ability VFX are translucent additive (unshaded, no depth write) and fade within 0.25 s (Sword Slash); multi-hit spells show a hit flash per hit; the target stays readable through every effect` (GG, part 1)
  9. `- [ ] Out-of-range: the reticle dims while the "OUT OF RANGE" label stays large on a dark pill; the target bar keeps its dark panel and dims only its content` (GG, part 2 — refines the existing "Per-spell range ... (reticle + target bar dim)" line; apply as an amendment to that line rather than a new one)
  - Dedup notes: GG's single draft was split into 8 + 9 because 9 overlaps the existing per-spell-range line. II's line 4 "switch onto it blocked" complements the existing party-switch line ("blocked in ... dead"); either add it there as "dead/downed" or keep line 4. KK filed no contract draft (its rule "prefer preload for scripts; no runtime load() of .gd during gameplay" could become a coding rule if the user wants one — LL suggestion only). All 9 lines are covered by test_v6 asserts.

---

### Cross-Agent Requests
| From | To | Request | Status |
|---|---|---|---|
| — | — | — | — |
| KK | Head | **Exit-leak root fix (KK-1/2/3).** `src/combat/stance_component.gd` (unowned → Head): preload the unique-ability scripts instead of `load()`ing one at runtime in `refresh_ability()`. In `REGISTRY` replace `&"arcane_stance": "res://src/combat/unique_abilities/arcane_stance.gd",` / `&"super_jump": "res://src/combat/unique_abilities/super_jump.gd",` with `&"arcane_stance": preload("res://src/combat/unique_abilities/arcane_stance.gd"),` / `&"super_jump": preload("res://src/combat/unique_abilities/super_jump.gd"),`, and in `refresh_ability()` replace `var script: GDScript = load(REGISTRY[ability_id])` with `var script: GDScript = REGISTRY[ability_id]`. Update the header comment "resolved through REGISTRY (id -> script)" stays true; add "(preloaded: a runtime load() here made Godot skip breaking script cycles at exit)". Why: the runtime `load()` during the player's `_ready` is what stops Godot from clearing self-referencing `class_name` scripts at exit (UIStyle widgets, plus II's ThreatTable↔EnemyBase and HH's BasicAttackProfile↔ComboComponent), so they leak, and test_ui_style segfaults (139). Verified in a throwaway copy of the live tree: town/field/dungeon/arena exit with 0 leaks; test_ui_style no longer crashes. | DONE (Head: town/field/dungeon exit 0, 0 leaks; ui_style no crash) |
| II | Head | `scripts/autoloads/events.gd`, Party section, add: `signal party_member_damaged(member_id: StringName, amount: float, source: Node3D)`. `companion_ai.take_damage` already emits it through `Events.has_signal(&"party_member_damaged")`, so nothing breaks before it exists. Optional; the HUD already polls HP. | DONE (Head, boot clean) |
| JJ | II | (Optional, not blocking) `enemy_base.gd`: a `body_height` export that scales the body capsule, hurtbox, LockOnPoint, AttackOrigin and health bar (`HEALTH_BAR_Y_OFFSET` is a const). Until then `dungeon_zone._scale_enemy_body()` resizes per-spawn duplicates of those shapes/markers before `_ready` and moves `HealthBar` after it (Goblin Chief, 2.4 m). If II adds the export, JJ/LL can swap the helper for it. | II: not done in v6 (optional). The helper is compatible with the v6 spacing (see the II Handoff Notes). |
| LL | Head (HH area) | (Optional, cosmetic) `src/combat/basic_attacks/mage_bolt.gd _spawn_spark()`: the impact flash's fade tween runs in game time (0.35 s), so a companion bolt that lands just before the Command Menu opens leaves a pale additive sphere on the target for ~7 s real (GG's "pale capsule shell"; repro `v6_ll_06_pale_shell_repro.png`). Suggested fix: `tw.set_ignore_time_scale(true)` on that tween (or shorten/cap it). (Note only: `MageBolt.create()` runtime-`load()`s its own script; it is already preloaded by its callers, so it's a cache hit and no suite shows a leak. A self-`preload` const would add the self-reference KK described, so leave it.) No test fails either way. | DONE (Head: tween set_ignore_time_scale) |

## 7. Head review checklist (fill in per run)
- [x] R-1. Signals and registrations requested by agents added.
- [x] R-2. Diffs reviewed: ownership respected, no camera mutation outside the camera owner, UIStyle only, no new exit leaks.
- [x] R-3. Boot and full suite reproduced by Head.
- [x] R-4. Scene trees printed; signals verified.
- [x] R-5. Screenshots reviewed.
- [x] R-6. CLAUDE.md lines applied after user approval, then the controller test, `project_status.json`, and a commit with approval.

### Head proof (2026-11-13)
- Applied requests: `events.gd` `party_member_damaged` (II); `stance_component.gd` preload fix (KK, root cause of the exit leak); `mage_bolt.gd` impact-flash tween ignores time scale (LL, the "pale shell").
- Boot exit 0, 0 errors. Full suite reproduced by Head: 19 suites, **1781/1781, all exit 0**. Exit-leak lines only in runner/performance (runtime `load()` in those test files) and carry (one pending test timer); town/field/dungeon exit with 0 leaks.
- Runtime trees printed: Player (VisualRoot/IdleLayer added), Companion (Hurtbox added), dungeon enemies (Kobold, Kobold Queen, Goblin, Goblin Chief). Signals: `party_member_damaged` defined, emitted by companion_ai, no listeners (HUD polls HP).
- Screenshots reviewed: GG 01/02, HH 01, JJ 03/09.
- R-6 waits on user approval of the 9 CLAUDE.md lines (LL Handoff Notes) and the commit.
