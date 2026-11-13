## Combat HUD — "Lumina Frost" party panel (bottom-right).
## One slanted row per party member (player + companions from the party system).
## The active member's row is larger and highlighted: name, HP gauge + number,
## MP gauge + number, 2-cell ATB gauge, and the shared team meter.
## Also owns the ability-failure / cast toast and cooldown readouts.
## Battle System v3 (Package U): an "ARCANE" stance tag on the active row while
## the unique stance is on (Events.stance_changed), and a combo-step indicator
## (L / H pips + finisher name) above the panel during a string
## (Events.combo_step / combo_finisher / combo_reset).
## Builds UI programmatically; all tweens run in unscaled time (tactical = 0.1x).
extends CanvasLayer

# --- Layout (1920x1080 reference) ---
const PANEL_MARGIN := Vector2(36, 32)      # distance from the bottom-right corner
const ACTIVE_WIDTH := 460.0
const INACTIVE_WIDTH := 400.0
const ROW_SPACING := 6

# HP colour thresholds (ratio of max): <= 0.5 caution tint, <= 0.25 danger + pulse.
const HP_DANGER_RATIO := 0.25
const HP_CAUTION_RATIO := 0.5

# ATB cells: 2 cells x 50 (Design Direction). Max ATB is read from the signal.
const ATB_SEGMENT_COST: float = 50.0

# Bar references (player-controlled member's row — the targets of player_* signals)
var _hp_bar: Gauge
var _mp_bar: Gauge
var _atb_bar: SegmentGauge
var _hp_label: Label
var _mp_label: Label
var _atb_label: Label
var _flash_label: Label
var _flash_panel: PanelContainer
var _cooldown_container: VBoxContainer

# Party HUD
var _party_panel: VBoxContainer           # rows stack, anchored bottom-right
var _ally_bar_container: VBoxContainer    # holds the non-active ("ally") rows
var _active_container: VBoxContainer      # holds the active row
var _ally_hp_bar: Gauge                   # first ally's HP gauge (compat ref)
var _ally_hp_label: Label                 # first ally's HP number (compat ref)
var _team_meter_bar: Gauge
var _team_meter_label: Label

# Rows: plain Array of Dictionaries (no typed widget arrays — leaks in 4.6).
# {id, node, is_player, active, root, name, hp, hp_label, mp, mp_label, atb, atb_label, tag}
var _rows: Array = []
var _party_system: Node = null
var _player: Node = null
var _roster_signature: String = ""

# Player values cached from signals so rebuilt rows start correct.
var _p_hp := Vector2(100, 100)   # (current, max)
var _p_mp := Vector2(50, 50)
var _p_atb := Vector2(0, 100)
var _team := Vector2(0, 100)

# Flash feedback
var _flash_tween: Tween = null
var _mp_flash_tween: Tween = null
var _atb_flash_tween: Tween = null

# Stylebox references for flash (modulate colours for the widget-based bars)
const FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)

# Roster re-check throttle (real time)
const ROSTER_CHECK_MSEC := 250
var _last_roster_check: int = 0

