class_name ForestNavigator
extends RefCounted

const GRID_HALF := 28
const GRID_SIZE := 29
const CELL_SIZE := 2.0
const TREE_CLEARANCE := 1.45

var grid: AStarGrid2D


func _init(trees: Array[Vector2]) -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID_SIZE, GRID_SIZE)
	grid.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var id := Vector2i(x, y)
			var point := Vector2(_axis_to_world(x), _axis_to_world(y))
			for tree in trees:
				if point.distance_to(tree) <= TREE_CLEARANCE:
					grid.set_point_solid(id)
					break


func route(from_world: Vector3, to_world: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var start := _nearest_open_id(from_world)
	var destination := _nearest_open_id(to_world)
	var cells := grid.get_id_path(start, destination)
	if cells.is_empty():
		return result
	if grid.is_point_solid(_world_to_id(from_world)):
		result.append(_id_to_world(start, from_world.y))
	for id in cells:
		if id != start:
			result.append(_id_to_world(id, from_world.y))
	if not grid.is_point_solid(_world_to_id(to_world)):
		result.append(Vector3(to_world.x, from_world.y, to_world.z))
	elif result.is_empty():
		result.append(_id_to_world(destination, from_world.y))
	return result


func _nearest_open_id(world: Vector3) -> Vector2i:
	var preferred := _world_to_id(world)
	if not grid.is_point_solid(preferred):
		return preferred
	var nearest := preferred
	var best_distance := INF
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var id := Vector2i(x, y)
			if grid.is_point_solid(id):
				continue
			var point := _id_to_world(id, world.y)
			var distance := world.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				nearest = id
	return nearest


func _world_to_id(world: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi((world.x + float(GRID_HALF)) / CELL_SIZE), 0, GRID_SIZE - 1),
		clampi(roundi((world.z + float(GRID_HALF)) / CELL_SIZE), 0, GRID_SIZE - 1)
	)


func _id_to_world(id: Vector2i, height: float) -> Vector3:
	return Vector3(_axis_to_world(id.x), height, _axis_to_world(id.y))


func _axis_to_world(index: int) -> float:
	return float(index) * CELL_SIZE - float(GRID_HALF)
