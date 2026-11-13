## Tactical mode overlay: cool screen tint + Lumina Frost command menu.
## Three phases inside one bottom-left panel: Category → Ability → Target,
## plus a bottom description strip for the highlighted command.
## Driven entirely by signals from TacticalIdleState (behaviour frozen — this
## script only listens; it never mutates combat state or reads input).
## All tweens run in unscaled time (UIStyle.ui_tween) because tactical = 0.1x.
## v5 BB: reads the Command Menu context the state leaves on the AbilitySystem
## (menu_airborne, menu_ability) and its list helpers (get_menu_slots,
## get_enemy_candidates, is_in_range) so rows always match the state's rows.
##  - airborne: caption "AERIAL · ABILITIES", ground-only rows grey "Grounded only"
##  - target step: enemies beyond the selected ability's range are darkened
##    (TEXT_DISABLED, "Out of range" tag) but still listed.
extends CanvasLayer

## Mirrors TacticalIdleState.Phase / Category (signal payload ints).
enum Phase { CATEGORY_SELECT, ABILITY_SELECT, TARGET_SELECT }
enum Category { ABILITIES, MAGIC, ITEMS }

const CATEGORY_NAMES := ["Abilities", "Magic", "Items"]
const CATEGORY_HEADERS := ["ABILITIES", "MAGIC", "ITEMS"]
const CATEGORY_DESCRIPTIONS := [
	"Combat techniques. Costs ATB.",
	"Spells woven from Lumina. Costs ATB and MP.",
	"Consumables from the inventory.",
]

# --- Layout (1920x1080 reference; anchored bottom-left) ---
const MARGIN_LEFT := 48.0
const MARGIN_BOTTOM := 28.0
const PANEL_WIDTH := 470.0
const DESC_WIDTH := 860.0
const DESC_HEIGHT := 50.0
const GAP := 12.0
const ATB_PER_SEGMENT := 50.0
const MAX_VISIBLE_ROWS := 6       # longer lists scroll with the cursor

## v4 X: last row of offensive target lists (must match TacticalIdleState).
const FIRE_FORWARD_LABEL := "Fire Forward"
const OUT_OF_RANGE_LABEL := "Out of range"
const GROUNDED_ONLY_LABEL := "Grounded only"
const TargetBarScript := preload("res://src/ui/hud/target_bar.gd")

# --- Colors ---
const TINT_COLOR := Color(0.02, 0.08, 0.16, 0.18)
const TARGET_COLOR := UIStyle.GOLD

# --- References ---
var _tint_rect: ColorRect
var _menu_panel: Control          # full-rect slide host for the command panel
var _desc_root: Control           # full-rect slide host for the description strip
var _header_tab: HeaderTab
var _tab_labels: Array[Control] = []
var _tab_row: HBoxContainer
var _item_container: VBoxContainer
var _header_label: Label          # list caption ("ABILITIES", "SELECT TARGET — Fire Bolt")
var _hint_label: Label            # footer caption (navigation hint text)
var _hint_box: HBoxContainer      # footer GlyphHints
var _desc_label: Label
var _item_rows: Array[Control] = []
var _selected_index: int = 0
var _visible: bool = false
var _selected_category: int = Category.ABILITIES
var _phase: int = Phase.CATEGORY_SELECT
var _scroll_start: int = 0
var _list_caption: String = ""


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_signals()
	_hide_menu(true)


