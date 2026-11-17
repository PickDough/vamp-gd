class_name Hive
extends Node
uses TargetFinder

## Moves every registered enemy toward the target in one physics step, instead of each enemy running its own, and
## answers attack queries for them, since enemies have no colliders. It also draws them: one CrowdRenderer per baked
## VertexAnimation, refreshed after each step.
##
## Slot i of _enemies and _states is the same enemy; removing one moves the last enemy into its slot. The step runs
## on up to bucket_count WorkerThreadPool threads once there are enough enemies to be worth it. Nodes only work on
## the main thread, so a step reads the navigation server and the spatial grid and writes only its own EnemyState
## and its slots of the position and instance buffers; the hive then moves the nodes on the main thread. Those
## buffers are fresh arrays every tick: the grid and the renderer keep last tick's, and writing into a shared one
## would make each thread copy it. _write_instance() runs twice per enemy per tick, so it stays one flat function.
## Everything outside the step (registering, impulses, queries) runs on the main thread.
##
## The grid is rebuilt right after each step, so it matches the enemies' positions until the next one, for both the
## next step's separation and this frame's queries. Registering or removing an enemy changes slots, so it marks the
## grid stale and the next user rebuilds it.

const GRID_CELL_SIZE := 1.0
const MIN_ENEMIES_PER_BUCKET := 64

@export var bucket_count: int = 4
@export var path_refresh_interval: float = 0.3

var count: int:
	get:
		return _enemies.size()

var _enemies: Array[Enemy] = []
var _states: Array[EnemyState] = []
var _grid := SpatialGrid.new(GRID_CELL_SIZE)
var _candidates := PackedInt32Array()
var _is_grid_stale: bool = true
var _max_hit_radius: float = 0.0
var _navigation_map: RID
var _target: Node3D? = null
var _gravity: Vector3
var _step_context: StepContext
var _active_buckets: int = 1
var _crowds: Array[CrowdRenderer] = []
var _positions := PackedVector3Array()
var _instances := PackedFloat32Array()
var _previous_instances := PackedFloat32Array()
var _crowd_sizes := PackedInt32Array()


func _ready() -> void:
	var strength: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var direction: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	_gravity = direction * strength


func _physics_process(delta: float) -> void:
	if not _navigation_map.is_valid() or _enemies.is_empty():
		return

	_refresh_grid()
	_prepare_buffers()
	_step(_new_step_context(delta))
	for slot in _enemies.size():
		var state := _states[slot]
		_enemies[slot].move_to(state.position, state.yaw)

	_grid.rebuild(_positions)
	_is_grid_stale = false
	_draw_crowds()


func setup(navigation_map: RID, target: Node3D) -> void:
	_navigation_map = navigation_map
	_target = target


func register(enemy: Enemy, position: Vector3, chases: bool) -> void:
	if enemy.hive != null:
		push_error("%s is already registered with a hive." % enemy.name)
		return

	var state := _new_state(enemy, position, chases)
	_crowd_sizes[state.crowd_id] += 1
	enemy.hive = self
	enemy.hive_slot = _enemies.size()
	_enemies.append(enemy)
	_states.append(state)
	_max_hit_radius = maxf(_max_hit_radius, enemy.hit_radius)
	_is_grid_stale = true
	enemy.move_to(position, 0.0)
	enemy.reset_physics_interpolation()


func unregister(enemy: Enemy) -> void:
	if enemy.hive != self:
		return

	var slot := enemy.hive_slot
	_crowd_sizes[_states[slot].crowd_id] -= 1
	var last: Enemy = _enemies.back()
	_enemies[slot] = last
	_states[slot] = _states.back()
	last.hive_slot = slot
	_enemies.pop_back()
	_states.pop_back()
	enemy.hive = null
	_is_grid_stale = true


func push(slot: int, impulse: Impulse) -> void:
	_states[slot].apply_impulse(impulse)


func tint(slot: int, color: Color) -> void:
	_states[slot].tint = color


func find_nearest(origin: Vector3, radius: float, max_count: int) -> Array[Node3D]:
	_refresh_grid()
	_grid.candidates(origin, radius, _candidates)
	var in_range := PackedVector2Array()
	for slot in _candidates:
		var distance_squared := origin.distance_squared_to(_states[slot].position)
		if distance_squared <= radius * radius:
			in_range.append(Vector2(distance_squared, slot))

	in_range.sort()
	var found: Array[Node3D] = []
	for rank in mini(max_count, in_range.size()):
		found.append(_enemies[int(in_range[rank].y)])

	return found


func find_in_box(box: Transform3D, size: Vector3) -> Array[Node3D]:
	_refresh_grid()
	var local := box.orthonormalized().affine_inverse()
	var half_size := size / 2.0
	_grid.candidates(box.origin, (half_size + Vector3.ONE * _max_hit_radius).length(), _candidates)
	var found: Array[Node3D] = []
	for slot in _candidates:
		var state := _states[slot]
		if _is_inside_box(local, half_size, state.position, state.hit_radius):
			found.append(_enemies[slot])

	return found


func _is_inside_box(local: Transform3D, half_size: Vector3, feet: Vector3, radius: float) -> bool:
	var center := local * (feet + Vector3.UP * radius)
	var reach := half_size + Vector3.ONE * radius
	return absf(center.x) <= reach.x and absf(center.y) <= reach.y and absf(center.z) <= reach.z


