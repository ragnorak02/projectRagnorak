## Phase 10 tests: Quests & NPC Interaction (items 231-255).
extends Node

var _passed: int = 0
var _failed: int = 0
var _total: int = 0


func _ready() -> void:
	print("=== Phase 10: Quests & NPC Interaction Tests ===")
	print("")
	_run_tests()
	print("\n=== Phase 10 Results: %d passed, %d failed, %d total ===" % [_passed, _failed, _total])
	print("")

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _run_tests() -> void:
	# Category 1: Interaction System (items 231-235)
	_section("INTERACTION SYSTEM")
	test_interactable_script_exists()
	test_interactable_has_interact_method()
	test_interactable_has_priority()
	test_interactable_has_active_state()
	test_interactable_types_defined()
	test_interactable_sets_collision_layer()
	test_interactable_adds_to_group()
	test_npc_interactable_exists()
	test_npc_interactable_extends_base()
	test_npc_has_dialogue_pages()
	test_npc_has_npc_name()
	test_chest_interactable_exists()
	test_chest_interactable_extends_base()
	test_chest_has_contents()
	test_chest_has_opened_flag()
	test_lever_interactable_exists()
	test_lever_interactable_extends_base()
	test_lever_has_toggle()
	test_lever_has_signal()
	test_player_has_interaction_detection()
	test_player_has_interaction_anchor()
	test_player_handles_interact_input()
	test_interaction_priority_logic()

	# Category 2: Dialogue (items 236-240)
	_section("DIALOGUE SYSTEM")
	test_dialogue_ui_exists()
	test_dialogue_has_start_method()
	test_dialogue_has_speaker_label()
	test_dialogue_has_text_label()
	test_dialogue_supports_controller_advance()
	test_dialogue_supports_keyboard_advance()
	test_dialogue_has_active_state()
	test_dialogue_in_group()
	test_dialogue_allow_movement_param()

	# Category 3: Quest Core (items 241-248)
	_section("QUEST CORE")
	test_quest_data_exists()
	test_quest_data_has_id()
	test_quest_data_has_title()
	test_quest_data_has_description()
	test_quest_data_has_quest_type()
	test_quest_data_has_objectives()
	test_quest_data_has_prerequisites()
	test_quest_data_has_rewards()
	test_quest_types_defined()
	test_quest_objective_exists()
	test_quest_objective_has_fields()
	test_quest_system_exists()
	test_quest_system_accept()
	test_quest_system_advance_objective()
	test_quest_system_complete()
	test_quest_system_active_tracking()
	test_quest_system_completed_tracking()
	test_quest_system_tracked_quest()
	test_quest_system_prerequisite_check()
	test_quest_system_no_duplicate_accept()
	test_quest_system_auto_complete()
	test_test_quest_resource_loads()
	test_quest_system_save_data()
	test_quest_system_load_data()

	# Category 4: Quest Log UI (items 249-255)
	_section("QUEST LOG UI")
	test_quest_log_exists()
	test_quest_log_has_open_close()
	test_quest_log_has_selection()
	test_quest_log_has_detail_panel()
	test_quest_log_controller_nav()
	test_quest_log_keyboard_nav()
	test_quest_log_track_quest()

	# Category 5: Integration
	_section("INTEGRATION")
	test_player_has_quest_system()
	test_player_save_includes_quests()
	test_events_has_quest_signals()
	test_events_has_dialogue_signals()
	test_events_has_interaction_signals()
	test_pause_menu_has_quest_log()
	test_quest_tracker_connects_signals()
	test_interaction_prompt_custom_text()
	test_test_arena_has_dialogue_ui()


# ========== CATEGORY 1: INTERACTION SYSTEM ==========

func test_interactable_script_exists() -> void:
	var script = load("res://src/interaction/interactable.gd")
	_assert(script != null, "Interactable base script exists")


func test_interactable_has_interact_method() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains("func interact("), "Interactable has interact() method")


func test_interactable_has_priority() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains("interact_priority"), "Interactable has interact_priority property")


func test_interactable_has_active_state() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains("_is_active") and source.contains("func is_active") and source.contains("func set_active"),
		"Interactable has active state with getter/setter")


func test_interactable_types_defined() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains("GENERIC") and source.contains("NPC")
		and source.contains("CHEST") and source.contains("LEVER"),
		"InteractableType enum has GENERIC, NPC, CHEST, LEVER")


func test_interactable_sets_collision_layer() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains("collision_layer = 256"),
		"Interactable sets collision_layer to 256 (Layer 9)")


func test_interactable_adds_to_group() -> void:
	var source := _get_source("res://src/interaction/interactable.gd")
	_assert(source.contains('add_to_group(&"interactable")'),
		"Interactable adds to 'interactable' group")


