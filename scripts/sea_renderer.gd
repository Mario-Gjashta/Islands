class_name SeaRenderer
extends Node3D
## Draws the whole sea and its islands with one shader on two planes.
##
## Displayed cell heights are written into a tiny float texture (one texel per
## hex). The shader blends neighbouring texels into a smooth height field,
## lifts the land out of a flat sea, and paints it, so a cluster of hexes
## reads as one soft island with a curved, foamy shore.

const SEA_SHADER := preload("res://shaders/sea.gdshader")
const RISE_DURATION := 0.7
## Must match the shader's sea_level and layer_height.
const SEA_LEVEL := 2.5
const LAYER_HEIGHT := 0.55
## Terrain mesh vertices per hex width; more = smoother hills, more cost.
const VERTS_PER_HEX := 5.0

var hex_size := 1.0
var grid: HexGrid

var _image: Image
var _texture: ImageTexture
var _dirty := false
var _tweens := {}
var _terrain: MeshInstance3D
var _ocean: MeshInstance3D


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
	_build_meshes()


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
	if not grid.contains(cell):
		return 0.0
	return _image.get_pixel(cell.x + grid.radius, cell.y + grid.radius).r


## World y of a cell's surface (0 at sea level), ignoring blending.
func surface_y(cell: Vector2i) -> float:
	return maxf(get_display_height(cell) - SEA_LEVEL, 0.0) * LAYER_HEIGHT


## Argument order matches Tween.tween_method, which passes the value first.
func _tween_display_height(height: float, cell: Vector2i) -> void:
	_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, Color(height, 0.0, 0.0))
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and _texture:
		_texture.update(_image)
		_dirty = false


func _build_meshes() -> void:
	if _terrain == null:
		_terrain = MeshInstance3D.new()
		_ocean = MeshInstance3D.new()
		add_child(_terrain)
		add_child(_ocean)

	# Detailed, displaced plane over the map.
	var map_extent := hex_size * Hex.SQRT3 * (grid.radius + 3) * 2.0
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2.ONE * map_extent
	var subdivisions := int(map_extent / (hex_size * Hex.SQRT3) * VERTS_PER_HEX)
	terrain_mesh.subdivide_width = subdivisions
	terrain_mesh.subdivide_depth = subdivisions
	_terrain.mesh = terrain_mesh
	_terrain.material_override = _make_material(true)
	# Displacement happens on the GPU, so widen the culling box to cover it.
	_terrain.extra_cull_margin = LAYER_HEIGHT * 4.0

	# Flat open sea out to the horizon, just under the detailed plane.
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2.ONE * hex_size * 600.0
	_ocean.mesh = ocean_mesh
	_ocean.position.y = -0.02
	_ocean.material_override = _make_material(false)
	_ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_material(displace: bool) -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SEA_SHADER
	shader_material.set_shader_parameter("cells", _texture)
	shader_material.set_shader_parameter("hex_size", hex_size)
	shader_material.set_shader_parameter("grid_radius", grid.radius)
	shader_material.set_shader_parameter("displace", displace)
	shader_material.set_shader_parameter("sea_level", SEA_LEVEL)
	shader_material.set_shader_parameter("layer_height", LAYER_HEIGHT)
	return shader_material
