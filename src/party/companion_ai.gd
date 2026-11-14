## AI behavior for non-controlled party members.
## Follows the active player, attacks nearby enemies, and provides support.
##
## v5 party switch (Package CC): PartySystem swaps IDENTITIES between this body
## and the Player body (member data, HP/MP/ATB, command list, visual). This node
## can therefore embody any member (Taighe at start, Amaro after a switch).
## Identity API used by PartySystem:
##   export_member_state() -> Dictionary
##   import_member_state(data: Resource, state: Dictionary)
##   visual_root (Node3D; its single child is the member's model)
##
## v6 HH — basic-attack profile. The embodied member's BasicAttackProfile
## (PartyMemberData.basic_attack_profile, re-read on every identity swap) drives
## the AI's attacks with the same kit the player uses: it plays
## profile.ai_pattern (e.g. "LLH") as a string of strikes with the strike
## timings of that kit. Melee (Amaro): direct hits on the target in reach using
## MeleeStrike.STRIKES, step 3 = the ComboComponent finisher (blasts via
## BlastVFX). Mage (Taighe): every step fires a MageBolt at the target (step 3
## = the heavy-scaled finisher burst), keeps ai_keep_distance from the target
## and attacks from ai_attack_range. One string, then ai_string_cooldown.
extends CharacterBody3D

const MeleeStrikeScript = preload("res://src/player/states/melee_strike_state.gd")
const MageBolt = preload("res://src/combat/basic_attacks/mage_bolt.gd")
const BlastVFX = preload("res://src/effects/blast_vfx.gd")
const AttackVFX = preload("res://src/effects/attack_vfx.gd")

@export var follow_distance: float = 3.0
@export var attack_range: float = 2.5
@export var attack_damage: float = 12.0
@export var attack_cooldown: float = 2.0
@export var move_speed: float = 7.0
@export var gravity: float = 20.0

var member_data: Resource = null  # PartyMemberData
var current_hp: float = 80.0
var max_hp: float = 80.0
var current_mp: float = 70.0
var max_mp: float = 70.0
var current_atb: float = 0.0
var max_atb: float = 100.0
var atb_fill_rate: float = 6.0

var mp_regen_rate: float = 2.0
## The embodied member's command list while AI-controlled (carried across switches).
var abilities: Array = []

var follow_target: Node3D = null
## v6 HH: the embodied member's basic-attack kit (never null after initialize).
var attack_profile: BasicAttackProfile = null
## Running AI string: letters played so far ("" = none), current strike data,
## its timer and whether its hit fired. Read by tests.
var ai_string: String = ""
var _strike: Dictionary = {}
var _strike_timer: float = 0.0
var _strike_hit_done: bool = false
var _strike_kind: StringName = &"light"
var _strike_finisher: StringName = &""
## Debug / test: number of strike hits/bolts this body has executed.
var strikes_executed: int = 0
var _is_downed: bool = false
var _attack_cooldown_timer: float = 0.0
var _state_timer: float = 0.0
var _target_enemy: Node3D = null

# FLINCH is appended so existing values keep their indices (v6 II).
enum AIState { FOLLOW, ATTACK, SUPPORT, DOWNED, FLINCH }
var ai_state: AIState = AIState.FOLLOW

# --- v6 II: hurt path. Enemy attack hitboxes (layer 5 "EnemyHitbox", value 16)
# hit this body through its own Hurtbox (layer 6 "PlayerHurtbox", value 32),
# exactly like the Player body. A hit interrupts the running string and
# flinches for FLINCH_TIME (game time, no actions); 0 HP = downed (no actions,
# hurtbox off, not targetable by enemies, party switch onto it is blocked).
const FLINCH_TIME := 0.45
var hurtbox: Area3D = null
var _flinch_timer: float = 0.0

# Visual
var visual_root: Node3D = null
var _mesh: MeshInstance3D  # Built-in capsule (null while another model is embodied)
var _anim: AnimationPlayer = null


func _ready() -> void:
	add_to_group(&"party_members")
	collision_layer = 2  # PlayerBody
	collision_mask = 1   # World

	# Build visual
	_build_visual()


