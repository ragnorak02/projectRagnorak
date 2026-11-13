# UI Modernization Plan — Modern Action-RPG HUD & Menus

Created: 2026-11-12
Owner: Head Agent (reviews and verifies all work)
Status: IN PROGRESS — Wave 1 (K) launched. User approved fonts download and Amaro/Taighe rename (head renamed hero.tres → "Amaro", companion.tres → "Taighe"; test_phase13 updated).
Previous plans: `controller_remap_plan.md` (v1), `controls_v2_carry_plan.md` (v2)

---

## How to use this file (ALL AGENTS READ FIRST)

The protocol is the same as v1 and v2:
1. Do only your package's tasks.
2. Edit only your **Owned files**. Put any change needed in another agent's file under **Cross-Agent Requests**.
3. Status lifecycle: `IN PROGRESS` (Started time) → `DONE — AWAITING REVIEW` (Finished time + Handoff Notes). Tick tasks as you go, never delete tasks, and mark unnecessary ones `N/A` with a reason.
4. Before DONE, run a headless boot and paste the result: `Z:/godot/godot.exe --path . --headless --quit-after 1`.
5. The plan file is edited concurrently. Re-read it before each edit and keep edits small and inside your own section.
6. Don't commit. Don't edit `project_status.json` or `CLAUDE.md`.
7. Godot is `Z:/godot/godot.exe`. If you add a `class_name`, run `--headless --import`.
8. **UI must stay controller-first.** Every screen must be fully navigable with the D-pad/stick, A (confirm) and B (back). Never rely on the mouse.
9. **Behaviour contracts are frozen.** This is a visual pass. Don't change what signals UIs listen to or emit, the input actions they read, or the tactical state machine. The existing tests (`test_controls`, `test_carry`, phase suites) must keep passing. Source-grep tests may look for specific strings, so check `tests/` before renaming anything.

Working directory: `Z:/Development/lumina/games/projectRagnorak`

---

## User request (2026-11-12)

> The menu should look a lot more like FF7 Rebirth. Modernize the menu system and the look of the UI.

The user's screenshot of the current game shows:
- Flat navy boxes with thin borders, and generic fonts.
- The command and target list sits on the right as a large, mostly empty box.
- A full-width control-hint bar runs along the bottom, with raw bars at the bottom-left.
- The quest box sits top-right.
- An NPC name label ("Villager") renders huge when the camera is close.
- A target hint reads "[Left/Right] Switch", but the list is vertical.

---

## Design Direction (Approved Design)

**Layout conventions** of the modern hybrid action-RPG HUD (the genre layout the user referenced). The visual identity is **our own**: no copied art, logos, fonts or exact panel shapes from any existing game.

### Visual identity: "Lumina Frost"
This fits the lore: Lumina is super-cooled, and its reactors sit under ice and water.
- **Panels:** dark translucent glass (`#0A1420`, about 78% opacity). The left edge is cut at an angle (a slanted parallelogram via a custom `draw_*` or StyleBoxFlat skew). There's a thin cyan light-line on the top edge and a faint vertical gradient.
- **Primary accent:** Lumina cyan `#5FE3F0`, with a glow on the selected item.
- **Secondary accent:** ember gold `#F2B544`, the studio brand. Use it for ATB, headers and important numbers.
- **HP:** teal-to-cyan gradient. **MP:** violet `#B48CFF`. **ATB:** gold, segmented into 2 cells (each cell = 50). **Stagger:** orange `#FF8A3D`. **Danger/low HP:** `#FF5C5C`.
- **Text:** off-white `#E8F1F5`; dim text `#7F95A3`; disabled `#4A5A66`.
- **Font:** one geometric/condensed sans, OFL-licensed and bundled in `assets/fonts/`, for example **Rajdhani** (headers) plus **Exo 2** or **Barlow** (body). The package owner downloads the TTFs from Google Fonts and includes the OFL licence text. Fall back to the Godot default if they're missing.
- **Motion:** minimal, matching the studio rule. Fade in and slide 8–12px over 120–160ms, and a soft pulse on the selected row. No bouncing.
- **Controller glyphs:** procedural round badges drawn in code (A green, B red, X blue, Y yellow, LB/RB/LT/RT pill shapes). Keyboard glyphs are key-cap boxes. The active device decides which set shows (`InputManager`).

### Screen layout (1920×1080 reference, anchored so it scales)

| Region | Content |
|---|---|
| Bottom-right | **Party panel.** One slanted row per member. The active member's row is larger and highlighted, with name, HP bar plus number, MP number, a 2-cell ATB gauge and the team meter under the active row. Downed members are greyed. |
| Bottom-left | **Command panel.** Hidden until A. A title tab reads "COMMAND" with the active character's name. Category tabs (Abilities / Magic / Items) switch with D-pad L/R or the stick. The list shows each item's ATB pips and MP cost, and unavailable rows are greyed with the reason. Target selection replaces the list with target names plus a world-space marker. |
| Bottom strip, above the screen edge | **Description line** for the highlighted command, shown only while the menu is open. |
| Top-centre | **Target bar.** Shown when locked on or targeting: enemy name, HP bar, stagger gauge, "STAGGERED ×%" tag. Hidden otherwise. |
| Top-left | **Quest tracker:** a compact title plus the current objective, using the small glass panel. |
| Bottom-centre | **Interaction prompt:** a glyph badge plus a verb ("Talk to Villager"), small, sitting above the party/command panels. |
| Left edge, small | **Context hints** (replace the full-width control bar). Show 3–4 relevant hints for the current state, such as "A Command, B Interact, LB Dodge", or the carry hints while carrying. Respect the `show_control_hints` setting. |
| Full screen (tactical) | Tactical-mode treatment: slight desaturation and cool tint, plus a vignette while time is slowed. Purely visual. |

### Menus (pause and sub-menus)
- **Pause menu:**
  - Full-screen dim and blur (a blurred screen-texture shader if cheap, otherwise a darker tint).
  - Left column: vertical nav (Party, Items, Quests, Save, Load, Settings, Return to Title), using big slanted buttons.
  - Right side: a party overview card for each member (name, level placeholder, HP/MP, equipped weapon if available), plus a footer with play time and the zone name.
- **Quest log, save/load, settings:** the same shell (header bar with title, a content glass panel, and a footer glyph bar such as "A Select, B Back").
- **Dialogue box:** a wide lower-third glass panel with a speaker name tab and a glyph advance indicator.

### Out of scope
New gameplay features, character portraits/art (use name plates and placeholders), a real inventory screen if none exists (the Items nav entry can show "Coming soon"), shortcut menus (LB) and ally command menus.

---

## Work Packages

- **Wave 1:** **K** (foundation) runs alone first. All other packages depend on its API, so K must publish it fast.
- **Wave 2 (parallel):** **L**, **M**, **N** and **O**, after K's API is published.
- **Wave 3:** **P** takes screenshots and runs tests, then head review.

---

### Package K — UI Foundation (style kit, fonts, widgets)
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
API PUBLISHED: yes (2026-11-12, after smoke test)
Finished: 2026-11-12

Owned files: **new** `src/ui/theme/ui_style.gd` (`class_name UIStyle`, static), **new** `src/ui/theme/widgets/*.gd` (`SlantPanel`, `Gauge`, `SegmentGauge`, `ButtonGlyph`, `GlyphHint`, `MenuRow`, `HeaderTab`), **new** `assets/fonts/*` + `OFL.txt`

