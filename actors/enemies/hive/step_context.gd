struct_name StepContext:
## What every enemy shares in one hive step: the frame's time, the world and the player's position.
	var delta: float
	var tick: int
	var path_refresh_interval: float
	var navigation_map: RID
	var gravity: Vector3
	var target_position: Vector3
	var has_target: bool
	var grid: SpatialGrid
