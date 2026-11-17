class_name Score
extends Node

## The running tally of one run: how long it has been played. current_minute counts from 1, so the first minute of
## play is minute 1. Run owns it and hands it to whatever scores against it.

const SECONDS_PER_MINUTE := 60.0

var time_playing: float = 0.0
var current_minute: int:
	get:
		return floori(time_playing / SECONDS_PER_MINUTE) + 1


func _process(delta: float) -> void:
	time_playing += delta
