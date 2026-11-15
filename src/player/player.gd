## Player character controller.
## Designed as CharacterBase for future party member extension.
extends CharacterBody3D

@export var gravity: float = 30.0

@onready var state_machine: Node = $StateMachine
@onready var visual_root: Node3D = $VisualRoot
@onready var model: Node3D = $VisualRoot/Model
var anim_player: AnimationPlayer = null
@onready var hurtbox: Area3D = $Hurtbox
@onready var hitbox_anchor: Node3D = $HitboxAnchor
@onready var hitbox: Area3D = $HitboxAnchor/Hitbox
@onready var hitbox_shape: CollisionShape3D = $HitboxAnchor/Hitbox/CollisionShape3D
@onready var camera_anchor: Node3D = $CameraAnchor
@onready var interaction_anchor: Area3D = $InteractionAnchor
@onready var lock_on_component: LockOnComponent = $LockOnComponent
@onready var ability_system: Node = $AbilitySystem
@onready var inventory_system: Node = $InventorySystem
@onready var equipment_system: Node = $EquipmentSystem
@onready var quest_system: Node = $QuestSystem
var party_system: Node = null  # Assigned by zone/arena after spawn

# Battle system v3 components (Package Q). Stubs until R (combo) / S (stance).
@onready var battle_mode: BattleModeComponent = get_node_or_null(^"BattleModeComponent")
@onready var combo: ComboComponent = get_node_or_null(^"ComboComponent")
@onready var stance: StanceComponent = get_node_or_null(^"StanceComponent")
## Fallback PartyMemberData when no PartySystem lists this node (test scenes).
const DEFAULT_MEMBER_DATA_PATH := "res://resources/characters/hero.tres"
var _default_member_data: Resource = null

## Read-only: true while in Battle Mode (owned by BattleModeComponent).
var in_battle: bool:
	get:
		return battle_mode != null and battle_mode.in_battle

var is_locked_on: bool = false
var lock_on_target: Node3D = null
var dodge_ready: bool = true
var _dodge_cooldown_timer: float = 0.0
@export var dodge_cooldown_time: float = 0.45

# Jump parameters (owned here so Jump/Fall and future Carry states share them)
@export var jump_force: float = 12.0
## Second (air) jump sets velocity.y to this value. It must be >= the rising
## speed right after takeoff, otherwise a quick Y-Y press barely changes the arc
## (v1 used jump_force * 0.85 = 10.2 < 12, which felt like "not registering").
@export var double_jump_force: float = 12.0
@export var air_control: float = 5.0
@export var air_move_speed: float = 8.0

# Sprint (Run) — ground speed multiplier while `sprint` is held in free locomotion.
@export var sprint_multiplier: float = 1.6
var _sprinting: bool = false
## Read-only: true while Run (or a state that opts in) is applying sprint speed.
var is_sprinting: bool:
	get:
		return _sprinting

# Jump buffering
var jump_buffer_time: float = 0.12
var _jump_buffer_timer: float = 0.0

# Ledge detection
@onready var chest_ray: RayCast3D = $LedgeDetector/ChestRay
@onready var head_ray: RayCast3D = $LedgeDetector/HeadRay
var _ledge_surface_y: float = 0.0
var _ledge_wall_point: Vector3 = Vector3.ZERO
var _ledge_wall_normal: Vector3 = Vector3.ZERO

# Interaction detection
var _nearby_interactables: Array[Node3D] = []
var _current_interactable: Node3D = null
# Hold-to-interact (v7): an interactable with requires_hold() fires only after
# `interact` is held for its hold_duration. Progress goes out on
# Events.interaction_hold_progress (ratio 0..1; -1 = cancelled) for the HUD.
var _hold_target: Node3D = null
var _hold_time: float = 0.0
## Action whose button started the hold (v8: pad A = `jump`, keyboard E = `interact`).
var _hold_action: StringName = &"interact"

# Fall recovery (v7): a safety net under ZoneBounds. Below fall_reset_y the
# player is put back on the last floor position it stood on.
@export var fall_reset_y: float = -20.0
var _last_safe_position: Vector3 = Vector3.INF

# Combat flag (informational; kept for tests/legacy callers — input routing
# uses `in_battle`). True if an encounter owner emitted Events.combat_started,
# OR Battle Mode is on, OR any enemy is currently engaged (not IDLE/DEAD).
# Read-only query of the public enemy ai_state; never mutates enemy state.
var _combat_signal_active: bool = false
var is_in_combat: bool:
	get:
		return _combat_signal_active or in_battle or _any_enemy_engaged()

# Traversal abilities
# Unlocked by default for now; tie to progression later (item 481).
var has_double_jump: bool = true
var _double_jump_used: bool = false
# Set by try_double_jump() so JumpState.enter() keeps the air-jump velocity
# instead of re-applying the ground jump_force.
var _air_jump_pending: bool = false

# Free-locomotion states where an `interact` press may fire an interaction.
# Any other state (TacticalIdle, Ability, Dodge, attacks, Carry, ThrowAim...)
# owns its own input, so a shared button (B = interact + ui_cancel) can't leak.
const INTERACT_STATES: Array[StringName] = [&"Idle", &"Run", &"LockOnIdle", &"LockOnStrafe"]

