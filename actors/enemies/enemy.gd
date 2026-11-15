class_name Enemy
extends CharacterBody3D
uses PhysicsCharacterBody, Damageable

## Walks toward its target along the navigation mesh and dies when its Health runs out.
## Without a target it holds its position.

const COLINEAR_LIMIT := 0.999

@export var speed: float = 2.0
@export var target_refresh_interval: float = 0.3

var _target: Node3D? = null
var _time_until_refresh: float = 0.0

@onready var rg_collision: CollisionShape3D = $ComplexCollisionShape
@onready var model: EnemyModel = $Model

@onready var _animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	_health.died.connect(_on_health_died)
	_animation_player.play(&"Walking_001")
	_refresh_target_position()


func _physics_process(delta: float) -> void:
	_time_until_refresh -= delta
	if _time_until_refresh <= 0.0:
		_refresh_target_position()

	if is_on_floor():
		var next_position := _nav_agent.get_next_path_position()
		var direction := (next_position - global_position).normalized()
		if not direction.is_zero_approx() and absf(direction.dot(Vector3.UP)) < COLINEAR_LIMIT:
			look_at(next_position)

		velocity = (next_position - global_position).normalized() * speed
	else:
		velocity = Vector3.ZERO

	_simulate_physics(delta)

	move_and_slide()


func setup(target: Node3D?) -> void:
	_target = target


func _refresh_target_position() -> void:
	_time_until_refresh = target_refresh_interval
	var target := _target
	if target == null or not is_instance_valid(target):
		_nav_agent.target_position = global_position
		return

	_nav_agent.target_position = target.global_position


func _on_health_died(_hit: HitInfo) -> void:
	queue_free()
