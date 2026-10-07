extends Node2D
## First prototype: tap hexes to raise or lower them and watch them melt into
## one soft painted island. Owns input; grid, renderer and effects do the rest.

const HEX_SIZE := 48.0
const GRID_RADIUS := 18
## Pointer travel (pixels) before a press counts as a pan instead of a tap.
const DRAG_THRESHOLD := 12.0

var grid: HexGrid
var seed_value := 0
var lower_mode := false

var _pressing := false
var _dragging := false
var _press_position := Vector2.ZERO

@onready var sea: SeaRenderer = $Sea
@onready var effects: Node2D = $Effects
@onready var ghost: GhostHex = $GhostHex
@onready var camera: SeaCamera = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	randomize()
	ghost.setup(HEX_SIZE)
	camera.bounds_radius = HEX_SIZE * GRID_RADIUS * 1.6
	hud.new_sea_requested.connect(func() -> void: new_sea(randi()))
	hud.lower_mode_toggled.connect(_set_lower_mode)
	new_sea(randi())


func new_sea(new_seed: int) -> void:
	seed_value = new_seed
	grid = HexGrid.new(GRID_RADIUS)
	grid.generate(seed_value)
	sea.setup(grid, HEX_SIZE)
	hud.set_seed(seed_value)


## Raises (delta > 0) or lowers a cell one layer. Returns true if it changed.
func change_cell(cell: Vector2i, delta: int) -> bool:
	if not grid.contains(cell):
		return false
	var height := grid.get_height(cell) + delta
	if not grid.set_height(cell, height):
		return false
	sea.animate_cell(cell, grid.get_height(cell))
	var splash := Splash.new()
	splash.position = Hex.to_pixel(cell, HEX_SIZE)
	splash.radius = HEX_SIZE
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
		if _dragging or event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera.pan_by_screen(event.relative)
	elif event is InputEventMagnifyGesture:
		camera.zoom_at(event.factor, event.position)
	elif event is InputEventPanGesture:
		camera.pan_by_screen(-event.delta * 10.0)
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


func _cell_at_screen(screen_position: Vector2) -> Vector2i:
	var world := get_canvas_transform().affine_inverse() * screen_position
	return Hex.from_pixel(world, HEX_SIZE)


func _update_hover() -> void:
	var cell := _cell_at_screen(get_viewport().get_mouse_position())
	var inside := grid.contains(cell) and not _dragging
	ghost.hover(Hex.to_pixel(cell, HEX_SIZE), inside)
	if grid.contains(cell):
		var height := grid.get_height(cell)
		hud.set_info("%s  (layer %d)   q %d, r %d" % [HexGrid.layer_name(height), height, cell.x, cell.y])
	else:
		hud.set_info("Open sea")
