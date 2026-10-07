class_name PieceCard
extends Button
## A hand card showing a land piece's shape as a little cluster of hexes.

const LAND_COLOR := Color(0.93, 0.87, 0.7)
const ROCK_COLOR := Color(0.62, 0.63, 0.65)
const SPRING_COLOR := Color(0.45, 0.75, 0.9)
const EDGE_COLOR := Color(0.2, 0.25, 0.3, 0.9)

var piece: Piece


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(92, 84)
	focus_mode = Control.FOCUS_NONE


func set_piece(new_piece: Piece) -> void:
	piece = new_piece
	tooltip_text = piece.label() if piece else ""
	queue_redraw()


func _draw() -> void:
	if piece == null:
		return
	var size_px := 13.0
	var points: Array[Vector2] = []
	for o in piece.offsets:
		points.append(Hex.to_pixel(o, size_px))
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	var colour := LAND_COLOR
	match piece.kind:
		Piece.Kind.ROCK:
			colour = ROCK_COLOR
		Piece.Kind.SPRING:
			colour = SPRING_COLOR
	var corners := Hex.corners(size_px * 0.92)
	for p in points:
		var poly := PackedVector2Array()
		for c in corners:
			poly.append(size / 2.0 + p - centre + c)
		draw_colored_polygon(poly, colour)
		poly.append(poly[0])
		draw_polyline(poly, EDGE_COLOR, 1.5, true)
	if piece.kind == Piece.Kind.SPRING:
		draw_circle(size / 2.0, 4.0, Color(0.9, 0.97, 1.0))
	elif piece.kind == Piece.Kind.ROCK:
		draw_line(size / 2.0 + Vector2(-4, 3), size / 2.0 + Vector2(0, -5), EDGE_COLOR, 2.0)
		draw_line(size / 2.0 + Vector2(0, -5), size / 2.0 + Vector2(5, 3), EDGE_COLOR, 2.0)
