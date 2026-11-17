class_name Health
extends Node

## Hit points of its owner. Only reports damage and death; the owner decides what they mean.

signal damaged(hit: HitInfo)
signal died(hit: HitInfo)

@export var max_health: float = 10.0

var current: float = 0.0
var _is_dead: bool:
	get:
		return current <= 0.0


func _ready() -> void:
	current = max_health


func apply(hit: HitInfo) -> void:
	if _is_dead:
		return

	current -= hit.amount
	if _is_dead:
		died.emit(hit)
	else:
		damaged.emit(hit)
