class_name ReachOverlay
extends Node3D
## Soft markers on the water: where the boat can sail this turn, and the ring
## of cells it can raise land in.

const SAIL_COLOR := Color(0.85, 1.0, 1.0, 0.55)
const PLACE_COLOR := Color(1.0, 1.0, 1.0, 0.11)

var _sail := MultiMeshInstance3D.new()
var _place := MultiMeshInstance3D.new()


func setup(hex_size: float) -> void:
	_sail.multimesh = _make_multimesh(_disc(hex_size * 0.12, 20))
	_place.multimesh = _make_multimesh(_hex_fill(hex_size * 0.97))
	for node in [_place, _sail]:
		node.material_override = _material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


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


func _hex_fill(size: float) -> ArrayMesh:
	var corners := Hex.corners(size)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		for p in [Vector2.ZERO, corners[i], corners[(i + 1) % 6]]:
			st.set_color(PLACE_COLOR)
			st.add_vertex(Vector3(p.x, 0.0, p.y))
	return st.commit()
