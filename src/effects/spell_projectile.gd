## Generic spell projectile. Moves forward, damages on contact, auto-destroys.
extends Node3D

@export var speed: float = 20.0
@export var lifetime: float = 3.0
@export var homing_strength: float = 2.0

var _damage: float = 20.0
var _target: Node3D = null
var _timer: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _hit: bool = false


func _ready() -> void:
	_direction = -global_basis.z.normalized()

	# Create hitbox area
	var area := Area3D.new()
	area.collision_layer = 8   # Player attack layer (layer 4)
	area.collision_mask = 64   # Enemy hurtbox layer (layer 7)
	area.set_meta("damage", _damage)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.area_entered.connect(_on_hit)

	# Create visual mesh
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.25
	sphere_mesh.height = 0.5
	mesh_inst.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 3.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _physics_process(delta: float) -> void:
	if _hit:
		return

	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	# Homing toward target if available
	if _target and is_instance_valid(_target):
		var to_target := (_target.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
		_direction = _direction.lerp(to_target, homing_strength * delta).normalized()

	global_position += _direction * speed * delta


func set_damage(amount: float) -> void:
	_damage = amount
	# Update area meta if already created
	for child in get_children():
		if child is Area3D:
			child.set_meta("damage", _damage)


func set_target(target: Node3D) -> void:
	_target = target


func _on_hit(area: Area3D) -> void:
	if _hit:
		return
	_hit = true

	# Let the enemy hurtbox handle the damage via its own area_entered signal
	# The projectile's Area3D has "damage" meta which the enemy reads

	if DebugFlags.DEBUG_COMBAT:
		print("SpellProjectile: Hit %s for %.0f damage" % [area.get_parent().name, _damage])

	# Destroy after brief delay for visual feedback
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tween.tween_callback(queue_free)
