class_name SliceAction
extends Area3D

## One slice: hidden while it travels to its target, then turns its -Z away from its origin so it strikes the target
## from behind, swings once and frees itself, hitting each body at most once. Stats.area scales the blade and its
## hitbox but not the swing path.

var _stats: SkillStats
var _travel_time: float = 0.0
var _origin: Node3D
var _hit_bodies: Array[Node3D] = []

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hitbox: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_scale_by_area()
	_animation_player.speed_scale *= _stats.speed
	monitoring = false
	visible = false
	body_entered.connect(_on_body_entered)
	_animation_player.animation_finished.connect(_on_animation_finished)
	get_tree().create_timer(_travel_time, false, true).timeout.connect(_swing)


func setup(stats: SkillStats, travel_time: float, origin: Node3D) -> void:
	_stats = stats
	_travel_time = travel_time
	_origin = origin


func _scale_by_area() -> void:
	_mesh.scale *= _stats.area
	var box := _hitbox.shape.duplicate() as BoxShape3D
	box.size *= _stats.area
	_hitbox.shape = box


func _swing() -> void:
	_turn_back_to_origin()
	monitoring = true
	visible = true
	_animation_player.play(&"slice")


func _turn_back_to_origin() -> void:
	if is_instance_valid(_origin) and not _origin.global_position.is_equal_approx(global_position):
		look_at(global_position * 2.0 - _origin.global_position, Vector3.UP)


func _on_body_entered(body: Node3D) -> void:
	if body in _hit_bodies or body is not Damageable:
		return

	_hit_bodies.append(body)
	(body as Damageable).take_hit(_stats.roll_hit())


func _on_animation_finished(_animation_name: StringName) -> void:
	queue_free()
