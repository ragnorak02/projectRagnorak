## RiglessVisual — procedural "float" motion for un-rigged meshes (v5 EE).
##
## Wraps any mesh scene (Hunyuan GLB, kit prop, capsule fallback) and makes it
## read as a character with zero animation data:
##   idle bob · speed-driven lean + bob frequency · smooth yaw turn ·
##   jump stretch / land squash · attack lunge-twist · dodge spin ·
##   air_dodge_back backflip · hit shake.
##
## Contract:
## - Reads PUBLIC state only from the owning CharacterBody3D (velocity,
##   is_on_floor(), global_basis). Never writes to the body or any gameplay
##   system. Purely cosmetic: only its own child transforms change.
## - Gameplay/states trigger one-shot cues via play_cue(&"attack") etc.
##   Jump / land / fall are detected automatically from floor state.
## - Time: driven by real (unscaled) frame time multiplied by a time factor:
##     * ambient motion (bob, lean, yaw, squash spring) runs at
##       max(Engine.time_scale, ambient_min_factor) so the model still
##       "breathes" in the Command Menu (0.05), and holds still during
##       hit-stop (time_scale <= hit_stop_threshold) as a freeze-frame.
##     * one-shot cues run at Engine.time_scale (they slow with the game),
##       except "hit", which runs unscaled so the shake reads during hit-stop.
##     * get_tree().paused freezes everything (inherits process mode).
##
## Node layout built at _ready (all owned by this node):
##   RiglessVisual (this, at the body's feet)
##     _Yaw        smoothed facing (local yaw vs parent)
##       _Lean     lean/bank at the feet + bob/lunge/shake offset
##         _Squash scale at the feet (volume-preserving)
##           _Spin at pivot height: dodge spin / backflip / twist
##             _Facing  -pivot height, model_yaw_offset_deg (fix bad facing)
##               _Fit   auto-ground + centre + fit_height scale
##                 <model instance or capsule fallback>
##
## Facing convention: the model must face -Z (Godot forward). Use
## model_yaw_offset_deg = 180 for meshes exported facing +Z.
extends Node3D
class_name RiglessVisual

enum YawMode {
	FOLLOW_PARENT,  ## Body/parent rotates itself; visual lags behind it smoothly.
	FACE_VELOCITY,  ## Body never rotates (NPC movers); visual turns toward horizontal velocity.
	NONE,           ## No yaw handling at all.
}

# --- Model -------------------------------------------------------------------
## Mesh scene to wrap. Null = reuse any children already placed under this
## node, or build the capsule fallback if there are none.
@export var model_scene: PackedScene
## Extra uniform scale applied after fit_height (1.0 = no change).
@export var model_scale: float = 1.0
## > 0: scale the model so its AABB height equals this (metres), ground it
## (bottom at y=0) and centre it on X/Z. 0 = use the model as authored.
@export var fit_height: float = 1.8
## Yaw correction for meshes that do not face -Z (degrees).
@export var model_yaw_offset_deg: float = 0.0
## Rotation pivot height for spins/flips. < 0 = half the fitted height.
@export var pivot_height: float = -1.0
## Fallback capsule colour (when there is no model).
@export var fallback_color: Color = Color(0.3, 0.5, 0.8)
## Hunyuan/ComfyUI GLBs import fully metallic (metallic 1 + metallic map), which
## renders near-black under flat lighting. When true, model materials get a
## per-instance copy with the metal removed (albedo/emission kept).
@export var fix_generated_materials: bool = true

# --- Body / yaw ----------------------------------------------------------------
## Body to read. Empty = nearest CharacterBody3D ancestor.
@export var body_path: NodePath
@export var yaw_mode: YawMode = YawMode.FOLLOW_PARENT
## Yaw catch-up rate (1/s, exponential). Higher = snappier turn.
@export var turn_rate: float = 12.0
## Bank (roll) into turns: radians of roll per rad/s of yaw rate.
@export var turn_bank: float = 0.06

