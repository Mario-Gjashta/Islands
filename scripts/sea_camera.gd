class_name SeaCamera
extends Camera2D
## Top-down camera: drag or keys to pan, wheel or pinch to zoom at the pointer.

@export var min_zoom := 0.3
@export var max_zoom := 2.5
@export var key_pan_speed := 900.0

## Pan is clamped to this distance from the map centre.
var bounds_radius := 2000.0


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dir += Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	dir = dir.limit_length(1.0)
	if dir != Vector2.ZERO:
		position = _clamped(position + dir * key_pan_speed * delta / zoom.x)


func pan_by_screen(screen_delta: Vector2) -> void:
	position = _clamped(position - screen_delta / zoom.x)


## Zooms by `factor`, keeping the world point under `screen_point` fixed.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var offset_from_centre := screen_point - get_viewport_rect().size / 2.0
	var world_point := position + offset_from_centre / zoom.x
	var new_zoom := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2.ONE * new_zoom
	position = _clamped(world_point - offset_from_centre / new_zoom)


func _clamped(p: Vector2) -> Vector2:
	return p.limit_length(bounds_radius)
