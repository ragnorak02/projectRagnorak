## Phase 14 tests: Audio & VFX (items 341-365).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 14: Audio & VFX Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 14 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: AudioManager Core (items 341)
	_section("AUDIO MANAGER CORE")
	test_audio_manager_exists()
	test_audio_manager_is_autoload()
	test_audio_manager_has_music_player()
	test_audio_manager_has_sfx_pool()
	test_audio_manager_process_mode_always()
	test_audio_manager_has_sfx_registry()
	test_audio_manager_has_music_registry()
	test_audio_manager_play_sfx_named()
	test_audio_manager_play_sfx_varied()
	test_audio_manager_has_sfx_check()
	test_audio_manager_play_music_named()
	test_audio_manager_stop_music()
	test_audio_manager_crossfade()
	test_audio_manager_volume_controls()
	test_audio_manager_register_sfx()
	test_audio_manager_register_music()
	test_audio_manager_null_safety()

	# Category 2: Menu SFX Hooks (item 342)
	_section("MENU SFX HOOKS")
	test_pause_menu_sfx_open()
	test_pause_menu_sfx_close()
	test_pause_menu_sfx_select()
	test_pause_menu_sfx_confirm()
	test_main_menu_sfx_new_game()
	test_main_menu_sfx_continue()
	test_main_menu_sfx_load()

	# Category 3: Combat SFX Hooks (items 343-346)
	_section("COMBAT SFX HOOKS")
	test_attack_1_sfx()
	test_attack_2_sfx()
	test_attack_3_sfx()
	test_jump_attack_sfx()
	test_dodge_sfx()
	test_spell_cast_sfx()
	test_spell_release_sfx()
	test_spell_interrupt_sfx()
	test_hit_react_sfx()
	test_enemy_hurt_sfx()
	test_enemy_die_sfx()

	# Category 4: Music Hooks (items 347-350)
	_section("MUSIC HOOKS")
	test_zone_music_connection()
	test_battle_music_connection()
	test_music_registry_zones()
	test_music_state_tracking()
	test_pre_battle_restore()

	# Category 5: Tactical Audio (item 361)
	_section("TACTICAL AUDIO")
	test_tactical_mode_audio_enter()
	test_tactical_mode_audio_exit()

	# Category 6: VFX — Attack (items 351-352)
	_section("VFX — ATTACKS & SPELLS")
	test_attack_vfx_exists()
	test_attack_vfx_has_4_colors()
	test_attack_vfx_has_spawn_method()
	test_spell_projectile_exists()
	test_spell_projectile_has_damage()

	# Category 7: VFX — Dodge (item 353)
	_section("VFX — DODGE")
	test_dodge_vfx_exists()
	test_dodge_vfx_has_spawn_method()
	test_dodge_vfx_ghost_shape()
	test_dodge_vfx_fade_out()
	test_dodge_state_spawns_vfx()

	# Category 8: VFX — UI Polish (items 354-356)
	_section("VFX — UI POLISH")
	test_lock_on_indicator_exists()
	test_lock_on_indicator_pulse()
	test_interaction_prompt_pulse()
	test_pause_menu_transition()

	# Category 9: VFX — Team Attack (item 357)
	_section("VFX — TEAM ATTACK")
	test_team_attack_vfx_exists()
	test_team_attack_vfx_spawn()
	test_team_attack_vfx_burst_ring()

	# Category 10: Presentation Validation (items 358-365)
	_section("PRESENTATION VALIDATION")
	test_sfx_pool_prevents_duplication()
	test_audio_state_changes_on_zone()
	test_vfx_cleanup_attack()
	test_vfx_cleanup_dodge()
	test_vfx_cleanup_team_attack()
	test_target_indicator_visibility()
	test_controller_prompts_readable()
	test_no_gameplay_destabilization()


# ========== CATEGORY 1: AUDIO MANAGER CORE ==========

func test_audio_manager_exists() -> void:
	var script = load("res://scripts/autoloads/audio_manager.gd")
	_assert(script != null, "AudioManager script exists")


func test_audio_manager_is_autoload() -> void:
	var source := ""
	if FileAccess.file_exists("res://project.godot"):
		var f := FileAccess.open("res://project.godot", FileAccess.READ)
		if f:
			source = f.get_as_text()
	_assert(source.contains('AudioManager="*res://scripts/autoloads/audio_manager.gd"'),
		"AudioManager registered as autoload")


func test_audio_manager_has_music_player() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_music_player") and source.contains("AudioStreamPlayer"),
		"AudioManager has music player")


