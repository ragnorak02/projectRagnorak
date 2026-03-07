## Player hangs on a detected ledge. Jump to climb up, move down to drop.
extends State


func enter(_msg: Dictionary = {}) -> void:
	# Snap to hang position and kill velocity
	player.velocity = Vector3.ZERO
	player.global_position = player.get_ledge_snap_position()

	# Face into the wall
	var wall_normal: Vector3 = player.chest_ray.get_collision_normal()
	var face_dir: Vector3 = -wall_normal
	face_dir.y = 0.0
	if face_dir.length() > 0.01:
		player.basis = Basis.looking_at(face_dir)


func process_physics(_delta: float) -> StringName:
	return &""


func process_input(event: InputEvent) -> StringName:
	if event.is_action_pressed(&"jump"):
		return &"ClimbUp"

	# Drop down
	var input := InputManager.get_movement_vector()
	if input.y > 0.5:
		return &"Fall"

	return &""
