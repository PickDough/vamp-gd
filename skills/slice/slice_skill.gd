class_name SliceSkill
extends Node3D

## Every cooldown, sends slices out to the nearest enemies in range. A slice travels at base_travel_speed times
## stats.speed, then swings with its back to the skill, wherever the player has moved by then. Each instance
## works on its own copy of its stats. It finds targets through the TargetFinder handed to setup(); until then it
## casts nothing.

const SLICE_ACTION_SCENE_PATH := "res://skills/slice/slice_action.tscn"

@export var stats: SkillStats
@export var base_travel_speed: float = 15.0

var _target_finder: TargetFinder? = null

@onready var _cooldown: Timer = $Cooldown


func _ready() -> void:
	stats = stats.duplicate()
	_cooldown.wait_time = stats.cooldown
	_cooldown.timeout.connect(_cast)
	_cooldown.start()


func setup(target_finder: TargetFinder) -> void:
	_target_finder = target_finder


func _cast() -> void:
	var target_finder := _target_finder
	if target_finder == null:
		return

	for target in target_finder.find_nearest(global_position, stats.target_range, stats.count):
		_send_slice_to(target, target_finder)


func _send_slice_to(target: Node3D, target_finder: TargetFinder) -> void:
	var travel_time := global_position.distance_to(target.global_position) / (base_travel_speed * stats.speed)
	var slice := (load(SLICE_ACTION_SCENE_PATH) as PackedScene).instantiate() as SliceAction
	slice.setup(stats, travel_time, self, target_finder)
	slice.top_level = true
	add_child(slice)
	slice.global_position = target.global_position
