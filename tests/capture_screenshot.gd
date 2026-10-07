extends SceneTree
## Renders the main scene with a sample island and saves a PNG, for checking
## the look without opening the editor. Needs a real display (or xvfb-run):
##   godot --path . -s res://tests/capture_screenshot.gd -- out.png

const ISLAND := {
	Vector2i(0, 0): 5, Vector2i(1, 0): 4, Vector2i(0, 1): 4, Vector2i(-1, 1): 4,
	Vector2i(-1, 0): 4, Vector2i(0, -1): 4, Vector2i(1, -1): 3, Vector2i(2, -1): 3,
	Vector2i(2, 0): 3, Vector2i(1, 1): 3, Vector2i(-2, 1): 3, Vector2i(-2, 2): 3,
	Vector2i(-1, 2): 3, Vector2i(0, 2): 2, Vector2i(-2, 0): 3, Vector2i(-1, -1): 3,
	Vector2i(3, -2): 2, Vector2i(4, -2): 3, Vector2i(4, -3): 3, Vector2i(5, -3): 4,
	Vector2i(5, -4): 3, Vector2i(6, -4): 2, Vector2i(-4, 3): 3, Vector2i(3, 1): 2,
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.new_sea(42)
	for cell in ISLAND:
		var target: int = ISLAND[cell]
		while main.grid.get_height(cell) != target:
			main.change_cell(cell, signi(target - main.grid.get_height(cell)))
	main.camera.position = Vector3(1.5, 0.0, 0.0)
	main.camera.distance = 20.0
	main.camera.zoom_at(1.0, Vector2.ZERO)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("Saved ", out_path)
	quit()
