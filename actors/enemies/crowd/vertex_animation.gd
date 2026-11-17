class_name VertexAnimation
extends RefCounted

## One skeletal animation of an enemy model baked into textures, so a whole crowd can play it from a MultiMesh
## without a Skeleton3D, an AnimationPlayer or a node per enemy. Row f of `positions` and `normals` holds every
## vertex of the model, skinned for frame f and moved into the enemy's root space by `model_transform`; column v is
## vertex v of `mesh`, an unskinned copy of the model's first surface in the same vertex order.
##
## Baking poses a temporary copy of the model, which has to be inside the tree for its AnimationPlayer to apply
## poses, and skins its vertices on the CPU the way Skeleton3D skins them: bone global pose times the skin's bind
## pose, blended by the vertex's weights. Bakes are cached per model, animation and transform.

const FRAMES_PER_SECOND := 30.0
const MAX_TEXTURE_WIDTH := 16384
const BOUNDS_MARGIN := 0.1

static var _cache: Dictionary[String, VertexAnimation] = {}

var mesh: ArrayMesh
var positions: ImageTexture
var normals: ImageTexture
var frame_count: int


static func of(
		model_scene: PackedScene,
		animation: StringName,
		model_transform: Transform3D,
		host: Node,
) -> VertexAnimation:
	var key := "%s|%s|%s" % [model_scene.resource_path, animation, model_transform]
	if not _cache.has(key):
		_cache[key] = VertexAnimation.new(model_scene, animation, model_transform, host)
	return _cache[key]


func _init(model_scene: PackedScene, animation: StringName, model_transform: Transform3D, host: Node) -> void:
	var model := model_scene.instantiate() as Node3D
	host.add_child(model)
	var mesh_instance := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var to_root := model_transform * model.global_transform.affine_inverse() * mesh_instance.global_transform
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	_bake(mesh_instance, player, animation, arrays, to_root)
	_build_mesh(arrays)
	model.free()


func _bake(
		mesh_instance: MeshInstance3D,
		player: AnimationPlayer,
		animation: StringName,
		arrays: Array,
		to_root: Transform3D,
) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_count := vertices.size()
	assert(vertex_count <= MAX_TEXTURE_WIDTH, "too many vertices to bake into one texture row")
	frame_count = maxi(1, ceili(player.get_animation(animation).length * FRAMES_PER_SECOND))
	var position_image := Image.create_empty(vertex_count, frame_count, false, Image.FORMAT_RGBAF)
	var normal_image := Image.create_empty(vertex_count, frame_count, false, Image.FORMAT_RGBAF)
	var skeleton := mesh_instance.get_node(mesh_instance.skeleton) as Skeleton3D
	player.play(animation)
	for frame in frame_count:
		player.seek(frame / FRAMES_PER_SECOND, true)
		var skin_transforms := _skin_transforms(skeleton, mesh_instance.skin, to_root)
		_bake_frame(frame, arrays, skin_transforms, position_image, normal_image)

	positions = ImageTexture.create_from_image(position_image)
	normals = ImageTexture.create_from_image(normal_image)


func _skin_transforms(skeleton: Skeleton3D, skin: Skin, to_root: Transform3D) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone := skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(bind))
		transforms.append(to_root * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind))

	return transforms


func _bake_frame(
		frame: int,
		arrays: Array,
		skin_transforms: Array[Transform3D],
		position_image: Image,
		normal_image: Image,
) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences := floori(float(bones.size()) / vertices.size())
	for vertex in vertices.size():
		var position := Vector3.ZERO
		var normal := Vector3.ZERO
		for influence in range(vertex * influences, (vertex + 1) * influences):
			var skinning := skin_transforms[bones[influence]]
			position += skinning * vertices[vertex] * weights[influence]
			normal += skinning.basis * vertex_normals[vertex] * weights[influence]
		position_image.set_pixel(vertex, frame, Color(position.x, position.y, position.z))
		normal_image.set_pixel(vertex, frame, Color(normal.x, normal.y, normal.z))


func _build_mesh(arrays: Array) -> void:
	var bounds := AABB()
	var image := positions.get_image()
	for frame in frame_count:
		for vertex in image.get_width():
			var pixel := image.get_pixel(vertex, frame)
			bounds = bounds.expand(Vector3(pixel.r, pixel.g, pixel.b))

	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = bounds.grow(BOUNDS_MARGIN)
