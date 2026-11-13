## Quest tracker HUD element.
## Displays the current tracked quest objective in a compact Lumina Frost glass
## panel in the top-left corner (gold title, objective text). Fades in on update.
## Listens to QuestSystem signals via Events bus.
## v4: a mode chip sits above the quest panel: blue "FREE ROAM" / red "BATTLE",
## flashing on every switch (Events.battle_mode_changed).
extends CanvasLayer

const HEADER_COLOR := UIStyle.GOLD
const TEXT_COLOR := UIStyle.TEXT
const DIM_COLOR := UIStyle.TEXT_DIM
const PANEL_WIDTH := 340.0
const TOP_MARGIN := 28.0
## Quest panel sits below the mode chip.
const QUEST_TOP := 72.0
## Mode chip colours, derived from UIStyle tokens.
const BATTLE_ACCENT := UIStyle.DANGER
const ROAM_ACCENT := UIStyle.GLYPH_X
const MODE_FLASHES := 4
const MODE_FLASH_SEC := 0.12

var _root: Control
var _panel: SlantPanel
var _header_label: Label
var _objective_label: Label
var _no_quest_label: Label
var _mode_panel: SlantPanel
var _mode_label: Label
var _mode_tween: Tween
var _in_battle: bool = false


func _ready() -> void:
	layer = 9
	_build_ui()
	_connect_signals()
	_show_placeholder()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = SlantPanel.new()
	_panel.slant_left = false
	_panel.slant_right = true
	_panel.slant = 14.0
	_panel.padding = 10
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(0, QUEST_TOP)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	_header_label = UIStyle.make_label("QUEST", UIStyle.SIZE_S + 2, HEADER_COLOR, true)
	_header_label.uppercase = true
	vbox.add_child(_header_label)

	_objective_label = UIStyle.make_label("", UIStyle.SIZE_S, TEXT_COLOR)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size.x = PANEL_WIDTH - 40.0
	vbox.add_child(_objective_label)

	_no_quest_label = UIStyle.make_label("No active quest", UIStyle.SIZE_S, DIM_COLOR)
	vbox.add_child(_no_quest_label)

	# Mode chip (top-left, above the quest panel).
	_mode_panel = SlantPanel.new()
	_mode_panel.slant_left = false
	_mode_panel.slant_right = true
	_mode_panel.slant = 12.0
	_mode_panel.padding = 6
	_mode_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mode_panel.position = Vector2(0, TOP_MARGIN)
	_mode_panel.custom_minimum_size = Vector2(170, 0)
	_mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mode_panel)
	_mode_label = UIStyle.make_label("FREE ROAM", UIStyle.SIZE_S + 2, UIStyle.TEXT, true)
	_mode_label.uppercase = true
	_mode_panel.add_child(_mode_label)
	_apply_mode_style(false)


## Fade/slide the panel in after its contents change (unscaled time).
func _play_update_fade() -> void:
	_panel.reset_size()
	UIStyle.fade_slide_in(_panel, Vector2.LEFT)


func _connect_signals() -> void:
	if Events.has_signal(&"battle_mode_changed"):
		Events.battle_mode_changed.connect(_on_battle_mode_changed)
	if Events.has_signal(&"quest_objective_updated"):
		Events.quest_objective_updated.connect(_on_objective_updated)
	if Events.has_signal(&"quest_completed"):
		Events.quest_completed.connect(_on_quest_completed)


func _show_placeholder() -> void:
	_objective_label.visible = false
	_no_quest_label.visible = true


func set_quest(quest_name: String, objective_text: String) -> void:
	_header_label.text = quest_name
	_objective_label.text = objective_text
	_objective_label.visible = true
	_no_quest_label.visible = false
	_play_update_fade()


func clear_quest() -> void:
	_header_label.text = "QUEST"
	_show_placeholder()
	_play_update_fade()


func _on_objective_updated(quest_id: StringName, objective_index: int) -> void:
	# Try to find the tracked quest data from the player's quest system
	var players := get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		_header_label.text = String(quest_id)
		return

	var player: Node = players[0]
	if not player.has_node("QuestSystem"):
		_header_label.text = String(quest_id)
		return

	var quest_sys: Node = player.get_node("QuestSystem")
	var tracked: Dictionary = quest_sys.get_tracked_quest()
	if tracked.is_empty() or tracked["quest_id"] != quest_id:
		return

	var data: Resource = tracked["data"]
	var progress: Array = tracked["progress"]
	var idx: int = tracked["current_objective_index"]

	_header_label.text = data.title
	if idx < data.objectives.size():
		var obj: Resource = data.objectives[idx]
		if obj.target_count > 1:
			var current: int = progress[idx] if idx < progress.size() else 0
			_objective_label.text = "%s (%d/%d)" % [obj.description, current, obj.target_count]
		else:
			_objective_label.text = obj.description
	else:
		_objective_label.text = "All objectives complete"
	_objective_label.visible = true
	_no_quest_label.visible = false
	_play_update_fade()


func _on_quest_completed(_quest_id: StringName) -> void:
	clear_quest()


# --- Mode chip (Free Roam / Battle) -------------------------------------------

## True while the chip shows BATTLE.
func is_showing_battle() -> bool:
	return _in_battle


## Chip text, "FREE ROAM" or "BATTLE".
func get_mode_text() -> String:
	return _mode_label.text


func _on_battle_mode_changed(in_battle: bool) -> void:
	if in_battle == _in_battle:
		return
	_apply_mode_style(in_battle)
	_flash_mode()


func _apply_mode_style(in_battle: bool) -> void:
	_in_battle = in_battle
	var accent: Color = BATTLE_ACCENT if in_battle else ROAM_ACCENT
	_mode_label.text = "BATTLE" if in_battle else "FREE ROAM"
	_mode_panel.fill_color = Color(accent.darkened(0.55), 0.88)
	_mode_panel.fill_bottom_color = Color(accent.darkened(0.75), 0.92)
	_mode_panel.line_color = accent
	_mode_panel.glow_color = Color(accent, 0.55)
	_mode_panel.queue_redraw()


## Blinks the words and pops the chip on a switch (unscaled time, so it also
## reads while the Command Menu slows the game).
func _flash_mode() -> void:
	if _mode_tween and _mode_tween.is_valid():
		_mode_tween.kill()
	_mode_label.modulate = Color.WHITE
	_mode_panel.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_mode_tween = create_tween()
	_mode_tween.set_ignore_time_scale(true)
	for i in MODE_FLASHES:
		_mode_tween.tween_property(_mode_label, "modulate:a", 0.15, MODE_FLASH_SEC)
		_mode_tween.tween_property(_mode_label, "modulate:a", 1.0, MODE_FLASH_SEC)
	var glow := create_tween()
	glow.set_ignore_time_scale(true)
	glow.tween_property(_mode_panel, "modulate", Color.WHITE, MODE_FLASH_SEC * 2.0 * MODE_FLASHES)
