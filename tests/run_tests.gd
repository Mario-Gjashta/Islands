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
			# Points well inside the hex still map back to it.
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
	_check(grid.get_height(Vector2i(40, 40)) == HexGrid.Layer.SEABED, "outside reads as seabed")


func _test_grid_set_height_clamps() -> void:
	var grid := HexGrid.new(3)
	var cell := Vector2i(1, 1)
	_check(grid.set_height(cell, 9), "set changes height")
	_check(grid.get_height(cell) == HexGrid.MAX_HEIGHT, "clamped to peak")
	_check(not grid.set_height(cell, 7), "no change when already at max")
	grid.set_height(cell, -3)
	_check(grid.get_height(cell) == HexGrid.Layer.SEABED, "clamped to seabed")
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
