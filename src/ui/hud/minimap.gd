## Minimap HUD (Battle v4, Package Y) — top-right, rotates with the camera.
## Terrain: a 256x256 SubViewport sharing the zone's World3D, rendered by an
## orthographic top-down Camera3D (~40 m across) every RENDER_EVERY frames.
## The map camera's "up" is the gameplay camera's flattened forward, so the map
## image is already rotated; icons use the same frame. The player arrow sits fixed
## at the centre and turns with the player's facing relative to the camera.
## Icons (2D, clamped to the rim when off-range):
##   enemies red (larger while engaged), NPCs white, chests/levers gold,
##   zone portals cyan diamond, tracked quest objective gold star (marker_position).
## Hidden while the pause menu (or any full-screen menu) or dialogue is open, and
## outside PLAYING/TACTICAL_MODE. Visible in Battle and the Command Menu.
## Read-only: never mutates the camera rig, player or world. Never takes input.
## v5 Options (live, via SettingsManager): show_minimap=false hides it;
## minimap_rotate=false = static north-up (map frame fixed to world -Z, the
## player arrow turns with the player's world facing instead).
extends CanvasLayer

const MAP_PX := 220.0               ## frame size at 1080p
const MARGIN := 24.0
const CORNER := 30.0                 ## rounded-square corner radius (px)
const VIEWPORT_PX := 256
const WORLD_SPAN_M := 40.0           ## metres across the map
const RENDER_EVERY := 2              ## terrain + icon refresh every Nth frame
const SCAN_INTERVAL_MS := 500        ## re-collect group members (unscaled)
const CAM_HEIGHT := 40.0             ## map camera above the player
const CEILING_M := 8.0               ## geometry higher than this above the player is cut
const DEPTH_M := 40.0                ## and deeper than this below
const CLAMP_RANGE_M := 60.0          ## beyond this, only portals/quest stay on the rim
const RIM_INSET := 12.0              ## clamped icons sit this far inside the frame
const NO_MARKER := Vector3.ZERO

## Menus that are part of the Command Menu flow (minimap stays up).
const KEEP_VISIBLE_MENUS: Array[StringName] = [&"target_selection", &"tactical_menu"]

enum Icon { ENEMY, ENEMY_ENGAGED, NPC, CHEST, PORTAL, QUEST }

# Enemy AIState values (EnemyBase): IDLE = 0, DEAD = 6.
const AI_IDLE := 0
const AI_DEAD := 6
# InteractableType values (interactable.gd): NPC = 1, CHEST = 2.
const ITYPE_NPC := 1
const ITYPE_CHEST := 2

const FROST_SHADER := """
shader_type canvas_item;
uniform vec4 low_col : source_color;
uniform vec4 mid_col : source_color;
uniform vec4 high_col : source_color;
uniform float fill_alpha = 0.86;
uniform vec2 size_px = vec2(220.0);
uniform float radius_px = 30.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float l = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(low_col.rgb, mid_col.rgb, smoothstep(0.02, 0.45, l));
	col = mix(col, high_col.rgb, smoothstep(0.45, 0.95, l));
	// keep a hint of the source hue so paths/water still read
	col = mix(col, src.rgb * 0.55 + col * 0.45, 0.22);
	vec2 p = (UV - vec2(0.5)) * size_px;
	float d = sd_round_box(p, size_px * 0.5, radius_px);
	float mask = 1.0 - smoothstep(-1.0, 0.5, d);
	// inner vignette toward the rim
	float vig = smoothstep(-size_px.x * 0.30, 0.0, d);
	col = mix(col, low_col.rgb, vig * 0.55);
	COLOR = vec4(col, mask * fill_alpha);
}
"""

var _root: Control
var _frame: Control
var _map_rect: TextureRect
var _icons: MinimapIconLayer
var _viewport: SubViewport
var _map_cam: Camera3D

var _player: Node3D = null
var _enemies: Array = []
var _interactables: Array = []
var _quest_marker: Vector3 = NO_MARKER
var _last_scan_ms: int = -100000
var _frame_counter: int = 0

