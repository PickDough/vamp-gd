class_name SliceAction
extends Node3D

## One slice: hidden while it travels to its target, then turns its -Z away from its origin so it strikes the target
## from behind, swings once and frees itself, hitting each target at most once. stats.area scales the blade and its
## hitbox but not the swing path. Targets aren't physics bodies, so each physics frame of the swing tests the
## animated Hitbox node's box against the TargetFinder instead of an Area3D overlap.

@export var critical_color: Color = Color.GOLD
@export var hitbox_size := Vector3(0.5, 4.0, 0.5)

var scaled_hitbox_size: Vector3

var _stats: SkillStats
var _travel_time: float = 0.0
var _origin: Node3D
var _target_finder: TargetFinder
var _is_swinging: bool = false
var _hit_targets: Dictionary[Node3D, bool] = {}
var _hit: HitInfo

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hitbox: Node3D = $Hitbox


func _ready() -> void:
	_scale_by_area()
	_animation_player.speed_scale *= _stats.speed
	visible = false
	_animation_player.animation_finished.connect(_on_animation_finished)
	get_tree().create_timer(_travel_time, false, true).timeout.connect(_swing)
	if _hit.is_critical:
		(_mesh.get_active_material(0) as StandardMaterial3D).albedo_color = critical_color


func _physics_process(_delta: float) -> void:
	if not _is_swinging:
		return

	for target in _target_finder.find_in_box(_hitbox.global_transform, scaled_hitbox_size):
		_hit_once(target)


func setup(stats: SkillStats, travel_time: float, origin: Node3D, target_finder: TargetFinder) -> void:
	_stats = stats
	_travel_time = travel_time
	_origin = origin
	_target_finder = target_finder
	_hit = _stats.roll_hit()


func _scale_by_area() -> void:
	_mesh.scale *= _stats.area
	scaled_hitbox_size = hitbox_size * _stats.area


func _swing() -> void:
	if not is_inside_tree():
		return

	_turn_back_to_origin()
	_is_swinging = true
	visible = true
	_animation_player.play(&"slice")


func _turn_back_to_origin() -> void:
	if is_instance_valid(_origin) and not _origin.global_position.is_equal_approx(global_position):
		look_at(global_position * 2.0 - _origin.global_position, Vector3.UP)


func _hit_once(target: Node3D) -> void:
	if _hit_targets.has(target) or target is not Damageable:
		return

	_hit_targets[target] = true
	var hit := HitInfo.new(_hit.amount, _hit.is_critical)
	hit.hit_point = _mesh.global_position + global_transform.basis.z
	hit.hit_direction = (target.global_position - _knock_origin()).normalized() + Vector3.UP
	(target as Damageable).take_hit(hit)


func _knock_origin() -> Vector3:
	return _origin.global_position if is_instance_valid(_origin) else global_position


func _on_animation_finished(_animation_name: StringName) -> void:
	queue_free()
