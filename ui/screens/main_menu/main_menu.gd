class_name MainMenu
extends Control

## Title screen. Asks Main to start a run.

signal play_pressed(letter: String)

const DEFAULT_LETTER := "A"

@onready var _play_button: Button = $CenterContainer/Play


func _ready() -> void:
	_play_button.grab_focus()
	_play_button.pressed.connect(_on_play_button_pressed)


func _on_play_button_pressed() -> void:
	play_pressed.emit(DEFAULT_LETTER)
