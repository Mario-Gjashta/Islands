extends Node3D
## Runs a session: turns input into GameState moves, and keeps the sea,
## overlays and HUD in step with the rules.

const HEX_SIZE := 1.0
const GRID_RADIUS := 18
## Pointer travel (pixels) before a press counts as a pan instead of a tap.
const DRAG_THRESHOLD := 12.0
const DEFAULT_HINT := "Pick a piece and tap the sea to raise it. Land grows outward from the shallows."

## The sample island (Drift): a peak stepping down through hills and forest to
## beaches, a ring island around a lagoon, and a spring.
const SAMPLE_PROFILE := [6, 5, 4, 3]
const SAMPLE_ROCKS := [Vector2i(1, -1), Vector2i(2, -1)]
const SAMPLE_SPRING := Vector2i(-2, 2)
const SAMPLE_EXTRAS := {
	Vector2i(-6, 1): 4, Vector2i(-5, 1): 3, Vector2i(-6, 2): 3, Vector2i(-7, 1): 3,
	Vector2i(1, -1): 6, Vector2i(-1, 1): 5, Vector2i(2, -2): 5,
}

var grid: HexGrid
var game: GameState
var seed_value := 0
var selected := 0
var lower_mode := false

var _pressing := false
var _dragging := false
var _press_position := Vector2.ZERO
## Touch screens can't hover, so the first tap previews a placement and a
## second tap on the same spot confirms it.
var _pending_anchor := Vector2i(1 << 20, 0)
## Active touch points by finger index, for two-finger pinch zoom.
var _touches := {}
var _pinch_spread := 0.0
var _pinch_centre := Vector2.ZERO

@onready var sea: SeaRenderer = $Sea
@onready var effects: Node3D = $Effects
@onready var ghost: GhostHex = $GhostHex
@onready var camera: CameraRig = $CameraRig
@onready var hud: Hud = $HUD


func _ready() -> void:
	randomize()
	ghost.setup(HEX_SIZE)
	camera.bounds_radius = HEX_SIZE * Hex.SQRT3 * GRID_RADIUS
	camera.ground_height = sea.max_ground_y
	hud.mode_chosen.connect(start_session)
	hud.menu_requested.connect(_show_menu)
	hud.piece_selected.connect(_select)
	hud.rotate_requested.connect(_rotate_selected)
	hud.lower_mode_toggled.connect(_set_lower_mode)
	hud.sample_island_requested.connect(build_sample_island)
	# An empty sea to look at behind the menu.
	_new_sea(randi())


func start_session(mode: GameState.Mode, new_seed := -1) -> void:
	_new_sea(new_seed if new_seed >= 0 else randi())
	game = GameState.new(grid, mode, seed_value)
	sea.sync_all()
	selected = 0
	camera.position = Vector3.ZERO
	camera.zoom_at(1.0, Vector2.ZERO)
	hud.start_session(mode)
	_set_lower_mode(false)
	_refresh()


## Raises a ready-made island to show off every kind of terrain at once.
func build_sample_island() -> void:
	if game == null:
		return
	for cell in grid.cells():
		# A ragged outline, so the sample doesn't read as a hexagon.
		var d := Hex.distance(cell, Vector2i.ZERO) + (1 if (cell.x * 7 + cell.y * 13) % 5 == 0 else 0)
		if d < SAMPLE_PROFILE.size():
			grid.set_height(cell, SAMPLE_PROFILE[d])
	for cell in grid.cells():
		var d := Hex.distance(cell, Vector2i(7, -2))
		if d == 2:
			grid.set_height(cell, HexGrid.Level.SEA_LEVEL)
		elif d < 2:
			grid.set_height(cell, HexGrid.Level.SANDBANK)
	for cell: Vector2i in SAMPLE_EXTRAS:
		grid.set_height(cell, SAMPLE_EXTRAS[cell])
	for cell in SAMPLE_ROCKS:
		grid.rocks[cell] = true
	grid.springs[SAMPLE_SPRING] = true
	TerrainRules.settle(grid, game.wind_dir)
	sea.sync_all()
	_refresh()