var _open_menus: Dictionary = {}
var _in_dialogue: bool = false
var _map_up: Vector3 = Vector3(0, 0, -1)   # world direction drawn as map "up" (last refresh)


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	_update_visibility()


# --- Build -------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MinimapRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_frame = Control.new()
	_frame.name = "MinimapFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.anchor_left = 1.0
	_frame.anchor_right = 1.0
	_frame.anchor_top = 0.0
	_frame.anchor_bottom = 0.0
	_frame.offset_left = -(MAP_PX + MARGIN)
	_frame.offset_right = -MARGIN
	_frame.offset_top = MARGIN
	_frame.offset_bottom = MARGIN + MAP_PX
	_root.add_child(_frame)

	_viewport = SubViewport.new()
	_viewport.name = "MinimapViewport"
	_viewport.size = Vector2i(VIEWPORT_PX, VIEWPORT_PX)
	_viewport.own_world_3d = false           # shares the zone's World3D
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.use_occlusion_culling = false
	_viewport.positional_shadow_atlas_size = 0
	_viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED   # flat albedo: no lights/shadows
	_viewport.gui_disable_input = true
	_viewport.handle_input_locally = false
	_viewport.audio_listener_enable_3d = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_map_cam = Camera3D.new()
	_map_cam.name = "MinimapCamera"
	_map_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_cam.size = WORLD_SPAN_M
	_map_cam.near = CAM_HEIGHT - CEILING_M
	_map_cam.far = CAM_HEIGHT + DEPTH_M
	_map_cam.environment = _make_environment()
	_map_cam.current = true
	_viewport.add_child(_map_cam)

	_map_rect = TextureRect.new()
	_map_rect.name = "MinimapTerrain"
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.texture = _viewport.get_texture()
	_map_rect.material = _make_frost_material()
	_frame.add_child(_map_rect)

	_icons = MinimapIconLayer.new()
	_icons.name = "MinimapIcons"
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(_icons)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = UIStyle.GLASS_DEEP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = UIStyle.TEXT
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	return env


func _make_frost_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = FROST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter(&"low_col", UIStyle.GLASS_DEEP)
	mat.set_shader_parameter(&"mid_col", UIStyle.GLASS_LIGHT.lightened(0.18))
	mat.set_shader_parameter(&"high_col", UIStyle.TEXT_DIM.lerp(UIStyle.CYAN, 0.35))
	mat.set_shader_parameter(&"size_px", Vector2(MAP_PX, MAP_PX))
	mat.set_shader_parameter(&"radius_px", CORNER)
	return mat


func _connect_signals() -> void:
	Events.ui_menu_opened.connect(_on_menu_opened)
	Events.ui_menu_closed.connect(_on_menu_closed)
	Events.dialogue_started.connect(_on_dialogue_started)
	Events.dialogue_ended.connect(_on_dialogue_ended)
	Events.zone_entered.connect(_on_zone_entered)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	var sm := _settings()
	if sm and sm.has_signal(&"settings_changed"):
		sm.settings_changed.connect(_on_settings_changed)


func _settings() -> Node:
	return get_node_or_null(^"/root/SettingsManager") if is_inside_tree() else null


func _setting(key: StringName, fallback: bool) -> bool:
	var sm := _settings()
	if sm == null:
		return fallback
	var v = sm.get(key)
	return bool(v) if v != null else fallback


## Options: minimap enabled (SettingsManager.show_minimap, default true).
func is_enabled() -> bool:
	return _setting(&"show_minimap", true)


## Options: true = rotates with the camera, false = static north-up.
func is_rotating() -> bool:
	return _setting(&"minimap_rotate", true)


func _on_settings_changed() -> void:
	_update_visibility()
	if _root and _root.visible:
		_refresh()


# --- Visibility --------------------------------------------------------------

func _on_menu_opened(menu_name: StringName) -> void:
	_open_menus[menu_name] = true
	_update_visibility()


func _on_menu_closed(menu_name: StringName) -> void:
	_open_menus.erase(menu_name)
	_update_visibility()


func _on_dialogue_started() -> void:
	_in_dialogue = true
	_update_visibility()


func _on_dialogue_ended() -> void:
	_in_dialogue = false
	_update_visibility()


