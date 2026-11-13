## UIStyle — "Lumina Frost" style kit (static, no instance needed).
## Palette, fonts (with fallback), StyleBox factories and unscaled-time tween helpers.
## All helpers are headless-safe: they never require a renderer, and tween helpers
## return null when the node is not inside the scene tree.
class_name UIStyle
extends RefCounted

# --- Palette ---------------------------------------------------------------
const GLASS := Color(0.039, 0.078, 0.125, 0.78)          # #0A1420 @ 78%
const GLASS_DEEP := Color(0.020, 0.043, 0.075, 0.88)     # darker bottom of gradient
const GLASS_LIGHT := Color(0.075, 0.141, 0.212, 0.82)    # selected / top of gradient
const CYAN := Color("#5FE3F0")                           # primary accent (Lumina)
const CYAN_DIM := Color(0.373, 0.890, 0.941, 0.35)
const CYAN_GLOW := Color(0.373, 0.890, 0.941, 0.55)
const GOLD := Color("#F2B544")                           # secondary accent (ember)
const GOLD_DIM := Color(0.949, 0.710, 0.267, 0.35)
const HP_START := Color("#2FB8A6")                        # teal
const HP_END := Color("#5FE3F0")                          # cyan
const MP := Color("#B48CFF")                              # violet
const ATB := Color("#F2B544")                             # gold
const ATB_FULL := Color("#FFD37A")
const STAGGER := Color("#FF8A3D")                         # orange
const DANGER := Color("#FF5C5C")                          # low HP / errors
const CHIP := Color(1.0, 0.92, 0.92, 0.85)                # damage-chip trail
const GAUGE_BACK := Color(0.11, 0.18, 0.25, 0.85)       # empty-bar track (visible on glass)
const TEXT := Color("#E8F1F5")
const TEXT_DIM := Color("#7F95A3")
const TEXT_DISABLED := Color("#4A5A66")
const SHADOW := Color(0, 0, 0, 0.6)
const DIM_SCREEN := Color(0.01, 0.03, 0.05, 0.72)         # full-screen menu dim

# Controller face-button colours (procedural badges)
const GLYPH_A := Color("#4CC96B")
const GLYPH_B := Color("#E5534B")
const GLYPH_X := Color("#3F8CFF")
const GLYPH_Y := Color("#F2C94C")
const GLYPH_PILL := Color("#2A3A48")      # shoulders/triggers/sticks/dpad
const KEYCAP_FILL := Color("#1A2733")
const KEYCAP_EDGE := Color("#7F95A3")

# --- Sizes -----------------------------------------------------------------
const SIZE_S := 16
const SIZE_M := 22
const SIZE_L := 30
const SIZE_XL := 48

const SLANT := 18.0          # default slant width in px for panels
const ANIM_TIME := 0.14      # standard fade/slide duration (seconds, unscaled)
const SLIDE_DIST := 10.0     # standard slide distance in px

# --- Fonts -----------------------------------------------------------------
const FONT_HEADER_PATH := "res://assets/fonts/rajdhani/Rajdhani-Bold.ttf"
const FONT_HEADER_MEDIUM_PATH := "res://assets/fonts/rajdhani/Rajdhani-SemiBold.ttf"
const FONT_BODY_PATH := "res://assets/fonts/barlow/Barlow-Medium.ttf"
const FONT_BODY_BOLD_PATH := "res://assets/fonts/barlow/Barlow-SemiBold.ttf"

static func _load_font(path: String) -> Font:
	var f: Font = null
	if ResourceLoader.exists(path):
		f = load(path) as Font   # ResourceLoader caches the instance
	if f == null:
		f = ThemeDB.fallback_font
	return f


## Bold condensed header font (Rajdhani Bold). Falls back to the engine default.
static func font_header() -> Font:
	return _load_font(FONT_HEADER_PATH)


## Slightly lighter header font (Rajdhani SemiBold) for tabs and sub-headers.
static func font_header_medium() -> Font:
	return _load_font(FONT_HEADER_MEDIUM_PATH)


## Body font (Barlow Medium).
static func font_body() -> Font:
	return _load_font(FONT_BODY_PATH)


## Emphasised body font (Barlow SemiBold) for numbers and selected rows.
static func font_body_bold() -> Font:
	return _load_font(FONT_BODY_BOLD_PATH)


## True when the bundled fonts are present (false = engine fallback in use).
static func fonts_bundled() -> bool:
	return ResourceLoader.exists(FONT_HEADER_PATH) and ResourceLoader.exists(FONT_BODY_PATH)


# --- Label helpers ---------------------------------------------------------