- [x] K1. `UIStyle`:
  - Palette constants (from the Design Direction) and font getters with fallback (`font_header()`, `font_body()`, sizes S/M/L/XL).
  - StyleBox factories: `glass_panel()`, `glass_panel_selected()` and `pill()`.
  - Tween helpers: `fade_slide_in(node, dir)` and `pulse(node)`.
- [x] K2. `SlantPanel` (a Control or PanelContainer with custom `_draw`): angled left/right edge, glass fill, top light-line, optional selected glow.
- [x] K3. `Gauge`: smooth fill toward a target value with a lag "damage chip" segment (a white/red trail when value drops). Colour options, and an optional numeric label.
  - `SegmentGauge`: N cells, each with partial fill (for ATB).
- [x] K4. `ButtonGlyph`: shows the glyph for an **action name** (`&"interact"`, etc.) on the active device. It reads `SettingsManager.get_action_label()` and redraws when the device or bindings change. Controller face buttons are coloured circles; shoulders and triggers are pills; keys are key-caps.
  - `GlyphHint` = a glyph plus a label.
- [x] K5. `MenuRow`: a selectable row with selected, disabled and normal states, optional right-side cost widgets, and a selection pulse.
  - `HeaderTab`: a title tab with a slant.
- [x] K6. Fonts: download the chosen OFL fonts into `assets/fonts/` with `OFL.txt` and import them. If the download fails, keep the fallback and note it.
- [x] K7. Make a demo scene, `src/ui/theme/ui_style_demo.tscn`, that shows every widget. P uses it for screenshots.
- [x] K8. **Publish the API** (class names, method signatures, usage snippets) in Handoff Notes, then set `API PUBLISHED: yes (time)`.
- [x] K9. Headless boot passes.

Handoff Notes:
- **API (K8), published 2026-11-12.** Every class is a global `class_name`. Every widget instantiates with `.new()` (no .tscn needed), is headless-safe, and animates in **unscaled** time. Tweens use `set_ignore_time_scale(true)`; gauges use `Time.get_ticks_usec()`.
- Fonts are bundled (OFL, from google/fonts): `assets/fonts/rajdhani/` (Rajdhani Medium/SemiBold/Bold + OFL.txt) and `assets/fonts/barlow/` (Barlow Regular/Medium/SemiBold + OFL.txt). If a file is missing, the font getters fall back to `ThemeDB.fallback_font`.
- **`UIStyle`** (static, `src/ui/theme/ui_style.gd`)
  - Colours: `GLASS GLASS_DEEP GLASS_LIGHT CYAN CYAN_DIM CYAN_GLOW GOLD GOLD_DIM HP_START HP_END MP ATB ATB_FULL STAGGER DANGER CHIP GAUGE_BACK TEXT TEXT_DIM TEXT_DISABLED SHADOW DIM_SCREEN GLYPH_A/B/X/Y GLYPH_PILL KEYCAP_FILL KEYCAP_EDGE`
  - Sizes: `SIZE_S=16 SIZE_M=22 SIZE_L=30 SIZE_XL=48`, `SLANT=18`, `ANIM_TIME=0.14`, `SLIDE_DIST=10`
  - Fonts: `font_header()` (Rajdhani Bold), `font_header_medium()` (Rajdhani SemiBold), `font_body()` (Barlow Medium), `font_body_bold()` (Barlow SemiBold), `fonts_bundled() -> bool`. The `FONT_*_PATH` consts also work for `Label3D.font`.
  - Labels: `style_label(label, size=SIZE_M, color=TEXT, header=false, outline=0)` and `make_label(text, size, color, header) -> Label`
  - StyleBoxes:
    - `glass_panel(margin=14)` and `glass_panel_selected(margin=14)`
    - `pill(color=GLASS, border=transparent, margin_h=12, margin_v=4)`
    - `slant_row(state="normal"|"selected"|"disabled")`, a skewed StyleBoxFlat
    - `style_button(button, size=SIZE_M)` restyles an **existing** Button in place. Its text, signals and focus stay the same, so it's the safe choice for O.
    - `make_theme() -> Theme` gives Lumina defaults for Label, Button, Panel and PanelContainer.
  - Tweens:
    - `ui_tween(node) -> Tween` is unscaled. It returns null when the node is outside the tree.
    - `fade_slide_in(node, dir=Vector2.LEFT, duration=0.14, distance=10) -> Tween` shows the node, fades it in and slides it in from `dir`. It slides only when the parent isn't a Container; otherwise it just fades.
    - `fade_out(node, duration=0.14, hide_after=true, dir=ZERO, distance=10) -> Tween`
    - `pulse(node, strength=0.25, period=1.1) -> Tween` loops `self_modulate`. Stop it with `stop_pulse(node)`.
  - Draw helpers: `slant_points(rect, slant, left=true, right=false) -> PackedVector2Array` and `hp_color(ratio, low_threshold=0.25) -> Color`
- **`SlantPanel extends PanelContainer`**: add children normally.
  - Exports: `slant=18 slant_left=true slant_right=false padding=12 fill_color fill_bottom_color line_color show_top_line=true selected=false glow_color`
  - Content margins include the slant automatically.
- **`Gauge extends Control`** (default min size 160×12)
  - Exports: `max_value value fill_color fill_color_end back_color chip_color low_threshold(0=off) low_color slant=6 show_label label_format="%d / %d" label_size chip_delay=0.35 chip_drain_speed fill_speed`
  - Methods: `set_values(value, max, instant=false)`, `snap()`, `get_target_ratio()`, `get_display_ratio()`, `is_low()`
  - Signal: `low_state_changed(is_low)`
  - A drop snaps the fill and drains the chip trail; a rise fills smoothly. For MP, set `fill_color = fill_color_end = UIStyle.MP`. For stagger, use `UIStyle.STAGGER`.
- **`SegmentGauge extends Control`** for ATB (default min size 120×8)
  - Exports: `segments=2 per_segment=50 value fill_color full_color back_color gap slant smooth_speed`
  - Methods: `set_value(v, instant=false)`, `snap()`, `get_max_value()`, `get_full_segments()`, `get_display_value()`
  - Signal: `segment_filled(index)`
- **`ButtonGlyph extends Control`**
  - Exports: `action: StringName`, `device: ButtonGlyph.Device {AUTO, KEYBOARD, CONTROLLER}` (AUTO follows `InputManager.is_using_controller()`), `label_override: String` (draws a literal label, e.g. "A" or "D-Left/D-Right"), `glyph_height=26`, `max_parts=2`
  - Methods: `setup(action, device=AUTO) -> ButtonGlyph`, `get_label() -> String`, `is_controller()`, `refresh()`, and `static label_for(action, controller) -> String`, which wraps `SettingsManager.get_action_label` and returns "---" without autoloads.
  - Signal: `glyph_changed(label)`
  - It auto-refreshes on `InputManager.device_changed` and `SettingsManager.settings_changed`. **Note:** `SettingsManager.rebind_action()` doesn't emit `settings_changed` (only `apply_settings()` does), so call `refresh()` after a rebind if needed.
  - Shapes: A/B/X/Y are coloured circles. LB/RB/LT/RT/Back/Start/L3/R3/LS/RS are pills. D-Up/D-Down/D-Left/D-Right are a cross with the lit direction. Keys and mouse buttons are key-caps.
  - Action names: `move_* camera_* jump attack dodge interact sprint tactical_mode lock_on camera_reset pause target_switch_left target_switch_right quicksave party_switch quickload ui_accept ui_cancel` (plus the built-in `ui_up`/`ui_down`/...). Current pad bindings: interact=B, jump=Y.