func _on_game_state_changed(_old: int, _new: int) -> void:
	_update_visibility()


func _on_zone_entered(_zone_id: StringName) -> void:
	_last_scan_ms = -100000   # rescan right away


func _blocking_menu_open() -> bool:
	for m in _open_menus:
		if not KEEP_VISIBLE_MENUS.has(m):
			return true
	return false


## True when the minimap should be on screen (see header for the rules).
func should_show() -> bool:
	if not is_enabled():
		return false
	if _in_dialogue or _blocking_menu_open():
		return false
	var st: int = GameManager.current_state
	if st != GameManager.GameState.PLAYING and st != GameManager.GameState.TACTICAL_MODE:
		return false
	if is_inside_tree() and get_tree().paused:
		return false
	return true


func _update_visibility() -> void:
	if _root == null:
		return
	var show := should_show()
	_root.visible = show
	if not show and _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


# --- Per frame ---------------------------------------------------------------

func _process(_delta: float) -> void:
	# Re-check cheap visibility conditions (tree pause has no signal).
	var show := should_show()
	if show != _root.visible:
		_update_visibility()
	if not show:
		return
	_frame_counter += 1
	if _frame_counter % RENDER_EVERY != 0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_scan_ms >= SCAN_INTERVAL_MS:
		_last_scan_ms = now
		_scan()
	_refresh()


## Collect the tracked nodes (groups) and the quest marker. Runs every 0.5 s.
func _scan() -> void:
	var tree := get_tree()
	_player = tree.get_first_node_in_group(&"player") as Node3D
	_enemies = tree.get_nodes_in_group(&"enemies")
	_interactables = []
	for n in tree.get_nodes_in_group(&"interactable"):
		if n.is_in_group(&"carryable"):
			continue   # crate pick-up areas: not map-worthy
		_interactables.append(n)
	_quest_marker = _read_quest_marker()


func _read_quest_marker() -> Vector3:
	if _player == null or not _player.has_node("QuestSystem"):
		return NO_MARKER
	var qs: Node = _player.get_node("QuestSystem")
	if not qs.has_method("get_tracked_quest"):
		return NO_MARKER
	var tracked: Dictionary = qs.get_tracked_quest()
	if tracked.is_empty():
		return NO_MARKER
	var data: Resource = tracked.get("data")
	var idx: int = tracked.get("current_objective_index", -1)
	if data == null or idx < 0 or idx >= data.objectives.size():
		return NO_MARKER
	var obj: Resource = data.objectives[idx]
	var pos = obj.get("marker_position")
	return pos if pos is Vector3 else NO_MARKER


## Gameplay camera forward on the ground plane (read-only).
func _camera_forward() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.FORWARD
	var f := -cam.global_basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		f = cam.global_basis.y   # looking straight down: use the camera's up
		f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _refresh() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = null
		_icons.clear()
		_icons.queue_redraw()
		return
	# Rotating: map "up" = camera forward. Static: map "up" = world north (-Z).
	var fwd := _camera_forward() if is_rotating() else Vector3(0, 0, -1)
	var right := fwd.cross(Vector3.UP).normalized()
	_map_up = fwd
	var center := _player.global_position

	# Map camera: looks down, its up axis = camera forward.
	_map_cam.global_transform = Transform3D(Basis(right, fwd, Vector3.UP), center + Vector3(0, CAM_HEIGHT, 0))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var half := MAP_PX * 0.5
	var px_per_m := MAP_PX / WORLD_SPAN_M
	_icons.begin(Vector2(half, half), half - RIM_INSET)

	for e in _enemies:
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		var st: int = int(e.get(&"ai_state")) if e.get(&"ai_state") != null else AI_IDLE
		if st == AI_DEAD:
			continue
		var kind: int = Icon.ENEMY if st == AI_IDLE else Icon.ENEMY_ENGAGED
		_add_world_icon(e.global_position - center, right, fwd, px_per_m, kind, false)

	for n in _interactables:
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n.get(&"_is_active") == false:
			continue
		var kind := _classify_interactable(n)
		if kind < 0:
			continue
		var dim: bool = kind == Icon.CHEST and n.get(&"is_opened") == true
		_add_world_icon(n.global_position - center, right, fwd, px_per_m, kind, dim)

	if _quest_marker != NO_MARKER:
		_add_world_icon(_quest_marker - center, right, fwd, px_per_m, Icon.QUEST, false)

	# Player arrow: player facing relative to the map "up" (camera forward when
	# rotating, north when static).
	var pf := -_player.global_basis.z
	_icons.player_angle = atan2(pf.dot(right), pf.dot(fwd))
	# North (world -Z) direction on the map.
	var north := Vector3(0, 0, -1)
	_icons.north_dir = Vector2(north.dot(right), -north.dot(fwd))
	_icons.queue_redraw()


