struct_name HitInfo:
## One hit from an attack: how much damage it deals, whether it was critical, where it landed and which way it pushes.
	var amount: float
	var is_critical: bool = false
	var hit_point: Vector3
	var hit_direction: Vector3
