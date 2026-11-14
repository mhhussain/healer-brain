extends GutTest

# Milestone 1: how the hero moves and how the keys map onto the floor.

const HERO := preload("res://scenes/unit.tscn")

var hero: Unit


func before_each():
	hero = HERO.instantiate()
	add_child_autofree(hero)
	await wait_physics_frames(2)


func test_reaches_top_speed_and_holds_it():
	hero.wish = Vector3.RIGHT
	await wait_physics_frames(30)
	assert_almost_eq(hero.velocity.length(), hero.speed, 0.01)
	assert_gt(hero.global_position.x, 3.0, "it has covered ground")
	assert_almost_eq(hero.global_position.y, 0.0, 0.001, "it stays on the floor")


func test_gets_up_to_speed_quickly():
	hero.wish = Vector3.RIGHT
	await wait_physics_frames(8)
	assert_almost_eq(hero.velocity.length(), hero.speed, 0.01, "full speed inside an eighth of a second")


func test_stops_soon_after_the_keys_are_let_go():
	hero.wish = Vector3.RIGHT
	await wait_physics_frames(30)
	hero.wish = Vector3.ZERO
	var from := hero.global_position
	await wait_physics_frames(12)
	assert_eq(hero.velocity, Vector3.ZERO)
	assert_lt(hero.global_position.distance_to(from), 0.6, "it does not slide far")


func test_a_diagonal_is_no_faster():
	hero.wish = Vector3(1, 0, 1)
	await wait_physics_frames(30)
	assert_almost_eq(hero.velocity.length(), hero.speed, 0.01)


func test_turns_to_face_the_way_it_goes():
	hero.wish = Vector3.RIGHT
	await wait_physics_frames(30)
	var looking := -hero.visual.global_basis.z
	assert_almost_eq(looking.x, 1.0, 0.01)


func test_keys_follow_the_camera():
	# the camera in the main scene: looking down from a corner
	var basis := Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(-45), 0))
	var up := Controls.ground_direction(Vector2.UP, basis)
	var right := Controls.ground_direction(Vector2.RIGHT, basis)
	assert_almost_eq(up, Vector3(1, 0, -1).normalized(), Vector3.ONE * 0.001, "W goes up the screen")
	assert_almost_eq(right, Vector3(1, 0, 1).normalized(), Vector3.ONE * 0.001, "D goes to the right of it")
	assert_almost_eq(Controls.ground_direction(Vector2(1, -1), basis).length(), 1.0, 0.001, "two keys are no faster than one")


func test_q_and_e_move_too():
	Controls.install()
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	assert_true(InputMap.action_has_event("move_left", q))
	assert_true(InputMap.action_has_event("move_right", e))
