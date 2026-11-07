extends SceneSpec


func spec() -> void:
	describe("Player on the map", func() -> void:
		it("walks, turns to face where it goes, stops, and jumps back onto the floor", func() -> void:
			var run := await start_run("A")
			var player := run.player
			if player == null:
				return
			var start := player.global_position

			await hold(&"ui_right", 0.35)
			expect(player.global_position.x - start.x).to(be_greater_than(1.0))
			expect(absf(player.global_position.z - start.z)).to(be_less_than(0.1))
			expect(player.facing.dot(Vector3.RIGHT)).to(be_greater_than(0.9))

			var stopped_at := player.global_position
			await wait_seconds(0.25)
			expect(player.global_position.distance_to(stopped_at)).to(be_less_than(0.05))

			await hold(&"ui_left", 0.35)
			expect(player.global_position.x).to(be_close_to(start.x, 0.5))
			expect(player.facing.dot(Vector3.LEFT)).to(be_greater_than(0.9))

			var floor_y := player.global_position.y
			await tap(&"ui_accept")
			var airborne := func() -> bool: return player.global_position.y > floor_y + 0.5
			if not await wait_until(airborne, "the player rises off the floor", 1.0):
				return
			var landed := func() -> bool: return player.is_on_floor()
			if not await wait_until(landed, "the player lands back on the floor", 3.0):
				return
			expect(player.global_position.y).to(be_close_to(floor_y, 0.05))
		)
	)
