## Pure grid / terrain math for the isometric board.
##
## Nothing in here touches the scene tree: every function takes data in and
## returns data out so it can be unit tested headlessly.
class_name GridSystem
extends RefCounted

## World-space size of one isometric tile (2:1 diamond), matching the generated
## tile art (32x16 logical pixels upscaled 2x).
const TILE_SIZE := Vector2(64, 32)

enum Terrain { GRASS, PATH, WATER, HILL, WATER_EDGE, ROCK, FOREST, DIRT }

## Terrain types a building may not stand on.
const BLOCKED_TERRAIN: Array[Terrain] = [Terrain.WATER, Terrain.ROCK]

const MIN_GRID_SIZE := 5
const MAX_GRID_SIZE := 12

## Row-major atlas coordinates inside terrain_tileset.png, one entry per Terrain.
const TILE_COORDS := {
	Terrain.GRASS: Vector2i(0, 0),
	Terrain.PATH: Vector2i(1, 0),
	Terrain.WATER: Vector2i(2, 0),
	Terrain.HILL: Vector2i(3, 0),
	Terrain.WATER_EDGE: Vector2i(0, 1),
	Terrain.ROCK: Vector2i(1, 1),
	Terrain.FOREST: Vector2i(2, 1),
	Terrain.DIRT: Vector2i(3, 1),
}

const TERRAIN_NAMES := {
	Terrain.GRASS: "Grass",
	Terrain.PATH: "Path",
	Terrain.WATER: "Water",
	Terrain.HILL: "Hill",
	Terrain.WATER_EDGE: "Shore",
	Terrain.ROCK: "Rock",
	Terrain.FOREST: "Forest",
	Terrain.DIRT: "Dirt",
}


## Grid coordinate -> centre of that tile in world space.
##
## Cells form 2:1 diamonds: cell (0,0)'s diamond is centred on (0,16) and spans
## x in [-32,32], y in [0,32]. Everything that needs to sit "on" a tile
## (buildings, props, camera focus) uses this.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x - cell.y) * TILE_SIZE.x * 0.5,
		float(cell.x + cell.y) * TILE_SIZE.y * 0.5 + TILE_SIZE.y * 0.5
	)


## World position -> the grid coordinate that contains it (exact inverse of the
## cell -> world mapping above).
static func world_to_cell(world_pos: Vector2) -> Vector2i:
	var fx := world_pos.x / (TILE_SIZE.x * 0.5)
	var fy := world_pos.y / (TILE_SIZE.y * 0.5)
	return Vector2i(floori((fy + fx) * 0.5), floori((fy - fx) * 0.5))


static func is_inside(cell: Vector2i, grid_size: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size


static func is_buildable_terrain(terrain: int) -> bool:
	return not BLOCKED_TERRAIN.has(terrain)


## Every cell covered by a `size` x `size` footprint anchored at `cell`.
static func footprint(cell: Vector2i, size: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			cells.append(Vector2i(cell.x + dx, cell.y + dy))
	return cells


## Can a building of `size` be placed at `cell`?
##
## `terrain` is a Dictionary[Vector2i, int]; `occupied` is a Dictionary[Vector2i, String]
## mapping cell -> task id for anything already built there.
static func can_place(
	cell: Vector2i, size: int, grid_size: int, terrain: Dictionary, occupied: Dictionary
) -> bool:
	for c in footprint(cell, size):
		if not is_inside(c, grid_size):
			return false
		if occupied.has(c):
			return false
		if not is_buildable_terrain(int(terrain.get(c, Terrain.GRASS))):
			return false
	return true


## The hand-authored starter map for a `size` x `size` plot. Deterministic so the
## same city always grows the same way.
static func generate_starter_terrain(size: int) -> Dictionary:
	var terrain := {}
	for y in size:
		for x in size:
			terrain[Vector2i(x, y)] = Terrain.GRASS

	# A small pond in the top-left quadrant, ringed by shore tiles.
	var pond := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]
	for c in pond:
		if is_inside(c, size):
			terrain[c] = Terrain.WATER
	for c in [Vector2i(2, 1), Vector2i(0, 3), Vector2i(2, 2)]:
		if is_inside(c, size) and terrain[c] == Terrain.GRASS:
			terrain[c] = Terrain.WATER_EDGE

	# Rocky outcrop on the far side of the plot.
	for c in [Vector2i(size - 1, 0), Vector2i(size - 2, 0)]:
		if is_inside(c, size):
			terrain[c] = Terrain.ROCK

	# Hill and forest patch along the bottom edge.
	for c in [Vector2i(0, size - 1), Vector2i(1, size - 1)]:
		if is_inside(c, size):
			terrain[c] = Terrain.HILL
	for c in [Vector2i(size - 1, size - 1), Vector2i(size - 2, size - 1), Vector2i(size - 1, size - 2)]:
		if is_inside(c, size) and terrain[c] == Terrain.GRASS:
			terrain[c] = Terrain.FOREST

	# A dirt path running along the main diagonal so the starter plot reads as a place.
	for i in size:
		var path_cell := Vector2i(i, i)
		if is_inside(path_cell, size) and is_buildable_terrain(int(terrain[path_cell])):
			terrain[path_cell] = Terrain.PATH
	return terrain


static func terrain_name(terrain: int) -> String:
	return String(TERRAIN_NAMES.get(terrain, "Grass"))


## Is this terrain walk-on and buildable enough to host a decoration?
static func is_decoratable(terrain: int) -> bool:
	return terrain != Terrain.WATER and terrain != Terrain.WATER_EDGE
