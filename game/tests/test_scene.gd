extends GutTest

# The scene and the rules working together in the grey-box hall.

var main: Run
var hero: Unit
var enemy: Unit


func before_each():
	Run.place = "sandbox"
	Run.party = ["warden", "mender", "duelist", "ranger"]
	Run.player_slot = 3
	Run.chosen_level = 3
	Run.autoplay = false
	Run.rng_seed = 5
	main = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(main)
	# these tests are about the player's hero; the party stands still unless a test says otherwise
	main.combat.ai_plays = false
	hero = main.player
	enemy = main.unit_of(main.combat.packs[0].units[0].id)
	await wait_physics_frames(2)


func after_all():
	Run.place = "abbey"
	Run.chosen_level = 1
	Run.rng_seed = 0


func test_the_party_and_the_packs_are_built_from_the_level():
	assert_eq(hero.c.name, "Isolde Fenn")
	assert_eq(main.combat.heroes.size(), 4)
	assert_eq(main.combat.packs.size(), 2)
	assert_eq(enemy.c.name, "Drowned Porter")
	assert_eq(enemy.c.home, enemy.global_position)
	assert_gt(main.level.nav_polygons(), 10, "there is a floor to walk on")
	assert_eq(main.camera.target, hero)
	assert_not_null(hero.get_node_or_null("PlayerInput"))
	assert_not_null(enemy.get_node_or_null("Walker"))


func test_units_take_their_size_from_the_rules():
	var prior := main.unit_of(main.combat.packs[1].units[0].id)
	assert_eq(prior.c.name, "The Prior")
	assert_eq(prior.radius, 0.95)
	assert_gt(prior.height, enemy.height)


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
	var pillar: Vector3 = main.level.def.pillars[0].pos
	hero.place(pillar + (pillar - enemy.global_position).normalized() * 2.5)
	await wait_physics_frames(2)
	assert_false(main.combat.sees(hero.c, enemy.c))
	assert_eq(main.level.pillar_between(hero.global_position, enemy.global_position), 0)
	hero.c.target_id = enemy.c.id
	assert_eq(main.combat.use_ability(hero.c, 0, enemy.c), "No line of sight")


func test_a_fallen_pillar_no_longer_blocks_sight_or_the_way():
	var pillar: Vector3 = main.level.def.pillars[0].pos
	hero.place(pillar + (pillar - enemy.global_position).normalized() * 2.5)
	await wait_physics_frames(2)
	assert_false(main.level.can_stand(pillar))
	main.combat.destroy_pillar(0)
	await wait_physics_frames(2)
	assert_true(main.combat.sees(hero.c, enemy.c))
	assert_true(main.level.can_stand(pillar), "you can walk where it stood")
	main.level.restore_pillars()
	await wait_physics_frames(2)
	assert_false(main.combat.sees(hero.c, enemy.c), "and it is back after a wipe")


func test_the_level_knows_where_a_unit_can_stand():
	assert_true(main.level.can_stand(Vector3(2, 0, 0)))
	assert_false(main.level.can_stand(Vector3(26, 0, -5)), "inside the wall between the rooms")
	assert_true(main.level.can_stand(Vector3(26, 0, 0)), "in the doorway")
	assert_false(main.level.can_stand(Vector3(80, 0, 0)), "off the end of the hall")
	assert_true(main.level.clear_walk(Vector3(2, 0, 0), Vector3(20, 0, 0)))
	assert_false(main.level.clear_walk(Vector3(20, 0, -5), Vector3(30, 0, -5)), "through the wall")


func test_an_enemy_walks_round_the_wall_through_the_doorway():
	# from the back corner of the first room, straight at the Prior is through the wall
	hero.place(Vector3(23, 0, -5.5))
	await wait_physics_frames(2)
	var prior := main.unit_of(main.combat.packs[1].units[0].id)
	main.combat.engage(main.combat.packs[1], hero.c)
	var crossed_at := INF
	for i in 600:
		await wait_physics_frames(1)
		if prior.global_position.x < 26.0 and crossed_at == INF:
			crossed_at = prior.global_position.z
		if prior.global_position.distance_to(hero.global_position) < 2.6:
			break
	assert_lt(prior.global_position.distance_to(hero.global_position), 2.6, "it reached the hero")
	assert_between(crossed_at, -2.0, 2.0, "by way of the doorway")