# --- v3: stance tag + combo pips ---
const COMBO_STEPS := 3
const COMBO_HOLD_SEC := 0.55       # pips stay readable this long after a reset (real time)
const FINISHER_NAMES := {
	&"triple_slash": "TRIPLE SLASH", &"strong_slash": "STRONG SLASH",
	&"blast": "BLAST", &"big_blast": "BIG BLAST", &"huge_blast": "HUGE BLAST",
}
var _stance_id: StringName = &""   # active member's stance (&"" = none)
var _stance_member: StringName = &""
var _combo_box: PanelContainer     # glass backing; holds _combo_row
var _combo_row: HBoxContainer
var _combo_pips: Array = []        # PanelContainer per step (plain Array, see K gotchas)
var _combo_finisher_label: Label
var _combo_kinds: Array = []       # &"light"/&"heavy" per filled step
var _combo_tween: Tween = null


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()
	_sync_roster()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "CombatHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bottom-right stack: toast, cooldowns, ally rows, active row.
	_party_panel = VBoxContainer.new()
	_party_panel.name = "PartyPanel"
	_party_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_panel.anchor_left = 1.0
	_party_panel.anchor_right = 1.0
	_party_panel.anchor_top = 1.0
	_party_panel.anchor_bottom = 1.0
	_party_panel.offset_right = -PANEL_MARGIN.x
	_party_panel.offset_bottom = -PANEL_MARGIN.y
	_party_panel.offset_left = -PANEL_MARGIN.x - ACTIVE_WIDTH
	_party_panel.offset_top = -PANEL_MARGIN.y
	_party_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_party_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_party_panel.alignment = BoxContainer.ALIGNMENT_END
	_party_panel.add_theme_constant_override("separation", ROW_SPACING)
	root.add_child(_party_panel)

	# Toast (failure / cast feedback) — small pill above the panel.
	_flash_panel = PanelContainer.new()
	_flash_panel.name = "Toast"
	_flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_flash_panel.add_theme_stylebox_override("panel",
		UIStyle.pill(UIStyle.GLASS_DEEP, UIStyle.DANGER, 16.0, 5.0))
	_flash_panel.modulate.a = 0.0
	_party_panel.add_child(_flash_panel)
	_flash_label = Label.new()
	_flash_label.name = "FlashLabel"
	_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.style_label(_flash_label, UIStyle.SIZE_S + 2, UIStyle.DANGER, true, 4)
	_flash_label.add_theme_font_size_override("font_size", 18)
	_flash_panel.add_child(_flash_label)

	_build_combo_row()

	# Cooldown readouts (right-aligned, above the rows)
	_cooldown_container = VBoxContainer.new()
	_cooldown_container.name = "Cooldowns"
	_cooldown_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	_cooldown_container.add_theme_constant_override("separation", 2)
	_party_panel.add_child(_cooldown_container)

	# Ally rows (non-active members), then the active row at the bottom.
	_ally_bar_container = VBoxContainer.new()
	_ally_bar_container.name = "AllyRows"
	_ally_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ally_bar_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ally_bar_container.add_theme_constant_override("separation", ROW_SPACING)
	_ally_bar_container.visible = false
	_party_panel.add_child(_ally_bar_container)

	_active_container = VBoxContainer.new()
	_active_container.name = "ActiveRow"
	_active_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	_party_panel.add_child(_active_container)


