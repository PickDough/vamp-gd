class_name FloatingToys
extends Node3D

## Toy shapes (balls, rings, blocks, cones, capsules; some polka-dotted) scattered through the void around the map.
## scatter() places them once the navigation mesh is ready, at least clear_distance away from it unless they float
## well below the floor, so none of them sits in the play area. Their shader bobs, spins and fades them near the
## camera.

const TOY_SHADER_PATH := "res://world/map/void/toy.gdshader"
const PLACE_ATTEMPTS := 50

@export var count: int = 34
@export var min_distance: float = 30.0
@export var max_distance: float = 110.0
@export var min_height: float = -35.0
@export var max_height: float = 18.0
@export var clear_distance: float = 16.0
@export var free_depth: float = 14.0
@export var min_size: float = 3.0
@export var max_size: float = 10.0
@export_range(0.0, 1.0) var dotted_share: float = 0.4
@export var colors: Array[Color] = [
	Color(0.98, 0.5, 0.52),
	Color(0.45, 0.62, 0.98),
	Color(1.0, 0.86, 0.35),
	Color(0.7, 0.5, 0.95),
	Color(0.45, 0.85, 0.62),
]
@export var random_seed: int = 3


func scatter(navigation_region: RID, floor_height: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var shapes: Array[Mesh] = [SphereMesh.new(), TorusMesh.new(), BoxMesh.new(), CylinderMesh.new(), CapsuleMesh.new()]
	(shapes[3] as CylinderMesh).top_radius = 0.0
	for index in count:
		var toy := MeshInstance3D.new()
		toy.mesh = shapes[index % shapes.size()]
		toy.material_override = _toy_material(rng)
		toy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		toy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(toy)
		toy.global_position = _free_spot(rng, navigation_region, floor_height)
		toy.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		toy.scale = Vector3.ONE * rng.randf_range(min_size, max_size)


func _toy_material(rng: RandomNumberGenerator) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(TOY_SHADER_PATH) as Shader
	material.set_shader_parameter(&"albedo", colors[rng.randi_range(0, colors.size() - 1)])
	material.set_shader_parameter(&"dots", 1.0 if rng.randf() < dotted_share else 0.0)
	return material


func _free_spot(rng: RandomNumberGenerator, navigation_region: RID, floor_height: float) -> Vector3:
	for attempt in PLACE_ATTEMPTS:
		var angle := rng.randf() * TAU
		var distance := rng.randf_range(min_distance, max_distance)
		var height := floor_height + rng.randf_range(min_height, max_height)
		var spot := Vector3(cos(angle) * distance, height, sin(angle) * distance)
		var ground := Vector3(spot.x, floor_height, spot.z)
		var nearest := NavigationServer3D.region_get_closest_point(navigation_region, ground)
		var is_clear := Vector2(spot.x - nearest.x, spot.z - nearest.z).length() > clear_distance
		if is_clear or height < floor_height - free_depth:
			return spot

	return Vector3(0.0, floor_height + min_height, 0.0)
