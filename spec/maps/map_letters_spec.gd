extends SceneSpec

const LETTERS: Array[String] = ["A", "B", "O", "W"]


func spec() -> void:
	describe("Map for a letter", func() -> void:
		for letter in LETTERS:
			it("builds a walkable %s with the player standing on it" % letter, func() -> void:
				var run := await start_run(letter)
				var map := run.map
				var player := run.player
				if player == null:
					return

				expect(letter_shown(map)).to(eq(letter))
				expect(map.navigation_region.navigation_mesh.get_polygon_count()).to(be_greater_than(0))

				var region := map.navigation_region.get_rid()
				var on_nav_mesh := NavigationServer3D.region_get_closest_point(region, player.global_position)
				expect(on_nav_mesh.distance_to(player.global_position)).to(be_less_than(NAV_MESH_TOLERANCE))

				var landed_y := player.global_position.y
				await wait_seconds(1.0)
				expect(player.is_on_floor()).to(be_true())
				expect(player.global_position.y).to(be_close_to(landed_y, 0.05))
			)
	)
