## Battle banner (Battle System v3, Package U2).
## A short slanted "BATTLE" banner when Battle Mode starts
## (Events.battle_mode_changed(true)) and a subtle "CLEAR" when it ends.
## Lumina Frost style (SlantPanel + UIStyle fonts), upper-centre of the screen,
## clear of the target bar (top) and the party / command panels (bottom).
## Every tween is unscaled (tactical runs at 0.05, hit-stop at 0.01).
## Read-only: it only listens to Events and never touches gameplay state.
## Builds UI programmatically — register as a CanvasLayer script in
## zone_base._spawn_hud and test_arena (Head, R-2).
extends CanvasLayer

const BATTLE_TEXT := "BATTLE"
const CLEAR_TEXT := "CLEAR"
const ANCHOR_Y := 0.22            # banner centre, fraction of screen height
const SLIDE_PX := 36.0
const BATTLE_IN := 0.16
const BATTLE_HOLD := 1.1
const BATTLE_OUT := 0.4
const CLEAR_IN := 0.22
const CLEAR_HOLD := 0.7
const CLEAR_OUT := 0.5
const CLEAR_ALPHA := 0.85         # "subtle": never fully opaque

var _host: Control                # full-rect, slid as a whole (home = 0,0)
var _panel: SlantPanel
var _label: Label
var _accent_left: ColorRect
var _accent_right: ColorRect
var _tween: Tween = null
var _text: String = ""
var _zone_exiting: bool = false
var _battle_count: int = 0
var _clear_count: int = 0


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	Events.battle_mode_changed.connect(_on_battle_mode_changed)
	Events.zone_exiting.connect(_on_zone_exiting)
	Events.tactical_mode_entered.connect(_on_tactical_entered)


func _build_ui() -> void:
	_host = Control.new()
	_host.name = "BannerHost"
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_panel = SlantPanel.new()
	_panel.name = "Banner"
	_panel.slant_left = true
	_panel.slant_right = true
	_panel.slant = 26.0
	_panel.padding = 10
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = ANCHOR_Y
	_panel.anchor_bottom = ANCHOR_Y
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_host.add_child(_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	_panel.add_child(row)

	_accent_left = _make_accent()
	row.add_child(_accent_left)
	_label = UIStyle.make_label("", UIStyle.SIZE_XL, UIStyle.GOLD, true)
	_label.add_theme_font_size_override(&"font_size", UIStyle.SIZE_XL)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_color_override(&"font_outline_color", UIStyle.SHADOW)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	_accent_right = _make_accent()
	row.add_child(_accent_right)

	_host.visible = false
	_host.modulate.a = 0.0


func _make_accent() -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(56, 3)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


# --- Public (tools / tests) ---------------------------------------------------

## Text currently shown ("BATTLE" / "CLEAR"), or "" when hidden.
func get_text() -> String:
	return _text if is_showing() else ""


func is_showing() -> bool:
	return _host != null and _host.visible and _host.modulate.a > 0.01


## [battle banners shown, clear banners shown] since _ready.
func get_counts() -> Vector2i:
	return Vector2i(_battle_count, _clear_count)


func show_battle() -> void:
	_battle_count += 1
	_style(true)
	_play(BATTLE_IN, BATTLE_HOLD, BATTLE_OUT, 1.0, SLIDE_PX)


func show_clear() -> void:
	_clear_count += 1
	_style(false)
	_play(CLEAR_IN, CLEAR_HOLD, CLEAR_OUT, CLEAR_ALPHA, 0.0)


# --- Signals --------------------------------------------------------------------

func _on_battle_mode_changed(in_battle: bool) -> void:
	if in_battle:
		_zone_exiting = false
		show_battle()
	else:
		# Deferred: a zone exit force-ends the battle before zone_exiting reaches
		# this node; no "CLEAR" over a loading transition.
		_show_clear_deferred.call_deferred()


func _show_clear_deferred() -> void:
	if _zone_exiting or not is_inside_tree():
		return
	show_clear()


func _on_zone_exiting(_zone_id: StringName) -> void:
	_zone_exiting = true
	_hide_now()


func _on_tactical_entered() -> void:
	# The Command Menu takes over the screen; get out of its way quickly.
	if is_showing():
		_kill_tween()
		_tween = UIStyle.ui_tween(_host)
		if _tween == null:
			_hide_now()
			return
		_tween.tween_property(_host, "modulate:a", 0.0, 0.12)
		_tween.tween_callback(_on_tween_done)


# --- Internals ------------------------------------------------------------------

func _style(battle: bool) -> void:
	_text = BATTLE_TEXT if battle else CLEAR_TEXT
	_label.text = _text
	if battle:
		_label.add_theme_color_override(&"font_color", UIStyle.GOLD.lightened(0.1))
		_label.add_theme_font_size_override(&"font_size", UIStyle.SIZE_XL + 8)
		_panel.line_color = UIStyle.STAGGER
		_panel.fill_color = Color(UIStyle.GLASS_DEEP, 0.9)
		_panel.padding = 12
		_accent_left.color = Color(UIStyle.STAGGER, 0.85)
		_accent_right.color = Color(UIStyle.STAGGER, 0.85)
		_accent_left.custom_minimum_size = Vector2(72, 3)
		_accent_right.custom_minimum_size = Vector2(72, 3)
	else:
		_label.add_theme_color_override(&"font_color", UIStyle.CYAN)
		_label.add_theme_font_size_override(&"font_size", UIStyle.SIZE_L + 4)
		_panel.line_color = UIStyle.CYAN_GLOW
		_panel.fill_color = Color(UIStyle.GLASS, 0.6)
		_panel.padding = 8
		_accent_left.color = UIStyle.CYAN_DIM
		_accent_right.color = UIStyle.CYAN_DIM
		_accent_left.custom_minimum_size = Vector2(40, 2)
		_accent_right.custom_minimum_size = Vector2(40, 2)
	_panel.queue_redraw()
	# Re-centre for the new text width (anchors at 0.5 with GROW_BOTH).
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.reset_size()
	_recenter.call_deferred()


## Explicitly centre the panel on its anchor once its new minimum size is known.
func _recenter() -> void:
	if not is_instance_valid(_panel):
		return
	var sz := _panel.get_combined_minimum_size()
	_panel.offset_left = -sz.x * 0.5
	_panel.offset_right = sz.x * 0.5
	_panel.offset_top = -sz.y * 0.5
	_panel.offset_bottom = sz.y * 0.5


func _play(t_in: float, hold: float, t_out: float, alpha: float, slide: float) -> void:
	_kill_tween()
	_host.visible = true
	_host.modulate.a = 0.0
	_host.position = Vector2(-slide, 0.0)
	_tween = UIStyle.ui_tween(_host)
	if _tween == null:
		_host.position = Vector2.ZERO
		_host.modulate.a = alpha
		return
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_host, "modulate:a", alpha, t_in)
	if slide != 0.0:
		_tween.parallel().tween_property(_host, "position:x", 0.0, t_in)
	_tween.tween_interval(hold)
	_tween.tween_property(_host, "modulate:a", 0.0, t_out)
	_tween.tween_callback(_on_tween_done)


func _on_tween_done() -> void:
	_tween = null
	_host.visible = false
	_host.modulate.a = 0.0
	_host.position = Vector2.ZERO


func _hide_now() -> void:
	_kill_tween()
	if _host:
		_host.visible = false
		_host.modulate.a = 0.0
		_host.position = Vector2.ZERO


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
