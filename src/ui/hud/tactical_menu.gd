## Tactical mode overlay: blue screen tint + FF7R-style command menu.
## Three vertical phases inside one panel: Category → Ability → Target.
## Driven entirely by signals from TacticalIdleState.
extends CanvasLayer

# --- Colors ---
const TINT_COLOR := Color(0.05, 0.1, 0.35, 0.3)
const BG_COLOR := Color(0.02, 0.04, 0.12, 0.92)
const BORDER_COLOR := Color(0.3, 0.5, 0.9, 0.6)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const TEXT_DIM := Color(0.35, 0.4, 0.5)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const COST_ATB_COLOR := Color(0.9, 0.7, 0.1)
const COST_MP_COLOR := Color(0.3, 0.5, 1.0)
const HEADER_COLOR := Color(0.5, 0.7, 1.0)
const UNAVAILABLE_COLOR := Color(0.5, 0.3, 0.3)
const TARGET_COLOR := Color(1.0, 0.85, 0.3)

# --- References ---
var _tint_rect: ColorRect
var _menu_panel: PanelContainer
var _item_container: VBoxContainer
var _header_label: Label
var _hint_label: Label
var _item_rows: Array[Control] = []
var _selected_index: int = 0
var _visible: bool = false
var _selected_category: int = 0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	_hide_menu()


func _build_ui() -> void:
	# --- Full screen tint ---
	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = TINT_COLOR
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint_rect)

	# --- Root container ---
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Command menu panel (right side of screen) ---
	_menu_panel = PanelContainer.new()
	_menu_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_menu_panel.position = Vector2(-380, -150)
	_menu_panel.custom_minimum_size = Vector2(360, 300)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.border_color = BORDER_COLOR
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_menu_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_menu_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_panel.add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = "COMMANDS"
	_header_label.add_theme_font_size_override("font_size", 15)
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_header_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Item container (categories, abilities, or target hint)
	_item_container = VBoxContainer.new()
	_item_container.add_theme_constant_override("separation", 2)
	_item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_item_container)

	# Control hint at bottom
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", TEXT_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_hint_label)


func _connect_signals() -> void:
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)
	Events.tactical_phase_changed.connect(_on_phase_changed)
	Events.tactical_slot_changed.connect(_on_slot_changed)
	Events.tactical_category_changed.connect(_on_category_changed)
	Events.tactical_target_info.connect(_on_target_info)


func _on_tactical_entered() -> void:
	_show_menu()


func _on_tactical_exited() -> void:
	_hide_menu()


func _on_phase_changed(phase: int) -> void:
	if not _visible:
		return
	_selected_index = 0
	match phase:
		0:  # CATEGORY_SELECT
			_refresh_categories()
		1:  # ABILITY_SELECT
			_refresh_abilities()
		2:  # TARGET_SELECT
			_show_target_hint()


func _on_slot_changed(index: int) -> void:
	if not _visible:
		return
	_selected_index = clampi(index, 0, maxi(_item_rows.size() - 1, 0))
	_update_selection()


func _on_category_changed(category: int) -> void:
	_selected_category = category


func _on_target_info(ability_name: String, target_names: PackedStringArray, selected_index: int) -> void:
	if not _visible:
		return
	_show_target_list(ability_name, target_names, selected_index)


func _show_menu() -> void:
	_visible = true
	_tint_rect.visible = true
	_menu_panel.visible = true
	_selected_index = 0
	_refresh_categories()


func _hide_menu() -> void:
	_visible = false
	_tint_rect.visible = false
	_menu_panel.visible = false


# ── Phase 1: Category List ───────────────────────────────────

func _refresh_categories() -> void:
	_header_label.text = "COMMANDS"
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_hint_label.text = "[A] Select    [B] Close"
	_clear_items()

	for cat_name in ["Abilities", "Magic", "Items"]:
		var row := _create_selectable_row(cat_name, TEXT_COLOR, 16)
		_item_container.add_child(row)
		_item_rows.append(row)

	_update_selection()


# ── Phase 2: Ability List ─────────────────────────────────────

func _refresh_abilities() -> void:
	var cat_names := ["ABILITIES", "MAGIC", "ITEMS"]
	_header_label.text = cat_names[_selected_category]
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_hint_label.text = "[A] Select    [B] Back"
	_clear_items()

	if _selected_category == 2:  # Items
		_add_empty_row("No items available")
		return

	var player_node: CharacterBody3D = _get_player()
	if player_node == null:
		return

	var abilities: Array = player_node.ability_system.equipped_abilities
	if abilities.is_empty():
		_add_empty_row("No abilities equipped")
		return

	for i in abilities.size():
		var ability: AbilityData = abilities[i]
		if ability == null:
			continue
		var row := _create_ability_row(player_node, ability)
		_item_container.add_child(row)
		_item_rows.append(row)

	_selected_index = 0
	_update_selection()


