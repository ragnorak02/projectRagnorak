## Target bar — top-centre "Lumina Frost" readout for the locked-on / selected target.
## Shows name, HP gauge with damage chip, an optional stagger gauge and a
## "STAGGERED" tag. Visible only while a target is locked on (lock-on or tactical
## target selection, which both emit Events.lock_on_target_*). Read-only: uses the
## target's public properties and Events signals, never mutates it.
##
## Stagger is duck-typed: shown only when the target exposes `stagger_value` and
## `stagger_max` (and optionally `is_staggered()` / `stagger_damage_multiplier`).
extends CanvasLayer

const BAR_WIDTH := 540.0
const TOP_MARGIN := 28.0

var _panel: SlantPanel
var _name_label: Label
var _hp_number: Label
var _hp_gauge: Gauge
var _stagger_row: HBoxContainer
var _stagger_gauge: Gauge
var _stagger_tag: PanelContainer
var _stagger_tag_label: Label

var _target: Node3D = null
var _shown: bool = false


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_panel.visible = false


func _build_ui() -> void:
	var root := Control.new()
	root.name = "TargetBarRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = SlantPanel.new()
	_panel.name = "TargetPanel"
	_panel.slant_left = true
	_panel.slant_right = true
	_panel.padding = 12.0
	_panel.line_color = UIStyle.DANGER
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -BAR_WIDTH * 0.5
	_panel.offset_right = BAR_WIDTH * 0.5
	_panel.offset_top = TOP_MARGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	root.add_child(_panel)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 5)
	_panel.add_child(v)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	_name_label = UIStyle.make_label("", UIStyle.SIZE_M + 2, UIStyle.TEXT, true)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", UIStyle.SIZE_M + 2)
	top.add_child(_name_label)
	_stagger_tag = PanelContainer.new()
	_stagger_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stagger_tag.add_theme_stylebox_override("panel",
		UIStyle.pill(UIStyle.STAGGER.darkened(0.35), UIStyle.STAGGER, 10.0, 2.0))
	_stagger_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stagger_tag.visible = false
	top.add_child(_stagger_tag)
	_stagger_tag_label = UIStyle.make_label("STAGGERED", UIStyle.SIZE_S, UIStyle.TEXT, true)
	_stagger_tag.add_child(_stagger_tag_label)
	_hp_number = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	_hp_number.add_theme_font_override("font", UIStyle.font_body_bold())
	_hp_number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_hp_number)

	_hp_gauge = Gauge.new()
	_hp_gauge.name = "TargetHP"
	_hp_gauge.custom_minimum_size = Vector2(0, 12)
	_hp_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_hp_gauge)

	_stagger_row = HBoxContainer.new()
	_stagger_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stagger_row.add_theme_constant_override("separation", 8)
	_stagger_row.visible = false
	v.add_child(_stagger_row)
	_stagger_row.add_child(UIStyle.make_label("STAGGER", UIStyle.SIZE_S - 2, UIStyle.STAGGER, true))
	_stagger_gauge = Gauge.new()
	_stagger_gauge.name = "TargetStagger"
	_stagger_gauge.fill_color = UIStyle.STAGGER.darkened(0.1)
	_stagger_gauge.fill_color_end = UIStyle.STAGGER.lightened(0.25)
	_stagger_gauge.custom_minimum_size = Vector2(0, 6)
	_stagger_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stagger_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stagger_row.add_child(_stagger_gauge)


func _connect_signals() -> void:
	Events.lock_on_target_acquired.connect(_on_target_acquired)
	Events.lock_on_target_switched.connect(_on_target_acquired)
	Events.lock_on_target_lost.connect(_on_target_lost)
	Events.enemy_died.connect(_on_enemy_died)
	Events.tactical_target_reach.connect(_on_target_reach)
	Events.lock_on_target_lost.connect(_clear_reach)
	Events.tactical_mode_exited.connect(_clear_reach)


# --- Public (read-only helpers, also used by tests/screenshots) ---

func get_target() -> Node3D:
	return _target


func is_shown() -> bool:
	return _shown


## Display name for any target: display_name, member_data.display_name, or a
## cleaned-up node name ("Enemy2" -> "Enemy", "@CharacterBody3D@820" -> "Enemy").
static func target_display_name(t: Node) -> String:
	if t == null:
		return ""
	if "display_name" in t and str(t.display_name) != "":
		return str(t.display_name)
	if "member_data" in t and t.member_data and "display_name" in t.member_data:
		return str(t.member_data.display_name)
	if t.is_in_group(&"player"):
		var hero := load("res://resources/characters/hero.tres")
		if hero and "display_name" in hero:
			return hero.display_name
	var raw := String(t.name)
	# Auto-generated names ("@CharacterBody3D@820") carry no meaning.
	if raw.begins_with("@") or raw.begins_with("CharacterBody"):
		return "Enemy" if t.is_in_group(&"enemies") else "Target"
	while raw.length() > 1 and raw[raw.length() - 1].is_valid_int():
		raw = raw.left(raw.length() - 1)
	return raw.capitalize()


