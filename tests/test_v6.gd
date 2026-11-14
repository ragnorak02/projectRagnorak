## v6 tests (docs/plans/v6_next_session_plan.md, Package LL).
## Covers the v6 packages:
##  - HH  BasicAttackProfile per member (Amaro melee / Taighe mage), the profile
##        follows a real party switch; Taighe tap bolt (9) / hold charged shot (17,
##        stagger 18) / 3-step finisher scaling with heavies (LLL Arcane Burst 2 m
##        vs HHH Lumina Nova 4.5 m: only HHH reaches a side enemy at 3.5 m);
##        a bolt charging when B cancels the strike fizzles (no damage); a bolt in
##        flight is slowed by the Command Menu time scale (0.05) and still lands;
##        Amaro's melee is unchanged (STRIKES table, hitbox hit 12, no bolts);
##        the AI companion plays its own profile (Taighe: LLH bolts, finisher burst).
##  - II  Threat targeting + spacing (bare world, real enemy.tscn / player.tscn /
##        PartySystem): 1v1/1v2/1v3 vs the player and vs the companion, min
##        distance to every member >= 1.45 m (stop_distance 1.5), <= 2 attackers
##        per member at any frame, voluntary retargets >= 2 s apart (no flapping),
##        companion damage draws its victim; companion Hurtbox (32/16), hurt ->
##        FLINCH, Events.party_member_damaged, 0 HP -> DOWNED (no actions, hurtbox
##        off), enemies drop the downed member at once, switch onto it blocked.
##  - JJ  Amaro never T-poses (idle = held walk pose, 1 key per track, hips X/Z 0;
##        walk in place + looping; IdleLayer; idle in the Command Menu and on the
##        AI body); NPC default facing + dialogue facing; Scholar Yeun / Alchemist
##        Ines models; Goblin in ENEMY_MODELS (field + dungeon); Goblin Chief 2.4 m.
##  - GG  Sword Slash is additive / no depth write and its visuals are gone within
##        0.25 s game time; out-of-range: reticle dims but the label is large on a
##        dark pill; the target bar keeps (darkens) its panel and dims only content.
##  - Head check: the model shown on the Player node matches the controlled member
##        after a real D-pad switch, both ways (and the AI body shows the other).
##  - KK  Exit-leak guard: StanceComponent.REGISTRY holds preloaded GDScripts.
## Input goes through Input.parse_input_event (the real _unhandled_input path).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0

const JOY_A := 0
const JOY_B := 1
const JOY_X := 2
const JOY_Y := 3
const JOY_DPAD_UP := 11
const JOY_DPAD_DOWN := 12
const JOY_DPAD_RIGHT := 14

const PLAYER_SCENE := "res://src/player/player.tscn"
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const TOWN_SCENE := "res://scenes/zones/town_hub.tscn"
const DUNGEON_SCENE := "res://scenes/zones/dungeon_zone.tscn"
const HERO_TRES := "res://resources/characters/hero.tres"
const COMPANION_TRES := "res://resources/characters/companion.tres"
const PRINCESS_GLB := "res://assets/models/characters/princess1.glb"
const WATCHDOG_SECONDS := 480.0
const SWITCH_WAIT := 1.1
const PHASE_ABILITY := 1
const PHASE_TARGET := 2
## Spacing: stop_distance 1.5 m, measured centre to centre (small physics slack).
const MIN_MEMBER_DIST := 1.45

## Town test lane: the main road (x in +-3, z from 8 to -48) is open.
const LANE_ORIGIN := Vector3(0, 0.1, -2)

var _zone: Node = null
var _player: Node = null
var _party: Node = null
var _rig: Node = null
var _dummies: Array = []

# Bare world (II spacing harness).
var _world: Node3D = null
var _comp: CharacterBody3D = null
var _enemies: Array = []
var _target_log: Dictionary = {}  # enemy instance id -> [[game_time, target], ...]

var _game_time: float = 0.0
var _fail_log: Array = []
var _switch_log: Array = []
var _hit_log: Array = []        # [enemy, amount, source]
var _finisher_log: Array = []   # [name, radius]
var _damaged_log: Array = []    # party_member_damaged [id, amount, source]
var _bolt_nodes: Array = []
var _finished: bool = false


func _ready() -> void:
	print("=== v6 Tests (Taighe kit, party targeting/spacing, companion hurt, models, VFX) ===")
	print("")
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(func():
		_fail("Watchdog", "suite did not finish within %.0fs (a test hung or aborted)" % WATCHDOG_SECONDS)
		_finish())
	await _run_tests()
	_finish()


func _physics_process(delta: float) -> void:
	_game_time += delta  # physics delta is already scaled by Engine.time_scale


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all_input()
	Engine.time_scale = 1.0
	print("\n=== V6 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")
	get_tree().quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	_section("CONTRACT — PROFILES / THREAT / SPACING / MODELS / LEAK GUARD")
	test_contract()
	_connect_logs()

	_section("BARE WORLD — COMPANION AI PROFILE")
	await _build_bare_world()
	await test_companion_ai_profile()

	_section("BARE WORLD — SPACING + THREAT vs PLAYER")
	_park(_comp, Vector3(60, 0.0, 60))
	_player.global_position = Vector3(0, 0.1, 0)
	for n in [1, 2, 3]:
		await _scenario_vs(_player, n, "player")

	_section("BARE WORLD — SPACING + THREAT vs COMPANION")
	_player.global_position = Vector3(-60, 0.1, -60)
	_comp.global_position = Vector3(0, 0.0, 0)
	_comp.max_hp = 1e6
	_comp.current_hp = 1e6
	for n in [1, 2, 3]:
		await _scenario_vs(_comp, n, "companion")

	_section("BARE WORLD — MIXED TARGETING + NO FLAPPING")
	await _scenario_mixed()

	_section("BARE WORLD — COMPANION DOWNED")
	await _scenario_downed()
	await _teardown_bare()

	_section("TOWN HUB HARNESS")
	if not await _load_town():
		_fail("v6 town tests", "skipped: town harness failed")
		return

	_section("AMARO — NO T-POSE (idle / walk / Command Menu)")
	await test_amaro_idle()

	_section("NPCs — FACING, MODELS, DIALOGUE FACING")
	await test_npcs()

	_section("PARTY SWITCH — VISIBLE MODEL MATCHES THE CONTROLLED MEMBER (to Taighe)")
	await test_switch_to_taighe()

	if _is_member(&"companion"):
		_section("TAIGHE — TAP BOLT / CHARGED SHOT")
		await test_taighe_bolts()
		_section("TAIGHE — FINISHER SCALES WITH HEAVIES (LLL vs HHH)")
		await test_taighe_finishers()
		_section("TAIGHE — DODGE FIZZLES A CHARGING BOLT")
		await test_taighe_dodge_fizzle()
		_section("TAIGHE — BOLT SLOWED BY THE COMMAND MENU TIME SCALE")
		await test_taighe_bolt_slowed()
	else:
		_fail("Taighe kit tests", "skipped: the party switch to Taighe failed")

	_section("PARTY SWITCH — VISIBLE MODEL MATCHES THE CONTROLLED MEMBER (back to Amaro)")
	await test_switch_back_to_amaro()

	_section("AMARO — MELEE UNCHANGED")
	await test_amaro_melee()

	_section("SWORD SLASH VFX + OUT-OF-RANGE DIM")
	await test_sword_slash_and_range_dim()
	_teardown_zone()
	await _frames(5)

	_section("DUNGEON — GOBLIN + GOBLIN CHIEF")
	await test_dungeon_models()
	_teardown_zone()
	await _frames(5)


# ========== CONTRACT ==========

