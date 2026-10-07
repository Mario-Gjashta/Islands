class_name SeaRenderer
extends Node2D
## Draws the whole sea and its islands with one shader.
##
## Displayed cell heights are written into a tiny float texture (one texel per
## hex). The shader blends neighbouring texels into a smooth height field, so a
## cluster of hexes reads as one soft island with a curved, foamy shore.

const SEA_SHADER := preload("res://shaders/sea.gdshader")
const RISE_DURATION := 0.7

var hex_size := 48.0
var grid: HexGrid

var _image: Image
var _texture: ImageTexture
var _dirty := false
var _tweens := {}


func setup(new_grid: HexGrid, new_hex_size: float) -> void:
	for tween: Tween in _tweens.values():
		tween.kill()
	_tweens.clear()
	grid = new_grid
	hex_size = new_hex_size
	_image = Image.create(grid.side, grid.side, false, Image.FORMAT_RF)
	for cell in grid.cells():
		_tween_display_height(grid.get_height(cell), cell)
	_texture = ImageTexture.create_from_image(_image)
	_dirty = false

	var shader_material := ShaderMaterial.new()
	shader_material.shader = SEA_SHADER
	shader_material.set_shader_parameter("cells", _texture)
	shader_material.set_shader_parameter("hex_size", hex_size)
	shader_material.set_shader_parameter("grid_radius", grid.radius)
	material = shader_material
	queue_redraw()


## Tweens a cell's displayed height to its new layer, with a little overshoot.
func animate_cell(cell: Vector2i, target: int) -> void:
	if _tweens.has(cell):
		_tweens[cell].kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_tween_display_height.bind(cell), get_display_height(cell),
		float(target), RISE_DURATION)
	tween.finished.connect(func() -> void: _tweens.erase(cell))
	_tweens[cell] = tween


func get_display_height(cell: Vector2i) -> float:
	return _image.get_pixel(cell.x + grid.radius, cell.y + grid.radius).r


## Argument order matches Tween.tween_method, which passes the value first.
func _tween_display_height(height: float, cell: Vector2i) -> void:
	_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, Color(height, 0.0, 0.0))
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and _texture:
		_texture.update(_image)
		_dirty = false


func _draw() -> void:
	if grid == null:
		return
	# Cover the map plus a wide margin of open sea; the shader paints it all.
	var extent := hex_size * (grid.radius + 12) * 2.0
	draw_rect(Rect2(-extent, -extent, extent * 2.0, extent * 2.0), Color.WHITE)
