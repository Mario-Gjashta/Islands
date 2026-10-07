class_name ReachOverlay
extends Node3D
## Markers that explain the turn: where the boat can sail, the ring of cells
## it can build in, which of those the selected piece can go on (green), and
## each nearby cell's level, so the slope rule can be read at a glance.

const SAIL_COLOR := Color(0.85, 1.0, 1.0, 0.55)
const PLACE_COLOR := Color(1.0, 1.0, 1.0, 0.1)
const VALID_COLOR := Color(0.55, 1.0, 0.5, 0.32)
const MAX_LABELS := 40

var _sail := MultiMeshInstance3D.new()
var _place := MultiMeshInstance3D.new()
var _valid := MultiMeshInstance3D.new()
var _labels: Array[Label3D] = []


func setup(hex_size: float) -> void:
	_sail.multimesh = _make_multimesh(_disc(hex_size * 0.12, 20))
	_place.multimesh = _make_multimesh(_hex_fill(hex_size * 0.97, PLACE_COLOR))
	_valid.multimesh = _make_multimesh(_hex_fill(hex_size * 0.8, VALID_COLOR))
	for node in [_place, _valid, _sail]:
		node.material_override = _material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	for i in MAX_LABELS:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font_size = 26
		label.outline_size = 8
		label.modulate = Color(1, 1, 1, 0.9)
		label.outline_modulate = Color(0.05, 0.12, 0.2, 0.8)
		label.visible = false
		add_child(label)
		_labels.append(label)


func show_valid(points: Array[Vector3]) -> void:
	_fill(_valid.multimesh, points)


## Level numbers: `levels` maps world positions to the level shown there.
func show_levels(levels: Dictionary) -> void:
	var i := 0
	for point: Vector3 in levels:
		if i >= _labels.size():
			break
		_labels[i].text = str(levels[point])
		_labels[i].position = point + Vector3(0.0, 0.15, 0.0)
		_labels[i].visible = true
		i += 1
	for j in range(i, _labels.size()):
		_labels[j].visible = false


func show_sail(points: Array[Vector3]) -> void:
	_fill(_sail.multimesh, points)


func show_place(points: Array[Vector3]) -> void:
	_fill(_place.multimesh, points)


func _fill(multimesh: MultiMesh, points: Array[Vector3]) -> void:
	multimesh.instance_count = points.size()
	for i in points.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))


func _make_multimesh(mesh: Mesh) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	return multimesh


func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _disc(r: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		for v in [Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * r, Vector3(cos(a1), 0, sin(a1)) * r]:
			st.set_color(SAIL_COLOR)
			st.add_vertex(v)
	return st.commit()


func _hex_fill(size: float, colour: Color) -> ArrayMesh:
	var corners := Hex.corners(size)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		for p in [Vector2.ZERO, corners[i], corners[(i + 1) % 6]]:
			st.set_color(colour)
			st.add_vertex(Vector3(p.x, 0.0, p.y))
	return st.commit()
