## Combat HUD displaying HP, MP, ATB bars and insufficient resource feedback.
## Builds UI programmatically for easy testing and iteration.
extends CanvasLayer

# Bar references
var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _atb_bar: ProgressBar
var _hp_label: Label
var _mp_label: Label
var _atb_label: Label
var _flash_label: Label
var _cooldown_container: VBoxContainer

# Flash feedback
var _flash_tween: Tween = null
var _mp_flash_tween: Tween = null
var _atb_flash_tween: Tween = null

# Stylebox references for flash
var _mp_bar_normal_style: StyleBoxFlat
var _mp_bar_flash_style: StyleBoxFlat
var _atb_bar_normal_style: StyleBoxFlat
var _atb_bar_flash_style: StyleBoxFlat

# ATB segment tracking
var _atb_segment_markers: Array[ColorRect] = []
const ATB_SEGMENT_COST: float = 25.0


func _ready() -> void:
	layer = 10
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Bottom-left container for bars
	var bar_container := VBoxContainer.new()
	bar_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar_container.position = Vector2(20, -120)
	bar_container.size = Vector2(300, 100)
	bar_container.add_theme_constant_override("separation", 4)
	root.add_child(bar_container)

	# HP Bar
	_hp_bar = _create_bar("HP", Color(0.2, 0.8, 0.2), bar_container)
	_hp_label = _hp_bar.get_node("Label")

	# MP Bar
	_mp_bar = _create_bar("MP", Color(0.2, 0.4, 1.0), bar_container)
	_mp_label = _mp_bar.get_node("Label")
	_mp_bar_normal_style = _mp_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_mp_bar_flash_style = _mp_bar_normal_style.duplicate() as StyleBoxFlat
	_mp_bar_flash_style.bg_color = Color(1.0, 0.2, 0.2)

	# ATB Bar with segments
	_atb_bar = _create_bar("ATB", Color(0.9, 0.7, 0.1), bar_container)
	_atb_label = _atb_bar.get_node("Label")
	_atb_bar_normal_style = _atb_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_atb_bar_flash_style = _atb_bar_normal_style.duplicate() as StyleBoxFlat
	_atb_bar_flash_style.bg_color = Color(0.5, 0.3, 0.0)

	# Add ATB segment dividers
	_build_atb_segments()

	# Flash feedback label (center screen)
	_flash_label = Label.new()
	_flash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash_label.position = Vector2(-150, 80)
	_flash_label.size = Vector2(300, 40)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.add_theme_font_size_override("font_size", 20)
	_flash_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_flash_label.modulate.a = 0.0
	root.add_child(_flash_label)

	# Cooldown indicator container (below ATB bar)
	_cooldown_container = VBoxContainer.new()
	_cooldown_container.position = Vector2(20, 0)
	_cooldown_container.size = Vector2(200, 60)
	bar_container.add_child(_cooldown_container)


func _create_bar(label_text: String, fill_color: Color, parent: Control) -> ProgressBar:
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	parent.add_child(bar_row)

	var label := Label.new()
	label.name = "BarLabel"
	label.text = label_text
	label.custom_minimum_size = Vector2(30, 0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	bar_row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 18)
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false

	# Background style
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_style)

	# Fill style
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	bar_row.add_child(bar)

	# Value label overlaid on bar
	var val_label := Label.new()
	val_label.name = "Label"
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_label.add_theme_font_size_override("font_size", 12)
	val_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	val_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(val_label)

	return bar


func _build_atb_segments() -> void:
	# Add vertical divider lines at each ATB_SEGMENT_COST interval
	var segment_count := int(_atb_bar.max_value / ATB_SEGMENT_COST)
	for i in range(1, segment_count):
		var divider := ColorRect.new()
		divider.color = Color(1.0, 1.0, 1.0, 0.3)
		divider.size = Vector2(1, 18)
		divider.position = Vector2(_atb_bar.custom_minimum_size.x * (float(i) / float(segment_count)), 0)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_atb_bar.add_child(divider)
		_atb_segment_markers.append(divider)


