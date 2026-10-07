class_name GameState
extends RefCounted
## The rules of a session: the bag and hand of land pieces, the boat, and the
## turn. One turn: sail the boat (optional, up to SAIL_RANGE cells of water),
## raise one piece within PLACE_RANGE of the boat, then the sea updates,
## terrain settles and the hand refills.

enum Mode { VOYAGE, DRIFT }

const HAND_SIZE := 3
const SAIL_RANGE := 3
const PLACE_RANGE := 2
const VOYAGE_BAG_SIZE := 24

var grid: HexGrid
var mode := Mode.VOYAGE
## Wind blows along Hex.DIRECTIONS[wind_dir] for the whole session.
var wind_dir := 0
var bag: Array[Piece] = []
var hand: Array[Piece] = []
var boat := Vector2i.ZERO
var turn := 1
var sailed_this_turn := false
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
	boat = _start_cell()
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


## Water cells the boat can reach this turn, each mapped to its path there
## (excluding the start). Empty once the boat has sailed this turn.
func sail_targets() -> Dictionary:
	var paths := {}
	if sailed_this_turn:
		return paths
	var frontier: Array[Vector2i] = [boat]
	var came_from := {boat: boat}
	for step in SAIL_RANGE:
		var next: Array[Vector2i] = []
		for cell in frontier:
			for n in Hex.neighbors(cell):
				if came_from.has(n) or not grid.contains(n) or not grid.is_water(n):
					continue
				came_from[n] = cell
				next.append(n)
		frontier = next
	for cell: Vector2i in came_from:
		if cell == boat:
			continue
		var path: Array[Vector2i] = []
		var at := cell
		while at != boat:
			path.push_front(at)
			at = came_from[at]
		paths[cell] = path
	return paths


## Sails to `cell` if it's reachable. Returns the path taken (empty if not).
func sail_to(cell: Vector2i) -> Array[Vector2i]:
	var targets := sail_targets()
	if not targets.has(cell):
		return []
	boat = cell
	sailed_this_turn = true
	return targets[cell]


## Why `piece` can't be raised at `anchor`, or "" if it can.
func placement_error(piece: Piece, anchor: Vector2i) -> String:
	for cell in piece.cells_at(anchor):
		if not grid.contains(cell):
			return "Off the edge of the sea"
		if Hex.distance(cell, boat) > PLACE_RANGE:
			return "Too far from the boat"
		var raised := grid.get_height(cell) + 1
		if raised > HexGrid.MAX_HEIGHT:
			return "Already at the highest level"
		# The slope rule only binds land: below the waterline you can pile up
		# reefs and sandbanks freely.
		if raised >= HexGrid.Level.SEA_LEVEL and raised > grid.max_neighbor_height(cell) + piece.max_step():
			if piece.kind == Piece.Kind.ROCK:
				return "Rock can stand at most two levels above its highest neighbour"
			return "Land can only rise one level above its highest neighbour (here %d); build next to it first" \
				% grid.max_neighbor_height(cell)
		if cell == boat and raised > HexGrid.WATER_MAX:
			return "That would run the boat aground"
	return ""


## Every anchor where `piece` can be raised this turn.
func valid_anchors(piece: Piece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var reach := PLACE_RANGE + 3
	for dq in range(-reach, reach + 1):
		for dr in range(maxi(-reach, -dq - reach), mini(reach, -dq + reach) + 1):
			var anchor := boat + Vector2i(dq, dr)
			if placement_error(piece, anchor) == "":
				result.append(anchor)
	return result


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


## Drift mode's free action: lower one cell within reach. Doesn't end the turn.
func can_lower(cell: Vector2i) -> bool:
	return mode == Mode.DRIFT and grid.contains(cell) \
		and Hex.distance(cell, boat) <= PLACE_RANGE and grid.get_height(cell) > 0


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
	sailed_this_turn = false
	refill_hand()


## The deep-water cell nearest the middle of the map.
func _start_cell() -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := 1 << 30
	for cell in grid.cells():
		var d := Hex.distance(cell, Vector2i.ZERO)
		if grid.get_height(cell) == HexGrid.Level.DEEP and d < best_distance:
			best = cell
			best_distance = d
	return best
