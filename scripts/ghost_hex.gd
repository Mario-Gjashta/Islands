class_name GhostHex
extends Node3D
## A faint outline of the piece under the pointer, one hex per cell. White
## where it can be raised, red where it can't. It drops out when a piece lands
## and drifts back in a moment later.

const VALID_TINT := Color(1.0, 1.0, 1.0)
const INVALID_TINT := Color(1.0, 0.45, 0.4)
const LOWER_TINT := Color(0.55, 0.8, 1.0)
const MAX_CELLS := 4

var _material := StandardMaterial3D.new()
var _hexes: Array[MeshInstance3D] = []
var _alpha := 0.0
var _target_alpha := 0.0


func setup(hex_size: float) -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := _build_mesh(hex_size)
	for i in MAX_CELLS:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visible = false
		add_child(instance)
		_hexes.append(instance)
	_apply_colour()


## Shows the ghost over `positions` (world, one per cell).
func show_cells(positions: Array[Vector3], valid: bool, lowering := false) -> void:
	for i in _hexes.size():
		var hex := _hexes[i]
		hex.visible = i < positions.size()
		if hex.visible:
			if _alpha < 0.05:
				hex.position = positions[i]
			hex.set_meta("target", positions[i])
	_material.albedo_color = LOWER_TINT if lowering else (VALID_TINT if valid else INVALID_TINT)
	_target_alpha = 1.0 if not positions.is_empty() else 0.0
	_apply_colour()


func hide_ghost() -> void:
	_target_alpha = 0.0


func on_placed() -> void:
	_alpha = 0.0
	_apply_colour()


func _process(delta: float) -> void:
	for hex in _hexes:
		if hex.visible and hex.has_meta("target"):
			hex.position = hex.position.lerp(hex.get_meta("target"), 1.0 - exp(-delta * 25.0))
	_alpha = move_toward(_alpha, _target_alpha, delta * 2.5)
	_apply_colour()


func _apply_colour() -> void:
	_material.albedo_color.a = _alpha


## A faint filled hex with a brighter rim, lying flat on the XZ plane.
func _build_mesh(hex_size: float) -> ArrayMesh:
	var outer := Hex.corners(hex_size * 0.95)
	var inner := Hex.corners(hex_size * 0.84)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fill := Color(1, 1, 1, 0.14)
	var rim := Color(1, 1, 1, 0.7)
	for i in 6:
		var j := (i + 1) % 6
		_tri(st, Vector2.ZERO, inner[i], inner[j], fill)
		_tri(st, inner[i], outer[i], outer[j], rim)
		_tri(st, inner[i], outer[j], inner[j], rim)
	return st.commit()


func _tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, colour: Color) -> void:
	for p in [a, b, c]:
		st.set_color(colour)
		st.add_vertex(Vector3(p.x, 0.0, p.y))
