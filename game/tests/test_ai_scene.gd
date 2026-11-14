extends GutTest

# Milestone 4: the AI party playing the real scene, walking on the navigation mesh.
# Run the tests with --fixed-fps 60 so that these do not take as long as the fights do.

func play(place: String, party: Array, level: int, rng_seed: int) -> Run:
	Run.place = place
	Run.party.assign(party)
	Run.player_slot = 0
	Run.chosen_level = level
	Run.autoplay = true
	Run.rng_seed = rng_seed
	var main: Run = load("res://scenes/run.tscn").instantiate()
	main.endless = false
	watch_signals(main)
	add_child_autofree(main)
	return main


func after_each():
	Run.place = "abbey"
	Run.autoplay = false
	Run.rng_seed = 0
	Run.chosen_level = 1


func test_an_all_ai_party_clears_the_hall():
	var main := play("sandbox", ["warden", "mender", "duelist", "ranger"], 1, 11)
	for i in 60 * 150:
		await wait_physics_frames(1)
		if main.combat.finished:
			break
	assert_true(main.combat.finished, "both rooms cleared")
	assert_eq(main.combat.deaths, 0)
	assert_lt(main.combat.total_time(), 90.0)
	for h in main.combat.heroes:
		assert_gt(main.unit_of(h.id).global_position.x, 26.0, h.name + " ended up in the second room")


func test_the_other_healer_and_the_caster_manage_level_3():
	var main := play("sandbox", ["warden", "bloomweaver", "pyromancer", "ranger"], 3, 12)
	for i in 60 * 200:
		await wait_physics_frames(1)
		if main.combat.finished:
			break
	assert_true(main.combat.finished)
	assert_lt(main.combat.deaths, 2)
	var kicks := 0
	for h in main.combat.heroes:
		kicks += h.stats.interrupts
	assert_gt(kicks, 0, "casts were silenced")


func test_every_room_of_the_abbey_can_be_walked_to():
	var main := play("abbey", ["warden", "mender", "duelist", "ranger"], 1, 1)
	main.combat.ai_plays = false
	await wait_physics_frames(3)
	assert_gt(main.level.nav_polygons(), 50)
	assert_eq(main.combat.packs.size(), 9)
	assert_eq(main.combat.pillars.size(), 10)
	var start: Vector3 = main.level.def.start
	for p in main.combat.packs:
		var way := main.level.path(start, p.stand)
		assert_gt(way.size(), 1, p.name + ": there is a way")
		if way.size() > 1:
			assert_lt(Combat.flat(way[-1], p.stand), 0.6, p.name + ": and it gets there")
		for c in p.units:
			assert_true(main.level.can_stand(c.pos), "%s: %s stands on the floor" % [p.name, c.name])
	var first := main.combat.packs[0]
	var second := main.combat.packs[1]
	assert_false(main.level.sees(first.stand, second.stand), "walls split the rooms")


func test_an_all_ai_party_times_the_abbey_in_the_real_scene():
	var main := play("abbey", ["warden", "mender", "duelist", "ranger"], 1, 21)
	for i in 60 * 60 * 16:
		await wait_physics_frames(1)
		if main.combat.finished:
			break
	assert_true(main.combat.finished, "all nine rooms cleared")
	await wait_physics_frames(2)
	assert_signal_emit_count(main, "finished", 1, "the run says so, once")
	assert_true(main.combat.timed(), "inside 14 minutes: %s" % Kit.clock(main.combat.total_time()))
	assert_lt(main.combat.deaths, 3)
	gut.p("the Abbey in the scene: %s, %d deaths" % [Kit.clock(main.combat.total_time()), main.combat.deaths])
