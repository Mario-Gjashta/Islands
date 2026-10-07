extends SceneTree
## Headless logic tests. Run with:
##   godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_hex_round_trip()
	_test_hex_distance_and_neighbors()
	_test_grid_bounds_and_count()
	_test_grid_set_height_clamps()
	_test_generate_is_deterministic()
	_test_piece_rotation()
	_test_slope_rule()
	_test_rock_and_boat_rules()
	_test_sailing()
	_test_terrain_emerges()
	_test_lagoon()
	_test_voyage_ends()
	if _failures == 0:
		print("All tests passed.")
	else:
		printerr("%d test(s) failed." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


## A flat deep sea with the boat at the origin, for rule tests.
func _empty_game(mode := GameState.Mode.DRIFT) -> GameState:
	var grid := HexGrid.new(8)
	var game := GameState.new(grid, mode, 1)
	game.boat = Vector2i.ZERO
	return game


func _test_hex_round_trip() -> void:
	for q in range(-6, 7):
		for r in range(-6, 7):
			var cell := Vector2i(q, r)
			var p := Hex.to_pixel(cell, 48.0)
			_check(Hex.from_pixel(p, 48.0) == cell, "round trip at %s" % cell)
			_check(Hex.from_pixel(p + Vector2(20, -15), 48.0) == cell, "inner point at %s" % cell)


func _test_hex_distance_and_neighbors() -> void:
	_check(Hex.distance(Vector2i.ZERO, Vector2i(3, -1)) == 3, "distance (3,-1)")
	_check(Hex.distance(Vector2i(2, 2), Vector2i(-1, 0)) == 5, "distance (2,2)-(-1,0)")
	for n in Hex.neighbors(Vector2i(4, -2)):
		_check(Hex.distance(n, Vector2i(4, -2)) == 1, "neighbor %s is adjacent" % n)


func _test_grid_bounds_and_count() -> void:
	var grid := HexGrid.new(5)
	_check(grid.cells().size() == 3 * 5 * 6 + 1, "hex map of radius 5 has 91 cells")
	_check(grid.contains(Vector2i(5, -5)), "corner cell inside")
	_check(not grid.contains(Vector2i(5, 1)), "cell past the edge outside")
	_check(grid.get_height(Vector2i(40, 40)) == HexGrid.Level.DEEP, "outside reads as deep sea")


func _test_grid_set_height_clamps() -> void:
	var grid := HexGrid.new(3)
	var cell := Vector2i(1, 1)
	_check(grid.set_height(cell, HexGrid.MAX_HEIGHT + 4), "set changes height")
	_check(grid.get_height(cell) == HexGrid.MAX_HEIGHT, "clamped to peak")
	_check(not grid.set_height(cell, HexGrid.MAX_HEIGHT + 1), "no change when already at max")
	grid.set_height(cell, -3)
	_check(grid.get_height(cell) == HexGrid.Level.DEEP, "clamped to deep sea")
	_check(not grid.set_height(Vector2i(10, 0), 2), "outside cells cannot be set")


func _test_generate_is_deterministic() -> void:
	var a := HexGrid.new(10)
	var b := HexGrid.new(10)
	a.generate(1234)
	b.generate(1234)
	var same := true
	for cell in a.cells():
		same = same and a.get_height(cell) == b.get_height(cell)
	_check(same, "same seed gives the same sea")


func _test_piece_rotation() -> void:
	for shape in Piece.SHAPES:
		var piece := Piece.new(Piece.Kind.LAND, shape)
		var turned := piece
		for i in 6:
			turned = turned.rotated()
		_check(turned.offsets == piece.offsets, "six turns return %s to start" % [shape])
		# Rotation keeps every cell touching the shape.
		for o in piece.rotated().offsets:
			_check(Hex.distance(o, Vector2i.ZERO) <= 3, "rotated offsets stay close")


func _test_slope_rule() -> void:
	var game := _empty_game()
	var single := Piece.new()
	_check(game.placement_error(single, Vector2i(1, 0)) == "", "deep sea can become reef")
	game.grid.set_height(Vector2i(1, 0), HexGrid.Level.REEF)
	_check(game.placement_error(single, Vector2i(1, 0)) != "",
		"a lone reef can't rise above its deep neighbours")
	game.grid.set_height(Vector2i(2, 0), HexGrid.Level.REEF)
	_check(game.placement_error(single, Vector2i(1, 0)) == "", "a reef beside a reef can rise")
	_check(game.placement_error(single, Vector2i(3, 0)) != "", "too far from the boat")
	var line := Piece.new(Piece.Kind.LAND, [Vector2i(0, 0), Vector2i(1, 0)])
	_check(game.placement_error(line, Vector2i(1, 0)) == "", "a two-piece raises both reefs")


func _test_rock_and_boat_rules() -> void:
	var game := _empty_game()
	var cell := Vector2i(1, 0)
	game.grid.set_height(cell, HexGrid.Level.REEF)
	var rock := Piece.new(Piece.Kind.ROCK)
	_check(game.placement_error(rock, cell) == "", "rock may stand two above its neighbours")
	game.grid.set_height(Vector2i.ZERO, HexGrid.Level.SANDBANK)
	game.grid.set_height(Vector2i(-1, 0), HexGrid.Level.SANDBANK)
	_check(game.placement_error(Piece.new(), Vector2i.ZERO) != "",
		"can't raise the boat's own cell to land")


func _test_sailing() -> void:
	var game := _empty_game()
	_check(game.sail_targets().has(Vector2i(3, 0)), "boat reaches three cells")
	_check(not game.sail_targets().has(Vector2i(4, 0)), "but not four")
	for n in Hex.neighbors(Vector2i.ZERO):
		game.grid.set_height(n, HexGrid.Level.SEA_LEVEL)
	_check(game.sail_targets().is_empty(), "land on every side walls the boat in")
	game.grid.set_height(Vector2i(1, 0), HexGrid.Level.SANDBANK)
	var path := game.sail_to(Vector2i(2, 0))
	_check(path == [Vector2i(1, 0), Vector2i(2, 0)], "sails through the gap over the sandbank")
	_check(game.sail_targets().is_empty(), "only one sail per turn")


func _test_terrain_emerges() -> void:
	var grid := HexGrid.new(8)
	var wind := 0
	# A beach on open sea; a sheltered sea-level cell inside a ring of land.
	grid.set_height(Vector2i(0, 0), HexGrid.Level.SEA_LEVEL)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.BEACH,
		"sea level beside open sea is beach")
	for cell in grid.cells():
		if Hex.distance(cell, Vector2i.ZERO) <= 4:
			grid.set_height(cell, HexGrid.Level.SEA_LEVEL)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.MARSH,
		"sea level far from open sea is marsh")
	grid.set_height(Vector2i.ZERO, HexGrid.Level.LOWLAND)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.MEADOW,
		"dry lowland is meadow")
	grid.springs[Vector2i(1, 0)] = true
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.FOREST,
		"lowland near a spring is forest")
	grid.rocks[Vector2i.ZERO] = true
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.CLIFF,
		"rock settles into cliff")
	grid.set_height(Vector2i.ZERO, HexGrid.Level.PEAK)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.PEAK,
		"level six is a peak")