func test_contract() -> void:
	# --- HH profiles ---
	var hero: Resource = load(HERO_TRES)
	var comp: Resource = load(COMPANION_TRES)
	var hp: BasicAttackProfile = BasicAttackProfile.for_member(hero)
	var cp: BasicAttackProfile = BasicAttackProfile.for_member(comp)
	_assert(hero.get(&"basic_attack_profile") is BasicAttackProfile and not hp.is_mage(),
		"hero.tres (Amaro) has a melee BasicAttackProfile", str(hp.kind))
	_assert(comp.get(&"basic_attack_profile") is BasicAttackProfile and cp.is_mage(),
		"companion.tres (Taighe) has a mage BasicAttackProfile", str(cp.kind))
	_assert(not BasicAttackProfile.for_member(null).is_mage(), "A member without a profile falls back to melee")
	var light: Dictionary = cp.get_strike(&"light")
	var heavy: Dictionary = cp.get_strike(&"heavy")
	_assert(is_equal_approx(float(light.get("damage", 0)), 9.0) and is_equal_approx(float(light.get("stagger", 0)), 6.0),
		"Mage light bolt: 9 dmg, 6 stagger", str(light))
	_assert(is_equal_approx(float(heavy.get("damage", 0)), 17.0) and is_equal_approx(float(heavy.get("stagger", 0)), 18.0),
		"Mage charged shot: 17 dmg, 18 stagger", str(heavy))
	var want := {"LLL": [&"arcane_burst", 2.0], "LLH": [&"frost_burst", 2.6], "LHH": [&"frost_nova", 3.4],
		"HHH": [&"lumina_nova", 4.5], "HLL": [&"frost_burst", 2.6]}
	var bad: Array = []
	var last_r := 0.0
	for s in ["LLL", "LLH", "LHH", "HHH"]:
		var f: StringName = cp.get_finisher(s)
		var r := float(cp.get_finisher_data(f).get("radius", 0.0))
		if f != want[s][0] or not is_equal_approx(r, want[s][1]) or r <= last_r:
			bad.append("%s=%s/%.1f" % [s, f, r])
		last_r = r
	var f2: StringName = cp.get_finisher("HLL")
	if f2 != want["HLL"][0]:
		bad.append("HLL=%s" % f2)
	_assert(bad.is_empty(), "Mage finisher grows with heavies: Arcane Burst 2.0 / Frost Burst 2.6 / Frost Nova 3.4 / Lumina Nova 4.5 (order-free)",
		str(bad))
	_assert(cp.get_finisher("LL") == &"", "A 2-letter string has no finisher")
	var mults: Array = []
	for f in [&"arcane_burst", &"frost_burst", &"frost_nova", &"lumina_nova"]:
		mults.append(float(cp.get_finisher_data(f).get("mult", 0.0)))
	_assert(mults == [1.4, 1.7, 2.2, 3.0], "Finisher damage multipliers 1.4 / 1.7 / 2.2 / 3.0", str(mults))
	_assert(cp.ai_pattern == "LLH" and is_equal_approx(cp.ai_attack_range, 9.0) and is_equal_approx(cp.ai_keep_distance, 4.0),
		"Taighe AI kit: pattern LLH, attacks from 9 m, keeps 4 m", "%s %.1f %.1f" % [cp.ai_pattern, cp.ai_attack_range, cp.ai_keep_distance])
	var ms: Dictionary = load("res://src/player/states/melee_strike_state.gd").get_script_constant_map()
	var strikes: Dictionary = ms.get("STRIKES", {})
	_assert(strikes.has(&"light") and is_equal_approx(float(strikes[&"light"]["damage"]), 12.0)
			and is_equal_approx(float(strikes[&"heavy"]["damage"]), 20.0)
			and is_equal_approx(float(strikes[&"light"]["duration"]), 0.35)
			and is_equal_approx(float(strikes[&"heavy"]["duration"]), 0.60),
		"Amaro melee STRIKES unchanged (light 12 / 0.35 s, heavy 20 / 0.60 s)")
	_assert(ComboComponent.HOLD_THRESHOLD_MS == 220 and ComboComponent.MAX_STEPS == 3,
		"X tap/hold threshold 220 ms, 3-step strings (shared by every member)")

	# --- II threat / spacing ---
	var tt: Dictionary = load("res://src/enemies/threat_table.gd").get_script_constant_map()
	_assert(is_equal_approx(float(tt.get("RETARGET_INTERVAL", 0)), 0.5) and is_equal_approx(float(tt.get("MIN_HOLD", 0)), 2.0),
		"ThreatTable: re-evaluate every 0.5 s, hold 2.0 s after a voluntary switch")
	_assert(is_equal_approx(float(tt.get("STICKY_BONUS", 0)), 10.0) and is_equal_approx(float(tt.get("CROWD_PENALTY", 0)), 6.0)
			and is_equal_approx(float(tt.get("PROXIMITY_WEIGHT", 0)), 15.0) and is_equal_approx(float(tt.get("DECAY_PER_SEC", 0)), 0.1),
		"ThreatTable weights: sticky 10, crowd -6, proximity 15, decay 10 %/s", str(tt))
	var table: RefCounted = load("res://src/enemies/threat_table.gd").new()
	var rows := [{"key": &"hero", "dist": 3.0, "crowd": 0}, {"key": &"companion", "dist": 3.0, "crowd": 0}]
	_assert(table.pick(rows, &"companion", 12.0) == 1 and table.pick(rows, &"", 12.0) == 0,
		"Ties keep the current target, else party order")
	var rows2 := [{"key": &"hero", "dist": 3.0, "crowd": 2}, {"key": &"companion", "dist": 3.0, "crowd": 0}]
	_assert(table.pick(rows2, &"", 12.0) == 1, "Crowd penalty spreads enemies over the party")
	table.add(&"companion", 30.0)
	var rows3 := [{"key": &"hero", "dist": 1.0, "crowd": 0}, {"key": &"companion", "dist": 8.0, "crowd": 0}]
	_assert(table.pick(rows3, &"hero", 12.0) == 1, "Damage threat (30) outweighs proximity + stickiness")
	var e: Node = (load(ENEMY_SCENE) as PackedScene).instantiate()
	_assert(is_equal_approx(e.stop_distance, 1.5) and e.max_attackers_per_target == 2
			and is_equal_approx(e.enemy_separation, 1.3) and is_equal_approx(e.get_preferred_radius(), 1.8),
		"EnemyBase spacing: stop 1.5 m, ring 1.8 m, separation 1.3 m, max 2 attackers",
		"stop=%.2f max=%d sep=%.2f ring=%.2f" % [e.stop_distance, e.max_attackers_per_target, e.enemy_separation, e.get_preferred_radius()])
	_assert(e.has_signal(&"target_changed") and e.has_method(&"get_target") and e.has_method(&"get_ring_slot_angle"),
		"EnemyBase exposes target_changed / get_target / get_ring_slot_angle")
	e.free()
	var cai: GDScript = load("res://src/party/companion_ai.gd")
	var cmap: Dictionary = cai.get_script_constant_map()
	var ai_enum: Dictionary = cmap.get("AIState", {})
	var max_v := -1
	for k in ai_enum:
		max_v = maxi(max_v, int(ai_enum[k]))
	_assert(ai_enum.has("FLINCH") and int(ai_enum["FLINCH"]) == max_v and int(ai_enum.get("DOWNED", -1)) == 3,
		"CompanionAI.AIState: FLINCH appended last (DOWNED keeps index 3)", str(ai_enum))
	_assert(is_equal_approx(float(cmap.get("FLINCH_TIME", 0)), 0.45), "Companion flinch lasts 0.45 s")
	_assert(Events.has_signal(&"party_member_damaged") and Events.has_signal(&"party_member_downed"),
		"Events.party_member_damaged / party_member_downed exist")

	# --- JJ models ---
	for zone_script in ["res://scenes/zones/field_zone.gd", "res://scenes/zones/dungeon_zone.gd"]:
		var zm: Dictionary = load(zone_script).get_script_constant_map()
		var em: Array = zm.get("ENEMY_MODELS", [])
		var names: Array = em.map(func(x): return x[0])
		var goblin_ok := false
		for x in em:
			if x[0] == "Goblin" and x[1] is PackedScene and String((x[1] as PackedScene).resource_path).ends_with("goblin_male2.glb"):
				goblin_ok = true
		_assert(em.size() == 3 and names.has("Kobold") and names.has("Kobold Queen") and goblin_ok,
			"%s ENEMY_MODELS = Kobold / Kobold Queen / Goblin (goblin_male2.glb)" % zone_script.get_file(), str(names))
	var field_src := _get_source("res://scenes/zones/field_zone.gd")
	_assert(field_src.contains("func _add_npc(npc_name: String, pos: Vector3, color: Color, pages: Array, model: PackedScene = null"),
		"field_zone._add_npc has the optional model parameter")
	for f in ["teacher_female2.glb", "alchemist_female1.glb", "goblin_male2.glb", "goblinchief_male1.glb"]:
		_assert(ResourceLoader.exists("res://assets/models/characters/" + f), "Model %s imports" % f)

	# --- KK exit-leak guard ---
	var reg: Dictionary = StanceComponent.REGISTRY
	var all_scripts := not reg.is_empty()
	for k in reg:
		all_scripts = all_scripts and reg[k] is GDScript
	_assert(all_scripts, "StanceComponent.REGISTRY values are preloaded GDScripts (no runtime load(): exit-leak guard)",
		str(reg.values().map(func(v): return type_string(typeof(v)))))
	_assert(not _get_source("res://src/combat/stance_component.gd").contains("load(REGISTRY"),
		"StanceComponent.refresh_ability does not load() a script at runtime")


