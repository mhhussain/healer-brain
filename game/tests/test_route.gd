extends GutTest

# Milestone 10: a route as data, the rules that follow it, and the AI that follows the rules.

const DT := 1.0 / 60.0
const PARTY := ["warden", "mender", "duelist", "ranger"]

var abbey: LevelDef


func before_each():
	abbey = Levels.abbey()


## The Abbey's packs in those pulls, then the rest one at a time.
func plan(pulls: Array) -> Route:
	var r := Route.new()
	r.level = abbey.id
	for packs: Array in pulls:
		r.pulls.append(Route.pull(packs))
	for i in abbey.packs.size():
		if r.pull_of(i) < 0:
			r.pulls.append(Route.pull([i]))
	return r


## The rules in the Abbey with nobody playing: for asking what comes next.
func rules(route: Route = null, player_slot := 3) -> Combat:
	var c := Combat.new(1, 1)
	c.ai_plays = false
	for i in PARTY.size():
		var h := c.add_hero(Heroes.by_id(PARTY[i]), i == player_slot)
		h.pos = abbey.start
	c.enter(abbey, route)
	return c


func kill(c: Combat, pack: int) -> void:
	for e in c.packs[pack].units:
		c.damage(c.heroes[0], e, 9999999.0)
	c.tick(DT)


func ids(packs: Array) -> Array:
	return packs.map(func(p: Pack) -> int: return p.id)


# ---------- the route as data

func test_a_level_comes_with_a_route_of_every_pack_by_itself_in_order():
	var r := Route.default_for(abbey)
	assert_eq(r.level, "abbey")
	assert_eq(r.pulls.size(), 9)
	assert_eq(r.pulls.map(func(p: Dictionary) -> Array: return p.packs), [[0], [1], [2], [3], [4], [5], [6], [7], [8]])
	assert_eq(r.missing(abbey), {"count": 0, "bosses": [] as Array[String]})
	assert_eq(r.completes_at(abbey), 7, "the last pack of keepers meets the count")
	abbey.default_route = [[0, 1], [2]]
	assert_eq(Route.default_for(abbey).pulls.map(func(p: Dictionary) -> Array: return p.packs), [[0, 1], [2]], "or with one written for it")


func test_packs_are_put_in_pulls_and_taken_out_again():
	var r := Route.new()
	r.level = "abbey"
	var first := r.add_pull()
	r.toggle(0, first)
	r.toggle(1, first)
	assert_eq(r.pulls[0].packs, [0, 1], "in the order they were added")
	assert_eq(r.pull_of(1), 0)
	assert_eq(r.pull_of(5), -1)
	r.toggle(0, first)
	assert_eq(r.pulls[0].packs, [1], "a second click takes it out")
	var second := r.add_pull()
	r.toggle(1, second)
	assert_eq(r.pulls.map(func(p: Dictionary) -> Array: return p.packs), [[], [1]], "a pack is in one pull at most")
	r.toggle(2, second)
	assert_eq(r.count_of(abbey, 1), 14, "the Wet Stair, and a boss worth nothing")
	assert_eq(r.missing(abbey).count, 92 - 14)
	assert_eq(r.missing(abbey).bosses, ["Sister Velisse", "Abbot Sulmar"] as Array[String])
	assert_eq(r.completes_at(abbey), -1)
	r.prune()
	assert_eq(r.pulls.size(), 1, "empty pulls are dropped")


func test_pulls_are_put_in_order_inserted_merged_and_deleted():
	var r := plan([[0], [1], [2]])
	r.pulls = r.pulls.slice(0, 3)
	r.move_pull(2, 0)
	assert_eq(r.pulls.map(func(p: Dictionary) -> Array: return p.packs), [[2], [0], [1]])
	assert_eq(r.add_pull(1), 1)
	assert_eq(r.pulls.map(func(p: Dictionary) -> Array: return p.packs), [[2], [], [0], [1]])
	r.remove_pull(1)
	r.set_spot(2, 0, Vector3(40, 0, 2))
	r.pulls[2].note = "hold them by the stair"
	r.merge_up(2)
	assert_eq(r.pulls.map(func(p: Dictionary) -> Array: return p.packs), [[2], [0, 1]])
	assert_eq(r.pulls[1].spots, {0: Vector3(40, 0, 2)}, "the pull it joins takes its spots where it had none")
	assert_eq(r.pulls[1].note, "hold them by the stair")
	r.merge_up(0)
	assert_eq(r.pulls.size(), 2, "the first pull has nothing before it to join")
	assert_eq(r.count_through(abbey, 1), 29)


