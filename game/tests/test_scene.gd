extends GutTest

# Milestone 2: the scene and the rules working together in the grey-box room.

var main: Run
var hero: Unit
var enemy: Unit


func before_each():
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	hero = main.get_node("Hero")
	enemy = main.get_node("Enemy")
	await wait_physics_frames(2)


func test_the_units_are_in_the_rules():
	assert_eq(main.player, hero)
	assert_eq(hero.c.name, "Isolde Fenn")
	assert_eq(enemy.c.name, "Drowned Porter")
	assert_eq(enemy.c.home, enemy.global_position)


func test_a_hit_brings_the_enemy_over_to_fight():
	hero.c.target_id = enemy.c.id
	main.combat.press(0)
	await wait_physics_frames(3)
	assert_lt(enemy.c.hp, enemy.c.max_hp)
	var before := enemy.global_position.distance_to(hero.global_position)
	await wait_physics_frames(60)
	assert_lt(enemy.global_position.distance_to(hero.global_position), before - 4.0, "it walks towards the hero")
	await wait_physics_frames(200)
	assert_lt(hero.c.hp, hero.c.max_hp, "and hits back when it arrives")
	assert_lt(enemy.global_position.distance_to(hero.global_position), 2.4)


func test_a_pillar_blocks_the_line_of_sight():
	assert_true(main.combat.sees(hero.c, enemy.c), "clear from the start")
	# straight behind the first pillar, as the enemy sees it
	hero.place(Vector3(4.5, 0, -4))
	await wait_physics_frames(2)
	assert_false(main.combat.sees(hero.c, enemy.c))
	hero.c.target_id = enemy.c.id
	assert_eq(main.combat.use_ability(hero.c, 0, enemy.c), "No line of sight")


func test_clicking_an_enemy_finds_it():
	var cam := get_viewport().get_camera_3d()
	var on_it := cam.unproject_position(enemy.global_position + Vector3(0, 1.0, 0))
	assert_eq(main.enemy_under(cam, on_it), enemy)
	assert_null(main.enemy_under(cam, on_it + Vector2(200, 0)))


func test_jumping_is_only_for_show():
	hero.jump()
	await wait_physics_frames(10)
	assert_gt(hero.lift, 0.5, "the figure is in the air")
	assert_almost_eq(hero.global_position.y, 0.0, 0.001, "but the hero is still on the floor")
	await wait_physics_frames(40)
	assert_eq(hero.lift, 0.0, "and it comes down")


func test_a_dead_enemy_comes_back_at_its_post():
	main.respawn_after = 0.5
	hero.c.target_id = enemy.c.id
	enemy.c.hp = 10.0
	main.combat.press(0)
	await wait_physics_frames(5)
	assert_false(enemy.c.alive)
	await wait_physics_frames(40)
	assert_true(enemy.c.alive)
	assert_eq(enemy.c.hp, enemy.c.max_hp)