## Style an existing Label/RichTextLabel-like control (font, size, colour, outline).
static func style_label(label: Control, size: int = SIZE_M, color: Color = TEXT, header: bool = false, outline: int = 0) -> void:
	if label == null:
		return
	label.add_theme_font_override(&"font", font_header() if header else font_body())
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	if outline > 0:
		label.add_theme_constant_override(&"outline_size", outline)
		label.add_theme_color_override(&"font_outline_color", SHADOW)


## Create a styled Label.
static func make_label(text: String, size: int = SIZE_M, color: Color = TEXT, header: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(l, size, color, header)
	return l


# --- StyleBox factories ----------------------------------------------------

## Dark translucent glass panel with a thin cyan light-line on the top edge.
static func glass_panel(margin: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.border_color = CYAN_DIM
	sb.border_width_top = 1
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## Glass panel in the selected/focused state: lighter fill, cyan edge and glow.
static func glass_panel_selected(margin: float = 14.0) -> StyleBoxFlat:
	var sb := glass_panel(margin)
	sb.bg_color = GLASS_LIGHT
	sb.border_color = CYAN
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.28)
	sb.shadow_size = 8
	return sb


## Fully rounded pill (badges, toasts, tags).
static func pill(color: Color = GLASS, border: Color = Color(0, 0, 0, 0), margin_h: float = 12.0, margin_v: float = 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(64)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.anti_aliasing = true
	return sb


## Slanted (skewed parallelogram) button/row style. state: "normal", "selected", "disabled".
static func slant_row(state: String = "normal", margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.skew = Vector2(0.25, 0.0)
	sb.content_margin_left = margin + 12.0
	sb.content_margin_right = margin + 12.0
	sb.content_margin_top = margin * 0.5
	sb.content_margin_bottom = margin * 0.5
	sb.anti_aliasing = true
	match state:
		"selected":
			sb.bg_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.16)
			sb.border_color = CYAN
			sb.border_width_left = 3
			sb.border_width_bottom = 1
			sb.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.22)
			sb.shadow_size = 6
		"disabled":
			sb.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, 0.45)
			sb.border_color = Color(TEXT_DISABLED, 0.5)
			sb.border_width_bottom = 1
		_:
			sb.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, 0.6)
			sb.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.18)
			sb.border_width_bottom = 1
	return sb


## Apply the slanted Lumina style to any Button (keeps its text/signals/focus).
static func style_button(button: Button, size: int = SIZE_M) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override(&"normal", slant_row("normal"))
	button.add_theme_stylebox_override(&"hover", slant_row("selected"))
	button.add_theme_stylebox_override(&"pressed", slant_row("selected"))
	button.add_theme_stylebox_override(&"focus", slant_row("selected"))
	button.add_theme_stylebox_override(&"disabled", slant_row("disabled"))
	button.add_theme_font_override(&"font", font_header_medium())
	button.add_theme_font_size_override(&"font_size", size)
	button.add_theme_color_override(&"font_color", TEXT)
	button.add_theme_color_override(&"font_focus_color", Color.WHITE)
	button.add_theme_color_override(&"font_hover_color", Color.WHITE)
	button.add_theme_color_override(&"font_pressed_color", CYAN)
	button.add_theme_color_override(&"font_disabled_color", TEXT_DISABLED)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


## A Theme carrying the Lumina defaults (fonts, Label/Button/Panel styles).
## Assign to a root Control's `theme` to restyle a whole menu at once.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = SIZE_M
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_stylebox(&"panel", &"PanelContainer", glass_panel())
	t.set_stylebox(&"panel", &"Panel", glass_panel())
	t.set_stylebox(&"normal", &"Button", slant_row("normal"))
	t.set_stylebox(&"hover", &"Button", slant_row("selected"))
	t.set_stylebox(&"pressed", &"Button", slant_row("selected"))
	t.set_stylebox(&"focus", &"Button", slant_row("selected"))
	t.set_stylebox(&"disabled", &"Button", slant_row("disabled"))
	t.set_font(&"font", &"Button", font_header_medium())
	t.set_color(&"font_color", &"Button", TEXT)
	t.set_color(&"font_focus_color", &"Button", Color.WHITE)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_disabled_color", &"Button", TEXT_DISABLED)
	return t


# --- Tweens (unscaled time) ------------------------------------------------

## Create a Tween bound to `node` that ignores Engine.time_scale (tactical = 0.1).
## Returns null if the node is not inside the tree (headless/unit-test safety).
static func ui_tween(node: Node) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


