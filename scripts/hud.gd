class_name Hud
extends CanvasLayer
## The game's overlay: start menu, status panel with wind compass, the hand of
## land pieces, and the end-of-voyage summary.

signal mode_chosen(mode: GameState.Mode)
signal menu_requested
signal piece_selected(index: int)
signal rotate_requested
signal lower_mode_toggled(lowering: bool)
signal sample_island_requested

var _status_panel: Control
var _status: Label
var _info: Label
var _hint: Label
var _seed: Label
var _wind_arrow: WindArrow
var _sample_button: Button
var _lower_button: Button
var _hand_bar: HBoxContainer
var _cards: Array[PieceCard] = []
var _card_group := ButtonGroup.new()
var _menu: Control
var _end_screen: Control
var _end_text: Label


func _ready() -> void:
	_build_status_panel()
	_build_hand_bar()
	_build_menu()
	_build_end_screen()
	show_menu()


func show_menu() -> void:
	_menu.visible = true
	_end_screen.visible = false
	_status_panel.visible = false
	_hand_bar.get_parent().visible = false


func start_session(mode: GameState.Mode) -> void:
	_menu.visible = false
	_end_screen.visible = false
	_status_panel.visible = true
	_hand_bar.get_parent().visible = true
	_sample_button.visible = mode == GameState.Mode.DRIFT
	_lower_button.visible = mode == GameState.Mode.DRIFT
	set_lower_mode(false)


func show_end(summary: String) -> void:
	_end_text.text = summary
	_end_screen.visible = true
	_hand_bar.get_parent().visible = false


func set_status(text: String) -> void:
	_status.text = text


func set_info(text: String) -> void:
	_info.text = text


func set_hint(text: String) -> void:
	_hint.text = text


func set_seed(seed_value: int) -> void:
	_seed.text = "Seed %d · build %s" % [seed_value, _build_id()]


## Wind direction as an on-screen angle (radians, 0 = right, clockwise).
func set_wind_angle(angle: float) -> void:
	_wind_arrow.angle = angle
	_wind_arrow.queue_redraw()


func set_hand(hand: Array[Piece], selected: int) -> void:
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < hand.size()
		if card.visible:
			card.set_piece(hand[i])
			card.set_pressed_no_signal(i == selected)


func set_lower_mode(lowering: bool) -> void:
	_lower_button.set_pressed_no_signal(lowering)


## The release stamp the deploy workflow writes, or "dev" for local runs.
func _build_id() -> String:
	var file := FileAccess.open("res://build_info.txt", FileAccess.READ)
	return file.get_as_text().strip_edges() if file else "dev"


func _panel_style(alpha := 0.62) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.17, alpha)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	return style


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


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)
	_status_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	title_row.add_child(_label("Island Raiser", 20))
	_wind_arrow = WindArrow.new()
	_wind_arrow.custom_minimum_size = Vector2(28, 28)
	_wind_arrow.tooltip_text = "Wind: windward coasts stay bare, the lee grows lush"
	title_row.add_child(_wind_arrow)
	title_row.add_child(_label("wind", 12, 0.6))
	box.add_child(title_row)

	_status = _label("", 14)
	box.add_child(_status)
	_info = _label("", 14, 0.9)
	box.add_child(_info)
	_hint = _label("", 13, 0.7)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(330, 0)
	box.add_child(_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_button("Menu", menu_requested.emit))
	_sample_button = _button("Sample island", sample_island_requested.emit)
	row.add_child(_sample_button)
	box.add_child(row)

	_seed = _label("", 11, 0.5)
	box.add_child(_seed)


func _build_hand_bar() -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	anchor.add_theme_constant_override("margin_bottom", 16)
	add_child(anchor)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	anchor.add_child(panel)
	_hand_bar = HBoxContainer.new()
	_hand_bar.add_theme_constant_override("separation", 10)
	panel.add_child(_hand_bar)
	for i in GameState.HAND_SIZE:
		var card := PieceCard.new()
		card.button_group = _card_group
		card.pressed.connect(piece_selected.emit.bind(i))
		_hand_bar.add_child(card)
		_cards.append(card)
	var rotate := _button("Rotate", rotate_requested.emit)
	rotate.custom_minimum_size = Vector2(96, 84)
	_hand_bar.add_child(rotate)
	_lower_button = Button.new()
	_lower_button.text = "Lower"
	_lower_button.toggle_mode = true
	_lower_button.focus_mode = Control.FOCUS_NONE
	_lower_button.custom_minimum_size = Vector2(86, 84)
	_lower_button.tooltip_text = "Drift only: lower one cell near the boat (free)"
	_lower_button.toggled.connect(lower_mode_toggled.emit)
	_hand_bar.add_child(_lower_button)


func _build_menu() -> void:
	_menu = _centered_panel()
	var box: VBoxContainer = _menu.get_meta("box")
	box.add_child(_label("Island Raiser", 34))
	var tagline := _label("Sail a small boat, raise land from the seabed, and let the sea and the wind decide what grows.", 15, 0.85)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(420, 0)
	box.add_child(tagline)
	var voyage := _button("Voyage", mode_chosen.emit.bind(GameState.Mode.VOYAGE))
	voyage.custom_minimum_size = Vector2(0, 52)
	box.add_child(voyage)
	box.add_child(_label("%d land pieces. Make every one count." % GameState.VOYAGE_BAG_SIZE, 13, 0.7))
	var drift := _button("Drift", mode_chosen.emit.bind(GameState.Mode.DRIFT))
	drift.custom_minimum_size = Vector2(0, 52)
	box.add_child(drift)
	box.add_child(_label("Endless pieces and free lowering. Just build.", 13, 0.7))


func _build_end_screen() -> void:
	_end_screen = _centered_panel()
	var box: VBoxContainer = _end_screen.get_meta("box")
	box.add_child(_label("Voyage complete", 30))
	_end_text = _label("", 15, 0.9)
	box.add_child(_end_text)
	var again := _button("Sail again", menu_requested.emit)
	again.custom_minimum_size = Vector2(0, 48)
	box.add_child(again)


func _centered_panel() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.82))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	center.set_meta("box", box)
	return center


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
