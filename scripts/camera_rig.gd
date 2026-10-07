class_name CameraRig
extends Node3D
## Angled camera looking down at a point on the sea. The rig sits on the
## water and the camera orbits it. Zoomed out it looks steeply down like a
## map; zooming in lowers it towards the horizon, so islands stand up against
## the sky.

## Pitch when zoomed all the way in, and all the way out.
@export_range(5.0, 85.0) var near_pitch_degrees := 30.0
@export_range(5.0, 85.0) var far_pitch_degrees := 58.0
@export var distance := 24.0
@export var min_distance := 14.0
@export var max_distance := 55.0
@export var key_pan_speed := 18.0
@export var key_rotate_speed := 1.8

## Pan is clamped to this distance from the map centre.
var bounds_radius := 40.0
## Optional (Vector3 world, float radius) -> float giving the highest ground
## near a point; the camera tilts up to stay this far above it.
var ground_height: Callable
const GROUND_CLEARANCE := 1.2
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
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
		_place_camera()
	elif ground_height.is_valid() and Engine.get_process_frames() % 10 == 0:
		# Land rising under the camera pushes it up too.
		_place_camera()


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
	var zoom_t := inverse_lerp(min_distance, max_distance, distance)
	var pitch := deg_to_rad(lerpf(near_pitch_degrees, far_pitch_degrees, sqrt(zoom_t)))
	camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	# Tilt up until the camera clears any towers it would sit inside.
	if ground_height.is_valid():
		while pitch < deg_to_rad(far_pitch_degrees):
			camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
			var world := global_transform * camera.position
			if world.y > ground_height.call(world, 1.5) + GROUND_CLEARANCE:
				break
			pitch += deg_to_rad(2.0)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _move_to(p: Vector3) -> void:
	var flat := Vector2(p.x, p.z).limit_length(bounds_radius)
	position = Vector3(flat.x, 0.0, flat.y)
	_place_camera()