func initialize(data: Resource, target: Node3D) -> void:
	member_data = data
	follow_target = target
	if data:
		max_hp = data.max_hp
		current_hp = max_hp
		max_mp = data.max_mp
		current_mp = max_mp
		max_atb = data.max_atb
		atb_fill_rate = data.atb_fill_rate
		attack_damage = data.attack_damage
		move_speed = data.move_speed
		mp_regen_rate = data.mp_regen_rate
		_apply_attack_profile(data)
		if data.has_method("get_starting_abilities"):
			abilities = data.get_starting_abilities()
		if _mesh and data.get("capsule_color"):
			_mesh.material_override.albedo_color = data.capsule_color
		# v5 EE: rigless member model replaces the capsule (dormant until a
		# .tres sets rigless + model_scene).
		var rv: Node3D = data.make_rigless_visual() if data.has_method("make_rigless_visual") else null
		if rv and visual_root:
			for c in visual_root.get_children():
				visual_root.remove_child(c)
				c.queue_free()
			visual_root.add_child(rv)
			refresh_visual()


func _physics_process(delta: float) -> void:
	if _is_downed:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# ATB fills passively; MP regenerates (same rule as the player body).
	if current_atb < max_atb:
		current_atb = minf(current_atb + atb_fill_rate * delta, max_atb)
	if current_mp < max_mp:
		current_mp = minf(current_mp + mp_regen_rate * delta, max_mp)

	# Attack cooldown
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	match ai_state:
		AIState.FOLLOW:
			_process_follow(delta)
		AIState.ATTACK:
			_process_attack(delta)
			if not ai_string.is_empty():
				_process_strike(delta)
		AIState.SUPPORT:
			_process_follow(delta)
		AIState.FLINCH:
			_process_flinch(delta)

	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if _anim == null or not is_instance_valid(_anim):
		return
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var anim_name: StringName = &"walk" if horizontal > 0.5 else &"idle"
	if _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.2)