func _classify_interactable(n: Node) -> int:
	if n.get(&"target_zone_id") != null:
		return Icon.PORTAL
	var t = n.get(&"interactable_type")
	if t == null:
		return -1
	if int(t) == ITYPE_NPC:
		return Icon.NPC
	return Icon.CHEST   # chests, levers and other generic interactables


func _add_world_icon(offset: Vector3, right: Vector3, fwd: Vector3, px_per_m: float, kind: int, dim: bool) -> void:
	var local := Vector2(offset.dot(right), -offset.dot(fwd))   # screen y grows down
	var dist := local.length()
	var always_clamp := kind == Icon.PORTAL or kind == Icon.QUEST
	if dist > CLAMP_RANGE_M and not always_clamp:
		return
	_icons.add(local * px_per_m, kind, dim)


# --- Test / tooling API ------------------------------------------------------

## Screen-space rect of the minimap frame (for tests and screenshots).
func get_frame_rect() -> Rect2:
	return _frame.get_global_rect() if _frame else Rect2()


func is_map_visible() -> bool:
	return _root != null and _root.visible


## Number of icons drawn on the last refresh, by Icon kind.
func get_icon_counts() -> Dictionary:
	return _icons.counts() if _icons else {}


## World direction shown as map "up" on the last refresh (north in static mode).
func get_map_up() -> Vector3:
	return _map_up


## Player arrow angle (radians, 0 = map up) on the last refresh.
func get_player_arrow_angle() -> float:
	return _icons.player_angle if _icons else 0.0


func get_map_viewport() -> SubViewport:
	return _viewport


# --- Icon layer ----------------------------------------------------------------