var current_hp: float = 100.0
var max_hp: float = 100.0
var current_mp: float = 50.0
var max_mp: float = 50.0
var max_atb: float = 100.0
# Start with a full ATB gauge (user request 2026-11-12). It drains and refills as normal.
var current_atb: float = max_atb
var atb_fill_rate: float = 5.0

# MP regen
var mp_regen_rate: float = 1.5  # MP per second (passive regen)
var mp_regen_delay: float = 2.0  # Seconds after spending MP before regen starts
var _mp_regen_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"player")
	_apply_member_visual(get_member_data())
	_setup_model()
	state_machine.initialize(self)
	ability_system.initialize(self)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	Events.lock_on_target_acquired.connect(_on_lock_on_acquired)
	Events.lock_on_target_switched.connect(_on_lock_on_switched)
	Events.lock_on_target_lost.connect(_on_lock_on_lost)
	Events.combat_started.connect(_on_combat_started)
	Events.combat_ended.connect(_on_combat_ended)
	if battle_mode:
		battle_mode.changed.connect(_on_battle_mode_changed)
	Events.player_spawned.emit(self)
	# Push the starting (full) ATB to the HUD once it exists; the regen loop
	# only emits while below max, so the HUD would otherwise show 0.
	Events.player_atb_changed.emit.call_deferred(current_atb, max_atb)

	# Interaction detection
	interaction_anchor.area_entered.connect(_on_interactable_entered)
	interaction_anchor.area_exited.connect(_on_interactable_exited)

	# Equip the starting member's command list (hero.tres default_abilities, or
	# the legacy Fire Bolt / Ice Freeze / Heal set while that list is empty).
	_equip_ability_list(_starting_abilities(get_member_data()))

	# Illegal transitions per design contract
	state_machine.add_illegal_transition(&"Ability", &"Dodge")
	state_machine.add_illegal_transition(&"Flinch", &"TacticalIdle")
	state_machine.add_illegal_transition(&"Flinch", &"Attack1")
	state_machine.add_illegal_transition(&"LedgeGrab", &"Attack1")
	state_machine.add_illegal_transition(&"ClimbUp", &"Attack1")
	# v3 MeleeStrike mirrors Attack1's rules
	state_machine.add_illegal_transition(&"Flinch", &"MeleeStrike")
	state_machine.add_illegal_transition(&"LedgeGrab", &"MeleeStrike")
	state_machine.add_illegal_transition(&"ClimbUp", &"MeleeStrike")

	# Block tactical mode from forced/locked states (items 167-170)
	for blocked_state in [&"Dodge", &"DodgeReady", &"Focus", &"AirDodge", &"Ability", &"LedgeGrab", &"ClimbUp",
			&"JumpAttack", &"Attack1", &"Attack2", &"Attack3", &"MeleeStrike", &"Land"]:
		state_machine.add_illegal_transition(blocked_state, &"TacticalIdle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump buffer countdown
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	# Dodge cooldown
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
		if _dodge_cooldown_timer <= 0.0:
			dodge_ready = true

	# ATB fills over time during combat
	if current_atb < max_atb:
		var old_atb := current_atb
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)
		# Only emit when crossing a visible threshold (1% of max) to avoid per-frame signal spam
		if int(current_atb) != int(old_atb) or current_atb >= max_atb:
			Events.player_atb_changed.emit(current_atb, max_atb)

	# MP passive regen after delay
	if _mp_regen_timer > 0.0:
		_mp_regen_timer -= delta
	elif current_mp < max_mp:
		var old_mp := current_mp
		current_mp = minf(current_mp + mp_regen_rate * delta, max_mp)
		# Only emit when value visibly changes (integer part) to reduce signal noise
		if int(current_mp) != int(old_mp) or current_mp >= max_mp:
			Events.player_mp_changed.emit(current_mp, max_mp)

	move_and_slide()

	# Reset the air jump only on a real landing: checked AFTER move_and_slide()
	# (so is_on_floor() is this frame's result, not last frame's stale value on
	# the takeoff frame) and only when not moving upward.
	if is_on_floor() and velocity.y <= 0.0:
		_double_jump_used = false
		_air_jump_pending = false
		_last_safe_position = global_position
	elif global_position.y < fall_reset_y:
		recover_from_fall()

	_update_interact_hold(delta)


## Puts the player back on the last floor it stood on (fell out of the world).
## Returns false when there is no safe position yet (nothing to restore).
func recover_from_fall() -> bool:
	if not _last_safe_position.is_finite():
		return false
	global_position = _last_safe_position + Vector3(0.0, 0.3, 0.0)
	velocity = Vector3.ZERO
	return true


## Read-only: last floor position (Vector3.INF before the first landing).
func get_last_safe_position() -> Vector3:
	return _last_safe_position


func take_damage(amount: float, source: Node3D = null) -> void:
	current_hp = maxf(current_hp - amount, 0.0)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_hurt.emit(amount, source)
	disable_hitbox()
	state_machine.force_transition(&"Flinch")
	GameManager.hit_stop(65.0)
	Events.camera_shake_requested.emit(0.15, 0.2)

	_rigless_cue(&"hit")
	if current_hp <= 0.0:
		Events.player_died.emit()


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_healed.emit(amount)


