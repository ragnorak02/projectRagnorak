## Smoke tests for Project Ragnorak.
extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array[String] = []


func _ready() -> void:
	print("=== Project Ragnorak Smoke Tests ===")
	test_autoloads_exist()
	test_player_script_loads()
	test_enemy_script_loads()
	test_state_machine_loads()
	test_camera_rig_loads()
	test_resource_definitions()
	test_locomotion_states()
	_print_results()


func test_autoloads_exist() -> void:
	_assert("Events autoload", Events != null)
	_assert("GameManager autoload", GameManager != null)
	_assert("InputManager autoload", InputManager != null)
	_assert("AudioManager autoload", AudioManager != null)
	_assert("SaveManager autoload", SaveManager != null)
	_assert("DebugFlags autoload", DebugFlags != null)


func test_player_script_loads() -> void:
	var script = load("res://src/player/player.gd")
	_assert("Player script loads", script != null)


func test_enemy_script_loads() -> void:
	var script = load("res://src/enemies/enemy_base.gd")
	_assert("EnemyBase script loads", script != null)


func test_state_machine_loads() -> void:
	var sm_script = load("res://src/player/states/state_machine.gd")
	var state_script = load("res://src/player/states/state.gd")
	_assert("StateMachine script loads", sm_script != null)
	_assert("State base script loads", state_script != null)


func test_camera_rig_loads() -> void:
	var script = load("res://src/camera/camera_rig.gd")
	_assert("CameraRig script loads", script != null)


func test_resource_definitions() -> void:
	var ability = load("res://resources/abilities/ability_data.gd")
	var item = load("res://resources/items/item_data.gd")
	var equip = load("res://resources/equipment/equipment_data.gd")
	_assert("AbilityData resource loads", ability != null)
	_assert("ItemData resource loads", item != null)
	_assert("EquipmentData resource loads", equip != null)


func test_locomotion_states() -> void:
	var ledge_grab = load("res://src/player/states/ledge_grab_state.gd")
	var climb = load("res://src/player/states/climb_state.gd")
	var idle = load("res://src/player/states/idle_state.gd")
	var run = load("res://src/player/states/run_state.gd")
	var jump = load("res://src/player/states/jump_state.gd")
	var fall = load("res://src/player/states/fall_state.gd")
	var land = load("res://src/player/states/land_state.gd")
	_assert("LedgeGrabState loads", ledge_grab != null)
	_assert("ClimbState loads", climb != null)
	_assert("IdleState loads", idle != null)
	_assert("RunState loads", run != null)
	_assert("JumpState loads", jump != null)
	_assert("FallState loads", fall != null)
	_assert("LandState loads", land != null)


func _assert(test_name: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		_results.append("PASS: %s" % test_name)
	else:
		_fail_count += 1
		_results.append("FAIL: %s" % test_name)


func _print_results() -> void:
	print("")
	for r in _results:
		print(r)
	print("")
	print("Results: %d passed, %d failed, %d total" % [_pass_count, _fail_count, _pass_count + _fail_count])
	print("=== Tests Complete ===")

	if _fail_count > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