func test_a_route_survives_being_saved_and_read_back():
	var r := plan([[0, 1], [2]])
	r.name = "Two at the gate"
	r.set_spot(0, 0, Vector3(60.04, 0, 1.26))
	r.set_spot(0, 3, abbey.packs[1].stand)
	r.pulls[1].go = true
	r.pulls[1].note = "straight in"
	var d := r.to_dict()
	assert_eq(d.v, Route.VERSION)
	assert_eq(d.pulls[0], {"packs": [0, 1], "spots": {"0": [60.0, 1.3], "3": [abbey.packs[1].stand.x, abbey.packs[1].stand.z]}})
	assert_eq(d.pulls[1], {"packs": [2], "go": true, "note": "straight in"})
	assert_eq(d.pulls[2], {"packs": [3]}, "what a pull does not use is left out")
	var back := Route.from_dict(JSON.parse_string(JSON.stringify(d)), abbey)
	assert_eq(back.to_dict(), d)
	assert_eq(back.pulls[0].spots[0], Vector3(60.0, 0, 1.3))
	assert_true(back.pulls[1].go)
	assert_eq(r.copy().to_dict(), d)
	var twin := r.copy()
	twin.toggle(0, 0)
	assert_eq(r.pulls[0].packs, [0, 1], "a copy is its own")


func test_a_route_is_shared_as_a_line_of_text():
	var r := plan([[0, 1]])
	r.name = "Double"
	r.set_spot(0, 1, abbey.packs[0].stand)
	var code := r.to_code()
	assert_true(code.begins_with("FF1:"))
	assert_false(code.contains("\n"))
	assert_eq(Route.from_code("  " + code + "\n", abbey).to_dict(), r.to_dict(), "spaces round it do not matter")
	assert_null(Route.from_code("", abbey))
	assert_null(Route.from_code("hello", abbey))
	assert_null(Route.from_code("FF1:not a code!", abbey))
	assert_null(Route.from_code("FF1:" + Marshalls.utf8_to_base64("[1, 2]"), abbey))
	assert_null(Route.from_code(code, Levels.sandbox()), "a route for another place is not a route for this one")


func test_a_route_read_from_outside_keeps_only_what_makes_sense():
	var r := Route.from_dict({"level": "abbey", "name": 7, "pulls": [
		{"packs": [0, 1, 0, 99, -1, "two"], "spots": {"0": [30.0, 1.0], "9": [30.0, 1.0], "1": [9999, 0], "2": "here"}, "go": "yes", "note": 5},
		"nonsense",
		{"packs": [1, 2], "orders": {"kill_first": "shaman"}},
		{},
	]}, abbey)
	assert_eq(r.name, "7")
	assert_eq(r.pulls.size(), 3)
	assert_eq(r.pulls[0].packs, [0, 1], "packs the level has, each once")
	assert_eq(r.pulls[0].spots, {0: Vector3(30, 0, 1)}, "spots for places the party has, on the floor")
	assert_false(r.pulls[0].go)
	assert_eq(r.pulls[0].note, "5")
	assert_eq(r.pulls[1].packs, [2], "a pack already taken is not taken twice; what it does not know of is let go")
	assert_eq(r.pulls[2].packs, [])
	assert_null(Route.from_dict({"level": "abbey"}, abbey))
	assert_null(Route.from_dict("route", abbey))


# ---------- the rules follow it

func test_the_next_pull_is_the_first_with_a_pack_still_standing():
	var c := rules(plan([[1, 0], [2]]))
	var next := c.next_pull()
	assert_eq(next.index, 0)
	assert_eq(ids(next.packs), [1, 0], "in the order they were added")
	kill(c, 0)
	assert_eq(ids(c.next_pull().packs), [1], "a pack already dead is passed over")
	assert_eq(c.next_pull().index, 0)
	kill(c, 1)
	assert_eq(c.next_pull().index, 1)
	assert_eq(ids(c.next_pull().packs), [2])


