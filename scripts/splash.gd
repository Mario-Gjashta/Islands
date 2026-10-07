class_name Splash
extends Node3D
## Foam rings spreading on the water when a tile rises or sinks.

const DURATION := 1.1
const RINGS := 2

var radius := 1.0
var _time := 0.0
var _rings: Array[MeshInstance3D] = []


func _ready() -> void:
	for i in RINGS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.97, 0.97, 0.93, 0.0)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(radius)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	var k := _time / DURATION
	for i in RINGS:
		var rk := clampf(k * 1.25 - i * 0.25, 0.0, 1.0)
		var ring := _rings[i]
		ring.visible = rk > 0.0
		var eased := 1.0 - pow(1.0 - rk, 3.0)
		ring.scale = Vector3.ONE * (0.45 + eased * 0.9)
		(ring.material_override as StandardMaterial3D).albedo_color.a = (1.0 - rk) * 0.8


static func _ring_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48
	var width := r * 0.06
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var o0 := Vector3(cos(a0), 0, sin(a0)) * r
		var o1 := Vector3(cos(a1), 0, sin(a1)) * r
		var i0 := Vector3(cos(a0), 0, sin(a0)) * (r - width)
		var i1 := Vector3(cos(a1), 0, sin(a1)) * (r - width)
		for v in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(v)
	return st.commit()
