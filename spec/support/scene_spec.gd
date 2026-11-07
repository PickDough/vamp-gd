class_name SceneSpec
extends GSpec

## Base for end-to-end specs that drive real scenes. Each example makes its own scene the current scene; after it
## the scene is freed, held input is released and the gspec runner becomes the current scene again.
##
## Game time runs TIME_SCALE times faster while a spec waits. Scenes are added a frame late because the gspec
## runner starts specs from its own _ready, while the root is still busy. Clicks wait for the first layout pass
## and are sent in window coordinates, which the stretch mode scales away from canvas coordinates. Inside the
## editor (the GSpec panel) every example fails at once, because the editor doesn't run game scripts.

const MAIN_SCENE := "res://main.tscn"
const RUN_SCENE := "res://run/run.tscn"
const ENEMY_A_SCENE := "res://actors/enemies/enemy_a.tscn"
const TIME_SCALE := 4.0
const PLAYER_SPAWN_TIMEOUT := 10.0
const NAV_MESH_TOLERANCE := 1.0
const EDITOR_RUN_MESSAGE := (
	"Scene specs need a running game; the editor doesn't run game scripts. "
	+ "Run res://addons/gspec/runner.tscn with Run Current Scene (F6), or from the CLI."
)

var tree: SceneTree:
	get:
		return Engine.get_main_loop() as SceneTree

var _runner: Node
var _held_actions: Array[StringName] = []


func _init() -> void:
	super()
	after_each(_reset_world)


func it(description: String, block: Callable) -> void:
	super(description, _editor_guard(block))


func fit(description: String, block: Callable) -> void:
	super(description, _editor_guard(block))


func start_scene(path: String) -> Node:
	return await _change_scene((load(path) as PackedScene).instantiate())


func start_run(letter: String) -> Run:
	var run := (load(RUN_SCENE) as PackedScene).instantiate() as Run
	run.letter = letter
	await _change_scene(run)
	await wait_for_player(run)
	return run


func wait_for_player(run: Run) -> PlayerBody:
	var landed := func() -> bool:
		var player := run.player
		return player != null and player.is_on_floor()
	if not await wait_until(landed, "the player spawns and lands on the map", PLAYER_SPAWN_TIMEOUT):
		return null

	return run.player


func spawn_enemy(position: Vector3, target: Node3D? = null) -> Enemy:
	var enemy := (load(ENEMY_A_SCENE) as PackedScene).instantiate() as Enemy
	enemy.setup(target)
	tree.current_scene.add_child(enemy)
	enemy.global_position = position
	return enemy


func spawn_pinned_enemy(position: Vector3) -> Enemy:
	var enemy := spawn_enemy(position)
	enemy.set_physics_process(false)
	return enemy


func health_of(enemy: Enemy) -> Health:
	return TreeQuery.find_under(enemy, Health) as Health


func letter_shown(map: Map) -> String:
	var text_mesh := TreeQuery.find_under(map, MeshInstance3D, "TextMesh") as MeshInstance3D
	return (text_mesh.mesh as TextMesh).text


func horizontal_distance(a: Node3D, b: Node3D) -> float:
	var offset := a.global_position - b.global_position
	return Vector2(offset.x, offset.z).length()


func find(type: Variant, name: String? = null) -> Node?:
	return TreeQuery.find_under(tree.current_scene, type, name)


func find_all(root: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child in root.get_children():
		if is_instance_of(child, type):
			found.append(child)
		found.append_array(find_all(child, type))

	return found


func click(button: Button) -> void:
	await tree.process_frame
	var viewport := button.get_viewport()
	var center := viewport.get_final_transform() * button.get_global_rect().get_center()

	var hover := InputEventMouseMotion.new()
	hover.position = center
	hover.global_position = center
	viewport.push_input(hover)
	await tree.process_frame

	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		event.global_position = center
		viewport.push_input(event)
		await tree.process_frame


func hold(action: StringName, seconds: float) -> void:
	await tree.physics_frame
	press(action)
	await wait_seconds(seconds)
	release(action)


func press(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)


func release(action: StringName) -> void:
	Input.action_release(action)
	_held_actions.erase(action)


func tap(action: StringName) -> void:
	await tree.physics_frame
	Input.action_press(action)
	await tree.physics_frame
	Input.action_release(action)


func wait_seconds(seconds: float) -> void:
	Engine.time_scale = TIME_SCALE
	await tree.create_timer(seconds, true, true).timeout
	Engine.time_scale = 1.0


func wait_until(condition: Callable, description: String, timeout: float) -> bool:
	Engine.time_scale = TIME_SCALE
	var deadline := tree.create_timer(timeout, true, true)
	var met: bool = condition.call()
	while not met and deadline.time_left > 0.0:
		await tree.physics_frame
		met = condition.call()
	Engine.time_scale = 1.0

	if not met:
		_record_failure("Timed out after %.1fs waiting until %s" % [timeout, description])
	return met


func _editor_guard(block: Callable) -> Callable:
	if not Engine.is_editor_hint():
		return block

	return func() -> void: _record_failure(EDITOR_RUN_MESSAGE)


func _reset_world() -> void:
	if Engine.is_editor_hint():
		return

	for action in _held_actions:
		Input.action_release(action)
	_held_actions.clear()
	Engine.time_scale = 1.0

	var scene := tree.current_scene
	if scene != null and scene != _runner:
		scene.free()
	tree.current_scene = _runner
	await tree.process_frame


func _change_scene(node: Node) -> Node:
	if _runner == null:
		_runner = tree.current_scene

	await tree.process_frame
	tree.root.add_child(node)
	tree.current_scene = node
	return node