func test_a_pulls_spots_and_its_hurry_come_with_it():
	var r := plan([[0, 1]])
	r.set_spot(0, 0, Vector3(30, 0, 1))
	r.set_spot(0, 3, Vector3(25, 0, 4))
	r.pulls[0].go = true
	var c := rules(r)
	var next := c.next_pull()
	assert_true(next.go)
	assert_eq(Combat.spot_in(next, c.heroes[0]), Vector3(30, 0, 1))
	assert_eq(Combat.spot_in(next, c.heroes[3]), Vector3(25, 0, 4))
	assert_null(Combat.spot_in(next, c.heroes[1]), "nothing planned for the healer")
	assert_null(Combat.spot_in({}, c.heroes[0]))


func test_when_the_plan_runs_out_the_nearest_pack_is_next():
	var short := Route.new()
	short.level = "abbey"
	short.pulls.append(Route.pull([0]))
	var c := rules(short)
	assert_eq(c.next_pull().index, 0)
	kill(c, 0)
	var next := c.next_pull()
	assert_eq(next.index, -1, "beyond the plan")
	assert_eq(ids(next.packs), [1], "the Wet Stair is the nearest left")
	c.heroes[0].pos = abbey.packs[7].center
	assert_eq(ids(c.next_pull().packs), [7], "nearest to the tank, wherever it has got to")
	c.heroes[0].pos = abbey.lamps[2].pos
	assert_eq(ids(c.next_pull().packs), [5], "by the way there, not as the crow flies: Sister Velisse is in this room")


func test_with_the_count_met_only_bosses_are_left_to_do():
	var empty := Route.new()
	empty.level = "abbey"
	var c := rules(empty)
	c.count_needed = 15
	kill(c, 0)
	assert_eq(c.count(), 15)
	assert_eq(ids(c.next_pull().packs), [2], "Brother Krogg, past the Wet Stair")
	kill(c, 2)
	kill(c, 5)
	assert_eq(ids(c.next_pull().packs), [8])
	kill(c, 8)
	assert_true(c.finished)


func test_a_fight_is_the_pull_it_began_as():
	var r := plan([[0, 1], [2]])
	r.set_spot(0, 0, Vector3(30, 0, 1))
	var c := rules(r)
	assert_eq(c.fight, {})
	assert_true(c.gathered(), "nothing to gather out of a fight")
	c.engage(c.packs[0], c.heroes[0])
	assert_eq(c.fight.index, 0)
	assert_eq(ids(c.fight.packs), [0, 1])
	assert_eq(Combat.spot_in(c.fight, c.heroes[0]), Vector3(30, 0, 1))
	assert_false(c.gathered(), "the Wet Stair still sleeps")
	c.engage(c.packs[1], c.heroes[0])
	assert_true(c.gathered())
	kill(c, 0)
	assert_eq(c.fight.index, 0, "it is the same fight until it is over")
	kill(c, 1)
	assert_eq(c.fight, {})


func test_a_fight_nobody_planned_is_a_pull_of_that_pack_alone():
	var r := plan([[0, 1]])
	r.set_spot(0, 0, Vector3(30, 0, 1))
	var c := rules(r)
	c.engage(c.packs[4], c.heroes[2])
	assert_eq(c.fight.index, -1)
	assert_eq(ids(c.fight.packs), [4])
	assert_true(c.gathered(), "the tank does not go and fetch the rest of the plan")
	assert_null(Combat.spot_in(c.fight, c.heroes[0]))
	kill(c, 4)
	assert_eq(c.next_pull().index, 0, "and then the plan is picked up where it was")


func test_a_pull_that_beats_the_party_is_made_again():
	var c := rules(plan([[0, 1]]))
	c.engage(c.packs[0], c.heroes[0])
	c.engage(c.packs[1], c.heroes[0])
	c.damage(c.heroes[0], c.packs[0].units[0], 9999999.0)
	for h in c.heroes:
		c.damage(c.packs[1].units[0], h, 99999.0, "phys", {"raw": true})
	c.tick(DT)
	assert_eq(c.fight, {})
	assert_false(c.in_combat)
	assert_eq(c.next_pull().index, 0)
	assert_eq(ids(c.next_pull().packs), [0, 1], "both packs stand again")


