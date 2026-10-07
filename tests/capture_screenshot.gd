extends SceneTree
## Renders the main scene with a sample island and saves a PNG, for checking
## the look without opening the editor. Needs a real display (or xvfb-run):
##   godot --path . -s res://tests/capture_screenshot.gd -- out.png

## A mountain island: summit in the middle, falling away through every layer,
## with a lower wooded island to the east.
const MOUNTAIN_PROFILE := [8, 7, 6, 5, 4, 3]
const EAST_ISLAND := {
	Vector2i(6, -3): 5, Vector2i(7, -3): 5, Vector2i(6, -2): 4, Vector2i(7, -4): 4,
	Vector2i(5, -2): 3, Vector2i(8, -4): 3, Vector2i(8, -3): 4, Vector2i(6, -4): 3,
	Vector2i(5, -3): 4, Vector2i(7, -2): 3,
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.new_sea(42)
	var island := EAST_ISLAND.duplicate()
	for cell in main.grid.cells():
		var d := Hex.distance(cell, Vector2i.ZERO)
		var wobble := 1 if (cell.x * 7 + cell.y * 13) % 5 == 0 else 0
		if d + wobble < MOUNTAIN_PROFILE.size():
			island[cell] = MOUNTAIN_PROFILE[d + wobble]
	island[Vector2i(1, -1)] = 8
	for cell in island:
		var target: int = island[cell]
		while main.grid.get_height(cell) != target:
			main.change_cell(cell, signi(target - main.grid.get_height(cell)))
	main.camera.position = Vector3(3.0, 0.0, -1.0)
	main.camera.distance = 24.0
	main.camera.zoom_at(1.0, Vector2.ZERO)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("Saved ", out_path)
	quit()