func test_npc_interactable_exists() -> void:
	var script = load("res://src/interaction/npc_interactable.gd")
	_assert(script != null, "NPC interactable script exists")


func test_npc_interactable_extends_base() -> void:
	var source := _get_source("res://src/interaction/npc_interactable.gd")
	_assert(source.contains('extends "res://src/interaction/interactable.gd"'),
		"NPC interactable extends base interactable")


func test_npc_has_dialogue_pages() -> void:
	var source := _get_source("res://src/interaction/npc_interactable.gd")
	_assert(source.contains("dialogue_pages"),
		"NPC interactable has dialogue_pages")


func test_npc_has_npc_name() -> void:
	var source := _get_source("res://src/interaction/npc_interactable.gd")
	_assert(source.contains("npc_name"),
		"NPC interactable has npc_name property")


func test_chest_interactable_exists() -> void:
	var script = load("res://src/interaction/chest_interactable.gd")
	_assert(script != null, "Chest interactable script exists")


func test_chest_interactable_extends_base() -> void:
	var source := _get_source("res://src/interaction/chest_interactable.gd")
	_assert(source.contains('extends "res://src/interaction/interactable.gd"'),
		"Chest interactable extends base interactable")


func test_chest_has_contents() -> void:
	var source := _get_source("res://src/interaction/chest_interactable.gd")
	_assert(source.contains("contents"),
		"Chest interactable has contents array")


func test_chest_has_opened_flag() -> void:
	var source := _get_source("res://src/interaction/chest_interactable.gd")
	_assert(source.contains("is_opened"),
		"Chest interactable has is_opened flag")


func test_lever_interactable_exists() -> void:
	var script = load("res://src/interaction/lever_interactable.gd")
	_assert(script != null, "Lever interactable script exists")


func test_lever_interactable_extends_base() -> void:
	var source := _get_source("res://src/interaction/lever_interactable.gd")
	_assert(source.contains('extends "res://src/interaction/interactable.gd"'),
		"Lever interactable extends base interactable")


func test_lever_has_toggle() -> void:
	var source := _get_source("res://src/interaction/lever_interactable.gd")
	_assert(source.contains("is_on") and source.contains("not is_on"),
		"Lever interactable toggles is_on state")


func test_lever_has_signal() -> void:
	var source := _get_source("res://src/interaction/lever_interactable.gd")
	_assert(source.contains("signal lever_toggled"),
		"Lever interactable has lever_toggled signal")


func test_player_has_interaction_detection() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("_nearby_interactables") and source.contains("_current_interactable"),
		"Player tracks nearby interactables for detection")


func test_player_has_interaction_anchor() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("interaction_anchor") and source.contains("InteractionAnchor"),
		"Player has InteractionAnchor Area3D reference")


func test_player_handles_interact_input() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('is_action_pressed(&"interact")') and source.contains(".interact(self)"),
		"Player handles interact input and calls interact on target")


func test_interaction_priority_logic() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("interact_priority") and source.contains("distance_squared_to"),
		"Interaction detection uses interact_priority then distance for selection")


# ========== CATEGORY 2: DIALOGUE SYSTEM ==========

func test_dialogue_ui_exists() -> void:
	var script = load("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(script != null, "Dialogue UI script exists")


func test_dialogue_has_start_method() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains("func start_dialogue("),
		"DialogueUI has start_dialogue method")


func test_dialogue_has_speaker_label() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains("_speaker_label") and source.contains("speaker"),
		"DialogueUI has speaker label")


func test_dialogue_has_text_label() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains("_text_label") and source.contains('"text"'),
		"DialogueUI has text label")


func test_dialogue_supports_controller_advance() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains('"jump"') or source.contains("ui_accept"),
		"DialogueUI supports controller advance (A button / jump)")


func test_dialogue_supports_keyboard_advance() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains('"interact"') and source.contains('"ui_accept"'),
		"DialogueUI supports keyboard advance (E / Enter)")


func test_dialogue_has_active_state() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains("_is_active") and source.contains("func is_dialogue_active"),
		"DialogueUI tracks active dialogue state")


func test_dialogue_in_group() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains('add_to_group(&"dialogue_ui")'),
		"DialogueUI adds to dialogue_ui group for discovery")


func test_dialogue_allow_movement_param() -> void:
	var source := _get_source("res://src/ui/dialogue/dialogue_ui.gd")
	_assert(source.contains("allow_movement"),
		"DialogueUI supports allow_movement parameter")


# ========== CATEGORY 3: QUEST CORE ==========

func test_quest_data_exists() -> void:
	var script = load("res://resources/quests/quest_data.gd")
	_assert(script != null, "QuestData script exists")


func test_quest_data_has_id() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("quest_id"), "QuestData has quest_id")


