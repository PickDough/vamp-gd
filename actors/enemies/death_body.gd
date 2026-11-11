class_name DeathBody
extends RigidBody3D

## The ragdoll left behind by a dead enemy: a tinted copy of its model and collision that frees itself after a
## timeout.

const RG_COLLISION_LAYER := 2 ** 4
const RG_COLLISION_MASK := 1


func setup(body: Enemy, timeout: float) -> void:
	global_position = body.global_position
	global_rotation = body.global_rotation
	angular_damp = 5.0
	mass = body.mass
	collision_layer = RG_COLLISION_LAYER
	collision_mask = RG_COLLISION_MASK
	_add_visuals(body)
	_start_despawn_timer(timeout)


func _add_visuals(body: Enemy) -> void:
	var model := body.model.duplicate() as EnemyModel
	add_child(model)
	var material := model.mesh.get_active_material(0) as BaseMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color.from_rgba8(255, 0, 0, 180)
	add_child(body.rg_collision.duplicate())


func _start_despawn_timer(timeout: float) -> void:
	var timer := Timer.new()
	timer.wait_time = timeout
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
