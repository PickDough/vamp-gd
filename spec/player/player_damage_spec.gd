extends SceneSpec

const CONTACT_TIMEOUT := 5.0
const KNOCKBACK_SECONDS := 0.3
const MIN_KNOCKBACK := 0.5
const LAND_TIMEOUT := 2.0
const FALL_TIMEOUT := 5.0
const LATER_MINUTE_START := 120.0
const OFF_MAP_OFFSET := Vector3(1000.0, 0.0, 0.0)


func spec() -> void:
	describe(
		"Player under attack",
		func() -> void:
			it(
				"is hurt by a touching enemy for the minute of the run, knocked away, flashed and briefly invulnerable",
				func() -> void:
					var run := await start_run("A")
					var player := run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					clear_enemies(run)
					var health := TreeQuery.find_under(player, Health) as Health
					var timer := TreeQuery.find_under(player, Timer, "InvulnerabilityTimer") as Timer
					var region := run.map.navigation_region.get_rid()
					var start := NavigationServer3D.region_get_closest_point(
							region,
							player.global_position + Vector3.RIGHT * 4.0,
					)
					var enemy := spawn_enemy(start, true)
					var damage := float(run.score.current_minute)

					var overlay := (TreeQuery.find_under(player, MeshInstance3D) as MeshInstance3D).material_overlay
					var flash_opacities: Array[float] = []
					var record_flash := func() -> void:
						flash_opacities.append((overlay as StandardMaterial3D).albedo_color.a)
					tree.process_frame.connect(record_flash)

					var hurt := func() -> bool: return health.current < health.max_health
					if not await wait_until(hurt, "the enemy reaches and hurts the player", CONTACT_TIMEOUT):
						return
					expect(health.current).to(eq(health.max_health - damage))
					expect(player.is_invulnerable).to(be_true())
					var hit_distance := horizontal_distance(player, enemy)

					await wait_seconds(KNOCKBACK_SECONDS)
					expect(horizontal_distance(player, enemy) - hit_distance).to(be_greater_than(MIN_KNOCKBACK))
					if not await wait_until(player.is_on_floor, "the player lands after the knockback", LAND_TIMEOUT):
						return
					tree.process_frame.disconnect(record_flash)
					expect(flash_opacities.max()).to(be_greater_than(0.0))
					expect((overlay as StandardMaterial3D).albedo_color.a).to(be_close_to(0.0, 0.01))

					var hurt_again := func() -> bool: return health.current < health.max_health - damage
					var window := timer.wait_time
					var almost_over := func() -> bool: return timer.time_left < KNOCKBACK_SECONDS
					if not await wait_until(almost_over, "the invulnerability is about to end", window):
						return
					expect(health.current).to(eq(health.max_health - damage))
					run.score.time_playing = LATER_MINUTE_START
					var later_damage := float(run.score.current_minute)
					if not await wait_until(hurt_again, "the enemy hurts the player again", CONTACT_TIMEOUT):
						return
					expect(later_damage).to(be_greater_than(damage))
					expect(health.current).to(eq(health.max_health - damage - later_damage)),
			)

			it(
				"dies when its health runs out, which finishes the run and brings back the main menu",
				func() -> void:
					await start_scene(MAIN_SCENE)
					await click(find(Button, "Play") as Button)
					var run_started := func() -> bool: return find(Run) != null
					if not await wait_until(run_started, "a run replaces the main menu", 2.0):
						return
					var run := find(Run) as Run
					var player := await wait_for_player(run)
					if player == null:
						return
					clear_enemies(run)
					var finished: Array[bool] = [false]
					run.finished.connect(func() -> void: finished[0] = true)
					var health := TreeQuery.find_under(player, Health) as Health

					player.take_hit(HitInfo.new(health.max_health))
					expect(health.current).to(be_lte(0.0))
					expect(finished[0]).to(be_true())
					expect(player.is_physics_processing()).to(be_false())

					var menu_back := func() -> bool: return find(MainMenu) != null and find(Run) == null
					await wait_until(menu_back, "the main menu replaces the finished run", 2.0),
			)

			it(
				"dies after falling too far off the map, which finishes the run",
				func() -> void:
					var run := await start_run("A")
					var player := run.player
					if player == null:
						return
					clear_enemies(run)
					var finished: Array[bool] = [false]
					run.finished.connect(func() -> void: finished[0] = true)
					var health := TreeQuery.find_under(player, Health) as Health
					var start_height := player.global_position.y

					player.global_position += OFF_MAP_OFFSET
					var run_finished := func() -> bool: return finished[0]
					if not await wait_until(run_finished, "the falling player dies", FALL_TIMEOUT):
						return
					expect(health.current).to(be_lte(0.0))
					expect(start_height - player.global_position.y).to(be_greater_than(player.fall_death_distance)),
			)
	)
