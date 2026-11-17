class_name EnemyState
extends RefCounted

## Everything the Hive tracks for one enemy, as plain data: the enemy's settings are copied in when it registers,
## and there is no node reference. step() reads only this object, the navigation server and the StepContext, so the
## hive can step different enemies on different threads at once. An enemy turns toward where it walks at most
## turn_speed radians per second, taking the shorter way round.
##
## Three shortcuts keep big crowds cheap, all staggered by slot so the work spreads evenly over ticks: an enemy
## recomputes its separation push only every SEPARATION_TICKS ticks, reusing the last push in between; one far from
## its target refreshes its path less often (up to MAX_REFRESH_SLOWDOWN times); and a walking enemy beyond
## FAR_DISTANCE, out of the camera's view, runs its full step only every FAR_STEP_TICKS ticks and keeps walking at
## its last velocity in between.
##
## Enemies land on the nav mesh under them. The ground probe is a short vertical segment, so an enemy lands on the
## surface it is over rather than whichever surface is nearest in 3D. Off the mesh's edge the closest point is on the
## edge, which keeps walking enemies on the mesh.

const WAYPOINT_REACH := 0.5
const STOP_DISTANCE := 0.8
const GROUND_TOLERANCE := 0.1
const GROUND_PROBE := 0.5
const AVOIDANCE_DISTANCE := 0.8
const DIRECTION_EPSILON := 0.001
const SEPARATION_TICKS := 2
const NEAR_TARGET_DISTANCE := 10.0
const MAX_REFRESH_SLOWDOWN := 4.0
const FAR_DISTANCE := 100.0
const FAR_STEP_TICKS := 2

var hit_radius: float
var crowd_id: int
var animation_phase: float
var linear_body_color := Color.WHITE
var tint := Color.WHITE
var position: Vector3
var yaw: float = 0.0
var previous_position: Vector3
var previous_yaw: float = 0.0

var _speed: float
var _turn_speed: float
var _mass: float
var _chases: bool
var _physics := BodyPhysics.new()
var _is_grounded: bool = false
var _time_until_refresh: float
var _path := PackedVector3Array()
var _path_index: int = 0
var _separation_push := Vector3.ZERO
var _velocity := Vector3.ZERO


func _init(enemy: Enemy, start_position: Vector3, chases: bool, time_until_refresh: float) -> void:
	hit_radius = enemy.hit_radius
	position = start_position
	previous_position = start_position
	_speed = enemy.speed
	_turn_speed = enemy.turn_speed
	_mass = enemy.mass
	_chases = chases
	_time_until_refresh = time_until_refresh


func apply_impulse(impulse: Impulse) -> void:
	_physics.apply(impulse)


func step(context: StepContext, index: int) -> void:
	previous_position = position
	previous_yaw = yaw
	if _can_coast(context, index):
		position += _velocity * context.delta
		return

	_time_until_refresh -= context.delta
	if _time_until_refresh <= 0.0:
		_refresh_path(context)
	if (context.tick + index) % SEPARATION_TICKS == 0:
		_separation_push = context.grid.repulsion(index, AVOIDANCE_DISTANCE) * _speed
	var velocity := _walking_velocity(context.delta) if _is_grounded else Vector3.ZERO
	if not _is_grounded or _physics.has_impulse:
		velocity += _physics.simulate(context.delta, _mass, _is_grounded, context.gravity)
	_velocity = velocity
	position += velocity * context.delta
	_snap_to_ground(context.navigation_map, velocity.y)


func _can_coast(context: StepContext, index: int) -> bool:
	if (context.tick + index) % FAR_STEP_TICKS == 0 or not _is_grounded or _physics.has_impulse:
		return false

	return (
		context.has_target
		and _flat_offset_to(context.target_position).length_squared() > FAR_DISTANCE ** 2
	)


func _refresh_path(context: StepContext) -> void:
	var distance := _flat_offset_to(context.target_position).length() if context.has_target else 0.0
	var slowdown := clampf(distance / NEAR_TARGET_DISTANCE, 1.0, MAX_REFRESH_SLOWDOWN)
	_time_until_refresh = context.path_refresh_interval * slowdown
	_path_index = 1
	if _chases and context.has_target:
		_path = NavigationServer3D.map_get_path(
			context.navigation_map,
			position,
			context.target_position,
			true,
		)
	else:
		_path.clear()


func _walking_velocity(delta: float) -> Vector3:
	if not _chases:
		return Vector3.ZERO

	var heading := _heading_to_waypoint()
	if heading.length_squared() > DIRECTION_EPSILON:
		yaw = rotate_toward(yaw, atan2(-heading.x, -heading.z), _turn_speed * delta)

	return (heading * _speed + _separation_push).limit_length(_speed)


func _heading_to_waypoint() -> Vector3:
	if _path.is_empty():
		return Vector3.ZERO

	var last := _path.size() - 1
	while (
		_path_index < last
		and _flat_offset_to(_path[_path_index]).length_squared() < WAYPOINT_REACH ** 2
	):
		_path_index += 1

	_path_index = mini(_path_index, last)
	var offset := _flat_offset_to(_path[_path_index])
	var is_arrived := _path_index == last and offset.length_squared() < STOP_DISTANCE ** 2
	return Vector3.ZERO if is_arrived or offset.length_squared() < DIRECTION_EPSILON else offset.normalized()


func _flat_offset_to(point: Vector3) -> Vector3:
	return Vector3(point.x - position.x, 0.0, point.z - position.z)


func _snap_to_ground(navigation_map: RID, vertical_velocity: float) -> void:
	var ground := NavigationServer3D.map_get_closest_point_to_segment(
		navigation_map,
		position + Vector3.UP * GROUND_PROBE,
		position + Vector3.DOWN * GROUND_PROBE,
	)
	_is_grounded = vertical_velocity <= 0.0 and position.y <= ground.y + GROUND_TOLERANCE
	if _is_grounded:
		position = ground
