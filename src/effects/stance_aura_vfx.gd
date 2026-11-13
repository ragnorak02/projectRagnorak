## Arcane Stance aura (battle v3, Package S): a cyan ring and a soft glow at the
## caster's feet while the stance is active, plus a one-shot expanding flash
## ring on enter/exit. Real-time pulse and unscaled tweens (tactical runs at
## 0.05 and hit-stop at 0.01, so scaled time would freeze the effect).
class_name StanceAuraVfx
extends Node3D

const RING_COLOR := Color(0.35, 0.9, 1.0, 0.85)
const GLOW_COLOR := Color(0.3, 0.8, 1.0, 0.22)
const RING_RADIUS := 0.85
const PULSE_HZ := 1.4

var _ring_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _start_ms: int = 0


## Places an aura instance (created by the caller with StanceAuraVfx.new())
## as a child of `owner_node` at its feet. The caller instantiates it so this
## script never references its own class_name (that self-reference kept the
## script alive at exit: "1 resources still in use").
static func attach(owner_node: Node3D, aura: Node3D) -> Node3D:
	aura.name = "StanceAura"
	owner_node.add_child(aura)
	aura.position = Vector3(0, 0.05, 0)
	return aura


## One-shot expanding ring (enter/exit feedback) at `pos`, under `parent`.
static func flash(parent: Node, pos: Vector3, entering: bool = true) -> void:
	if parent == null:
		return
	var fx := MeshInstance3D.new()
	fx.name = "StanceFlash"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	fx.mesh = torus
	var mat := _make_mat(Color(0.5, 0.95, 1.0, 0.9), 3.0)
	fx.material_override = mat
	parent.add_child(fx)
	if fx.is_inside_tree():
		fx.global_position = pos + Vector3(0, 0.1, 0)
	var from := 0.3 if entering else 1.6
	var to := 1.8 if entering else 0.2
	fx.scale = Vector3(from, 1.0, from)
	var tw := fx.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(to, 1.0, to), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(fx.queue_free)


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.06
	torus.outer_radius = RING_RADIUS
	torus.rings = 32
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring_mat = _make_mat(RING_COLOR, 2.5)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var disc := CylinderMesh.new()
	disc.top_radius = RING_RADIUS
	disc.bottom_radius = RING_RADIUS
	disc.height = 0.01
	glow.mesh = disc
	_glow_mat = _make_mat(GLOW_COLOR, 1.2)
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	var light := OmniLight3D.new()
	light.name = "GlowLight"
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = Vector3(0, 0.4, 0)
	add_child(light)


func _process(_delta: float) -> void:
	# Real-time pulse so it keeps breathing during tactical/hit-stop.
	var t := float(Time.get_ticks_msec() - _start_ms) / 1000.0
	var p := 0.5 + 0.5 * sin(t * TAU * PULSE_HZ)
	if _ring_mat:
		_ring_mat.albedo_color.a = lerpf(0.55, 0.95, p)
	if _glow_mat:
		_glow_mat.albedo_color.a = lerpf(0.12, 0.28, p)
	if _ring:
		_ring.rotation.y = t * 0.8


static func _make_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
