extends Node

## Measures how a run holds up under a crowd: starts a run on the letter A, removes the player's skills so nothing
## dies, spawns `--count` chasing enemies on random nav mesh points and, after a warm-up, records frame times and
## the physics tick rate actually reached. Prints one BENCH line and quits. Run it headless:
##
##     Redot --headless --path . res://tools/bench/enemy_bench.tscn -- --count 2000
##
## Headless skips rendering, so the numbers cover simulation and scene-tree cost only.

const RUN_SCENE_PATH := "res://run/run.tscn"
const ENEMY_SCENE_PATH := "res://actors/enemies/enemy_a.tscn"
const DEFAULT_COUNT := 1000
const WARM_UP_SECONDS := 3.0
const MEASURE_SECONDS := 6.0
const UNHARMED_HEALTH := 1_000_000_000.0
const MICROSECONDS_PER_MILLISECOND := 1000.0
const MILLISECONDS_PER_SECOND := 1000.0
const REPORT_FORMAT := (
	"BENCH count=%d fps=%.1f avg_ms=%.2f p95_ms=%.2f physics_tps=%.1f physics_step_ms=%.2f process_ms=%.2f"
)

var _frame_times: Array[float] = []
var _physics_step_times: Array[float] = []
var _process_times: Array[float] = []


func _ready() -> void:
	var run := (load(RUN_SCENE_PATH) as PackedScene).instantiate() as Run
	add_child(run)
	while run.player == null or not (run.player as PlayerBody).is_on_floor():
		await get_tree().physics_frame

	_prepare(run, run.player as PlayerBody)
	_spawn_crowd(run, _requested_count())
	await get_tree().create_timer(WARM_UP_SECONDS, true, false, true).timeout
	await _measure()
	get_tree().quit()


func _requested_count() -> int:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--count")
	return args[index + 1].to_int() if index >= 0 and index + 1 < args.size() else DEFAULT_COUNT


func _prepare(run: Run, player: PlayerBody) -> void:
	for skill in TreeQuery.find_under(player, Node3D, "Skills").get_children():
		skill.free()
	var health := TreeQuery.find_under(player, Health) as Health
	health.max_health = UNHARMED_HEALTH
	health.current = UNHARMED_HEALTH
	var spawner := run.map.enemy_spawner
	(spawner.get_node("TickTimer") as Timer).stop()
	for enemy in spawner.find_children("*", "Enemy", false, false):
		enemy.free()


func _spawn_crowd(run: Run, count: int) -> void:
	var region := run.map.navigation_region.get_rid()
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	for index in count:
		var point := NavigationServer3D.region_get_random_point(region, 1, true)
		run.map.enemy_spawner.spawn(scene, point)


func _measure() -> void:
	var start_physics_frames := Engine.get_physics_frames()
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < MEASURE_SECONDS * 1_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		_frame_times.append((now - last) / MICROSECONDS_PER_MILLISECOND)
		_process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * MILLISECONDS_PER_SECOND)
		_physics_step_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * MILLISECONDS_PER_SECOND)
		last = now

	var seconds := (Time.get_ticks_usec() - start) / 1_000_000.0
	_report(seconds, Engine.get_physics_frames() - start_physics_frames)


func _report(seconds: float, physics_frames: int) -> void:
	_frame_times.sort()
	var p95: float = _frame_times[floori(_frame_times.size() * 0.95)]
	var line := REPORT_FORMAT % [
		_requested_count(),
		_frame_times.size() / seconds,
		_mean(_frame_times),
		p95,
		physics_frames / seconds,
		_mean(_physics_step_times),
		_mean(_process_times),
	]
	print(line)  # lint-ignore: no-print


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()
