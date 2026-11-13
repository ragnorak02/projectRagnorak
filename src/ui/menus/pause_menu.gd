## Pause menu overlay with Resume, Inventory, Quest Log, Settings, Return to Title.
## Builds UI programmatically — no .tscn needed.
## Toggle with the "pause" action (Escape / Start button).
## Visuals: "Lumina Frost" (UIStyle) — blurred/dimmed backdrop, left nav column of
## slanted MenuRows, party overview cards on the right, footer with zone + glyphs.
extends CanvasLayer

const QuestLogScript := preload("res://src/ui/menus/quest_log.gd")
const SaveLoadMenuScript := preload("res://src/ui/menus/save_load_menu.gd")
const SettingsMenuScript := preload("res://src/ui/menus/settings_menu.gd")

# --- Colors (legacy palette; the visual pass uses UIStyle) ---
const OVERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.7)
const PANEL_BG := Color(0.05, 0.08, 0.15, 0.95)
const PANEL_BORDER := Color(0.3, 0.5, 0.9, 0.5)
const TITLE_COLOR := Color(0.5, 0.7, 1.0)
const TEXT_COLOR := Color(0.85, 0.9, 1.0)
const HIGHLIGHT_BG := Color(0.15, 0.25, 0.55, 0.9)
const DIMMED_COLOR := Color(0.4, 0.4, 0.5)

