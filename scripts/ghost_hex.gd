class_name GhostHex
extends Node3D
## A faint hex under the pointer showing which cell a tap will change.
## It drops out when a tile lands and drifts back in a moment later.

const RAISE_TINT := Color(1.0, 1.0, 1.0)
const LOWER_TINT := Color(0.55, 0.8, 1.0)

var _material := StandardMaterial3D.new()
var _alpha := 0.0
var _target_position := Vector3.ZERO
var _target_alpha := 0.0


func setup(hex_size: float) -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = _build_mesh(hex_size)
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_apply_colour()


func hover(world_position: Vector3, visible_here: bool) -> void:
	if _alpha < 0.05:
		position = world_position
	_target_position = world_position
	_target_alpha = 1.0 if visible_here else 0.0


func set_lowering(lowering: bool) -> void:
	_material.albedo_color = LOWER_TINT if lowering else RAISE_TINT
	_apply_colour()


func on_placed() -> void:
	_alpha = 0.0
	_apply_colour()


func _process(delta: float) -> void:
	position = position.lerp(_target_position, 1.0 - exp(-delta * 25.0))
	_alpha = move_toward(_alpha, _target_alpha, delta * 1.5)
	_apply_colour()


func _apply_colour() -> void:
	_material.albedo_color.a = _alpha


## A faint filled hex with a brighter rim, lying flat on the XZ plane.
func _build_mesh(hex_size: float) -> ArrayMesh:
	var outer := Hex.corners(hex_size * 0.95)
	var inner := Hex.corners(hex_size * 0.86)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fill := Color(1, 1, 1, 0.12)
	var rim := Color(1, 1, 1, 0.6)
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
