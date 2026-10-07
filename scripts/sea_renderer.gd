class_name SeaRenderer
extends Node3D
## Draws the whole sea and its islands with one shader on two planes.
##
## Displayed cell heights are written into a tiny float texture (one texel per
## hex). The shader blends neighbouring texels into a smooth height field,
## lifts the land out of a flat sea, and paints it, so a cluster of hexes
## reads as one soft island with a curved, foamy shore.

const SEA_SHADER := preload("res://shaders/sea.gdshader")
const TREE_SHADER := preload("res://shaders/trees.gdshader")
const BAKE_SHADER := preload("res://shaders/height_bake.gdshader")
## Height map texels per side; about seven per hex across the map.
const BAKE_SIZE := 512
const RISE_DURATION := 0.7
## Passed to the shaders, which use them for sea_level and layer_height.
const SEA_LEVEL := 2.5
const LAYER_HEIGHT := 0.42
const MOUNTAIN_RISE := 0.11
## Terrain mesh vertices per hex width; more = sharper peaks, more cost.
const VERTS_PER_HEX := 7.0
## Tree candidates scattered per hex; the shader decides which ones grow.
const TREES_PER_HEX := 8
## Headroom for GPU displacement, so culling never clips peaks or trees.
const MAX_RISE := 6.0

var hex_size := 1.0
var grid: HexGrid

var _image: Image
var _texture: ImageTexture
var _dirty := false
var _tweens := {}
var _terrain: MeshInstance3D
var _ocean: MeshInstance3D
var _trees: MultiMeshInstance3D
var _bake_viewport: SubViewport
var _bake_rect: ColorRect
var _bake_extent := 1.0
## Per cell, the packed transforms (12 floats each) of its tree candidates.
var _tree_slots := {}


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
	tween.finished.connect(func() -> void:
		_tweens.erase(cell)
		_refresh_trees())
	_tweens[cell] = tween
	_refresh_trees()


func get_display_height(cell: Vector2i) -> float:
	if not grid.contains(cell):
		return 0.0
	return _image.get_pixel(cell.x + grid.radius, cell.y + grid.radius).r


## World y of a cell's surface (0 at sea level), ignoring blending and peaks.
## Mirrors surface_y() in terrain.gdshaderinc.
func surface_y(cell: Vector2i) -> float:
	var lift := maxf(get_display_height(cell) - SEA_LEVEL, 0.0)
	return lift * LAYER_HEIGHT + pow(maxf(lift - 1.5, 0.0), 1.7) * MOUNTAIN_RISE


## Argument order matches Tween.tween_method, which passes the value first.
func _tween_display_height(height: float, cell: Vector2i) -> void:
	_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, Color(height, 0.0, 0.0))
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty and _texture:
		_texture.update(_image)
		_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false


func _build_meshes() -> void:
	if _terrain == null:
		_terrain = MeshInstance3D.new()
		_ocean = MeshInstance3D.new()
		_trees = MultiMeshInstance3D.new()
		add_child(_terrain)
		add_child(_ocean)
		add_child(_trees)
		_bake_viewport = SubViewport.new()
		_bake_viewport.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
		_bake_viewport.disable_3d = true
		_bake_viewport.transparent_bg = false
		_bake_rect = ColorRect.new()
		_bake_rect.size = Vector2(BAKE_SIZE, BAKE_SIZE)
		_bake_viewport.add_child(_bake_rect)
		add_child(_bake_viewport)

	# Detailed, displaced plane over the map.
	var map_extent := hex_size * Hex.SQRT3 * (grid.radius + 3) * 2.0
	_bake_extent = map_extent
	_bake_rect.material = _make_material(BAKE_SHADER)
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2.ONE * map_extent
	var subdivisions := int(map_extent / (hex_size * Hex.SQRT3) * VERTS_PER_HEX)
	terrain_mesh.subdivide_width = subdivisions
	terrain_mesh.subdivide_depth = subdivisions
	_terrain.mesh = terrain_mesh
	_terrain.material_override = _make_material(SEA_SHADER)
	_terrain.material_override.set_shader_parameter("displace", true)
	# Displacement happens on the GPU, so widen the culling box to cover it.
	_terrain.extra_cull_margin = MAX_RISE

	# Flat open sea out to the horizon, just under the detailed plane.
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2.ONE * hex_size * 600.0
	_ocean.mesh = ocean_mesh
	_ocean.position.y = -0.02
	_ocean.material_override = _make_material(SEA_SHADER)
	_ocean.material_override.set_shader_parameter("displace", false)
	_ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_scatter_trees()
	_trees.material_override = _make_material(TREE_SHADER)
	_trees.extra_cull_margin = MAX_RISE


