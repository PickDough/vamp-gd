trait_name Damageable
extends Node

## Something attacks can hurt. Adopters route hits to their own Health.

@onready var _health: Health = $"Health"


func take_hit(hit: HitInfo) -> void:
	_health.apply(hit)
