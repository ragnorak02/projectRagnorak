## Tactical mode overlay: blue screen tint + FF7R-style ATB command menu.
## Builds UI programmatically. Shown/hidden via Events signals.
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

# --- References ---
var _tint_rect: ColorRect
var _menu_panel: PanelContainer
var _item_container: VBoxContainer
var _header_label: Label
var _item_rows: Array[Control] = []
var _selected_index: int = 0
var _visible: bool = false

# Category system
enum Category { ABILITIES, MAGIC, ITEMS }
var _current_category: Category = Category.ABILITIES
var _category_labels: Array[Label] = []


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

	# --- Category tabs (top-right area) ---
	var cat_container := HBoxContainer.new()
	cat_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cat_container.position = Vector2(-400, 20)
	cat_container.size = Vector2(380, 30)
	cat_container.add_theme_constant_override("separation", 20)
	cat_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cat_container)

	for cat_name in ["ABILITIES", "MAGIC", "ITEMS"]:
		var lbl := Label.new()
		lbl.text = cat_name
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", TEXT_DIM)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_container.add_child(lbl)
		_category_labels.append(lbl)

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

	# Item container
	_item_container = VBoxContainer.new()
	_item_container.add_theme_constant_override("separation", 2)
	_item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_item_container)

	# ATB reminder at bottom
	var atb_hint := Label.new()
	atb_hint.text = "[X/LMB] Execute    [B/Shift] Cancel"
	atb_hint.add_theme_font_size_override("font_size", 11)
	atb_hint.add_theme_color_override("font_color", TEXT_DIM)
	atb_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	atb_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(atb_hint)


func _connect_signals() -> void:
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)


func _on_tactical_entered() -> void:
	_show_menu()


func _on_tactical_exited() -> void:
	_hide_menu()


func _show_menu() -> void:
	_visible = true
	_tint_rect.visible = true
	_menu_panel.visible = true
	_selected_index = 0
	_current_category = Category.ABILITIES
	for lbl in _category_labels:
		lbl.visible = true
	_refresh_items()
	_update_category_tabs()


func _hide_menu() -> void:
	_visible = false
	_tint_rect.visible = false
	_menu_panel.visible = false
	for lbl in _category_labels:
		lbl.visible = false


func _refresh_items() -> void:
	# Clear old rows
	for child in _item_container.get_children():
		child.queue_free()
	_item_rows.clear()

	# Find the player
	var player: CharacterBody3D = _get_player()
	if player == null:
		return

	match _current_category:
		Category.ABILITIES, Category.MAGIC:
			var abilities: Array = player.ability_system.equipped_abilities
			if abilities.is_empty():
				_add_empty_row("No abilities equipped")
				return

			for i in abilities.size():
				var ability: AbilityData = abilities[i]
				if ability == null:
					continue
				var row := _create_ability_row(player, ability, i)
				_item_container.add_child(row)
				_item_rows.append(row)

		Category.ITEMS:
			_add_empty_row("No items available")

	_selected_index = clampi(_selected_index, 0, maxi(_item_rows.size() - 1, 0))
	_update_selection()


func _create_ability_row(player: CharacterBody3D, ability: AbilityData, _index: int) -> PanelContainer:
	var can_use: bool = player.ability_system.can_use_ability(ability)
	var fail_reason: String = "" if can_use else player.ability_system.get_fail_reason(ability)
	var on_cooldown: bool = player.ability_system.is_on_cooldown(ability.ability_id)

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(330, 40)
	row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Row background (transparent by default, highlighted when selected)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	row_style.corner_radius_top_left = 3
	row_style.corner_radius_top_right = 3
	row_style.corner_radius_bottom_left = 3
	row_style.corner_radius_bottom_right = 3
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.add_child(hbox)

	# Ability name
	var name_label := Label.new()
	name_label.text = ability.display_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if can_use:
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
	else:
		name_label.add_theme_color_override("font_color", UNAVAILABLE_COLOR)
	hbox.add_child(name_label)

	# Cooldown indicator
	if on_cooldown:
		var cd_remaining: float = player.ability_system.get_cooldown_remaining(ability.ability_id)
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

	# Store ability data on the row for selection
	row_panel.set_meta("ability_data", ability)
	row_panel.set_meta("can_use", can_use)

	return row_panel


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
		if i == _selected_index:
			style.bg_color = HIGHLIGHT_BG
		else:
			style.bg_color = Color(0, 0, 0, 0)


func _update_category_tabs() -> void:
	for i in _category_labels.size():
		if i == int(_current_category):
			_category_labels[i].add_theme_color_override("font_color", HEADER_COLOR)
		else:
			_category_labels[i].add_theme_color_override("font_color", TEXT_DIM)


func _get_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