func _build_ui() -> void:
	# --- Full screen tint (light; L's tactical_overlay adds the heavy grade) ---
	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = TINT_COLOR
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint_rect)

	# --- Command panel host (full rect so the slide "home" is always 0,0) ---
	_menu_panel = Control.new()
	_menu_panel.name = "CommandMenu"
	_menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = MARGIN_LEFT
	column.offset_right = MARGIN_LEFT + PANEL_WIDTH
	column.offset_bottom = -(MARGIN_BOTTOM + DESC_HEIGHT + GAP)
	column.offset_top = column.offset_bottom
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.custom_minimum_size.x = PANEL_WIDTH
	_menu_panel.add_child(column)

	# Title tab: "COMMAND  <active character>"
	_header_tab = HeaderTab.new().setup("Command", _get_character_name())
	_header_tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_header_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_header_tab)

	var panel := SlantPanel.new()
	panel.name = "ListPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Category tabs across the top (highlight only — selection is the state's)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override(&"separation", 6)
	_tab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tab_row)
	for cat_name in CATEGORY_NAMES:
		var tab := PanelContainer.new()
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_label := UIStyle.make_label(String(cat_name).to_upper(), UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
		tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(tab_label)
		_tab_row.add_child(tab)
		_tab_labels.append(tab)

	# List caption
	_header_label = UIStyle.make_label("SELECT", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_header_label)

	# Item container (categories, abilities, or targets)
	_item_container = VBoxContainer.new()
	_item_container.add_theme_constant_override(&"separation", 4)
	_item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_item_container)

	# Footer: glyph hints + caption
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 14)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(footer)
	_hint_box = HBoxContainer.new()
	_hint_box.add_theme_constant_override(&"separation", 14)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_hint_box)
	_hint_label = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT_DIM)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.visible = false
	footer.add_child(_hint_label)

	# --- Description strip (bottom, left of the party panel) ---
	_desc_root = Control.new()
	_desc_root.name = "DescriptionStrip"
	_desc_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desc_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_root)

	var desc_panel := PanelContainer.new()
	desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_panel.add_theme_stylebox_override(&"panel", UIStyle.glass_panel(10))
	desc_panel.anchor_left = 0.0
	desc_panel.anchor_right = 0.0
	desc_panel.anchor_top = 1.0
	desc_panel.anchor_bottom = 1.0
	desc_panel.offset_left = MARGIN_LEFT
	desc_panel.offset_right = MARGIN_LEFT + DESC_WIDTH
	desc_panel.offset_bottom = -MARGIN_BOTTOM
	desc_panel.offset_top = -(MARGIN_BOTTOM + DESC_HEIGHT)
	_desc_root.add_child(desc_panel)

	_desc_label = UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.TEXT)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_panel.add_child(_desc_label)


func _connect_signals() -> void:
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)
	Events.tactical_phase_changed.connect(_on_phase_changed)
	Events.tactical_slot_changed.connect(_on_slot_changed)
	Events.tactical_category_changed.connect(_on_category_changed)
	Events.tactical_target_info.connect(_on_target_info)
	Events.player_atb_changed.connect(_on_resource_changed)
	Events.player_mp_changed.connect(_on_resource_changed)


func _on_tactical_entered() -> void:
	_show_menu()


func _on_tactical_exited() -> void:
	_hide_menu()


func _on_phase_changed(phase: int) -> void:
	if not _visible:
		return
	_phase = phase
	_selected_index = 0
	match phase:
		Phase.CATEGORY_SELECT:
			_refresh_categories()
		Phase.ABILITY_SELECT:
			_refresh_abilities()
		Phase.TARGET_SELECT:
			_show_target_hint()


func _on_slot_changed(index: int) -> void:
	if not _visible:
		return
	_selected_index = clampi(index, 0, maxi(_item_rows.size() - 1, 0))
	_update_selection()


func _on_category_changed(category: int) -> void:
	_selected_category = clampi(category, Category.ABILITIES, Category.ITEMS)
	_update_tabs()


func _on_target_info(ability_name: String, target_names: PackedStringArray, selected_index: int) -> void:
	if not _visible:
		return
	_show_target_list(ability_name, target_names, selected_index)


## ATB/MP ticks during tactical (0.1x): re-grey ability rows in place.
func _on_resource_changed(_current: float, _maximum: float) -> void:
	if not _visible or _phase != Phase.ABILITY_SELECT:
		return
	var player_node: CharacterBody3D = _get_player()
	if player_node == null:
		return
	for row in _item_rows:
		if row.has_meta("ability_data"):
			_apply_ability_state(row, player_node, row.get_meta("ability_data"))
	_update_description()


func _show_menu() -> void:
	_visible = true
	_phase = Phase.CATEGORY_SELECT
	_selected_index = 0
	_header_tab.subtitle = _get_character_name()
	_refresh_categories()
	UIStyle.fade_slide_in(_tint_rect, Vector2.ZERO)
	UIStyle.fade_slide_in(_menu_panel, Vector2.LEFT)
	UIStyle.fade_slide_in(_desc_root, Vector2.DOWN)


