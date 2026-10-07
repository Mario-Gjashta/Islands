class_name CameraRig
extends Node3D
## Angled camera looking down at a point on the sea, like a tabletop view.
## The rig sits on the water; the camera orbits it at a fixed pitch.

@export_range(20.0, 85.0) var pitch_degrees := 50.0
@export var distance := 24.0
@export var min_distance := 11.0
@export var max_distance := 55.0
@export var key_pan_speed := 18.0
@export var key_rotate_speed := 1.8

## Pan is clamped to this distance from the map centre.
var bounds_radius := 40.0
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 400.0
	add_child(camera)
	_place_camera()


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		var move := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, rotation.y)
		_move_to(position + move * key_pan_speed * delta * distance / 24.0)
	var spin := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if spin != 0.0:
		rotation.y += spin * key_rotate_speed * delta


## Point on the horizontal plane at height `y` under a screen position.
func ground_point(screen_point: Vector2, y := 0.0) -> Variant:
	var origin := camera.project_ray_origin(screen_point)
	var normal := camera.project_ray_normal(screen_point)
	return Plane(Vector3.UP, y).intersects_ray(origin, normal)


## Drags the world so the point under `from` ends up under `to`.
func pan_screen(from: Vector2, to: Vector2) -> void:
	var a: Variant = ground_point(from)
	var b: Variant = ground_point(to)
	if a != null and b != null:
		_move_to(position + (a - b))


## Zooms by `factor` (>1 = closer), keeping the point under `screen_point` fixed.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before: Variant = ground_point(screen_point)
	distance = clampf(distance / factor, min_distance, max_distance)
	_place_camera()
	var after: Variant = ground_point(screen_point)
	if before != null and after != null:
		_move_to(position + (before - after))


func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _move_to(p: Vector3) -> void:
	var flat := Vector2(p.x, p.z).limit_length(bounds_radius)
	position = Vector3(flat.x, 0.0, flat.y)
