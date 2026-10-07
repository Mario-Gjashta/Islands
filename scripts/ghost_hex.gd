class_name GhostHex
extends Node2D
## A faint hex under the pointer showing which cell a tap will change.
## It drops out when a tile lands and drifts back in a moment later.

const RAISE_TINT := Color(1.0, 1.0, 1.0)
const LOWER_TINT := Color(0.55, 0.8, 1.0)

var _corners := PackedVector2Array()
var _tint := RAISE_TINT
var _target_position := Vector2.ZERO
var _target_alpha := 0.0


func setup(hex_size: float) -> void:
	_corners = Hex.corners(hex_size * 0.94)
	modulate.a = 0.0
	queue_redraw()


func hover(world_position: Vector2, visible_here: bool) -> void:
	if modulate.a < 0.05:
		position = world_position
	_target_position = world_position
	_target_alpha = 1.0 if visible_here else 0.0


func set_lowering(lowering: bool) -> void:
	_tint = LOWER_TINT if lowering else RAISE_TINT
	queue_redraw()


func on_placed() -> void:
	modulate.a = 0.0


func _process(delta: float) -> void:
	position = position.lerp(_target_position, 1.0 - exp(-delta * 25.0))
	modulate.a = move_toward(modulate.a, _target_alpha, delta * 1.5)


func _draw() -> void:
	if _corners.is_empty():
		return
	draw_colored_polygon(_corners, Color(_tint, 0.10))
	var outline := _corners.duplicate()
	outline.append(_corners[0])
	draw_polyline(outline, Color(_tint, 0.5), 2.0, true)
