extends SceneSpec

const DROP_HEIGHT := 6.0
const LAND_TIMEOUT := 5.0
const CHASE_CHECK_SECONDS := 1.0
const FLOOR_EPSILON := 0.01


func spec() -> void:
	describe(
		"Falling enemy",
		func() -> void:
			it(
				"falls faster the longer it is in the air without walking, then lands and chases",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					var region: RID = run.map.navigation_region.get_rid()
					var ground := NavigationServer3D.region_get_closest_point(
							region,
							player.global_position + Vector3.RIGHT * 8.0,
					)
					var enemy := spawn_enemy(ground + Vector3.UP * DROP_HEIGHT, true)
					var drop_point := enemy.global_position

					var heights: Array[float] = []
					var horizontal_drift: Array[float] = []
					var landed := func() -> bool:
						heights.append(enemy.global_position.y)
						var offset := enemy.global_position - drop_point
						horizontal_drift.append(Vector2(offset.x, offset.z).length())
						return enemy.global_position.y <= ground.y + FLOOR_EPSILON
					if not await wait_until(landed, "the enemy lands", LAND_TIMEOUT):
						return

					var fall_speeds: Array[float] = []
					for index in range(1, heights.size() - 1):
						fall_speeds.append(heights[index - 1] - heights[index])
					expect(fall_speeds.size()).to(be_greater_than(2))
					var speeds_grow := true
					for index in range(1, fall_speeds.size()):
						speeds_grow = speeds_grow and fall_speeds[index] > fall_speeds[index - 1]
					expect(speeds_grow).to(be_true())
					expect(horizontal_drift.max()).to(be_less_than(0.01))
					expect(enemy.global_position.y).to(be_close_to(ground.y, NAV_MESH_TOLERANCE))

					var landed_distance := horizontal_distance(enemy, player)
					await wait_seconds(CHASE_CHECK_SECONDS)
					expect(horizontal_distance(enemy, player)).to(be_less_than(landed_distance)),
			),
	)