- **`GlyphHint extends HBoxContainer`**
  - Exports: `action text font_size=SIZE_S text_color glyph_height=24`
  - Methods: `static create(action, text, font_size=SIZE_S, device=ButtonGlyph.Device.AUTO) -> GlyphHint`, `setup(action, text)`, `get_glyph()`, `get_label()`
- **`MenuRow extends Button`**, so `pressed`, focus navigation and `disabled` all still work.
  - Exports: `selected` (or focus = highlighted), `unavailable` (greyed but still highlightable), `unavailable_reason`, `description` (data only), `atb_cost` (gold pips), `mp_cost` (-1 = hidden, violet "N MP"), `right_text`, `row_font_size=SIZE_M`
  - Methods: `setup(text, atb_cost=0, mp_cost=-1, unavailable=false, reason="") -> MenuRow`, `is_highlighted()`, `is_greyed()`
  - Signal: `selected_changed(is_selected)`
  - When highlighted, its accent bar pulses (unscaled). For cursor-driven lists (M), set `focus_mode = FOCUS_NONE` and toggle `selected`.
- **`HeaderTab extends SlantPanel`** (slanted on the right, gold line)
  - Exports: `title subtitle uppercase=true title_size=SIZE_M title_color=GOLD`
  - Methods: `setup(title, subtitle="") -> HeaderTab`, `get_title_label()`, `get_subtitle_label()`
- Snippet:
  ```gdscript
  var panel := SlantPanel.new(); add_child(panel)
  var v := VBoxContainer.new(); panel.add_child(v)
  v.add_child(HeaderTab.new().setup("Command", "Amaro"))
  var hp := Gauge.new(); hp.low_threshold = 0.25; hp.show_label = true; v.add_child(hp); hp.set_values(cur, mx, true)
  var atb := SegmentGauge.new(); v.add_child(atb); atb.set_value(player.atb)
  v.add_child(MenuRow.new().setup("Fire", 1, 8, mp < 8, "Not enough MP"))
  v.add_child(GlyphHint.create(&"ui_accept", "Confirm"))
  UIStyle.fade_slide_in(panel, Vector2.LEFT)
  ```

- **Gotchas for L/M/N/O:**
  - Don't declare `Array[MenuRow]` (or any `Array[<widget class_name>]`) as a member of a scene script. In Godot 4.6 it leaks the scripts at exit ("resources still in use"). Use a plain `Array` or `Array[Control]` instead.
  - MenuRow refreshes its style one frame late on focus *loss* (deferred, so shutdown is safe). `is_highlighted()` is always exact.
- K7: the demo is `src/ui/theme/ui_style_demo.tscn` (+ `ui_style_demo.gd`). The gauges cycle damage and heal every 1.2s, and Up/Down moves the row focus. I captured it windowed at 1920×1080 and checked it visually: HP chip trail, low-HP red, 2-cell ATB, greyed rows, glyphs for both devices. Keyboard glyphs hide "Kp ..." duplicates.
- K9: `--headless --import` is clean. Headless boot `--quit-after 1` printed only the version banner (exit 0, no errors). The demo scene ran headless for 120 frames with no errors or leaks.
- No files outside K's ownership were edited.

---

### Package L — Combat HUD: Party Panel, Target Bar, Lock-On, Tactical Overlay
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `src/ui/hud/combat_hud.gd`, `src/ui/hud/lock_on_indicator.gd`, **new** `src/ui/hud/target_bar.gd`, **new** `src/ui/hud/tactical_overlay.gd`

- [x] L1. Rebuild `combat_hud.gd` as the bottom-right **party panel**:
  - One row per party member: player plus companions from the party system (`get_member_count`, the member data, `Events.party_*`).
  - The active member's row is larger: name, HP Gauge plus number, MP number, a 2-cell ATB SegmentGauge, and the team meter.
  - Keep all existing signal connections and the failure flash (`ability_request_failed`, "Not enough MP!" etc.). Restyle the flash text as a small toast above the panel.
- [x] L2. Low-HP state: the HP number and bar edge turn danger red, with a subtle pulse.
- [x] L3. New `target_bar.gd` at top-centre:
  - Shows on lock-on or target selection: name, HP Gauge with chip, stagger gauge if enemies expose stagger, and a "STAGGERED" tag.
  - Read enemy data via public properties and signals only. If stagger isn't exposed, file a Cross-Agent Request.
- [x] L4. `lock_on_indicator.gd`: restyle the reticle as a thin rotating cyan diamond with a small "LOCKED ON" label under it, matching the style kit.
- [x] L5. New `tactical_overlay.gd`: on `tactical_mode_entered/exited`, fade in a desaturate/cool-tint and vignette full-screen layer (shader on a ColorRect, using `hint_screen_texture`). It must not block input (`mouse_filter` ignore). File a Cross-Agent Request to the head agent to register L3/L5 in `zone_base._spawn_hud` and `test_arena`.
- [x] L6. Headless boot passes. Load field_zone headless for 60 frames with no errors.

