class_name DeathBody
extends RigidBody3D

## The ragdoll left behind by a dead enemy: an instance of its model in its body color, a shade darker, with matte
## cartoon shading and its collision shape. Over its timeout it burns away (ragdoll_dissolve.gdshader: a glowing
## ember front eats through it, starting after DISSOLVE_DELAY) and then frees itself.

const RAGDOLL_COLLISION_LAYER := 1 << 4
const RAGDOLL_COLLISION_MASK := 1
const RAGDOLL_ANGULAR_DAMP := 5.0
const DISSOLVE_SHADER_PATH := "res://actors/enemies/death/ragdoll_dissolve.gdshader"
const DEAD_DARKENING := 0.25
const DISSOLVE_DELAY := 0.3

var _material := ShaderMaterial.new()


func setup(body: Enemy, timeout: float) -> void:
	global_position = body.global_position
	global_rotation = body.global_rotation
	angular_damp = RAGDOLL_ANGULAR_DAMP
	mass = body.mass
	collision_layer = RAGDOLL_COLLISION_LAYER
	collision_mask = RAGDOLL_COLLISION_MASK
	_add_visuals(body)
	_dissolve_over(timeout)


func _add_visuals(body: Enemy) -> void:
	var model := body.model_scene.instantiate() as EnemyModel
	model.transform = body.model_transform
	add_child(model)
	var bounds := model.mesh.mesh.get_aabb()
	_material.shader = load(DISSOLVE_SHADER_PATH) as Shader
	_material.set_shader_parameter(&"albedo", body.body_color.darkened(DEAD_DARKENING))
	_material.set_shader_parameter(&"bounds_position", bounds.position)
	_material.set_shader_parameter(&"bounds_size", bounds.size)
	_material.set_shader_parameter(&"dissolve", 0.0)
	model.mesh.material_override = _material
	var collision := CollisionShape3D.new()
	collision.shape = body.ragdoll_shape
	collision.scale = Vector3.ONE * body.ragdoll_shape_scale
	add_child(collision)


func _dissolve_over(timeout: float) -> void:
	var tween := create_tween()
	tween.tween_interval(minf(DISSOLVE_DELAY, timeout))
	tween.tween_property(_material, ^"shader_parameter/dissolve", 1.0, maxf(timeout - DISSOLVE_DELAY, 0.0))
	tween.tween_callback(queue_free)