## Blurred, slightly desaturated screen backdrop with a vignette.
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.01, 0.03, 0.05, 0.70);
uniform float blur_lod = 2.5;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), 0.35);
	c = mix(c, tint.rgb, tint.a);
	float v = smoothstep(0.95, 0.35, distance(UV, vec2(0.5)));
	c *= mix(0.55, 1.0, v);
	COLOR = vec4(c, 1.0);
}
"""

# --- Menu item definitions ---
enum MenuItem { RESUME, SAVE_GAME, INVENTORY, QUEST_LOG, SETTINGS, RETURN_TO_TITLE }

const MENU_ITEMS: Array[Dictionary] = [
	{ "id": MenuItem.RESUME, "label": "Resume", "available": true },
	{ "id": MenuItem.SAVE_GAME, "label": "Save Game", "available": true },
	{ "id": MenuItem.INVENTORY, "label": "Inventory", "available": false },
	{ "id": MenuItem.QUEST_LOG, "label": "Quest Log", "available": true },
	{ "id": MenuItem.SETTINGS, "label": "Settings", "available": true },
	{ "id": MenuItem.RETURN_TO_TITLE, "label": "Return to Title", "available": true },
]

## One-line description shown under the nav column for the highlighted entry.
const MENU_DESCRIPTIONS := {
	MenuItem.RESUME: "Return to the game.",
	MenuItem.SAVE_GAME: "Write your progress to a manual save slot.",
	MenuItem.INVENTORY: "Coming soon.",
	MenuItem.QUEST_LOG: "Review active and completed quests. Choose which one to track.",
	MenuItem.SETTINGS: "Camera, audio, controls and gameplay options.",
	MenuItem.RETURN_TO_TITLE: "Leave to the title screen. Unsaved progress is lost.",
}

const NAV_WIDTH := 460.0
const MARGIN_X := 96.0
const CONTENT_TOP := 176.0
const FOOTER_H := 64.0

# --- State ---
var _is_open: bool = false
var _selected_index: int = 0
## Stick/D-pad/key navigation (v5 AA): one push = one step, hold = steady repeat.
var _nav := MenuNav.new([&"move_up", &"ui_up"], [&"move_down", &"ui_down"], [], [])

# --- UI References ---
var _root: Control
var _overlay: ColorRect
var _panel: Control              # all menu content (fades in after the backdrop)
var _nav_box: VBoxContainer
var _item_rows: Array = []       # MenuRow per MENU_ITEMS entry (plain Array: see UI kit notes)
var _item_labels: Array = []     # kept parallel to _item_rows (rows draw their own text)
var _nav_desc: Label
var _header: HeaderTab
var _party_box: HBoxContainer
var _zone_label: Label
var _placeholder_label: Label
var _quest_log: Node = null
var _save_load_menu: Node = null
var _settings_menu: Node = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_hide_menu()


func _build_ui() -> void:
	# --- Full-screen root ---
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- Blurred / dimmed backdrop ---
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = UIStyle.DIM_SCREEN
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = BACKDROP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_overlay.material = mat
	_root.add_child(_overlay)

	# --- Content layer ---
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	# Header tab: "PAUSED  <zone>"
	_header = HeaderTab.new().setup("Paused", "")
	_header.title_size = UIStyle.SIZE_L
	_header.position = Vector2(MARGIN_X, 72)
	_panel.add_child(_header)

	# Thin cyan light-line under the header across the screen
	var rule := ColorRect.new()
	rule.color = UIStyle.CYAN_DIM
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.anchor_right = 1.0
	rule.offset_left = MARGIN_X
	rule.offset_right = -MARGIN_X
	rule.offset_top = 138
	rule.offset_bottom = 139
	_panel.add_child(rule)

	# --- Left nav column ---
	_nav_box = VBoxContainer.new()
	_nav_box.position = Vector2(MARGIN_X, CONTENT_TOP)
	_nav_box.custom_minimum_size = Vector2(NAV_WIDTH, 0)
	_nav_box.add_theme_constant_override("separation", 8)
	_nav_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_nav_box)

	_item_rows.clear()
	_item_labels.clear()
	for item: Dictionary in MENU_ITEMS:
		var row := _create_menu_row(item)
		_nav_box.add_child(row)

	# Description line for the highlighted entry
	var desc_panel := PanelContainer.new()
	desc_panel.add_theme_stylebox_override("panel", UIStyle.glass_panel(12))
	desc_panel.custom_minimum_size = Vector2(NAV_WIDTH, 0)
	desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_desc = UIStyle.make_label("", UIStyle.SIZE_S, UIStyle.TEXT)
	_nav_desc.add_theme_font_size_override("font_size", 18)
	_nav_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nav_desc.custom_minimum_size = Vector2(NAV_WIDTH - 28, 48)
	desc_panel.add_child(_nav_desc)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_box.add_child(gap)
	_nav_box.add_child(desc_panel)

	# --- Right: party overview ---
	var right := VBoxContainer.new()
	right.anchor_right = 1.0
	right.offset_left = MARGIN_X + NAV_WIDTH + 72
	right.offset_right = -MARGIN_X
	right.offset_top = CONTENT_TOP
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(right)

	right.add_child(UIStyle.make_label("PARTY", UIStyle.SIZE_M, UIStyle.GOLD, true))
	_party_box = HBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 20)
	_party_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_party_box)

	# --- Footer: zone + glyph hints ---
	var footer := PanelContainer.new()
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -FOOTER_H - 24
	footer.offset_bottom = -24
	footer.offset_left = MARGIN_X
	footer.offset_right = -MARGIN_X
	footer.add_theme_stylebox_override("panel", UIStyle.glass_panel(12))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(footer)

	var fbox := HBoxContainer.new()
	fbox.add_theme_constant_override("separation", 28)
	fbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(fbox)

	var zone_caption := UIStyle.make_label("LOCATION", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true)
	zone_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fbox.add_child(zone_caption)
	_zone_label = UIStyle.make_label("", UIStyle.SIZE_M, UIStyle.TEXT, true)
	_zone_label.add_theme_font_size_override("font_size", 24)
	_zone_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fbox.add_child(_zone_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fbox.add_child(spacer)

	fbox.add_child(GlyphHint.create(&"ui_up", "Navigate", UIStyle.SIZE_S))
	fbox.add_child(GlyphHint.create(&"ui_accept", "Select", UIStyle.SIZE_S))
	fbox.add_child(GlyphHint.create(&"ui_cancel", "Resume", UIStyle.SIZE_S))

	# Small brand mark (decorative)
	var brand := UIStyle.make_label("LUMINA", UIStyle.SIZE_S, UIStyle.TEXT_DISABLED, true)
	brand.add_theme_font_size_override("font_size", 11)
	brand.anchor_left = 1.0
	brand.anchor_right = 1.0
	brand.offset_left = -MARGIN_X - 80
	brand.offset_right = -MARGIN_X
	brand.offset_top = 92
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(brand)

	# --- Placeholder "Coming Soon" toast (hidden by default) ---
	_placeholder_label = UIStyle.make_label("Coming Soon", UIStyle.SIZE_M, UIStyle.GOLD, true)
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.add_theme_stylebox_override("normal",
		UIStyle.pill(UIStyle.GLASS_DEEP, UIStyle.GOLD_DIM, 20, 6))
	_placeholder_label.position = Vector2(MARGIN_X + NAV_WIDTH + 24, CONTENT_TOP + 2 * 60)
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder_label.visible = false
	_root.add_child(_placeholder_label)


func _create_menu_row(item: Dictionary) -> Control:
	var row := MenuRow.new()
	row.text = item["label"]
	row.focus_mode = Control.FOCUS_NONE   # cursor-driven (see _update_selection)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.row_font_size = 26
	row.custom_minimum_size = Vector2(NAV_WIDTH, 54)
	if not item["available"]:
		row.unavailable = true
		row.unavailable_reason = "Coming soon"
		row.right_text = "SOON"

	row.set_meta("item_id", item["id"])
	row.set_meta("available", item["available"])

	_item_rows.append(row)
	_item_labels.append(row)
	return row


# --- Party overview ---

func _refresh_overview() -> void:
	for child in _party_box.get_children():
		child.queue_free()

	var players := get_tree().get_nodes_in_group(&"player")
	var player: Node = players[0] if not players.is_empty() else null
	var party: Node = player.get("party_system") if player else null

	var members: Array = []
	if party and party.get("members") is Array:
		members = party.members
	elif player:
		members = [{"id": &"hero", "data": null, "node": player, "is_active": true}]

	for m: Dictionary in members:
		_party_box.add_child(_create_member_card(m, party, player))

	if members.is_empty():
		_party_box.add_child(UIStyle.make_label("No party data", UIStyle.SIZE_S, UIStyle.TEXT_DIM))

	var zone := _get_zone_name()
	_zone_label.text = zone
	_header.subtitle = zone


func _create_member_card(m: Dictionary, party: Node, player: Node) -> Control:
	var node: Node = m.get("node")
	var data: Resource = m.get("data")
	var display_name := ""
	if data and data.get("display_name"):
		display_name = data.display_name
	elif node:
		display_name = String(node.name)
	var downed := false
	if party and party.has_method("is_member_downed"):
		downed = party.is_member_downed(m.get("id", &""))

	var card := SlantPanel.new()
	card.selected = m.get("is_active", false)
	# Only the active member's card glows; unselected cards stay transparent-edged.
	card.glow_color = UIStyle.CYAN_GLOW if card.selected else Color(0, 0, 0, 0)
	card.custom_minimum_size = Vector2(380, 0)
	card.padding = 16
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# Name plate
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_label := UIStyle.make_label(display_name.to_upper(), UIStyle.SIZE_L, UIStyle.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var lv := UIStyle.make_label("LV  --", UIStyle.SIZE_S, UIStyle.GOLD, true)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lv)

	var role := "ACTIVE" if m.get("is_active", false) else "ALLY"
	if downed:
		role = "DOWNED"
	v.add_child(UIStyle.make_label(role, UIStyle.SIZE_S,
		UIStyle.DANGER if downed else (UIStyle.CYAN if m.get("is_active", false) else UIStyle.TEXT_DIM), true))

	# HP / MP
	var hp_cur: float = _num(node, "current_hp", 0.0)
	var hp_max: float = _num(node, "max_hp", 1.0)
	var mp_cur: float = _num(node, "current_mp", 0.0)
	var mp_max: float = _num(node, "max_mp", 1.0)
	v.add_child(_stat_line("HP", hp_cur, hp_max, false))
	v.add_child(_stat_line("MP", mp_cur, mp_max, true))

	# Equipped weapon (player only exposes an EquipmentSystem)
	var weapon := _get_weapon_name(node if node == player else null)
	if weapon != "":
		var w := HBoxContainer.new()
		w.add_theme_constant_override("separation", 10)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.add_child(UIStyle.make_label("WEAPON", UIStyle.SIZE_S, UIStyle.TEXT_DIM, true))
		w.add_child(UIStyle.make_label(weapon, UIStyle.SIZE_S, UIStyle.TEXT))
		v.add_child(w)

	if downed:
		card.modulate = Color(0.6, 0.6, 0.65, 1.0)
	return card


func _stat_line(caption: String, cur: float, mx: float, is_mp: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var cap := UIStyle.make_label(caption, UIStyle.SIZE_S, UIStyle.MP if is_mp else UIStyle.TEXT_DIM, true)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var nums := UIStyle.make_label("%d / %d" % [roundi(cur), roundi(mx)], UIStyle.SIZE_S, UIStyle.TEXT)
	nums.add_theme_font_override("font", UIStyle.font_body_bold())
	nums.add_theme_font_size_override("font_size", 18)
	row.add_child(nums)
	var g := Gauge.new()
	g.custom_minimum_size = Vector2(340, 10 if is_mp else 14)
	if is_mp:
		g.fill_color = UIStyle.MP
		g.fill_color_end = UIStyle.MP.lightened(0.2)
	else:
		g.low_threshold = 0.25
	box.add_child(g)
	g.set_values(cur, maxf(mx, 1.0), true)
	return box


func _num(node: Object, prop: String, fallback: float) -> float:
	if node == null:
		return fallback
	var v = node.get(prop)
	return float(v) if v != null else fallback


func _get_weapon_name(player: Node) -> String:
	if player == null:
		return ""
	var eq: Node = player.get_node_or_null("EquipmentSystem")
	if eq == null or not eq.has_method("get_equipped"):
		return ""
	for slot in [EquipmentData.EquipmentSlot.RIGHT_HAND, EquipmentData.EquipmentSlot.LEFT_HAND]:
		var item = eq.get_equipped(slot)
		if item and item.get("display_name"):
			return item.display_name
	return ""


func _get_zone_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var zid = scene.get("zone_id")
	var raw: String = zid if zid is String and zid != "" else scene.scene_file_path.get_file().get_basename()
	return raw.replace("_", " ").capitalize()


# --- Input Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_toggle_menu()
		get_viewport().set_input_as_handled()
		return

	if not _is_open:
		return

	# Raw stick motion never navigates directly (noise = twitch); MenuNav turns
	# it into clean steps in _process.
	if _nav.consume_event(event):
		get_viewport().set_input_as_handled()
		return

	# Navigate up/down (D-pad / W/S / arrows: one press = one step)
	var step := _nav.event_step(event)
	if step.y != 0:
		_move_selection(step.y)
		get_viewport().set_input_as_handled()
		return

	# Confirm selection
	if event.is_action_pressed(&"ui_accept"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
		return

	# Cancel / back (same as Resume)
	if event.is_action_pressed(&"ui_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()
		return


# --- Menu Toggle ---

func _toggle_menu() -> void:
	if _is_open:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	# Block pause during states that should not allow it
	if GameManager.current_state == GameManager.GameState.MAIN_MENU:
		return
	if GameManager.current_state == GameManager.GameState.LOADING:
		return
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	_is_open = true
	_selected_index = 0
	_nav.reset()
	_placeholder_label.visible = false
	_update_selection()
	_show_menu()
	GameManager.change_state(GameManager.GameState.PAUSED)
	Events.ui_menu_opened.emit(&"pause_menu")
	AudioManager.play_sfx_named("menu_open")


func _close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_placeholder_label.visible = false
	_hide_menu()
	GameManager.change_state(GameManager.GameState.PLAYING)
	Events.ui_menu_closed.emit(&"pause_menu")
	AudioManager.play_sfx_named("menu_close")


# --- Selection ---

func _move_selection(direction: int) -> void:
	_selected_index = wrapi(_selected_index + direction, 0, _item_rows.size())
	_update_selection()
	AudioManager.play_sfx_named("menu_select")


func _update_selection() -> void:
	for i in _item_rows.size():
		var row: MenuRow = _item_rows[i]
		row.selected = i == _selected_index
	if _nav_desc and _selected_index >= 0 and _selected_index < MENU_ITEMS.size():
		var item: Dictionary = MENU_ITEMS[_selected_index]
		_nav_desc.text = MENU_DESCRIPTIONS.get(item["id"], "")
		_nav_desc.add_theme_color_override(&"font_color",
			UIStyle.GOLD if not item["available"] else UIStyle.TEXT)


func _confirm_selection() -> void:
	if _selected_index < 0 or _selected_index >= _item_rows.size():
		return

	var row: Control = _item_rows[_selected_index]
	var item_id: int = row.get_meta("item_id")
	var available: bool = row.get_meta("available")

	if not available:
		# Show "Coming Soon" briefly
		_show_placeholder()
		return

	AudioManager.play_sfx_named("menu_confirm")
	match item_id:
		MenuItem.RESUME:
			_close_menu()
		MenuItem.SAVE_GAME:
			_open_save_menu()
		MenuItem.QUEST_LOG:
			_open_quest_log()
		MenuItem.SETTINGS:
			_open_settings()
		MenuItem.RETURN_TO_TITLE:
			_return_to_title()


func _open_save_menu() -> void:
	if _save_load_menu == null:
		_save_load_menu = CanvasLayer.new()
		_save_load_menu.set_script(SaveLoadMenuScript)
		add_child(_save_load_menu)
	_save_load_menu.open_menu(0)  # 0 = Mode.SAVE


func _open_quest_log() -> void:
	# Find player's quest system
	var players := get_tree().get_nodes_in_group(&"player")
	var quest_sys: Node = null
	if not players.is_empty() and players[0].has_node("QuestSystem"):
		quest_sys = players[0].get_node("QuestSystem")

	if _quest_log == null:
		_quest_log = CanvasLayer.new()
		_quest_log.set_script(QuestLogScript)
		add_child(_quest_log)

	_quest_log.open_log(quest_sys)


func _open_settings() -> void:
	if _settings_menu == null:
		_settings_menu = CanvasLayer.new()
		_settings_menu.set_script(SettingsMenuScript)
		add_child(_settings_menu)
	_settings_menu.open_menu()


func _return_to_title() -> void:
	_is_open = false
	_hide_menu()
	# Unpause before changing scene
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	Events.ui_menu_closed.emit(&"pause_menu")
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


# --- Placeholder feedback ---

func _show_placeholder() -> void:
	_placeholder_label.visible = true
	_placeholder_label.modulate.a = 1.0
	_placeholder_label.position.y = CONTENT_TOP + _selected_index * 62.0 + 6.0

	var tween := UIStyle.ui_tween(_placeholder_label)
	if tween == null:
		return
	tween.tween_interval(1.0)
	tween.tween_property(_placeholder_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): _placeholder_label.visible = false)


# --- Visibility ---

var _menu_tween: Tween = null


func _show_menu() -> void:
	_root.visible = true
	_panel.visible = true
	_sub_menu_shown = false
	_refresh_overview()
	# Fade-in transition (unscaled time, so tactical slow-time never drags it)
	if _menu_tween and _menu_tween.is_running():
		_menu_tween.kill()
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_menu_tween = UIStyle.ui_tween(_root)
	if _menu_tween == null:
		_overlay.modulate.a = 1.0
		_panel.modulate.a = 1.0
		return
	_menu_tween.set_parallel(true)
	_menu_tween.tween_property(_overlay, "modulate:a", 1.0, 0.15)
	_menu_tween.tween_property(_panel, "modulate:a", 1.0, 0.16).set_delay(0.04)
	UIStyle.fade_slide_in(_nav_box, Vector2.LEFT, 0.16, 12.0)


func _hide_menu() -> void:
	_root.visible = false
	_sub_menu_shown = false


# --- Sub-menu layering (CAR-P5) ---
# While the quest log, save/load or settings menu is open, the pause nav, party
# cards and footer are hidden so they don't ghost through the sub-menu; only the
# blurred backdrop stays. Purely visual: input, focus and signals are untouched
# (sub-menus still consume their own input on higher layers).

var _sub_menu_shown: bool = false


## True while any pause sub-menu is open (read-only, duck-typed on their state).
func is_sub_menu_open() -> bool:
	for m in [_quest_log, _save_load_menu, _settings_menu]:
		if m == null or not is_instance_valid(m):
			continue
		if m.has_method("is_open"):
			if m.is_open():
				return true
		elif m.get("_is_open") == true:
			return true
	return false


func _process(_delta: float) -> void:
	if not _is_open:
		return
	var sub := is_sub_menu_open()
	if not sub:
		var nav_step := _nav.poll()
		if nav_step.y != 0:
			_move_selection(nav_step.y)
	if sub == _sub_menu_shown:
		return
	_sub_menu_shown = sub
	_nav.reset()   # sub-menu opened/closed: don't carry a held stick across layers
	if sub:
		if _menu_tween and _menu_tween.is_running():
			_menu_tween.kill()
		_panel.visible = false
		_placeholder_label.visible = false
	else:
		_panel.visible = true
		_overlay.modulate.a = 1.0
		_panel.modulate.a = 0.0
		var tw := UIStyle.ui_tween(_panel)
		if tw == null:
			_panel.modulate.a = 1.0
		else:
			tw.tween_property(_panel, "modulate:a", 1.0, 0.12)
		_refresh_overview()
