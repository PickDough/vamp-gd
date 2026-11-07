class_name NavPoints

## Picks points on a baked navigation region: spots away from its edges, or spots within a distance band around
## a center. A point counts as away from the edges when the region continues `inset` meters out in every sampled
## direction, within ON_MESH_SLACK.

const INSET_SAMPLES := 8
const ON_MESH_SLACK := 0.35


static func random_inset(region: RID, layers: int, inset: float, attempts: int) -> Vector3:
	var fallback := NavigationServer3D.region_get_random_point(region, layers, true)
	for i in attempts:
		var point := NavigationServer3D.region_get_random_point(region, layers, true)
		if is_inset(region, point, inset):
			return point

	return fallback


static func is_inset(region: RID, point: Vector3, inset: float) -> bool:
	for i in INSET_SAMPLES:
		var sample := point + _flat_direction(i * TAU / INSET_SAMPLES) * inset
		var closest := NavigationServer3D.region_get_closest_point(region, sample)
		if closest.distance_squared_to(sample) > ON_MESH_SLACK * ON_MESH_SLACK:
			return false

	return true


static func around(region: RID, center: Vector3, min_distance: float, max_distance: float, attempts: int) -> Vector3?:
	for i in attempts:
		var angle := AutoloadGame.rng.randf_range(0.0, TAU)
		var distance := AutoloadGame.rng.randf_range(min_distance, max_distance)
		var point := NavigationServer3D.region_get_closest_point(region, center + _flat_direction(angle) * distance)
		var point_distance := Vector2(point.x - center.x, point.z - center.z).length()
		if point_distance >= min_distance and point_distance <= max_distance:
			return point

	return null


static func _flat_direction(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))
