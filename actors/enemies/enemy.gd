class_name Enemy
extends CharacterBody3D
uses PhysicsCharacterBody, Damageable

## Walks toward its target along the navigation mesh and dies when its Health runs out.
## Without a target it holds its position.

@export var speed: float = 2.0
@export var target_refresh_interval: float = 0.3

var _target: Node3D? = null

@onready var rg_collision: CollisionShape3D = $ComplexCollisionShape
@onready var model: EnemyModel = $Model

@onready var _animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _target_refresh_timer: Timer = $TargetRefreshTimer


func _ready() -> void:
	_health.died.connect(_on_health_died)
	_target_refresh_timer.wait_time = target_refresh_interval
	_target_refresh_timer.timeout.connect(_refresh_target_position)
	_target_refresh_timer.start()
	_animation_player.play(&"Walking_001")
	_refresh_target_position()


func _physics_process(delta: float) -> void:
	if is_on_floor():
		var next_position := _nav_agent.get_next_path_position()
		if not global_position.is_equal_approx(next_position):
			look_at(next_position)

		velocity = (next_position - global_position).normalized() * speed
	else:
		velocity = Vector3.ZERO

	_simulate_physics(delta)

	move_and_slide()


func setup(target: Node3D?) -> void:
	_target = target


func _refresh_target_position() -> void:
	var target := _target
	if target != null and is_instance_valid(target):
		_nav_agent.target_position = target.global_position
	else:
		_nav_agent.target_position = global_position


func _on_health_died(_hit: HitInfo) -> void:
	queue_free()
