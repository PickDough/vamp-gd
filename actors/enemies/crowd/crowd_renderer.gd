class_name CrowdRenderer
extends MultiMeshInstance3D

## Draws every enemy that shares one VertexAnimation as one instance of a single MultiMesh. The Hive fills instance
## buffers in this layout once per physics tick: a 3x4 transform, a color for hit flashes, and custom data holding
## the animation phase and the body color (already in linear space, since custom data skips the sRGB conversion).
## The previous tick's buffer goes alongside, so the engine interpolates instances between ticks the way it
## interpolates nodes. Each enemy is drawn twice: the matte body, then a dark outline pass. show_members() picks this
## crowd's instances out of buffers that hold several crowds.

const SHADER_PATH := "res://actors/enemies/crowd/crowd.gdshader"
const OUTLINE_SHADER_PATH := "res://actors/enemies/crowd/crowd_outline.gdshader"
const FLOATS_PER_INSTANCE := 20
const COLOR_OFFSET := 12
const CUSTOM_OFFSET := 16

var crowd_id: int
var animation: VertexAnimation

var _current := PackedFloat32Array()
var _previous := PackedFloat32Array()


func setup(crowd_animation: VertexAnimation, id: int) -> void:
	crowd_id = id
	animation = crowd_animation
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = crowd_animation.mesh
	var material := _animated_material(SHADER_PATH, crowd_animation)
	material.next_pass = _animated_material(OUTLINE_SHADER_PATH, crowd_animation)
	material_override = material


func show_instances(current: PackedFloat32Array, previous: PackedFloat32Array, count: int) -> void:
	if multimesh.instance_count != count:
		multimesh.instance_count = count
	if count > 0:
		multimesh.set_buffer_interpolated(current, previous)


func show_members(current: PackedFloat32Array, previous: PackedFloat32Array, members: PackedInt32Array) -> void:
	_current.resize(members.size() * FLOATS_PER_INSTANCE)
	_previous.resize(members.size() * FLOATS_PER_INSTANCE)
	for index in members.size():
		for value in FLOATS_PER_INSTANCE:
			_current[index * FLOATS_PER_INSTANCE + value] = current[members[index] * FLOATS_PER_INSTANCE + value]
			_previous[index * FLOATS_PER_INSTANCE + value] = previous[members[index] * FLOATS_PER_INSTANCE + value]
	show_instances(_current, _previous, members.size())


func _animated_material(shader_path: String, crowd_animation: VertexAnimation) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(shader_path) as Shader
	material.set_shader_parameter(&"positions", crowd_animation.positions)
	material.set_shader_parameter(&"normals", crowd_animation.normals)
	material.set_shader_parameter(&"frame_count", float(crowd_animation.frame_count))
	material.set_shader_parameter(&"frames_per_second", VertexAnimation.FRAMES_PER_SECOND)
	return material