# ========== BARE WORLD (II harness port) ==========

func _build_bare_world() -> void:
	_world = Node3D.new()
	_world.name = "BareWorld"
	add_child(_world)
	var fb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	fb.add_child(col)
	_world.add_child(fb)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 20, 20)
	_world.add_child(cam)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_world.add_child(_player)
	_player.global_position = Vector3(2, 0.1, 2)
	GameManager.change_state(GameManager.GameState.PLAYING)
	_party = Node.new()
	_party.set_script(load("res://src/party/party_system.gd"))
	add_child(_party)
	_player.party_system = _party
	_party.initialize(_player, load(COMPANION_TRES))
	_comp = _party.get_companion()
	await _physics_frames(10)
	_player.max_hp = 1e6
	_player.current_hp = 1e6
	_assert(_comp != null and _comp.get_node_or_null(^"Hurtbox") is Area3D, "Bare world: companion spawned with a Hurtbox")
	if _comp:
		var hb: Area3D = _comp.get_node(^"Hurtbox")
		_assert(hb.collision_layer == 32 and hb.collision_mask == 16, "Companion Hurtbox layer 32 (PlayerHurtbox), mask 16 (EnemyHitbox)",
			"layer=%d mask=%d" % [hb.collision_layer, hb.collision_mask])
		_assert(_comp.is_in_group(&"party_members"), "Companion is in the party_members group")


func _park(n: Node3D, pos: Vector3) -> void:
	if n == null:
		return
	n.set_physics_process(false)
	n.global_position = pos
	n.set(&"velocity", Vector3.ZERO)


func test_companion_ai_profile() -> void:
	if _comp == null:
		_fail("Companion AI profile", "no companion")
		return
	_assert(_comp.attack_profile != null and _comp.attack_profile.is_mage(), "Taighe's AI body uses the mage profile")
	_comp.global_position = Vector3(0, 0, 0)
	_comp.rotation.y = 0.0
	var dummy := _spawn_frozen_enemy(Vector3(0, 0, -7))
	await _physics_frames(3)
	_hit_log.clear()
	_bolt_nodes.clear()
	var s0: int = _comp.strikes_executed
	_comp.set(&"_attack_cooldown_timer", 0.0)
	_comp.set_physics_process(true)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 6000:
		await get_tree().physics_frame
		if _comp.strikes_executed - s0 >= 3 and _comp.ai_string == "":
			break
	await _real_seconds(0.8)  # last bolt / burst lands
	var amounts: Array = []
	for h in _hit_log:
		if h[0] == dummy and h[2] == _comp:
			amounts.append(float(h[1]))
	_assert(_comp.strikes_executed - s0 >= 3, "Taighe AI plays a 3-strike string", "strikes=%d" % (_comp.strikes_executed - s0))
	_assert(_bolt_nodes.size() >= 3, "Taighe AI fires MageBolts (not melee hits)", "bolts=%d" % _bolt_nodes.size())
	_assert(_has_approx(amounts, 9.0) and _has_approx(amounts, 28.9),
		"Taighe AI string LLH: 9-dmg bolts + Frost Burst finisher (17 x 1.7 = 28.9) on the target",
		str(amounts))
	_assert(not _damaged_by_melee_from(_comp), "Taighe AI never lands a melee hit")
	# Identity swap: the AI body becomes Amaro and adopts the melee kit.
	_park(_comp, _comp.global_position)
	_player.state_machine.force_transition(&"Idle")
	await _physics_frames(2)
	var ok: bool = _party.switch_member()
	await _physics_frames(2)
	_assert(ok and _comp.attack_profile != null and not _comp.attack_profile.is_mage()
			and is_equal_approx(_comp.attack_range, 2.5),
		"After a switch the AI body (Amaro) uses the melee profile (attack range 2.5)",
		"ok=%s kind=%s range=%.1f" % [ok, _comp.attack_profile.kind if _comp.attack_profile else &"?", _comp.attack_range])
	_assert(_player.combo.active_profile().is_mage(), "...and the Player node's combo now resolves the mage profile")
	_player.state_machine.force_transition(&"Idle")
	await _physics_frames(2)
	ok = _party.switch_member()
	await _physics_frames(2)
	_assert(ok and _comp.attack_profile.is_mage() and not _player.combo.active_profile().is_mage(),
		"Switching back restores Taighe = mage on the AI body, Amaro = melee on the Player")
	dummy.queue_free()
	await _physics_frames(3)


func _damaged_by_melee_from(src: Node) -> bool:
	for h in _hit_log:
		if h[2] == src and is_equal_approx(float(h[1]), 12.0):
			return true
	return false


func _spawn_frozen_enemy(pos: Vector3) -> Node3D:
	var e: Node3D = (load(ENEMY_SCENE) as PackedScene).instantiate()
	e.max_hp = 1e6
	e.current_hp = 1e6
	e.stagger_max = 1e6
	_world.add_child(e)
	e.global_position = pos
	e.set_physics_process(false)
	e.set_process(false)
	return e


func _clear_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()
	_target_log.clear()
	await _physics_frames(3)


func _spawn(pos: Vector3) -> Node3D:
	var e: Node3D = (load(ENEMY_SCENE) as PackedScene).instantiate()
	e.max_hp = 1e6
	e.current_hp = 1e6
	_world.add_child(e)
	e.global_position = pos
	e.target_changed.connect(_on_target_changed)
	_enemies.append(e)
	return e


func _on_target_changed(en: Node3D, t: Node3D) -> void:
	var k := en.get_instance_id()
	if not _target_log.has(k):
		_target_log[k] = []
	(_target_log[k] as Array).append([_game_time, t])


## Runs `secs` of game time: min centre distance enemy->any member (after 0.2 s),
## min enemy-enemy distance, max simultaneous attackers on one member, states.
func _observe(secs: float, members: Array) -> Dictionary:
	var min_member := INF
	var min_enemy := INF
	var max_attackers := 0
	var states_seen := {}
	var t0 := _game_time
	while _game_time - t0 < secs:
		await get_tree().physics_frame
		var t := _game_time - t0
		for m in members:
			var atk := 0
			for e in _enemies:
				if is_instance_valid(e) and e.get_target() == m and e.is_attacking():
					atk += 1
			max_attackers = maxi(max_attackers, atk)
		for e in _enemies:
			if not is_instance_valid(e):
				continue
			states_seen[e.ai_state] = true
			for m in members:
				var d := Vector2(e.global_position.x - m.global_position.x, e.global_position.z - m.global_position.z).length()
				if t > 0.2:
					min_member = minf(min_member, d)
			for o in _enemies:
				if o != e and is_instance_valid(o):
					min_enemy = minf(min_enemy, (e.global_position - o.global_position).length())
	return {"min_member": min_member, "min_enemy": min_enemy, "max_attackers": max_attackers, "states": states_seen.keys()}


## Smallest gap (game s) between two consecutive target changes to a live target
## of the same enemy, and the max number of changes of any enemy.
func _retarget_stats() -> Dictionary:
	var min_gap := INF
	var max_changes := 0
	for k in _target_log:
		var log: Array = _target_log[k]
		max_changes = maxi(max_changes, log.size())
		var prev := -1.0
		for entry in log:
			if entry[1] == null:
				continue
			if prev >= 0.0:
				min_gap = minf(min_gap, float(entry[0]) - prev)
			prev = float(entry[0])
	return {"min_gap": min_gap, "max_changes": max_changes}


