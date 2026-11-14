extends GutTest

# Milestone 4: the AI party playing the real scene, walking on the navigation mesh.
# Run the tests with --fixed-fps 60 so that these do not take as long as the fights do.

func play(party: Array, level: int, rng_seed: int) -> Run:
	Run.party.assign(party)
	Run.player_slot = 0
	Run.chosen_level = level
	Run.autoplay = true
	Run.rng_seed = rng_seed
	var main: Run = load("res://scenes/main.tscn").instantiate()
	main.sandbox = false
	add_child_autofree(main)
	return main


func after_each():
	Run.autoplay = false
	Run.rng_seed = 0


func test_an_all_ai_party_clears_the_hall():
	var main := play(["warden", "mender", "duelist", "ranger"], 1, 11)
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
	var main := play(["warden", "bloomweaver", "pyromancer", "ranger"], 3, 12)
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