func test_the_party_holds_its_damage_while_an_ai_tank_gathers():
	var c := rules(plan([[0, 1]]), 3)
	c.engage(c.packs[0], c.heroes[0])
	c.packs[0].tank_hit_at = c.time
	for i in 120:
		c.tick(DT)
	assert_false(c.can_attack(), "one pack of two is awake")
	c.engage(c.packs[1], c.heroes[0])
	assert_false(c.can_attack(), "the tank has only just woken the second")
	c.packs[1].tank_hit_at = c.time
	for i in 100:
		c.tick(DT)
	assert_true(c.can_attack(), "a moment after its first blow on the pack woken last")


func test_nobody_waits_for_ever_on_a_tank_that_does_not_gather():
	var c := rules(plan([[0, 1]]), 3)
	c.engage(c.packs[0], c.heroes[0])
	c.packs[0].tank_hit_at = c.time
	c.time += Combat.GATHER_LIMIT - 1.0
	assert_false(c.can_attack())
	c.time += 1.5
	assert_true(c.can_attack())


func test_with_you_as_the_tank_the_party_goes_when_you_do():
	var c := rules(plan([[0, 1]]), 0)
	assert_true(c.heroes[0].is_player)
	c.engage(c.packs[0], c.heroes[0])
	c.packs[0].tank_hit_at = c.time
	for i in 100:
		c.tick(DT)
	assert_true(c.can_attack(), "whether or not you fetch the second pack is up to you")


# ---------- the AI follows the rules

func test_the_ai_takes_two_packs_together_when_the_plan_says_so():
	var r := AIHarness.new(abbey, PARTY, 1, 1, true, 0, plan([[0, 1]]))
	var c := r.combat
	var first := c.packs[0]
	var second := c.packs[1]
	assert_true(r.run_until(func() -> bool: return second.engaged, 60.0), "the tank goes on to wake the Wet Stair")
	assert_true(first.engaged and not first.cleared, "with the Cloister Walk at its heels")
	var early := r.of("hit").filter(func(e: Dictionary) -> bool:
		var src := c.unit(e.src)
		return src != null and src.hero != null and src.hero.role != "tank" and e.amt > 0.0)
	assert_eq(early.size(), 0, "and nobody else struck a blow while it gathered")
	assert_true(r.run_until(func() -> bool: return first.cleared and second.cleared, 240.0), "eight keepers at once")
	assert_eq(r.of("wipe").size(), 0)
	assert_almost_eq(first.cleared_at, second.cleared_at, 45.0, "one fight, not two")
	assert_true(abbey.same_room(second.stand, c.heroes[0].pos), "fought in the second room, where the last pack was woken")
	assert_eq(c.next_pull().index, 1)


func test_the_ai_tank_holds_the_pull_where_the_plan_says():
	var route := plan([])
	var room: Rect2 = abbey.rooms[1].rect
	var spot := Vector3(room.end.x - 5.0, 0, room.position.y + 4.0)
	route.set_spot(0, 0, spot)
	var r := AIHarness.new(abbey, PARTY, 1, 1, true, 0, route)
	var tank := r.combat.heroes[0]
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 30.0))
	assert_true(r.run_until(func() -> bool: return Combat.flat(tank.pos, spot) < 1.2, 10.0), "it goes to the spot")
	var strayed := 0.0
	while not r.combat.packs[0].cleared and r.combat.time < 200.0:
		r.tick()
		strayed = maxf(strayed, Combat.flat(tank.pos, spot))
	assert_true(r.combat.packs[0].cleared)
	assert_lt(strayed, 1.6, "and stays on it, though the Cantor sings from across the room")
	r.run_until(func() -> bool: return r.combat.in_combat, 60.0)
	r.run_for(6.0)
	assert_true(abbey.same_room(r.combat.packs[1].stand, tank.pos), "with nothing planned for the next pull it goes in as it always did")
	assert_lt(Combat.flat(tank.pos, r.combat.packs[1].stand), 12.0)