func _scenario_vs(target: Node3D, n: int, label: String) -> void:
	await _clear_enemies()
	var c := target.global_position
	var dirs := [Vector3(0, 0, -7), Vector3(6, 0, -5), Vector3(-6, 0, -4)]
	for i in n:
		_spawn(c + dirs[i])
	var hp0: float = target.current_hp
	_damaged_log.clear()
	var r: Dictionary = await _observe(8.0, [_player, _comp])
	var hp1: float = target.current_hp
	var on_target := 0
	for e in _enemies:
		if e.get_target() == target:
			on_target += 1
	var st := _retarget_stats()
	var tag := "1v%d vs %s" % [n, label]
	_assert(on_target == n, "%s: every enemy targets the %s" % [tag, label], "on_target=%d" % on_target)
	_assert(r.min_member >= MIN_MEMBER_DIST, "%s: no enemy closer than stop_distance to any member" % tag,
		"min=%.3f m" % r.min_member)
	_assert(n == 1 or r.min_enemy >= 1.0, "%s: enemies do not stack" % tag, "min_enemy=%.3f" % r.min_enemy)
	_assert(int(st.max_changes) <= 1, "%s: one target acquire per enemy, no flapping" % tag, "max target_changed=%d" % st.max_changes)
	_assert(int(r.max_attackers) <= 2, "%s: at most 2 simultaneous attackers on one member" % tag, "max=%d" % r.max_attackers)
	_assert(EnemyBase.AIState.ATTACK_STRIKE in r.states and hp1 < hp0,
		"%s: enemies strike from the ring and land through the %s's hurtbox" % [tag, label],
		"hp %.0f -> %.0f" % [hp0, hp1])
	if label == "companion":
		var got := false
		for d in _damaged_log:
			if d[0] == &"companion" and float(d[1]) > 0.0:
				got = true
		_assert(got, "%s: Events.party_member_damaged(companion, amount, source) emitted" % tag, str(_damaged_log.size()))
		if n == 1:
			# Flinch: catch the next hit.
			var flinched := false
			var t0 := _game_time
			while _game_time - t0 < 4.0:
				await get_tree().physics_frame
				if _comp.is_flinching():
					flinched = true
					break
			var s_before: int = _comp.strikes_executed
			var cur_str: String = _comp.ai_string
			_assert(flinched and cur_str == "", "Companion hit -> FLINCH (running string dropped)",
				"flinched=%s string=%s" % [flinched, cur_str])
			await get_tree().physics_frame
			_assert(_comp.strikes_executed == s_before, "No AI actions while flinching")


func _scenario_mixed() -> void:
	await _clear_enemies()
	_player.global_position = Vector3(-2, 0.1, 0)
	_comp.global_position = Vector3(2, 0, 0)
	await _physics_frames(5)
	_spawn(Vector3(-2, 0, -8))
	_spawn(Vector3(2, 0, -8))
	_spawn(Vector3(0, 0, -9))
	await _physics_frames(5)
	_enemies[1].take_damage(30.0, _comp)  # companion damage -> threat on its victim
	var r: Dictionary = await _observe(10.0, [_player, _comp])
	var on_p := 0
	var on_c := 0
	for e in _enemies:
		if e.get_target() == _player:
			on_p += 1
		elif e.get_target() == _comp:
			on_c += 1
	var st := _retarget_stats()
	_assert(on_c >= 1 and on_p >= 1, "Mixed: enemies split over both members", "player=%d companion=%d" % [on_p, on_c])
	_assert(_enemies[1].get_target() == _comp, "Mixed: companion damage draws its victim onto the companion")
	_assert(r.min_member >= MIN_MEMBER_DIST, "Mixed: no overlap with either member", "min=%.3f" % r.min_member)
	_assert(int(r.max_attackers) <= 2, "Mixed: at most 2 simultaneous attackers per member", "max=%d" % r.max_attackers)
	_assert(st.min_gap == INF or float(st.min_gap) >= 1.95,
		"No flapping: consecutive voluntary retargets of one enemy are >= 2 s apart (game time)",
		"min gap=%s s, max changes=%d" % [str(snappedf(float(st.min_gap), 0.01)) if st.min_gap != INF else "none", st.max_changes])
	# Tactical slow (0.05) while enemies retarget: heavy companion threat.
	var victim: Node3D = null
	for e in _enemies:
		if e.get_target() == _player:
			victim = e
			break
	if victim == null:
		_fail("Tactical retarget", "no enemy on the player")
		return
	GameManager.enter_tactical_mode()
	await _physics_frames(2)
	victim.take_damage(200.0, _comp)
	var r2: Dictionary = await _observe(2.3, [_player, _comp])
	_assert(victim.get_target() == _comp, "Tactical (0.05): high companion threat retargets the enemy after the hold")
	_assert(r2.min_member >= MIN_MEMBER_DIST, "Tactical: spacing holds while enemies retarget", "min=%.3f" % r2.min_member)
	GameManager.exit_tactical_mode()
	await _physics_frames(2)
	_assert(is_equal_approx(Engine.time_scale, 1.0), "Tactical exit restores time scale 1.0", str(Engine.time_scale))


func _scenario_downed() -> void:
	var on_c := 0
	for e in _enemies:
		if is_instance_valid(e) and e.get_target() == _comp:
			on_c += 1
	_comp.set_physics_process(true)
	_comp.take_damage(_comp.current_hp + 10.0, _enemies[0])
	await _physics_frames(3)
	var hb: Area3D = _comp.get_node(^"Hurtbox")
	_assert(_comp.is_downed() and _comp.ai_state == 3, "Companion at 0 HP is DOWNED", "ai_state=%d" % _comp.ai_state)
	_assert(not hb.monitoring, "Downed companion's Hurtbox is off")
	var still_on := 0
	for e in _enemies:
		if is_instance_valid(e) and e.get_target() == _comp:
			still_on += 1
	_assert(still_on == 0, "Enemies drop the downed member at once", "were on companion=%d, still=%d" % [on_c, still_on])
	var s0: int = _comp.strikes_executed
	var p0: Vector3 = _comp.global_position
	var r: Dictionary = await _observe(3.0, [_player, _comp])
	_assert(_comp.strikes_executed == s0 and _comp.global_position.distance_to(p0) < 0.05,
		"Downed companion takes no actions (no strikes, does not move)")
	_assert(r.min_member >= MIN_MEMBER_DIST, "After the retarget: no overlap with either member (downed included)",
		"min=%.3f" % r.min_member)
	var hp_before: float = _comp.current_hp
	_comp.take_damage(10.0, _enemies[0])
	_assert(_comp.current_hp == hp_before and _comp.is_downed(), "A downed companion takes no further damage")
	_player.state_machine.force_transition(&"Idle")
	await _physics_frames(2)
	var before: int = _party.active_index
	_switch_log.clear()
	var ok: bool = _party.switch_member()
	_assert(not ok and _party.active_index == before and _switch_log.is_empty(),
		"Party switch onto a downed member is blocked (active member unchanged)")
	# Input path too: D-pad Up with the cooldown clear.
	await _real_seconds(SWITCH_WAIT)
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	_assert(_party.active_index == before and _switch_log.is_empty(), "D-pad switch onto a downed member is blocked")
	_comp.revive()
	await _physics_frames(3)
	_assert(not _comp.is_downed() and hb.monitoring, "Revive turns the Hurtbox back on")


func _teardown_bare() -> void:
	await _clear_enemies()
	if is_instance_valid(_comp):
		_comp.queue_free()
	if is_instance_valid(_party):
		_party.queue_free()
	if is_instance_valid(_world):
		_world.queue_free()
	_comp = null
	_party = null
	_player = null
	_world = null
	await _frames(5)


# ========== TOWN: AMARO IDLE ==========

