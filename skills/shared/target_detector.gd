class_name TargetDetector
extends Area3D

## Finds the nearest damageable bodies within a radius around it.

@onready var _shape: CollisionShape3D = $CollisionShape3D


func set_radius(radius: float) -> void:
	(_shape.shape as SphereShape3D).radius = radius


func nearest(count: int) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for body in get_overlapping_bodies():
		if body is Damageable:
			targets.append(body)

	targets.sort_custom(_is_nearer)
	return targets.slice(0, count)


func _is_nearer(a: Node3D, b: Node3D) -> bool:
	return _distance_squared_to(a) < _distance_squared_to(b)


func _distance_squared_to(node: Node3D) -> float:
	return global_position.distance_squared_to(node.global_position)