# --- Bob / lean ---------------------------------------------------------------
@export var idle_bob_amplitude: float = 0.035
@export var idle_bob_frequency: float = 0.55  # Hz
@export var move_bob_amplitude: float = 0.06
## Bob frequency added per m/s of horizontal speed (Hz per m/s).
@export var move_bob_freq_per_speed: float = 0.32
## Speed considered "full run" for lean/bob scaling (m/s).
@export var reference_speed: float = 8.0
@export var max_lean_deg: float = 14.0
@export var max_side_lean_deg: float = 8.0
@export var lean_rate: float = 8.0

# --- Squash / stretch -------------------------------------------------------
@export var jump_stretch: float = 0.22
@export var land_squash_per_speed: float = 0.025  # per m/s of impact speed
@export var max_squash: float = 0.32
@export var squash_stiffness: float = 180.0
@export var squash_damping: float = 14.0
## Airborne stretch per m/s of vertical speed.
@export var air_stretch_per_speed: float = 0.012

# --- Time -----------------------------------------------------------------------
@export var ambient_min_factor: float = 0.3
@export var hit_stop_threshold: float = 0.02

# Cue table: name -> duration (s, game time) and whether it ignores time scale.
const CUES := {
	&"attack": {"dur": 0.28, "unscaled": false},
	&"attack_heavy": {"dur": 0.42, "unscaled": false},
	&"cast": {"dur": 0.6, "unscaled": false},
	&"dodge": {"dur": 0.38, "unscaled": false},
	&"air_dash": {"dur": 0.3, "unscaled": false},
	&"air_dodge_back": {"dur": 0.55, "unscaled": false},
	&"hit": {"dur": 0.32, "unscaled": true},
	&"jump": {"dur": 0.0, "unscaled": false},
	&"land": {"dur": 0.0, "unscaled": false},
}

var _body: CharacterBody3D
var _yaw_node: Node3D
var _lean_node: Node3D
var _squash_node: Node3D
var _spin_node: Node3D
var _facing_node: Node3D
var _fit_node: Node3D
var _model_root: Node3D
var _fitted_height: float = 1.8

var _last_ticks_usec: int = 0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _move_blend: float = 0.0
var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0
var _yaw_global: float = 0.0
var _yaw_local: float = 0.0
var _yaw_rate: float = 0.0
var _squash: float = 0.0       # +stretch / -squash
var _squash_vel: float = 0.0
var _was_on_floor: bool = true
var _air_vy_min: float = 0.0   # most negative vy while airborne
var _attack_side: float = 1.0
var _active_cues: Array = []   # [{name, t, dur, unscaled, strength, side}]
var _cue_counts: Dictionary = {}

# Debug snapshot of the cue layer (for verification).
var _cue_offset := Vector3.ZERO
var _cue_rot := Vector3.ZERO
var _cue_squash: float = 0.0


func _ready() -> void:
	_build_hierarchy()
	_resync_body()
	_last_ticks_usec = Time.get_ticks_usec()


## Re-resolve the owning body every time we (re)enter the tree. Party identity
## swaps reparent the visual_root child between the Player and companion bodies.
func _enter_tree() -> void:
	if is_node_ready():
		_resync_body()


func _resync_body() -> void:
	_body = _resolve_body()
	_yaw_global = _parent_yaw()
	_yaw_rate = 0.0
	_yaw_local = 0.0
	_was_on_floor = _body.is_on_floor() if _body else true
	_air_vy_min = 0.0


# ---------------------------------------------------------------- public API