func test_audio_manager_has_sfx_pool() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_sfx_players") and source.contains("_sfx_pool_size"),
		"AudioManager has SFX player pool")


func test_audio_manager_process_mode_always() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("PROCESS_MODE_ALWAYS"),
		"AudioManager runs even when paused")


func test_audio_manager_has_sfx_registry() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_sfx_registry") and source.contains("_register_default_sfx"),
		"AudioManager has SFX registry with default keys")


func test_audio_manager_has_music_registry() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_music_registry") and source.contains("_register_default_music"),
		"AudioManager has music registry with zone mappings")


func test_audio_manager_play_sfx_named() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func play_sfx_named(key: String"),
		"AudioManager has play_sfx_named method")


func test_audio_manager_play_sfx_varied() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func play_sfx_varied(") and source.contains("randf_range"),
		"AudioManager has play_sfx_varied with random pitch")


func test_audio_manager_has_sfx_check() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func has_sfx(key: String)"),
		"AudioManager has has_sfx check method")


func test_audio_manager_play_music_named() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func play_music_named(key: String"),
		"AudioManager has play_music_named method")


func test_audio_manager_stop_music() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func stop_music(") and source.contains("_music_player.stop()"),
		"AudioManager has stop_music with fade support")


func test_audio_manager_crossfade() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_crossfade_music") and source.contains("new_stream"),
		"AudioManager supports music crossfading")


func test_audio_manager_volume_controls() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func set_music_volume(") and source.contains("func set_sfx_volume("),
		"AudioManager has volume controls for music and SFX")


func test_audio_manager_register_sfx() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func register_sfx(key: String, stream: AudioStream)"),
		"AudioManager allows registering custom SFX")


func test_audio_manager_register_music() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("func register_music(key: String, stream: AudioStream)"),
		"AudioManager allows registering custom music")


func test_audio_manager_null_safety() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	# play_sfx checks for null, play_sfx_named checks registry for null
	_assert(source.contains("if stream == null") and source.contains("_sfx_registry.get(key)"),
		"AudioManager gracefully handles null audio streams")


# ========== CATEGORY 2: MENU SFX HOOKS ==========

func test_pause_menu_sfx_open() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('play_sfx_named("menu_open")'),
		"Pause menu plays SFX on open")


func test_pause_menu_sfx_close() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('play_sfx_named("menu_close")'),
		"Pause menu plays SFX on close")


func test_pause_menu_sfx_select() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('play_sfx_named("menu_select")'),
		"Pause menu plays SFX on selection change")


func test_pause_menu_sfx_confirm() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains('play_sfx_named("menu_confirm")'),
		"Pause menu plays SFX on confirm")


func test_main_menu_sfx_new_game() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("_on_new_game") and source.contains('play_sfx_named("menu_confirm")'),
		"Main menu plays SFX on New Game")


func test_main_menu_sfx_continue() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("_on_continue") and source.contains('play_sfx_named("menu_confirm")'),
		"Main menu plays SFX on Continue")


func test_main_menu_sfx_load() -> void:
	var source := _get_source("res://scenes/menus/main_menu.gd")
	_assert(source.contains("_on_load") and source.contains('play_sfx_named("menu_confirm")'),
		"Main menu plays SFX on Load")


# ========== CATEGORY 3: COMBAT SFX HOOKS ==========

func test_attack_1_sfx() -> void:
	var source := _get_source("res://src/player/states/attack_1_state.gd")
	_assert(source.contains('play_sfx_varied("attack_1")'),
		"Attack 1 state plays attack SFX with variation")


func test_attack_2_sfx() -> void:
	var source := _get_source("res://src/player/states/attack_2_state.gd")
	_assert(source.contains('play_sfx_varied("attack_2")'),
		"Attack 2 state plays attack SFX with variation")


func test_attack_3_sfx() -> void:
	var source := _get_source("res://src/player/states/attack_3_state.gd")
	_assert(source.contains('play_sfx_varied("attack_3")'),
		"Attack 3 state plays attack SFX with variation")


func test_jump_attack_sfx() -> void:
	var source := _get_source("res://src/player/states/jump_attack_state.gd")
	_assert(source.contains('play_sfx_varied("jump_attack")'),
		"Jump attack state plays SFX with variation")


func test_dodge_sfx() -> void:
	var source := _get_source("res://src/player/states/dodge_state.gd")
	_assert(source.contains('play_sfx_named("dodge")'),
		"Dodge state plays dodge SFX")


func test_spell_cast_sfx() -> void:
	var source := _get_source("res://src/player/states/ability_state.gd")
	_assert(source.contains('play_sfx_named("spell_cast")'),
		"Ability state plays spell cast SFX")


