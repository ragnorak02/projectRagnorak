## Base class for all enemies.
extends CharacterBody3D
class_name EnemyBase

## Name shown on the target bar and Command Menu target list.
@export var display_name: String = "Reactor Sentry"
@export var max_hp: float = 50.0
@export var attack_damage: float = 10.0
@export var move_speed: float = 4.0
@export var aggro_range: float = 12.0
@export var attack_range: float = 2.0
@export var attack_telegraph: float = 0.4
@export var attack_active: float = 0.2
@export var attack_recovery: float = 0.5
@export var attack_cooldown: float = 1.8
@export var stagger_duration: float = 0.5  # HURT flinch length (not the stagger break)
@export var gravity: float = 20.0

# --- Stagger (battle v3). Duck-typed by src/ui/hud/target_bar.gd:
# stagger_value, stagger_max, is_staggered(), stagger_damage_multiplier.
@export var stagger_max: float = 100.0
## Damage multiplier applied while STAGGERED.
@export var stagger_damage_multiplier: float = 1.6
## Length of the STAGGERED break (game time).
@export var stagger_break_time: float = 4.0
## Seconds without stagger gain before the gauge starts to drain.
@export var stagger_decay_delay: float = 2.5
## Gauge drain per second once decaying (also used after a break ends).
@export var stagger_decay_rate: float = 12.0
## Drain per second right after a break, so the gauge empties visibly.
const STAGGER_RECOVER_RATE := 60.0
var stagger_value: float = 0.0
var _stagger_timer: float = 0.0
var _stagger_idle_timer: float = 0.0
var _stagger_recovering: bool = false
const STAGGER_TINT := Color(1.0, 0.62, 0.3, 1.0)

var current_hp: float

## v5: optional un-rigged model (docs/rigless_models.md). When set, the capsule
## is hidden and a RiglessVisual (procedural bob/lean/cues) shows this mesh.
@export var rigless_model: PackedScene = null
@export var rigless_fit_height: float = 1.7
@export var rigless_yaw_offset_deg: float = 180.0
var _rigless: Node3D = null

@onready var visual_root: Node3D = $VisualRoot
@onready var hurtbox: Area3D = $Hurtbox
@onready var attack_origin: Node3D = $AttackOrigin
@onready var attack_hitbox_shape: CollisionShape3D = $AttackOrigin/AttackHitbox/CollisionShape3D
@onready var aggro_area: Area3D = $AggroArea
@onready var lock_on_point: Marker3D = $LockOnPoint

var _target: Node3D = null
var _is_dead: bool = false
var _state_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _hit_active: bool = false
var _original_color: Color

# Health bar (overhead billboard)
var _health_bar_root: Node3D = null
var _health_bar_fill: MeshInstance3D = null
var _health_bar_bg: MeshInstance3D = null
var _health_bar_visible: bool = false
var _stagger_bar_fill: MeshInstance3D = null
const HEALTH_BAR_WIDTH: float = 1.2
const HEALTH_BAR_HEIGHT: float = 0.05
const HEALTH_BAR_BORDER: float = 0.03
const STAGGER_BAR_HEIGHT: float = 0.025
const HEALTH_BAR_Y_OFFSET: float = 2.4

# STAGGERED is appended so existing values (IDLE..DEAD) keep their indices.
enum AIState { IDLE, CHASE, ATTACK_TELEGRAPH, ATTACK_STRIKE, ATTACK_RECOVERY, HURT, DEAD, STAGGERED }
var ai_state: AIState = AIState.IDLE


func _ready() -> void:
	add_to_group(&"enemies")
	current_hp = max_hp
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	aggro_area.body_entered.connect(_on_aggro_body_entered)

	var mesh: MeshInstance3D = visual_root.get_node("MeshInstance3D")
	if mesh and mesh.material_override:
		# Per-instance copy: the scene's sub-resource material is shared by every
		# enemy instance, so a flash / stagger tint would otherwise recolour all.
		mesh.material_override = mesh.material_override.duplicate()
		_original_color = mesh.material_override.albedo_color

	_setup_rigless()
	_build_health_bar()
	Events.enemy_spawned.emit(self)


func _setup_rigless() -> void:
	if rigless_model == null or visual_root == null:
		return
	var script: GDScript = load("res://src/characters/rigless_visual.gd")
	if script == null:
		return
	for c in visual_root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
	_rigless = script.new()
	_rigless.name = "RiglessVisual"
	_rigless.set(&"model_scene", rigless_model)
	_rigless.set(&"fit_height", rigless_fit_height)
	_rigless.set(&"model_yaw_offset_deg", rigless_yaw_offset_deg)
	visual_root.add_child(_rigless)