## Trigger a one-shot motion cue. Returns false for unknown cue names.
## Known: attack, attack_heavy, cast, dodge, air_dash, air_dodge_back, hit,
## jump, land. strength scales the cue (1.0 = default).
func play_cue(cue: StringName, strength: float = 1.0) -> bool:
	if not CUES.has(cue):
		push_warning("RiglessVisual: unknown cue '%s'" % cue)
		return false
	_cue_counts[cue] = int(_cue_counts.get(cue, 0)) + 1
	match cue:
		&"jump":
			_kick_squash(jump_stretch * strength)
			return true
		&"land":
			_kick_squash(-0.18 * strength)
			return true
	var side := 1.0
	if cue == &"attack" or cue == &"attack_heavy":
		_attack_side = -_attack_side
		side = _attack_side
	# Spins/flips restart rather than stack; hits/attacks may overlap.
	if cue in [&"dodge", &"air_dash", &"air_dodge_back"]:
		for c in _active_cues.duplicate():
			if c["name"] in [&"dodge", &"air_dash", &"air_dodge_back"]:
				_active_cues.erase(c)
	var info: Dictionary = CUES[cue]
	_active_cues.append({
		"name": cue, "t": 0.0, "dur": float(info["dur"]),
		"unscaled": bool(info["unscaled"]), "strength": strength, "side": side,
	})
	return true


## Cancel every running cue (e.g. on death / zone change).
func clear_cues() -> void:
	_active_cues.clear()


func is_cue_active(cue: StringName) -> bool:
	for c in _active_cues:
		if c["name"] == cue:
			return true
	return false


## Root of the wrapped model (instance, moved children, or capsule fallback).
func get_model_root() -> Node3D:
	return _model_root


## Replace the wrapped model at runtime (e.g. party identity swap).
func set_model(scene: PackedScene, scale_mult: float = 1.0, yaw_offset_deg: float = 0.0) -> void:
	model_scene = scene
	model_scale = scale_mult
	model_yaw_offset_deg = yaw_offset_deg
	if _fit_node == null:
		return
	if _model_root:
		_model_root.queue_free()
		_fit_node.remove_child(_model_root)
	_model_root = _instance_model([])
	_fit_node.add_child(_model_root)
	_apply_fit()


## Snapshot for tests / debug overlays. Read-only.
func get_debug_state() -> Dictionary:
	return {
		"bob": _bob_offset,
		"bob_phase": _bob_phase,
		"move_blend": _move_blend,
		"lean_pitch": _lean_pitch,
		"lean_roll": _lean_roll,
		"yaw_local": _yaw_local,
		"squash": _squash,
		"cue_squash": _cue_squash,
		"scale_y": _squash_node.scale.y if _squash_node else 1.0,
		"spin": _spin_node.rotation if _spin_node else Vector3.ZERO,
		"cue_offset": _cue_offset,
		"cues": _active_cues.map(func(c): return c["name"]),
		"cue_counts": _cue_counts.duplicate(),
		"fitted_height": _fitted_height,
		"on_floor": _was_on_floor,
	}


# ---------------------------------------------------------------- per-frame

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := clampf(float(now - _last_ticks_usec) / 1000000.0, 0.0, 0.1)
	_last_ticks_usec = now
	step(real_dt, Engine.time_scale)


## One update. Public so headless tests can drive it deterministically.
func step(real_dt: float, time_scale: float) -> void:
	if _yaw_node == null:
		return
	var frozen := time_scale <= hit_stop_threshold
	var amb_dt := 0.0 if frozen else real_dt * maxf(time_scale, ambient_min_factor)
	var cue_dt := real_dt * time_scale

	var vel := Vector3.ZERO
	var on_floor := true
	if is_instance_valid(_body):
		vel = _body.velocity
		on_floor = _body.is_on_floor()

	_update_floor_events(on_floor, vel)
	_update_yaw(amb_dt, vel)
	_update_bob_lean(amb_dt, vel, on_floor)
	_update_squash(amb_dt, vel, on_floor)
	_update_cues(cue_dt, real_dt)
	_apply_transforms()


