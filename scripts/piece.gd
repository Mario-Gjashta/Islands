class_name Piece
extends RefCounted
## A land piece: a small shape of 1-4 hexes that raises each one by a level.

enum Kind { LAND, ROCK, SPRING }

## Land shapes as axial offsets from the anchor (the first cell).
const SHAPES := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, -1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
]
## Relative odds of each shape in the bag, matching SHAPES.
const SHAPE_WEIGHTS := [5, 6, 4, 4, 4, 2, 2, 2]
## Odds of a special piece instead of a land shape.
const ROCK_CHANCE := 0.07
const SPRING_CHANCE := 0.06

var kind := Kind.LAND
var offsets: Array[Vector2i] = []


func _init(piece_kind := Kind.LAND, piece_offsets: Array = [Vector2i.ZERO]) -> void:
	kind = piece_kind
	for o in piece_offsets:
		offsets.append(o)


static func random(rng: RandomNumberGenerator) -> Piece:
	var roll := rng.randf()
	if roll < ROCK_CHANCE:
		return Piece.new(Kind.ROCK)
	if roll < ROCK_CHANCE + SPRING_CHANCE:
		return Piece.new(Kind.SPRING)
	var total := 0
	for w in SHAPE_WEIGHTS:
		total += w
	var pick := rng.randi_range(1, total)
	for i in SHAPES.size():
		pick -= SHAPE_WEIGHTS[i]
		if pick <= 0:
			var piece := Piece.new(Kind.LAND, SHAPES[i])
			# Start in a random orientation.
			for turn in rng.randi_range(0, 5):
				piece = piece.rotated()
			return piece
	return Piece.new()


## The same piece turned 60 degrees clockwise about its anchor.
func rotated() -> Piece:
	var turned: Array[Vector2i] = []
	for o in offsets:
		turned.append(Vector2i(-o.y, o.x + o.y))
	return Piece.new(kind, turned)


func cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for o in offsets:
		result.append(anchor + o)
	return result


## How many levels above its highest neighbour this piece may raise a cell.
func max_step() -> int:
	return 2 if kind == Kind.ROCK else 1


func label() -> String:
	match kind:
		Kind.ROCK:
			return "Rock"
		Kind.SPRING:
			return "Spring"
	return "Land ×%d" % offsets.size()