func _rigless_cue(cue: StringName) -> void:
	if _rigless and is_instance_valid(_rigless) and _rigless.has_method(&"play_cue"):
		_rigless.play_cue(cue)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Attack cooldown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	_update_stagger_decay(delta)

	match ai_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK_TELEGRAPH:
			_process_attack_telegraph(delta)
		AIState.ATTACK_STRIKE:
			_process_attack_strike(delta)
		AIState.ATTACK_RECOVERY:
			_process_attack_recovery(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.STAGGERED:
			_process_staggered(delta)

	move_and_slide()


## hit_kind (optional, battle v3): &"blast" / &"finisher" colour the damage
## number gold. While STAGGERED, damage is multiplied by stagger_damage_multiplier.
## v5: knock the enemy into the air (Water Geyser). Sets velocity; gravity
## stays on and the normal AI resumes on landing. Ignored when dead.
func launch(vel: Vector3) -> void:
	if _is_dead:
		return
	velocity = vel


func take_damage(amount: float, source: Node3D = null, hit_kind: StringName = &"") -> void:
	if _is_dead:
		return
	var staggered := is_staggered()
	if staggered:
		amount *= stagger_damage_multiplier
	current_hp = maxf(current_hp - amount, 0.0)
	Events.enemy_damaged.emit(self, amount)
	Events.enemy_hit.emit(self, amount, source)
	_rigless_cue(&"hit")

	# Visual feedback
	_show_health_bar()
	_update_health_bar()
	_spawn_damage_number(amount, hit_kind, staggered)

	# Hit stop feedback
	GameManager.hit_stop(40.0)

	if current_hp <= 0.0:
		die()
	else:
		if staggered:
			# A break is not interrupted by flinches; just flash.
			_flash_color(Color(1.0, 0.85, 0.6, 1.0), 0.1)
		else:
			_enter_hurt()
		AudioManager.play_sfx_varied("enemy_hurt")


# --- Stagger ---

func is_staggered() -> bool:
	return ai_state == AIState.STAGGERED


## Build stagger. At stagger_max the enemy breaks: STAGGERED for
## stagger_break_time (can't act), then the gauge drains. Ignored while already
## staggered or dead.
func add_stagger(amount: float) -> void:
	if _is_dead or amount <= 0.0 or is_staggered():
		return
	_stagger_recovering = false
	_stagger_idle_timer = 0.0
	stagger_value = minf(stagger_value + amount, stagger_max)
	_update_stagger_bar()
	if stagger_value >= stagger_max:
		_enter_staggered()


func _enter_staggered() -> void:
	_disable_attack_hitbox()
	ai_state = AIState.STAGGERED
	_stagger_timer = 0.0
	stagger_value = stagger_max
	velocity.x = 0.0
	velocity.z = 0.0
	_show_health_bar()
	_set_body_color(STAGGER_TINT)
	if visual_root:
		visual_root.rotation.x = deg_to_rad(-12.0)
	Events.enemy_staggered.emit(self)


func _process_staggered(delta: float) -> void:
	_stagger_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if _stagger_timer >= stagger_break_time:
		_exit_staggered()


func _exit_staggered() -> void:
	_stagger_recovering = true
	_stagger_idle_timer = 0.0
	if visual_root:
		visual_root.rotation.x = 0.0
	_set_body_color(_original_color)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer, attack_cooldown * 0.5)
	ai_state = AIState.CHASE


func _update_stagger_decay(delta: float) -> void:
	if is_staggered() or stagger_value <= 0.0:
		return
	if _stagger_recovering:
		stagger_value = maxf(stagger_value - STAGGER_RECOVER_RATE * delta, 0.0)
	else:
		_stagger_idle_timer += delta
		if _stagger_idle_timer < stagger_decay_delay:
			return
		stagger_value = maxf(stagger_value - stagger_decay_rate * delta, 0.0)
	if stagger_value <= 0.0:
		_stagger_recovering = false
	_update_stagger_bar()


