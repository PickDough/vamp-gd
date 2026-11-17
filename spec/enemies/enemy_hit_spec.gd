extends SceneSpec

const HIT_AMOUNT := 1.0
const LAND_TIMEOUT := 5.0
const FLASH_TIMEOUT := 1.0
const FLOOR_EPSILON := 0.01


func spec() -> void:
	describe(
		"Enemy hit",
		func() -> void:
			it(
				"is knocked up and along the hit, then lands back on the floor",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					clear_enemies(run)
					var enemy := _spawn_on_floor_away_from(run, player)
					var start := enemy.global_position
					var full_health: float = health_of(enemy).max_health

					var heights: Array[float] = []
					var knocked_up := func() -> bool:
						heights.append(enemy.global_position.y)
						return enemy.global_position.y > start.y + FLOOR_EPSILON
					enemy.take_hit(_hit_along(Vector3.RIGHT))
					if not await wait_until(knocked_up, "the enemy leaves the floor", FLASH_TIMEOUT):
						return

					var landed := func() -> bool:
						heights.append(enemy.global_position.y)
						return enemy.global_position.y <= start.y + FLOOR_EPSILON
					if not await wait_until(landed, "the enemy lands after the hit", LAND_TIMEOUT):
						return
					expect(heights.max()).to(be_greater_than(start.y))
					expect(enemy.global_position.x).to(be_greater_than(start.x))
					expect(enemy.global_position.y).to(be_close_to(start.y, NAV_MESH_TOLERANCE))
					expect(health_of(enemy).current).to(eq(full_health - HIT_AMOUNT)),
			)

			it(
				"flashes only the hit enemy, then returns to its own color",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					clear_enemies(run)
					var hit_enemy := _spawn_on_floor_away_from(run, player)
					var other_enemy := _spawn_on_floor_away_from(run, player, Vector3.LEFT)
					var base_color := hit_enemy.tint

					var hit_colors: Array[Color] = []
					var other_colors: Array[Color] = []
					var record_colors := func() -> void:
						hit_colors.append(hit_enemy.tint)
						other_colors.append(other_enemy.tint)
					tree.process_frame.connect(record_colors)
					hit_enemy.take_hit(_hit_along(Vector3.RIGHT))
					var is_flash_color := func(color: Color) -> bool: return color != base_color
					var flashed := func() -> bool: return hit_colors.any(is_flash_color)
					if not await wait_until(flashed, "the hit enemy changes color", FLASH_TIMEOUT):
						return
					var flash_color: Color = hit_colors.filter(is_flash_color)[0]
					expect(flash_color.r).to(be_greater_than(flash_color.g))

					var restored := func() -> bool: return hit_enemy.tint == base_color
					if not await wait_until(restored, "the hit enemy returns to its color", FLASH_TIMEOUT):
						return
					tree.process_frame.disconnect(record_colors)
					expect(other_colors).to(all(eq(base_color))),
			),
	)


func _spawn_on_floor_away_from(run: Run, player: PlayerBody, side: Vector3 = Vector3.RIGHT) -> Enemy:
	var region: RID = run.map.navigation_region.get_rid()
	var position := NavigationServer3D.region_get_closest_point(region, player.global_position + side * 8.0)
	return spawn_enemy(position)


func _hit_along(direction: Vector3) -> HitInfo:
	var hit := HitInfo.new()
	hit.amount = HIT_AMOUNT
	hit.hit_direction = direction
	return hit

