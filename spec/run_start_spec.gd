extends SceneSpec

const CAMERA_DRIFT := 1.0
const CAMERA_SETTLED := 0.01


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
			var map: Map = run.map
			expect(letter_shown(map)).to(eq("A"))

			var player := await wait_for_player(run)
			if player == null:
				return
			var region: RID = map.navigation_region.get_rid()
			var on_nav_mesh := NavigationServer3D.region_get_closest_point(region, player.global_position)
			expect(on_nav_mesh.distance_to(player.global_position)).to(be_less_than(NAV_MESH_TOLERANCE))

			var camera := tree.root.get_camera_3d()
			expect(camera).to(eq(TreeQuery.find_under(player, Camera3D)))
			var last_distance: Array[float] = [INF]
			var camera_settled := func() -> bool:
				var distance := camera.global_position.distance_to(player.global_position)
				var settled := absf(distance - last_distance[0]) < CAMERA_SETTLED
				last_distance[0] = distance
				return settled
			if not await wait_until(camera_settled, "the camera settles behind the player", 5.0):
				return
			var resting_distance := last_distance[0]
			await hold(&"ui_right", 0.5)
			await wait_seconds(1.0)
			expect(camera.global_position.distance_to(player.global_position)).to(
					be_close_to(resting_distance, CAMERA_DRIFT),
			)
		)
	)
