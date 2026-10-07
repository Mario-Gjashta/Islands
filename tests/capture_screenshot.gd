extends SceneTree
## Renders the main scene with a sample island and saves a PNG, for checking
## the look without opening the editor. Needs a real display (or xvfb-run):
##   godot --path . -s res://tests/capture_screenshot.gd -- out.png

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.new_sea(42)
	main.build_sample_island()
	var args_view: String = args[1] if args.size() > 1 else "near"
	if args_view == "near":
		main.camera.position = Vector3(0.0, 0.0, 1.5)
		main.camera.distance = 15.0
	else:
		main.camera.position = Vector3(2.0, 0.0, 0.0)
		main.camera.distance = 30.0
	main.camera.zoom_at(1.0, Vector2.ZERO)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("Saved ", out_path)
	quit()