func _make_material(shader: Shader) -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("cells", _texture)
	shader_material.set_shader_parameter("hex_size", hex_size)
	shader_material.set_shader_parameter("grid_radius", grid.radius)
	shader_material.set_shader_parameter("sea_level", SEA_LEVEL)
	shader_material.set_shader_parameter("layer_height", LAYER_HEIGHT)
	shader_material.set_shader_parameter("mountain_rise", MOUNTAIN_RISE)
	shader_material.set_shader_parameter("bake_extent", _bake_extent)
	if shader != BAKE_SHADER:
		shader_material.set_shader_parameter("height_map", _bake_viewport.get_texture())
	return shader_material


## Tree candidates at jittered spots on every hex, each with a random turn.
## They sit at y = 0; the tree shader lifts them onto the terrain and decides
## which ones grow.
func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	_tree_slots.clear()
	for cell in grid.cells():
		var centre := Hex.to_pixel(cell, hex_size)
		var slots := PackedFloat32Array()
		for n in TREES_PER_HEX:
			var offset := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * hex_size * 0.85
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			slots.append_array([
				b.x.x, b.y.x, b.z.x, centre.x + offset.x,
				b.x.y, b.y.y, b.z.y, 0.0,
				b.x.z, b.y.z, b.z.z, centre.y + offset.y,
			])
		_tree_slots[cell] = slots
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tree_mesh()
	_trees.multimesh = multimesh
	_refresh_trees()


## Only hand the GPU candidates near ground high enough to grow trees;
## the rest would cost a full vertex pass just to be scaled to nothing.
func _refresh_trees() -> void:
	var buffer := PackedFloat32Array()
	for cell: Vector2i in _tree_slots:
		if _could_grow_trees(cell):
			buffer.append_array(_tree_slots[cell])
	var multimesh := _trees.multimesh
	multimesh.instance_count = buffer.size() / 12
	if multimesh.instance_count > 0:
		multimesh.buffer = buffer


func _could_grow_trees(cell: Vector2i) -> bool:
	for c in [cell] + Hex.neighbors(cell):
		if maxf(grid.get_height(c), get_display_height(c)) >= HexGrid.Layer.MEADOW:
			return true
	return false


## A small low-poly tree: a trunk and two stacked cones of foliage.
## Vertex colour red marks foliage (1) versus trunk (0) for the shader.
func _tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cone(st, 4, 0.035, 0.03, 0.0, 0.14, Color.BLACK)
	_add_cone(st, 6, 0.17, 0.0, 0.08, 0.36, Color.WHITE)
	_add_cone(st, 6, 0.12, 0.0, 0.22, 0.50, Color.WHITE)
	st.generate_normals()
	return st.commit()


func _add_cone(st: SurfaceTool, sides: int, bottom_radius: float, top_radius: float,
		bottom_y: float, top_y: float, colour: Color) -> void:
	for i in sides:
		var a0 := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / sides)
		var a1 := Vector3.RIGHT.rotated(Vector3.UP, TAU * (i + 1) / sides)
		var b0 := a0 * bottom_radius + Vector3.UP * bottom_y
		var b1 := a1 * bottom_radius + Vector3.UP * bottom_y
		var t0 := a0 * top_radius + Vector3.UP * top_y
		var t1 := a1 * top_radius + Vector3.UP * top_y
		var tris := [b0, t0, b1, b1, t0, t1] if top_radius > 0.0 else [b0, t0, b1]
		for v in tris:
			st.set_color(colour)
			st.add_vertex(v)
