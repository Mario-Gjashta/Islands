class_name Splash
extends Node2D
## Foam ripple and droplets thrown up when a tile rises or sinks.

const DURATION := 1.1

var radius := 40.0
var _time := 0.0
var _droplets: Array[Vector2] = []


func _ready() -> void:
	for i in 9:
		var angle := randf() * TAU
		_droplets.append(Vector2(cos(angle), sin(angle)) * randf_range(0.6, 1.2))


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _time / DURATION
	for ring in 2:
		var rk := clampf(k * 1.25 - ring * 0.25, 0.0, 1.0)
		if rk <= 0.0:
			continue
		var eased := 1.0 - pow(1.0 - rk, 3.0)
		var alpha := (1.0 - rk) * 0.75
		draw_arc(Vector2.ZERO, radius * (0.45 + eased * 0.9), 0.0, TAU, 64,
			Color(0.97, 0.97, 0.93, alpha), 1.0 + 4.0 * (1.0 - rk), true)
	var drop_k := clampf(k * 2.2, 0.0, 1.0)
	for dir in _droplets:
		var lift := sin(drop_k * PI) * radius * 0.25
		var pos := dir * radius * (0.3 + drop_k * 0.8) - Vector2(0.0, lift)
		draw_circle(pos, 3.0 * (1.0 - drop_k) + 0.5, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - drop_k)))