## Fade in and slide from `dir` (e.g. Vector2.LEFT = comes in from the left).
## Slides only Controls/Node2Ds whose parent is not a Container; otherwise fades only.
## Makes the node visible. Returns the Tween (or null when not in tree; node is
## then simply shown at full opacity).
static func fade_slide_in(node: CanvasItem, dir: Vector2 = Vector2.LEFT, duration: float = ANIM_TIME, distance: float = SLIDE_DIST) -> Tween:
	if node == null:
		return null
	_kill_meta_tween(node, &"_ui_fade_tween")
	node.visible = true
	var tw := ui_tween(node)
	if tw == null:
		node.modulate.a = 1.0
		return null
	node.modulate.a = 0.0
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, duration)
	var can_slide := (node is Control and not (node.get_parent() is Container)) or node is Node2D
	if can_slide and dir != Vector2.ZERO:
		var home: Vector2 = node.get_meta(&"_ui_home") if node.has_meta(&"_ui_home") else node.position
		node.set_meta(&"_ui_home", home)
		node.position = home + dir.normalized() * distance
		tw.tween_property(node, "position", home, duration)
	node.set_meta(&"_ui_fade_tween", tw)
	return tw


## Fade out (optionally sliding toward `dir`), then hide. Returns the Tween or null.
static func fade_out(node: CanvasItem, duration: float = ANIM_TIME, hide_after: bool = true, dir: Vector2 = Vector2.ZERO, distance: float = SLIDE_DIST) -> Tween:
	if node == null:
		return null
	_kill_meta_tween(node, &"_ui_fade_tween")
	var tw := ui_tween(node)
	if tw == null:
		if hide_after:
			node.visible = false
		return null
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "modulate:a", 0.0, duration)
	var can_slide := (node is Control and not (node.get_parent() is Container)) or node is Node2D
	if can_slide and dir != Vector2.ZERO:
		var home: Vector2 = node.get_meta(&"_ui_home") if node.has_meta(&"_ui_home") else node.position
		node.set_meta(&"_ui_home", home)
		tw.tween_property(node, "position", home + dir.normalized() * distance, duration)
	if hide_after:
		tw.chain().tween_callback(func() -> void:
			node.visible = false
			node.modulate.a = 1.0
			if node.has_meta(&"_ui_home"):
				node.position = node.get_meta(&"_ui_home"))
	node.set_meta(&"_ui_fade_tween", tw)
	return tw


## Soft looping brightness pulse on `node` (selected rows, low-HP). Stop with stop_pulse().
## Returns the Tween or null when not in tree.
static func pulse(node: CanvasItem, strength: float = 0.25, period: float = 1.1) -> Tween:
	if node == null:
		return null
	stop_pulse(node)
	var tw := ui_tween(node)
	if tw == null:
		return null
	var base: Color = node.self_modulate
	node.set_meta(&"_ui_pulse_base", base)
	var bright := Color(base.r * (1.0 + strength), base.g * (1.0 + strength), base.b * (1.0 + strength), base.a)
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "self_modulate", bright, period * 0.5)
	tw.tween_property(node, "self_modulate", base, period * 0.5)
	node.set_meta(&"_ui_pulse_tween", tw)
	return tw


## Stop a pulse started with pulse() and restore the original self_modulate.
static func stop_pulse(node: CanvasItem) -> void:
	if node == null:
		return
	_kill_meta_tween(node, &"_ui_pulse_tween")
	if node.has_meta(&"_ui_pulse_base"):
		node.self_modulate = node.get_meta(&"_ui_pulse_base")
		node.remove_meta(&"_ui_pulse_base")


static func _kill_meta_tween(node: Object, key: StringName) -> void:
	if node.has_meta(key):
		var old = node.get_meta(key)
		if old is Tween and old.is_valid():
			old.kill()
		node.remove_meta(key)


# --- Drawing helpers (for widgets' _draw) ----------------------------------

## Points of a parallelogram/trapezoid inside `rect` with slanted left and/or right edges.
## Left slant: top-left corner pushed right by `slant`. Right slant: bottom-right pulled left.
static func slant_points(rect: Rect2, slant: float, left: bool = true, right: bool = false) -> PackedVector2Array:
	var s := minf(slant, rect.size.x * 0.4)
	var tl := rect.position + Vector2(s if left else 0.0, 0.0)
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end - Vector2(s if right else 0.0, 0.0)
	var bl := Vector2(rect.position.x, rect.end.y)
	return PackedVector2Array([tl, tr, br, bl])


## Lerp between HP colours by ratio, switching to DANGER below `low_threshold`.
static func hp_color(ratio: float, low_threshold: float = 0.25) -> Color:
	if ratio <= low_threshold:
		return DANGER
	return HP_START.lerp(HP_END, clampf(ratio, 0.0, 1.0))
