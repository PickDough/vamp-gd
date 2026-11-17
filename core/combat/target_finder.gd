trait_name TargetFinder
extends Node

## Answers spatial questions about the things attacks can hurt, for targets that aren't physics bodies. Every
## target it returns is a Node3D that uses Damageable. The adopter overrides both queries: find_nearest() returns
## up to `count` targets within `radius` of `origin`, nearest first; find_in_box() returns the targets whose hit
## sphere touches the box of `size` centred on `box`.


func find_nearest(_origin: Vector3, _radius: float, _count: int) -> Array[Node3D]:
	push_error("%s doesn't implement TargetFinder.find_nearest" % name)
	return []


func find_in_box(_box: Transform3D, _size: Vector3) -> Array[Node3D]:
	push_error("%s doesn't implement TargetFinder.find_in_box" % name)
	return []