func has_mp(cost: float) -> bool:
	return current_mp >= cost


func spend_mp(cost: float) -> void:
	current_mp = maxf(current_mp - cost, 0.0)
	_mp_regen_timer = mp_regen_delay
	Events.player_mp_changed.emit(current_mp, max_mp)


func has_atb(cost: float) -> bool:
	return current_atb >= cost


func spend_atb(cost: float) -> void:
	current_atb = maxf(current_atb - cost, 0.0)
	Events.player_atb_changed.emit(current_atb, max_atb)


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		take_damage(area.get_meta("damage"), area.get_parent())


func buffer_jump() -> void:
	_jump_buffer_timer = jump_buffer_time


func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0


func consume_jump_buffer() -> void:
	_jump_buffer_timer = 0.0


## True if an air jump is available right now.
func can_double_jump() -> bool:
	return has_double_jump and not _double_jump_used and not is_on_floor()


## Perform the air jump if available. Returns true if it fired. Callers in the
## air (Jump/Fall/Carry) should transition to/stay in Jump on true.
func try_double_jump() -> bool:
	if not can_double_jump():
		return false
	_double_jump_used = true
	_air_jump_pending = true
	velocity.y = double_jump_force
	return true


## Consumed by JumpState.enter(): true if the entry was an air jump (velocity
## already set by try_double_jump), false for a ground jump.
func consume_air_jump_pending() -> bool:
	var pending := _air_jump_pending
	_air_jump_pending = false
	return pending


## Sprint input query (action-based; works for any binding of `sprint`).
func wants_sprint() -> bool:
	return InputMap.has_action(&"sprint") and Input.is_action_pressed(&"sprint")


## Set by locomotion states that apply sprint speed (Run; later Carry).
func set_sprinting(value: bool) -> void:
	_sprinting = value


func can_grab_ledge() -> bool:
	if not chest_ray.is_colliding() or head_ray.is_colliding():
		return false

	_ledge_wall_point = chest_ray.get_collision_point()
	_ledge_wall_normal = chest_ray.get_collision_normal()

	# Raycast down from above the wall hit to find the actual ledge surface
	var space := get_world_3d().direct_space_state
	var ray_start: Vector3 = _ledge_wall_point + Vector3(0, 4.0, 0) - _ledge_wall_normal * 0.3
	var ray_end: Vector3 = _ledge_wall_point + Vector3(0, -0.5, 0) - _ledge_wall_normal * 0.3
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false

	_ledge_surface_y = result["position"].y

	# Check if ledge height is within grab range relative to player
	var ledge_height: float = _ledge_surface_y - global_position.y
	return ledge_height >= 0.5 and ledge_height <= 3.5


func get_ledge_snap_position() -> Vector3:
	# Hang position: back from wall, player center below ledge surface
	var hang_pos: Vector3 = _ledge_wall_point + _ledge_wall_normal * 0.4
	hang_pos.y = _ledge_surface_y - 1.6
	return hang_pos


func get_ledge_climb_position() -> Vector3:
	# Top of ledge: past the wall edge, standing on surface
	var top_pos: Vector3 = _ledge_wall_point - _ledge_wall_normal * 0.6
	top_pos.y = _ledge_surface_y + 0.1
	return top_pos


func start_dodge_cooldown() -> void:
	dodge_ready = false
	_dodge_cooldown_timer = dodge_cooldown_time


func enable_hitbox(damage: float) -> void:
	hitbox.set_meta("damage", damage)
	hitbox_shape.set_deferred("disabled", false)


func disable_hitbox() -> void:
	hitbox_shape.set_deferred("disabled", true)
	if hitbox.has_meta("damage"):
		hitbox.remove_meta("damage")