func test_a_ranged_hero_waits_and_fights_on_its_planned_spot():
	var route := plan([])
	var door: Vector3 = abbey.doors[0].pos
	var spot := door + Vector3(-3.5, 0, 0)
	route.set_spot(0, 3, spot)
	var r := AIHarness.new(abbey, PARTY, 1, 1, true, 0, route)
	var ranger := r.combat.heroes[3]
	assert_eq(abbey.room_at(spot), 0, "on the landing, looking in through the doorway")
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 30.0))
	assert_lt(Combat.flat(ranger.pos, spot), HeroAI.ON_SPOT, "it was on its spot before the tank pulled")
	var strayed := 0.0
	while not r.combat.packs[0].cleared and r.combat.time < 200.0:
		r.tick()
		strayed = maxf(strayed, Combat.flat(ranger.pos, spot))
	assert_true(r.combat.packs[0].cleared)
	assert_lt(strayed, HeroAI.ON_SPOT, "and it fought from there, not from inside the room")
	assert_gt(ranger.stats.dmg, 1500.0)
	assert_true(r.run_until(func() -> bool: return Combat.dist(ranger, r.combat.heroes[0]) < 10.0, 8.0),
		"with no spot in the next pull it goes with the tank again")


func test_a_planned_spot_that_cannot_do_its_job_is_left_for_one_that_can():
	var route := plan([])
	var landing: Rect2 = abbey.rooms[0].rect
	var spot := Vector3(landing.position.x + 2.0, 0, landing.position.y + 2.0)
	route.set_spot(0, 3, spot)
	route.set_spot(0, 1, spot + Vector3(2, 0, 0))
	var r := AIHarness.new(abbey, PARTY, 1, 1, true, 0, route)
	var ranger := r.combat.heroes[3]
	var healer := r.combat.heroes[1]
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 30.0), "the tank pulls once they are on their spots")
	assert_lt(Combat.flat(ranger.pos, spot), HeroAI.ON_SPOT)
	assert_true(r.run_until(func() -> bool: return r.combat.packs[0].cleared, 200.0))
	assert_eq(r.of("wipe").size(), 0)
	assert_gt(ranger.stats.dmg, 1500.0, "a far corner with a wall in the way: she found somewhere she could throw from")
	assert_gt(healer.stats.heal, 0.0, "and the healer somewhere she could heal from")


func test_a_melee_hero_attacks_from_the_side_of_its_planned_spot():
	var route := plan([])
	var room: Rect2 = abbey.rooms[1].rect
	var stand: Vector3 = abbey.packs[0].stand
	route.set_spot(0, 0, stand)
	var side := Vector3(stand.x, 0, room.position.y + 1.0)
	route.set_spot(0, 2, side)
	var r := AIHarness.new(abbey, ["warden", "mender", "duelist", "duelist"], 1, 1, true, 0, route)
	var planned := r.combat.heroes[2]
	var free := r.combat.heroes[3]
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 30.0))
	r.run_for(10.0)
	var t := r.combat.unit(planned.target_id)
	assert_not_null(t)
	assert_lt(Combat.flat(planned.pos, t.pos), 3.5, "in reach of its target")
	assert_lt(planned.pos.z, t.pos.z - 0.5, "on the side the spot is: towards the back wall")
	assert_gt(Combat.flat(planned.pos, side), 3.0, "not on the spot itself")
	assert_gt(free.stats.dmg, 0.0)


func test_a_pull_marked_go_at_once_does_not_wait_for_the_party():
	var hurry := plan([])
	hurry.pulls[0].go = true
	for route: Route in [plan([]), hurry]:
		var r := AIHarness.new(abbey, PARTY, 1, 1, true, 0, route)
		r.combat.heroes[2].hp = 100.0
		r.combat.heroes[1].res = 0.0
		r.run_for(3.0)
		assert_eq(r.combat.in_combat, route.pulls[0].go, "go at once" if route.pulls[0].go else "wait for the party")


func test_with_no_plan_at_all_the_party_still_clears_the_hall():
	var none := Route.new()
	none.level = "sandbox"
	var r := AIHarness.new(Levels.sandbox(), PARTY, 1, 1, true, 0, none)
	assert_true(r.run_until(func() -> bool: return r.combat.finished, 300.0), "nearest pack first, then the next")
	assert_eq(r.of("wipe").size(), 0)
