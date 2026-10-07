class_name Hex
extends RefCounted
## Axial-coordinate math for pointy-top hexagons.
##
## Cells are Vector2i(q, r); the implicit third cube coordinate is s = -q - r.
## `size` is the distance from a hex centre to any of its corners.

const SQRT3 := 1.7320508075688772

## The six neighbour offsets, clockwise from east.
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func to_pixel(cell: Vector2i, size: float) -> Vector2:
	return Vector2(
		size * (SQRT3 * cell.x + SQRT3 / 2.0 * cell.y),
		size * 1.5 * cell.y)


static func from_pixel(point: Vector2, size: float) -> Vector2i:
	var q := (SQRT3 / 3.0 * point.x - point.y / 3.0) / size
	var r := (2.0 / 3.0 * point.y) / size
	return round_axial(q, r)


static func round_axial(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		result.append(cell + dir)
	return result


## Corner points of a hex centred on the origin.
static func corners(size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(Vector2(cos(angle), sin(angle)) * size)
	return points