func _update_floor_events(on_floor: bool, vel: Vector3) -> void:
	if on_floor and not _was_on_floor:
		var impact := -_air_vy_min
		_kick_squash(-clampf(impact * land_squash_per_speed, 0.04, max_squash))
		_cue_counts[&"land"] = int(_cue_counts.get(&"land", 0)) + 1
	elif not on_floor and _was_on_floor:
		_air_vy_min = 0.0
		if vel.y > 0.5:
			_kick_squash(jump_stretch)
			_cue_counts[&"jump"] = int(_cue_counts.get(&"jump", 0)) + 1
	if not on_floor:
		_air_vy_min = minf(_air_vy_min, vel.y)
	_was_on_floor = on_floor


func _update_yaw(dt: float, vel: Vector3) -> void:
	if yaw_mode == YawMode.NONE:
		_yaw_local = 0.0
		_yaw_rate = 0.0
		return
	var parent_yaw := _parent_yaw()
	var target := _yaw_global
	if yaw_mode == YawMode.FOLLOW_PARENT:
		target = parent_yaw
	else:
		var flat := Vector2(vel.x, vel.z)
		if flat.length() > 0.3:
			target = atan2(-vel.x, -vel.z)
	var prev := _yaw_global
	if dt > 0.0:
		var diff := wrapf(target - _yaw_global, -PI, PI)
		_yaw_global = wrapf(_yaw_global + diff * (1.0 - exp(-turn_rate * dt)), -PI, PI)
		_yaw_rate = lerpf(_yaw_rate, wrapf(_yaw_global - prev, -PI, PI) / dt, 1.0 - exp(-10.0 * dt))
	_yaw_local = wrapf(_yaw_global - parent_yaw, -PI, PI)


func _update_bob_lean(dt: float, vel: Vector3, on_floor: bool) -> void:
	var speed := Vector2(vel.x, vel.z).length()
	var speed_n := clampf(speed / maxf(reference_speed, 0.01), 0.0, 1.5)
	_move_blend = lerpf(_move_blend, speed_n if on_floor else 0.0, 1.0 - exp(-lean_rate * dt))
	var freq := idle_bob_frequency + speed * move_bob_freq_per_speed
	_bob_phase = fmod(_bob_phase + TAU * freq * dt, TAU * 64.0)
	var amp := lerpf(idle_bob_amplitude, move_bob_amplitude, clampf(_move_blend, 0.0, 1.0))
	var air_fade := 1.0 if on_floor else 0.25
	# Moving bob: |sin| gives a step-like double bounce; idle: smooth sine.
	var idle_wave := sin(_bob_phase) * 0.5 + 0.5
	var step_wave := absf(sin(_bob_phase))
	var wave := lerpf(idle_wave, step_wave, clampf(_move_blend * 2.0, 0.0, 1.0))
	_bob_offset = wave * amp * air_fade

	# Lean in the visual's own frame (forward = -Z of the yaw node).
	var target_pitch := 0.0
	var target_roll := 0.0
	if speed > 0.05:
		var yaw_basis := Basis(Vector3.UP, _yaw_global)
		var local_v := yaw_basis.inverse() * Vector3(vel.x, 0.0, vel.z)
		var fwd := clampf(-local_v.z / maxf(reference_speed, 0.01), -1.0, 1.0)
		var side := clampf(local_v.x / maxf(reference_speed, 0.01), -1.0, 1.0)
		target_pitch = -fwd * deg_to_rad(max_lean_deg)
		target_roll = -side * deg_to_rad(max_side_lean_deg)
	target_roll += clampf(-_yaw_rate * turn_bank, -0.25, 0.25)
	if not on_floor:
		target_pitch *= 0.5
	var k := 1.0 - exp(-lean_rate * dt)
	_lean_pitch = lerpf(_lean_pitch, target_pitch, k)
	_lean_roll = lerpf(_lean_roll, target_roll, k)