func _hide_menu(instant: bool = false) -> void:
	_visible = false
	if instant or not is_inside_tree():
		_tint_rect.visible = false
		_menu_panel.visible = false
		_desc_root.visible = false
		return
	UIStyle.fade_out(_tint_rect)
	UIStyle.fade_out(_menu_panel, UIStyle.ANIM_TIME, true, Vector2.LEFT)
	UIStyle.fade_out(_desc_root, UIStyle.ANIM_TIME, true, Vector2.DOWN)


# ── Phase 1: Category List ───────────────────────────────────

func _refresh_categories() -> void:
	_header_tab.title = "Command"
	_header_tab.title_color = UIStyle.GOLD
	_set_caption("SELECT CATEGORY")
	_set_hints([[&"ui_accept", "Select"], [&"ui_cancel", "Close"]], "")
	_clear_items()

	var ability_count := _get_ability_count()
	for i in CATEGORY_NAMES.size():
		var row := _create_selectable_row(CATEGORY_NAMES[i])
		row.description = CATEGORY_DESCRIPTIONS[i]
		row.right_text = "—" if i == Category.ITEMS else str(ability_count)
		_item_container.add_child(row)
		_item_rows.append(row)

	_update_selection()


# ── Phase 2: Ability List ─────────────────────────────────────

func _refresh_abilities() -> void:
	_header_tab.title = "Command"
	_header_tab.title_color = UIStyle.GOLD
	var airborne := _is_airborne_menu()
	_set_caption(("AERIAL · " if airborne else "") + String(CATEGORY_HEADERS[_selected_category]))
	_set_hints([[&"ui_accept", "Select"], [&"ui_cancel", "Back"]], "")
	_clear_items()

	if _selected_category == Category.ITEMS:
		_add_empty_row("No items available")
		_set_description("Items are not usable in battle yet.", UIStyle.TEXT_DIM)
		_update_tabs()
		return

	var player_node: CharacterBody3D = _get_player()
	if player_node == null:
		return

	var abilities: Array = _menu_abilities(player_node)
	if abilities.is_empty():
		_add_empty_row("No abilities equipped")
		_set_description("Equip abilities to use them here.", UIStyle.TEXT_DIM)
		_update_tabs()
		return

	for ability in abilities:
		var row := _create_ability_row(player_node, ability)
		_item_container.add_child(row)
		_item_rows.append(row)

	_selected_index = 0
	_update_selection()


# ── Phase 3: Target Selection ────────────────────────────────

## Shows the inputs TacticalIdleState actually cycles targets on:
## target_switch_left/right (D-Left/D-Right, [ / ]) — up/down and move also work.
## v4 X: offensive lists add "Y Fire Forward" (interact = Y / E):
## `Switch · A Confirm · Y Fire Forward · B Back`.
func _target_hints(with_forward: bool) -> void:
	var hints: Array = [[&"target_switch_left", ""], [&"target_switch_right", "Switch"],
		[&"ui_accept", "Confirm"]]
	if with_forward:
		hints.append([&"interact", FIRE_FORWARD_LABEL])
	hints.append([&"ui_cancel", "Back"])
	_set_hints(hints, "")


func _show_target_hint() -> void:
	# Fallback if target_info signal hasn't arrived yet
	_header_tab.title = "Target"
	_header_tab.title_color = TARGET_COLOR
	_set_caption("SELECT TARGET")
	_target_hints(false)
	for row in _item_rows:
		row.modulate = Color(0.4, 0.4, 0.4)