func test_amaro_idle() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	await _physics_frames(10)
	var ap: AnimationPlayer = _player.anim_player
	_assert(ap != null and ap.has_animation(&"idle") and ap.has_animation(&"walk") and ap.has_animation(&"tpose"),
		"Amaro AnimationPlayer has idle / walk / tpose", str(ap.get_animation_list() if ap else []))
	if ap == null:
		return
	_assert(_state() == &"Idle" and ap.current_animation == &"idle", "Idle state plays 'idle' (not the T-pose)",
		"state=%s anim=%s" % [_state(), ap.current_animation])
	var idle: Animation = ap.get_animation(&"idle")
	var one_key := true
	var hips_ok := false
	for i in idle.get_track_count():
		one_key = one_key and idle.track_get_key_count(i) == 1
		if idle.track_get_type(i) == Animation.TYPE_POSITION_3D and String(idle.track_get_path(i)).ends_with("Hips"):
			var p: Vector3 = idle.track_get_key_value(i, 0)
			hips_ok = absf(p.x) < 0.0001 and absf(p.z) < 0.0001
	_assert(idle.get_track_count() > 0 and one_key, "'idle' is a static pose (1 key per track)", "tracks=%d" % idle.get_track_count())
	_assert(hips_ok, "'idle' hips X/Z are zero (stands on the body origin)")
	var walk: Animation = ap.get_animation(&"walk")
	var drift := INF
	for i in walk.get_track_count():
		if walk.track_get_type(i) == Animation.TYPE_POSITION_3D and String(walk.track_get_path(i)).ends_with("Hips"):
			var n := walk.track_get_key_count(i)
			var a: Vector3 = walk.track_get_key_value(i, 0)
			var b: Vector3 = walk.track_get_key_value(i, n - 1)
			drift = Vector2(b.x - a.x, b.z - a.z).length()
	_assert(walk.loop_mode == Animation.LOOP_LINEAR and drift < 0.05, "'walk' loops and is in place (hips drift < 5 cm)",
		"loop=%d drift=%.3f" % [walk.loop_mode, drift])
	var layer: Node = _player.visual_root.get_child(0) if _player.visual_root.get_child_count() > 0 else null
	_assert(layer != null and layer.name == "IdleLayer" and layer is RiglessVisual and layer.auto_fit == false
			and layer.yaw_mode == RiglessVisual.YawMode.NONE,
		"Amaro's VisualRoot child is the cosmetic IdleLayer (no auto-fit, yaw NONE)", str(layer.name if layer else "none"))
	_assert(layer != null and layer.get(&"_body") == _player, "IdleLayer reads the Player body (its own body)")
	# Walking plays 'walk', never the T-pose.
	Input.action_press(&"move_up")
	await _real_seconds(0.5)
	var walk_anim: StringName = ap.current_animation
	Input.action_release(&"move_up")
	_assert(walk_anim == &"walk", "Moving plays 'walk'", "anim=%s state=%s" % [walk_anim, _state()])
	await _ground_idle()
	await _physics_frames(10)
	# Command Menu (time scale 0.05): still the idle pose.
	await _open_command_menu()
	var in_menu := _state() == &"TacticalIdle"
	await _real_seconds(0.3)
	_assert(in_menu and is_equal_approx(Engine.time_scale, 0.05) and ap.current_animation == &"idle",
		"Command Menu (0.05): Amaro holds 'idle' (no T-pose)",
		"state=%s ts=%.2f anim=%s" % [_state(), Engine.time_scale, ap.current_animation])
	await _close_menu()


# ========== TOWN: NPCs ==========

func _npc(npc_name: String) -> Node3D:
	for c in _zone.get_children():
		if c.get(&"npc_name") == npc_name:
			return c
	return null


func test_npcs() -> void:
	var town_script: GDScript = load("res://scenes/zones/town_hub.gd")
	var soo := _npc("Merchant Soo")
	_assert(soo != null, "Merchant Soo exists")
	if soo:
		var want: float = town_script.npc_face_yaw(Vector3(4, 0, -8))
		_assert(is_equal_approx(soo.rotation.y, want) and absf(want) > 0.1,
			"Merchant Soo faces the road / approach (npc_face_yaw, non-zero)", "rot=%.3f want=%.3f" % [soo.rotation.y, want])
	var models := {"Scholar Yeun": "teacher_female2.glb", "Alchemist Ines": "alchemist_female1.glb",
		"Merchant Soo": "pirate_female1.glb"}
	for n in models:
		var npc := _npc(n)
		var rv: Node = npc.get_node_or_null(^"RiglessVisual") if npc else null
		var ok: bool = rv != null and rv.model_scene != null and String(rv.model_scene.resource_path).ends_with(models[n]) \
			and rv.face_speaker_in_dialogue
		_assert(ok, "%s uses %s (RiglessVisual, faces the speaker in dialogue)" % [n, models[n]],
			str(rv.model_scene.resource_path if rv and rv.model_scene else "none"))
	var yeun := _npc("Scholar Yeun")
	if yeun:
		_assert(yeun.global_position.is_equal_approx(Vector3(-4, 0, -27)) and absf(yeun.rotation.y) > 0.01,
			"Scholar Yeun stands at (-4, 0, -27) facing the street")
	# Default facing for every NPC points at the street (x = 0, 4 m south).
	var bad: Array = []
	for c in _zone.get_children():
		if c.get(&"npc_name") == null:
			continue
		var p: Vector3 = c.global_position
		if is_equal_approx(p.x, 0.0):
			continue
		var want2: float = town_script.npc_face_yaw(p)
		if not is_equal_approx(wrapf(c.rotation.y - want2, -PI, PI), 0.0):
			bad.append(c.npc_name)
	_assert(bad.is_empty(), "Every town NPC defaults to facing the street/approach", str(bad))
	# Dialogue facing (cosmetic): the model NPC looks at the player, then lets go.
	var ines := _npc("Alchemist Ines")
	var rvi: Node = ines.get_node_or_null(^"RiglessVisual") if ines else null
	if rvi:
		_player._current_interactable = ines
		Events.dialogue_started.emit()
		await _frames(10)
		var lt = rvi.get_look_target()
		Events.dialogue_ended.emit()
		await _frames(3)
		_player._current_interactable = null
		_assert(lt == _player and rvi.get_look_target() == null,
			"Alchemist Ines turns to the player in dialogue and lets go after", "during=%s after=%s" % [lt, rvi.get_look_target()])


# ========== TOWN: PARTY SWITCH + VISIBLE MODEL ==========

## "amaro" = the red-knight IdleLayer, "taighe" = RiglessVisual(princess1.glb), else a description.
func _visual_id(body: Node) -> String:
	var vr: Node3D = body.get(&"visual_root")
	if vr == null:
		return "no visual_root"
	var vis: Array = []
	for c in vr.get_children():
		if c is Node3D and (c as Node3D).visible:
			vis.append(c)
	if vis.size() != 1:
		return "visible children=%d" % vis.size()
	var m: Node = vis[0]
	if m.name == "IdleLayer":
		return "amaro"
	if m.name == "RiglessVisual" and m.get(&"model_scene") != null and String(m.model_scene.resource_path) == PRINCESS_GLB:
		return "taighe"
	return "other:%s" % m.name


func test_switch_to_taighe() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	await _ground_idle()
	var comp: Node = _party.get_companion() if _party else null
	_assert(comp != null, "Town party has a companion body")
	if comp == null:
		return
	_assert(_is_member(&"hero") and _visual_id(_player) == "amaro" and _visual_id(comp) == "taighe",
		"Before the switch: Player shows Amaro, AI body shows Taighe",
		"player=%s comp=%s" % [_visual_id(_player), _visual_id(comp)])
	await _real_seconds(SWITCH_WAIT)
	_switch_log.clear()
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	await _frames(3)
	_assert(_is_member(&"companion") and _player.get_member_data().display_name == "Taighe",
		"D-pad Up: control passes to Taighe", str(_switch_log))
	_assert(_visual_id(_player) == "taighe", "After the switch the Player node shows Taighe's model", _visual_id(_player))
	_assert(_visual_id(comp) == "amaro", "...and the AI body shows Amaro's model", _visual_id(comp))
	var rv: Node = _player.visual_root.get_child(0)
	_assert(rv.get(&"_body") == _player and _player.model == rv,
		"Taighe's RiglessVisual re-bound to the Player body (player.model updated)")
	_assert(_player.combo.active_profile().is_mage(), "Player's combo now resolves Taighe's mage profile")
	_assert(comp.attack_profile != null and not comp.attack_profile.is_mage(), "AI body (Amaro) runs the melee profile")
	# Amaro AI-standing: the held idle pose, never the T-pose.
	await _real_seconds(0.8)
	var an: AnimationPlayer = comp.get(&"_anim")
	_assert(an != null and an.current_animation == &"idle", "AI-controlled Amaro standing plays 'idle'",
		"anim=%s speed=%.2f" % [an.current_animation if an else &"none", Vector2(comp.velocity.x, comp.velocity.z).length()])


