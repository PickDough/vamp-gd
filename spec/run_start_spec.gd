extends SceneSpec


func spec() -> void:
	describe("Starting a run", func() -> void:
		it("leaves the main menu for the letter A map with the player standing on it", func() -> void:
			await start_scene(MAIN_SCENE)
			var menu := find(MainMenu)
			await click(find(Button, "Play") as Button)

			var run_started := func() -> bool: return find(Run) != null
			if not await wait_until(run_started, "a run replaces the main menu", 2.0):
				return
			await tree.process_frame
			expect(is_instance_valid(menu)).to(be_false())

			var run := find(Run) as Run
			var map := run.map
			expect(letter_shown(map)).to(eq("A"))

			var player := await wait_for_player(run)
			if player == null:
				return
			var region := map.navigation_region.get_rid()
			var on_nav_mesh := NavigationServer3D.region_get_closest_point(region, player.global_position)
			expect(on_nav_mesh.distance_to(player.global_position)).to(be_less_than(NAV_MESH_TOLERANCE))

			var camera := tree.root.get_camera_3d()
			expect(camera).to(eq(TreeQuery.find_under(player, Camera3D)))
			await hold(&"ui_right", 0.5)
			await wait_seconds(1.0)
			expect(camera.global_position.distance_to(player.global_position)).to(be_less_than(15.0))
		)
	)
