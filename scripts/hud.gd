class_name Hud
extends CanvasLayer
## Sandbox overlay: controls hint, hovered-cell readout, wind compass, and the
## Lower, New sea and Sample island buttons.

signal new_sea_requested
signal lower_mode_toggled(lowering: bool)
signal sample_island_requested

var _info: Label
var _seed: Label
var _wind_arrow: WindArrow
var _lower_button: Button


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.17, 0.62)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.add_child(_label("Island Raiser · sandbox", 20))
	_wind_arrow = WindArrow.new()
	_wind_arrow.custom_minimum_size = Vector2(28, 28)
	_wind_arrow.tooltip_text = "Wind: windward coasts stay scrub, the lee grows forest"
	title_row.add_child(_wind_arrow)
	title_row.add_child(_label("wind", 12, 0.6))
	box.add_child(title_row)

	var hint := _label("Tap: raise one level   Right-click: lower\nDrag: pan   Wheel / pinch: zoom   Q / E: rotate   R: new sea", 13, 0.75)
	box.add_child(hint)

	_info = _label("", 15)
	box.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_lower_button = Button.new()
	_lower_button.toggle_mode = true
	_lower_button.focus_mode = Control.FOCUS_NONE
	_lower_button.custom_minimum_size = Vector2(110, 40)
	_lower_button.toggled.connect(func(on: bool) -> void:
		_update_lower_text(on)
		lower_mode_toggled.emit(on))
	row.add_child(_lower_button)
	_update_lower_text(false)
	row.add_child(_button("New sea", new_sea_requested.emit))
	row.add_child(_button("Sample island", sample_island_requested.emit))

	_seed = _label("", 11, 0.5)
	box.add_child(_seed)


func set_info(text: String) -> void:
	_info.text = text


func set_seed(seed_value: int) -> void:
	_seed.text = "Seed %d · build %s" % [seed_value, _build_id()]


## Wind direction as an on-screen angle (radians, 0 = right, clockwise).
func set_wind_angle(angle: float) -> void:
	_wind_arrow.angle = angle
	_wind_arrow.queue_redraw()


## Updates the toggle without re-emitting, for keyboard shortcuts.
func set_lower_mode(lowering: bool) -> void:
	_lower_button.set_pressed_no_signal(lowering)
	_update_lower_text(lowering)


func _update_lower_text(lowering: bool) -> void:
	_lower_button.text = "Mode: Lower" if lowering else "Mode: Raise"


## The release stamp the deploy workflow writes, or "dev" for local runs.
func _build_id() -> String:
	var file := FileAccess.open("res://build_info.txt", FileAccess.READ)
	return file.get_as_text().strip_edges() if file else "dev"


func _label(text: String, font_size: int, alpha := 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(1, 1, 1, alpha)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(110, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	return button


## A small compass arrow showing which way the wind blows on screen.
class WindArrow:
	extends Control
	var angle := 0.0

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, size.x * 0.48, Color(1, 1, 1, 0.12))
		var dir := Vector2.from_angle(angle)
		var tip := c + dir * size.x * 0.38
		var tail := c - dir * size.x * 0.38
		draw_line(tail, tip, Color(1, 1, 1, 0.95), 2.0, true)
		draw_line(tip, tip - dir.rotated(0.5) * 7.0, Color(1, 1, 1, 0.95), 2.0, true)
		draw_line(tip, tip - dir.rotated(-0.5) * 7.0, Color(1, 1, 1, 0.95), 2.0, true)
