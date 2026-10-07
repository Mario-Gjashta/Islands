extends Node3D
## Sandbox for testing the look: tap a hex to raise it one level, right-click
## (or the Lower toggle) to lower it. Terrain settles from the rules after
## every change.

const HEX_SIZE := 1.0
const GRID_RADIUS := 18
## Pointer travel (pixels) before a press counts as a pan instead of a tap.
const DRAG_THRESHOLD := 12.0

## The sample island: a peak stepping down through every level to beaches,
## a ring island around a lagoon, and a cliff-edged plateau.
const SAMPLE_PROFILE := [6, 5, 4, 3]
const SAMPLE_EXTRAS := {
	Vector2i(-6, 1): 4, Vector2i(-5, 1): 4, Vector2i(-6, 2): 4, Vector2i(-7, 1): 3,
	Vector2i(1, -1): 6, Vector2i(-1, 1): 5, Vector2i(2, -2): 5,
}

var grid: HexGrid
var seed_value := 0
var wind_dir := 0
var lower_mode := false

var _pressing := false
var _dragging := false
var _press_position := Vector2.ZERO
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
	hud.new_sea_requested.connect(func() -> void: new_sea(randi()))
	hud.lower_mode_toggled.connect(_set_lower_mode)
	hud.sample_island_requested.connect(build_sample_island)
	new_sea(randi())


func new_sea(new_seed: int) -> void:
	seed_value = new_seed
	wind_dir = new_seed % 6
	grid = HexGrid.new(GRID_RADIUS)
	grid.generate(seed_value)
	TerrainRules.settle(grid, wind_dir)
	sea.setup(grid, HEX_SIZE)
	hud.set_seed(seed_value)


## Raises a ready-made island to show off every kind of terrain at once.
func build_sample_island() -> void:
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
	_settle()


## Raises (delta > 0) or lowers a cell one level. Returns true if it changed.
func change_cell(cell: Vector2i, delta: int) -> bool:
	if not grid.set_height(cell, grid.get_height(cell) + delta):
		return false
	var splash := Splash.new()
	splash.radius = HEX_SIZE
	splash.position = _cell_world(cell, 0.03)
	effects.add_child(splash)
	ghost.on_placed()
	_settle()
	return true


func _settle() -> void:
	TerrainRules.settle(grid, wind_dir)
	sea.sync_all()


func _process(_delta: float) -> void:
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
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				new_sea(randi())
			KEY_TAB:
				_set_lower_mode(not lower_mode)
				hud.set_lower_mode(lower_mode)


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
					change_cell(_cell_at_screen(event.position), -1 if lower_mode else 1)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				change_cell(_cell_at_screen(event.position), -1)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera.zoom_at(1.1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera.zoom_at(1.0 / 1.1, event.position)


func _set_lower_mode(lowering: bool) -> void:
	lower_mode = lowering
	ghost.set_lowering(lowering)


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


func _update_hover() -> void:
	var cell := _cell_at_screen(get_viewport().get_mouse_position())
	var inside := grid.contains(cell) and not _dragging
	ghost.hover(_cell_world(cell, 0.04), inside)
	if grid.contains(cell):
		var height := grid.get_height(cell)
		hud.set_info("%s · %s (level %d)" % [TerrainRules.NAMES[grid.get_terrain(cell)], HexGrid.level_name(height), height])
	else:
		hud.set_info("Open sea")


func _update_wind_arrow() -> void:
	var cam := camera.camera
	var dir_2d := Hex.to_pixel(Hex.DIRECTIONS[wind_dir], 1.0)
	var from := cam.unproject_position(camera.position)
	var to := cam.unproject_position(camera.position + Vector3(dir_2d.x, 0.0, dir_2d.y))
	hud.set_wind_angle((to - from).angle())
