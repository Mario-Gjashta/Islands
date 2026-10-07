class_name HexGrid
extends RefCounted
## Hex-shaped map of cells, each storing an integer height layer.
##
## Logic lives here; rendering only reads it. Cells are stored in a square
## (2R+1)^2 array indexed by axial coords offset by the radius, which is also
## the layout of the texture the sea shader samples.

enum Layer { SEABED, REEF, SHALLOWS, BEACH, MEADOW, HILLS, HIGHLAND, MOUNTAIN, SUMMIT }

const MAX_HEIGHT := Layer.SUMMIT
const LAYER_NAMES := [
	"Seabed", "Reef", "Shallows", "Beach", "Meadow", "Hills", "Highland", "Mountain", "Summit",
]

var radius: int
## Side length of the backing square array (and the shader's cell texture).
var side: int

var _heights := PackedByteArray()


func _init(map_radius: int) -> void:
	radius = map_radius
	side = 2 * radius + 1
	_heights.resize(side * side)
	_heights.fill(Layer.SEABED)


func contains(cell: Vector2i) -> bool:
	return Hex.distance(cell, Vector2i.ZERO) <= radius


func get_height(cell: Vector2i) -> int:
	if not contains(cell):
		return Layer.SEABED
	return _heights[_index(cell)]


## Sets a cell's height, clamped to the valid layers. Returns true if it changed.
func set_height(cell: Vector2i, height: int) -> bool:
	if not contains(cell):
		return false
	var clamped := clampi(height, Layer.SEABED, MAX_HEIGHT)
	var index := _index(cell)
	if _heights[index] == clamped:
		return false
	_heights[index] = clamped
	return true


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(Vector2i(q, r))
	return result


## Fills the map with an empty, gently varied seabed from noise.
func generate(seed_value: int) -> void:
	_heights.fill(Layer.SEABED)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.11
	noise.fractal_octaves = 3
	for cell in cells():
		var p := Hex.to_pixel(cell, 1.0)
		var n := noise.get_noise_2d(p.x, p.y)
		if n > 0.45:
			set_height(cell, Layer.SHALLOWS)
		elif n > 0.15:
			set_height(cell, Layer.REEF)


static func layer_name(height: int) -> String:
	return LAYER_NAMES[clampi(height, 0, MAX_HEIGHT)]


func _index(cell: Vector2i) -> int:
	return (cell.y + radius) * side + (cell.x + radius)
