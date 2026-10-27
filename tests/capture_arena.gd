extends SceneTree

## CI visual smoke test: render the real arena scene and save a screenshot.
## Run with a display server (for example xvfb-run), not --headless.
func _initialize() -> void:
	call_deferred("_capture_arena")

func _capture_arena() -> void:
	var packed_scene := load("res://scenes/levels/boot_arena.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load boot arena scene.")
		quit(1)
		return

	var scene_instance := packed_scene.instantiate()
	root.add_child(scene_instance)

	# Allow _ready(), one rendered frame, and the first UI layout pass.
	for _frame in range(4):
		await process_frame

	# Regression checks: touch controls must be present and fully inside the viewport.
	var viewport_size := root.get_visible_rect().size
	for control_name in ["joystick_base", "joystick_knob", "attack_button", "blink_button"]:
		var control := scene_instance.get(control_name) as Control
		if control == null:
			push_error("Required mobile control is missing: %s" % control_name)
			quit(1)
			return
		var rect := control.get_global_rect()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
			push_error("Mobile control is outside viewport: %s -> %s" % [control_name, rect])
			quit(1)
			return
	if not (scene_instance.get("joystick_base") is Panel):
		push_error("Joystick base must be a styled circular Panel, not a plain block.")
		quit(1)
		return
	print("VISUAL_SMOKE_CONTROLS=all present and within %s x %s" % [viewport_size.x, viewport_size.y])

	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Arena screenshot capture returned an empty image.")
		quit(1)
		return

	var output_path := "artifacts/ashen-covenant-arena.png"
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save arena screenshot. Error: %s" % save_error)
		quit(1)
		return

	print("VISUAL_SMOKE_SCREENSHOT=%s (%sx%s)" % [output_path, image.get_width(), image.get_height()])
	quit()
