class_name SkillStats
extends Resource

## Tunable numbers for a skill; each skill reads the ones it uses. Speed and area are multipliers, cooldown is in
## seconds, count is targets per cast and target_range is how far away targets can be. Rolls the hits the skill
## deals, including critical ones.

@export var damage: float = 1.0
@export var speed: float = 1.0
@export var area: float = 1.0
@export var cooldown: float = 1.0
@export_range(0.0, 1.0) var critical_chance: float = 0.0
@export var critical_multiplier: float = 1.0
@export var count: int = 1
@export var target_range: float = 1.0


func roll_hit() -> HitInfo:
	var is_critical := AutoloadGame.rng.randf() < critical_chance
	return HitInfo.new(damage * (critical_multiplier if is_critical else 1.0), is_critical)