Handoff Notes:
- **combat_hud.gd** (layer 10): bottom-right party panel. Rows come from `player.party_system.members` (display names from the `PartyMemberData` resources, so "Amaro"/"Taighe"; falls back to hero.tres when there's no party). The active row is larger and selected, with name, HP Gauge + "cur / max", MP Gauge + number, 2-cell ATB SegmentGauge (`ATB_SEGMENT_COST = 50`, cell count = max/50) + full-cell count, and the TEAM meter (pulses when full). Ally rows are compact and dimmer. Downed rows are greyed with a "DOWNED" tag.
  - Player row is fed by `player_*` signals (values cached, so rebuilt rows start correct). Companion rows poll `current_hp/max_hp/current_mp/current_atb` (no per-companion signals exist).
  - The roster re-syncs on `party_member_joined`/`party_member_switched` (new connection, additive) and a 250ms real-time check. That handles test_arena, where the party is created after the HUD.
  - All 12 original `Events` connections are kept. Failure texts are unchanged ("Not enough MP!" etc., shown uppercased) in a pill toast above the panel. MP/ATB bars flash red. Cast names toast in gold. Cooldown readouts sit above the rows.
  - Every tween is unscaled (`UIStyle.ui_tween` / `set_ignore_time_scale`). Rows are stored in a plain `Array` of Dictionaries (no typed widget arrays).
  - L2: Gauge `low_threshold = 0.25` turns the bar and its edge red, and the HP number turns DANGER and pulses. At ≤0.5 the number is tinted gold.
- **target_bar.gd** (new, layer 10): top-centre SlantPanel (both edges slanted, red top line for enemies, cyan for allies). It shows the name, HP% and an HP Gauge with chip.
  - Shown on `lock_on_target_acquired/switched`, which tactical target selection also emits. Hidden on `lock_on_target_lost`, `enemy_died`, or an invalid target. Fades and slides in from above.
  - Name: `display_name` → `member_data.display_name` → hero.tres for the player → otherwise "Enemy"/"Target" for auto-generated names.
  - The stagger gauge and the "STAGGERED ×%" pill are duck-typed and stay hidden until enemies expose `stagger_value`/`stagger_max` and `is_staggered()` (optionally `stagger_damage_multiplier`). See Cross-Agent Request.
  - Read-only helpers: `get_target()`, `is_shown()`, `static target_display_name(node)`.
- **lock_on_indicator.gd**: a procedural thin cyan diamond with broken edges and a soft glow. It rotates in real time, with a counter-rotating inner diamond and a centre dot. Below it is a "LOCKED ON" label, which becomes a gold "TARGET" while tactical mode is open. It keeps `_pulse_tween` scale/TRANS_BACK (now unscaled), the validity checks and `_connect_signals`.
- **tactical_overlay.gd** (new, layer 8, below the HUD): a full-rect ColorRect with a `hint_screen_texture` shader that desaturates 45%, adds a cool tint and a vignette. `amount` fades 0→1 over 0.16s on `tactical_mode_entered` and back over 0.14s on exit, in unscaled time. It's hidden when the amount is 0 and uses `MOUSE_FILTER_IGNORE`. Helpers: `is_active()`, `get_amount()`.
- Tests: these suites run with no failures in L-owned assertions: phase6 (110/111), phase8 (63/65), phase13 64/64, phase14 67/67, phase15 68/68, performance (64/65), phase12 (64/65), phase7 23/23, controls 157/157. The remaining failures are in other files: TacticalIdle slot navigation, pause-menu transparent bg, New Game → test arena, the 8-autoload count, and return portals.
- Screenshots (windowed 1920×1080, field_zone, target_bar + tactical_overlay instantiated by the capture script): `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/l_free_roam.png`, `l_lock_on.png`, `l_low_hp_toast.png`, `l_tactical.png` (same dir). The capture script is `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/l_capture.gd`. The party panel (x≈1425–1885) does not overlap M's command panel or description strip (x≤910).
- L6: headless boot `--quit-after 1` printed only the version banner (exit 0). Field_zone loaded headless for 200+ frames with target_bar and tactical_overlay added and lock-on, low HP, toast and tactical driven: no errors or leaks.

---

### Package M — Command Menu (Tactical) Visuals
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `src/ui/hud/tactical_menu.gd` only. Don't touch `tactical_idle_state.gd`; the behaviour is frozen.

- [x] M1. Move the menu to the **bottom-left**, above the hint area. Use a HeaderTab "COMMAND" with the active character's name and a SlantPanel list.
- [x] M2. Category display: show Abilities / Magic / Items as tabs across the top of the panel. Highlight them from the existing `tactical_category_changed` / `tactical_slot_changed` signals. Keep the existing phase flow (category list → ability list → targets). If you want category switching on D-pad L/R, file a request; don't change the state script.
- [x] M3. Ability rows use `MenuRow`: name, ATB cost pips (gold cells), MP cost (violet). Unavailable rows are greyed with a short reason shown on the description line.
- [x] M4. Description line: a bottom-of-screen glass strip with the highlighted ability's description (`AbilityData.description` if it exists, otherwise its type and cost).
- [x] M5. Target phase:
  - The list shows target names with HP percentages.
  - Fix the hint text: the list is vertical, so the hint should read "Up/Down Select". Check which inputs `tactical_idle_state` actually cycles on (left/right **and** target_switch) and show glyphs for what really works.
  - Use `GlyphHint`s for A Confirm and B Back.
- [x] M6. Open and close animation: fade and slide in from the left over about 140ms. Use unscaled time so the 10% time scale doesn't make it crawl (tweens `set_ignore_time_scale(true)`).
- [x] M7. Keep every public method and signal hookup, so tests that grep this file still pass. Run test_phase6/7/9 and test_controls.
- [x] M8. Headless boot passes.

Handoff Notes:
- Only `src/ui/hud/tactical_menu.gd` was edited. `tactical_idle_state.gd` was read but not changed. The menu only listens to the signals it used before, plus `player_atb_changed`/`player_mp_changed` so rows re-grey in place while ATB fills at 0.1x.
- **Layout:** bottom-left column at x=48, width 470, made of HeaderTab "COMMAND / <active name>" + SlantPanel. The description strip is a `glass_panel` at the bottom (x 48–908, 28px from the edge), so it stays clear of L's party panel (bottom-right). Lists longer than 6 rows scroll with the cursor and add a "n / N" counter to the caption, so the panel never grows past about y=565. N's left-edge hints are hidden in tactical mode, so they don't collide with the menu.
- **M2:** Abilities/Magic/Items pill tabs. In the category phase they follow the cursor (`tactical_slot_changed`); after that they show the chosen category (`tactical_category_changed`). The phase flow is unchanged. Category switching on D-pad L/R was not requested.
- **M3:** MenuRows show ATB pips (ceil(atb_cost/50) cells) and violet MP. Unavailable rows are greyed, and the description line shows a red reason: "Not enough ATB", "Not enough MP" or "Recharging — 2.3s".
- **M4:** the strip shows `AbilityData.description`, falling back to "<Type> — N ATB, N MP". Categories and targets have their own lines (e.g. "Fire Bolt › Enemy A   HP 100%").
- **M5:** target rows show HP %, using the candidate order rebuilt read-only from the state's rules. The hint shows the inputs that actually cycle: `target_switch_left/right` glyphs (D-Left/D-Right on pad, `[`/`]` on keyboard; stick/A-D/arrows also work) + "Switch", then A Confirm and B Back as GlyphHints. Enemies have no `display_name`, so the state sends node names like "@CharacterBody3D@820". The menu shows these as "Enemy A/B/…" for display only; indices are unchanged.
- **M6:** `UIStyle.fade_slide_in`/`fade_out` run on full-rect host Controls (home is always 0,0, so it's safe on resize) and use unscaled time. The panel slides in from the left and the strip from below. The full-screen tint is now light (alpha 0.18), assuming L5's overlay does the heavy grade.
- **M7:** kept `layer = 12`, `_connect_signals`, `_clear_items` / `child.queue_free` / `_item_rows.clear`, `tactical_mode_entered`, "ITEMS". Added `enum Category` mirroring the state, so `Category.ITEMS` now exists in this file. MenuRows use `FOCUS_NONE` + mouse ignore, so they never take input from the state. `_item_rows` is `Array[Control]`.
- **Tests (headless):** test_phase6_runner 110/111, test_phase7_runner 23/23, test_phase9 56/56, test_controls 157/157. Extra runs: test_phase8 63/65 and test_performance 64/65. Every failure is in a file M doesn't own: phase6 checks for `_navigate_slot` in tactical_idle_state; phase8 checks pause_menu "Color(0, 0, 0, 0)" and main_menu test_arena; performance expects 7 autoloads but finds 8.
- **M8:** headless boot `--quit-after 1` printed only the version banner, exit 0.
- **Screenshots** (windowed 1920x1080, field_zone, driven by InputEventAction through the real state), all in `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/`: `m_tactical_category.png`, `m_tactical_category_magic.png`, `m_tactical_ability_list.png`, `m_tactical_target.png`, `m_tactical_target_switched.png` (wrap to 8/8, scrolled), `m_tactical_target_controller.png`, `m_tactical_ability_controller.png`, `m_tactical_category_controller.png` and `m_tactical_closed.png`. The driver is `m_shots.gd` in the same folder. In the 3 windowed runs after the first, the log had no errors. The very first run logged a few `text_server_adv _shape_run: fd null` errors from MenuRow `_refresh_state`, which I put down to the first font load/import, but I didn't confirm the cause.

---

### Package N — Exploration HUD: Hints, Prompt, Quest Tracker, Toasts, World Labels
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `src/ui/hud/control_bar.gd`, `src/ui/hud/interaction_prompt.gd`, `src/ui/hud/quest_tracker.gd`, `src/ui/hud/save_feedback.gd`, `src/ui/hud/loading_screen.gd`, `src/ui/hud/throw_arc.gd` (colour only), and the NPC/label `Label3D` code in `scenes/zones/town_hub.gd` and `scenes/zones/field_zone.gd` (label creation blocks only)

- [x] N1. `control_bar.gd`: replace the full-width bar with a compact **context hint stack** on the left edge, made of 3–5 GlyphHints chosen from the player's state:
  - Free roam: Command / Jump / Dodge, plus Interact when a prompt is active.
  - Carrying: Put Down / Hold Throw / Jump.
  - ThrowAim: Throw (X) / Cancel (release B).
  - Tactical: hidden, because the menu shows its own hints.

  Read state through public getters or signals (`Events.carry_*`, `tactical_mode_*`, `interaction_available`). Hide everything when `SettingsManager.show_control_hints` is false. Keep the `CONTROLS` list and `refresh_labels()` if tests use them.
- [x] N2. `interaction_prompt.gd`: a small glass pill with a ButtonGlyph plus the verb text. Keep `get_prompt_text()` / `get_key_hint()` and the carry logic exactly as they are, since tests depend on them.
- [x] N3. `quest_tracker.gd`: move it top-left and use the compact glass panel (gold title, objective text). Fade it on update.
- [x] N4. `save_feedback.gd` becomes a toast (top-right slide-in, with an icon dot). `loading_screen.gd` becomes the frost style with a thin progress line.
- [x] N5. NPC name `Label3D`s: fix the huge-label bug. Use `fixed_size = true` with a sensible `pixel_size`, an outline, the style-kit font, and dim text. Clamp the size so labels never fill the screen when the camera is close, and fade them beyond about 20m.
- [x] N6. `throw_arc.gd`: arc colour becomes Lumina cyan, landing marker gold.
- [x] N7. Headless boot passes. Run test_controls, test_carry and test_phase14.

Handoff Notes:
- **N1** `src/ui/hud/control_bar.gd`: a context hint stack. It's a SlantPanel flush with the left edge, slanted on the right, anchored at 56% screen height (y≈550–660 @1080p). That keeps it clear of M's bottom-left command panel (top ≈ y705), and it's hidden in tactical anyway.
  - Hint sets:
    - FREE: Command / Jump / Dodge, plus Interact while `interaction_available` is active.
    - CARRY: Put Down / Hold to Throw / Jump.
    - AIM: Throw / Release to Cancel.
  - Hidden when any of these apply: `show_control_hints` is false, tactical mode (signals plus a GameManager state check), dialogue, any `ui_menu_opened` without a matching close, or no player.
  - State comes from `player.state_machine.current_state.name` (`ThrowAim`/`Carry`) and `CarryComponent.is_carrying`. Both are read-only.
  - A hint turns gold while its action is held.
  - `CONTROLS` (v2 order) and `refresh_labels()` are kept, and `refresh_labels()` now also refreshes the glyphs (call it after a rebind). Added `get_control_label(i, controller)`.
  - Fade and slide run in unscaled time, one frame after a rebuild so the size is current. Widgets are held in an `Array[Control]`.
- **N2** `interaction_prompt.gd`: a glass pill at bottom-centre (bottom edge 236px above the screen bottom), showing a ButtonGlyph(interact) plus the verb. While carrying, a second "· Hold [glyph] Throw" group appears.
  - `get_prompt_text()`, `get_key_hint()`, the carry signal handlers and the `_refresh` priority are unchanged.
  - Added `get_prompt_verb()`.
  - The show pulse (`_pulse_tween`, modulate) is now unscaled.
- **N3** `quest_tracker.gd`: a top-left SlantPanel (340px) with a gold uppercase Rajdhani title and Barlow objective text. It fade-slides in on set/update/clear. The placeholder and signal names are unchanged.
- **N4** `save_feedback.gd`: a top-right glass toast with a status dot: red when the message reads as negative (cannot/blocked/fail…), cyan otherwise. It slides in from the right, holds 1.5s, fades over 0.5s, and runs unscaled while paused.
  - `loading_screen.gd`: frost background, cyan "LOADING..." header, and a 280px thin cyan line with an indeterminate sweep in real time. `fade_out`/`fade_in`, their signals, `PROCESS_MODE_ALWAYS` and `layer = 100` are kept, and the tweens are unscaled.
- **N5** Label3D blocks in `scenes/zones/town_hub.gd` (`_add_npc`, `_add_portal`) and `scenes/zones/field_zone.gd` (same two functions): `fixed_size = true` with font_size 48. Each label keeps a constant on-screen size, so it can never fill the screen.
  - NPC labels: `pixel_size` 0.00052 (≈24px tall), Barlow SemiBold, dim text (TEXT lerped 35% toward TEXT_DIM), a dark outline of 12, and `visibility_range_end` 22 with margin 4, FADE_SELF (fades from 18 to 22m).
  - Portal labels: Rajdhani SemiBold in gold, `pixel_size` 0.00058, fading from 25 to 30m.
  - Both hide inside 0.6m of the camera.
  - Confirmed in `n_label_close.png`, where the camera is ~1m from the Villager.
- **N6** `throw_arc.gd`: `arc_color` is Lumina cyan, and the new `landing_color` export is ember gold for the landing ring.
- **N7** Headless boot is clean (banner only). Suite results:
  - test_controls 157/157
  - test_carry 76/76: the "ObjectDB leaked" warning is a SceneTreeTimer from `zone_base._autosave_on_entry`, which predates this work.
  - test_phase10 72/72
  - test_phase14 67/67
  - test_phase11 63/63
  - test_phase8 63/65 and test_phase12 64/65. Both are failures that predate this work and aren't in N's files: pause_menu `Color(0, 0, 0, 0)` and main_menu `test_arena.tscn` are O's area, and the field portal was renamed "Return to Millhaven" in the existing uncommitted diff.
- Screenshots: windowed 1920×1080, town_hub, captured with a scratch SceneTree script (not committed). Saved in `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/`:
  - `n_free_roam.png`
  - `n_prompt_npc.png`
  - `n_label_close.png`
  - `n_carrying.png`
  - `n_save_toast.png`: the faded command menu visible here comes from the capture emitting tactical enter/exit to check that the hints hide. They do: visible=false in tactical, true after.
- No files outside N's ownership were edited.

---

### Package O — Menus: Pause, Quest Log, Save/Load, Settings, Dialogue, Main Menu
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: `src/ui/menus/pause_menu.gd`, `quest_log.gd`, `save_load_menu.gd`, `settings_menu.gd`, `src/ui/dialogue/dialogue_ui.gd`, `scenes/menus/main_menu.gd` (+ `main_menu.tscn` visuals only)

- [x] O1. Pause menu, rebuilt visually per the Design Direction:
  - Left nav column of slanted MenuRows.
  - Right party overview cards, with data from the party system and player via public getters.
  - Footer with zone name, play time (if tracked, otherwise omit) and GlyphHints.
  - Background dim or blur.
  - Keep every existing nav entry and action, and the `ui_menu_opened/closed` signals.
- [x] O2. Shared "menu shell" look for quest log, save/load and settings: header tab, content glass panel, footer glyph bar. The settings keybind rows show ButtonGlyphs for the current binding.
- [x] O3. Dialogue: a lower-third glass panel, a speaker name tab, a typewriter effect only if one exists already (don't add a new behaviour that changes timing tests), and an advance indicator glyph.
- [x] O4. Main menu: a title treatment ("RAGNORAK" in the header font with a cyan light-line), slanted buttons, a footer glyph bar.
- [x] O5. Keep all input handling, focus logic, `set_input_as_handled` calls and signals unchanged. Run test_phase8/10/11/15 and test_controls.
- [x] O6. Headless boot passes.

Handoff Notes:
- **Scope:** visual only. Every `_unhandled_input` body, the main-menu focus/`_restore_focus` logic, the dialogue open-frame guard and the settings rebind capture (`open_menu` through `_cancel_rebind`) are unchanged. The settings block was diffed byte-for-byte against the pre-edit file. All nav entries, signals (`ui_menu_opened/closed`, `menu_closed`, `closed`) and SFX calls are kept, and so are the legacy colour consts and strings that the tests grep.
- **Pause** (`pause_menu.gd`):
  - Backdrop: a blur, desaturate and vignette shader on `_overlay` (`BACKDROP_SHADER`, l.22).
  - `_build_ui` (l.93):
    - HeaderTab "PAUSED · <zone>".
    - Nav column of MenuRows (cursor-driven, `focus_mode` NONE) with a description line. Inventory is greyed with the tag "SOON" and keeps the "Coming Soon" toast.
    - Footer showing the location plus glyphs for Navigate, Select and Resume. No play-time tracker exists, so it is omitted.
  - `_refresh_overview` / `_create_member_card` (l.260/285): one SlantPanel card per `party_system.members` entry.
    - Name comes from `data.display_name`, so Amaro and Taighe come from data.
    - Shows ACTIVE/ALLY/DOWNED, HP and MP Gauges with numbers, and the weapon only when the player's EquipmentSystem has one in a hand slot.
    - The level shows "LV --" as a placeholder.
    - Without a party system it falls back to the player alone.
  - Tweens are unscaled (`UIStyle.ui_tween`).
- **Shell** (quest log l.56, save/load l.239, settings l.108):
  - Layout: a near-opaque dim (94%) so the pause screen doesn't show through, a HeaderTab, SlantPanel content and a glass footer with GlyphHints.
  - Quest log: MenuRow list and a detail panel (title, type pill, description, objective bullets).
    - A "TRACKED" tag follows `get_tracked_quest()`. It's polled read-only in `_process` (l.420), so no new signal hookups.
  - Save/load: three slot cards (index, zone, timestamp). The overwrite prompt is a glass dialog with A Yes / B No glyphs, and feedback appears as a pill toast.
  - Settings:
    - Rows: slanted rows, Gauge sliders and ON/OFF pills.
    - Keybind rows show a KEYBOARD glyph and a CONTROLLER glyph (`_build_keybind_row` l.324).
    - `_refresh_keybind` (l.677) calls `refresh()` on the glyphs, because `rebind_action()` doesn't emit `settings_changed`.
    - During capture the row shows "Press key/button..." (`_start_rebind` l.591).
    - The footer hints change with row type and device (`_rebuild_hints` l.718). "Defaults" shows Y on pad and E on keyboard, matching the input code.
- **Dialogue** (`dialogue_ui.gd` l.42):
  - Layout: a lower-third SlantPanel, left of centre so it clears L's bottom-right party panel.
  - Speaker HeaderTab, hidden when the speaker is empty, plus a page counter "1 / 2".
  - Advance glyph: A (ui_accept) on pad, E (interact) on keyboard (`_update_advance_hint` l.169). It only reassigns when changed.
  - No typewriter effect existed, so none was added. The text label has a fixed min width so autowrap height is measured correctly.
- **Main menu:**
  - Scene (`main_menu.tscn`): VBox moved left, Title text "RAGNORAK", `focus_mode = 2` kept, node paths unchanged.
  - Code (`main_menu.gd` `_apply_style` l.119): frost backdrop shader, "PROJECT" caption, a 112px Rajdhani title with a cyan light-line, `UIStyle.style_button` on all five buttons (signals and focus kept), and a footer with Navigate/Select glyphs.
- **Tests (headless):**
  - Boot `--quit-after 1`: exit 0, banner only.
  - Results:

    | Suite | Passed | Note |
    |---|---|---|
    | test_phase8 | 64/65 | The 1 failure, "New Game loads test arena scene", fails identically on baseline before my edits |
    | test_phase10 | 72/72 | |
    | test_phase11 | 63/63 | |
    | test_phase14 | 67/67 | Also greps my files |
    | test_phase15 | 68/68 | |
    | test_controls | 157/157 | |

  - No SCRIPT ERROR or leak lines.
- **Screenshots:** windowed 1920×1080, via a scratch driver (not in the project). Pad and keyboard sets are in `C:/Users/nick/AppData/Local/Temp/claude/de72464e2d5e7768/cf7379d0-116f-4d51-bd3b-06276e1787df/scratchpad/`.
  - Files: `o_main_menu`, `o_pause_menu`, `o_pause_menu_inventory`, `o_quest_log`, `o_save_load`, `o_save_overwrite`, `o_settings`, `o_settings_controls`, `o_settings_rebind`, `o_dialogue`.
  - Each is a `.png` for the pad set, plus a `_kb.png` variant for the keyboard set.
- No files outside O's ownership were edited.

---

### Package P — Screenshots, Tests, Regression
Status: DONE — AWAITING REVIEW
Started: 2026-11-12
Finished: 2026-11-12

Owned files: **new** `tests/test_ui_style.gd` + `.tscn`, **new** `tools/ui_screenshots.gd` (windowed capture script), and other `tests/*.gd` only for assertions broken by the visual pass (no weakening)

- [x] P1. `test_ui_style.gd`:
  - UIStyle palette and fonts load.
  - Every widget instantiates headless.
  - ButtonGlyph returns the right label for each action and device.
  - The HUD layers spawn in field_zone with no errors.
  - The new target bar and tactical overlay are registered.
- [x] P2. `tools/ui_screenshots.gd`: run **windowed** (not headless) at 1920×1080. Load field_zone and capture PNGs to `docs/ui_screenshots/`:
  - free roam
  - the interaction prompt near an NPC
  - carrying
  - the command menu (category, ability list and target phase)
  - lock-on with the target bar
  - pause menu, quest log, settings, dialogue, main menu

  Use `get_viewport().get_texture().get_image().save_png()`. Drive the screens through the same signals or inputs the game uses.
- [x] P3. Run every suite and report counts. Separate the 5 failures known to predate this work from new failures.
- [x] P4. List the screenshot paths in Handoff Notes so the head agent and the user can review them.

Handoff Notes:
- **Files (new, P-owned only):** `tests/test_ui_style.gd` + `tests/test_ui_style.tscn`, `tools/ui_screenshots.gd`, and `docs/ui_screenshots/*.png` (36 PNGs). No UI, state or other test files were edited.
- **P1 `test_ui_style` (128/128).** Run it with `Z:/godot/godot.exe --path . --headless --scene res://tests/test_ui_style.tscn`. It covers:
  - Palette values against the Design Direction, the 4 bundled fonts, the OFL files, and confirms the fonts are not the fallback.
  - The StyleBox factories and `style_button`.
  - All 7 widgets instantiated headless, plus Gauge and SegmentGauge behaviour.
  - ButtonGlyph pad and keyboard labels for 13 actions, checked against `SettingsManager`. Also AUTO device switching, forced KEYBOARD and `label_override`.
  - Source checks that `zone_base` and `test_arena` register `target_bar` and `tactical_overlay`.
  - A real `field_zone` instance: exactly one of each of the 12 HUD scripts, overlay layer below the HUD and menu, target bar show/switch/hide on the lock-on signals with the "Reactor Sentry" display name, overlay fading in and out on the tactical signals, and overlay mouse-ignore.
  - An `OS.add_logger` Logger that fails the suite on any engine or script error raised while field_zone runs. I verified the logger catches `push_error`.
- **P2 `tools/ui_screenshots.gd`.**
  - Run windowed: `Z:/godot/godot.exe --path . --resolution 1920x1080 --script res://tools/ui_screenshots.gd`. Add `-- kb` for the keyboard glyph set (`_kb` suffix).
  - It loads `main_menu`, then `town_hub`, then `field_zone` through `change_scene_to_file`, so `zone_base._spawn_hud` creates every layer.
  - Each screen is driven by the actions the game reads (`InputEventAction`): `interact` opens dialogue and picks up the crate, `ui_accept` advances dialogue, and `pause`, `ui_up/down/accept/cancel` move through the pause menu and sub-menus. In the field it uses `lock_on`, then `tactical_mode`, then `ui_down`/`ui_accept` for Magic, Fire Bolt and the target, `ui_down` to switch target, and `ui_cancel` x3.
  - Teleports are followed by `force_transition(&"Idle")`, because a teleport can land the player in LedgeGrab, where interact is gated off.
  - Save/load is only viewed; no slot is ever confirmed. The quest is accepted through `QuestSystem` so the tracker and log have content.
  - Both runs exit 0 with no SCRIPT ERROR or ERROR lines.
  - Runtime notes printed: prompt "[B] Talk to Villager" / "[E] ...", dialogue opens, GameManager PAUSED->PLAYING, carry state `Carry`, target bar shown ("Reactor Sentry"), TacticalIdle at time_scale 0.10, overlay amount 1.00, and back to Idle at 1.00 after closing.
- **P3 suites** (headless, each run with a timeout of 240s):

  | Suite | Result | Notes |
  |---|---|---|
  | test_runner | 35/35 | |
  | test_controls | 157/157 | |
  | test_carry | 76/76 | ObjectDB leak warning at exit: the known SceneTreeTimer from `zone_base._autosave_on_entry`, which predates this work |
  | **test_ui_style** | **128/128** | new |
  | test_phase6_runner | 110/111 | KNOWN: `_navigate_slot` |
  | test_phase7_runner | 23/23 | |
  | test_phase8 | 64/65 | KNOWN: New Game -> test_arena |
  | test_phase9 | 56/56 | ITEMS now passes |
  | test_phase10 | 72/72 | |
  | test_phase11 | 63/63 | |
  | test_phase12 | 64/65 | KNOWN: return portals ("Return to Millhaven") |
  | test_phase13 | 64/64 | |
  | test_phase14 | 67/67 | |
  | test_phase15 | 68/68 | |
  | test_performance | 64/65 | KNOWN: 8 autoloads vs 7 |

  - **New failures: none.** All 4 remaining failures are the known ones that predate this work. No SCRIPT ERROR lines appear in any suite log.
  - Headless boot `--quit-after 1`: banner only, exit 0.
- **P4 screenshots** (1920x1080), in `Z:/Development/lumina/games/projectRagnorak/docs/ui_screenshots/`. Each name below is a pad-glyph `.png`; each also has a keyboard-glyph `_kb.png` variant:
  - `01_main_menu`
  - `02_town_free_roam`
  - `03_town_prompt_npc`
  - `04_dialogue`
  - `05_pause_menu`
  - `06_quest_log`
  - `07_save_load`
  - `08_settings`
  - `09_settings_controls`
  - `10_town_carrying`
  - `11_field_free_roam`
  - `12_field_lock_on_target_bar`
  - `13_command_category`: the tactical overlay is active here and in 14-17.
  - `14_command_category_magic`
  - `15_command_ability_list`
  - `16_command_target_select`
  - `17_command_target_switched`
  - `18_field_after_tactical`
- **Visual review.** I looked at every pad shot and spot-checked the kb set.
  - What works:
    - The party panel (x>=1425) never overlaps the command panel or description strip (x<=908).
    - The hint stack is hidden in tactical mode.
    - The quest tracker, target bar and party panel don't collide.
    - Glyphs are correct for both devices.
    - Fonts are legible at 1080p.
  - Issues found:
    1. **Hint stack stays visible during dialogue** (`04_dialogue`). `control_bar` hides on `Events.dialogue_started/ended`, but nothing in the project emits those signals; `dialogue_ui` only emits `interaction_cleared` on end. See CAR-P1.
    2. **Interaction prompt stays up over other modes.** "B Talk to Villager" still shows above the dialogue box (`04`), and "B Pick Up" shows during the command menu (`14`-`17`, field crate nearby). In both cases B means something else (advance in dialogue, Back in the menu). See CAR-P2.
    3. **Target bar vs command menu names.** In the target phase the list reads "Reactor Sentry A/B...", but the top bar always reads "REACTOR SENTRY", so switching A->B (`17`) shows no change in the bar. See CAR-P3.
    4. **Target list includes all 8 field enemies** ("1 / 8", including camps 60-90m away). The list scrolls and stays readable, but most entries are off-screen. The candidate rules belong to the state, so this is an observation for the head, not a UI bug.
    5. **Lock-on framing hides the target behind Amaro.** In `12`-`16` the camera lines up player -> target, so the cyan reticle and the "LOCKED ON"/"TARGET" label draw over Amaro's hood instead of on a visible enemy. It reads as if the player were targeted. This comes from camera framing (camera owner), not the indicator.
    6. **Off-style world-space combat UI.** The enemy overhead HP bar is a flat bright-green bar, and damage numbers ("12" in `18`) use the default font in yellow. Neither uses the Lumina Frost palette or fonts. They come from the earlier "enemy health bars, damage numbers" commit and fall outside the L-O ownership. See CAR-P4.
    7. **Sub-menus show the pause screen through them.** Ghost text from the pause nav and party cards is visible behind the quest log (`06`) and clearly visible around the centred save/load dialog (`07`) and the settings panel (`08`/`09`, where "Camera, audio, controls and gameplay op..." is cut off at the panel edge). Legibility is fine, but it looks layered. See CAR-P5.
    8. Minor: the D-Left/D-Right glyph pair ("Switch" in `16`, "Adjust" in `08`) draws as two tiny crosses that are hard to read at 1080p (K, optional).
    9. Minor: NPC/portal `Label3D`s use `no_depth_test`, so they draw through houses and carried crates ("Elder Hwan" through a wall in `03`, "Merchant Soo" over the crate in `10`). Intended for readability; noting for N/head.
    10. Minor: the carry prompt ("Put Down - Hold Throw") repeats the left hint stack ("Put Down / Hold to Throw / Jump").
  - Non-UI items seen in the shots, for context only: the player model is in T-pose, NPCs and the companion are placeholder capsules, and the field quest tracker reads "No active quest" because quest state doesn't carry across `change_scene_to_file` in the capture.
  - After switching to Sentry B and backing out with B x3, the state was `Idle`, not `LockOnIdle`, so the lock-on and target bar dropped (`18`). It may be range-based loss on the farther target; flagging it for the head to confirm against "B at top closes to LockOnIdle".

---

## Cross-Agent Requests
Format: `[from X → to Y] request — status (OPEN / DONE / REJECTED)`

- [from M → Head (state owner)] Optional: in `tactical_idle_state` TARGET_SELECT, also cycle targets on `ui_up`/`ui_down`/`move_up`/`move_down`, so the vertical target list matches the stick/D-pad direction. Today only left/right + target_switch cycle, and the menu hint shows exactly those. — DONE (Head): up/down (move_up/ui_up, move_down/ui_down) now also cycle targets.
- [from M → Head (enemy owner)] Enemies have no `display_name`, so target names arrive as "@CharacterBody3D@820". Consider adding an `@export var display_name` to `enemy_base.gd`. The menu prefers it automatically and falls back to "Enemy A/B/…" for display. — DONE (Head): `@export var display_name` added (default "Reactor Sentry"). The menu adds A/B suffixes when names repeat.
- [from L → Head] Register the new HUD layers (R3). Both are headless-safe and need no setup. — DONE (Head): registered in zone_base._spawn_hud and test_arena.
  - `src/world/zone_base.gd`:
    - Add the consts: `const TargetBarScript := preload("res://src/ui/hud/target_bar.gd")` and `const TacticalOverlayScript := preload("res://src/ui/hud/tactical_overlay.gd")`.
    - In `_spawn_hud`, add `TargetBarScript, TacticalOverlayScript,` to `hud_scripts`, for example after `LockOnIndicatorScript,`.
  - `scenes/test/test_arena.gd`:
    - Add the same two consts.
    - After the lock-on indicator block, add:
      ```gdscript
      	var target_bar := CanvasLayer.new()
      	target_bar.set_script(TargetBarScript)
      	add_child(target_bar)
      	var tactical_overlay := CanvasLayer.new()
      	tactical_overlay.set_script(TacticalOverlayScript)
      	add_child(tactical_overlay)
      ```
- [from L → Head (enemy owner)] Enemies don't expose stagger. `stagger_duration` is only the hurt-flinch time. To light up the target bar's stagger gauge and the STAGGERED tag, add the following to `enemy_base.gd`. `target_bar.gd` picks them up automatically (duck-typed), so no further L changes are needed. A `display_name` export (same as M's request) also replaces the "Enemy" fallback. — DEFERRED to Controls v3 / battle plan: heavy attacks build stagger there. display_name done.
  - `var stagger_value: float`
  - `var stagger_max: float`
  - `func is_staggered() -> bool`
  - Optionally `var stagger_damage_multiplier: float`, e.g. 1.6 → "STAGGERED 160%".
- [from P → O / Head] **CAR-P1:** `dialogue_ui.start_dialogue` should emit `Events.dialogue_started` and `_end_dialogue` should emit `Events.dialogue_ended`. Both signals exist in `events.gd` and `control_bar` already listens for them, but nothing emits them, so the hint stack stays visible during dialogue (`docs/ui_screenshots/04_dialogue.png`). This adds signal emissions, so the head should approve it under the frozen-contract rule. — DONE (fix-up, head-approved): `start_dialogue` emits `dialogue_started` on the closed→open edge and `_end_dialogue` emits `dialogue_ended` (before `interaction_cleared`), once each. control_bar's hint stack is now hidden in `04_dialogue`.
- [from P → N] **CAR-P2:** `interaction_prompt.gd` should hide while tactical mode (`tactical_mode_entered/exited`), dialogue (`dialogue_started/ended` once CAR-P1 lands, or `player.is_dialogue_active()`) or a menu (`ui_menu_opened/closed`) is active, then restore its prior state afterwards. Visual only: `get_prompt_text()`/`get_key_hint()` and the carry logic are unchanged. Evidence: `04_dialogue.png`, `14_command_category_magic.png` through `17_command_target_switched.png`. — DONE (fix-up): the pill hides while dialogue, tactical mode or any `ui_menu_opened` menu is open (`is_suppressed()`) and comes back when they all close. Prompt state, `get_prompt_text()`/`get_key_hint()` and the carry logic are unchanged. Checked in `04` and `14`-`17` and with a runtime check.
- [from P → L] **CAR-P3:** make the target bar name match the command menu's A/B suffix when several enemies share a `display_name` (e.g. reuse M's suffix ordering, or have the state/menu expose the resolved label), so switching targets visibly changes the bar (`17_command_target_switched.png`). — DONE (fix-up): `target_bar.disambiguated_name()` adds A/B/... in `enemies` group order (the same candidate order as the state/menu). Auto-named enemies read "Enemy A/B". The bar shows REACTOR SENTRY A in `16` and B in `17`.
- [from P → Head (enemy/combat feedback owner)] **CAR-P4:** restyle the enemy overhead HP bar and the damage numbers with the style kit (`UIStyle.DANGER`/HP gradient bar with `GAUGE_BACK` track, Rajdhani numbers with an outline, gold for crits). Evidence: `12_field_lock_on_target_bar.png`, `18_field_after_tactical.png`. — OPEN
- [from P → O] **CAR-P5 (minor):** hide or fade the pause menu's nav and cards while a sub-menu (quest log, save/load, settings) is open, or raise the sub-menu dim, so pause text doesn't ghost through (`06`-`09`). — DONE (fix-up): pause_menu hides its content panel (nav, cards, footer) while a sub-menu is open and keeps only the blurred backdrop. It fades the panel back in when the sub-menu closes (polled in `_process`). Input, focus and signals are unchanged. Clean in `06`-`09`.
-

---

## Head Agent Review
Status: NOT STARTED

- [ ] R1. All packages DONE and requests resolved.
- [ ] R2. Diff review. File ownership respected, and no behaviour changes in state scripts.
- [ ] R3. Register the new HUD layers (target bar, tactical overlay) in `zone_base._spawn_hud` and `test_arena`.
- [ ] R4. Review screenshots against the Design Direction. Check legibility, controller glyphs, no overlap between the party panel and command panel, and that it looks original and not copied.
- [ ] R5. Headless boot and all suites pass.
- [ ] R6. Debug-verification report.
- [ ] R7. User review of screenshots and an in-game check, then project_status.json and commit on approval.

Review Notes:
-
