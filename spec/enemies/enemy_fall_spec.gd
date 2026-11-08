extends SceneSpec

const DROP_HEIGHT := 6.0
const LAND_TIMEOUT := 5.0
const CHASE_CHECK_SECONDS := 1.0


func spec() -> void:
	describe(
		"Falling enemy",
		func() -> void:
			it(
				"falls faster the longer it is in the air without walking, then lands and chases",
				func() -> void:
					var run := await start_run("A")
					var player := run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					var region := run.map.navigation_region.get_rid()
					var ground := NavigationServer3D.region_get_closest_point(
							region,
							player.global_position + Vector3.RIGHT * 8.0,
					)
					var enemy := spawn_enemy(ground + Vector3.UP * DROP_HEIGHT, player)
					var drop_point := enemy.global_position

					var fall_speeds: Array[float] = []
					var horizontal_drift: Array[float] = []
					var landed := func() -> bool:
						if not enemy.is_on_floor() and enemy.velocity.y < 0.0:
							fall_speeds.append(-enemy.velocity.y)
							var offset := enemy.global_position - drop_point
							horizontal_drift.append(Vector2(offset.x, offset.z).length())
						return enemy.is_on_floor()
					if not await wait_until(landed, "the enemy lands", LAND_TIMEOUT):
						return

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
