class_name OnHitEffect
extends Node

## Reacts to its enemy's Health taking damage: knocks the enemy mostly upward and slightly along the hit, and
## flashes its model red before fading back to white.

const KNOCKBACK_LIFT := 20.0
const KNOCKBACK_DURATION := 0.15
const FLASH_IN_DURATION := 0.05
const FLASH_OUT_DURATION := 0.15

@export var hit_force: float = 1.0
@export var death_force: float = 10.0
@export var death_timeout: float = 2.0

@onready var _health: Health = $"../Health"
@onready var _model: EnemyModel = $"../Model"
@onready var _body: Enemy = $"../."


func _ready() -> void:
	_health.damaged.connect(_on_damage)
	_health.died.connect(_on_death)


func _on_damage(info: HitInfo) -> void:
	_knockback(info)
	_flash()


func _knockback(info: HitInfo) -> void:
	_body.apply_impulse(
		Impulse.new(
			(info.hit_direction + Vector3.UP * KNOCKBACK_LIFT).normalized() * hit_force,
			KNOCKBACK_DURATION,
		)
	)


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(
		_model.mesh,
		^"material_override:albedo_color",
		Color.RED,
		FLASH_IN_DURATION,
	)
	tween.tween_property(
		_model.mesh,
		^"material_override:albedo_color",
		Color.WHITE,
		FLASH_OUT_DURATION,
	)


func _on_death(info: HitInfo) -> void:
	var rg := DeathBody.new()
	get_tree().root.add_child(rg)

	rg.setup(_body, death_timeout)
	rg.apply_impulse(info.hit_direction * death_force, info.hit_point)
