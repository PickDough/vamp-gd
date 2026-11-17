extends SceneSpec

const ENEMY_COUNT := 300
const MIN_SPAWN_DISTANCE := 5.0
const CHASE_SECONDS := 2.0
const MIN_TRAVEL := 0.5


func spec() -> void:
	describe(
		"Hive",
		func() -> void:
			it(
				"moves every enemy of a crowd along the nav mesh across its worker buckets",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					clear_enemies(run)
					var region: RID = run.map.navigation_region.get_rid()

					var enemies: Array[Enemy] = []
					var starts: Array[Vector3] = []
					while enemies.size() < ENEMY_COUNT:
						var point := NavigationServer3D.region_get_random_point(region, 1, true)
						if _horizontal_distance_to(point, player) < MIN_SPAWN_DISTANCE:
							continue
						enemies.append(spawn_enemy(point, true))
						starts.append(point)
					await wait_seconds(CHASE_SECONDS)

					var travelled: Array[float] = []
					var heights_off_mesh: Array[float] = []
					for index in ENEMY_COUNT:
						var enemy := enemies[index]
						travelled.append(enemy.global_position.distance_to(starts[index]))
						var ground := NavigationServer3D.region_get_closest_point(region, enemy.global_position)
						heights_off_mesh.append(absf(enemy.global_position.y - ground.y))
					expect(travelled).to(all(be_greater_than(MIN_TRAVEL)))
					expect(heights_off_mesh).to(all(be_less_than(NAV_MESH_TOLERANCE))),
			),
	)


func _horizontal_distance_to(point: Vector3, node: Node3D) -> float:
	var offset := point - node.global_position
	return Vector2(offset.x, offset.z).length()