## Draws terrain overlay rings, icons, the player arrow, the rim and the N tick.
class MinimapIconLayer extends Control:
	var center: Vector2 = Vector2.ZERO
	var rim_half: float = 100.0
	var player_angle: float = 0.0
	var north_dir: Vector2 = Vector2(0, -1)
	var _pos: PackedVector2Array = PackedVector2Array()
	var _kind: PackedInt32Array = PackedInt32Array()
	var _flags: PackedInt32Array = PackedInt32Array()   # bit0 = dim, bit1 = clamped
	var _rim_box: StyleBoxFlat
	var _glow_box: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rim_box = StyleBoxFlat.new()
		_rim_box.draw_center = false
		_rim_box.border_color = UIStyle.CYAN
		_rim_box.set_border_width_all(2)
		_rim_box.set_corner_radius_all(int(CORNER))
		_rim_box.anti_aliasing = true
		_glow_box = StyleBoxFlat.new()
		_glow_box.draw_center = false
		_glow_box.border_color = Color(UIStyle.CYAN_GLOW, 0.25)
		_glow_box.set_border_width_all(5)
		_glow_box.set_corner_radius_all(int(CORNER) + 3)
		_glow_box.anti_aliasing = true

	func begin(c: Vector2, half: float) -> void:
		center = c
		rim_half = half
		clear()

	func clear() -> void:
		_pos.clear()
		_kind.clear()
		_flags.clear()

	func add(screen_offset: Vector2, kind: int, dim: bool) -> void:
		var p := screen_offset
		var flags := 1 if dim else 0
		var m := maxf(absf(p.x), absf(p.y))
		if m > rim_half:
			p *= rim_half / m
			flags |= 2
		_pos.append(center + p)
		_kind.append(kind)
		_flags.append(flags)

	func counts() -> Dictionary:
		var d := {}
		for k in _kind:
			d[k] = int(d.get(k, 0)) + 1
		return d

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# Range ring (frost).
		draw_arc(center, size.x * 0.25, 0.0, TAU, 48, Color(UIStyle.CYAN, 0.10), 1.0, true)
		# Icons: low-priority first so enemies / quest end on top.
		for pass_kind in [Icon.CHEST, Icon.NPC, Icon.PORTAL, Icon.ENEMY, Icon.ENEMY_ENGAGED, Icon.QUEST]:
			for i in _kind.size():
				if _kind[i] == pass_kind:
					_draw_icon(_pos[i], _kind[i], _flags[i])
		_draw_player()
		# Rim.
		draw_style_box(_glow_box, r.grow(2.0))
		draw_style_box(_rim_box, r)
		_draw_north()

	func _draw_icon(p: Vector2, kind: int, flags: int) -> void:
		var clamped := (flags & 2) != 0
		var a := 0.45 if (flags & 1) != 0 else 1.0
		if clamped:
			a *= 0.75
		var s := 0.8 if clamped else 1.0
		match kind:
			Icon.ENEMY:
				_dot(p, 3.5 * s, Color(UIStyle.DANGER, a))
			Icon.ENEMY_ENGAGED:
				draw_circle(p, 8.0 * s, Color(UIStyle.DANGER, 0.25 * a))
				_dot(p, 5.5 * s, Color(UIStyle.DANGER, a))
			Icon.NPC:
				_dot(p, 3.5 * s, Color(UIStyle.TEXT, a))
			Icon.CHEST:
				_dot(p, 3.5 * s, Color(UIStyle.GOLD, a))
			Icon.PORTAL:
				var d := 6.0 * s
				var pts := PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)])
				draw_colored_polygon(pts, Color(UIStyle.CYAN, a))
				pts.append(pts[0])
				draw_polyline(pts, Color(UIStyle.GLASS_DEEP, a), 1.5, true)
			Icon.QUEST:
				_star(p, 8.0 * s, Color(UIStyle.GOLD, a))

	func _dot(p: Vector2, radius: float, col: Color) -> void:
		draw_circle(p, radius + 1.2, Color(UIStyle.GLASS_DEEP, col.a))
		draw_circle(p, radius, col)

	func _star(p: Vector2, radius: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var rr := radius if i % 2 == 0 else radius * 0.45
			var ang := -PI * 0.5 + i * PI / 5.0
			pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(UIStyle.GLASS_DEEP, col.a), 1.2, true)

	func _draw_player() -> void:
		var fwd := Vector2(sin(player_angle), -cos(player_angle))
		var side := Vector2(-fwd.y, fwd.x)
		var tip := center + fwd * 10.0
		var back := center - fwd * 6.0
		var pts := PackedVector2Array([tip, center + side * 7.0 - fwd * 7.0, back, center - side * 7.0 - fwd * 7.0])
		draw_colored_polygon(pts, UIStyle.CYAN)
		pts.append(pts[0])
		draw_polyline(pts, UIStyle.GLASS_DEEP, 2.0, true)

	func _draw_north() -> void:
		var dir := north_dir.normalized() if north_dir.length_squared() > 0.0001 else Vector2(0, -1)
		# Place the N badge on the rounded-square rim along `dir`.
		var half := size.x * 0.5
		var m := maxf(absf(dir.x), absf(dir.y))
		var p := center + dir / m * (half - 1.0)
		var font := UIStyle.font_header()
		var fs := UIStyle.SIZE_S
		draw_circle(p, 10.0, UIStyle.GLASS_DEEP)
		draw_arc(p, 10.0, 0.0, TAU, 24, UIStyle.CYAN, 1.5, true)
		var ts := font.get_string_size("N", HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, p + Vector2(-ts.x * 0.5, ts.y * 0.32), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, UIStyle.TEXT)
		# Heading tick at the top centre (camera forward); the N badge covers it when facing north.
		var top := Vector2(center.x, 0.0)
		if p.distance_to(top) < 16.0:
			return
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -1), top + Vector2(6, -1), top + Vector2(0, 7)]), UIStyle.CYAN)