func _show_target_list(ability_name: String, target_names: PackedStringArray, selected_index: int) -> void:
	_header_tab.title = "Target"
	_header_tab.title_color = TARGET_COLOR
	_set_caption("SELECT TARGET — %s" % ability_name)
	_clear_items()

	# v4 X: the state appends "Fire Forward" as the last row of offensive lists.
	var names := PackedStringArray(target_names)
	var with_forward := names.size() > 0 and names[names.size() - 1] == FIRE_FORWARD_LABEL \
		and not names.has("Self")
	if with_forward:
		names.remove_at(names.size() - 1)
	_target_hints(with_forward)
	if with_forward and names.is_empty():
		# Empty-enemy layout: say why, then the single pre-selected row.
		_add_empty_row("No targets in range")

	var nodes := _resolve_target_nodes(names)
	for i in names.size():
		var target: Node = nodes[i] if i < nodes.size() else null
		var shown := ""
		if target and target.is_in_group(&"enemies"):
			# Same label as the in-world target bar ("Reactor Sentry B", by
			# "enemies" group order), so a row and its reticle always agree even
			# though rows are sorted nearest-first.
			shown = TargetBarScript.disambiguated_name(target)
		else:
			shown = _display_target_name(names[i], target, i)
			# Disambiguate identical names ("Reactor Sentry A", "Reactor Sentry B").
			if names.count(names[i]) > 1 and not shown.begins_with("Enemy "):
				var dup_index := 0
				for j in i:
					if names[j] == names[i]:
						dup_index += 1
				shown += " " + (String.chr(65 + dup_index) if dup_index < 26 else str(dup_index + 1))
		var row := _create_selectable_row(shown)
		var hp_text := _hp_percent_text(target)
		row.right_text = hp_text
		row.description = "%s  ›  %s%s" % [ability_name, shown,
			("   HP " + hp_text) if hp_text != "" else ""]
		# v5 BB1: beyond the selected ability's range -> darkened, can't confirm.
		if target and not _target_in_range(target):
			row.unavailable = true
			row.unavailable_reason = OUT_OF_RANGE_LABEL
			row.right_text = OUT_OF_RANGE_LABEL
			row.set_meta("out_of_range", true)
		_item_container.add_child(row)
		_item_rows.append(row)

	if with_forward:
		var fwd := _create_selectable_row(FIRE_FORWARD_LABEL)
		fwd.right_text = "Camera aim"
		fwd.description = "%s  ›  Fire forward along the camera (no target)" % ability_name
		fwd.set_meta("fire_forward", true)
		_item_container.add_child(fwd)
		_item_rows.append(fwd)

	_selected_index = clampi(selected_index, 0, maxi(_item_rows.size() - 1, 0))
	_update_selection()


## Rebuilds the candidate order TacticalIdleState uses (read-only: live enemies,
## nearest-first) so each name row can show its HP %. Returns [] when the order
## can't be matched safely.
func _resolve_target_nodes(target_names: PackedStringArray) -> Array:
	var player_node: CharacterBody3D = _get_player()
	if player_node == null:
		return []
	if target_names.has("Self"):
		var allies: Array = [player_node]
		var party = player_node.party_system
		if party and party.has_method("get_companion"):
			var companion: Node3D = party.get_companion()
			if companion and is_instance_valid(companion):
				allies.append(companion)
		return allies if allies.size() == target_names.size() else []
	var abil = player_node.ability_system
	if abil and abil.has_method(&"get_enemy_candidates"):
		# v5 BB1: same max-range, nearest-first list as the state.
		var cands: Array = abil.get_enemy_candidates()
		return cands if cands.size() == target_names.size() else []
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if is_instance_valid(enemy) and enemy is Node3D:
			if "_is_dead" in enemy and enemy._is_dead:
				continue
			if not enemy.is_inside_tree():
				continue
			enemies.append(enemy)
	var origin: Vector3 = player_node.global_position
	enemies.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var da := origin.distance_squared_to(a.global_position)
		var db := origin.distance_squared_to(b.global_position)
		if is_equal_approx(da, db):
			return a.get_instance_id() < b.get_instance_id()
		return da < db)
	return enemies if enemies.size() == target_names.size() else []


## Display-only: auto-generated node names ("@CharacterBody3D@820") read as
## "Enemy A", "Enemy B"... The state's names/indices are left untouched.
func _display_target_name(raw: String, target: Node, index: int) -> String:
	if target and is_instance_valid(target) and "display_name" in target 			and String(target.display_name) != "":
		return target.display_name
	if raw.begins_with("@") or raw == "Enemy" or raw == "":
		var letter := String.chr(65 + index) if index < 26 else str(index + 1)
		return "Enemy %s" % letter
	return raw