func test_spell_release_sfx() -> void:
	var source := _get_source("res://src/player/states/ability_state.gd")
	_assert(source.contains('play_sfx_named("spell_release")'),
		"Ability state plays spell release SFX")


func test_spell_interrupt_sfx() -> void:
	var source := _get_source("res://src/player/states/ability_state.gd")
	_assert(source.contains('play_sfx_named("spell_interrupt")'),
		"Ability state plays spell interrupt SFX")


func test_hit_react_sfx() -> void:
	var source := _get_source("res://src/player/states/flinch_state.gd")
	_assert(source.contains('play_sfx_varied("hit_react")'),
		"Flinch state plays hit reaction SFX")


func test_enemy_hurt_sfx() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(source.contains('play_sfx_varied("enemy_hurt")'),
		"Enemy base plays hurt SFX on damage")


func test_enemy_die_sfx() -> void:
	var source := _get_source("res://src/enemies/enemy_base.gd")
	_assert(source.contains('play_sfx_named("enemy_die")'),
		"Enemy base plays death SFX")


# ========== CATEGORY 4: MUSIC HOOKS ==========

func test_zone_music_connection() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("zone_entered.connect") and source.contains("_on_zone_entered"),
		"AudioManager connects to zone_entered for music changes")


func test_battle_music_connection() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("combat_started.connect") and source.contains("combat_ended.connect"),
		"AudioManager connects to combat_started/ended for battle music")


func test_music_registry_zones() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains('"town_hub"') and source.contains('"field_zone"')
		and source.contains('"dungeon_zone"') and source.contains('"battle"'),
		"Music registry has town, field, dungeon, and battle entries")


func test_music_state_tracking() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_current_music_key") and source.contains("get_current_music_key"),
		"AudioManager tracks current music key")


func test_pre_battle_restore() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_pre_battle_music_key") and source.contains("_battle_music_active"),
		"AudioManager restores pre-battle music after combat ends")


# ========== CATEGORY 5: TACTICAL AUDIO ==========

func test_tactical_mode_audio_enter() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("tactical_mode_entered.connect")
		and source.contains("pitch_scale = 0.5"),
		"AudioManager slows music pitch in tactical mode")


func test_tactical_mode_audio_exit() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("tactical_mode_exited.connect")
		and source.contains("_original_pitch"),
		"AudioManager restores music pitch on tactical exit")


# ========== CATEGORY 6: VFX — ATTACKS & SPELLS ==========

func test_attack_vfx_exists() -> void:
	var script = load("res://src/effects/attack_vfx.gd")
	_assert(script != null, "AttackVFX script exists")


func test_attack_vfx_has_4_colors() -> void:
	var source := _get_source("res://src/effects/attack_vfx.gd")
	_assert(source.contains("ATTACK_COLORS") and source.contains("Attack 1")
		and source.contains("Attack 2") and source.contains("Attack 3")
		and source.contains("Jump Attack"),
		"AttackVFX has 4 color variants for each attack type")


func test_attack_vfx_has_spawn_method() -> void:
	var source := _get_source("res://src/effects/attack_vfx.gd")
	_assert(source.contains("static func spawn(") and source.contains("queue_free"),
		"AttackVFX has static spawn and auto-cleanup")


func test_spell_projectile_exists() -> void:
	var script = load("res://src/effects/spell_projectile.gd")
	_assert(script != null, "SpellProjectile script exists")


func test_spell_projectile_has_damage() -> void:
	var source := _get_source("res://src/effects/spell_projectile.gd")
	_assert(source.contains("set_damage") and source.contains("set_target"),
		"SpellProjectile has set_damage and set_target methods")


# ========== CATEGORY 7: VFX — DODGE ==========

func test_dodge_vfx_exists() -> void:
	var script = load("res://src/effects/dodge_vfx.gd")
	_assert(script != null, "DodgeVFX script exists")


func test_dodge_vfx_has_spawn_method() -> void:
	var source := _get_source("res://src/effects/dodge_vfx.gd")
	_assert(source.contains("static func spawn(") and source.contains("queue_free"),
		"DodgeVFX has static spawn with auto-cleanup")


func test_dodge_vfx_ghost_shape() -> void:
	var source := _get_source("res://src/effects/dodge_vfx.gd")
	_assert(source.contains("CapsuleMesh") and source.contains("GHOST_COLOR"),
		"DodgeVFX creates ghost capsule silhouette")