# ── Phase 3: Target Selection ────────────────────────────────

func _show_target_hint() -> void:
	# Fallback if target_info signal hasn't arrived yet
	_header_label.text = "SELECT TARGET"
	_header_label.add_theme_color_override("font_color", TARGET_COLOR)
	_hint_label.text = "[Left/Right] Switch    [A] Confirm    [B] Back"
	for row in _item_rows:
		row.modulate = Color(0.4, 0.4, 0.4)


func _show_target_list(ability_name: String, target_names: PackedStringArray, selected_index: int) -> void:
	_header_label.text = "SELECT TARGET — %s" % ability_name
	_header_label.add_theme_color_override("font_color", TARGET_COLOR)
	_hint_label.text = "[Left/Right] Switch    [A] Confirm    [B] Back"
	_clear_items()

	for i in target_names.size():
		var row := _create_selectable_row(target_names[i], TEXT_COLOR, 15)
		_item_container.add_child(row)
		_item_rows.append(row)

	_selected_index = clampi(selected_index, 0, maxi(_item_rows.size() - 1, 0))
	_update_selection()


# ── Row Builders ──────────────────────────────────────────────

func _create_selectable_row(text: String, color: Color, font_size: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(330, 44)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	var arrow := Label.new()
	arrow.text = "> "
	arrow.add_theme_font_size_override("font_size", font_size)
	arrow.add_theme_color_override("font_color", color)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.visible = false
	arrow.name = "Arrow"
	hbox.add_child(arrow)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)

	return row


func _create_ability_row(player_node: CharacterBody3D, ability: AbilityData) -> PanelContainer:
	var can_use: bool = player_node.ability_system.can_use_ability(ability)
	var fail_reason: String = "" if can_use else player_node.ability_system.get_fail_reason(ability)
	var on_cooldown: bool = player_node.ability_system.is_on_cooldown(ability.ability_id)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(330, 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	# Selection arrow
	var arrow := Label.new()
	arrow.text = "> "
	arrow.add_theme_font_size_override("font_size", 14)
	arrow.add_theme_color_override("font_color", TEXT_COLOR)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.visible = false
	arrow.name = "Arrow"
	hbox.add_child(arrow)

	# Ability name
	var name_label := Label.new()
	name_label.text = ability.display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", TEXT_COLOR if can_use else UNAVAILABLE_COLOR)
	hbox.add_child(name_label)

	# Cooldown indicator
	if on_cooldown:
		var cd_remaining: float = player_node.ability_system.get_cooldown_remaining(ability.ability_id)
		var cd_label := Label.new()
		cd_label.text = "%.1fs" % cd_remaining
		cd_label.add_theme_font_size_override("font_size", 11)
		cd_label.add_theme_color_override("font_color", UNAVAILABLE_COLOR)
		cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(cd_label)

	# ATB cost
	var atb_label := Label.new()
	atb_label.text = "ATB %d" % int(ability.atb_cost)
	atb_label.add_theme_font_size_override("font_size", 12)
	atb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if can_use or fail_reason != "atb":
		atb_label.add_theme_color_override("font_color", COST_ATB_COLOR)
	else:
		atb_label.add_theme_color_override("font_color", UNAVAILABLE_COLOR)
	hbox.add_child(atb_label)

	# MP cost
	var mp_label := Label.new()
	mp_label.text = "MP %d" % int(ability.mp_cost)
	mp_label.add_theme_font_size_override("font_size", 12)
	mp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if can_use or fail_reason != "mp":
		mp_label.add_theme_color_override("font_color", COST_MP_COLOR)
	else:
		mp_label.add_theme_color_override("font_color", UNAVAILABLE_COLOR)
	hbox.add_child(mp_label)

	row.set_meta("ability_data", ability)
	row.set_meta("can_use", can_use)

	return row


# ── Shared ────────────────────────────────────────────────────

func _clear_items() -> void:
	for child in _item_container.get_children():
		child.queue_free()
	_item_rows.clear()


func _add_empty_row(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_container.add_child(lbl)


func _update_selection() -> void:
	for i in _item_rows.size():
		var row: PanelContainer = _item_rows[i] as PanelContainer
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat

		# Show/hide selection arrow
		var arrow: Label = row.find_child("Arrow", false) as Label
		if arrow:
			arrow.visible = (i == _selected_index)

		# Highlight background
		if i == _selected_index:
			style.bg_color = HIGHLIGHT_BG
		else:
			style.bg_color = Color(0, 0, 0, 0)


func _get_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