func _hp_percent_text(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return ""
	if not ("current_hp" in target and "max_hp" in target):
		return ""
	var mx: float = target.max_hp
	if mx <= 0.0:
		return ""
	return "%d%%" % int(round(clampf(target.current_hp / mx, 0.0, 1.0) * 100.0))


# ── Row Builders ──────────────────────────────────────────────

func _create_selectable_row(text: String) -> MenuRow:
	var row := MenuRow.new().setup(text)
	row.focus_mode = Control.FOCUS_NONE   # cursor-driven; never steals input
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.row_font_size = UIStyle.SIZE_M
	row.custom_minimum_size = Vector2(0, 42)
	return row


func _create_ability_row(player_node: CharacterBody3D, ability: AbilityData) -> MenuRow:
	var row := _create_selectable_row(ability.display_name)
	row.atb_cost = maxi(1, ceili(ability.atb_cost / ATB_PER_SEGMENT)) if ability.atb_cost > 0.0 else 0
	row.mp_cost = int(ability.mp_cost) if ability.mp_cost > 0.0 else -1
	row.description = ability.description if ability.description != "" else _fallback_description(ability)
	row.set_meta("ability_data", ability)
	_apply_ability_state(row, player_node, ability)
	return row


## Greys the row and sets the short reason shown on the description line.
func _apply_ability_state(row: Control, player_node: CharacterBody3D, ability: AbilityData) -> void:
	# v5 BB6: aerial list — ground-only commands grey out first.
	var abil = player_node.ability_system
	if abil.has_method(&"get_air_block_reason") \
			and abil.get_air_block_reason(ability, _is_airborne_menu()) == "grounded_only":
		row.right_text = GROUNDED_ONLY_LABEL
		row.unavailable = true
		row.unavailable_reason = GROUNDED_ONLY_LABEL
		row.set_meta("can_use", false)
		return
	var can_use: bool = player_node.ability_system.can_use_ability(ability)
	var fail_reason: String = "" if can_use else player_node.ability_system.get_fail_reason(ability)
	var on_cooldown: bool = player_node.ability_system.is_on_cooldown(ability.ability_id)
	var reason := ""
	match fail_reason:
		"atb":
			reason = "Not enough ATB"
		"mp":
			reason = "Not enough MP"
		"cooldown":
			reason = "Recharging"
	if on_cooldown:
		var cd_remaining: float = player_node.ability_system.get_cooldown_remaining(ability.ability_id)
		row.right_text = "%.1fs" % cd_remaining
		reason = "Recharging — %.1fs" % cd_remaining
	else:
		row.right_text = ""
	row.unavailable = not can_use
	row.unavailable_reason = reason
	row.set_meta("can_use", can_use)


func _fallback_description(ability: AbilityData) -> String:
	var type_names := ["Melee", "Projectile", "Area", "Movement", "Defense", "Heal"]
	var type_name: String = type_names[ability.ability_type] if ability.ability_type < type_names.size() else "Ability"
	return "%s — %d ATB, %d MP" % [type_name, int(ability.atb_cost), int(ability.mp_cost)]


# ── Shared ────────────────────────────────────────────────────

func _clear_items() -> void:
	for child in _item_container.get_children():
		_item_container.remove_child(child)
		child.queue_free()
	_item_rows.clear()
	_scroll_start = 0


func _add_empty_row(text: String) -> void:
	var lbl := UIStyle.make_label(text, UIStyle.SIZE_M, UIStyle.TEXT_DIM)
	lbl.custom_minimum_size = Vector2(0, 42)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_container.add_child(lbl)


func _update_selection() -> void:
	var count := _item_rows.size()
	if _selected_index < _scroll_start:
		_scroll_start = _selected_index
	elif _selected_index >= _scroll_start + MAX_VISIBLE_ROWS:
		_scroll_start = _selected_index - MAX_VISIBLE_ROWS + 1
	_scroll_start = clampi(_scroll_start, 0, maxi(count - MAX_VISIBLE_ROWS, 0))
	for i in count:
		var row := _item_rows[i] as MenuRow
		if row:
			row.selected = (i == _selected_index)
			row.visible = i >= _scroll_start and i < _scroll_start + MAX_VISIBLE_ROWS
	_update_caption()
	_update_tabs()
	_update_description()


## Tabs follow the cursor in category phase, the chosen category afterwards.
func _update_tabs() -> void:
	var active := _selected_category
	if _phase == Phase.CATEGORY_SELECT:
		active = _selected_index
	for i in _tab_labels.size():
		var tab := _tab_labels[i] as PanelContainer
		var on := i == active
		tab.add_theme_stylebox_override(&"panel", UIStyle.pill(
			Color(UIStyle.CYAN, 0.18) if on else Color(UIStyle.GLASS_DEEP, 0.6),
			UIStyle.CYAN if on else Color(UIStyle.TEXT_DISABLED, 0.6), 10, 3))
		var lbl := tab.get_child(0) as Label
		if lbl:
			lbl.add_theme_color_override(&"font_color", UIStyle.TEXT if on else UIStyle.TEXT_DIM)


func _update_description() -> void:
	if _selected_index < 0 or _selected_index >= _item_rows.size():
		return
	var row := _item_rows[_selected_index] as MenuRow
	if row == null:
		return
	if row.unavailable and row.unavailable_reason != "":
		_set_description("%s   —   %s" % [row.unavailable_reason, row.description], UIStyle.DANGER)
	else:
		_set_description(row.description, UIStyle.TEXT)


func _set_caption(text: String) -> void:
	_list_caption = text
	_update_caption()


## Caption gets a "2 / 9" counter when the list scrolls.
func _update_caption() -> void:
	var count := _item_rows.size()
	if count > MAX_VISIBLE_ROWS:
		_header_label.text = "%s   %d / %d" % [_list_caption, _selected_index + 1, count]
	else:
		_header_label.text = _list_caption


func _set_description(text: String, color: Color) -> void:
	_desc_label.text = text
	_desc_label.add_theme_color_override(&"font_color", color)


## hints: [[action, text], ...]. An empty text groups the glyph with the next hint.
func _set_hints(hints: Array, caption: String) -> void:
	_hint_label.text = caption
	_hint_label.visible = caption != ""
	for child in _hint_box.get_children():
		_hint_box.remove_child(child)
		child.queue_free()
	var group: HBoxContainer = null
	for h in hints:
		if group == null:
			group = HBoxContainer.new()
			group.add_theme_constant_override(&"separation", 4)
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_hint_box.add_child(group)
		if h[1] == "":
			var glyph := ButtonGlyph.new().setup(h[0])
			glyph.glyph_height = 24.0
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			group.add_child(glyph)
		else:
			group.add_child(GlyphHint.create(h[0], h[1]))
			group = null


func _get_ability_count() -> int:
	var player_node: CharacterBody3D = _get_player()
	if player_node == null or player_node.ability_system == null:
		return 0
	return _menu_abilities(player_node).size()


## v5 BB6: the rows the state shows, in order (AbilitySystem.get_menu_slots).
func _menu_abilities(player_node: CharacterBody3D) -> Array:
	var out: Array = []
	var abil = player_node.ability_system
	if abil == null:
		return out
	if abil.has_method(&"get_menu_slots"):
		for i in abil.get_menu_slots(_is_airborne_menu()):
			var a = abil.get_equipped_ability(i)
			if a != null:
				out.append(a)
		return out
	for a in abil.equipped_abilities:
		if a != null:
			out.append(a)
	return out


## v5 BB6: true while the open Command Menu is the aerial list.
func _is_airborne_menu() -> bool:
	var player_node: CharacterBody3D = _get_player() if is_inside_tree() else null
	if player_node == null or player_node.ability_system == null:
		return false
	var abil = player_node.ability_system
	return "menu_airborne" in abil and bool(abil.menu_airborne)


## v5 BB1: is `target` within the range of the ability whose target step is open?
func _target_in_range(target: Node) -> bool:
	var player_node: CharacterBody3D = _get_player()
	if player_node == null or not (target is Node3D) or not target.is_in_group(&"enemies"):
		return true
	var abil = player_node.ability_system
	if abil == null or not ("menu_ability" in abil) or abil.menu_ability == null \
			or not abil.has_method(&"is_in_range"):
		return true
	return abil.is_in_range(abil.menu_ability, target)


## Active character's display name via the party system's public roster.
func _get_character_name() -> String:
	if not is_inside_tree():
		return ""
	var player_node: CharacterBody3D = _get_player()
	if player_node == null:
		return ""
	var party = player_node.party_system
	if party and "members" in party and "active_index" in party:
		var members: Array = party.members
		var idx: int = party.active_index
		if idx >= 0 and idx < members.size():
			var data = members[idx].get("data")
			if data and "display_name" in data and data.display_name != "":
				return data.display_name
	return ""


func _get_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group(&"player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