func test_quest_data_has_title() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("title"), "QuestData has title")


func test_quest_data_has_description() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("description"), "QuestData has description")


func test_quest_data_has_quest_type() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("quest_type"), "QuestData has quest_type")


func test_quest_data_has_objectives() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("objectives"), "QuestData has objectives array")


func test_quest_data_has_prerequisites() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("prerequisite_quests"), "QuestData has prerequisite_quests")


func test_quest_data_has_rewards() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("rewards"), "QuestData has rewards dictionary")


func test_quest_types_defined() -> void:
	var source := _get_source("res://resources/quests/quest_data.gd")
	_assert(source.contains("STORY") and source.contains("SIDE") and source.contains("EXPLORATION"),
		"QuestData has Story, Side, Exploration quest types")


func test_quest_objective_exists() -> void:
	var script = load("res://resources/quests/quest_objective.gd")
	_assert(script != null, "QuestObjective script exists")


func test_quest_objective_has_fields() -> void:
	var source := _get_source("res://resources/quests/quest_objective.gd")
	_assert(source.contains("objective_id") and source.contains("description")
		and source.contains("target_id") and source.contains("target_count")
		and source.contains("marker_position"),
		"QuestObjective has id, description, target_id, target_count, marker_position")


func test_quest_system_exists() -> void:
	var script = load("res://src/quest/quest_system.gd")
	_assert(script != null, "QuestSystem script exists")


func test_quest_system_accept() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("accept_test", "Test Quest", 0)
	var result = qs.accept_quest(quest)
	_assert(result and qs.is_quest_active(&"accept_test"),
		"QuestSystem can accept a quest")
	qs.free()


func test_quest_system_advance_objective() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("advance_test", "Advance", 0)
	qs.accept_quest(quest)
	qs.advance_objective(&"advance_test", &"obj_1", 1)
	var active = qs.get_active_quests()
	var progress: Array = active[0]["progress"]
	_assert(progress[0] == 1, "QuestSystem advances objective progress")
	qs.free()


func test_quest_system_complete() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("complete_test", "Complete", 0)
	qs.accept_quest(quest)
	qs.complete_quest(&"complete_test")
	_assert(qs.is_quest_completed(&"complete_test") and not qs.is_quest_active(&"complete_test"),
		"QuestSystem can complete a quest and move to completed")
	qs.free()


func test_quest_system_active_tracking() -> void:
	var qs = _create_quest_system()
	var q1 = _create_test_quest("active_1", "Quest One", 0)
	var q2 = _create_test_quest("active_2", "Quest Two", 1)
	qs.accept_quest(q1)
	qs.accept_quest(q2)
	var active = qs.get_active_quests()
	_assert(active.size() == 2, "get_active_quests returns all active quests")
	qs.free()


func test_quest_system_completed_tracking() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("comp_track", "Completed", 0)
	qs.accept_quest(quest)
	qs.complete_quest(&"comp_track")
	var completed = qs.get_completed_quests()
	_assert(completed.has(&"comp_track"), "get_completed_quests includes completed quest IDs")
	qs.free()


func test_quest_system_tracked_quest() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("tracked", "Tracked Quest", 0)
	qs.accept_quest(quest)
	qs.set_tracked_quest(&"tracked")
	var tracked = qs.get_tracked_quest()
	_assert(tracked.has("quest_id") and tracked["quest_id"] == &"tracked",
		"QuestSystem tracks a single quest for HUD display")
	qs.free()


func test_quest_system_prerequisite_check() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("prereq_locked", "Locked", 0)
	quest.prerequisite_quests.append(&"some_other_quest")
	var result = qs.accept_quest(quest)
	_assert(not result, "Cannot accept quest with unmet prerequisites")
	qs.free()


func test_quest_system_no_duplicate_accept() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("no_dup", "No Dup", 0)
	qs.accept_quest(quest)
	var result = qs.accept_quest(quest)
	_assert(not result and qs.get_quest_count() == 1,
		"Cannot accept the same quest twice")
	qs.free()


func test_quest_system_auto_complete() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("auto_comp", "Auto", 0, 1)
	qs.accept_quest(quest)
	qs.advance_objective(&"auto_comp", &"obj_1", 1)
	_assert(qs.is_quest_completed(&"auto_comp"),
		"Quest auto-completes when all objectives are done")
	qs.free()


func test_test_quest_resource_loads() -> void:
	var quest = load("res://resources/quests/test_fetch_quest.tres")
	_assert(quest != null and quest.get("quest_id") == &"fetch_herbs",
		"Test fetch quest resource loads with correct ID")


func test_quest_system_save_data() -> void:
	var qs = _create_quest_system()
	var quest = _create_test_quest("save_test", "Save Quest", 0)
	qs.accept_quest(quest)
	var data = qs.get_save_data()
	_assert(data is Dictionary and data.has("active") and data.has("completed") and data.has("tracked"),
		"QuestSystem save data has active, completed, and tracked keys")
	qs.free()