func _update_squash(dt: float, vel: Vector3, on_floor: bool) -> void:
	if dt <= 0.0:
		return
	var rest := 0.0
	if not on_floor:
		rest = clampf(absf(vel.y) * air_stretch_per_speed, 0.0, 0.15)
	# Semi-implicit spring toward rest; sub-step for stability.
	var steps := int(ceil(dt / 0.008))
	var h := dt / float(steps)
	for i in steps:
		var acc := -squash_stiffness * (_squash - rest) - squash_damping * _squash_vel
		_squash_vel += acc * h
		_squash += _squash_vel * h
	_squash = clampf(_squash, -max_squash, max_squash)


func _kick_squash(amount: float) -> void:
	# Impulse: set displacement directly so the pose is visible immediately.
	_squash = clampf(amount, -max_squash, max_squash)
	_squash_vel = 0.0


func _update_cues(cue_dt: float, real_dt: float) -> void:
	var off := Vector3.ZERO
	var rot := Vector3.ZERO
	var squash_add := 0.0
	for c in _active_cues.duplicate():
		c["t"] += real_dt if c["unscaled"] else cue_dt
		var dur: float = c["dur"]
		var t := clampf(c["t"] / dur, 0.0, 1.0)
		var s: float = c["strength"]
		var side: float = c["side"]
		match c["name"]:
			&"attack", &"attack_heavy":
				var heavy: bool = c["name"] == &"attack_heavy"
				var reach := (0.32 if heavy else 0.2) * s
				var twist := deg_to_rad(38.0 if heavy else 24.0) * s
				# Snap out fast, ease back: lunge peaks at ~30% of the cue.
				var lunge := sin(PI * pow(t, 0.6))
				off.z -= reach * lunge
				rot.y += twist * side * sin(PI * t) * (1.0 - t * 0.5)
				rot.x -= deg_to_rad(10.0 if heavy else 6.0) * s * lunge
			&"cast":
				var lift := sin(PI * t)
				off.y += 0.14 * s * lift
				rot.x += deg_to_rad(6.0) * s * lift
			&"dodge":
				var e := _ease_in_out(t)
				rot.y += TAU * e
				squash_add -= 0.1 * s * sin(PI * t)
			&"air_dash":
				rot.z += TAU * _ease_in_out(t) * side
				squash_add += 0.12 * s * sin(PI * t)
			&"air_dodge_back":
				# Backflip: head travels backward (+X rotation for a -Z-facing model).
				rot.x += TAU * _ease_in_out(t)
				squash_add -= 0.12 * s * sin(TAU * t) * 0.5
			&"hit":
				var decay := (1.0 - t) * (1.0 - t)
				var ct: float = c["t"]
				off.x += 0.07 * s * decay * sin(ct * 71.0)
				off.z += 0.05 * s * decay * cos(ct * 53.0)
				rot.x += deg_to_rad(9.0) * s * decay  # flinch back
				rot.z += deg_to_rad(6.0) * s * decay * sin(ct * 47.0)
		if c["t"] >= dur:
			_active_cues.erase(c)
	_cue_offset = off
	_cue_rot = rot
	_cue_squash = squash_add


func _apply_transforms() -> void:
	_yaw_node.rotation = Vector3(0.0, _yaw_local, 0.0)
	_lean_node.rotation = Vector3(_lean_pitch, 0.0, _lean_roll)
	_lean_node.position = Vector3(_cue_offset.x, _bob_offset + _cue_offset.y, _cue_offset.z)
	# Volume-preserving squash at the feet.
	var sy := 1.0 + clampf(_squash + _cue_squash, -max_squash, max_squash)
	var sxz := 1.0 / sqrt(maxf(sy, 0.2))
	_squash_node.scale = Vector3(sxz, sy, sxz)
	_spin_node.rotation = _cue_rot


# ---------------------------------------------------------------- build

func _resolve_body() -> CharacterBody3D:
	if not body_path.is_empty():
		return get_node_or_null(body_path) as CharacterBody3D
	var n := get_parent()
	while n:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null


