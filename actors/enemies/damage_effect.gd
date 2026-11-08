class_name DamageEffect
extends Node

## Reacts to its enemy's Health taking damage: knocks the enemy mostly upward and slightly along the hit, and
## flashes its model red before fading back to white.

const KNOCKBACK_LIFT := 20.0
const KNOCKBACK_DURATION := 0.15
const FLASH_IN_DURATION := 0.05
const FLASH_OUT_DURATION := 0.15

@export var hit_force: float = 1.0

@onready var _health: Health = $"../Health"
@onready var _model: EnemyModel = $"../Model"
@onready var _body: Enemy = $"../."


func _ready() -> void:
	_health.damaged.connect(_on_damage)


func _on_damage(info: HitInfo) -> void:
	_body.apply_impulse(
		Impulse.new((info.hit_direction + Vector3.UP * KNOCKBACK_LIFT).normalized() * hit_force, KNOCKBACK_DURATION)
	)

	var tween := create_tween()
	tween.tween_property(_model.mesh, ^"material_override:albedo_color", Color.RED, FLASH_IN_DURATION)
	tween.tween_property(_model.mesh, ^"material_override:albedo_color", Color.WHITE, FLASH_OUT_DURATION)
