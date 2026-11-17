class_name BodyPhysics
extends RefCounted

## Gravity and impulses for a body its owner moves by hand. Add simulate() to the body's velocity each physics
## frame: gravity builds up while airborne and resets on the ground, and an applied Impulse adds its force for its
## duration. A body that handles its own gravity adds only consume_impulse(). It touches no engine objects, so it
## may run on worker threads. Applying an impulse while another is running merges them and restarts the clock. A
## grounded body without an impulse gets nothing from simulate(), so its owner may skip the call; the next grounded
## call resets the fall speed.

var has_impulse: bool:
	get:
		return _duration > 0.0

var _force := Vector3.ZERO
var _duration: float = 0.0
var _elapsed: float = 0.0
var _fall_velocity := Vector3.ZERO


func apply(impulse: Impulse) -> void:
	_force += impulse.total_force
	_duration += impulse.total_time
	_elapsed = 0.0


func simulate(delta: float, mass: float, is_grounded: bool, gravity: Vector3) -> Vector3:
	_fall_velocity = Vector3.ZERO if is_grounded else _fall_velocity + gravity * delta
	return _fall_velocity + consume_impulse(delta, mass)


func consume_impulse(delta: float, mass: float) -> Vector3:
	if _duration <= _elapsed:
		_force = Vector3.ZERO
		_duration = 0.0
		_elapsed = 0.0
		return Vector3.ZERO

	_elapsed += delta
	return _force / (mass * _duration)