func test_clicking_an_enemy_finds_it():
	var cam := get_viewport().get_camera_3d()
	var on_it := cam.unproject_position(enemy.global_position + Vector3(0, 1.0, 0))
	assert_eq(main.unit_under(cam, on_it, "enemy"), enemy)
	assert_null(main.unit_under(cam, on_it + Vector2(200, 0), "enemy"))
	var on_me := cam.unproject_position(hero.global_position + Vector3(0, 1.0, 0))
	assert_eq(main.unit_under(cam, on_me, "hero"), hero)


func test_a_party_frame_aims_an_ally_ability():
	var tank := main.combat.heroes[0]
	var frame := main.hud.party_frame(0)
	assert_eq(frame.who(), tank)
	frame.mouse_entered.emit()
	await wait_frames(2)
	assert_eq(main.combat.hover_ally_id, tank.id)
	frame.mouse_exited.emit()
	await wait_frames(2)
	assert_ne(main.combat.hover_ally_id, tank.id)


func test_jumping_is_only_for_show():
	hero.jump()
	await wait_physics_frames(10)
	assert_gt(hero.lift, 0.5, "the figure is in the air")
	assert_almost_eq(hero.global_position.y, 0.0, 0.001, "but the hero is still on the floor")
	await wait_physics_frames(40)
	assert_eq(hero.lift, 0.0, "and it comes down")


func test_the_cleared_hall_starts_over():
	main.respawn_after = 0.5
	hero.place(Vector3(40, 0, 0))
	for c in main.combat.packs[0].units:
		main.combat.damage(hero.c, c, 99999.0)
	await wait_physics_frames(50)
	assert_false(enemy.c.alive, "not until every pack is cleared")
	for c in main.combat.packs[1].units:
		main.combat.damage(hero.c, c, 99999.0)
	await wait_physics_frames(50)
	assert_true(enemy.c.alive)
	assert_eq(enemy.c.hp, enemy.c.max_hp)
	assert_almost_eq(enemy.global_position, enemy.c.home, Vector3.ONE * 0.5)
	assert_lt(hero.global_position.x, 3.0, "and the party is back at the start")


func test_a_roll_carries_the_harpooner_back():
	hero.place(Vector3(1, 0, 0))
	await wait_physics_frames(2)
	assert_eq(main.combat.use_ability(hero.c, 4, null), "", "Deck Roll")
	await wait_physics_frames(30)
	# she faces up the hall, so she rolls back towards the start wall and stops against it
	assert_lt(hero.global_position.x, -2.5)
	assert_gt(hero.global_position.x, -4.0, "the wall stops her")
	assert_true(main.combat.has_aura(hero.c, "tumble"))


func test_a_telegraph_is_drawn_and_goes():
	var zones: Node3D = main.get_node("Zones")
	main.combat.add_zone({"kind": "circle", "pos": Vector3(5, 0, 0), "r": 3.0, "delay": 0.3, "dmg": 10.0})
	await wait_frames(3)
	assert_eq(zones.get_child_count(), 1)
	# the same kind of material as the shadow under a unit, so no new shader is built for it:
	# building one froze the game each time a zone appeared
	var patch: StandardMaterial3D = zones.get_child(0).get_child(0).material_override
	var shadow: StandardMaterial3D = hero.shadow.get_surface_override_material(0)
	for setting in ["shading_mode", "transparency", "cull_mode", "blend_mode", "no_depth_test"]:
		assert_eq(patch.get(setting), shadow.get(setting), setting)
	await wait_physics_frames(30)
	await wait_frames(3)
	assert_eq(zones.get_child_count(), 0)


func test_choosing_a_hero_takes_the_place_of_its_role():
	Run.choose("bloomweaver")
	assert_eq(Run.party, ["warden", "bloomweaver", "duelist", "ranger"])
	assert_eq(Run.player_slot, 1)
	Run.choose("ranger")
	assert_eq(Run.party, ["warden", "bloomweaver", "ranger", "duelist"], "no two of the same")
	assert_eq(Run.player_slot, 2)
	Run.choose("warden")
	assert_eq(Run.player_slot, 0)