func _process_follow(delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dist := global_position.distance_to(follow_target.global_position)

	# Check for nearby enemies to attack
	if _attack_cooldown_timer <= 0.0:
		var enemy := _find_nearest_enemy()
		if enemy and global_position.distance_to(enemy.global_position) < 8.0:
			_target_enemy = enemy
			ai_state = AIState.ATTACK
			return

	# Follow the active player
	if dist > follow_distance:
		var dir: Vector3 = (follow_target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			basis = basis.slerp(Basis.looking_at(dir), clampf(8.0 * delta, 0.0, 1.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)

	# Teleport if too far (prevent getting stuck)
	if dist > 20.0:
		global_position = follow_target.global_position + Vector3(2, 0, 2)


func _process_attack(delta: float) -> void:
	if _target_enemy == null or not is_instance_valid(_target_enemy):
		_end_string(false)
		ai_state = AIState.FOLLOW
		return

	# Check if enemy is dead
	if _target_enemy.has_method("die") and _target_enemy.get("_is_dead"):
		_target_enemy = null
		_end_string(false)
		ai_state = AIState.FOLLOW
		return

	var prof := _profile()
	var dist := global_position.distance_to(_target_enemy.global_position)

	if dist > maxf(10.0, prof.ai_attack_range + 2.0) and ai_string.is_empty():
		# Too far, give up
		_target_enemy = null
		ai_state = AIState.FOLLOW
		return

	var dir: Vector3 = (_target_enemy.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.1:
		dir = dir.normalized()
		basis = basis.slerp(Basis.looking_at(dir), clampf(8.0 * delta, 0.0, 1.0))

	if not ai_string.is_empty():
		# A string is running: hold position (strikes are rooted).
		velocity.x = 0.0
		velocity.z = 0.0
		return

	if dist > attack_range:
		# Move toward enemy
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		return
	if prof.ai_keep_distance > 0.0 and dist < prof.ai_keep_distance:
		# Mage: back off to casting distance between strings.
		velocity.x = -dir.x * move_speed * 0.6
		velocity.z = -dir.z * move_speed * 0.6
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	# Strike
	if _attack_cooldown_timer <= 0.0:
		_start_string()


# --- v6 HH: basic-attack profile strings ---

func _profile() -> BasicAttackProfile:
	if attack_profile == null:
		attack_profile = BasicAttackProfile.for_member(member_data)
	return attack_profile


## Adopt `data`'s basic-attack kit (initialize / identity swap).
func _apply_attack_profile(data: Resource) -> void:
	attack_profile = BasicAttackProfile.for_member(data)
	attack_range = attack_profile.ai_attack_range
	attack_cooldown = attack_profile.ai_string_cooldown
	_end_string(false)


func _start_string() -> void:
	ai_string = ""
	_begin_strike()


## Start the next letter of the profile's ai_pattern.
func _begin_strike() -> void:
	var prof := _profile()
	var pattern := prof.ai_pattern if not prof.ai_pattern.is_empty() else "L"
	var letter := pattern[mini(ai_string.length(), pattern.length() - 1)]
	ai_string += "H" if letter == "H" else "L"
	_strike_kind = ComboComponent.KIND_HEAVY if letter == "H" else ComboComponent.KIND_LIGHT
	var step := ai_string.length()
	_strike_finisher = prof.get_finisher(ai_string) if step == ComboComponent.MAX_STEPS else &""
	if prof.is_mage() and not prof.get_strike(_strike_kind).is_empty():
		_strike = prof.get_strike(_strike_kind).duplicate()
	else:
		_strike = (MeleeStrikeScript.STRIKES[_strike_kind] as Dictionary).duplicate()
	_strike["damage_final"] = float(_strike["damage"])
	_strike["stagger_final"] = float(_strike["stagger"])
	if _strike_finisher != &"":
		var fin := prof.get_finisher_data(_strike_finisher)
		_strike["damage_final"] = float(_strike["damage"]) * float(fin.get("mult", 1.0))
		_strike["stagger_final"] = float(fin.get("stagger", _strike["stagger"]))
		if float(fin.get("radius", 0.0)) > 0.0:
			_strike["duration"] = float(_strike["duration"]) + MeleeStrikeScript.FINISHER_EXTRA_TIME
	_strike_timer = 0.0
	_strike_hit_done = false
	var rv: Node = visual_root.get_node_or_null(^"RiglessVisual") if visual_root else null
	if rv and rv.has_method(&"play_cue"):
		rv.play_cue(&"attack_heavy" if _strike_kind == ComboComponent.KIND_HEAVY else &"attack")


func _process_strike(delta: float) -> void:
	if _strike.is_empty():
		return
	_strike_timer += delta
	if not _strike_hit_done and _strike_timer >= float(_strike["hit_start"]):
		_do_attack()
	if _strike_timer < float(_strike["duration"]):
		return
	var pattern_len := clampi(_profile().ai_pattern.length(), 1, ComboComponent.MAX_STEPS)
	if ai_string.length() >= pattern_len:
		_end_string(true)
		ai_state = AIState.FOLLOW
	else:
		_begin_strike()


## Drop the running string; `cooldown` starts attack_cooldown.
func _end_string(cooldown: bool) -> void:
	ai_string = ""
	_strike = {}
	_strike_hit_done = false
	if cooldown:
		_attack_cooldown_timer = attack_cooldown


## The current strike's hit: a MageBolt (mage) or a direct melee hit / finisher
## blast (melee), with the profile's damage and stagger.
func _do_attack() -> void:
	_strike_hit_done = true
	strikes_executed += 1
	var prof := _profile()
	var dmg := float(_strike.get("damage_final", attack_damage))
	var stg := float(_strike.get("stagger_final", 0.0))
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var parent: Node = get_parent()
	if prof.is_mage():
		if parent == null or not is_inside_tree():
			return
		var p := {
			"damage": dmg, "stagger": stg, "source": self, "hit_kind": _strike_kind,
			"speed": float(_strike.get("speed", 30.0)), "lifetime": float(_strike.get("lifetime", 0.6)),
			"homing": float(_strike.get("homing", 6.0)), "radius": float(_strike.get("radius", 0.3)),
			"core_color": prof.core_color, "glow_color": prof.glow_color,
		}
		if _strike_finisher != &"":
			var fin := prof.get_finisher_data(_strike_finisher)
			p["burst_radius"] = float(fin.get("radius", 0.0))
			p["speed"] = float(fin.get("speed", p["speed"]))
			p["lifetime"] = float(fin.get("lifetime", p["lifetime"]))
			p["homing"] = float(fin.get("homing", p["homing"]))
			p["radius"] = float(fin.get("size", p["radius"]))
			p["hit_kind"] = &"finisher"
		var bolt: Node3D = MageBolt.create(p)
		parent.add_child(bolt)
		bolt.global_position = global_position + Vector3(0, 1.25, 0) + fwd * 0.55
		bolt.launch(fwd, _target_enemy)
		return
	# Melee: finisher blast in front, else a direct hit on the target in reach.
	var fin_data: Dictionary = prof.get_finisher_data(_strike_finisher) if _strike_finisher != &"" else {}
	if float(fin_data.get("radius", 0.0)) > 0.0:
		var centre: Vector3 = global_position + fwd * MeleeStrikeScript.BLAST_FORWARD
		BlastVFX.detonate(self, centre, float(fin_data["radius"]), dmg, stg)
		if parent:
			BlastVFX.spawn(parent, centre + Vector3(0, 0.6, 0), float(fin_data["radius"]))
		return
	if parent:
		AttackVFX.spawn_strike(parent, global_position + Vector3(0, 1.0, 0), fwd, _strike_kind, ai_string.length(), 0.0, 0.0)
	if _target_enemy and is_instance_valid(_target_enemy) and _target_enemy.has_method("take_damage") 			and global_position.distance_to(_target_enemy.global_position) <= attack_range + 0.75:
		var hk: StringName = &"finisher" if _strike_finisher != &"" else _strike_kind
		if _target_enemy.get_method_argument_count(&"take_damage") >= 3:
			_target_enemy.take_damage(dmg, self, hk)
		else:
			_target_enemy.take_damage(dmg, self)
		if is_instance_valid(_target_enemy):
			if stg > 0.0 and _target_enemy.has_method("add_stagger"):
				_target_enemy.add_stagger(stg)
			Events.attack_hit.emit(_target_enemy, dmg)


func take_damage(amount: float, source: Node3D = null) -> void:
	if _is_downed or amount <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	var id: StringName = member_data.member_id if member_data else &"companion"
	# Optional bus signal (requested from the Head); the HUD party panel already
	# polls current_hp, so nothing depends on it existing.
	if Events.has_signal(&"party_member_damaged"):
		Events.emit_signal(&"party_member_damaged", id, amount, source)
	if current_hp <= 0.0:
		_enter_downed()
		return
	_enter_flinch()


func _on_hurtbox_hit(area: Area3D) -> void:
	if area.has_meta("damage"):
		take_damage(float(area.get_meta("damage")), area.get_parent())


func _enter_flinch() -> void:
	_end_string(false)  # a hit interrupts the running string (no cooldown)
	ai_state = AIState.FLINCH
	_flinch_timer = FLINCH_TIME
	velocity.x = 0.0
	velocity.z = 0.0
	var rv: Node = visual_root.get_node_or_null(^"RiglessVisual") if visual_root else null
	if rv and rv.has_method(&"play_cue"):
		rv.play_cue(&"hit")
	if _mesh and _mesh.material_override is StandardMaterial3D:
		var mat := _mesh.material_override as StandardMaterial3D
		var base := mat.albedo_color
		mat.albedo_color = Color(1.0, 0.55, 0.55, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(mat):
				mat.albedo_color = base)


func _process_flinch(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	_flinch_timer -= delta
	if _flinch_timer <= 0.0:
		ai_state = AIState.FOLLOW


func is_flinching() -> bool:
	return ai_state == AIState.FLINCH


func _set_hurtbox_enabled(on: bool) -> void:
	if hurtbox and is_instance_valid(hurtbox):
		hurtbox.set_deferred("monitoring", on)


func _enter_downed() -> void:
	_is_downed = true
	_end_string(false)
	ai_state = AIState.DOWNED
	current_hp = 0.0
	velocity = Vector3.ZERO
	_set_hurtbox_enabled(false)
	Events.party_member_downed.emit(member_data.member_id if member_data else &"companion")
	# Visual feedback — shrink slightly
	if visual_root:
		visual_root.scale = Vector3(0.7, 0.4, 0.7)


func revive(hp_amount: float = -1.0) -> void:
	if not _is_downed:
		return
	_is_downed = false
	if hp_amount < 0:
		current_hp = max_hp * 0.3  # Revive at 30% HP
	else:
		current_hp = minf(hp_amount, max_hp)
	ai_state = AIState.FOLLOW
	_set_hurtbox_enabled(true)
	Events.party_member_revived.emit(member_data.member_id if member_data else &"companion")
	if visual_root:
		visual_root.scale = Vector3.ONE


func heal(amount: float) -> void:
	if _is_downed:
		return
	current_hp = minf(current_hp + amount, max_hp)


func is_downed() -> bool:
	return _is_downed


func _find_nearest_enemy() -> Node3D:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	var best: Node3D = null
	var best_dist := 999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("_is_dead"):
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Model"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	_mesh.mesh = capsule
	_mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.4, 0.5)
	_mesh.material_override = mat
	visual_root.add_child(_mesh)

	# Collision shape
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	# v6 II: hurtbox, same layers/size as the Player body's Hurtbox.
	hurtbox = Area3D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32  # PlayerHurtbox
	hurtbox.collision_mask = 16   # EnemyHitbox
	hurtbox.monitorable = true
	hurtbox.position.y = 0.9
	var hs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	hs.shape = sphere
	hurtbox.add_child(hs)
	add_child(hurtbox)
	hurtbox.area_entered.connect(_on_hurtbox_hit)


func get_save_data() -> Dictionary:
	return {
		"member_id": String(member_data.member_id) if member_data else "companion",
		"hp": current_hp,
		"mp": current_mp,
		"atb": current_atb,
		"is_downed": _is_downed,
	}


func load_save_data(data: Dictionary) -> void:
	current_hp = data.get("hp", max_hp)
	current_mp = data.get("mp", max_mp)
	current_atb = data.get("atb", 0.0)
	if data.get("is_downed", false):
		_enter_downed()


# --- v5 identity swap (PartySystem) ---

## Snapshot of the embodied member's live state (see PartySystem._swap_identities).
func export_member_state() -> Dictionary:
	return {
		"hp": current_hp, "max_hp": max_hp,
		"mp": current_mp, "max_mp": max_mp,
		"atb": current_atb, "max_atb": max_atb,
		"atb_fill_rate": atb_fill_rate, "mp_regen_rate": mp_regen_rate,
		"abilities": abilities.duplicate(),
		"downed": _is_downed,
	}


## Become `data` with `state` (from the Player body's export_member_state()).
## The body keeps following follow_target (the Player node).
func import_member_state(data: Resource, state: Dictionary) -> void:
	member_data = data
	if data:
		attack_damage = data.attack_damage
		move_speed = data.move_speed
	_apply_attack_profile(data)
	max_hp = state.get("max_hp", max_hp)
	max_mp = state.get("max_mp", max_mp)
	max_atb = state.get("max_atb", max_atb)
	atb_fill_rate = state.get("atb_fill_rate", atb_fill_rate)
	mp_regen_rate = state.get("mp_regen_rate", mp_regen_rate)
	current_hp = clampf(state.get("hp", max_hp), 0.0, max_hp)
	current_mp = clampf(state.get("mp", max_mp), 0.0, max_mp)
	current_atb = clampf(state.get("atb", 0.0), 0.0, max_atb)
	abilities = (state.get("abilities", []) as Array).duplicate()
	_is_downed = false
	_target_enemy = null
	_attack_cooldown_timer = 0.5  # short grace so the fresh AI doesn't strike on frame 1
	ai_state = AIState.FOLLOW
	_flinch_timer = 0.0
	_set_hurtbox_enabled(true)
	velocity = Vector3.ZERO
	if visual_root:
		visual_root.scale = Vector3.ONE
	if state.get("downed", false) or current_hp <= 0.0:
		_enter_downed()


## Called by PartySystem after the visual_root's child was exchanged.
func refresh_visual() -> void:
	_mesh = null
	_anim = null
	if visual_root == null or visual_root.get_child_count() == 0:
		return
	var model := visual_root.get_child(0)
	if model is MeshInstance3D and (model as MeshInstance3D).mesh is CapsuleMesh:
		_mesh = model
	_anim = _find_anim(model)


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null
