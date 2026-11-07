@tool
class_name SyncedNavigationRegion
extends NavigationRegion3D

## A navigation region that rebakes at runtime and reports when the navigation server answers from the new mesh.
## Until the region's next sync, queries still use the mesh saved in the scene, and async region builds can
## finish out of order, so builds run synchronously and readiness waits for a fresh region iteration.

signal navigation_ready


func rebake() -> void:
	NavigationServer3D.region_set_use_async_iterations(get_rid(), false)
	bake_finished.connect(_wait_for_sync, CONNECT_ONE_SHOT)
	bake_navigation_mesh(false)


func _wait_for_sync() -> void:
	var stale_iteration := NavigationServer3D.region_get_iteration_id(get_rid())
	while NavigationServer3D.region_get_iteration_id(get_rid()) == stale_iteration:
		await get_tree().physics_frame
		if not is_inside_tree():
			return

	navigation_ready.emit()
