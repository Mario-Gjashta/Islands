class_name TerrainRules
extends RefCounted
## Emergent terrain: after every change each cell settles into a type from
## its height and its neighbours. The player only shapes land; how cells
## connect decides what they become.

enum Terrain {
	DEEP, REEF, SANDBANK, LAGOON,
	BEACH, MARSH,
	MEADOW, SCRUB, FOREST,
	CLIFF, HILL_FOREST, ALPINE,
	PEAK,
}

const NAMES := [
	"Deep sea", "Reef", "Sandbank", "Lagoon",
	"Beach", "Marsh",
	"Meadow", "Scrub", "Forest",
	"Cliff", "Hill forest", "Alpine meadow",
	"Peak",
]

## How each terrain paints, as (vegetation, wetness, rock), each 0..1.
## The shaders blend these between hexes, so types melt into each other.
## Rock also steepens the cell's slopes, which is what makes a cliff a cliff.
const FIELDS := {
	Terrain.DEEP: Vector3(0.0, 0.0, 0.0),
	Terrain.REEF: Vector3(0.0, 0.0, 0.0),
	Terrain.SANDBANK: Vector3(0.0, 0.0, 0.0),
	Terrain.LAGOON: Vector3(0.7, 1.0, 0.0),
	Terrain.BEACH: Vector3(0.0, 0.0, 0.0),
	Terrain.MARSH: Vector3(0.55, 1.0, 0.0),
	Terrain.MEADOW: Vector3(0.38, 0.0, 0.0),
	Terrain.SCRUB: Vector3(0.22, 0.0, 0.1),
	Terrain.FOREST: Vector3(1.0, 0.0, 0.0),
	Terrain.CLIFF: Vector3(0.3, 0.0, 1.0),
	Terrain.HILL_FOREST: Vector3(1.0, 0.0, 0.1),
	Terrain.ALPINE: Vector3(0.3, 0.0, 0.35),
	Terrain.PEAK: Vector3(0.05, 0.0, 1.0),
}

## Open waves reach a coast if deep sea lies within this many cells.
const WAVE_REACH := 3


## Settles every cell. Wind blows along Hex.DIRECTIONS[wind_dir].
static func settle(grid: HexGrid, wind_dir: int) -> void:
	var lagoons := lagoon_cells(grid)
	for cell in grid.cells():
		grid.set_terrain(cell, classify(grid, cell, wind_dir, lagoons))


## The rules, cell by cell:
##   water      reef / sandbank, or lagoon when land encloses it
##   sea level  beach on an open coast, marsh on a calm one
##   lowland    cliff if it drops straight into water; forest when sheltered
##              from the wind; scrub on a windward coast; otherwise meadow
##   upland     cliff if it drops straight into water; otherwise hill forest,
##              or alpine meadow when it's already high ground all around
##   peak       bare rock
static func classify(grid: HexGrid, cell: Vector2i, wind_dir: int, lagoons: Dictionary) -> int:
	match grid.get_height(cell):
		HexGrid.Level.DEEP:
			return Terrain.DEEP
		HexGrid.Level.REEF, HexGrid.Level.SANDBANK:
			if lagoons.has(cell):
				return Terrain.LAGOON
			return Terrain.REEF if grid.get_height(cell) == HexGrid.Level.REEF else Terrain.SANDBANK
		HexGrid.Level.SEA_LEVEL:
			return Terrain.BEACH if is_exposed(grid, cell) else Terrain.MARSH
		HexGrid.Level.LOWLAND:
			if faces_water(grid, cell):
				return Terrain.CLIFF
			if is_sheltered(grid, cell, wind_dir):
				return Terrain.FOREST
			return Terrain.SCRUB if is_windward(grid, cell, wind_dir) else Terrain.MEADOW
		HexGrid.Level.UPLAND:
			if faces_water(grid, cell):
				return Terrain.CLIFF
			if min_neighbor_height(grid, cell) >= HexGrid.Level.UPLAND:
				return Terrain.ALPINE
			return Terrain.HILL_FOREST
	return Terrain.PEAK


## Open waves: deep sea (or the map edge) within reach.
static func is_exposed(grid: HexGrid, cell: Vector2i) -> bool:
	for other in _cells_within(cell, WAVE_REACH):
		if not grid.contains(other) or grid.get_height(other) == HexGrid.Level.DEEP:
			return true
	return false


## Hit straight on by the wind: water directly upwind.
static func is_windward(grid: HexGrid, cell: Vector2i, wind_dir: int) -> bool:
	return grid.is_water(upwind(cell, wind_dir, 1))


## Tucked in the lee of higher ground: a hill directly upwind, or two cells
## of land in a row.
static func is_sheltered(grid: HexGrid, cell: Vector2i, wind_dir: int) -> bool:
	var near := grid.get_height(upwind(cell, wind_dir, 1))
	var far := grid.get_height(upwind(cell, wind_dir, 2))
	return near >= HexGrid.Level.UPLAND or (near >= HexGrid.Level.LOWLAND and far >= HexGrid.Level.LOWLAND)


static func faces_water(grid: HexGrid, cell: Vector2i) -> bool:
	for n in Hex.neighbors(cell):
		if grid.is_water(n):
			return true
	return false


static func min_neighbor_height(grid: HexGrid, cell: Vector2i) -> int:
	var lowest := HexGrid.MAX_HEIGHT
	for n in Hex.neighbors(cell):
		lowest = mini(lowest, grid.get_height(n))
	return lowest


static func upwind(cell: Vector2i, wind_dir: int, steps: int) -> Vector2i:
	return cell - Hex.DIRECTIONS[wind_dir] * steps


## Shallow water enclosed by land: a pocket of reef and sandbank that can't
## reach deep sea or the map edge, or any shallow cell with land on four or
## more sides.
static func lagoon_cells(grid: HexGrid) -> Dictionary:
	var result := {}
	var seen := {}
	for start in grid.cells():
		var h := grid.get_height(start)
		if seen.has(start) or h < HexGrid.Level.REEF or h > HexGrid.WATER_MAX:
			continue
		var pocket: Array[Vector2i] = []
		var open_sea := false
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			pocket.append(cell)
			for n in Hex.neighbors(cell):
				if not grid.contains(n) or grid.get_height(n) == HexGrid.Level.DEEP:
					open_sea = true
					continue
				if seen.has(n) or not grid.is_water(n):
					continue
				seen[n] = true
				queue.append(n)
		for cell in pocket:
			if not open_sea or _land_sides(grid, cell) >= 4:
				result[cell] = true
	return result


static func _land_sides(grid: HexGrid, cell: Vector2i) -> int:
	var count := 0
	for n in Hex.neighbors(cell):
		if grid.contains(n) and not grid.is_water(n):
			count += 1
	return count


static func _cells_within(cell: Vector2i, reach: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-reach, reach + 1):
		for dr in range(maxi(-reach, -dq - reach), mini(reach, -dq + reach) + 1):
			result.append(cell + Vector2i(dq, dr))
	return result