func test_switch_back_to_amaro() -> void:
	var comp: Node = _party.get_companion() if _party else null
	if comp == null:
		_fail("Switch back", "no companion")
		return
	_free_dummies()
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	comp.global_position = LANE_ORIGIN + Vector3(2, -0.1, 1)
	comp.set_physics_process(true)
	await _ground_idle()
	await _real_seconds(SWITCH_WAIT)
	if _is_member(&"hero"):
		_fail("Switch back", "already Amaro")
		return
	await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
	await _frames(3)
	_assert(_is_member(&"hero") and _player.get_member_data().display_name == "Amaro", "D-pad Down: control back to Amaro")
	_assert(_visual_id(_player) == "amaro" and _visual_id(comp) == "taighe",
		"After switching back: Player shows Amaro, AI body shows Taighe",
		"player=%s comp=%s" % [_visual_id(_player), _visual_id(comp)])
	await _ground_idle()
	await _physics_frames(6)
	var ap: AnimationPlayer = _player.anim_player
	_assert(ap != null and ap.current_animation == &"idle", "Amaro back on the Player node plays 'idle'",
		str(ap.current_animation if ap else &"none"))
	_assert(not _player.combo.active_profile().is_mage() and comp.attack_profile.is_mage(),
		"Profiles follow the identities back (Player melee, AI Taighe mage)")


# ========== TOWN: TAIGHE KIT ==========

func _strike() -> Node:
	return _player.state_machine.states.get(&"MeleeStrike")


func _freeze_companion_far() -> void:
	var comp: Node3D = _party.get_companion()
	_park(comp, Vector3(40, 0.1, 30))


func _wait_combo_clear() -> void:
	await _wait_until(func(): return _state() != &"MeleeStrike", 3.0)
	await _real_seconds(0.5)
	await _ground_idle()


func _hits_on(e: Node) -> Array:
	var out: Array = []
	for h in _hit_log:
		if h[0] == e:
			out.append(float(h[1]))
	return out


func test_taighe_bolts() -> void:
	_freeze_companion_far()
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -8.0))
	await _ground_idle()
	_hit_log.clear()
	_bolt_nodes.clear()
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.05)
	var st := _strike()
	_assert(_state() == &"MeleeStrike" and st.mage and st.kind == &"light", "X tap (Taighe) = a mage light strike",
		"state=%s mage=%s kind=%s" % [_state(), st.mage, st.kind])
	await _wait_until(func(): return not _hits_on(e).is_empty(), 2.0)
	var lb: Dictionary = st.last_bolt
	_assert(lb.get("kind") == &"light" and lb.get("target") == e and is_equal_approx(float(lb.get("damage", 0)), 9.0),
		"Quick bolt soft-aims the 8 m enemy (9 dmg)", str(lb))
	await _real_seconds(0.3)
	_assert(_approx_list(_hits_on(e), [9.0]), "Quick bolt hits once for 9", str(_hits_on(e)))
	_assert(_bolt_nodes.size() == 1, "One MageBolt spawned for a tap", str(_bolt_nodes.size()))
	_assert(_player.current_mp >= 0.0 and _src_is(_hit_log, e, _player), "Bolt damage is attributed to the Player body (source)")
	await _wait_combo_clear()
	# Hold = charged shot.
	_hit_log.clear()
	e.stagger_value = 0.0
	var mp0: float = _player.current_mp
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.32)
	_assert(_state() == &"MeleeStrike" and st.mage and st.kind == &"heavy", "X hold (Taighe) = charged shot",
		"state=%s kind=%s" % [_state(), st.kind])
	await _wait_until(func(): return not _hits_on(e).is_empty(), 2.0)
	await _physics_frames(2)
	_assert(_approx_list(_hits_on(e), [17.0]), "Charged shot hits once for 17 (> 9)", str(_hits_on(e)))
	_assert(absf(e.stagger_value - 18.0) < 0.6, "Charged shot builds 18 stagger", "stagger=%.1f" % e.stagger_value)
	_assert(_player.current_mp >= mp0 - 0.01, "Basic mage attacks cost 0 MP", "mp %.1f -> %.1f" % [mp0, _player.current_mp])
	await _wait_combo_clear()


func _approx_list(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.05:
			return false
	return true


func _has_approx(a: Array, v: float) -> bool:
	for x in a:
		if absf(float(x) - v) <= 0.05:
			return true
	return false


func _src_is(log: Array, e: Node, src: Node) -> bool:
	for h in log:
		if h[0] == e and h[2] == src:
			return true
	return false


func _play_string(letters: String) -> void:
	for l in letters:
		if l == "H":
			await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.30)
		else:
			await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.05)
			await _real_seconds(0.06)
	await _wait_until(func(): return _state() != &"MeleeStrike", 4.0)
	await _real_seconds(0.9)


func test_taighe_finishers() -> void:
	_free_dummies()
	await _physics_frames(2)
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -8.0))
	var side: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(3.5, -0.1, -8.0))
	await _ground_idle()
	var results := {}
	for s in ["LLL", "HHH"]:
		_hit_log.clear()
		_finisher_log.clear()
		_place_player(LANE_ORIGIN, 0.0)
		await _ground_idle()
		await _play_string(s)
		var st := _strike()
		results[s] = {"fin": _finisher_log.duplicate(), "main": _hits_on(e), "side": _hits_on(side),
			"bolt": st.last_bolt.duplicate()}
		await _wait_combo_clear()
	var lll: Dictionary = results["LLL"]
	var hhh: Dictionary = results["HHH"]
	_assert(lll.fin.size() == 1 and lll.fin[0][0] == &"arcane_burst" and is_equal_approx(float(lll.fin[0][1]), 2.0),
		"LLL -> Arcane Burst (2.0 m) announced", str(lll.fin))
	_assert(hhh.fin.size() == 1 and hhh.fin[0][0] == &"lumina_nova" and is_equal_approx(float(hhh.fin[0][1]), 4.5),
		"HHH -> Lumina Nova (4.5 m) announced", str(hhh.fin))
	_assert(lll.bolt.get("step") == 3 and lll.bolt.get("finisher") == &"arcane_burst"
			and is_equal_approx(float(lll.bolt.get("burst_radius", 0)), 2.0),
		"LLL step 3 fires the Arcane Burst orb", str(lll.bolt))
	_assert(_approx_list(lll.main, [9.0, 9.0, 12.6]), "LLL on the target: 9, 9, then the burst 9 x 1.4 = 12.6 (each once)", str(lll.main))
	_assert(_approx_list(hhh.main, [17.0, 17.0, 51.0]), "HHH on the target: 17, 17, then the burst 17 x 3.0 = 51 (each once)", str(hhh.main))
	_assert(lll.side.is_empty(), "LLL burst (2.0 m) does not reach the side enemy at 3.5 m", str(lll.side))
	_assert(_approx_list(hhh.side, [51.0]), "HHH burst (4.5 m) reaches the side enemy at 3.5 m, once", str(hhh.side))


func test_taighe_dodge_fizzle() -> void:
	_free_dummies()
	await _physics_frames(2)
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -8.0))
	await _ground_idle()
	await _wait_until(func(): return bool(_player.dodge_ready), 2.0)
	_hit_log.clear()
	_bolt_nodes.clear()
	Input.parse_input_event(_joy_press(JOY_X))
	var entered: bool = await _wait_until(func(): return _state() == &"MeleeStrike", 1.0)
	var st := _strike()
	var bolt: Node = st.get(&"_bolt")
	var charging: bool = bolt != null and is_instance_valid(bolt) and not bolt.launched
	Input.parse_input_event(_joy_press(JOY_B))
	await _physics_frames(2)
	Input.parse_input_event(_joy_release(JOY_B))
	Input.parse_input_event(_joy_release(JOY_X))
	var dodged := _state() == &"Dodge"
	_assert(entered and charging, "Holding X: the charged shot is charging at the hand",
		"entered=%s charging=%s kind=%s" % [entered, charging, st.kind])
	_assert(dodged, "B cancels the charging strike into Dodge", "state=%s" % _state())
	var fizzled: bool = bolt == null or not is_instance_valid(bolt) or (bool(bolt.done) and not bool(bolt.launched))
	_assert(fizzled, "The charging bolt fizzles (never launches)")
	_assert(_player.combo.current_string() == "", "The string is reset by the dodge", _player.combo.current_string())
	await _real_seconds(1.0)
	_assert(_hits_on(e).is_empty(), "A fizzled bolt deals no damage", str(_hits_on(e)))
	await _ground_idle()


