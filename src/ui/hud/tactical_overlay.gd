## Tactical overlay — full-screen "time slowed" treatment while tactical mode is open.
## Slight desaturation + cool Lumina tint + vignette, via a screen-texture shader on
## a ColorRect. Purely visual: listens to Events.tactical_mode_entered/exited only,
## never blocks input (MOUSE_FILTER_IGNORE) and fades in unscaled time.
## Layer 8: above the 3D world, below the HUD (9-12) so HUD text stays crisp.
extends CanvasLayer

const FADE_IN_TIME := 0.16
const FADE_OUT_TIME := 0.14

const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.45;
uniform vec3 tint : source_color = vec3(0.62, 0.86, 0.95);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.22;
uniform float vignette : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(col, vec3(luma), desaturate);
	graded = mix(graded, graded * tint * 1.25, tint_strength);
	vec2 d = UV - vec2(0.5);
	d.x *= 1.35;
	float v = smoothstep(0.35, 0.95, length(d) * vignette * 1.25);
	graded = mix(graded, graded * vec3(0.05, 0.12, 0.18), v * 0.75);
	COLOR = vec4(mix(col, graded, amount), 1.0);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween = null
var _active: bool = false


func _ready() -> void:
	layer = 8
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	_rect = ColorRect.new()
	_rect.name = "TacticalOverlay"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"amount", 0.0)
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func _connect_signals() -> void:
	Events.tactical_mode_entered.connect(_on_tactical_entered)
	Events.tactical_mode_exited.connect(_on_tactical_exited)


func is_active() -> bool:
	return _active


func get_amount() -> float:
	return float(_material.get_shader_parameter(&"amount"))


func _on_tactical_entered() -> void:
	_active = true
	_rect.visible = true
	_fade_to(1.0, FADE_IN_TIME)


func _on_tactical_exited() -> void:
	_active = false
	_fade_to(0.0, FADE_OUT_TIME)


func _fade_to(target: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = UIStyle.ui_tween(self)
	if _tween == null:
		_set_amount(target)
		return
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_amount, get_amount(), target, duration)
	if target <= 0.0:
		_tween.tween_callback(func() -> void:
			if not _active:
				_rect.visible = false)


func _set_amount(v: float) -> void:
	_material.set_shader_parameter(&"amount", v)
	if v <= 0.0 and not _active:
		_rect.visible = false
