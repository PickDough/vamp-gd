class_name Enemy
extends CharacterBody3D
uses Damageable

## Walks toward its target along the navigation mesh, alternating a full-speed step with a slower one in time with
## its walk animation, and dies when its Health runs out. Without a target it holds its position.

signal died

const STEP_DURATION := 0.6
const SLOW_STEP_SPEED_FACTOR := 0.7

@export var speed: float = 2.0
@export var target_refresh_interval: float = 0.3

var _target: Node3D? = null

@onready var _animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var _nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _health: Health = $Health
@onready var _target_refresh_timer: Timer = $TargetRefreshTimer


func _ready() -> void:
	_health.died.connect(_on_health_died)
	_target_refresh_timer.wait_time = target_refresh_interval
	_target_refresh_timer.timeout.connect(_refresh_target_position)
	_target_refresh_timer.start()
	_animation_player.play(&"Walking_001")
	_refresh_target_position()


func _physics_process(_delta: float) -> void:
	var next_position := _nav_agent.get_next_path_position()
	velocity = (next_position - global_position).normalized() * speed * _step_speed_factor()
	if not next_position.is_equal_approx(global_position):
		look_at(next_position)
	move_and_slide()


func setup(target: Node3D?) -> void:
	_target = target


func take_hit(hit: HitInfo) -> void:
	_health.apply(hit)


func _refresh_target_position() -> void:
	var target := _target
	if target != null and is_instance_valid(target):
		_nav_agent.target_position = target.global_position
	else:
		_nav_agent.target_position = global_position


func _step_speed_factor() -> float:
	var step := int(_animation_player.current_animation_position / STEP_DURATION)
	return 1.0 if step % 2 == 0 else SLOW_STEP_SPEED_FACTOR


func _on_health_died(_hit: HitInfo) -> void:
	died.emit()
	queue_free()