func _test_lagoon() -> void:
	var grid := HexGrid.new(8)
	for cell in grid.cells():
		var d := Hex.distance(cell, Vector2i.ZERO)
		if d == 2:
			grid.set_height(cell, HexGrid.Level.SEA_LEVEL)
		elif d < 2:
			grid.set_height(cell, HexGrid.Level.SANDBANK)
	var lagoons := TerrainRules.lagoon_cells(grid)
	_check(lagoons.has(Vector2i.ZERO) and lagoons.has(Vector2i(1, 0)), "a ring of land encloses a lagoon")
	grid.set_height(Vector2i(2, 0), HexGrid.Level.DEEP)
	lagoons = TerrainRules.lagoon_cells(grid)
	_check(not lagoons.has(Vector2i.ZERO), "a gap to deep sea opens it up")


func _test_voyage_ends() -> void:
	var game := _empty_game(GameState.Mode.VOYAGE)
	_check(game.hand.size() == GameState.HAND_SIZE, "starts with a full hand")
	_check(game.pieces_left() == GameState.VOYAGE_BAG_SIZE, "pieces come out of the bag")
	game.bag.clear()
	game.hand.clear()
	_check(game.is_over(), "voyage ends when bag and hand are empty")
	var drift := _empty_game()
	drift.hand.clear()
	drift.refill_hand()
	_check(drift.hand.size() == GameState.HAND_SIZE and not drift.is_over(), "drift never runs out")