func test_taighe_bolt_slowed() -> void:
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = _dummies[0] if not _dummies.is_empty() else await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -8.0))
	await _wait_combo_clear()
	_hit_log.clear()
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.03)
	var st := _strike()
	var bolt: Node = null
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 1000:
		var cand = st.last_bolt.get("node") if not st.last_bolt.is_empty() else null
		if cand != null and is_instance_valid(cand) and bool(cand.launched) and not bool(cand.done):
			bolt = cand
			break
		await get_tree().physics_frame
	if bolt == null or not is_instance_valid(bolt) or bool(bolt.done):
		_fail("Bolt in flight", "no launched bolt to slow")
		return
	GameManager._push_time_scale("ll_command_menu", GameManager.TACTICAL_TIME_SCALE)
	var p0: Vector3 = bolt.global_position
	await _real_seconds(0.3)
	var moved: float = bolt.global_position.distance_to(p0) if is_instance_valid(bolt) else -1.0
	var alive: bool = is_instance_valid(bolt) and not bool(bolt.done)
	GameManager._pop_time_scale("ll_command_menu")
	_assert(alive and moved >= 0.0 and moved < 1.5, "At the Command Menu scale (0.05) a bolt in flight crawls (< 1.5 m in 0.3 s real; ~9.6 m at 1.0)",
		"moved=%.2f m alive=%s" % [moved, alive])
	await _wait_until(func(): return not _hits_on(e).is_empty(), 2.0)
	_assert(_approx_list(_hits_on(e), [9.0]), "...and still lands after the slow ends", str(_hits_on(e)))
	await _wait_combo_clear()


# ========== TOWN: AMARO MELEE ==========

func test_amaro_melee() -> void:
	_free_dummies()
	await _physics_frames(2)
	_freeze_companion_far()
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -1.8))
	await _ground_idle()
	_hit_log.clear()
	_bolt_nodes.clear()
	await _tap(_joy_press(JOY_X), _joy_release(JOY_X), 0.05)
	var st := _strike()
	_assert(_state() == &"MeleeStrike" and not st.mage and st.kind == &"light", "Amaro X tap = melee light strike",
		"state=%s mage=%s" % [_state(), st.mage])
	await _wait_until(func(): return _state() != &"MeleeStrike", 2.0)
	await _physics_frames(3)
	var srcs: Array = []
	for h in _hit_log:
		if h[0] == e:
			srcs.append(String(h[2].name) if h[2] else "null")
	_assert(_approx_list(_hits_on(e), [12.0]), "Amaro light hits once for 12 through the sword hitbox", "%s src=%s" % [str(_hits_on(e)), str(srcs)])
	_assert(_bolt_nodes.is_empty(), "Amaro spawns no MageBolts")
	await _wait_combo_clear()


# ========== TOWN: SWORD SLASH VFX + RANGE DIM ==========

func test_sword_slash_and_range_dim() -> void:
	_free_dummies()
	await _physics_frames(2)
	await _ground_idle()
	_place_player(LANE_ORIGIN, 0.0)
	var e1: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -2.5))
	var e2: Node = await _spawn_dummy(LANE_ORIGIN + Vector3(0, -0.1, -10.0))
	await _ground_idle()
	_player.current_mp = _player.max_mp
	var tac := await _open_to_ability(&"sword_slash")
	if tac == null:
		return
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	_assert(int(tac._phase) == PHASE_TARGET and tac._target_candidates.size() >= 2, "Sword Slash target step open")
	var ind := _hud("lock_on_indicator.gd")
	var tbar := _hud("target_bar.gd")
	await _tap(_joy_press(JOY_DPAD_RIGHT), _joy_release(JOY_DPAD_RIGHT))
	await _frames(3)
	_assert(tac._target_index == 1 and tbar and tbar.is_out_of_range() and ind and ind.is_out_of_range(),
		"Highlighting the 10 m enemy marks reticle + bar out of range")
	if tbar and ind:
		var panel: Control = tbar._panel
		var dimmed: bool = tbar._name_label.modulate != Color.WHITE and tbar._hp_gauge.modulate != Color.WHITE \
			and tbar._stagger_row.modulate != Color.WHITE
		_assert(dimmed, "Target bar dims its content (name, HP gauge, stagger row)")
		_assert(panel.modulate == Color.WHITE and panel.self_modulate == Color.WHITE and panel.visible,
			"Target bar panel itself is not dimmed (modulate white)")
		var oor_fill: Color = tbar.get_script().get_script_constant_map()["OUT_OF_RANGE_FILL"]
		_assert(panel.fill_color.is_equal_approx(oor_fill) and panel.fill_color.v < 0.25 and panel.fill_color.a >= 0.9,
			"Target bar keeps a dark, near-opaque backing panel", str(panel.fill_color))
		_assert(tbar._range_tag != null and tbar._range_tag.visible and tbar._range_tag.modulate == Color.WHITE,
			"Target bar shows an undimmed OUT OF RANGE pill")
		_assert(ind._indicator.modulate == Color.WHITE and ind._reticle.modulate != Color.WHITE,
			"Reticle dims; the indicator root does not")
		var fs: int = ind._label.get_theme_font_size(&"font_size")
		_assert(ind._label.text == "OUT OF RANGE" and fs >= 20 and ind._label_box.get_theme_stylebox(&"panel") is StyleBoxFlat,
			"Reticle label 'OUT OF RANGE' is large (>= 20 px) on a dark pill", "text=%s size=%d" % [ind._label.text, fs])
	await _tap(_joy_press(JOY_DPAD_UP), _joy_release(JOY_DPAD_UP))
	await _frames(3)
	_assert(tac._target_index == 0 and not tbar.is_out_of_range() and tbar._name_label.modulate == Color.WHITE
			and tbar._panel.fill_color.is_equal_approx(UIStyle.GLASS),
		"Back in range: content and panel restored")
	# Cast on the 2.5 m enemy and time the visuals.
	_player.current_atb = _player.max_atb
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	var fx := await _wait_effect()
	_assert(fx != null, "Sword Slash spawned its effect", "state=%s fails=%s" % [_state(), str(_fail_log)])
	if fx == null:
		return
	var t0 := _game_time
	var trail: MeshInstance3D = fx.find_child("SlashTrail", true, false)
	var mat: StandardMaterial3D = trail.material_override if trail else null
	_assert(mat != null and mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
			and mat.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED
			and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
		"Sword Slash crescent is translucent additive, unshaded, no depth write")
	var gone_at := -1.0
	while _game_time - t0 < 1.0:
		await get_tree().physics_frame
		if not is_instance_valid(fx) or fx.get_node_or_null(^"Sweep") == null:
			gone_at = _game_time - t0
			break
	_assert(gone_at >= 0.0 and gone_at <= 0.27, "Sword Slash visuals are gone within ~0.25 s (game time)",
		"gone at %.3f s" % gone_at)
	var hits: Array = fx.get(&"hit_targets") if is_instance_valid(fx) else []
	_assert(e1 in hits and not (e2 in hits), "Sword Slash hit the 2.5 m enemy only")
	await _wait_until(func(): return _state() != &"Ability", 3.0)
	await _ground_idle()


# ========== DUNGEON ==========

