## GlyphHint — a ButtonGlyph followed by a short label ("[A] Confirm").
## Use GlyphHint.create(&"interact", "Talk") or set `action` / `text`.
class_name GlyphHint
extends HBoxContainer

@export var action: StringName = &"":
	set(v):
		action = v
		if _glyph:
			_glyph.action = v
@export var text: String = "":
	set(v):
		text = v
		if _label:
			_label.text = v
@export var font_size: int = UIStyle.SIZE_S:
	set(v):
		font_size = v
		_apply_style()
@export var text_color: Color = UIStyle.TEXT:
	set(v):
		text_color = v
		_apply_style()
@export var glyph_height: float = 24.0:
	set(v):
		glyph_height = v
		if _glyph:
			_glyph.glyph_height = v

var _glyph: ButtonGlyph
var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	_glyph = ButtonGlyph.new()
	_glyph.name = "Glyph"
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.glyph_height = glyph_height
	add_child(_glyph)
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	_apply_style()


## Build a hint in one call. `device` = ButtonGlyph.Device (AUTO by default).
static func create(p_action: StringName, p_text: String, p_font_size: int = UIStyle.SIZE_S, p_device: int = ButtonGlyph.Device.AUTO) -> GlyphHint:
	var h := GlyphHint.new()
	h.font_size = p_font_size
	h.text = p_text
	h.get_glyph().device = p_device
	h.action = p_action
	return h


func setup(p_action: StringName, p_text: String) -> GlyphHint:
	text = p_text
	action = p_action
	return self


func get_glyph() -> ButtonGlyph:
	return _glyph


func get_label() -> Label:
	return _label


func _apply_style() -> void:
	if _label:
		UIStyle.style_label(_label, font_size, text_color, false, 3)
