class_name Run
extends Node3D

## One play session: builds the map for a letter, spawns the player on it and wires the systems together.

const PLAYER_SCENE_PATH := "res://actors/player/player_body.tscn"

@export var letter: String = "A"

var map: Map
var player: PlayerBody? = null


func _ready() -> void:
	map = Map.new_from_letter(letter)
	map.ready_for_player.connect(_on_map_ready_for_player)
	add_child(map)


func _on_map_ready_for_player(spawn_point: Vector3) -> void:
	var new_player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerBody
	add_child(new_player)
	new_player.global_position = spawn_point
	player = new_player
	map.enemy_spawner.setup(new_player, map.navigation_region)