## Combo-step indicator: "COMBO [L][H][ ]  BLAST" right-aligned above the rows.
func _build_combo_row() -> void:
	_combo_box = PanelContainer.new()
	_combo_box.name = "ComboPips"
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_combo_box.add_theme_stylebox_override("panel", UIStyle.pill(UIStyle.GLASS_DEEP, UIStyle.CYAN_DIM, 12.0, 4.0))
	_combo_box.modulate.a = 0.0
	_combo_box.visible = false
	_party_panel.add_child(_combo_box)
	_combo_row = HBoxContainer.new()
	_combo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_row.add_theme_constant_override("separation", 7)
	_combo_box.add_child(_combo_row)
	_combo_finisher_label = UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.GOLD, true)
	_combo_finisher_label.add_theme_font_size_override("font_size", UIStyle.SIZE_M)
	_combo_finisher_label.add_theme_constant_override("outline_size", 4)
	_combo_finisher_label.add_theme_color_override("font_outline_color", UIStyle.SHADOW)
	_combo_finisher_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_row.add_child(_combo_finisher_label)
	var caption := UIStyle.make_label("COMBO", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_row.add_child(caption)
	for i in COMBO_STEPS:
		var pip := PanelContainer.new()
		pip.name = "Pip%d" % (i + 1)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(26, 24)
		var lbl := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT, true)
		lbl.add_theme_font_size_override("font_size", UIStyle.SIZE_S + 2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pip.add_child(lbl)
		_combo_row.add_child(pip)
		_combo_pips.append(pip)
	_paint_combo_pips()


## Slanted pip box (skewed StyleBoxFlat, matches the Frost slant language).
func _pip_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.skew = Vector2(0.28, 0.0)
	sb.anti_aliasing = true
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	return sb


func _paint_combo_pips() -> void:
	for i in _combo_pips.size():
		var pip: PanelContainer = _combo_pips[i]
		var lbl: Label = pip.get_child(0)
		var kind: StringName = _combo_kinds[i] if i < _combo_kinds.size() else &""
		match kind:
			&"heavy":
				pip.custom_minimum_size = Vector2(38, 24)
				pip.add_theme_stylebox_override("panel", _pip_style(Color(UIStyle.GOLD, 0.32), UIStyle.GOLD))
				lbl.text = "H"
				lbl.add_theme_color_override("font_color", UIStyle.ATB_FULL)
			&"light":
				pip.custom_minimum_size = Vector2(26, 24)
				pip.add_theme_stylebox_override("panel", _pip_style(Color(UIStyle.CYAN, 0.22), UIStyle.CYAN))
				lbl.text = "L"
				lbl.add_theme_color_override("font_color", UIStyle.CYAN)
			_:
				pip.custom_minimum_size = Vector2(26, 24)
				pip.add_theme_stylebox_override("panel", _pip_style(UIStyle.GAUGE_BACK, UIStyle.CYAN_DIM))
				lbl.text = ""


## Current combo pips as a string ("LH", "" when none) — for tools/tests.
func get_combo_pips() -> String:
	var out := ""
	for k in _combo_kinds:
		out += "H" if k == &"heavy" else "L"
	return out


func is_combo_visible() -> bool:
	return _combo_box != null and _combo_box.visible and _combo_box.modulate.a > 0.01


## Active stance shown on the active row (&"" = none).
func get_stance_tag() -> String:
	for row in _rows:
		var t: Control = row.get("stance")
		if t != null and is_instance_valid(t) and t.visible:
			return (t.get_child(0) as Label).text
	return ""


## Build one party row. Active rows are larger and carry the team meter.
func _create_row(id: StringName, display_name: String, node: Node, active: bool) -> Dictionary:
	var width := ACTIVE_WIDTH if active else INACTIVE_WIDTH
	var panel := SlantPanel.new()
	panel.name = "Row_" + String(id)
	panel.selected = active
	panel.padding = 12.0 if active else 9.0
	panel.custom_minimum_size = Vector2(width, 0)
	if not active:
		panel.line_color = UIStyle.CYAN_DIM
		panel.fill_color = Color(UIStyle.GLASS, 0.62)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 5 if active else 3)
	panel.add_child(v)

	# Line 1: name, status tag, HP number
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var name_label := UIStyle.make_label(display_name.to_upper(),
		UIStyle.SIZE_L - 4 if active else UIStyle.SIZE_M - 2,
		UIStyle.TEXT if active else UIStyle.TEXT_DIM.lightened(0.25), true)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var tag := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.DANGER, true)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.visible = false
	top.add_child(tag)
	# v3 stance tag ("ARCANE"): cyan pill next to the name, hidden by default.
	var stance_tag := PanelContainer.new()
	stance_tag.name = "StanceTag"
	stance_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stance_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stance_tag.add_theme_stylebox_override("panel",
		UIStyle.pill(Color(UIStyle.CYAN, 0.18), UIStyle.CYAN, 10.0, 1.0))
	var stance_label := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.CYAN, true)
	stance_label.add_theme_font_size_override("font_size", UIStyle.SIZE_S)
	stance_tag.add_child(stance_label)
	stance_tag.visible = false
	top.add_child(stance_tag)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var hp_caption := UIStyle.make_label("HP", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	hp_caption.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(hp_caption)
	var hp_label := UIStyle.make_label("0 / 0", UIStyle.SIZE_M + 2 if active else UIStyle.SIZE_S + 2, UIStyle.TEXT)
	hp_label.add_theme_font_override("font", UIStyle.font_body_bold())
	hp_label.add_theme_font_size_override("font_size", UIStyle.SIZE_M + 2 if active else UIStyle.SIZE_S + 2)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(hp_label)

	# Line 2: HP gauge
	var hp := Gauge.new()
	hp.name = "HP"
	hp.custom_minimum_size = Vector2(0, 14 if active else 9)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.low_threshold = HP_DANGER_RATIO
	v.add_child(hp)

	# Line 3: MP gauge + number, ATB cells
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 8)
	v.add_child(bottom)
	var mp_caption := UIStyle.make_label("MP", UIStyle.SIZE_S, UIStyle.MP, true)
	bottom.add_child(mp_caption)
	var mp := Gauge.new()
	mp.name = "MP"
	mp.fill_color = UIStyle.MP
	mp.fill_color_end = UIStyle.MP.lightened(0.2)
	mp.custom_minimum_size = Vector2(110 if active else 80, 7 if active else 5)
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(mp)
	var mp_label := UIStyle.make_label("0", UIStyle.SIZE_S, UIStyle.MP.lightened(0.3))
	mp_label.add_theme_font_override("font", UIStyle.font_body_bold())
	mp_label.custom_minimum_size = Vector2(34, 0)
	bottom.add_child(mp_label)
	var spacer2 := Control.new()
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer2)
	var atb_caption := UIStyle.make_label("ATB", UIStyle.SIZE_S, UIStyle.GOLD, true)
	bottom.add_child(atb_caption)
	var atb := SegmentGauge.new()
	atb.name = "ATB"
	atb.segments = 2
	atb.per_segment = ATB_SEGMENT_COST
	atb.custom_minimum_size = Vector2(150 if active else 110, 10 if active else 7)
	atb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(atb)
	var atb_label := UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.GOLD, true)
	atb_label.custom_minimum_size = Vector2(16, 0)
	atb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(atb_label)

	# Team meter under the active row
	if active:
		var team := HBoxContainer.new()
		team.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team.add_theme_constant_override("separation", 8)
		v.add_child(team)
		var team_caption := UIStyle.make_label("TEAM", UIStyle.SIZE_S, UIStyle.STAGGER.lightened(0.15), true)
		team.add_child(team_caption)
		_team_meter_bar = Gauge.new()
		_team_meter_bar.name = "TEAM"
		_team_meter_bar.fill_color = UIStyle.GOLD.darkened(0.15)
		_team_meter_bar.fill_color_end = UIStyle.STAGGER
		_team_meter_bar.custom_minimum_size = Vector2(0, 5)
		_team_meter_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_team_meter_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		team.add_child(_team_meter_bar)
		_team_meter_label = UIStyle.make_label("0%", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
		_team_meter_label.custom_minimum_size = Vector2(44, 0)
		_team_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		team.add_child(_team_meter_label)

	var row := {
		"id": id, "node": node, "is_player": node != null and node == _player,
		"active": active, "root": panel, "name": name_label, "tag": tag,
		"hp": hp, "hp_label": hp_label, "mp": mp, "mp_label": mp_label,
		"atb": atb, "atb_label": atb_label, "downed": false, "danger": false,
		"stance": stance_tag,
	}
	hp.low_state_changed.connect(_on_row_low_state.bind(hp_label))
	return row


# --- Roster ---

func _find_party() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if _player and "party_system" in _player:
		_party_system = _player.party_system


## Rebuilds rows when the roster (count/active member) changes. Cheap to call.
func _sync_roster() -> void:
	_find_party()
	var sig := _roster_key()
	if sig == _roster_signature:
		return
	_roster_signature = sig
	_rebuild_rows()


func _roster_key() -> String:
	if _party_system == null or not is_instance_valid(_party_system) or not ("members" in _party_system):
		return "solo:%s" % str(_player != null)
	var parts: PackedStringArray = []
	for m in _party_system.members:
		parts.append("%s%s" % [m.get("id", &""), "*" if m.get("is_active", false) else ""])
	return ",".join(parts)


func _rebuild_rows() -> void:
	for row in _rows:
		var r: Control = row["root"]
		if is_instance_valid(r):
			if r.get_parent():
				r.get_parent().remove_child(r)
			r.queue_free()
	_rows.clear()
	_hp_bar = null
	_mp_bar = null
	_atb_bar = null
	_ally_hp_bar = null
	_ally_hp_label = null
	_team_meter_bar = null
	_team_meter_label = null

	var entries: Array = []  # [id, name, node, active]
	if _party_system and is_instance_valid(_party_system) and "members" in _party_system \
			and _party_system.members.size() > 0:
		for m in _party_system.members:
			var data: Resource = m.get("data")
			var nm := String(m.get("id", &"member")).capitalize()
			if data and "display_name" in data and data.display_name != "":
				nm = data.display_name
			entries.append([m.get("id", &"member"), nm, m.get("node"), m.get("is_active", false)])
	else:
		entries.append([&"hero", _default_player_name(), _player, true])

	var any_active := false
	for e in entries:
		any_active = any_active or e[3]
	if not any_active:
		entries[0][3] = true

	for e in entries:
		var row := _create_row(e[0], e[1], e[2], e[3])
		if row["active"]:
			_active_container.add_child(row["root"])
		else:
			_ally_bar_container.add_child(row["root"])
			if _ally_hp_bar == null:
				_ally_hp_bar = row["hp"]
				_ally_hp_label = row["hp_label"]
		# The player node's widgets receive the player_* signals.
		if row["is_player"] or (_player == null and row["active"]):
			row["is_player"] = true
			_hp_bar = row["hp"]
			_mp_bar = row["mp"]
			_atb_bar = row["atb"]
			_hp_label = row["hp_label"]
			_mp_label = row["mp_label"]
			_atb_label = row["atb_label"]
		_rows.append(row)
	_ally_bar_container.visible = _ally_bar_container.get_child_count() > 0

	# Seed values (instant) so rows don't animate from zero on rebuild.
	for row in _rows:
		if row["is_player"]:
			_apply_hp(row, _p_hp.x, _p_hp.y, true)
			_apply_mp(row, _p_mp.x, _p_mp.y, true)
			_apply_atb(row, _p_atb.x, _p_atb.y, true)
		else:
			_poll_row(row, true)
		if _party_system and _party_system.has_method("is_member_downed"):
			_set_row_downed(row, _party_system.is_member_downed(row["id"]))
	if _team_meter_bar:
		_team_meter_bar.set_values(_team.x, _team.y, true)
		_update_team_label()
	_apply_stance_tag()


func _default_player_name() -> String:
	var hero := load("res://resources/characters/hero.tres")
	if hero and "display_name" in hero and hero.display_name != "":
		return hero.display_name
	return "Hero"


func _find_row(member_id: StringName) -> Dictionary:
	for row in _rows:
		if row["id"] == member_id:
			return row
	return {}


# --- Row value helpers ---

func _apply_hp(row: Dictionary, current: float, maximum: float, instant: bool = false) -> void:
	var hp: Gauge = row["hp"]
	hp.set_values(current, maxf(maximum, 1.0), instant)
	var lbl: Label = row["hp_label"]
	lbl.text = "%d / %d" % [int(current), int(maximum)] if row["active"] else "%d" % int(current)
	_tint_hp_label(row, current / maxf(maximum, 1.0))


func _apply_mp(row: Dictionary, current: float, maximum: float, instant: bool = false) -> void:
	var mp: Gauge = row["mp"]
	mp.set_values(current, maxf(maximum, 1.0), instant)
	var lbl: Label = row["mp_label"]
	lbl.text = "%d" % int(current)


func _apply_atb(row: Dictionary, current: float, maximum: float, instant: bool = false) -> void:
	var atb: SegmentGauge = row["atb"]
	var cells := maxi(int(round(maximum / ATB_SEGMENT_COST)), 1)
	if atb.segments != cells:
		atb.segments = cells
	atb.set_value(current, instant)
	var lbl: Label = row["atb_label"]
	var full := int(current / ATB_SEGMENT_COST + 0.0001)
	lbl.text = str(full) if full > 0 else ""


func _tint_hp_label(row: Dictionary, ratio: float) -> void:
	var lbl: Label = row["hp_label"]
	if row.get("downed", false):
		lbl.add_theme_color_override("font_color", UIStyle.TEXT_DISABLED)
	elif ratio <= HP_DANGER_RATIO:
		lbl.add_theme_color_override("font_color", UIStyle.DANGER)
	elif ratio <= HP_CAUTION_RATIO:
		lbl.add_theme_color_override("font_color", UIStyle.GOLD.lightened(0.2))
	else:
		lbl.add_theme_color_override("font_color", UIStyle.TEXT)


## Low-HP state: number + bar edge go danger red (Gauge handles the bar), soft pulse.
func _on_row_low_state(is_low: bool, hp_label: Label) -> void:
	if not is_instance_valid(hp_label):
		return
	if is_low:
		UIStyle.pulse(hp_label, 0.6, 0.9)
	else:
		UIStyle.stop_pulse(hp_label)


## Pull values from a non-player member node (companion AI exposes plain properties).
func _poll_row(row: Dictionary, instant: bool = false) -> void:
	var node = row["node"]
	if node == null or not is_instance_valid(node):
		return
	if "current_hp" in node and "max_hp" in node:
		var hp: Gauge = row["hp"]
		if instant or not is_equal_approx(hp.value, node.current_hp) or not is_equal_approx(hp.max_value, node.max_hp):
			_apply_hp(row, node.current_hp, node.max_hp, instant)
	if "current_mp" in node and "max_mp" in node:
		var mp: Gauge = row["mp"]
		if instant or not is_equal_approx(mp.value, node.current_mp):
			_apply_mp(row, node.current_mp, node.max_mp, instant)
	if "current_atb" in node and "max_atb" in node:
		var atb: SegmentGauge = row["atb"]
		if instant or not is_equal_approx(atb.value, clampf(node.current_atb, 0.0, atb.get_max_value())):
			_apply_atb(row, node.current_atb, node.max_atb, instant)


func _set_row_downed(row: Dictionary, downed: bool) -> void:
	row["downed"] = downed
	var root: Control = row["root"]
	var tag: Label = row["tag"]
	tag.text = "DOWNED"
	tag.visible = downed
	root.modulate = Color(0.55, 0.58, 0.62, 0.85) if downed else Color.WHITE
	var hp: Gauge = row["hp"]
	_tint_hp_label(row, hp.get_target_ratio())


func _connect_signals() -> void:
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_mp_changed.connect(_on_mp_changed)
	Events.player_atb_changed.connect(_on_atb_changed)
	Events.ability_request_failed.connect(_on_ability_request_failed)
	Events.ability_cooldown_started.connect(_on_cooldown_started)
	Events.ability_cooldown_finished.connect(_on_cooldown_finished)
	Events.ability_cast_started.connect(_on_cast_started)
	Events.ability_cast_completed.connect(_on_cast_completed)
	Events.party_member_joined.connect(_on_party_member_joined)
	Events.party_member_downed.connect(_on_party_member_downed)
	Events.party_member_revived.connect(_on_party_member_revived)
	Events.party_member_switched.connect(_on_party_member_switched)
	Events.team_meter_changed.connect(_on_team_meter_changed)
	# v3 (Package U)
	Events.stance_changed.connect(_on_stance_changed)
	Events.combo_step.connect(_on_combo_step)
	Events.combo_finisher.connect(_on_combo_finisher)
	Events.combo_reset.connect(_on_combo_reset)


# --- Signal Handlers ---

func _player_row() -> Dictionary:
	for row in _rows:
		if row["is_player"]:
			return row
	return {}


func _on_hp_changed(current: float, maximum: float) -> void:
	_p_hp = Vector2(current, maximum)
	var row := _player_row()
	if not row.is_empty():
		_apply_hp(row, current, maximum)


func _on_mp_changed(current: float, maximum: float) -> void:
	_p_mp = Vector2(current, maximum)
	var row := _player_row()
	if not row.is_empty():
		_apply_mp(row, current, maximum)


func _on_atb_changed(current: float, maximum: float) -> void:
	_p_atb = Vector2(current, maximum)
	var row := _player_row()
	if not row.is_empty():
		_apply_atb(row, current, maximum)


func _on_ability_request_failed(reason: String, _ability_data: Resource) -> void:
	match reason:
		"mp":
			_mp_flash_tween = _flash_bar_insufficient(_mp_bar, _mp_flash_tween)
			_show_flash_text("Not enough MP!")
		"atb":
			_atb_flash_tween = _flash_bar_insufficient(_atb_bar, _atb_flash_tween)
			_show_flash_text("Not enough ATB!")
		"cooldown":
			_show_flash_text("Ability on cooldown!")
		"empty_slot":
			_show_flash_text("No ability equipped!")
		"no_target":
			_show_flash_text("No valid target!")
		"unavailable":
			_show_flash_text("Not available yet!")
		"out_of_range":
			_show_flash_text("Out of range!")
		"grounded_only":
			_show_flash_text("Grounded only!")
		"airborne_only":
			_show_flash_text("Airborne only!")
		_:
			_show_flash_text("Can't use that now!")


func _on_cooldown_started(ability_id: StringName, duration: float) -> void:
	var cd_label := Label.new()
	cd_label.name = "CD_" + String(ability_id)
	cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIStyle.style_label(cd_label, UIStyle.SIZE_S, UIStyle.GOLD, true, 3)
	cd_label.add_theme_font_size_override("font_size", 14)
	_cooldown_container.add_child(cd_label)

	# Update cooldown label each frame
	var start_time := Time.get_ticks_msec()
	var update_fn: Callable
	update_fn = func():
		if not is_instance_valid(cd_label):
			return
		var elapsed := (Time.get_ticks_msec() - start_time) / 1000.0
		var remaining := maxf(duration - elapsed, 0.0)
		if remaining <= 0.0:
			return
		cd_label.text = "%s  %.1fs" % [String(ability_id).capitalize().to_upper(), remaining]
	cd_label.set_meta("update_fn", update_fn)


func _on_cooldown_finished(ability_id: StringName) -> void:
	var cd_node := _cooldown_container.get_node_or_null("CD_" + String(ability_id))
	if cd_node:
		cd_node.queue_free()


func _on_cast_started(ability_data: Resource) -> void:
	if ability_data and ability_data is AbilityData:
		_show_flash_text(ability_data.display_name, UIStyle.GOLD)


func _on_cast_completed(_ability_data: Resource) -> void:
	pass


func _process(_delta: float) -> void:
	# Tick cooldown labels
	for child in _cooldown_container.get_children():
		if child.has_meta("update_fn"):
			child.get_meta("update_fn").call()
	# Roster changes (party set up after the HUD, joins, switches) — throttled.
	var now := Time.get_ticks_msec()
	if now - _last_roster_check >= ROSTER_CHECK_MSEC:
		_last_roster_check = now
		_sync_roster()
	# Companion values are plain properties (no per-member signals) — poll them.
	for row in _rows:
		if not row["is_player"]:
			_poll_row(row)


# --- Flash Effects ---

## Flash a bar red three times (unscaled time). Returns the tween.
func _flash_bar_insufficient(bar: Control, previous: Tween) -> Tween:
	if bar == null or not is_instance_valid(bar):
		return null
	if previous and previous.is_valid():
		previous.kill()
	bar.modulate = Color.WHITE
	var tween := UIStyle.ui_tween(bar)
	if tween == null:
		return null
	for i in 3:
		tween.tween_callback(func(): bar.modulate = FLASH_COLOR)
		tween.tween_interval(0.08)
		tween.tween_callback(func(): bar.modulate = Color.WHITE)
		tween.tween_interval(0.08)
	return tween


## Small toast above the party panel. Red for failures, gold for casts.
func _show_flash_text(text: String, color: Color = UIStyle.DANGER) -> void:
	_flash_label.text = text.to_upper()
	_flash_label.add_theme_color_override("font_color", color)
	_flash_panel.add_theme_stylebox_override("panel",
		UIStyle.pill(UIStyle.GLASS_DEEP, Color(color, 0.8), 16.0, 5.0))

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_panel.modulate.a = 1.0
	_flash_tween = UIStyle.ui_tween(_flash_panel)
	if _flash_tween == null:
		return
	_flash_tween.tween_interval(0.9)
	_flash_tween.tween_property(_flash_panel, "modulate:a", 0.0, 0.35)


# --- Party HUD ---

func _on_party_member_joined(_member_id: StringName) -> void:
	_ally_bar_container.visible = true
	_roster_signature = ""
	_sync_roster()


## v5: the new controlled member's row becomes the large active row (rebuild
## now, not on the throttled poll) and a toast names them.
func _on_party_member_switched(_old_id: StringName, new_id: StringName) -> void:
	_roster_signature = ""
	_sync_roster()
	var nm := _member_display_name(new_id)
	last_switch_toast = nm
	_show_flash_text(nm, UIStyle.CYAN)


## Text of the last party-switch toast (for headless checks).
var last_switch_toast: String = ""


func _member_display_name(member_id: StringName) -> String:
	if _party_system and is_instance_valid(_party_system) and "members" in _party_system:
		for m in _party_system.members:
			if m.get("id") == member_id:
				var data: Resource = m.get("data")
				if data and "display_name" in data and data.display_name != "":
					return data.display_name
	return String(member_id).capitalize()


func _on_party_member_downed(member_id: StringName) -> void:
	var row := _find_row(member_id)
	if row.is_empty():
		return
	_set_row_downed(row, true)
	if row["hp_label"] == _ally_hp_label and _ally_hp_label:
		_ally_hp_label.text = "0"


func _on_party_member_revived(member_id: StringName) -> void:
	var row := _find_row(member_id)
	if row.is_empty():
		return
	_set_row_downed(row, false)
	_poll_row(row)


func _on_team_meter_changed(current: float, maximum: float) -> void:
	_team = Vector2(current, maximum)
	if _team_meter_bar == null:
		return
	_team_meter_bar.set_values(current, maxf(maximum, 1.0))
	_update_team_label()


func _update_team_label() -> void:
	if _team_meter_label == null:
		return
	var maximum := maxf(_team.y, 1.0)
	_team_meter_label.text = "%d%%" % [int((_team.x / maximum) * 100.0)]
	# Glow when full
	if _team.x >= maximum:
		_team_meter_label.add_theme_color_override("font_color", UIStyle.ATB_FULL)
		if not _team_meter_bar.has_meta(&"_ui_pulse_tween"):
			UIStyle.pulse(_team_meter_bar, 0.4, 1.0)
	else:
		_team_meter_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
		UIStyle.stop_pulse(_team_meter_bar)


# --- v3: stance tag ---

func _on_stance_changed(member_id: StringName, stance: StringName) -> void:
	_stance_member = member_id
	_stance_id = stance
	_apply_stance_tag()


## Shows the stance tag on the active row only (the player-controlled member).
func _apply_stance_tag() -> void:
	var text := _stance_display_name()
	for row in _rows:
		var t: PanelContainer = row.get("stance")
		if t == null or not is_instance_valid(t):
			continue
		var show: bool = text != "" and bool(row["active"])
		var was := t.visible
		t.visible = show
		(t.get_child(0) as Label).text = text
		if show and not was:
			UIStyle.fade_slide_in(t, Vector2.ZERO)
			UIStyle.pulse(t, 0.3, 1.4)
		elif not show:
			UIStyle.stop_pulse(t)


func _stance_display_name() -> String:
	if _stance_id == &"":
		return ""
	if _player and is_instance_valid(_player):
		var st: Node = _player.get(&"stance")
		if st and st.has_method(&"get_display_name"):
			var nm: String = st.get_display_name()
			if nm != "":
				return nm.to_upper()
	return String(_stance_id).get_slice("_", 0).to_upper()


# --- v3: combo pips ---

func _on_combo_step(step: int, kind: StringName) -> void:
	if step <= 1:
		_combo_kinds.clear()
		_combo_finisher_label.text = ""
	while _combo_kinds.size() < step - 1:
		_combo_kinds.append(&"light")   # missed an earlier step: keep the slot filled
	if _combo_kinds.size() >= step:
		_combo_kinds.resize(step - 1)
	_combo_kinds.append(kind)
	_paint_combo_pips()
	_show_combo()


func _on_combo_finisher(kind: StringName, radius: float) -> void:
	var nm: String = _finisher_display_name(kind)
	_combo_finisher_label.text = nm
	var big := radius >= 3.0
	_combo_finisher_label.add_theme_color_override("font_color",
		UIStyle.ATB_FULL if big else (UIStyle.GOLD if radius > 0.0 else UIStyle.CYAN))
	_combo_finisher_label.add_theme_font_size_override("font_size",
		UIStyle.SIZE_L if big else UIStyle.SIZE_M)
	_show_combo()


func _finisher_display_name(kind: StringName) -> String:
	return FINISHER_NAMES.get(kind, String(kind).capitalize().to_upper())


func _on_combo_reset() -> void:
	if _combo_kinds.is_empty() and _combo_finisher_label.text == "":
		return
	# Keep the string readable briefly (longer after a finisher), then fade.
	var hold := COMBO_HOLD_SEC + (0.5 if _combo_finisher_label.text != "" else 0.0)
	_kill_combo_tween()
	_combo_tween = UIStyle.ui_tween(_combo_box)
	if _combo_tween == null:
		_clear_combo()
		return
	_combo_tween.tween_interval(hold)
	_combo_tween.tween_property(_combo_box, "modulate:a", 0.0, 0.25)
	_combo_tween.tween_callback(_clear_combo)


func _show_combo() -> void:
	_kill_combo_tween()
	_combo_box.visible = true
	_combo_box.modulate.a = 1.0


func _clear_combo() -> void:
	_combo_kinds.clear()
	_combo_finisher_label.text = ""
	_paint_combo_pips()
	_combo_box.visible = false
	_combo_box.modulate.a = 0.0


func _kill_combo_tween() -> void:
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = null


func _update_ally_hp(current: float, maximum: float) -> void:
	if _ally_hp_bar == null:
		return
	_ally_hp_bar.set_values(current, maxf(maximum, 1.0))
	_ally_hp_label.text = "%d" % int(current)
