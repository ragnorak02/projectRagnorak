# Rigless Models — Using Un-rigged Meshes as Characters

Owner: v5 Package EE. Script: `src/characters/rigless_visual.gd` (`class_name RiglessVisual`).

`RiglessVisual` turns any static mesh (Hunyuan GLB, kit prop, capsule) into a character that reads as alive with no
skeleton or animation. All motion is procedural and comes from the owning `CharacterBody3D`'s **public** state:

| Motion | Driven by |
|---|---|
| Idle bob | always (smooth sine, ~0.55 Hz, 3.5 cm) |
| Move bob | horizontal speed: frequency +0.32 Hz per m/s, step-like bounce, 6 cm |
| Lean | speed relative to facing: forward up to 14°, sideways up to 8°, plus bank into turns |
| Smooth yaw | lags the parent's yaw (`FOLLOW_PARENT`) or turns toward velocity (`FACE_VELOCITY`) |
| Jump stretch / land squash | `is_on_floor()` transitions; squash scales with impact speed, volume-preserving, spring settle |
| Air stretch | vertical speed while airborne |
| Attack lunge-twist | `play_cue(&"attack")` / `&"attack_heavy"` (alternates left/right twist per hit) |
| Cast lift | `play_cue(&"cast")` |
| Dodge spin | `play_cue(&"dodge")`: 360° yaw spin |
| Air dash | `play_cue(&"air_dash")`: 360° roll |
| Backflip | `play_cue(&"air_dodge_back")`: 360° flip, head goes backward |
| Hit shake | `play_cue(&"hit")`: decaying shake + flinch back |
| Manual jump/land | `play_cue(&"jump")` / `&"land"` (auto-detected anyway) |

Rules it follows:
- Read-only. It never writes to the body, its velocity, states, camera or any gameplay system. Only its own
  internal child nodes move. A rigless model can't change hitboxes or collision.
- Time. It uses real frame time × a factor:
  - Ambient motion (bob, lean, yaw, squash spring) runs at `max(Engine.time_scale, 0.3)`, so it keeps breathing slowly in the Command Menu (0.05).
  - Ambient motion freezes during hit-stop (`time_scale <= 0.02`), which gives a freeze-frame.
  - Cues follow `Engine.time_scale`, so they slow with the game. The exception is `hit`, which runs unscaled so the shake reads during hit-stop.
  - Tree pause freezes everything.

## API

```gdscript
var rv: RiglessVisual = $VisualRoot/RiglessVisual
rv.play_cue(&"attack")            # -> bool (false + warning on unknown name)
rv.play_cue(&"attack_heavy", 1.3) # strength multiplier
rv.is_cue_active(&"dodge")
rv.clear_cues()                   # on death / zone change
rv.set_model(scene, 1.0, 180.0)   # swap model at runtime (party identity swap)
rv.get_model_root()
rv.get_debug_state()              # bob, lean_pitch, lean_roll, yaw_local, squash, spin, cue counts...
```

To call a cue from code that shouldn't hard-depend on the class, use duck typing:
```gdscript
var rv := player.get_node_or_null("VisualRoot/RiglessVisual")
if rv and rv.has_method("play_cue"):
	rv.play_cue(&"dodge")
```

Key exports:
- `model_scene`: the mesh to wrap. If null, any Node3D children already placed under the node are wrapped. With no children either, it builds a capsule fallback with a "nose" box that marks forward.
- `fit_height` (default 1.8 m): auto-scales so the AABB height equals this, puts the feet on y = 0 and centres on X/Z. Set it to 0 to keep the authored scale.
- `model_scale`: extra multiplier applied after the fit.
- `model_yaw_offset_deg`: fixes a model that doesn't face -Z.
- `pivot_height`: centre for spins and flips. -1 means half the height.
- `yaw_mode`:
  - `FOLLOW_PARENT`: for the player and enemies that rotate their own body.
  - `FACE_VELOCITY`: for movers that never rotate.
  - `NONE`
- Tuning:
  - `turn_rate`, `turn_bank`
  - `idle_bob_*`, `move_bob_*`, `reference_speed`
  - `max_lean_deg`, `max_side_lean_deg`
  - `jump_stretch`, `land_squash_per_speed`, `max_squash`
  - `squash_stiffness`, `squash_damping`
  - `ambient_min_factor`, `hit_stop_threshold`