func face_lock_target(delta: float) -> void:
	if lock_on_target == null or not is_instance_valid(lock_on_target):
		return
	var dir: Vector3 = (lock_on_target.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		var target_basis := Basis.looking_at(dir.normalized())
		basis = basis.slerp(target_basis, clampf(10.0 * delta, 0.0, 1.0))


func _on_lock_on_acquired(target: Node3D) -> void:
	is_locked_on = true
	lock_on_target = target


func _on_lock_on_switched(new_target: Node3D) -> void:
	lock_on_target = new_target


func _on_lock_on_lost() -> void:
	is_locked_on = false
	lock_on_target = null


# --- Interaction Detection ---

func _on_interactable_entered(area: Area3D) -> void:
	if not area.is_in_group(&"interactable"):
		return
	if area.has_method("is_active") and not area.is_active():
		return
	if not _nearby_interactables.has(area):
		_nearby_interactables.append(area)
	_update_nearest_interactable()


func _on_interactable_exited(area: Area3D) -> void:
	_nearby_interactables.erase(area)
	_update_nearest_interactable()


func _update_nearest_interactable() -> void:
	# Remove invalid entries
	_nearby_interactables = _nearby_interactables.filter(
		func(n: Node3D) -> bool:
			return is_instance_valid(n) and n.is_in_group(&"interactable") \
				and (not n.has_method("is_active") or n.is_active())
	)

	if _nearby_interactables.is_empty():
		if _current_interactable != null:
			_current_interactable = null
			Events.interaction_cleared.emit()
		return

	# Pick best: highest interact_priority, then nearest
	var best: Node3D = _nearby_interactables[0]
	var best_priority: int = best.interact_priority if "interact_priority" in best else 0
	var best_dist: float = global_position.distance_squared_to(best.global_position)

	for i in range(1, _nearby_interactables.size()):
		var candidate: Node3D = _nearby_interactables[i]
		var c_priority: int = candidate.interact_priority if "interact_priority" in candidate else 0
		var c_dist: float = global_position.distance_squared_to(candidate.global_position)
		if c_priority > best_priority or (c_priority == best_priority and c_dist < best_dist):
			best = candidate
			best_priority = c_priority
			best_dist = c_dist

	if best != _current_interactable:
		_current_interactable = best
		Events.interaction_available.emit(best)


func _on_combat_started() -> void:
	_combat_signal_active = true


func _any_enemy_engaged() -> bool:
	if not is_inside_tree():
		return false
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		var e := enemy as EnemyBase
		if e == null or not is_instance_valid(e):
			continue
		if e.ai_state != EnemyBase.AIState.IDLE and e.ai_state != EnemyBase.AIState.DEAD:
			return true
	return false


func _on_combat_ended() -> void:
	_combat_signal_active = false


## True when a valid, active interactable is currently targeted.
func has_interactable() -> bool:
	if _current_interactable == null or not is_instance_valid(_current_interactable):
		return false
	if _current_interactable.has_method("is_active") and not _current_interactable.is_active():
		return false
	return _current_interactable.has_method("interact")


## Read-only: the interactable currently targeted (null if none/invalid).
## Used by cosmetic listeners (RiglessVisual NPC face-the-speaker, v6 JJ-2).
func get_current_interactable() -> Node3D:
	if _current_interactable == null or not is_instance_valid(_current_interactable):
		return null
	return _current_interactable


## True when the current interactable wants `interact` held (v7).
func current_interact_needs_hold() -> bool:
	return has_interactable() and _current_interactable.has_method("requires_hold") 		and _current_interactable.requires_hold()


## True while a hold-to-interact is charging.
func is_holding_interact() -> bool:
	return _hold_target != null


func _start_interact_hold(action: StringName = &"interact") -> void:
	_hold_target = _current_interactable
	_hold_action = action
	_hold_time = 0.0
	Events.interaction_hold_progress.emit(_hold_target, 0.0)


func _cancel_interact_hold() -> void:
	if _hold_target == null:
		return
	var t := _hold_target
	_hold_target = null
	_hold_time = 0.0
	if is_instance_valid(t):
		Events.interaction_hold_progress.emit(t, -1.0)


## Advances a hold-to-interact. Cancels on release, a target change, Battle
## Mode or any state where interacting is not allowed.
func _update_interact_hold(delta: float) -> void:
	if _hold_target == null:
		return
	if not is_instance_valid(_hold_target) or _hold_target != _current_interactable 			or not has_interactable() or in_battle or not can_interact_now() 			or not Input.is_action_pressed(_hold_action):
		_cancel_interact_hold()
		return
	var duration := 0.6
	if "hold_duration" in _hold_target:
		duration = maxf(float(_hold_target.get(&"hold_duration")), 0.05)
	_hold_time += delta
	var ratio := clampf(_hold_time / duration, 0.0, 1.0)
	Events.interaction_hold_progress.emit(_hold_target, ratio)
	if ratio >= 1.0:
		_hold_target = null
		_hold_time = 0.0
		try_interact()


## Interact with the current interactable. Returns true if an interaction fired.
## (Fires immediately, hold or not: the hold gate lives in input handling.)
func try_interact() -> bool:
	if not has_interactable():
		return false
	_current_interactable.interact(self)
	return true


## True while a dialogue box is open (public DialogueUI API, looked up by group).
func is_dialogue_active() -> bool:
	if not is_inside_tree():
		return false
	for ui in get_tree().get_nodes_in_group(&"dialogue_ui"):
		if ui.has_method("is_dialogue_active") and ui.is_dialogue_active():
			return true
	return false


# --- Battle v3 input routing (Package Q) ---
# InputMap actions are PHYSICAL-ROLE actions (jump = A/Space, interact = Y/E,
# tactical_mode = Q only, unique_ability = R only). These helpers translate a
# press into its meaning for the current mode. Every state must use them; no
# state may hardcode the mode logic. All return false for echo events and while
# a dialogue box is open (the dialogue owns the press; this preserves the v2
# handle_contextual_command gate).

## v8 controller layout (Free Roam):
##   A = context button: interacts while a prompt is up and the player is in a
##       free-locomotion state, otherwise jumps (air jumps always jump).
##   Y = Command Menu (always; it no longer interacts).
## Keyboard is unchanged: Space jumps, E interacts (Command with no prompt), Q
## opens the Command Menu. Battle is unchanged on both: A / Q = Command Menu
## (no jumping), Y / R = the member's unique ability.

## True for presses coming from a gamepad button (A/B/X/Y...).
static func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton


## True when a pad A press right now would interact instead of jumping.
func pad_a_interacts() -> bool:
	return not in_battle and has_interactable() and can_interact_now()


## Command Menu: `tactical_mode` (Q) in either mode, OR `jump` (A) in battle,
## OR in free roam: pad Y always, keyboard E when nothing is targeted.
func is_command_press(event: InputEvent) -> bool:
	if is_dialogue_active():
		return false
	if event.is_action_pressed(&"tactical_mode"):
		return true
	if in_battle:
		return event.is_action_pressed(&"jump")
	if not event.is_action_pressed(&"interact"):
		return false
	return is_pad_event(event) or not has_interactable()


## Jump: `jump` (A/Space) in free roam only. Does nothing in battle. On a pad,
## A interacts instead while a prompt is up in a free-locomotion state.
func is_jump_press(event: InputEvent) -> bool:
	if in_battle or is_dialogue_active():
		return false
	if not event.is_action_pressed(&"jump"):
		return false
	return not (is_pad_event(event) and pad_a_interacts())


## Interact: free roam with an interactable targeted, from pad A or keyboard E.
## (Whether the current state allows it is can_interact_now()'s job.)
func is_interact_press(event: InputEvent) -> bool:
	if in_battle or is_dialogue_active() or not has_interactable():
		return false
	if is_pad_event(event):
		return event.is_action_pressed(&"jump")
	return event.is_action_pressed(&"interact")


## The action an interact press came from (polled while a hold-interaction charges).
static func interact_action_of(event: InputEvent) -> StringName:
	return &"jump" if is_pad_event(event) and event.is_action(&"jump") else &"interact"


## Unique ability: `unique_ability` (R) in battle, OR `interact` (Y/E) in battle.
func is_unique_press(event: InputEvent) -> bool:
	if not in_battle or is_dialogue_active():
		return false
	return event.is_action_pressed(&"unique_ability") or event.is_action_pressed(&"interact")


## True while a unique-ability button (R, or Y/E) is held (channel abilities).
func is_unique_held() -> bool:
	return Input.is_action_pressed(&"unique_ability") or Input.is_action_pressed(&"interact")


## Battle toggle (v4): `battle_toggle` (View/Back on pad, F on keyboard) in
## either mode. Gating lives in can_toggle_battle().
func is_battle_toggle_press(event: InputEvent) -> bool:
	if is_dialogue_active():
		return false
	return event.is_action_pressed(&"battle_toggle")


## True when a manual Battle/Free Roam toggle may fire: gameplay running (no
## pause/menu, tactical menu, cutscene or game over), no dialogue, alive, and not
## carrying or aiming a throw.
func can_toggle_battle() -> bool:
	if battle_mode == null:
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if is_dialogue_active() or current_hp <= 0.0:
		return false
	var carry := get_node_or_null(^"CarryComponent")
	if carry and bool(carry.get(&"is_carrying")):
		return false
	var cur: Node = state_machine.current_state if state_machine else null
	if cur != null and StringName(cur.name) in [&"Carry", &"ThrowAim"]:
		return false
	return true


## DEPRECATED (v2 shim): kept only so the pre-T states keep compiling. Returns
## true while a dialogue is open. T replaces its callers with is_command_press().
func handle_contextual_command(_event: InputEvent) -> bool:
	return is_dialogue_active()


## Transition the state machine to `target`, honouring illegal transitions.
## Returns true if the transition happened. For time-driven entries that don't
## come from a state's return value (ComboComponent heavy-at-threshold, stance).
func request_transition(target: StringName, msg: Dictionary = {}) -> bool:
	if state_machine == null or not state_machine.states.has(target):
		return false
	var cur: Node = state_machine.current_state
	if cur and state_machine._is_illegal_transition(cur.name, target):
		return false
	state_machine._transition(target, msg)
	return true


## PartyMemberData of this character: the PartySystem entry whose node is this
## player, else hero.tres. Never null unless hero.tres is missing.
func get_member_data() -> Resource:
	if party_system and "members" in party_system:
		for m in party_system.members:
			if m is Dictionary and m.get("node") == self and m.get("data") != null:
				return m["data"]
	if _default_member_data == null:
		_default_member_data = load(DEFAULT_MEMBER_DATA_PATH)
	return _default_member_data


# --- v5 party switch: identity swap (Package CC) ---
# PartySystem swaps IDENTITIES, not bodies: this Player node stays the input
# body the camera follows; switching exchanges member data, HP/MP/ATB, command
# list and visual model with the CompanionAI body (and their positions/facing).
# Camera, lock-on, battle mode and state ownership never move.

## States from which a party switch may fire (everything else is blocked:
## dodge, casts, attacks, flinch, ledge, carry/throw, tactical menu...).
const SWITCH_STATES: Array[StringName] = [&"Idle", &"Run", &"Jump", &"Fall",
	&"Land", &"LockOnIdle", &"LockOnStrafe"]


## True when the controlled member may hand over control right now.
func can_party_switch() -> bool:
	if current_hp <= 0.0 or is_dialogue_active():
		return false
	var carry := get_node_or_null(^"CarryComponent")
	if carry and bool(carry.get(&"is_carrying")):
		return false
	var cur: Node = state_machine.current_state if state_machine else null
	return cur != null and StringName(cur.name) in SWITCH_STATES


## Snapshot of the controlled member's live state (handed to the other body).
func export_member_state() -> Dictionary:
	return {
		"hp": current_hp, "max_hp": max_hp,
		"mp": current_mp, "max_mp": max_mp,
		"atb": current_atb, "max_atb": max_atb,
		"atb_fill_rate": atb_fill_rate, "mp_regen_rate": mp_regen_rate,
		"abilities": ability_system.equipped_abilities.duplicate() if ability_system else [],
		"downed": false,
	}


## Become member `data` with `state` (from CompanionAI.export_member_state()).
## Stance exits, the combo resets, the unique ability is re-resolved and the
## state machine drops to a neutral state. Lock-on and battle mode are kept.
func import_member_state(data: Resource, state: Dictionary) -> void:
	if stance and stance.is_active():
		stance.exit_stance(&"party_switch")
	if combo:
		combo.reset(&"party_switch")
	disable_hitbox()
	max_hp = state.get("max_hp", max_hp)
	max_mp = state.get("max_mp", max_mp)
	max_atb = state.get("max_atb", max_atb)
	atb_fill_rate = state.get("atb_fill_rate", atb_fill_rate)
	mp_regen_rate = state.get("mp_regen_rate", mp_regen_rate)
	current_hp = clampf(state.get("hp", max_hp), 0.0, max_hp)
	current_mp = clampf(state.get("mp", max_mp), 0.0, max_mp)
	current_atb = clampf(state.get("atb", 0.0), 0.0, max_atb)
	_mp_regen_timer = 0.0
	var list: Array = state.get("abilities", [])
	if list.is_empty():
		list = _starting_abilities(data)
	_equip_ability_list(list)
	if stance:
		stance.refresh_ability()
	velocity = Vector3.ZERO
	consume_jump_buffer()
	if state_machine and state_machine.current_state:
		state_machine.force_transition(&"LockOnIdle" if is_locked_on else &"Idle")
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_mp_changed.emit(current_mp, max_mp)
	Events.player_atb_changed.emit(current_atb, max_atb)


## v5 EE: a rigless member replaces the authored model with a RiglessVisual
## (dormant until a .tres sets rigless + model_scene).
func _apply_member_visual(data: Resource) -> void:
	if data == null or not data.has_method("make_rigless_visual"):
		return
	var rv: Node3D = data.make_rigless_visual()
	if rv == null:
		return
	for c in visual_root.get_children():
		visual_root.remove_child(c)
		c.queue_free()
	visual_root.add_child(rv)
	model = rv


## Cosmetic RiglessVisual cue (&"attack", &"dodge", &"hit"...). No-op otherwise.
func _rigless_cue(cue: StringName) -> void:
	var rv: Node = visual_root.get_node_or_null(^"RiglessVisual") if visual_root else null
	if rv and rv.has_method(&"play_cue"):
		rv.play_cue(cue)


## Re-resolve `model` / `anim_player` after PartySystem exchanged the child of
## $VisualRoot (the member's model travels with the identity).
func refresh_visual() -> void:
	model = visual_root.get_child(0) if visual_root.get_child_count() > 0 else null
	anim_player = _find_child_of_type(model, "AnimationPlayer") as AnimationPlayer if model else null


## Vertical launch into Jump (Super Jump etc.): sets velocity.y = `vy`, adds
## `forward_carry` m/s along facing and enters Jump without re-applying
## jump_force. Returns false if Jump is illegal from the current state.
func launch_jump(vy: float, forward_carry: float = 0.0) -> bool:
	var cur: Node = state_machine.current_state if state_machine else null
	if cur and state_machine._is_illegal_transition(cur.name, &"Jump"):
		return false
	prepare_launch(vy, forward_carry)
	if not request_transition(&"Jump"):
		_air_jump_pending = false
		return false
	return true


## Sets the launch velocity (vy up + forward_carry along facing) and flags it so
## the next JumpState.enter() keeps it. The caller enters Jump (v8: the Ability
## state returns &"Jump" for a LAUNCH command such as Super Jump).
func prepare_launch(vy: float, forward_carry: float = 0.0) -> void:
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	velocity.x += fwd.x * forward_carry
	velocity.z += fwd.z * forward_carry
	velocity.y = vy
	_air_jump_pending = true  # JumpState.enter() keeps our velocity.y


## Restores MP (v8: Arcane Focus channel). Clamped to max; resets nothing else.
func restore_mp(amount: float) -> void:
	if amount <= 0.0:
		return
	var old := current_mp
	current_mp = minf(current_mp + amount, max_mp)
	if int(current_mp) != int(old) or current_mp >= max_mp:
		Events.player_mp_changed.emit(current_mp, max_mp)


func _starting_abilities(data: Resource) -> Array:
	if data and data.has_method("get_starting_abilities"):
		return data.get_starting_abilities()
	return []


func _equip_ability_list(list: Array) -> void:
	if ability_system == null:
		return
	ability_system.equipped_abilities.clear()
	for i in list.size():
		var a := list[i] as AbilityData
		if a:
			ability_system.equip_ability(a, i)


func _on_battle_mode_changed(value: bool) -> void:
	# Entering battle drops a carried crate (pick-up is free-roam only).
	if value:
		var carry := get_node_or_null(^"CarryComponent")
		if carry and carry.has_method("drop") and carry.is_carrying:
			carry.drop(&"forced")


## True when an `interact` press may fire: gameplay running (not tactical,
## paused, cutscene...), no dialogue open, and in a free-locomotion state.
func can_interact_now() -> bool:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return false
	if is_dialogue_active():
		return false
	var cur: Node = state_machine.current_state if state_machine else null
	return cur != null and StringName(cur.name) in INTERACT_STATES


func _unhandled_input(event: InputEvent) -> void:
	# The StateMachine (child) sees events first; states that consume a shared
	# button mark it handled. v8: pad A / keyboard E interact in free roam with
	# a prompt (A otherwise jumps; pad Y is the Command Menu / battle unique).
	if is_interact_press(event) and can_interact_now():
		if current_interact_needs_hold():
			_start_interact_hold(interact_action_of(event))
			get_viewport().set_input_as_handled()
			return
		if try_interact():
			get_viewport().set_input_as_handled()
			return
	# v4: View/Back (F) flips Battle / Free Roam on the fly.
	if is_battle_toggle_press(event):
		if can_toggle_battle():
			battle_mode.toggle_manual()
		get_viewport().set_input_as_handled()


# --- Model & Animation Setup ---

func _setup_model() -> void:
	if model == null:
		return
	# Find AnimationPlayer in the imported model
	anim_player = _find_child_of_type(model, "AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		push_warning("Player: No AnimationPlayer found in model")
		return

	# The model's own imported clip is only the T-pose rest: keep it as "tpose"
	# (never played) so "idle" can be the held walk pose below.
	var default_lib: AnimationLibrary = anim_player.get_animation_library(&"")
	if default_lib and default_lib.has_animation(&"mixamo_com"):
		var rest_anim: Animation = default_lib.get_animation(&"mixamo_com")
		default_lib.remove_animation(&"mixamo_com")
		default_lib.add_animation(&"tpose", rest_anim)

	# Load walking animation from separate FBX
	_import_animation("res://public/assets/fbx/redKnight/red_knight_walking.fbx", &"walk")

	# v6 JJ-1: no T-pose in any state. The only real clip is the walk, so:
	#  - "walk" is made in-place (root motion stripped) and looping;
	#  - "idle" is a static pose built from the walk's two passing frames
	#    (mirror phases averaged: feet together, arms down) — the "paused
	#    walk on a neutral frame". Static, so it holds at any time_scale
	#    (Command Menu 0.05) and when the AI body plays &"idle".
	if default_lib and default_lib.has_animation(&"walk"):
		var src_walk: Animation = default_lib.get_animation(&"walk")
		var walk_in_place := make_in_place_loop(src_walk)
		default_lib.remove_animation(&"walk")
		default_lib.add_animation(&"walk", walk_in_place)
		if default_lib.has_animation(&"idle"):
			default_lib.remove_animation(&"idle")
		default_lib.add_animation(&"idle", build_idle_pose(src_walk))
		anim_player.play(&"idle")
		_add_idle_layer()

	if DebugFlags.DEBUG_PLAYER:
		print("Player: Animations loaded: %s" % str(anim_player.get_animation_list()))


## Walk-cycle times (fractions of the clip) of the two "passing" frames, where
## the feet are together and the arms hang at the sides (measured on
## red_knight_walking.fbx: feet 0.157 m / 0.158 m apart at 0.026 s / 0.542 s).
const IDLE_PASS_FRACTIONS: Array[float] = [0.025, 0.525]
## Hips drop for the averaged pose so both feet reach the floor (the averaged
## swing leg is ~5 cm up otherwise).
const IDLE_HIPS_DROP: float = -0.04


## Static one-key idle pose from a walk clip: every bone track is sampled at
## IDLE_PASS_FRACTIONS and averaged (rotations slerped). Root (hips) X/Z are
## zeroed so the pose stands on the body origin.
static func build_idle_pose(walk: Animation) -> Animation:
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var times: Array[float] = []
	for f in IDLE_PASS_FRACTIONS:
		times.append(walk.length * f)
	for i in walk.get_track_count():
		var type := walk.track_get_type(i)
		var path := walk.track_get_path(i)
		var t := -1
		match type:
			Animation.TYPE_POSITION_3D:
				var p := Vector3.ZERO
				for tm in times:
					p += walk.position_track_interpolate(i, tm)
				p /= float(times.size())
				if String(path).ends_with("Hips"):
					p.x = 0.0
					p.z = 0.0
					p.y += IDLE_HIPS_DROP
				t = idle.add_track(type)
				idle.track_set_path(t, path)
				idle.position_track_insert_key(t, 0.0, p)
			Animation.TYPE_ROTATION_3D:
				var q := walk.rotation_track_interpolate(i, times[0])
				for k in range(1, times.size()):
					q = q.slerp(walk.rotation_track_interpolate(i, times[k]), 1.0 / float(k + 1))
				t = idle.add_track(type)
				idle.track_set_path(t, path)
				idle.rotation_track_insert_key(t, 0.0, q.normalized())
			Animation.TYPE_SCALE_3D:
				var s := Vector3.ZERO
				for tm in times:
					s += walk.scale_track_interpolate(i, tm)
				t = idle.add_track(type)
				idle.track_set_path(t, path)
				idle.scale_track_insert_key(t, 0.0, s / float(times.size()))
	return idle


## Copy of a Mixamo walk with the root's forward travel removed (the clip moves
## the hips ~2 m per cycle, which drifted the model off the body) and looping on.
static func make_in_place_loop(walk: Animation) -> Animation:
	var anim := walk.duplicate(true) as Animation
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not String(anim.track_get_path(i)).ends_with("Hips"):
			continue
		var n := anim.track_get_key_count(i)
		if n == 0:
			continue
		var first: Vector3 = anim.track_get_key_value(i, 0)
		var last: Vector3 = anim.track_get_key_value(i, n - 1)
		var clip_len := maxf(anim.length, 0.001)
		for k in n:
			var tk := anim.track_get_key_time(i, k)
			var v: Vector3 = anim.track_get_key_value(i, k)
			# Remove the linear forward drift; keep the small in-cycle sway.
			var drift := first.lerp(last, tk / clip_len)
			v.x -= drift.x
			v.z -= drift.z
			anim.track_set_key_value(i, k, v)
	return anim


## v6 JJ-1: wrap the rigged model in a cosmetic RiglessVisual ("IdleLayer") so
## the held idle pose breathes (bob) and leans with speed. Named IdleLayer, not
## RiglessVisual, so gameplay cues (_rigless_cue: dodge spin, hit shake...) stay
## off for the rigged knight. Read-only: it never writes the body. It travels
## with the model on a party identity swap (it is $VisualRoot's child).
func _add_idle_layer() -> void:
	if model == null or model.get_parent() != visual_root:
		return
	var layer := RiglessVisual.new()
	layer.name = "IdleLayer"
	layer.auto_fit = false            # keep the authored scale/offset of the FBX
	layer.fix_generated_materials = false
	layer.yaw_mode = RiglessVisual.YawMode.NONE  # body facing stays exact
	layer.idle_bob_amplitude = 0.02
	layer.move_bob_amplitude = 0.0    # the walk clip carries the step bounce
	layer.max_lean_deg = 7.0
	layer.max_side_lean_deg = 4.0
	layer.jump_stretch = 0.08
	layer.land_squash_per_speed = 0.01
	layer.max_squash = 0.12
	layer.air_stretch_per_speed = 0.004
	visual_root.remove_child(model)
	layer.add_child(model)
	visual_root.add_child(layer)
	model = layer


func _import_animation(fbx_path: String, anim_name: StringName) -> void:
	var scene: PackedScene = load(fbx_path)
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	var src_anim_player: AnimationPlayer = _find_child_of_type(instance, "AnimationPlayer") as AnimationPlayer
	if src_anim_player == null:
		instance.queue_free()
		return

	var src_lib: AnimationLibrary = src_anim_player.get_animation_library(&"")
	if src_lib and src_lib.has_animation(&"mixamo_com"):
		var anim: Animation = src_lib.get_animation(&"mixamo_com")
		var lib: AnimationLibrary = anim_player.get_animation_library(&"")
		if lib:
			lib.add_animation(anim_name, anim)

	instance.queue_free()


func _find_child_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var found: Node = _find_child_of_type(child, type_name)
		if found:
			return found
	return null


func play_animation(anim_name: StringName, blend: float = 0.2) -> void:
	if anim_player == null:
		return
	if anim_player.current_animation == anim_name:
		return
	anim_player.play(anim_name, blend)


func get_save_data() -> Dictionary:
	var data := {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"rotation_y": global_rotation.y,
		"hp": current_hp,
		"mp": current_mp,
		"atb": current_atb,
		"inventory": inventory_system.get_save_data(),
		"equipment": equipment_system.get_save_data(),
		"quests": quest_system.get_save_data(),
	}
	if party_system and party_system.has_method("get_save_data"):
		data["party"] = party_system.get_save_data()
	return data


func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos = data["position"]
		global_position = Vector3(pos["x"], pos["y"], pos["z"])
	if data.has("rotation_y"):
		global_rotation.y = data["rotation_y"]
	# v5: party first; it may swap the active identity onto this body (which
	# sets the member's max values), then the body's saved HP/MP/ATB apply.
	if data.has("party") and party_system and party_system.has_method("load_save_data"):
		party_system.load_save_data(data["party"])
	current_hp = data.get("hp", max_hp)
	current_mp = data.get("mp", max_mp)
	current_atb = data.get("atb", 0.0)
	Events.player_hp_changed.emit(current_hp, max_hp)
	Events.player_mp_changed.emit(current_mp, max_mp)
	Events.player_atb_changed.emit(current_atb, max_atb)
	if data.has("inventory"):
		inventory_system.load_save_data(data["inventory"])
	if data.has("equipment"):
		equipment_system.load_save_data(data["equipment"])
	if data.has("quests"):
		quest_system.load_save_data(data["quests"])
