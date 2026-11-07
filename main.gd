class_name Main
extends Node

## Root of the game. Shows the main menu and starts runs; the only code that changes screens.

const MAIN_MENU_SCENE_PATH := "res://ui/screens/main_menu/main_menu.tscn"
const RUN_SCENE_PATH := "res://run/run.tscn"

var _screen: Node? = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_main_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_main_menu() -> void:
	var menu := (load(MAIN_MENU_SCENE_PATH) as PackedScene).instantiate() as MainMenu
	menu.play_pressed.connect(_start_run)
	_show(menu)


func _start_run(letter: String) -> void:
	var run := (load(RUN_SCENE_PATH) as PackedScene).instantiate() as Run
	run.letter = letter
	_show(run)


func _show(screen: Node) -> void:
	var previous := _screen
	if previous != null:
		previous.queue_free()
	_screen = screen
	add_child(screen)