func test_quest_system_load_data() -> void:
	var source := _get_source("res://src/quest/quest_system.gd")
	_assert(source.contains("func load_save_data(") and source.contains("func get_save_data("),
		"QuestSystem has save/load methods")


# ========== CATEGORY 4: QUEST LOG UI ==========

func test_quest_log_exists() -> void:
	var script = load("res://src/ui/menus/quest_log.gd")
	_assert(script != null, "Quest Log UI script exists")


func test_quest_log_has_open_close() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains("func open_log(") and source.contains("func close_log("),
		"Quest Log has open/close methods")


func test_quest_log_has_selection() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains("_selected_index") and source.contains("_move_selection"),
		"Quest Log has selection navigation")


func test_quest_log_has_detail_panel() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains("_detail_title") and source.contains("_detail_desc")
		and source.contains("_detail_objectives"),
		"Quest Log has detail panel with title, description, objectives")


func test_quest_log_controller_nav() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains('"move_up"') and source.contains('"move_down"')
		and source.contains('"attack"'),
		"Quest Log supports controller navigation (D-pad + A)")


func test_quest_log_keyboard_nav() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains('"ui_up"') and source.contains('"ui_down"')
		and source.contains('"ui_accept"'),
		"Quest Log supports keyboard navigation (arrow keys + Enter)")


func test_quest_log_track_quest() -> void:
	var source := _get_source("res://src/ui/menus/quest_log.gd")
	_assert(source.contains("_track_selected") and source.contains("set_tracked_quest"),
		"Quest Log can set tracked quest")


# ========== CATEGORY 5: INTEGRATION ==========

func test_player_has_quest_system() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains("quest_system") and source.contains("QuestSystem"),
		"Player has quest_system reference")


func test_player_save_includes_quests() -> void:
	var source := _get_source("res://src/player/player.gd")
	_assert(source.contains('"quests"') and source.contains("quest_system.get_save_data"),
		"Player save data includes quests")


func test_events_has_quest_signals() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal quest_accepted") and source.contains("signal quest_completed")
		and source.contains("signal quest_objective_updated"),
		"Events bus has quest signals")


func test_events_has_dialogue_signals() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal dialogue_started") and source.contains("signal dialogue_ended"),
		"Events bus has dialogue signals")


func test_events_has_interaction_signals() -> void:
	var source := _get_source("res://scripts/autoloads/events.gd")
	_assert(source.contains("signal interaction_available") and source.contains("signal interaction_cleared"),
		"Events bus has interaction signals")


func test_pause_menu_has_quest_log() -> void:
	var source := _get_source("res://src/ui/menus/pause_menu.gd")
	_assert(source.contains("QUEST_LOG") and source.contains('"available": true')
		and source.contains("_open_quest_log"),
		"Pause menu has Quest Log item enabled with handler")


func test_quest_tracker_connects_signals() -> void:
	var source := _get_source("res://src/ui/hud/quest_tracker.gd")
	_assert(source.contains("quest_objective_updated") and source.contains("quest_completed"),
		"Quest tracker connects to quest signals")


func test_interaction_prompt_custom_text() -> void:
	var source := _get_source("res://src/ui/hud/interaction_prompt.gd")
	_assert(source.contains("get_prompt_text") and source.contains("_custom_text"),
		"Interaction prompt supports custom text from interactable")


func test_test_arena_has_dialogue_ui() -> void:
	var source := _get_source("res://scenes/test/test_arena.gd")
	_assert(source.contains("DialogueUiScript") and source.contains("dialogue_ui"),
		"Test arena instantiates DialogueUI")


# ========== HELPERS ==========

func _create_quest_system() -> Node:
	var script = load("res://src/quest/quest_system.gd")
	var node = Node.new()
	node.set_script(script)
	add_child(node)
	return node


func _create_test_quest(id: String, title: String, quest_type: int, obj_target: int = 3) -> Resource:
	var quest_script = load("res://resources/quests/quest_data.gd")
	var obj_script = load("res://resources/quests/quest_objective.gd")

	var obj = Resource.new()
	obj.set_script(obj_script)
	obj.objective_id = &"obj_1"
	obj.description = "Test objective"
	obj.target_id = &"test_target"
	obj.target_count = obj_target

	var quest = Resource.new()
	quest.set_script(quest_script)
	quest.quest_id = StringName(id)
	quest.title = title
	quest.description = "A test quest"
	quest.quest_type = quest_type
	quest.objectives.append(obj)
	quest.prerequisite_quests = [] as Array[StringName]
	quest.rewards = {"gold": 10}

	return quest


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
