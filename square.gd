extends Node3D

@export var time_offset: float = 0.1
@export var mesh: RigidBody3D
@export var r = 0.025

var timer: float

func _process(delta: float) -> void:
    if timer < time_offset:
        timer += delta
        return
    timer = 0.0;
    if randf() > 0.25: 
        var m = mesh.duplicate()
        m.position = Vector3((-1.0+r) + 2.0*((1-r)*randf()), 1, (-1.0+r) + 2.0*(1-r)*randf())
        add_child(m)
