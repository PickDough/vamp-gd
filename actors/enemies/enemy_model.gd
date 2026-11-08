class_name EnemyModel
extends Node3D

## The enemy's imported model. Exposes the mesh that damage effects tint.

@onready var mesh: MeshInstance3D = $"Armature/Skeleton3D".get_child(0)
