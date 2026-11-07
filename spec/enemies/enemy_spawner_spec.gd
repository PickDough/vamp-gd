extends SceneSpec


func spec() -> void:
	describe("Enemy spawner", func() -> void:
		it("surrounds the idle player with enemies up to the limit and refills after kills", func() -> void:
			var run := await start_run("A")
			var map := run.map
			var player := run.player
			if player == null:
				return
			TreeQuery.find_under(player, SliceSkill).free()
			var spawner := run.map.enemy_spawner
			var scenario := spawner.spawn_scenarios[0]
			var spawn_points: Dictionary[Node, Vector3] = {}
			var record_spawn_points := func() -> void:
				for enemy: Node3D in find_all(spawner, Enemy):
					if not spawn_points.has(enemy):
						spawn_points[enemy] = enemy.global_position
			var enemy_count := func() -> int:
				record_spawn_points.call()
				return find_all(spawner, Enemy).size()
			var seconds_to_fill := scenario.max_enemies / scenario.amount_per_tick

			var first_spawned := func() -> bool: return enemy_count.call() > 0
			if not await wait_until(first_spawned, "the first enemy spawns", 2.0):
				return
			expect(enemy_count.call()).to(eq(1))

			var filled := func() -> bool: return enemy_count.call() >= scenario.max_enemies
			if not await wait_until(filled, "the spawner reaches its limit", seconds_to_fill * 1.5):
				return
			await wait_seconds(2.0)
			expect(enemy_count.call()).to(eq(scenario.max_enemies))

			var region := map.navigation_region.get_rid()
			var scene_path := func(scene: PackedScene) -> String: return scene.resource_path
			var allowed_scenes := scenario.enemy_scenes.map(scene_path)
			for enemy: Node3D in find_all(spawner, Enemy):
				var spawn_point := spawn_points[enemy]
				var offset := spawn_point - player.global_position
				var distance := Vector2(offset.x, offset.z).length()
				expect(distance).to(be_between(EnemySpawner.MIN_SPAWN_DISTANCE, scenario.radius_around_player))
				var on_nav_mesh := NavigationServer3D.region_get_closest_point(region, spawn_point)
				expect(on_nav_mesh.distance_to(spawn_point)).to(be_less_than(NAV_MESH_TOLERANCE))
				expect(allowed_scenes).to(include(enemy.scene_file_path))

			for enemy: Enemy in find_all(spawner, Enemy).slice(0, 3):
				enemy.take_hit(HitInfo.new(health_of(enemy).current, false))
			await tree.process_frame
			expect(enemy_count.call()).to(eq(scenario.max_enemies - 3))
			var refill_time := 3.0 / scenario.amount_per_tick * 1.5
			if not await wait_until(filled, "the spawner refills to its limit", refill_time):
				return
		)

		it("switches to the next scenario once its start time passes", func() -> void:
			var run := await start_run("A")
			var map := run.map
			var player := run.player
			if player == null:
				return
			TreeQuery.find_under(player, SliceSkill).free()
			var spawner := run.map.enemy_spawner

			var opening := spawner.spawn_scenarios[0].duplicate() as SpawnScenario
			opening.max_enemies = 3
			var later := spawner.spawn_scenarios[0].duplicate() as SpawnScenario
			later.max_enemies = 6
			later.start_time = spawner.time_since_start + 6.0
			spawner.spawn_scenarios = [opening, later]

			var count := func() -> int: return find_all(spawner, Enemy).size()
			var opening_filled := func() -> bool: return count.call() >= opening.max_enemies
			var opening_fill_time := 4.0 / opening.amount_per_tick
			if not await wait_until(opening_filled, "the opening scenario reaches its limit", opening_fill_time):
				return
			await wait_seconds(1.0)
			expect(count.call()).to(eq(opening.max_enemies))

			var later_filled := func() -> bool: return count.call() >= later.max_enemies
			if not await wait_until(later_filled, "the later scenario raises the limit", 10.0):
				return
			await wait_seconds(1.0)
			expect(count.call()).to(eq(later.max_enemies))
		)
	)
