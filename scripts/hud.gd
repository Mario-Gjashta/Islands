class_name Hud
extends CanvasLayer
## Prototype overlay: controls hint, hovered-cell readout, mode and new-sea buttons.

signal new_sea_requested
signal lower_mode_toggled(lowering: bool)

var _info: Label
var _seed: Label
var _mode_button: Button


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.18, 0.6)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Island Raiser · prototype"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Tap / left-click: raise   Right-click: lower\nDrag: pan   Wheel / pinch: zoom   Q / E: rotate\nR: new sea   Tab: toggle mode"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	box.add_child(hint)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 15)
	box.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	_mode_button = Button.new()
	_mode_button.toggle_mode = true
	_mode_button.custom_minimum_size = Vector2(120, 40)
	_mode_button.toggled.connect(func(on: bool) -> void:
		_update_mode_text(on)
		lower_mode_toggled.emit(on))
	row.add_child(_mode_button)
	_update_mode_text(false)

	var new_sea := Button.new()
	new_sea.text = "New sea"
	new_sea.custom_minimum_size = Vector2(120, 40)
	new_sea.pressed.connect(new_sea_requested.emit)
	row.add_child(new_sea)

	_seed = Label.new()
	_seed.add_theme_font_size_override("font_size", 12)
	_seed.modulate = Color(1, 1, 1, 0.5)
	box.add_child(_seed)


func set_info(text: String) -> void:
	_info.text = text


func set_seed(seed_value: int) -> void:
	_seed.text = "Seed %d" % seed_value


## Updates the toggle without re-emitting, for keyboard shortcuts.
func set_lower_mode(lowering: bool) -> void:
	_mode_button.set_pressed_no_signal(lowering)
	_update_mode_text(lowering)


func _update_mode_text(lowering: bool) -> void:
	_mode_button.text = "Mode: Lower" if lowering else "Mode: Raise"
