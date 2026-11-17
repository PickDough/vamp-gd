class_name SpatialGrid
extends RefCounted

## Buckets points into square cells on the XZ plane so neighbours can be found without scanning every point.
## rebuild() keeps the positions it is given; the caller hands over an array it no longer writes to. Queries only
## read, so any number of threads may run them between rebuilds. repulsion() sums the push away from every other
## point within a radius of one point: each neighbour pushes along the flat direction from it, with a strength
## falling from 1 at no distance to 0 at the radius; points on top of each other push apart along X.
##
## Each point becomes one int64 entry, its cell key in the high bits and its index in the low bits, so a single
## native PackedInt64Array.sort() groups points by cell instead of a sort with a GDScript comparator. Cell
## coordinates wrap past +-32768 cells, far beyond any map.

const INDEX_BITS := 24
const INDEX_MASK := (1 << INDEX_BITS) - 1
const CELL_BITS := 16
const CELL_MASK := (1 << CELL_BITS) - 1

var positions := PackedVector3Array()

var _cell_size: float
var _entries := PackedInt64Array()
var _cells: Dictionary[int, Vector2i] = {}


func _init(cell_size: float) -> void:
	_cell_size = cell_size


func rebuild(new_positions: PackedVector3Array) -> void:
	positions = new_positions
	_entries.resize(positions.size())
	for index in positions.size():
		var position := positions[index]
		_entries[index] = (_cell_key(_cell_of(position.x), _cell_of(position.z)) << INDEX_BITS) | index

	_entries.sort()
	_fill_cells()


func candidates(center: Vector3, radius: float, found: PackedInt32Array) -> void:
	found.clear()
	for cell_x in range(_cell_of(center.x - radius), _cell_of(center.x + radius) + 1):
		for cell_z in range(_cell_of(center.z - radius), _cell_of(center.z + radius) + 1):
			var span: Vector2i = _cells.get(_cell_key(cell_x, cell_z), Vector2i.ZERO)
			for entry in range(span.x, span.x + span.y):
				found.append(_entries[entry] & INDEX_MASK)


func repulsion(index: int, radius: float) -> Vector3:
	var center := positions[index]
	var push := Vector3.ZERO
	for cell_x in range(_cell_of(center.x - radius), _cell_of(center.x + radius) + 1):
		for cell_z in range(_cell_of(center.z - radius), _cell_of(center.z + radius) + 1):
			var span: Vector2i = _cells.get(_cell_key(cell_x, cell_z), Vector2i.ZERO)
			for entry in range(span.x, span.x + span.y):
				var other := _entries[entry] & INDEX_MASK
				var offset := center - positions[other]
				offset.y = 0.0
				var distance := offset.length()
				if other == index or distance >= radius:
					continue
				var direction := offset / distance if distance > 0.0 else Vector3.RIGHT * signf(other - index)
				push += direction * (1.0 - distance / radius)

	return push


func _fill_cells() -> void:
	_cells.clear()
	var start := 0
	var count := _entries.size()
	for index in range(1, count + 1):
		if index < count and _entries[index] >> INDEX_BITS == _entries[start] >> INDEX_BITS:
			continue

		_cells[_entries[start] >> INDEX_BITS] = Vector2i(start, index - start)
		start = index


func _cell_of(coordinate: float) -> int:
	return floori(coordinate / _cell_size)


func _cell_key(cell_x: int, cell_z: int) -> int:
	return ((cell_x & CELL_MASK) << CELL_BITS) | (cell_z & CELL_MASK)