Internal layout (built at `_ready`, all private):
`RiglessVisual → _Yaw → _Lean → _Squash → _Spin → _Facing → _Fit → <model>`.
Lean and squash pivot at the feet. Spins and flips pivot at `pivot_height`.

## Step-by-step: dropping in an approved Hunyuan GLB

Do this only after the user has approved the model. Source folders: `Z:\Development\lumina\assets\models\hunyuan\dev\`, or
the Lumina approval flow (approved models land in `shared_assets/3d/`).

1. **Copy, don't link.** Copy the `.glb` (and its preview `.glb.png` if you want it) into the game:
   `res://assets/models/characters/rigless/<name>/<name>.glb`. Use one folder per model, a lowercase snake_case name, and no spaces.
2. **Import.** Run `Z:/godot/godot.exe --path . --headless --import`. In the Import dock (or `<name>.glb.import`), keep the defaults and check these settings:
   - `nodes/root_type` empty (Node3D)
   - `nodes/root_scale = 1.0`, `nodes/apply_root_scale = true`
   - `meshes/generate_lods = true`, `meshes/create_shadow_meshes = true`
   - `animation/import = false`: Hunyuan meshes have no animation, so this keeps the import clean.
   - `meshes/light_baking = Static Lightmaps (1)` is fine. Don't generate collision: the CharacterBody3D owns collision.

   Hunyuan textures are embedded in the GLB. Leave `materials/extract` off unless you need to tweak them.
3. **Scale.** Hunyuan output is unit-normalised, roughly -1..1 and often centred on the mesh's middle, so the raw scale is meaningless. Leave the import scale at 1 and let `fit_height` do the work:
   - humanoid party member: `fit_height = 1.8` (matches the 1.8 m player capsule)
   - small enemy: around 1.2
   - brute: 2.4 to 3.0, and make its collision capsule match

   Use `model_scale` only for a deliberate tweak.
4. **Facing (-Z forward).** Godot forward is -Z. glTF characters are usually authored facing +Z, which is the glTF front, so most Hunyuan GLBs need `model_yaw_offset_deg = 180`. To check:
   1. Put the model in a scene with a capsule-fallback RiglessVisual beside it.
   2. Compare against the fallback's nose box, which points forward.
   3. Or run the game and push the stick forward: the model's face must lead.

   Fix facing only with `model_yaw_offset_deg`. Don't rotate the GLB or the body.
5. **Pivot.** For spins and flips to look centred, the default (half height) is fine for humanoids. For top-heavy meshes, set `pivot_height` to roughly the chest height.
6. **Point a character at it**:
   - **Party member (player / companion).** Set these on `hero.tres` / `companion.tres`, using the fields requested from CC:
     - `model_scene = preload("res://assets/models/characters/rigless/<name>/<name>.glb")`
     - `model_scale = 1.0`
     - `rigless = true`
     - (proposed) `model_yaw_offset_deg = 180`

     `player.gd` then hides `VisualRoot/Model` (red knight), adds a `RiglessVisual` under `VisualRoot` and calls `set_model()` on identity swap.
   - **Enemy / NPC.** This goes through the Head request below. Until it lands, an enemy or NPC scene can instance `RiglessVisual` under its `VisualRoot` by hand:
     1. Add a Node3D with `rigless_visual.gd` as a child of `VisualRoot`.
     2. Set `model_scene`.
     3. Hide or remove the old mesh child.
     4. Use `FACE_VELOCITY` if that script never rotates its body.
7. **Verify.**
   1. Run a headless boot.
   2. Check in game:
      - idle bob visible
      - forward lean when running
      - stretch on jump, squash on land
      - spin on dodge
      - shake when hit
   3. Check the model doesn't clip the floor (feet at y = 0 from the fit) and that the lock-on reticle is still at the head. Lock-on points are owned by the body, not the visual.
8. **Don't** add an AnimationPlayer or skeleton expectations: `player.gd` already warns when no AnimationPlayer is found, and `play_animation` is a no-op without one.

## Stand-ins verified (no new imports)
- Capsule fallback, plus children placed under the node (the moved-children path).
- `public/assets/medieval_village_megakitstandard/glTF/Prop_Crate.gltf`: a static mesh fitted to 1.8 m.
- `public/assets/fbx/redKnight/red_knight.fbx`: used as a static mesh, `model_yaw_offset_deg = 180`.

Screenshots: `docs/ui_screenshots/v5_ee_1_idle.png` … `v5_ee_7_air_backflip.png`.
