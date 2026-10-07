class_name GameState
extends RefCounted
## The rules of a session: the bag and hand of land pieces and the turn.
## One turn: raise one piece anywhere it fits, then terrain settles and the
## hand refills.

enum Mode { VOYAGE, DRIFT }

const HAND_SIZE := 3
const VOYAGE_BAG_SIZE := 24

var grid: HexGrid
var mode := Mode.VOYAGE
## Wind blows along Hex.DIRECTIONS[wind_dir] for the whole session.
var wind_dir := 0
var bag: Array[Piece] = []
var hand: Array[Piece] = []
var turn := 1
var pieces_placed := 0

var _rng := RandomNumberGenerator.new()


func _init(map: HexGrid, session_mode: Mode, seed_value: int) -> void:
	grid = map
	mode = session_mode
	_rng.seed = seed_value
	wind_dir = _rng.randi_range(0, 5)
	if mode == Mode.VOYAGE:
		for i in VOYAGE_BAG_SIZE:
			bag.append(Piece.random(_rng))
	refill_hand()
	TerrainRules.settle(grid, wind_dir)


func pieces_left() -> int:
	return bag.size() + hand.size()


func is_over() -> bool:
	return mode == Mode.VOYAGE and hand.is_empty() and bag.is_empty()


func refill_hand() -> void:
	while hand.size() < HAND_SIZE:
		if mode == Mode.DRIFT:
			hand.append(Piece.random(_rng))
		elif bag.is_empty():
			return
		else:
			hand.append(bag.pop_back())


## Why `piece` can't be raised at `anchor`, or "" if it can.
func placement_error(piece: Piece, anchor: Vector2i) -> String:
	for cell in piece.cells_at(anchor):
		if not grid.contains(cell):
			return "Off the edge of the sea"
		var raised := grid.get_height(cell) + 1
		if raised > HexGrid.MAX_HEIGHT:
			return "Already at the highest level"
		# The slope rule only binds land: below the waterline you can pile up
		# reefs and sandbanks freely.
		if raised >= HexGrid.Level.SEA_LEVEL and raised > grid.max_neighbor_height(cell) + piece.max_step():
			if piece.kind == Piece.Kind.ROCK:
				return "Rock can stand at most two levels above its highest neighbour"
			return "Land grows outward: build up the cells next to it first"
	return ""


## Raises the hand piece at `hand_index` and ends the turn. Returns the cells
## raised, or an empty array if the placement isn't allowed.
func place(hand_index: int, anchor: Vector2i) -> Array[Vector2i]:
	var piece := hand[hand_index]
	if placement_error(piece, anchor) != "":
		return []
	var raised := piece.cells_at(anchor)
	for cell in raised:
		grid.set_height(cell, grid.get_height(cell) + 1)
		match piece.kind:
			Piece.Kind.ROCK:
				grid.rocks[cell] = true
			Piece.Kind.SPRING:
				grid.springs[cell] = true
	hand.remove_at(hand_index)
	pieces_placed += 1
	end_turn()
	return raised


## Drift mode's free action: lower one cell. Doesn't end the turn.
func can_lower(cell: Vector2i) -> bool:
	return mode == Mode.DRIFT and grid.contains(cell) and grid.get_height(cell) > 0


func lower(cell: Vector2i) -> bool:
	if not can_lower(cell):
		return false
	grid.set_height(cell, grid.get_height(cell) - 1)
	if grid.is_water(cell):
		grid.rocks.erase(cell)
		grid.springs.erase(cell)
	TerrainRules.settle(grid, wind_dir)
	return true


func end_turn() -> void:
	TerrainRules.settle(grid, wind_dir)
	turn += 1
	refill_hand()
