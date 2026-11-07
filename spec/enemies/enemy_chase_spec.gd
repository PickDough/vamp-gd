extends SceneSpec

const REACH_DISTANCE := 1.5


func spec() -> void:
	describe("Enemy", func() -> void:
		it("chases the player along the nav mesh until it reaches them", func() -> void:
			var run := await start_run("A")
			var map := run.map
			var player := run.player
			if player == null:
				return
			TreeQuery.find_under(player, SliceSkill).free()
			var region := map.navigation_region.get_rid()
			var start := NavigationServer3D.region_get_closest_point(region, player.global_position + Vector3.RIGHT * 8)
			var enemy := spawn_enemy(start, player)

			var start_distance := horizontal_distance(enemy, player)
			await wait_seconds(1.0)
			expect(horizontal_distance(enemy, player)).to(be_less_than(start_distance))

			var reached := func() -> bool: return horizontal_distance(enemy, player) < REACH_DISTANCE
			if not await wait_until(reached, "the enemy reaches the player", 30.0):
				return
			expect(enemy.global_position.y).to(be_close_to(player.global_position.y, NAV_MESH_TOLERANCE))
		)
	)