func _new_sea(new_seed: int) -> void:
	seed_value = new_seed
	grid = HexGrid.new(GRID_RADIUS)
	grid.generate(seed_value)
	TerrainRules.settle(grid, 0)
	sea.setup(grid, HEX_SIZE)
	hud.set_seed(seed_value)


func _show_menu() -> void:
	game = null
	ghost.hide_ghost()
	hud.show_menu()


func _process(_delta: float) -> void:
	if game == null:
		return
	_update_hover()
	_update_wind_arrow()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if _pressing and not _dragging \
				and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
		var pinching := _touches.size() >= 2
		if not pinching and (_dragging or event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			camera.pan_screen(event.position - event.relative, event.position)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var spread := _touch_spread()
			var centre := _touch_centre()
			if _pinch_spread > 0.0:
				camera.pan_screen(_pinch_centre, centre)
				camera.zoom_at(spread / _pinch_spread, centre)
			_pinch_spread = spread
			_pinch_centre = centre
	elif event is InputEventMagnifyGesture:
		camera.zoom_at(event.factor, event.position)
	elif event is InputEventPanGesture:
		camera.pan_screen(event.position, event.position - event.delta * 10.0)
	elif event is InputEventKey and event.pressed and not event.echo and game != null:
		match event.keycode:
			KEY_R:
				_rotate_selected()
			KEY_1, KEY_2, KEY_3:
				_select(event.keycode - KEY_1)
			KEY_TAB:
				if game.mode == GameState.Mode.DRIFT:
					_set_lower_mode(not lower_mode)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressing = true
				_dragging = false
				_press_position = event.position
			elif _pressing:
				_pressing = false
				if not _dragging:
					_tap(event.position)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_rotate_selected()
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera.zoom_at(1.1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera.zoom_at(1.0 / 1.1, event.position)


func _tap(screen_position: Vector2) -> void:
	if game == null or game.is_over():
		return
	var cell := _cell_at_screen(screen_position)
	if lower_mode:
		if game.lower(cell):
			_splash(cell)
			sea.sync_all()
			_refresh()
		return
	var piece := _selected_piece()
	if piece != null and game.placement_error(piece, cell) == "":
		if _is_touch() and cell != _pending_anchor:
			_pending_anchor = cell
			hud.set_hint("Tap again to raise it here.")
			return
		_place(cell)
		return
	if piece != null:
		hud.set_hint(game.placement_error(piece, cell) + ".")


func _place(anchor: Vector2i) -> void:
	_pending_anchor = Vector2i(1 << 20, 0)
	var raised := game.place(selected, anchor)
	for cell in raised:
		_splash(cell)
	ghost.on_placed()
	sea.sync_all()
	selected = clampi(selected, 0, maxi(game.hand.size() - 1, 0))
	_refresh()
	if game.is_over():
		hud.show_end(_summary())


func _select(index: int) -> void:
	if game == null or index >= game.hand.size():
		return
	selected = index
	_set_lower_mode(false)
	_refresh()


func _rotate_selected() -> void:
	if game == null or game.hand.is_empty():
		return
	game.hand[selected] = game.hand[selected].rotated()
	_refresh()


func _set_lower_mode(lowering: bool) -> void:
	lower_mode = lowering and game != null and game.mode == GameState.Mode.DRIFT
	hud.set_lower_mode(lower_mode)
	_refresh()


func _selected_piece() -> Piece:
	if game == null or game.hand.is_empty():
		return null
	return game.hand[clampi(selected, 0, game.hand.size() - 1)]


## Updates everything that depends on the game state after a move.
func _refresh() -> void:
	if game == null:
		return
	hud.set_hand(game.hand, selected)
	var mode_name := "Voyage" if game.mode == GameState.Mode.VOYAGE else "Drift"
	var status := "%s · turn %d" % [mode_name, game.turn]
	if game.mode == GameState.Mode.VOYAGE:
		status += " · %d pieces left" % game.pieces_left()
	hud.set_status(status)
	hud.set_hint(DEFAULT_HINT)


func _update_hover() -> void:
	var cell := _cell_at_screen(get_viewport().get_mouse_position())
	if not grid.contains(cell) or _dragging:
		ghost.hide_ghost()
		hud.set_info("Open sea")
		return
	var terrain: String = TerrainRules.NAMES[grid.get_terrain(cell)]
	hud.set_info("%s · %s (level %d)" % [terrain, HexGrid.level_name(grid.get_height(cell)), grid.get_height(cell)])
	if _is_touch() and _pending_anchor.x == 1 << 20:
		ghost.hide_ghost()
		return
	var anchor := _pending_anchor if _is_touch() else cell
	if lower_mode:
		ghost.show_cells([_cell_world(anchor, 0.05)], game.can_lower(anchor), true)
		hud.set_hint("Tap a cell to lower it one level (free).")
		return
	var piece := _selected_piece()
	if piece == null:
		ghost.hide_ghost()
		return
	var positions: Array[Vector3] = []
	for c in piece.cells_at(anchor):
		positions.append(_cell_world(c, 0.05))
	var error := game.placement_error(piece, anchor)
	ghost.show_cells(positions, error == "")
	# Explain the spot under the pointer: what it would become, or why not.
	if error == "":
		var h := grid.get_height(anchor)
		hud.set_hint("Raise here: %s → %s." % [HexGrid.level_name(h), HexGrid.level_name(h + 1)])
	else:
		hud.set_hint(error + ".")


func _update_wind_arrow() -> void:
	var cam := camera.camera
	var dir_2d := Hex.to_pixel(Hex.DIRECTIONS[game.wind_dir], 1.0)
	var from := cam.unproject_position(camera.position)
	var to := cam.unproject_position(camera.position + Vector3(dir_2d.x, 0.0, dir_2d.y))
	hud.set_wind_angle((to - from).angle())


func _summary() -> String:
	var counts := {}
	for cell in grid.cells():
		var t: int = grid.get_terrain(cell)
		counts[t] = counts.get(t, 0) + 1
	var lines: Array[String] = ["%d pieces raised over %d turns." % [game.pieces_placed, game.turn - 1], ""]
	for t in [TerrainRules.Terrain.BEACH, TerrainRules.Terrain.MARSH, TerrainRules.Terrain.MEADOW,
			TerrainRules.Terrain.SCRUB, TerrainRules.Terrain.FOREST, TerrainRules.Terrain.HILL_FOREST,
			TerrainRules.Terrain.CLIFF, TerrainRules.Terrain.PEAK, TerrainRules.Terrain.LAGOON]:
		if counts.get(t, 0) > 0:
			lines.append("%s: %d" % [TerrainRules.NAMES[t], counts[t]])
	lines.append("")
	lines.append("Species, habitats and scoring arrive next.")
	return "\n".join(lines)


func _splash(cell: Vector2i) -> void:
	var splash := Splash.new()
	splash.radius = HEX_SIZE
	splash.position = _cell_world(cell, 0.03)
	effects.add_child(splash)


func _is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


## The first finger also arrives as an emulated mouse, so it still taps and pans;
## a second finger turns the gesture into a pinch and cancels the tap.
func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	_pinch_spread = 0.0
	if _touches.size() == 2:
		_pinch_spread = _touch_spread()
		_pinch_centre = _touch_centre()
	if _touches.size() >= 2:
		_dragging = true


func _touch_spread() -> float:
	var points: Array = _touches.values()
	return points[0].distance_to(points[1])


func _touch_centre() -> Vector2:
	var points: Array = _touches.values()
	return (points[0] + points[1]) / 2.0


## The hex under a screen point. Casts against the sea first, then against
## the height of the cell it found, so raised land picks correctly at an angle.
func _cell_at_screen(screen_position: Vector2) -> Vector2i:
	var cell := Vector2i(1 << 20, 0)
	var y := 0.0
	for i in 2:
		var hit: Variant = camera.ground_point(screen_position, y)
		if hit == null:
			return cell
		cell = Hex.from_pixel(Vector2(hit.x, hit.z), HEX_SIZE)
		y = sea.surface_y(cell)
	return cell


func _cell_world(cell: Vector2i, lift := 0.0) -> Vector3:
	var p := Hex.to_pixel(cell, HEX_SIZE)
	return Vector3(p.x, sea.surface_y(cell) + lift, p.y)
