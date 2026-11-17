class_name Enemy
extends Node3D
uses Damageable, HitReactive

## An enemy with Health that dies when its Health runs out. It has no body and no model of its own: the Hive it is
## registered with moves it, takes its impulses and draws it, playing `walk_animation` of `model_scene` (placed by
## `model_transform`) from a crowd MultiMesh in `body_color`, one of `colors` picked when it registers, and flashed by
## `tint`. Its hit_radius is what attacks hit. It leaves the
## hive when it leaves the tree. speed, turn_speed (radians per second), mass, hit_radius and the model settings are
## read once, when it registers. When it dies it leaves a DeathBody ragdoll pushed along the killing hit.

@export var speed: float = 2.0
@export var turn_speed: float = 4.0
@export var mass: float = 1.0
@export var hit_radius: float = 0.5
@export var model_scene: PackedScene
@export var model_transform := Transform3D.IDENTITY
@export var walk_animation: StringName = &"Walking_001"
@export var colors: Array[Color] = [
	Color(0.98, 0.66, 0.7),
	Color(0.62, 0.78, 0.98),
	Color(1.0, 0.9, 0.56),
	Color(0.66, 0.9, 0.76),
	Color(0.8, 0.7, 0.98),
]
@export var ragdoll_shape: Shape3D
@export var ragdoll_shape_scale: float = 1.0
@export var death_force: float = 10.0
@export var death_timeout: float = 2.0

var hive: Hive? = null
var hive_slot: int = 0
var body_color := Color.WHITE
var tint := Color.WHITE:
	set(value):
		tint = value
		var current_hive := hive
		if current_hive != null:
			current_hive.tint(hive_slot, value)


func _ready() -> void:
	_health.died.connect(_on_health_died)


func _exit_tree() -> void:
	var current_hive := hive
	if current_hive != null and is_instance_valid(current_hive):
		current_hive.unregister(self)


func apply_impulse(impulse: Impulse) -> void:
	var current_hive := hive
	if current_hive != null:
		current_hive.push(hive_slot, impulse)


func move_to(feet: Vector3, yaw: float) -> void:
	transform = Transform3D(Basis(Vector3.UP, yaw), feet)


func show_tint(color: Color) -> void:
	tint = color


func _on_health_died(hit: HitInfo) -> void:
	var ragdoll := DeathBody.new()
	get_tree().root.add_child(ragdoll)
	ragdoll.setup(self, death_timeout)
	ragdoll.apply_impulse(hit.hit_direction * death_force, hit.hit_point)
	queue_free()