func _new_state(enemy: Enemy, position: Vector3, chases: bool) -> EnemyState:
	var first_refresh := AutoloadGame.rng.randf() * path_refresh_interval
	var state := EnemyState.new(enemy, position, chases, first_refresh)
	state.crowd_id = _crowd_for(enemy)
	state.animation_phase = AutoloadGame.rng.randf()
	if not enemy.colors.is_empty():
		enemy.body_color = enemy.colors[AutoloadGame.rng.randi_range(0, enemy.colors.size() - 1)]
	state.linear_body_color = enemy.body_color.srgb_to_linear()
	return state


func _crowd_for(enemy: Enemy) -> int:
	var animation := VertexAnimation.of(enemy.model_scene, enemy.walk_animation, enemy.model_transform, self)
	for crowd in _crowds:
		if crowd.animation == animation:
			return crowd.crowd_id

	var crowd := CrowdRenderer.new()
	crowd.setup(animation, _crowds.size())
	add_child(crowd)
	_crowds.append(crowd)
	_crowd_sizes.append(0)
	return crowd.crowd_id


func _prepare_buffers() -> void:
	_positions = PackedVector3Array()
	_positions.resize(count)
	_instances = PackedFloat32Array()
	_instances.resize(count * CrowdRenderer.FLOATS_PER_INSTANCE)
	_previous_instances = PackedFloat32Array()
	_previous_instances.resize(count * CrowdRenderer.FLOATS_PER_INSTANCE)


func _draw_crowds() -> void:
	if _crowds.size() == 1:
		_crowds[0].show_instances(_instances, _previous_instances, _states.size())
		return

	for crowd in _crowds:
		var members := PackedInt32Array()
		for slot in _states.size():
			if _states[slot].crowd_id == crowd.crowd_id:
				members.append(slot)
		crowd.show_members(_instances, _previous_instances, members)


func _refresh_grid() -> void:
	if _is_grid_stale:
		_rebuild_grid()


func _rebuild_grid() -> void:
	var positions := PackedVector3Array()
	positions.resize(_states.size())
	for slot in _states.size():
		positions[slot] = _states[slot].position

	_grid.rebuild(positions)
	_is_grid_stale = false


func _new_step_context(delta: float) -> StepContext:
	var target := _target
	var has_target := target != null and is_instance_valid(target)
	var target_position := target.global_position if has_target else Vector3.ZERO
	return StepContext.new(
			delta, Engine.get_physics_frames(), path_refresh_interval, _navigation_map, _gravity, target_position,
			has_target, _grid,
	)


func _step(context: StepContext) -> void:
	_step_context = context
	_active_buckets = clampi(floori(float(_enemies.size()) / MIN_ENEMIES_PER_BUCKET), 1, maxi(1, bucket_count))
	if _active_buckets == 1:
		_step_bucket(0)
		return

	var group := WorkerThreadPool.add_group_task(_step_bucket, _active_buckets, _active_buckets, true)
	WorkerThreadPool.wait_for_group_task_completion(group)


func _step_bucket(bucket: int) -> void:
	var context := _step_context
	var positions := _positions
	var instances := _instances
	var previous_instances := _previous_instances
	var total := _states.size()
	var first := floori(float(total * bucket) / _active_buckets)
	var end := floori(float(total * (bucket + 1)) / _active_buckets)
	for slot in range(first, end):
		var state := _states[slot]
		state.step(context, slot)
		positions[slot] = state.position
		_write_instance(instances, slot, state.position, state.yaw, state)
		_write_instance(previous_instances, slot, state.previous_position, state.previous_yaw, state)


func _write_instance(  # lint-ignore: function-length
		buffer: PackedFloat32Array,
		slot: int,
		feet: Vector3,
		yaw: float,
		state: EnemyState,
) -> void:
	var offset := slot * CrowdRenderer.FLOATS_PER_INSTANCE
	var cosine := cos(yaw)
	var sine := sin(yaw)
	buffer[offset] = cosine
	buffer[offset + 2] = sine
	buffer[offset + 3] = feet.x
	buffer[offset + 5] = 1.0
	buffer[offset + 7] = feet.y
	buffer[offset + 8] = -sine
	buffer[offset + 10] = cosine
	buffer[offset + 11] = feet.z
	buffer[offset + CrowdRenderer.COLOR_OFFSET] = state.tint.r
	buffer[offset + CrowdRenderer.COLOR_OFFSET + 1] = state.tint.g
	buffer[offset + CrowdRenderer.COLOR_OFFSET + 2] = state.tint.b
	buffer[offset + CrowdRenderer.COLOR_OFFSET + 3] = 1.0
	buffer[offset + CrowdRenderer.CUSTOM_OFFSET] = state.animation_phase
	buffer[offset + CrowdRenderer.CUSTOM_OFFSET + 1] = state.linear_body_color.r
	buffer[offset + CrowdRenderer.CUSTOM_OFFSET + 2] = state.linear_body_color.g
	buffer[offset + CrowdRenderer.CUSTOM_OFFSET + 3] = state.linear_body_color.b