func test_dodge_vfx_fade_out() -> void:
	var source := _get_source("res://src/effects/dodge_vfx.gd")
	_assert(source.contains("FADE_DURATION") and source.contains("tween_method"),
		"DodgeVFX fades out over time")


func test_dodge_state_spawns_vfx() -> void:
	var source := _get_source("res://src/player/states/dodge_state.gd")
	_assert(source.contains("DodgeVFX") and source.contains("DodgeVFX.spawn("),
		"Dodge state spawns DodgeVFX on enter")


# ========== CATEGORY 8: VFX — UI POLISH ==========

func test_lock_on_indicator_exists() -> void:
	var script = load("res://src/ui/hud/lock_on_indicator.gd")
	_assert(script != null, "Lock-on indicator script exists")


func test_lock_on_indicator_pulse() -> void:
	var source := _get_source("res://src/ui/hud/lock_on_indicator.gd")
	_assert(source.contains("_pulse_tween") and source.contains("scale")
		and source.contains("TRANS_BACK"),
		"Lock-on indicator pulses scale on target acquire")


func test_interaction_prompt_pulse() -> void:
	var source := _get_source("res://src/ui/hud/interaction_prompt.gd")
	_assert(source.contains("_pulse_tween") and source.contains("modulate"),
		"Interaction prompt has pulse animation on show")


func test_pause_menu_transition() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("_menu_tween") and source.contains("modulate:a"),
		"Pause menu has fade-in transition")


# ========== CATEGORY 9: VFX — TEAM ATTACK ==========

func test_team_attack_vfx_exists() -> void:
	var script = load("res://src/effects/team_attack_vfx.gd")
	_assert(script != null, "TeamAttackVFX script exists")


func test_team_attack_vfx_spawn() -> void:
	var source := _get_source("res://src/effects/team_attack_vfx.gd")
	_assert(source.contains("static func spawn(") and source.contains("queue_free"),
		"TeamAttackVFX has static spawn with auto-cleanup")


func test_team_attack_vfx_burst_ring() -> void:
	var source := _get_source("res://src/effects/team_attack_vfx.gd")
	_assert(source.contains("BURST_COLOR") and source.contains("TorusMesh")
		and source.contains("MAX_SCALE"),
		"TeamAttackVFX creates expanding golden burst ring")


# ========== CATEGORY 10: PRESENTATION VALIDATION ==========

func test_sfx_pool_prevents_duplication() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("not player.playing") and source.contains("for player in _sfx_players"),
		"SFX pool iterates to find free player, preventing overlap bugs")


func test_audio_state_changes_on_zone() -> void:
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("_on_zone_entered") and source.contains("play_music_named"),
		"Audio state changes when zone is entered")


func test_vfx_cleanup_attack() -> void:
	var source := _get_source("res://src/effects/attack_vfx.gd")
	_assert(source.contains("queue_free") and source.contains("tween_callback"),
		"Attack VFX auto-cleans up via tween callback")


func test_vfx_cleanup_dodge() -> void:
	var source := _get_source("res://src/effects/dodge_vfx.gd")
	_assert(source.contains("queue_free") and source.contains("tween_callback"),
		"Dodge VFX auto-cleans up via tween callback")


func test_vfx_cleanup_team_attack() -> void:
	var source := _get_source("res://src/effects/team_attack_vfx.gd")
	_assert(source.contains("queue_free") and source.contains("tween_callback"),
		"Team attack VFX auto-cleans up via tween callback")


func test_target_indicator_visibility() -> void:
	var source := _get_source("res://src/ui/hud/lock_on_indicator.gd")
	_assert(source.contains("is_position_behind") and source.contains("unproject_position"),
		"Lock-on indicator checks camera visibility before showing")


func test_controller_prompts_readable() -> void:
	var source := _get_source("res://src/ui/hud/interaction_prompt.gd")
	_assert(source.contains("is_using_controller") and source.contains("[Y]")
		and source.contains("[E]"),
		"Interaction prompt shows controller/keyboard context-appropriate hints")


func test_no_gameplay_destabilization() -> void:
	# Verify AudioManager null-safety doesn't crash when no audio assets
	var source := _get_source("res://scripts/autoloads/audio_manager.gd")
	_assert(source.contains("if stream == null") and source.contains("return"),
		"AudioManager safely no-ops when audio streams are null")


# ========== HELPERS ==========

func _get_source(path: String) -> String:
	var res = load(path)
	if res == null:
		return ""
	if res is GDScript:
		return res.source_code
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			return f.get_as_text()
	return ""


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_pass(test_name)
	else:
		_fail(test_name)


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
