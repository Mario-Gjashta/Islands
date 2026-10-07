class_name SeaRenderer
extends Node3D
## Draws the whole sea and its islands with one shader on two planes.
##
## Each cell's displayed state is written into a tiny float texture, one texel
## per hex: R = height level, G = vegetation, B = wetness, A = rock (the
## terrain type's paint fields). The shaders blend neighbouring texels into a
## smooth height field and smooth paint fields, so a cluster of hexes reads as
## one soft island and terrain types melt into each other.

const SEA_SHADER := preload("res://shaders/sea.gdshader")
const TREE_SHADER := preload("res://shaders/trees.gdshader")
const BAKE_SHADER := preload("res://shaders/height_bake.gdshader")
## Height map texels per side; about nine per hex across the map.
const BAKE_SIZE := 640
const RISE_DURATION := 0.7
## Terrain repaints more slowly than land rises, so changes read as settling.
const REPAINT_DURATION := 1.4
## Passed to the shaders, which use them for sea_level and layer_height.
const SEA_LEVEL := 2.5
const LAYER_HEIGHT := 0.42
const MOUNTAIN_RISE := 0.08
## Rock towers: mirror PEAK_BASE and pillar_height in terrain.gdshaderinc.
const TOWER_BASE := 3.0
const TOWER_HEIGHT := 1.1
## Terrain mesh vertices per hex width; more = sharper peaks, more cost.
const VERTS_PER_HEX := 9.0
## Tree candidates scattered per hex; the shader decides which ones grow.
const TREES_PER_HEX := 18
## Headroom for GPU displacement, so culling never clips peaks or trees.
const MAX_RISE := 9.0

var hex_size := 1.0
var grid: HexGrid

var _image: Image
var _texture: ImageTexture
var _dirty := false
var _trees_dirty := false
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
	_image = Image.create(grid.side, grid.side, false, Image.FORMAT_RGBAF)
	for cell in grid.cells():
		_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, _target_state(cell))
	_texture = ImageTexture.create_from_image(_image)
	_dirty = false
	_build_meshes()


## Brings every cell's display in line with the grid: heights rise or sink
## with a little overshoot, terrain types softly repaint.
func sync_all() -> void:
	for cell in grid.cells():
		var current := _display(cell)
		var target := _target_state(cell)
		if not current.is_equal_approx(target):
			animate_cell(cell)


func animate_cell(cell: Vector2i) -> void:
	if _tweens.has(cell):
		_tweens[cell].kill()
	var current := _display(cell)
	var target := _target_state(cell)
	var tween := create_tween().set_parallel()
	tween.tween_method(_tween_display_height.bind(cell), current.r, target.r, RISE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_tween_display_fields.bind(cell), Vector3(current.g, current.b, current.a),
		Vector3(target.g, target.b, target.a), REPAINT_DURATION).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func() -> void:
		_tweens.erase(cell)
		_trees_dirty = true)
	_tweens[cell] = tween
	_trees_dirty = true


func get_display_height(cell: Vector2i) -> float:
	if not grid.contains(cell):
		return 0.0
	return _display(cell).r


func _display(cell: Vector2i) -> Color:
	return _image.get_pixel(cell.x + grid.radius, cell.y + grid.radius)


## What a cell should look like: its height and its terrain's paint fields.
func _target_state(cell: Vector2i) -> Color:
	var fields: Vector3 = TerrainRules.FIELDS[grid.get_terrain(cell)]
	if grid.springs.has(cell):
		fields.y = 1.0
	return Color(grid.get_height(cell), fields.x, fields.y, fields.z)


## World y of a cell's surface (0 at sea level), ignoring blending and peaks.
## Mirrors surface_y() in terrain.gdshaderinc.
func surface_y(cell: Vector2i) -> float:
	var lift := maxf(get_display_height(cell) - SEA_LEVEL, 0.0)
	return lift * LAYER_HEIGHT + pow(maxf(lift - 1.5, 0.0), 1.7) * MOUNTAIN_RISE


## Rough height of the tallest ground within `radius` of a world point,
## including rock towers, for keeping the camera out of the terrain.
## Mirrors the tower and rise maths in terrain.gdshaderinc, approximately.
func max_ground_y(world: Vector3, radius: float) -> float:
	var centre := Hex.from_pixel(Vector2(world.x, world.z), hex_size)
	var reach := int(ceil(radius / (hex_size * Hex.SQRT3))) + 1
	var highest := 0.0
	for dq in range(-reach, reach + 1):
		for dr in range(-reach, reach + 1):
			var cell := centre + Vector2i(dq, dr)
			if not grid.contains(cell):
				continue
			var state := _display(cell)
			var h := state.r + pow(maxf(state.r - TOWER_BASE, 0.0), 1.3) * TOWER_HEIGHT * state.a
			var lift := maxf(h - SEA_LEVEL, 0.0)
			highest = maxf(highest, lift * LAYER_HEIGHT + pow(maxf(lift - 1.5, 0.0), 1.7) * MOUNTAIN_RISE)
	return highest


## Argument order matches Tween.tween_method, which passes the value first.
func _tween_display_height(height: float, cell: Vector2i) -> void:
	var state := _display(cell)
	state.r = height
	_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, state)
	_dirty = true


func _tween_display_fields(fields: Vector3, cell: Vector2i) -> void:
	var state := Color(_display(cell).r, fields.x, fields.y, fields.z)
	_image.set_pixel(cell.x + grid.radius, cell.y + grid.radius, state)
	_dirty = true


func _process(_delta: float) -> void:
	if _trees_dirty and _trees:
		_refresh_trees()
		_trees_dirty = false
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
		if maxf(grid.get_height(c), get_display_height(c)) >= HexGrid.Level.SEA_LEVEL:
			return true
	return false


## A tree canopy: a low-poly squashed sphere, lumpy so neighbours overlap
## into a jungle rather than a field of balls.
func _tree_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.34
	sphere.radial_segments = 8
	sphere.rings = 4
	var st := SurfaceTool.new()
	st.create_from(sphere, 0)
	st.deindex()
	var mesh := st.commit()
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var lump := 1.0 + 0.18 * sin(v.x * 23.0 + v.z * 17.0) * cos(v.y * 19.0)
		mdt.set_vertex(i, Vector3(v.x * lump, v.y * lump + 0.14, v.z * lump))
	mesh.clear_surfaces()
	mdt.commit_to_surface(mesh)
	st.create_from(mesh, 0)
	st.index()
	st.generate_normals()
	return st.commit()
