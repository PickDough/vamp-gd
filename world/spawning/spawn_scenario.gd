class_name SpawnScenario
extends Resource

## One phase of enemy spawning: from start_time on, which enemies spawn, how many per tick, how many may be alive
## at once and how far from the player they appear.

@export var start_time: float = 0.0
@export var radius_around_player: float = 100.0
@export var amount_per_tick: float = 1.0
@export var max_enemies: int = 10
@export var enemy_scenes: Array[PackedScene] = []


static func active_at(scenarios: Array[SpawnScenario], time: float) -> SpawnScenario?:
	var active: SpawnScenario? = null
	for scenario in scenarios:
		if scenario.start_time <= time and (active == null or scenario.start_time >= active.start_time):
			active = scenario

	return active


func random_enemy_scene() -> PackedScene:
	return enemy_scenes[AutoloadGame.rng.randi_range(0, enemy_scenes.size() - 1)]
