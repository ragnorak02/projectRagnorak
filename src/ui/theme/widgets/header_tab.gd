## HeaderTab — slanted title tab ("COMMAND  Amaro"). Title in the header font
## (gold by default), optional dim subtitle. Extends SlantPanel (slant on the right).
class_name HeaderTab
extends SlantPanel

@export var title: String = "":
	set(v):
		title = v
		if _title:
			_title.text = v.to_upper() if uppercase else v
@export var subtitle: String = "":
	set(v):
		subtitle = v
		if _subtitle:
			_subtitle.text = v
			_subtitle.visible = v != ""
@export var uppercase: bool = true:
	set(v):
		uppercase = v
		title = title
@export var title_size: int = UIStyle.SIZE_M:
	set(v):
		title_size = v
		_restyle()
@export var title_color: Color = UIStyle.GOLD:
	set(v):
		title_color = v
		_restyle()

var _title: Label
var _subtitle: Label


func _init() -> void:
	slant_left = false
	slant_right = true
	padding = 10.0
	line_color = UIStyle.GOLD
	var box := HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 12)
	add_child(box)
	_title = Label.new()
	_title.name = "Title"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_subtitle.visible = false
	box.add_child(_subtitle)
	_restyle()


func setup(p_title: String, p_subtitle: String = "") -> HeaderTab:
	title = p_title
	subtitle = p_subtitle
	return self


func get_title_label() -> Label:
	return _title


func get_subtitle_label() -> Label:
	return _subtitle


func _restyle() -> void:
	if _title == null:
		return
	UIStyle.style_label(_title, title_size, title_color, true)
	UIStyle.style_label(_subtitle, int(title_size * 0.8), UIStyle.TEXT, false)
