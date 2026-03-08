## Ice spell projectile. Blue-white appearance, slows target on hit.
extends Node3D

@export var speed: float = 18.0
@export var lifetime: float = 3.0
@export var homing_strength: float = 3.0

var _damage: float = 30.0
var _target: Node3D = null
var _timer: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _hit: bool = false


func _ready() -> void:
	_direction = -global_basis.z.normalized()

	# Create hitbox area
	var area := Area3D.new()
	area.collision_layer = 8   # Player attack layer
	area.collision_mask = 64   # Enemy hurtbox layer
	area.set_meta("damage", _damage)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.area_entered.connect(_on_hit)

	# Create visual mesh — icy blue crystal shard
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.6
	mesh_inst.mesh = sphere_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.7, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	add_child(mesh_inst)


func _physics_process(delta: float) -> void:
	if _hit:
		return

	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	# Homing toward target
	if _target and is_instance_valid(_target):
		var to_target := (_target.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
		_direction = _direction.lerp(to_target, homing_strength * delta).normalized()

	global_position += _direction * speed * delta


func set_damage(amount: float) -> void:
	_damage = amount
	for child in get_children():
		if child is Area3D:
			child.set_meta("damage", _damage)


func set_target(target: Node3D) -> void:
	_target = target


func _on_hit(_area: Area3D) -> void:
	if _hit:
		return
	_hit = true

	if DebugFlags.DEBUG_COMBAT:
		print("IceProjectile: Hit for %.0f damage" % _damage)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tween.tween_callback(queue_free)
