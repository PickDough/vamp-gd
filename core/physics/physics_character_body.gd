trait_name PhysicsCharacterBody
extends CharacterBody3D

## Gravity and impulses for a CharacterBody3D that sets its own velocity. Call _simulate_physics() each physics frame
## before move_and_slide(): gravity builds up while airborne and resets on the floor, and an applied Impulse adds its
## force for its duration.

@export var mass: float = 1.0

var _impulse: Impulse = Impulse.new()
var _fall_velocity: Vector3 = Vector3.ZERO


func apply_impulse(impulse: Impulse) -> void:
	_impulse = Impulse.new(
		_impulse.total_force + impulse.total_force,
		_impulse.total_time + impulse.total_time)


func _simulate_physics(delta: float) -> void:
	_fall_velocity = _next_fall_velocity(delta)
	velocity += _fall_velocity + _compute_impulse(delta)


func _next_fall_velocity(delta: float) -> Vector3:
	if is_on_floor():
		return Vector3.ZERO
	return _fall_velocity + get_gravity() * delta


func _compute_impulse(delta: float) -> Vector3:
	if _impulse.total_time <= _impulse.time_passed:
		_impulse = Impulse.new()
		return Vector3.ZERO

	_impulse.time_passed += delta
	var impulse := _impulse.total_force / (mass * _impulse.total_time)
	return impulse
