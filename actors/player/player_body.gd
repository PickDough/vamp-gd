class_name PlayerBody
extends CharacterBody3D

## The player character: turns input into walking, turning toward the walking direction, and jumping.

const DIRECTION_EPSILON := 0.001
const ANGLE_EPSILON := 1e-5

@export var speed: float = 5.0
@export var jump_velocity: float = 6.5
@export var ground_check: float = 1.0
@export var rotation_speed: float = 5.0
@export var gravity_scale: float = 1.0

var facing: Vector3:
	get:
		return -_mesh.global_basis.z
var is_close_to_floor: bool:  # lint-ignore: private-member
	get:
		return _ground_ray.is_colliding()

@onready var _mesh: Node3D = $Mesh
@onready var _ground_ray: RayCast3D = $GroundRay


func _ready() -> void:
	_ground_ray.target_position = Vector3.DOWN * ground_check


func _physics_process(delta: float) -> void:
	var intent := _read_intent()
	velocity = _next_velocity(intent, delta)
	if intent.direction.length() > DIRECTION_EPSILON:
		_turn_toward(global_transform.basis * intent.direction, delta)
	move_and_slide()


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
