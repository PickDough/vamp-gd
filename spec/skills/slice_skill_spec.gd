extends SceneSpec

const SLICE_ACTION_SCENE := "res://skills/slice/slice_action.tscn"
const FLOOR_EPSILON := 0.01


func spec() -> void:
	describe(
		"Slice skill",
		func() -> void:
			it(
				"cuts the nearest enemies in range once per cast, then moves on to the next one",
				func() -> void:
					var run := await start_run("A")
					var map: Map = run.map
					var player: PlayerBody = run.player
					if player == null:
						return
					clear_enemies(run)
					var skill := TreeQuery.find_under(player, SliceSkill) as SliceSkill
					skill.stats.critical_chance = 0.0
					var count := skill.stats.count
					var slice_range: float = skill.stats.target_range
					var damage: float = skill.stats.damage
					var region: RID = map.navigation_region.get_rid()
					var in_range: Array[Enemy] = []
					for i in count + 1:
						var angle := i * TAU / (count + 1)
						var distance := lerpf(0.25, 0.75, float(i) / count) * slice_range
						var offset := Vector3(cos(angle), 0.0, sin(angle)) * distance
						var ground := NavigationServer3D.region_get_closest_point(
								region,
								player.global_position + offset,
						)
						in_range.append(spawn_enemy(ground))
					in_range.sort_custom(
						func(a: Enemy, b: Enemy) -> bool:
							var origin := skill.global_position
							return a.global_position.distance_to(origin) < b.global_position.distance_to(origin),
					)
					var out_of_range := spawn_enemy(_nav_point_beyond(map, player, slice_range * 1.5))
					var nearest := in_range.slice(0, count)
					var next := in_range[count]
					var full_health: float = health_of(next).max_health

					var nearest_cut := func() -> bool:
						return nearest.all(
							func(enemy: Enemy) -> bool:
								return health_of(enemy).current < full_health,
						)
					if not await wait_until(nearest_cut, "the %d nearest enemies are cut" % count, _cast_window(skill)):
						return
					expect(
						nearest.map(
							func(enemy: Enemy) -> float:
								return health_of(enemy).current,
						)
					).to(all(eq(full_health - damage)))
					expect(health_of(next).current).to(eq(full_health))
					expect(health_of(out_of_range).current).to(eq(full_health))

					var hits_to_kill := ceili(full_health / damage)
					var nearest_dead := func() -> bool:
						return nearest.all(
							func(enemy: Variant) -> bool:
								return not is_instance_valid(enemy),
						)
					var kill_time := _cast_window(skill) * hits_to_kill
					if not await wait_until(nearest_dead, "the nearest enemies die", kill_time):
						return
					expect(health_of(next).current).to(eq(full_health))

					var next_cut := func() -> bool:
						return health_of(next).current < full_health
					if not await wait_until(next_cut, "the next enemy in range is cut", _cast_window(skill)):
						return
					expect(health_of(out_of_range).current).to(eq(full_health))

					var slices_freed := func() -> bool:
						return TreeQuery.find_under(skill, SliceAction) == null
					await wait_until(slices_freed, "every slice frees itself after its animation", 2.0),
			)

			it(
				"kills an enemy with a single critical cut, drawn in the critical color",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					clear_enemies(run)
					var skill := TreeQuery.find_under(player, SliceSkill) as SliceSkill
					skill.stats.critical_chance = 1.0
					var slice_range: float = skill.stats.target_range

					var enemy := spawn_enemy(player.global_position + Vector3.RIGHT * slice_range * 0.5)
					var full_health: float = health_of(enemy).max_health
					skill.stats.damage = full_health / skill.stats.critical_multiplier

					var enemy_ref: WeakRef = weakref(enemy)
					var slices_in_critical_color: Array[bool] = []
					var cut := func() -> bool:
						for slice: SliceAction in skill.find_children("*", "SliceAction", false, false):
							var mesh := TreeQuery.find_under(slice, MeshInstance3D) as MeshInstance3D
							var material := mesh.get_active_material(0) as StandardMaterial3D
							slices_in_critical_color.append(material.albedo_color == slice.critical_color)
						var living: Object = enemy_ref.get_ref()
						return living == null or health_of(living as Enemy).current < full_health
					if not await wait_until(cut, "the enemy is cut", _cast_window(skill)):
						return
					await tree.process_frame
					expect(enemy_ref.get_ref()).to(be_null())
					expect(slices_in_critical_color).not_to(be_empty())
					expect(slices_in_critical_color).to(all(be_true())),
			)

			it(
				"lands each slice on its target, sized by AREA, striking away from the player, nearer targets first",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					clear_enemies(run)
					var skill := TreeQuery.find_under(player, SliceSkill) as SliceSkill
					skill.stats.critical_chance = 0.0
					var slice_range: float = skill.stats.target_range
					var area: float = skill.stats.area
					var travel_speed: float = skill.base_travel_speed * skill.stats.speed

					var region: RID = run.map.navigation_region.get_rid()
					var near_point := player.global_position + Vector3.RIGHT * slice_range * 0.25
					var far_point := player.global_position + Vector3.FORWARD * slice_range * 0.9
					var near := spawn_enemy(NavigationServer3D.region_get_closest_point(region, near_point))
					var far := spawn_enemy(NavigationServer3D.region_get_closest_point(region, far_point))
					var full_health: float = health_of(near).max_health
					var extra_distance := horizontal_distance(far, player) - horizontal_distance(near, player)

					var template := (load(SLICE_ACTION_SCENE) as PackedScene).instantiate()
					var base_box_size: Vector3 = (template as SliceAction).hitbox_size
					var base_mesh_scale := (TreeQuery.find_under(template, MeshInstance3D) as MeshInstance3D).scale
					template.free()

					var slices: Array[Node3D] = []
					var swung: Array[Node3D] = []
					var cut_on_frame: Dictionary[Enemy, int] = {}
					var both_cut := func() -> bool:
						for slice: Node3D in skill.find_children("*", "SliceAction", false, false):
							if slice not in slices:
								if slices.is_empty():
									press(&"ui_left")
								slices.append(slice)
								var to_near := slice.global_position.distance_to(near.global_position)
								var to_far := slice.global_position.distance_to(far.global_position)
								expect(minf(to_near, to_far)).to(be_less_than(0.1))
								var box_size: Vector3 = (slice as SliceAction).scaled_hitbox_size
								expect(box_size.is_equal_approx(base_box_size * area)).to(be_true())
								var mesh := TreeQuery.find_under(slice, MeshInstance3D) as MeshInstance3D
								expect(mesh.scale.is_equal_approx(base_mesh_scale * area)).to(be_true())
								var material := mesh.get_active_material(0) as StandardMaterial3D
								expect(material.albedo_color).not_to(eq((slice as SliceAction).critical_color))
							if slice.visible and slice not in swung:
								if swung.is_empty():
									release(&"ui_left")
								swung.append(slice)
								var away_from_player := (slice.global_position - player.global_position).normalized()
								var forward := (-slice.global_basis.z).normalized()
								expect(forward.dot(away_from_player)).to(be_greater_than(0.99))
						for enemy: Enemy in [near, far]:
							if enemy not in cut_on_frame and health_of(enemy).current < full_health:
								cut_on_frame[enemy] = Engine.get_physics_frames()
						return cut_on_frame.size() == 2
					if not await wait_until(both_cut, "both enemies are cut", _cast_window(skill)):
						return

					expect(slices).to(have_size(2))
					expect(swung).to(have_size(2))
					var frames_between := cut_on_frame[far] - cut_on_frame[near]
					var seconds_between := frames_between * TIME_SCALE / Engine.physics_ticks_per_second
					var expected_delay := extra_distance / travel_speed
					expect(seconds_between).to(be_between(expected_delay * 0.5, expected_delay * 1.5)),
			)

			it(
				"knocks the cut enemy up and away from the player",
				func() -> void:
					var run := await start_run("A")
					var player: PlayerBody = run.player
					if player == null:
						return
					clear_enemies(run)
					var skill := TreeQuery.find_under(player, SliceSkill) as SliceSkill
					skill.stats.critical_chance = 0.0
					var region: RID = run.map.navigation_region.get_rid()
					var ground := NavigationServer3D.region_get_closest_point(
							region,
							player.global_position + Vector3.RIGHT * skill.stats.target_range * 0.5,
					)
					var enemy := spawn_enemy(ground)
					var start := enemy.global_position
					var start_distance := horizontal_distance(enemy, player)
					var full_health: float = health_of(enemy).max_health

					var heights: Array[float] = []
					var cut := func() -> bool:
						heights.append(enemy.global_position.y)
						return health_of(enemy).current < full_health
					if not await wait_until(cut, "the enemy is cut", _cast_window(skill)):
						return
					var airborne := func() -> bool:
						heights.append(enemy.global_position.y)
						return enemy.global_position.y > start.y + FLOOR_EPSILON
					if not await wait_until(airborne, "the cut enemy leaves the floor", 1.0):
						return
					var landed := func() -> bool:
						heights.append(enemy.global_position.y)
						return enemy.global_position.y <= start.y + FLOOR_EPSILON
					if not await wait_until(landed, "the enemy lands after the cut", 5.0):
						return

					expect(heights.max()).to(be_greater_than(start.y))
					expect(horizontal_distance(enemy, player)).to(be_greater_than(start_distance)),
			),
	)


func _cast_window(skill: SliceSkill) -> float:
	var travel_speed: float = skill.base_travel_speed * skill.stats.speed
	return skill.stats.cooldown + skill.stats.target_range / travel_speed + 1.0


func _nav_point_beyond(map: Map, player: PlayerBody, min_distance: float) -> Vector3:
	var region: RID = map.navigation_region.get_rid()
	while true:
		var point := NavigationServer3D.region_get_random_point(region, 1, true)
		if Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > min_distance:
			return point
	return Vector3.ZERO
