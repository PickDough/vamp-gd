class_name SliceSkill
extends Node3D

## Every cooldown, sends slices out to the nearest enemies in range. A slice travels at base_travel_speed times
## stats.speed, then swings with its back to the skill, wherever the player has moved by then. Each instance
## works on its own copy of its stats.

const SLICE_ACTION_SCENE_PATH := "res://skills/slice/slice_action.tscn"

@export var stats: SkillStats
@export var base_travel_speed: float = 15.0

@onready var _detector: TargetDetector = $Detector
@onready var _cooldown: Timer = $Cooldown


func _ready() -> void:
	stats = stats.duplicate()
	_detector.set_radius(stats.target_range)
	_cooldown.wait_time = stats.cooldown
	_cooldown.timeout.connect(_cast)
	_cooldown.start()


func _cast() -> void:
	for target in _detector.nearest(stats.count):
		_send_slice_to(target)


func _send_slice_to(target: Node3D) -> void:
	var travel_time := global_position.distance_to(target.global_position) / (base_travel_speed * stats.speed)
	var slice := (load(SLICE_ACTION_SCENE_PATH) as PackedScene).instantiate() as SliceAction
	slice.setup(stats, travel_time, self)
	slice.top_level = true
	add_child(slice)
	slice.global_position = target.global_position