func _connect_signals() -> void:
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_mp_changed.connect(_on_mp_changed)
	Events.player_atb_changed.connect(_on_atb_changed)
	Events.ability_request_failed.connect(_on_ability_request_failed)
	Events.ability_cooldown_started.connect(_on_cooldown_started)
	Events.ability_cooldown_finished.connect(_on_cooldown_finished)
	Events.ability_cast_started.connect(_on_cast_started)
	Events.ability_cast_completed.connect(_on_cast_completed)


# --- Signal Handlers ---

func _on_hp_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [int(current), int(maximum)]

	# Color shift at low HP
	var fill_style := _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if current / maximum <= 0.25:
		fill_style.bg_color = Color(0.9, 0.2, 0.2)
	elif current / maximum <= 0.5:
		fill_style.bg_color = Color(0.9, 0.7, 0.2)
	else:
		fill_style.bg_color = Color(0.2, 0.8, 0.2)


func _on_mp_changed(current: float, maximum: float) -> void:
	_mp_bar.max_value = maximum
	_mp_bar.value = current
	_mp_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_atb_changed(current: float, maximum: float) -> void:
	_atb_bar.max_value = maximum
	_atb_bar.value = current
	_atb_label.text = "%d%%" % [int((current / maximum) * 100.0)]

	# Highlight segments that are "full"
	var segments_filled := int(current / ATB_SEGMENT_COST)
	var fill_style := _atb_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if segments_filled >= 1:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.5, 0.4, 0.1)


func _on_ability_request_failed(reason: String, _ability_data: Resource) -> void:
	match reason:
		"mp":
			_flash_bar_insufficient(_mp_bar, _mp_bar_normal_style, _mp_bar_flash_style)
			_show_flash_text("Not enough MP!")
		"atb":
			_flash_bar_insufficient(_atb_bar, _atb_bar_normal_style, _atb_bar_flash_style)
			_show_flash_text("Not enough ATB!")
		"cooldown":
			_show_flash_text("Ability on cooldown!")


func _on_cooldown_started(ability_id: StringName, duration: float) -> void:
	var cd_label := Label.new()
	cd_label.name = "CD_" + String(ability_id)
	cd_label.add_theme_font_size_override("font_size", 12)
	cd_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
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
		cd_label.text = "%s: %.1fs" % [ability_id, remaining]
	cd_label.set_meta("update_fn", update_fn)


func _on_cooldown_finished(ability_id: StringName) -> void:
	var cd_node := _cooldown_container.get_node_or_null("CD_" + String(ability_id))
	if cd_node:
		cd_node.queue_free()


func _on_cast_started(ability_data: Resource) -> void:
	if ability_data and ability_data is AbilityData:
		_show_flash_text(ability_data.display_name, Color(0.9, 0.8, 0.3))


func _on_cast_completed(_ability_data: Resource) -> void:
	pass


func _process(_delta: float) -> void:
	# Tick cooldown labels
	for child in _cooldown_container.get_children():
		if child.has_meta("update_fn"):
			child.get_meta("update_fn").call()


# --- Flash Effects ---

func _flash_bar_insufficient(bar: ProgressBar, normal_style: StyleBoxFlat, flash_style: StyleBoxFlat) -> void:
	bar.add_theme_stylebox_override("fill", flash_style)

	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func(): bar.add_theme_stylebox_override("fill", normal_style))
	tween.tween_interval(0.1)
	tween.tween_callback(func(): bar.add_theme_stylebox_override("fill", flash_style))
	tween.tween_interval(0.1)
	tween.tween_callback(func(): bar.add_theme_stylebox_override("fill", normal_style))


func _show_flash_text(text: String, color: Color = Color(1.0, 0.3, 0.3)) -> void:
	_flash_label.text = text
	_flash_label.add_theme_color_override("font_color", color)

	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()

	_flash_label.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.8)
	_flash_tween.tween_property(_flash_label, "modulate:a", 0.0, 0.4)