## Name as the tactical command menu lists it (CAR-P3): when several live
## enemies share a display name, append A/B/... in "enemies" group order (the
## same candidate order TacticalIdleState and tactical_menu use), e.g.
## "Reactor Sentry B". Auto-named enemies read "Enemy A/B/..." by their index
## among all live enemies, matching the menu's fallback. Non-enemies: plain name.
static func disambiguated_name(t: Node) -> String:
	var base := target_display_name(t)
	if t == null or not t.is_in_group(&"enemies") or not t.is_inside_tree():
		return base
	var live_index := 0
	var dup_index := -1
	var dup_count := 0
	var own_index := -1
	for e in t.get_tree().get_nodes_in_group(&"enemies"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		if "_is_dead" in e and e._is_dead and e != t:
			continue
		if e == t:
			own_index = live_index
			dup_index = dup_count
		if target_display_name(e) == base:
			dup_count += 1
		live_index += 1
	if base == "Enemy":
		var i := maxi(own_index, 0)
		return "Enemy %s" % (String.chr(65 + i) if i < 26 else str(i + 1))
	if dup_count > 1 and dup_index >= 0:
		return "%s %s" % [base, String.chr(65 + dup_index) if dup_index < 26 else str(dup_index + 1)]
	return base


# --- Handlers ---

func _on_target_acquired(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		_on_target_lost()
		return
	var changed := target != _target
	_target = target
	_refresh(true)
	if not _shown:
		_shown = true
		UIStyle.fade_slide_in(_panel, Vector2.UP, 0.16, 10.0)
	elif changed:
		UIStyle.fade_slide_in(_panel, Vector2.ZERO, 0.12)


func _on_target_lost() -> void:
	_target = null
	if _shown:
		_shown = false
		UIStyle.fade_out(_panel, 0.14, true, Vector2.UP, 8.0)


func _on_enemy_died(enemy: Node3D) -> void:
	if enemy == _target:
		_on_target_lost()


func _process(_delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target):
		_on_target_lost()
		return
	_refresh(false)


func _refresh(instant: bool) -> void:
	var t := _target
	var is_enemy := t.is_in_group(&"enemies")
	var name_text := disambiguated_name(t).to_upper()
	if _name_label.text != name_text:
		_name_label.text = name_text
	_panel.line_color = UIStyle.DANGER if is_enemy else UIStyle.CYAN
	if is_enemy:
		_hp_gauge.fill_color = UIStyle.DANGER.darkened(0.25)
		_hp_gauge.fill_color_end = UIStyle.DANGER
	else:
		_hp_gauge.fill_color = UIStyle.HP_START
		_hp_gauge.fill_color_end = UIStyle.HP_END

	if "current_hp" in t and "max_hp" in t:
		var cur: float = t.current_hp
		var mx: float = maxf(t.max_hp, 1.0)
		if instant or not is_equal_approx(_hp_gauge.value, cur) or not is_equal_approx(_hp_gauge.max_value, mx):
			_hp_gauge.set_values(cur, mx, instant)
			_hp_number.text = "%d%%" % int(ceil(cur / mx * 100.0))

	# Stagger (only if the target exposes it)
	var has_stagger := "stagger_value" in t and "stagger_max" in t
	_stagger_row.visible = has_stagger
	var staggered := false
	if t.has_method("is_staggered"):
		staggered = t.is_staggered()
	if has_stagger:
		var sv: float = t.stagger_value
		var sm: float = maxf(t.stagger_max, 1.0)
		if instant or not is_equal_approx(_stagger_gauge.value, sv):
			_stagger_gauge.set_values(sv, sm, instant)
	if staggered != _stagger_tag.visible:
		_stagger_tag.visible = staggered
		if staggered:
			UIStyle.pulse(_stagger_tag, 0.35, 0.8)
		else:
			UIStyle.stop_pulse(_stagger_tag)
	if staggered:
		var txt := "STAGGERED"
		if "stagger_damage_multiplier" in t:
			txt = "STAGGERED  %d%%" % int(round(float(t.stagger_damage_multiplier) * 100.0))
		if _stagger_tag_label.text != txt:
			_stagger_tag_label.text = txt


# --- v5: out-of-range dimming (Events.tactical_target_reach) -------------------

const OUT_OF_RANGE_TINT := Color(UIStyle.TEXT_DISABLED, 0.55)
var _out_of_range: bool = false


func _on_target_reach(target: Node3D, in_range: bool) -> void:
	_set_out_of_range(not in_range and target != null and target == _target)


func _clear_reach(_a = null) -> void:
	_set_out_of_range(false)


## True while the shown target is dimmed as out of range.
func is_out_of_range() -> bool:
	return _out_of_range


func _set_out_of_range(dim: bool) -> void:
	_out_of_range = dim
	var root := get_node_or_null(^"TargetBarRoot") as Control
	if root:
		root.modulate = OUT_OF_RANGE_TINT if dim else Color.WHITE