func _parent_yaw() -> float:
	var p := get_parent() as Node3D
	if p == null or not p.is_inside_tree():
		return 0.0
	var fwd := -p.global_basis.z
	return atan2(-fwd.x, -fwd.z)


func _build_hierarchy() -> void:
	var existing: Array[Node] = []
	for ch in get_children():
		if ch is Node3D:
			existing.append(ch)
	_yaw_node = _mk("_Yaw", self)
	_lean_node = _mk("_Lean", _yaw_node)
	_squash_node = _mk("_Squash", _lean_node)
	_spin_node = _mk("_Spin", _squash_node)
	_facing_node = _mk("_Facing", _spin_node)
	_fit_node = _mk("_Fit", _facing_node)
	_model_root = _instance_model(existing)
	if _model_root.get_parent() == null:
		_fit_node.add_child(_model_root)
	_apply_fit()


func _mk(n: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node


func _instance_model(existing: Array) -> Node3D:
	if model_scene:
		var inst := model_scene.instantiate()
		if inst is Node3D:
			if fix_generated_materials:
				_fix_materials(inst)
			return inst
		push_warning("RiglessVisual: model_scene root is not Node3D; using fallback")
		inst.free()
	if not existing.is_empty():
		var holder := Node3D.new()
		holder.name = "Model"
		_fit_node.add_child(holder)
		for ch in existing:
			ch.reparent(holder, false)
		return holder
	return _make_capsule()


func _make_capsule() -> Node3D:
	var root := Node3D.new()
	root.name = "CapsuleFallback"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_color
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	body.mesh = cap
	body.position.y = 0.9
	body.material_override = mat
	root.add_child(body)
	# "Nose" so facing (-Z) is readable.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.16, 0.3)
	nose.mesh = box
	nose.position = Vector3(0.0, 1.45, -0.42)
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = fallback_color.lightened(0.5)
	nose.material_override = nmat
	root.add_child(nose)
	return root


func _apply_fit() -> void:
	_fit_node.transform = Transform3D.IDENTITY
	var aabb := _model_aabb()
	var s := model_scale
	if fit_height > 0.0 and aabb.size.y > 0.0001:
		s = fit_height / aabb.size.y * model_scale
	_fit_node.scale = Vector3.ONE * s
	var centre := aabb.get_center()
	_fit_node.position = Vector3(-centre.x * s, -aabb.position.y * s, -centre.z * s)
	_fitted_height = aabb.size.y * s
	var ph := pivot_height if pivot_height >= 0.0 else _fitted_height * 0.5
	_spin_node.position = Vector3(0.0, ph, 0.0)
	_facing_node.position = Vector3(0.0, -ph, 0.0)
	_facing_node.rotation = Vector3(0.0, deg_to_rad(model_yaw_offset_deg), 0.0)


## Merged AABB of every VisualInstance3D under the model, in _fit space.
func _model_aabb() -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[_model_root, _model_root.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		if n is VisualInstance3D:
			var box: AABB = xf * (n as VisualInstance3D).get_aabb()
			if first:
				out = box
				first = false
			else:
				out = out.merge(box)
		for ch in n.get_children():
			if ch is Node3D:
				stack.append([ch, xf * (ch as Node3D).transform])
	if first:
		return AABB(Vector3(-0.4, 0.0, -0.4), Vector3(0.8, 1.8, 0.8))
	return out


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)



## See fix_generated_materials. Copies each StandardMaterial3D (the imported
## resource is shared) and drops metallic so the albedo texture reads.
static func _fix_materials(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as StandardMaterial3D
			if mat == null or (mat.metallic < 0.5 and mat.metallic_texture == null):
				continue
			var copy := mat.duplicate() as StandardMaterial3D
			copy.metallic = 0.0
			copy.metallic_texture = null
			copy.roughness = maxf(copy.roughness, 0.8)
			m.set_surface_override_material(i, copy)
