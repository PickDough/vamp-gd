class_name EnemySpawner
extends Node3D

## Spawns enemies around the player on the navigation mesh, following the spawn scenario whose start time passed
## most recently, and registers them with its Hive. Fresh spawns keep min_spawn_distance away, outside the
## player's immediate attack range.

const PICK_ATTEMPTS := 16

@export var spawn_scenarios: Array[SpawnScenario] = []
@export var tick_interval_seconds: float = 1.0
@export var sub_ticks_per_tick: int = 3
@export var min_spawn_distance: float = 10.0

var time_since_start: float = 0.0

var _spawn_carry: float = 0.0
var _player: Node3D? = null
var _navigation_region_rid: RID

@onready var hive: Hive = $Hive

@onready var _tick_timer: Timer = $TickTimer


func _ready() -> void:
	_tick_timer.wait_time = tick_interval_seconds / sub_ticks_per_tick
	_tick_timer.timeout.connect(_on_tick)
	_tick_timer.start()


func _process(delta: float) -> void:
	time_since_start += delta


func setup(player: Node3D, navigation_region: NavigationRegion3D) -> void:
	_player = player
	_navigation_region_rid = navigation_region.get_rid()
	hive.setup(navigation_region.get_navigation_map(), player)


func spawn(scene: PackedScene, spawn_point: Vector3, chases: bool = true) -> Enemy:
	var enemy := scene.instantiate() as Enemy
	add_child(enemy)
	hive.register(enemy, spawn_point, chases)
	return enemy


func _on_tick() -> void:
	var scenario := SpawnScenario.active_at(spawn_scenarios, time_since_start)
	var player := _player
	if scenario == null or player == null or not is_instance_valid(player) or scenario.enemy_scenes.is_empty():
		return

	_spawn_carry += scenario.amount_per_tick / sub_ticks_per_tick
	while _spawn_carry >= 1.0:
		_spawn_carry -= 1.0
		_spawn_one(scenario, player)


func _spawn_one(scenario: SpawnScenario, player: Node3D) -> void:
	if hive.count >= scenario.max_enemies:
		_spawn_carry = 0.0
		return

	var spawn_point: Vector3? = NavPoints.around(
			_navigation_region_rid, player.global_position,
			min_spawn_distance, scenario.radius_around_player, PICK_ATTEMPTS,
	)
	if spawn_point != null:
		spawn(scenario.random_enemy_scene(), spawn_point)