func die() -> void:
	_is_dead = true
	ai_state = AIState.DEAD
	_disable_attack_hitbox()
	_hide_health_bar()
	AudioManager.play_sfx_named("enemy_die")

	# Disable collisions so player/lock-on clean up
	collision_layer = 0
	collision_mask = 0
	hurtbox.set_deferred("monitoring", false)
	aggro_area.set_deferred("monitoring", false)

	Events.enemy_died.emit(self)

	# Death shrink then cleanup
	var tween := create_tween()
	tween.tween_property(visual_root, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tween.tween_callback(queue_free)


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		var kind: StringName = area.get_meta("hit_kind", &"")
		take_damage(area.get_meta("damage"), area.get_parent(), kind)
		if area.has_meta("stagger") and not _is_dead:
			add_stagger(float(area.get_meta("stagger")))


func _on_aggro_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_target = body
		if ai_state == AIState.IDLE:
			ai_state = AIState.CHASE
			_show_health_bar()
			Events.enemy_aggro_triggered.emit(self)


# --- AI States ---

func _process_idle(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _process_chase(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		ai_state = AIState.IDLE
		return

	var dist := global_position.distance_to(_target.global_position)

	# Lost interest
	if dist > aggro_range * 1.5:
		_target = null
		ai_state = AIState.IDLE
		return

	# In attack range and cooldown ready
	if dist < attack_range and _attack_cooldown_timer <= 0.0:
		_enter_attack_telegraph()
		return

	# Navigate toward target — use direct steering (no nav mesh dependency)
	var direction: Vector3 = (_target.global_position - global_position)
	direction.y = 0.0
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		# Face movement direction
		basis = basis.slerp(Basis.looking_at(direction), clampf(8.0 * delta, 0.0, 1.0))
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _enter_attack_telegraph() -> void:
	ai_state = AIState.ATTACK_TELEGRAPH
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _process_attack_telegraph(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	# Face the target during wind-up
	if _target and is_instance_valid(_target):
		var dir: Vector3 = (_target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			basis = basis.slerp(Basis.looking_at(dir.normalized()), clampf(12.0 * delta, 0.0, 1.0))

	if _state_timer >= attack_telegraph:
		_enter_attack_strike()


func _enter_attack_strike() -> void:
	_rigless_cue(&"attack")
	ai_state = AIState.ATTACK_STRIKE
	_state_timer = 0.0
	_enable_attack_hitbox()


func _process_attack_strike(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_active:
		_disable_attack_hitbox()
		ai_state = AIState.ATTACK_RECOVERY
		_state_timer = 0.0


func _process_attack_recovery(delta: float) -> void:
	_state_timer += delta
	velocity.x = 0.0
	velocity.z = 0.0

	if _state_timer >= attack_recovery:
		_attack_cooldown_timer = attack_cooldown
		ai_state = AIState.CHASE


func _enter_hurt() -> void:
	_disable_attack_hitbox()
	ai_state = AIState.HURT
	_state_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	# Flash red on hit
	_flash_color(Color(1.0, 0.5, 0.5, 1.0), 0.15)


func _process_hurt(delta: float) -> void:
	_state_timer += delta
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)

	if _state_timer >= stagger_duration:
		ai_state = AIState.CHASE


# --- Attack Hitbox ---

func _enable_attack_hitbox() -> void:
	attack_hitbox_shape.disabled = false
	var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
	hitbox_area.set_meta("damage", attack_damage)
	_hit_active = true


func _disable_attack_hitbox() -> void:
	if _hit_active:
		attack_hitbox_shape.set_deferred("disabled", true)
		var hitbox_area: Area3D = attack_hitbox_shape.get_parent()
		if hitbox_area.has_meta("damage"):
			hitbox_area.remove_meta("damage")
		_hit_active = false


# --- Visual Feedback ---

func _flash_color(color: Color, duration: float) -> void:
	var mesh: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D")
	if mesh == null or mesh.material_override == null:
		return
	mesh.material_override.albedo_color = color
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(mesh) and mesh.material_override:
			mesh.material_override.albedo_color = STAGGER_TINT if is_staggered() else _original_color
	)


func _set_body_color(color: Color) -> void:
	var mesh: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D") if visual_root else null
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = color


# --- Overhead Health Bar (Lumina Frost style, R5b) ---
# A thin cyan->red HP strip on a dark glass backing, plus a hairline orange
# stagger strip under it. All quads billboard; fills shrink from the right via
# QuadMesh.center_offset (applied in billboard space, so it stays left-aligned
# from any camera angle).

func _make_bar_quad(width: float, height: float, color: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = priority
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_health_bar() -> void:
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBar"
	_health_bar_root.position = Vector3(0, HEALTH_BAR_Y_OFFSET, 0)
	add_child(_health_bar_root)

	# Dark glass backing (covers HP + stagger strips, with a small border).
	var back_h := HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT + HEALTH_BAR_BORDER * 2.0 + 0.01
	_health_bar_bg = _make_bar_quad(HEALTH_BAR_WIDTH + HEALTH_BAR_BORDER * 2.0, back_h,
		UIStyle.GLASS_DEEP, 1)
	var bg_quad: QuadMesh = _health_bar_bg.mesh
	bg_quad.center_offset = Vector3(0, -(STAGGER_BAR_HEIGHT + 0.01) * 0.5, 0)
	_health_bar_root.add_child(_health_bar_bg)

	# HP fill.
	_health_bar_fill = _make_bar_quad(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT, UIStyle.CYAN, 2)
	_health_bar_root.add_child(_health_bar_fill)

	# Stagger fill (orange hairline under the HP strip). Empty = invisible.
	_stagger_bar_fill = _make_bar_quad(HEALTH_BAR_WIDTH, STAGGER_BAR_HEIGHT, UIStyle.STAGGER, 2)
	var st_quad: QuadMesh = _stagger_bar_fill.mesh
	st_quad.center_offset = Vector3(0, -(HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT) * 0.5 - 0.01, 0)
	_stagger_bar_fill.visible = false
	_health_bar_root.add_child(_stagger_bar_fill)

	# Start hidden — shows when enemy aggros or is hit
	_health_bar_root.visible = false


func _show_health_bar() -> void:
	if _health_bar_root and not _health_bar_visible:
		_health_bar_visible = true
		_health_bar_root.visible = true
		_update_health_bar()
		_update_stagger_bar()


func _hide_health_bar() -> void:
	if _health_bar_root:
		_health_bar_visible = false
		_health_bar_root.visible = false


## Cyan at full HP -> stagger orange at half -> danger red when low.
static func hp_bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return UIStyle.STAGGER.lerp(UIStyle.CYAN, (ratio - 0.5) * 2.0)
	if ratio > 0.25:
		return UIStyle.DANGER.lerp(UIStyle.STAGGER, (ratio - 0.25) * 4.0)
	return UIStyle.DANGER


func _set_bar_fill(bar: MeshInstance3D, ratio: float, height: float, base_y: float) -> void:
	var quad: QuadMesh = bar.mesh as QuadMesh
	var w: float = maxf(HEALTH_BAR_WIDTH * ratio, 0.001)
	quad.size = Vector2(w, height)
	quad.center_offset = Vector3((w - HEALTH_BAR_WIDTH) * 0.5, base_y, 0)


func _update_health_bar() -> void:
	if _health_bar_fill == null or not _health_bar_visible:
		return
	var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	_set_bar_fill(_health_bar_fill, ratio, HEALTH_BAR_HEIGHT, 0.0)
	var fill_mat: StandardMaterial3D = _health_bar_fill.material_override
	var c := hp_bar_color(ratio)
	fill_mat.albedo_color = Color(c.r, c.g, c.b, 0.95)


func _update_stagger_bar() -> void:
	if _stagger_bar_fill == null or not _health_bar_visible:
		return
	var ratio := clampf(stagger_value / maxf(stagger_max, 1.0), 0.0, 1.0)
	_stagger_bar_fill.visible = ratio > 0.001
	if not _stagger_bar_fill.visible:
		return
	_set_bar_fill(_stagger_bar_fill, ratio, STAGGER_BAR_HEIGHT,
		-(HEALTH_BAR_HEIGHT + STAGGER_BAR_HEIGHT) * 0.5 - 0.01)
	var mat: StandardMaterial3D = _stagger_bar_fill.material_override
	mat.albedo_color = UIStyle.ATB_FULL if is_staggered() else UIStyle.STAGGER


# --- Floating Damage Numbers (UIStyle body font, R5b) ---
# White with a dark outline; gold for blasts / finishers; orange while staggered.

const DMG_COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)

func _spawn_damage_number(amount: float, hit_kind: StringName = &"", staggered: bool = false) -> void:
	if not SettingsManager.show_damage_numbers:
		return

	var big := hit_kind == &"blast" or hit_kind == &"finisher"
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.font = UIStyle.font_body_bold()
	label.font_size = 60 if big else 48
	label.outline_size = 12
	if big:
		label.modulate = UIStyle.GOLD
	elif staggered:
		label.modulate = UIStyle.STAGGER
	else:
		label.modulate = DMG_COLOR_NORMAL
	label.outline_modulate = Color(0.02, 0.04, 0.07, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 5
	label.pixel_size = 0.01

	# Spawn slightly above the enemy with random horizontal offset
	var spawn_offset := Vector3(
		randf_range(-0.3, 0.3),
		HEALTH_BAR_Y_OFFSET + 0.3,
		randf_range(-0.1, 0.1)
	)
	# Add to scene root (not enemy child — survives enemy death briefly).
	# Must be in the tree before global_position can be set.
	if not is_inside_tree() or get_tree().current_scene == null:
		label.free()
		return
	get_tree().current_scene.add_child(label)
	label.global_position = global_position + spawn_offset

	# Animate: float up, scale pop, then fade out
	label.scale = Vector3(0.5, 0.5, 0.5)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "scale", Vector3.ONE * (1.25 if big else 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)
