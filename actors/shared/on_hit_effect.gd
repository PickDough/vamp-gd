class_name OnHitEffect
extends Node

## Reacts to its owner's Health taking damage: knocks the owner along the hit and lifted by knockback_lift, and
## flashes it red before fading back to white. The owner is its parent, which uses HitReactive and has a Health
## child. Death is the owner's business.

const FLASH_IN_DURATION := 0.05
const FLASH_OUT_DURATION := 0.15

@export var hit_force: float = 1.0
@export var knockback_lift: float = 20.0
@export var knockback_duration: float = 0.15

@onready var _health: Health = $"../Health"
@onready var _body: HitReactive = $".."


func _ready() -> void:
	_health.damaged.connect(_on_damage)


func _on_damage(info: HitInfo) -> void:
	_knockback(info)
	_flash()


func _knockback(info: HitInfo) -> void:
	var direction := (info.hit_direction + Vector3.UP * knockback_lift).normalized()
	_body.apply_impulse(Impulse.new(direction * hit_force, knockback_duration))


func _flash() -> void:
	var tween := create_tween()
	tween.tween_method(_body.show_tint, Color.WHITE, Color.RED, FLASH_IN_DURATION)
	tween.tween_method(_body.show_tint, Color.RED, Color.WHITE, FLASH_OUT_DURATION)