func test_dungeon_models() -> void:
	if not await _load_zone(DUNGEON_SCENE):
		_fail("Dungeon harness", "dungeon_zone failed to load")
		return
	var chief: Node = null
	var names: Array = []
	var goblin: Node = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		names.append(e.display_name)
		if e.display_name == "Goblin Chief":
			chief = e
		elif e.display_name == "Goblin":
			goblin = e
	_assert(goblin != null and goblin.rigless_model != null
			and String(goblin.rigless_model.resource_path).ends_with("goblin_male2.glb"),
		"Dungeon spawns a Goblin (goblin_male2.glb)", str(names))
	_assert(chief != null, "Dungeon spawns the Goblin Chief elite", str(names))
	if chief == null:
		return
	var rv: Node = chief.visual_root.get_node_or_null(^"RiglessVisual")
	var fitted: float = float(rv.get(&"_fitted_height")) if rv else 0.0
	_assert(is_equal_approx(chief.rigless_fit_height, 2.4) and absf(fitted - 2.4) < 0.1
			and String(chief.rigless_model.resource_path).ends_with("goblinchief_male1.glb"),
		"Goblin Chief model goblinchief_male1.glb fitted to ~2.4 m", "fit=%.2f fitted=%.2f" % [chief.rigless_fit_height, fitted])
	var cap: Shape3D = (chief.get_node(^"CollisionShape3D") as CollisionShape3D).shape
	_assert(cap is CapsuleShape3D and is_equal_approx((cap as CapsuleShape3D).height, 2.4),
		"Goblin Chief collision capsule height 2.4", str(cap))
	var lp: Node3D = chief.get_node_or_null(^"LockOnPoint")
	var hb: Node3D = chief.get_node_or_null(^"HealthBar")
	_assert(lp != null and lp.position.y > 1.6, "Goblin Chief LockOnPoint raised (> 1.6 m)", str(lp.position.y if lp else -1))
	_assert(hb != null and hb.position.y > 2.6, "Goblin Chief health bar above the 2.4 m model", str(hb.position.y if hb else -1))
	var reg: Node = (load(ENEMY_SCENE) as PackedScene).instantiate()
	var shared_h: float = ((reg.get_node(^"CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).height
	reg.free()
	_assert(is_equal_approx(shared_h, 1.6), "enemy.tscn's shared capsule stays 1.6 m (per-spawn copy)")
	_assert(chief.max_hp >= 140.0 and is_equal_approx(chief.attack_range, 2.4), "Goblin Chief elite stats (HP 140, reach 2.4)")


# ========== HELPERS ==========

func _load_town() -> bool:
	return await _load_zone(TOWN_SCENE)


func _load_zone(path: String) -> bool:
	var ps = load(path) as PackedScene
	if ps == null:
		_fail("Zone harness", "%s failed to load" % path)
		return false
	GameManager.change_state(GameManager.GameState.PLAYING)
	_zone = ps.instantiate()
	add_child(_zone)
	await _frames(2)
	# Block the deferred autosave on entry (it only saves while PLAYING).
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	await _frames(45)
	GameManager.change_state(GameManager.GameState.PLAYING)
	await _frames(45)
	_player = _zone.get(&"player")
	if _player == null or not is_instance_valid(_player):
		_fail("Zone harness", "zone has no player")
		return false
	_party = _player.party_system
	_rig = null
	for ch in _zone.get_children():
		if ch.get(&"yaw_pivot") != null and ch.has_method(&"get_frame_angle"):
			_rig = ch
	_assert(_rig != null and _party != null and _party.get_member_count() >= 2,
		"%s harness: player, party (2 members) and camera rig found" % path.get_file())
	await _wait_on_floor(240)
	InputManager.active_device = InputManager.DeviceType.CONTROLLER
	return _rig != null and _party != null


func _hud(script_file: String) -> Node:
	if _zone == null:
		return null
	for ch in _zone.get_children():
		if ch.get_script() and String(ch.get_script().resource_path).ends_with(script_file):
			return ch
	return null


func _place_player(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	if _rig:
		_rig.global_position = pos
		_rig._yaw = yaw


func _spawn_dummy(pos: Vector3) -> Node:
	var e: Node = (load(ENEMY_SCENE) as PackedScene).instantiate()
	_zone.add_child(e)
	e.global_position = pos
	await _physics_frames(2)
	e.set_physics_process(false)
	e.set_process(false)
	e.max_hp = 100000.0
	e.current_hp = e.max_hp
	e.stagger_max = 100000.0
	e.ai_state = EnemyBase.AIState.IDLE
	_dummies.append(e)
	return e


func _free_dummies() -> void:
	for e in _dummies:
		if is_instance_valid(e):
			e.queue_free()
	_dummies.clear()


func _ground_idle() -> void:
	_release_all_input()
	if _state() == &"TacticalIdle":
		await _close_menu()
	await _wait_on_floor(300)
	if _state() != &"Idle" and _state() != &"LockOnIdle":
		_player.state_machine.force_transition(&"Idle")
	_player.velocity = Vector3.ZERO
	await _physics_frames(2)


func _open_command_menu() -> void:
	await _ground_idle()
	if _player.in_battle:
		await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	else:
		_player._current_interactable = null
		await _tap(_joy_press(JOY_Y), _joy_release(JOY_Y))
	if _state() != &"TacticalIdle":
		return
	var tac: Node = _player.state_machine.current_state
	await _wait_until(func(): return bool(tac._confirm_armed), 3.0)


func _open_to_ability(id: StringName) -> Node:
	_fail_log.clear()
	_player.current_atb = _player.max_atb
	await _open_command_menu()
	if _state() != &"TacticalIdle":
		_fail("Command Menu opens (for %s)" % id, "state=%s" % _state())
		return null
	var tac: Node = _player.state_machine.current_state
	await _tap(_joy_press(JOY_A), _joy_release(JOY_A))
	if int(tac._phase) != PHASE_ABILITY:
		_fail("Abilities category opens (for %s)" % id, "phase=%s" % str(tac._phase))
		return null
	var guard := 0
	while (tac._ability_at_cursor() == null or tac._ability_at_cursor().ability_id != id) and guard < 10:
		await _tap(_joy_press(JOY_DPAD_DOWN), _joy_release(JOY_DPAD_DOWN))
		guard += 1
	if tac._ability_at_cursor() == null or tac._ability_at_cursor().ability_id != id:
		_fail("Ability list reaches %s" % id)
		await _close_menu()
		return null
	return tac


func _wait_effect() -> Node:
	var st: Node = _player.state_machine.states.get(&"Ability")
	if st == null:
		return null
	st.last_effect = null
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2500:
		await get_tree().physics_frame
		if st.last_effect != null and is_instance_valid(st.last_effect):
			return st.last_effect
	return null


func _close_menu() -> void:
	var tries := 0
	while _state() == &"TacticalIdle" and tries < 4:
		await _tap(_joy_press(JOY_B), _joy_release(JOY_B))
		tries += 1
	if _state() == &"TacticalIdle":
		_player.state_machine.force_transition(&"Idle")
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	Engine.time_scale = 1.0
	await _frames(2)


func _connect_logs() -> void:
	Events.ability_request_failed.connect(func(r, _a): _fail_log.append(str(r)))
	Events.party_member_switched.connect(func(o, n): _switch_log.append([o, n]))
	Events.enemy_hit.connect(func(e, a, s): _hit_log.append([e, a, s]))
	Events.combo_finisher.connect(func(k, r): _finisher_log.append([k, r]))
	Events.party_member_damaged.connect(func(i, a, s): _damaged_log.append([i, a, s]))
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	var sc: Script = n.get_script()
	if sc != null and String(sc.resource_path).ends_with("mage_bolt.gd"):
		_bolt_nodes.append(n)


func _is_member(id: StringName) -> bool:
	return _party != null and _party.members.size() > _party.active_index \
		and _party.members[_party.active_index].id == id


func _teardown_zone() -> void:
	_release_all_input()
	_free_dummies()
	if GameManager.current_state != GameManager.GameState.PLAYING:
		GameManager.change_state(GameManager.GameState.PLAYING)
	Engine.time_scale = 1.0
	# The companion body lives in current_scene (this runner), not in the zone.
	if _party:
		for m in _party.members:
			var n: Node = m.get("node")
			if is_instance_valid(n) and n != _player and not _zone.is_ancestor_of(n):
				n.queue_free()
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_player = null
	_party = null
	_rig = null


func _state() -> StringName:
	if _player == null or not is_instance_valid(_player) or _player.state_machine.current_state == null:
		return &""
	return _player.state_machine.current_state.name


func _wait_on_floor(max_frames: int = 120) -> bool:
	for i in max_frames:
		if _player.is_on_floor():
			return true
		await get_tree().physics_frame
	return _player.is_on_floor()


func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout_s * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _release_all_input() -> void:
	for a in [&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"interact", &"attack",
			&"jump", &"dodge", &"tactical_mode", &"unique_ability", &"battle_toggle", &"lock_on"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(press: InputEvent, release: InputEvent, hold: float = 0.05) -> void:
	Input.parse_input_event(press)
	await _real_seconds(hold)
	Input.parse_input_event(release)
	await _real_seconds(0.08)


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _real_seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _joy_press(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = true
	return ev


func _joy_release(idx: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = idx
	ev.pressed = false
	return ev


func _get_source(path: String) -> String:
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String, reason: String = "") -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name, reason)


func _section(title: String) -> void:
	print("")
	print("--- %s ---" % title)


func _pass(test_name: String) -> void:
	_passed += 1
	_total += 1
	print("  PASS: %s" % test_name)


func _fail(test_name: String, reason: String = "") -> void:
	_failed += 1
	_total += 1
	var msg := "  FAIL: %s" % test_name
	if reason != "":
		msg += " — %s" % reason
	print(msg)
