class_name HexGrid
extends RefCounted
## Hex-shaped map of cells. Each cell stores a height level, the terrain type
## it has settled into, and whether a rock or spring piece raised it.
##
## Logic lives here; rendering only reads it. Cells are stored in a square
## (2R+1)^2 array indexed by axial coords offset by the radius, which is also
## the layout of the texture the shaders sample.

enum Level { DEEP, REEF, SANDBANK, SEA_LEVEL, LOWLAND, UPLAND, PEAK }

const MAX_HEIGHT := Level.PEAK
## Cells at or below this level are water; the boat can sail them.
const WATER_MAX := Level.SANDBANK
const LEVEL_NAMES := ["Deep sea", "Reef", "Sandbank", "Sea level", "Lowland", "Upland", "Peak"]

var radius: int
## Side length of the backing square array (and the shader's cell texture).
var side: int
## Cells raised by a rock piece: they may stand two levels above a neighbour
## and always settle into cliff.
var rocks := {}
## Cells raised by a spring piece: freshwater sources.
var springs := {}

var _heights := PackedByteArray()
var _terrain := PackedByteArray()


func _init(map_radius: int) -> void:
	radius = map_radius
	side = 2 * radius + 1
	_heights.resize(side * side)
	_terrain.resize(side * side)


func contains(cell: Vector2i) -> bool:
	return Hex.distance(cell, Vector2i.ZERO) <= radius


func get_height(cell: Vector2i) -> int:
	if not contains(cell):
		return Level.DEEP
	return _heights[_index(cell)]


## Sets a cell's height, clamped to the valid levels. Returns true if it changed.
func set_height(cell: Vector2i, height: int) -> bool:
	if not contains(cell):
		return false
	var clamped := clampi(height, Level.DEEP, MAX_HEIGHT)
	var index := _index(cell)
	if _heights[index] == clamped:
		return false
	_heights[index] = clamped
	return true


func is_water(cell: Vector2i) -> bool:
	return get_height(cell) <= WATER_MAX


func get_terrain(cell: Vector2i) -> int:
	if not contains(cell):
		return 0
	return _terrain[_index(cell)]


func set_terrain(cell: Vector2i, terrain: int) -> void:
	if contains(cell):
		_terrain[_index(cell)] = terrain


## The highest level among a cell's six neighbours (off-map counts as deep sea).
func max_neighbor_height(cell: Vector2i) -> int:
	var highest := 0
	for n in Hex.neighbors(cell):
		highest = maxi(highest, get_height(n))
	return highest


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(Vector2i(q, r))
	return result


## Fills the map with deep sea and scattered reefs and sandbanks from noise.
func generate(seed_value: int) -> void:
	_heights.fill(Level.DEEP)
	_terrain.fill(0)
	rocks.clear()
	springs.clear()
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.11
	noise.fractal_octaves = 3
	for cell in cells():
		var p := Hex.to_pixel(cell, 1.0)
		var n := noise.get_noise_2d(p.x, p.y)
		if n > 0.5:
			set_height(cell, Level.SANDBANK)
		elif n > 0.22:
			set_height(cell, Level.REEF)


static func level_name(height: int) -> String:
	return LEVEL_NAMES[clampi(height, 0, MAX_HEIGHT)]


func _index(cell: Vector2i) -> int:
	return (cell.y + radius) * side + (cell.x + radius)
