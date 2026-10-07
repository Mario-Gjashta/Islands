extends Node3D
## First prototype: tap hexes to raise or lower them and watch them melt into
## one soft painted island. Owns input; grid, renderer and effects do the rest.

const HEX_SIZE := 1.0
const GRID_RADIUS := 18
## The sample island, as (cell, layer) rings: a big rock tower in the middle
## stepping down through jungle to white beaches, a wooded island to the
## east, and a few sea stacks standing alone in the water.
const SAMPLE_PROFILE := [8, 6, 5, 4, 3]
const SAMPLE_EXTRAS := {
	Vector2i(1, -1): 8, Vector2i(-1, 0): 7, Vector2i(2, -2): 6,
	Vector2i(6, -3): 5, Vector2i(7, -3): 5, Vector2i(6, -2): 4, Vector2i(7, -4): 4,
	Vector2i(5, -2): 3, Vector2i(8, -4): 3, Vector2i(8, -3): 4, Vector2i(6, -4): 3,
	Vector2i(5, -3): 4, Vector2i(7, -2): 3, Vector2i(8, -5): 6,
	Vector2i(-6, 2): 6, Vector2i(-6, 3): 2, Vector2i(-7, 3): 2,
	Vector2i(2, 5): 6, Vector2i(3, 5): 2,
	Vector2i(-3, -4): 7, Vector2i(-3, -3): 3, Vector2i(-2, -4): 3,
}
## Pointer travel (pixels) before a press counts as a pan instead of a tap.
const DRAG_THRESHOLD := 12.0
## Screen pixels of horizontal drag per radian of rotation.
const ROTATE_DRAG_SCALE := 250.0

var grid: HexGrid
var seed_value := 0
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
	grid = HexGrid.new(GRID_RADIUS)
	grid.generate(seed_value)
	sea.setup(grid, HEX_SIZE)
	hud.set_seed(seed_value)


## Raises a ready-made mountain island in the middle of the sea, to show off
## every layer at once.
func build_sample_island() -> void:
	var island := {}
	for cell in grid.cells():
		var d := Hex.distance(cell, Vector2i.ZERO)
		var wobble := 1 if (cell.x * 7 + cell.y * 13) % 5 == 0 else 0
		if d + wobble < SAMPLE_PROFILE.size():
			island[cell] = SAMPLE_PROFILE[d + wobble]
	island.merge(SAMPLE_EXTRAS, true)
	for cell: Vector2i in island:
		if grid.set_height(cell, island[cell]):
			sea.animate_cell(cell, grid.get_height(cell))


## Raises (delta > 0) or lowers a cell one layer. Returns true if it changed.
func change_cell(cell: Vector2i, delta: int) -> bool:
	if not grid.contains(cell):
		return false
	var height := grid.get_height(cell) + delta
	if not grid.set_height(cell, height):
		return false
	sea.animate_cell(cell, grid.get_height(cell))
	var splash := Splash.new()
	splash.radius = HEX_SIZE
	splash.position = _cell_world(cell, 0.03)
	effects.add_child(splash)
	ghost.on_placed()
	return true


func _process(_delta: float) -> void:
	_update_hover()


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


func _set_lower_mode(lowering: bool) -> void:
	lower_mode = lowering
	ghost.set_lowering(lowering)


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
	ghost.hover(_cell_world(cell, 0.03), inside)
	if grid.contains(cell):
		var height := grid.get_height(cell)
		hud.set_info("%s  (layer %d)   q %d, r %d" % [HexGrid.layer_name(height), height, cell.x, cell.y])
	else:
		hud.set_info("Open sea")
