extends SceneSpec

const HIT_AMOUNT := 1.0
const LAND_TIMEOUT := 5.0
const FLASH_TIMEOUT := 1.0


func spec() -> void:
	describe(
		"Enemy hit",
		func() -> void:
			it(
				"is knocked up and along the hit, then lands back on the floor",
				func() -> void:
					var run := await start_run("A")
					var player := run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					var enemy := _spawn_on_floor_away_from(run, player)
					if not await wait_until(enemy.is_on_floor, "the enemy lands after spawning", LAND_TIMEOUT):
						return
					var start := enemy.global_position
					var full_health: float = health_of(enemy).max_health

					var heights: Array[float] = []
					var knocked_up := func() -> bool:
						heights.append(enemy.global_position.y)
						return not enemy.is_on_floor()
					(enemy as Damageable).take_hit(_hit_along(Vector3.RIGHT))
					if not await wait_until(knocked_up, "the enemy leaves the floor", FLASH_TIMEOUT):
						return

					var landed := func() -> bool:
						heights.append(enemy.global_position.y)
						return enemy.is_on_floor()
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
					var player := run.player
					if player == null:
						return
					TreeQuery.find_under(player, SliceSkill).free()
					var hit_enemy := _spawn_on_floor_away_from(run, player)
					var other_enemy := _spawn_on_floor_away_from(run, player, Vector3.LEFT)
					var hit_material := _model_material(hit_enemy)
					var other_material := _model_material(other_enemy)
					var base_color := hit_material.albedo_color

					var other_colors: Array[Color] = []
					var flashed := func() -> bool:
						other_colors.append(other_material.albedo_color)
						return hit_material.albedo_color != base_color
					(hit_enemy as Damageable).take_hit(_hit_along(Vector3.RIGHT))
					if not await wait_until(flashed, "the hit enemy changes color", FLASH_TIMEOUT):
						return
					expect(hit_material.albedo_color.r).to(be_greater_than(hit_material.albedo_color.g))

					var restored := func() -> bool:
						other_colors.append(other_material.albedo_color)
						return hit_material.albedo_color == base_color
					if not await wait_until(restored, "the hit enemy returns to its color", FLASH_TIMEOUT):
						return
					expect(other_colors).to(all(eq(base_color))),
			),
	)


func _spawn_on_floor_away_from(run: Run, player: PlayerBody, side: Vector3 = Vector3.RIGHT) -> Enemy:
	var region := run.map.navigation_region.get_rid()
	var position := NavigationServer3D.region_get_closest_point(region, player.global_position + side * 8.0)
	return spawn_enemy(position)


func _hit_along(direction: Vector3) -> HitInfo:
	var hit := HitInfo.new(HIT_AMOUNT, false)
	hit.hit_direction = direction
	return hit


func _model_material(enemy: Enemy) -> StandardMaterial3D:
	var model := TreeQuery.find_under(enemy, EnemyModel) as EnemyModel
	return model.mesh.material_override as StandardMaterial3D
