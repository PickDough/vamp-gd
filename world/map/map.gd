@tool
class_name Map
extends Node3D

## A walkable letter. Builds the letter's mesh, collision and navigation, then offers the player a spawn point
## away from the letter's edges.

signal ready_for_player(spawn_point: Vector3)

const SCENE_PATH := "res://world/map/map.tscn"
const FONT_SIZE := 64
const PIXEL_SIZE := 4.0
const DEPTH := 12.0
const SPAWN_EDGE_INSET := 2.0
const SPAWN_PICK_ATTEMPTS := 24

var letter: String = "A"

@onready var navigation_region: SyncedNavigationRegion = $NavigationRegion3D
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var _text_mesh: MeshInstance3D = $NavigationRegion3D/TextMesh
@onready var _voxel_gi: VoxelGI = $VoxelGI


static func new_from_letter(map_letter: String) -> Map:
	var map := (load(SCENE_PATH) as PackedScene).instantiate() as Map
	map.letter = map_letter
	return map


func _ready() -> void:
	_text_mesh.mesh = _create_letter_mesh()
	if Engine.is_editor_hint():
		return

	_text_mesh.create_trimesh_collision()
	_voxel_gi.bake.call_deferred()
	navigation_region.navigation_ready.connect(_on_navigation_ready)
	navigation_region.rebake()


func _create_letter_mesh() -> TextMesh:
	var mesh := TextMesh.new()
	mesh.text = letter
	mesh.font_size = FONT_SIZE
	mesh.pixel_size = PIXEL_SIZE
	mesh.depth = DEPTH
	return mesh


func _on_navigation_ready() -> void:
	var region := navigation_region.get_rid()
	var layers := navigation_region.navigation_layers
	ready_for_player.emit(NavPoints.random_inset(region, layers, SPAWN_EDGE_INSET, SPAWN_PICK_ATTEMPTS))
