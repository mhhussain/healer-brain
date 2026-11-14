extends GutTest

# Milestone 0: the project is set up the way the web export needs it.

func test_renderer_is_compatibility():
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_tick_is_60_hz():
	assert_eq(Engine.physics_ticks_per_second, 60)


func test_the_game_starts_at_the_app():
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/app.tscn")


func test_the_run_has_an_isometric_camera():
	var run: Node = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	var cam := run.get_node_or_null("Camera") as Camera3D
	assert_not_null(cam, "the run has a camera")
	assert_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL)
	# about 45 degrees down
	assert_almost_eq(cam.global_transform.basis.z.y, 0.7071, 0.01)
