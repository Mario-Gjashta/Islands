class_name Boat
extends Node3D
## The player's boat: a small sailboat that bobs on the water and sails along
## a path of cells, turning to face where it's going.

signal arrived

const STEP_DURATION := 0.45
const HULL_COLOR := Color(0.55, 0.34, 0.2)
const DECK_COLOR := Color(0.78, 0.62, 0.42)
const SAIL_COLOR := Color(0.97, 0.94, 0.86)

var _model := Node3D.new()
var _time := 0.0
var _sailing := false


func _ready() -> void:
	add_child(_model)
	_model.scale = Vector3.ONE * 1.7
	_model.add_child(_part(_hull_mesh(), HULL_COLOR))
	_model.add_child(_part(_deck_mesh(), DECK_COLOR))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.018
	mast.bottom_radius = 0.022
	mast.height = 0.62
	var mast_part := _part(mast, HULL_COLOR.darkened(0.2))
	mast_part.position = Vector3(0.0, 0.4, 0.04)
	_model.add_child(mast_part)
	var sail := _part(_sail_mesh(), SAIL_COLOR)
	(sail.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_model.add_child(sail)


func _process(delta: float) -> void:
	_time += delta
	# Gentle bob and roll; a little more while under way.
	var swell := 1.6 if _sailing else 1.0
	_model.position.y = 0.025 * sin(_time * 2.1) * swell
	_model.rotation.z = 0.05 * sin(_time * 1.7) * swell
	_model.rotation.x = 0.03 * sin(_time * 1.3 + 1.0) * swell


func place_at(world: Vector3) -> void:
	position = world


## Sails through `points` one after another, then emits `arrived`.
func sail(points: Array[Vector3]) -> void:
	if points.is_empty():
		arrived.emit()
		return
	_sailing = true
	var tween := create_tween()
	var from := position
	for p in points:
		var heading := atan2(-(p.x - from.x), -(p.z - from.z))
		tween.tween_property(self, "rotation:y", _nearest_angle(rotation.y, heading), 0.15)
		tween.tween_property(self, "position", p, STEP_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		from = p
	tween.finished.connect(func() -> void:
		_sailing = false
		arrived.emit())


func is_sailing() -> bool:
	return _sailing


func _nearest_angle(current: float, target: float) -> float:
	return current + wrapf(target - current, -PI, PI)


func _part(mesh: Mesh, colour: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	return part


## A pointed hull, bow towards -Z, tapering to a narrow keel.
func _hull_mesh() -> ArrayMesh:
	var top := PackedVector2Array([
		Vector2(0.0, -0.42), Vector2(0.13, -0.2), Vector2(0.15, 0.1),
		Vector2(0.11, 0.3), Vector2(-0.11, 0.3), Vector2(-0.15, 0.1), Vector2(-0.13, -0.2),
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim_y := 0.1
	var keel_y := -0.06
	for i in top.size():
		var a := top[i]
		var b := top[(i + 1) % top.size()]
		var a_top := Vector3(a.x, rim_y, a.y)
		var b_top := Vector3(b.x, rim_y, b.y)
		var a_low := Vector3(a.x * 0.45, keel_y, a.y * 0.85)
		var b_low := Vector3(b.x * 0.45, keel_y, b.y * 0.85)
		for v in [a_top, a_low, b_top, b_top, a_low, b_low]:
			st.add_vertex(v)
		for v in [Vector3(0, keel_y, 0), b_low, a_low]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _deck_mesh() -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.02, 0.5)
	var st := SurfaceTool.new()
	st.create_from(box, 0)
	var mesh := st.commit()
	var transformed := ArrayMesh.new()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0.0, 0.1, 0.04)
	arrays[Mesh.ARRAY_VERTEX] = verts
	transformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return transformed


## A triangular mainsail beside the mast, gently bellied.
func _sail_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := Vector3(0.0, 0.68, 0.04)
	var tack := Vector3(0.0, 0.16, 0.06)
	var clew := Vector3(0.02, 0.16, 0.3)
	var belly := Vector3(0.05, 0.36, 0.14)
	for v in [head, tack, belly, belly, tack, clew, head, belly, clew]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()
