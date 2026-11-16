extends GutTest

# Milestone 5: what is kept between runs.

func test_a_timed_run_unlocks_the_next_level_and_sets_a_best():
	var s := SaveData.new()
	assert_eq(s.unlocked, 1)
	assert_true(s.record(1, "ranger", 480.0, true))
	assert_eq(s.unlocked, 2)
	assert_eq(s.bests["ranger"], {"level": 1, "time": 480.0})
	assert_false(s.record(1, "ranger", 470.0, true), "the same level again unlocks nothing new")
	assert_eq(s.bests["ranger"].time, 470.0, "but a faster time is a new best")
	s.record(1, "ranger", 500.0, true)
	assert_eq(s.bests["ranger"].time, 470.0)
	s.record(2, "warden", 600.0, true)
	assert_eq(s.unlocked, 3, "unlocks are shared by all heroes")
	assert_false(s.bests.has("mender"))
	s.record(2, "ranger", 700.0, true)
	assert_eq(s.bests["ranger"], {"level": 2, "time": 700.0}, "a higher level beats a faster time")


func test_a_run_over_the_time_changes_nothing():
	var s := SaveData.new()
	assert_false(s.record(1, "ranger", 900.0, false))
	assert_eq(s.unlocked, 1)
	assert_true(s.bests.is_empty())


func test_it_survives_the_file_and_back():
	SaveStore.path = "user://test-save.json"
	var s := SaveData.new()
	s.record(3, "pyromancer", 612.5, true)
	s.party.assign(["warden", "bloomweaver", "pyromancer", "duelist"])
	s.slot = 2
	s.level = 4
	SaveStore.store(s)
	var back := SaveStore.load_save()
	assert_eq(back.to_dict(), s.to_dict())
	assert_eq(back.bests["pyromancer"].time, 612.5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	assert_eq(SaveStore.load_save().unlocked, 1, "with no file you start fresh")
	SaveStore.path = "user://fourfold-save.json"


func test_a_damaged_save_falls_back_to_what_is_safe():
	var s := SaveData.from_dict({"unlocked": "7", "bests": {"ranger": {"level": 6, "time": 700}, "nobody": {"level": 9, "time": 1}, "warden": 5},
		"party": ["warden", "mender", "ghost", "ranger"], "slot": 9, "level": 40})
	assert_eq(s.unlocked, 7)
	assert_eq(s.bests.keys(), ["ranger"])
	assert_eq(s.party, ["warden", "mender", "duelist", "ranger"], "a party with a stranger in it is not used")
	assert_eq(s.slot, 3)
	assert_eq(s.level, 7, "never above what is unlocked")
	assert_eq(SaveData.from_dict({}).to_dict(), SaveData.new().to_dict())


func test_routes_are_kept_in_three_slots_for_each_level_and_the_last_used_comes_back():
	var abbey := Levels.abbey()
	var s := SaveData.new()
	assert_eq(s.route_slot(abbey), 0)
	assert_null(s.route_in(abbey, 0), "a slot is empty until something is kept in it")
	assert_eq(s.route_for(abbey).to_dict(), Route.default_for(abbey).to_dict(), "with nothing kept, the level's own route")
	var mine := Route.default_for(abbey)
	mine.name = "Mine"
	mine.merge_up(1)
	mine.set_spot(0, 0, abbey.packs[1].stand)
	s.keep_route(abbey, 2, mine)
	assert_eq(s.route_slot(abbey), 2)
	assert_eq(s.route_for(abbey).to_dict(), mine.to_dict())
	assert_null(s.route_in(abbey, 1))
	assert_eq(s.route_for(Levels.sandbox()).level, "sandbox", "each level has its own")
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.to_dict(), s.to_dict())
	assert_eq(back.route_for(abbey).name, "Mine")
	assert_eq(back.route_for(abbey).pulls[0].spots[0], abbey.packs[1].stand)
	back.use_slot(abbey, 0)
	assert_eq(back.route_for(abbey).name, Route.default_for(abbey).name, "an empty slot gives the level's own route")
	back.keep_route(abbey, 2, null)
	assert_null(back.route_in(abbey, 2))


func test_the_save_says_which_version_it_is_and_an_older_one_still_reads():
	var s := SaveData.new()
	assert_eq(s.to_dict().v, SaveData.VERSION)
	var old := s.to_dict()
	old.erase("v")
	old.erase("routes")
	old.erase("markers")
	old.erase("place")
	old.erase("progress")
	old["unlocked"] = 4
	var read := SaveData.from_dict(old)
	assert_eq(read.unlocked, 4)
	assert_true(read.markers)
	assert_eq(read.routes, {})


func test_routes_with_nonsense_in_them_do_no_harm():
	var abbey := Levels.abbey()
	var s := SaveData.from_dict({"muted": "yes", "markers": 0, "routes": {"abbey": {"used": 7, "slots": ["x", {"level": "sandbox", "pulls": []}, {"level": "abbey", "pulls": [{"packs": [1, 0]}]}, 4]},
		"nowhere": "y", 5: {}, "sandbox": {"slots": 3}}})
	assert_false(s.muted)
	assert_true(s.markers)
	assert_eq(s.route_slot(abbey), 2)
	assert_eq(s.route_for(abbey).pulls[0].packs, [1, 0])
	assert_null(s.route_in(abbey, 0))
	assert_null(s.route_in(abbey, 1), "a route for somewhere else is not used here")
	assert_eq(s.routes.keys(), ["abbey"])
	assert_null(s.routes.abbey.slots[1], "nor kept")
