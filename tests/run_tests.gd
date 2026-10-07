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
	_test_terrain_emerges()
	_test_lagoon()
	if _failures == 0:
		print("All tests passed.")
	else:
		printerr("%d test(s) failed." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


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
	grid.set_height(Vector2i(-1, 0), HexGrid.Level.UPLAND)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.FOREST,
		"lowland in the lee of a hill is forest")
	grid.set_height(Vector2i(1, 0), HexGrid.Level.DEEP)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.CLIFF,
		"lowland dropping straight into water is a cliff")
	grid.set_height(Vector2i(1, 0), HexGrid.Level.SEA_LEVEL)
	grid.set_height(Vector2i.ZERO, HexGrid.Level.UPLAND)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.HILL_FOREST,
		"upland among lower land is hill forest")
	for n in Hex.neighbors(Vector2i.ZERO):
		grid.set_height(n, HexGrid.Level.UPLAND)
	_check(TerrainRules.classify(grid, Vector2i.ZERO, wind, {}) == TerrainRules.Terrain.ALPINE,
		"upland surrounded by upland is alpine meadow")
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


