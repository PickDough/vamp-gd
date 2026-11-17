class_name PlayerBody
extends CharacterBody3D
uses Damageable, HitReactive

## The player character: turns input into walking, turning toward the walking direction, and jumping. Enemies
## within contact_range hurt it, each hit dealing the current minute of the run (from its Score); each hit leaves it
## invulnerable, blinking, for the InvulnerabilityTimer's wait time, and its OnHitEffect knocks it away from the
## enemy and flashes it. When its Health runs out it stops moving and emits died. Falling more than
## fall_death_distance below the last floor it stood on kills it outright, invulnerable or not.
##
## Knockback comes from BodyPhysics.consume_impulse() and is added to the velocity only around move_and_slide(), so
## the push lasts exactly as long as the impulse instead of carrying over into the next frame's walking velocity.
## The flash is an unshaded overlay on every mesh of the model, so it works whatever materials the model has; its
## opacity follows how far the tint is from white. Each mesh also hands its bounds to the light-blue outline pass of
## its material (assets/shaders/outline.gdshader).

signal died

const DIRECTION_EPSILON := 0.001
const ANGLE_EPSILON := 1e-5
const BLINK_PERIOD := 0.15
const MAX_FLASH_OPACITY := 0.7

@export var speed: float = 5.0
@export var jump_velocity: float = 6.5
@export var ground_check: float = 1.0
@export var rotation_speed: float = 5.0
@export var gravity_scale: float = 1.0
@export var mass: float = 1.0
@export var contact_range: float = 1.0
@export var fall_death_distance: float = 20.0

var facing: Vector3:
	get:
		return -_mesh.global_basis.z
var is_close_to_floor: bool:  # lint-ignore: private-member
	get:
		return _ground_ray.is_colliding()
var is_invulnerable: bool:
	get:
		return not _invulnerability_timer.is_stopped()

var _target_finder: TargetFinder? = null
var _score: Score? = null
var _physics := BodyPhysics.new()
var _flash_material := StandardMaterial3D.new()
var _last_floor_height: float = 0.0

@onready var _mesh: Node3D = $Mesh
@onready var _ground_ray: RayCast3D = $GroundRay
@onready var _skills: Node3D = $Skills
@onready var _invulnerability_timer: Timer = $InvulnerabilityTimer


func _ready() -> void:
	_ground_ray.target_position = Vector3.DOWN * ground_check
	_setup_flash()
	_health.damaged.connect(_on_health_damaged)
	_health.died.connect(_on_health_died)


func _process(_delta: float) -> void:
	_mesh.visible = not is_invulnerable or fmod(_invulnerability_timer.time_left, BLINK_PERIOD) > BLINK_PERIOD / 2.0


func _physics_process(delta: float) -> void:
	if not _is_in_physics_space():
		return

	var intent := _read_intent()
	velocity = _next_velocity(intent, delta)
	if intent.direction.length() > DIRECTION_EPSILON:
		_turn_toward(global_transform.basis * intent.direction, delta)

	var push := _physics.consume_impulse(delta, mass)
	velocity += push
	move_and_slide()
	velocity -= push
	_take_contact_damage()
	_check_fall()


func setup(target_finder: TargetFinder, score: Score) -> void:
	_target_finder = target_finder
	_score = score
	_last_floor_height = global_position.y
	_skills.propagate_call(&"setup", [target_finder])


func take_hit(hit: HitInfo) -> void:
	if not is_invulnerable:
		_health.apply(hit)


func apply_impulse(impulse: Impulse) -> void:
	_physics.apply(impulse)


func show_tint(color: Color) -> void:
	var strength := 1.0 - minf(color.g, color.b)
	_flash_material.albedo_color = Color(color, strength * MAX_FLASH_OPACITY)


func _is_in_physics_space() -> bool:
	return PhysicsServer3D.body_get_direct_state(get_rid()) != null


func _setup_flash() -> void:
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	show_tint(Color.WHITE)
	for mesh: MeshInstance3D in _mesh.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _flash_material
		var bounds := mesh.get_aabb()
		mesh.set_instance_shader_parameter(&"outline_center", bounds.get_center())
		mesh.set_instance_shader_parameter(&"outline_extent", bounds.size / 2.0)


func _read_intent() -> PlayerIntent:
	var intent := PlayerIntent.new()
	intent.jump = Input.is_action_just_pressed("ui_accept") and is_on_floor()
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	intent.direction = (transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
	return intent


func _next_velocity(intent: PlayerIntent, delta: float) -> Vector3:
	var next := velocity
	if not is_on_floor():
		next += get_gravity() * gravity_scale * delta
	if intent.jump:
		next.y = jump_velocity
	var walking := intent.direction.length() > DIRECTION_EPSILON
	next.x = intent.direction.x * speed if walking else move_toward(velocity.x, 0.0, speed)
	next.z = intent.direction.z * speed if walking else move_toward(velocity.z, 0.0, speed)
	return next


func _turn_toward(world_direction: Vector3, delta: float) -> void:
	var current := _mesh.global_basis.orthonormalized()
	var target := Basis.looking_at(world_direction, Vector3.UP)
	var angle := current.get_rotation_quaternion().angle_to(target.get_rotation_quaternion())
	var weight := minf(1.0, rotation_speed * delta / angle) if angle > ANGLE_EPSILON else 1.0
	_mesh.global_basis = current.slerp(target, weight).orthonormalized()


func _take_contact_damage() -> void:
	var target_finder := _target_finder
	var score := _score
	if target_finder == null or score == null or is_invulnerable:
		return

	for target in target_finder.find_nearest(global_position, contact_range, 1):
		var away := target.global_position.direction_to(global_position)
		away.y = 0.0
		var hit := HitInfo.new(score.current_minute)
		hit.hit_point = target.global_position
		hit.hit_direction = away.normalized()
		take_hit(hit)


func _check_fall() -> void:
	if is_on_floor():
		_last_floor_height = global_position.y
	elif _last_floor_height - global_position.y > fall_death_distance:
		var fall := HitInfo.new(_health.current)
		fall.hit_point = global_position
		_health.apply(fall)


func _on_health_damaged(_hit: HitInfo) -> void:
	_invulnerability_timer.start()


func _on_health_died(_hit: HitInfo) -> void:
	set_physics_process(false)
	set_process(false)
	_mesh.visible = true
	died.emit()
