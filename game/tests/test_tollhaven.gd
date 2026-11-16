extends GutTest

# Milestone 11: Tollhaven. The level's shape, its gate and its patrols, finding a way round
# packs, the four new enemies and the four bosses, and levels kept for each dungeon.

const DT := 1.0 / 60.0
const PARTY := ["warden", "mender", "duelist", "ranger"]
const TEMP_SAVE := "user://test-tollhaven-save.json"

# packs of Tollhaven, by their place in its list
const WATCH := 0
const NET_ROW := 2
const NET_MENDERS := 3
const BRINE_VATS := 6
const SMOKE_RACKS := 7
const HASK := 8
const CORROW := 16
const GARROW := 20
const KEEPER := 25

var combat: Combat
var pack: Pack
var events: Array[Dictionary]


func after_all():
	Run.place = "abbey"
	Run.route = null
	Run.autoplay = false
	Run.rng_seed = 0
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.party.assign(PARTY)


## A run of the rules alone with those heroes in a row from the origin, and one empty pack.
func start(hero_ids: Array, level := 1) -> void:
	combat = Combat.new(level, 7)
	combat.endless = true
	combat.ai_plays = false
	events = []
	combat.event.connect(func(e: Dictionary) -> void: events.append(e))
	for i in hero_ids.size():
		var h := combat.add_hero(Heroes.by_id(hero_ids[i]), i == 0)
		h.pos = Vector3(-i * 1.5, 0, 0)
	pack = combat.add_pack()


func enemy(def_id: String, at: Vector3) -> Combatant:
	return combat.spawn_enemy(def_id, at, 0)


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)


func run_until(what: Callable, at_most := 30.0) -> bool:
	for i in roundi(at_most / DT):
		if what.call():
			return true
		combat.tick(DT)
	return what.call()


func of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.k == kind)


func hits_on(u: Combatant) -> Array:
	return of("hit").filter(func(e: Dictionary) -> bool: return e.id == u.id).map(func(e: Dictionary) -> float: return e.amt)


# Puts a pack to rest at once, as if it had been fought and beaten.
func fell(c: Combat, id: int) -> void:
	c.engage(c.packs[id], c.heroes[0])
	for u in c.packs[id].units:
		if u.alive:
			c._kill(u)
	c._update_combat()


# A run of Tollhaven on the rules alone, with the party standing together at a spot.
func harness_at(at: Vector3, level := 1, plan: Route = null) -> AIHarness:
	var r := AIHarness.new(Levels.tollhaven(), PARTY, level, 3, true, 0, plan)
	for h in r.combat.heroes:
		h.pos = at + Vector3((h.slot % 2) * 1.6, 0, (h.slot / 2) * 1.6)
	return r


# ---------- the place

func test_tollhaven_is_a_market_three_wings_and_a_light():
	var l := Levels.tollhaven()
	assert_eq(l.id, "tollhaven")
	assert_eq(l.rooms.size(), 18)
	assert_eq(l.packs.size(), 26)
	assert_eq(l.packs.filter(func(p: Dictionary) -> bool: return p.boss).size(), 4)
	assert_eq(l.packs.filter(func(p: Dictionary) -> bool: return p.has("path")).size(), 3, "three patrols")
	assert_eq(l.time_limit, 25 * 60.0)
	assert_eq(l.lamps.size(), 5, "one at the start and one by each boss")
	var held := 0
	for i in l.packs.size():
		held += l.pack_count(i)
	assert_almost_eq(float(held) / l.count_goal(), 1.3, 0.02, "it holds about three tenths more than it asks for")
	for d in l.doors:
		assert_ne(d.a, d.b)
		for room: int in [d.a, d.b]:
			assert_true((l.rooms[room].rect as Rect2).grow(0.01).intersects(d.rect), "a doorway meets both its rooms")
	assert_eq(Levels.abbey().time_limit, 14 * 60.0, "the Abbey keeps its fourteen minutes")
	assert_eq(Levels.DUNGEONS, ["abbey", "tollhaven"] as Array[String])
	assert_eq(Levels.by_name("tollhaven").name, "Tollhaven")


func test_every_pack_can_be_stood_at_seen_and_pulled():
	var l := Levels.tollhaven()
	for i in l.packs.size():
		var p: Dictionary = l.packs[i]
		assert_eq(l.room_at(p.center), p.room, p.name + " is in its room")
		for post in LevelDef.posts(p):
			assert_true(l.can_stand(post), p.name + ": a post is on clear floor")
		assert_true(l.can_stand(p.pull_from), p.name + " can be pulled from clear floor")
		assert_true(l.can_stand(p.stand), p.name + " can be held on clear floor")
		assert_lt(Combat.flat(p.pull_from, p.center), 26.0, p.name + " is within a hail of where it is pulled from")
		assert_true(LevelDef.posts(p).any(func(post: Vector3) -> bool: return l.clear_line(p.pull_from, post, 1.3)), p.name + " can be seen from there")
		for path_spot: Vector3 in p.get("path", []):
			assert_eq(l.room_at(path_spot), p.room, p.name + " keeps to its room")
		for k in i:
			assert_gt(Combat.flat(p.center, l.packs[k].center), 16.0, "%s and %s stand apart" % [p.name, l.packs[k].name])
	for lamp in l.lamps:
		assert_true(l.can_stand(lamp.pos), "a party can start again at " + lamp.name)


func test_a_run_takes_its_time_limit_from_the_place():
	var r := AIHarness.new(Levels.tollhaven(), PARTY)
	assert_eq(r.combat.time_limit, 25 * 60.0)
	r.combat.finished = true
	r.combat.elapsed = 20 * 60.0
	assert_true(r.combat.timed(), "twenty minutes is in time here")
	var abbey := AIHarness.new(Levels.abbey(), PARTY)
	abbey.combat.finished = true
	abbey.combat.elapsed = 20 * 60.0
	assert_false(abbey.combat.timed(), "and not in the Abbey")


# ---------- the gate

func test_the_mole_gate_is_shut_until_three_bosses_rest():
	var r := AIHarness.new(Levels.tollhaven(), PARTY)
	var c := r.combat
	var l := r.level
	var door: Vector3 = l.doors[l.gates[0].door].pos
	assert_true(c.locked(c.packs[KEEPER]))
	assert_false(c.locked(c.packs[WATCH]))
	assert_false(l.reachable(l.start, l.packs[KEEPER].center))
	assert_false(l.can_stand(door), "nobody stands in a shut gate")
	assert_false(l.clear_line(door + Vector3(0, 0, -4), door + Vector3(0, 0, 4), 1.3), "or sees through one")
	# a plan that begins with the Keeper passes him over
	var plan := Route.new()
	plan.level = l.id
	plan.pulls = [Route.pull([KEEPER]), Route.pull([WATCH])]
	c.route = plan
	assert_eq(c.next_pull().index, 1)
	fell(c, HASK)
	fell(c, CORROW)
	assert_true(c.locked(c.packs[KEEPER]), "two are not enough")
	assert_eq(r.of("gate").size(), 0)
	fell(c, GARROW)
	assert_false(c.locked(c.packs[KEEPER]))
	assert_eq(r.of("gate").size(), 1)
	assert_true(r.of("alert").any(func(e: Dictionary) -> bool: return e.s == "The Mole gate stands open."))
	assert_true(l.reachable(l.start, l.packs[KEEPER].center))
	assert_true(l.can_stand(door))
	assert_eq(c.next_pull().index, 0, "and now he is next")
	assert_false(c.finished, "the count is still to be met")


func test_once_the_plan_runs_out_the_keeper_waits_for_his_gate():
	var r := AIHarness.new(Levels.tollhaven(), PARTY)
	var c := r.combat
	c.route = Route.new()
	c.count_needed = 1
	fell(c, WATCH)
	assert_true(c.count() >= c.count_goal())
	var next: Pack = c.next_pull().packs[0]
	assert_true(next.boss, "with the count met, only bosses are left to do")
	assert_ne(next, c.packs[KEEPER], "and not the one behind the gate")


# ---------- patrols

func test_a_patrol_walks_its_round_until_it_is_woken():
	var r := AIHarness.new(Levels.tollhaven(), PARTY)
	var c := r.combat
	c.ai_plays = false
	var watch := c.packs[WATCH]
	var was := watch.at
	r.run_for(3.0)
	assert_almost_eq(Combat.flat(was, watch.at), Combat.PATROL_SPEED * 3.0, 0.1, "at a walk")
	for u in watch.units:
		assert_lt(Combat.flat(u.pos, watch.at + u.post), 1.0, u.name + " keeps step")
	assert_eq(watch.pull_from, watch.at, "the tank goes to wherever it has got to")
	r.run_for(60.0)
	assert_eq(r.level.room_at(watch.at), watch.room, "round and round its own room")
	assert_gt(watch.path_i + 1, 0)
	assert_false(watch.engaged, "nobody came near")
	c.engage(watch, c.heroes[0])
	var stopped := watch.at
	r.run_for(1.0)
	assert_eq(watch.at, stopped, "woken, it walks no further")


# ---------- finding the way

func test_a_way_goes_round_a_sleeping_pack_where_it_can_and_through_it_where_it_cannot():
	var l := Levels.tollhaven()
	var ways := Paths.new(l)
	# through the Smokehouse from its south door to its north, with the Brine Vats asleep
	var vats: Dictionary = l.packs[BRINE_VATS]
	ways.avoid([{"id": BRINE_VATS, "at": vats.center, "r": Paths.watch(4), "room": vats.room}])
	var south := Vector3(9, 0, 89)
	var north := Vector3(19, 0, 57)
	assert_true(ways.threatened(south, north), "the straight way is too near them")
	var path := ways.way(south, north)
	assert_gt(path.size(), 5)
	assert_eq(path[-1], north)
	assert_eq(ways.wakes(path), [] as Array[int], "but there is a way round")
	for stop in path:
		assert_gt(Combat.flat(stop, vats.center), Combat.AGGRO + LevelDef.RING, "out of their notice all the way")
	assert_false(ways.threatened(Vector3(11, 0, 125), Vector3(11, 0, 100)), "a walk in another room is no matter")
	# Net Row watches the door from the market: the only way to the Drying Yard that does not
	# wake it is right round the town, by Gutter Lane
	var row: Dictionary = l.packs[NET_ROW]
	ways.avoid([{"id": NET_ROW, "at": row.center, "r": Paths.watch(5), "room": row.room}])
	var round := ways.way(Vector3(77, 0, 103), Vector3(37, 0, 103))
	assert_eq(ways.wakes(round), [] as Array[int])
	assert_gt(round.size() * Paths.CELL, 150.0, "a long walk for forty metres")
	for stop in round:
		assert_ne(l.room_at(stop), row.room, "that never sets foot in Net Row")
	# and to a spot it stands over there is no way but through it
	assert_eq(ways.wakes(ways.way(Vector3(77, 0, 103), Vector3(66, 0, 103))), [NET_ROW] as Array[int])
	# and a shut gate is no way at all
	assert_true(ways.way(l.start, l.packs[KEEPER].center).is_empty())
	ways.open_door(l.gates[0].door)
	assert_false(ways.way(l.start, l.packs[KEEPER].center).is_empty())


func test_a_pack_does_not_watch_through_a_wall():
	var l := Levels.tollhaven()
	var ways := Paths.new(l)
	# the Chandlery is against the wall the market is behind
	var chandlery: Dictionary = l.packs[11]
	ways.avoid([{"id": 11, "at": chandlery.center, "r": Paths.watch(4), "room": chandlery.room}])
	var a := Vector3(118, 0, 97)
	var b := Vector3(106, 0, 97)
	assert_lt(Combat.flat(Vector3(109, 0, 97), chandlery.center), Paths.watch(4), "near enough, were there no wall")
	assert_eq(ways.wakes(ways.way(a, b)), [] as Array[int])


func test_the_safe_way_wakes_nothing_it_does_not_mean_to():
	var l := Levels.tollhaven()
	var safe := Route.default_for(l)
	assert_eq(safe.pulls.size(), 26)
	assert_eq(safe.missing(l), {"count": 0, "bosses": [] as Array[String]})
	assert_eq(Paths.check(l, safe, l.start), [] as Array[Dictionary])


func test_a_route_is_told_what_it_cannot_walk_past_and_what_is_behind_the_gate():
	var l := Levels.tollhaven()
	var without_guard := Route.default_for(l)
	without_guard.remove_pull(without_guard.pull_of(NET_ROW))
	var wrong := Paths.check(l, without_guard, l.start)
	assert_eq(wrong.size(), 1)
	assert_eq(wrong[0].wakes, [NET_ROW] as Array[int], "Net Row guards the way west")
	assert_eq(wrong[0].pull, without_guard.pull_of(NET_MENDERS))
	var without_corner := Route.default_for(l)
	without_corner.remove_pull(without_corner.pull_of(NET_MENDERS))
	assert_eq(Paths.check(l, without_corner, l.start), [] as Array[Dictionary], "the Net Menders can be left in their corner")
	var keeper_first := Route.default_for(l)
	keeper_first.move_pull(keeper_first.pull_of(KEEPER), 0)
	var gated := Paths.check(l, keeper_first, l.start)
	assert_eq(gated.size(), 1)
	assert_eq(gated[0].pull, 0)
	assert_eq(gated[0].gate, "The Mole gate")
	assert_true(l.shut.has(l.gates[0].door), "trying a route leaves the level's gates as they were")
	# Keel Street stands between its far door and the market: left standing at the end of the
	# safe way, it sends the party right back round by the Ropewalk
	var without_street := Route.default_for(l)
	without_street.remove_pull(without_street.pull_of(24))
	var long := Paths.check(l, without_street, l.start)
	assert_eq(long.size(), 1)
	assert_eq(long[0].pull, without_street.pull_of(KEEPER))
	assert_eq(long[0].wakes, [] as Array[int], "nothing is woken")
	assert_eq(long[0].round, [24] as Array[int])
	assert_gt(long[0].metres, 200.0, "but it is a long walk")


func test_the_party_walks_round_a_pack_that_is_not_in_the_plan():
	var plan := Route.new()
	plan.level = "tollhaven"
	plan.pulls = [Route.pull([SMOKE_RACKS])]
	# at the Smokehouse's south door, with the Brine Vats between it and the Smoke Racks
	var r := harness_at(Vector3(10, 0, 92), 1, plan)
	var c := r.combat
	assert_true(r.run_until(func() -> bool: return c.packs[SMOKE_RACKS].engaged, 40.0), "the Smoke Racks are pulled")
	assert_false(c.packs[BRINE_VATS].engaged, "and the Brine Vats sleep on")
	assert_true(r.run_until(func() -> bool: return c.packs[SMOKE_RACKS].cleared, 120.0))
	assert_false(c.packs[BRINE_VATS].engaged, "through the whole fight")
	assert_eq(c.deaths, 0)


func test_nobody_is_led_onto_ground_a_sleeping_pack_watches():
	var plan := Route.new()
	plan.level = "tollhaven"
	plan.pulls = [Route.pull([SMOKE_RACKS])]
	var r := harness_at(Vector3(9, 0, 88), 1, plan)
	var c := r.combat
	c.ai_plays = false
	var duelist := c.heroes[2]
	var vats: Vector3 = r.level.packs[BRINE_VATS].center
	# a spot well inside the Brine Vats' notice: walked towards, it is never reached
	var wanted := Vector3(17, 0, 80)
	assert_lt(Combat.flat(wanted, vats), Combat.AGGRO)
	for i in 400:
		var stop := c.steer(duelist, wanted)
		duelist.pos = duelist.pos.move_toward(stop, 8.5 / 60.0)
		c.time += 1.0 / 60.0
	assert_gt(Combat.flat(duelist.pos, vats), Combat.AGGRO + LevelDef.RING, "it stops short")
	assert_lt(Combat.flat(duelist.pos, wanted), 9.0, "as near as it may come")
	assert_false(c.packs[BRINE_VATS].engaged)
	# a spot that is clear is walked to as ever
	var clear := Vector3(8, 0, 76)
	for i in 300:
		duelist.pos = duelist.pos.move_toward(c.steer(duelist, clear), 8.5 / 60.0)
		c.time += 1.0 / 60.0
	assert_lt(Combat.flat(duelist.pos, clear), 0.5)


# ---------- the keepers of Tollhaven

func test_everything_the_new_enemies_do_is_written_out_and_each_has_a_mark():
	for id: String in ["deckhand", "crier", "mate", "dredger", "hask", "net", "corrow", "garrow", "keeper"]:
		var e := Enemies.by_id(id)
		assert_gt(e.traits.size(), 0, e.name + " does something")
		var told := {}
		for t: Array in e.traits:
			assert_eq(t.size(), 3, "%s: a name, what it does and a level" % e.name)
			assert_gt((t[1] as String).length(), 15, "%s: %s is explained" % [e.name, t[0]])
			told[t[0]] = t[2]
		for ab in e.abilities:
			assert_true(told.has(ab.name), "%s: %s is written out" % [e.name, ab.name])
			assert_eq(told.get(ab.name), maxi(1, ab.min_level), "%s: %s begins at the level it says" % [e.name, ab.name])
	for p in Levels.tollhaven().packs:
		for id: String in p.enemies:
			assert_true(Enemies.by_id(id).boss or MapView.ENEMY_MARKS.has(id), id + " has a mark on the map")
			assert_not_null(Figures.scene_for(id), id + " has a figure to wear")
	assert_eq(Enemies.by_id("deckhand").count, 1, "a deckhand is worth little")
	assert_lt(Enemies.by_id("deckhand").hp * 2.5, Enemies.by_id("brute").hp, "and is soon dealt with")


func test_a_shipwrights_mate_turns_aside_what_comes_at_its_front():
	start(["duelist", "warden"])
	var d := combat.heroes[0]
	var w := combat.heroes[1]
	var mate := enemy("mate", Vector3(10, 0, 0))
	mate.facing = Vector3.RIGHT
	d.pos = Vector3(12, 0, 0)
	assert_eq(combat.damage(d, mate, 100.0), 40.0, "from the front, two fifths")
	assert_true(of("text").any(func(e: Dictionary) -> bool: return e.s == "Shielded"))
	d.pos = Vector3(8, 0, 0)
	assert_eq(combat.damage(d, mate, 100.0), 100.0, "from behind, all of it")
	d.pos = Vector3(10, 0, 3)
	assert_eq(combat.damage(d, mate, 100.0), 100.0, "and from the side")
	# the tank in front of it is hated as much as if every blow had landed whole
	w.pos = Vector3(12, 0, 0)
	combat.damage(w, mate, 100.0)
	var before: float = mate.threat[w.id]
	assert_eq(combat.damage(w, mate, 100.0), 40.0)
	assert_almost_eq(mate.threat[w.id] - before, 100.0 * w.hero.threat_mult, 0.01)
	assert_eq(combat.damage(mate, w, 100.0), 100.0, "its own blows are as they were")


func test_a_tide_crier_wakes_the_nearest_sleeping_pack_but_never_a_boss():
	start(["ranger"])
	var h := combat.player
	var crier := enemy("crier", Vector3(15, 0, 0))
	var near := combat.add_pack("The Near Pack")
	near.at = Vector3(15, 0, 20)
	combat.spawn_enemy("brute", near.at, near.id)
	var far := combat.add_pack("The Far Pack")
	far.at = Vector3(15, 0, 32)
	combat.spawn_enemy("brute", far.at, far.id)
	var boss := combat.add_pack("A boss", true)
	boss.at = Vector3(15, 0, -12)
	combat.spawn_enemy("krogg", boss.at, boss.id)
	combat.engage(pack, h)
	assert_true(run_until(func() -> bool: return crier.cast != null, 8.0))
	assert_eq(crier.cast.name, "Cry the Hour")
	assert_true(crier.cast.interruptible)
	assert_eq(crier.cast.importance, 2, "a cast the party must stop")
	assert_true(run_until(func() -> bool: return near.engaged, 4.0))
	assert_false(far.engaged, "only the nearest")
	assert_false(boss.engaged, "and never a boss, however near")
	assert_true(of("alert").any(func(e: Dictionary) -> bool: return e.s == "The hour is cried. The Near Pack wakes!"))
	assert_gt(near.units[0].threat.size(), 0, "what it wakes comes for the party")


func test_a_silenced_cry_wakes_nothing_and_with_nothing_to_wake_there_is_no_cry():
	start(["ranger"])
	var h := combat.player
	var crier := enemy("crier", Vector3(15, 0, 0))
	var near := combat.add_pack("The Near Pack")
	near.at = Vector3(15, 0, 20)
	combat.spawn_enemy("brute", near.at, near.id)
	combat.engage(pack, h)
	assert_true(run_until(func() -> bool: return crier.cast != null, 8.0))
	combat.interrupt(h, crier)
	run_for(4.0)
	assert_false(near.engaged)
	# too far to hear
	start(["ranger"])
	crier = enemy("crier", Vector3(15, 0, 0))
	var distant := combat.add_pack("Out of hearing")
	distant.at = Vector3(15, 0, 60)
	combat.spawn_enemy("brute", distant.at, distant.id)
	combat.engage(pack, combat.player)
	run_for(12.0)
	assert_null(crier.cast, "it has nobody to cry to")
	assert_false(distant.engaged)


func test_a_dredger_drags_in_whoever_stands_furthest_off():
	start(["warden", "ranger", "mender"])
	var w := combat.heroes[0]
	var far := combat.heroes[1]
	var nearer := combat.heroes[2]
	var dredger := enemy("dredger", Vector3(3, 0, 0))
	far.pos = Vector3(-16, 0, 0)
	nearer.pos = Vector3(-9, 0, 0)
	combat.engage(pack, w)
	assert_true(run_until(func() -> bool: return not of("yank").is_empty(), 8.0))
	assert_eq(of("yank")[0].id, far.id)
	assert_lt(Combat.dist(far, dredger), 3.0, "to its feet")
	assert_eq(nearer.pos, Vector3(-9, 0, 0))
	assert_true(hits_on(far).has(130.0), "with a blow for good measure")
	# with everyone close there is nobody to hook
	start(["warden", "ranger"])
	dredger = enemy("dredger", Vector3(3, 0, 0))
	combat.heroes[1].pos = Vector3(-3, 0, 0)
	combat.engage(pack, combat.heroes[0])
	run_for(10.0)
	assert_eq(of("yank").size(), 0)
	# nor anyone it cannot see
	start(["warden", "ranger"])
	dredger = enemy("dredger", Vector3(3, 0, 0))
	var hidden := combat.heroes[1]
	hidden.pos = Vector3(-16, 0, 0)
	combat.los = func(a: Vector3, b: Vector3) -> bool: return a != hidden.pos and b != hidden.pos
	combat.engage(pack, combat.heroes[0])
	run_for(10.0)
	assert_eq(of("yank").size(), 0)


# ---------- zones that stay, move and turn

func test_a_lane_holds_what_is_along_it_and_a_turning_cone_what_it_is_about_to_sweep():
	var lane := Zone.make({"kind": "lane", "pos": Vector3(10, 0, 10), "r": 20.0, "dir": Vector3.RIGHT, "half": 3.0})
	assert_true(lane.holds(Vector3(25, 0, 12)))
	assert_true(lane.holds(Vector3(-8, 0, 8)))
	assert_false(lane.holds(Vector3(25, 0, 14)), "beside it")
	assert_false(lane.holds(Vector3(31, 0, 10)), "past its end")
	assert_true(lane.holds(Vector3(25, 0, 13.4), 0.6), "a margin widens it")
	var cone := Zone.make({"kind": "cone", "r": 20.0, "dir": Vector3.RIGHT, "half": 0.3, "turn": 0.4})
	var ahead := Vector3(cos(0.7), 0, sin(0.7)) * 10.0
	var behind := Vector3(cos(-0.7), 0, sin(-0.7)) * 10.0
	assert_false(cone.holds(ahead), "it is not there yet")
	assert_true(cone.holds(ahead, 0.4), "but it is coming, and the AI knows")
	assert_false(cone.holds(behind, 0.4), "where it has been is safe")
	cone.turn = -0.4
	assert_true(cone.holds(behind, 0.4), "turned the other way, the other side")


# ---------- Mother Hask

func test_mother_hask_nets_a_hero_until_the_net_is_cut():
	start(["warden", "mender", "duelist"])
	var w := combat.heroes[0]
	var hask := enemy("hask", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var held := func() -> Array: return combat.heroes.filter(func(h: Combatant) -> bool: return combat.held(h))
	assert_true(run_until(func() -> bool: return not held.call().is_empty(), 12.0))
	assert_eq(held.call().size(), 1, "one at a time below level 6")
	var caught: Combatant = held.call()[0]
	assert_ne(caught, w, "never whoever she is fighting")
	assert_eq(combat.use_ability(caught, 0, hask), "You are held fast")
	var nets := combat.enemies.filter(func(e: Combatant) -> bool: return e.enemy.id == "net")
	assert_eq(nets.size(), 1)
	var net: Combatant = nets[0]
	assert_true(net.engaged and net.summoned, "the net is a target, and worth nothing")
	assert_eq(net.max_hp, 1000.0)
	assert_eq(net.pos, caught.pos)
	assert_true(of("alert").any(func(e: Dictionary) -> bool: return e.s == caught.name + " is netted. Cut the net!"))
	var hp := caught.hp
	run_for(2.1)
	assert_lt(caught.hp, hp, "it squeezes")
	combat.damage(w, net, 99999.0)
	assert_false(combat.held(caught), "cut down, it lets go")
	assert_ne(combat.use_ability(caught, 0, hask), "You are held fast")
	run_for(14.0)
	assert_eq(of("yank").size(), 0, "with no net there is nothing to haul")


func test_haul_drags_the_netted_to_her_feet_and_strikes_round_her():
	start(["warden", "mender"])
	var w := combat.heroes[0]
	var m := combat.heroes[1]
	m.pos = Vector3(-15, 0, 0)
	var hask := enemy("hask", Vector3(3, 0, 0))
	combat.engage(pack, w)
	assert_true(run_until(func() -> bool: return combat.held(m), 12.0))
	var netted_at := combat.time
	assert_true(run_until(func() -> bool: return not of("yank").is_empty(), 16.0))
	assert_almost_eq(combat.time - netted_at, 12.5, 0.6, "ten seconds to cut the net, and the haul itself")
	assert_lt(Combat.dist(m, hask), 4.0)
	assert_true(hits_on(m).has(280.0), "and the blow lands on all within reach")
	assert_true(hits_on(w).has(280.0))
	assert_true(combat.held(m), "still netted")
	var net: Combatant = combat.enemies.filter(func(e: Combatant) -> bool: return e.enemy.id == "net")[0]
	assert_eq(net.pos, m.pos, "and the net has come with them, where a sweep can reach it")


func test_from_level_6_she_nets_two_and_her_nets_fall_with_her():
	start(["warden", "mender", "duelist", "ranger"], 6)
	var w := combat.heroes[0]
	var hask := enemy("hask", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var held := func() -> int: return combat.heroes.filter(func(h: Combatant) -> bool: return combat.held(h)).size()
	assert_true(run_until(func() -> bool: return held.call() > 0, 12.0))
	assert_eq(held.call(), 2)
	for net: Combatant in combat.enemies.filter(func(e: Combatant) -> bool: return e.enemy.id == "net"):
		assert_eq(net.max_hp, roundf(roundf(1000.0 * combat.scale) * 0.5), "each half as stout as one alone")
	combat.damage(w, hask, 9999999.0)
	assert_eq(held.call(), 0, "everyone is let go")
	combat._update_combat()
	assert_true(pack.cleared, "and nothing is left standing")


# ---------- Exciseman Corrow

# Lets Corrow fight for a while and counts the casts of his Audit, silencing the first.
func audit(level: int) -> Dictionary:
	start(["warden", "mender"], level)
	var w := combat.heroes[0]
	var corrow := enemy("corrow", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var seen := {}
	var taxed := false
	for i in roundi(26.0 / DT):
		combat.tick(DT)
		var cast := corrow.cast
		if cast and cast.name == "The Audit" and not seen.has(cast):
			seen[cast] = true
			assert_true(cast.interruptible)
			if seen.size() == 1:
				combat.interrupt(w, corrow)
		taxed = taxed or combat.heroes.any(func(h: Combatant) -> bool: return combat.has_aura(h, "tax"))
	return {"casts": seen.size(), "taxed": taxed}


func test_the_audit_is_three_casts_one_after_another_and_four_from_level_6():
	var at_1 := audit(1)
	assert_eq(at_1.casts, 3)
	assert_true(at_1.taxed, "one that is not silenced lands a tax")
	assert_true(of("alert").any(func(e: Dictionary) -> bool: return e.s == "The Audit. Silence every count!"))
	assert_eq(audit(6).casts, 4)


func test_a_tax_hurts_weakens_and_can_be_cleansed():
	start(["mender", "duelist"])
	var m := combat.heroes[0]
	var d := combat.heroes[1]
	var corrow := enemy("corrow", Vector3(3, 0, 0))
	combat.engage(pack, d)
	corrow.flags["audit"] = 1
	assert_true(run_until(func() -> bool: return combat.has_aura(d, "tax") or combat.has_aura(m, "tax"), 6.0))
	var taxed := d if combat.has_aura(d, "tax") else m
	var brute := enemy("brute", Vector3(4, 0, 2))
	assert_eq(combat.damage(taxed, brute, 100.0), 80.0, "a fifth less")
	combat.dispel(m, taxed)
	assert_false(combat.has_aura(taxed, "tax"))
	assert_eq(combat.damage(taxed, brute, 100.0), 100.0)


func test_seize_marks_a_hero_with_a_circle_that_goes_where_they_go():
	start(["warden", "mender"])
	var w := combat.heroes[0]
	var m := combat.heroes[1]
	enemy("corrow", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var carried := func() -> Array: return combat.zones.filter(func(z: Zone) -> bool: return z.follow_id > 0)
	assert_true(run_until(func() -> bool: return not carried.call().is_empty(), 20.0))
	var z: Zone = carried.call()[0]
	assert_eq(z.follow_id, m.id, "not whoever he is fighting")
	assert_eq(z.r, 7.0)
	m.pos = Vector3(-30, 0, 5)
	run_for(0.1)
	assert_eq(z.pos, m.pos, "it goes with them")
	var tank_hits := hits_on(w).size()
	events.clear()
	assert_true(run_until(func() -> bool: return carried.call().is_empty(), 6.0))
	assert_true(hits_on(m).has(430.0), "and goes off on them")
	assert_false(hits_on(w).has(430.0), "and on nobody they carried it clear of")
	assert_gt(tank_hits + 1, 0)


# ---------- Old Garrow

func test_a_hull_runs_the_length_of_a_slip():
	start(["warden", "mender"])
	var w := combat.heroes[0]
	var m := combat.heroes[1]
	var garrow := enemy("garrow", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var lanes := func() -> Array: return combat.zones.filter(func(z: Zone) -> bool: return z.kind == "lane")
	assert_true(run_until(func() -> bool: return not lanes.call().is_empty(), 14.0))
	assert_eq(lanes.call().size(), 1, "one hull below level 6")
	var lane: Zone = lanes.call()[0]
	assert_true(absf(lane.pos.z - garrow.home.z) in [0.0, 9.0], "down one of the three slips")
	assert_eq(lane.dir, Vector3.RIGHT)
	assert_eq(garrow.cast.name, "Launch")
	assert_true(of("alert").any(func(e: Dictionary) -> bool: return e.s == "A hull is coming down the slip!"))
	m.pos = lane.pos + Vector3(-18, 0, 2)
	w.pos = lane.pos + Vector3(0, 0, 6)
	events.clear()
	assert_true(run_until(func() -> bool: return lanes.call().is_empty(), 4.0))
	assert_true(hits_on(m).has(620.0), "whoever is on the slip is run down")
	assert_false(hits_on(w).has(620.0), "whoever stepped off it is not")
	assert_true(of("boom").any(func(e: Dictionary) -> bool: return e.kind == "lane"))


func test_from_level_6_a_second_hull_crosses_the_first():
	start(["warden"], 6)
	enemy("garrow", Vector3(3, 0, 0))
	combat.engage(pack, combat.player)
	var lanes := func() -> Array: return combat.zones.filter(func(z: Zone) -> bool: return z.kind == "lane")
	assert_true(run_until(func() -> bool: return not lanes.call().is_empty(), 14.0))
	assert_eq(lanes.call().size(), 2)
	assert_almost_eq(absf((lanes.call()[0] as Zone).dir.dot((lanes.call()[1] as Zone).dir)), 0.0, 0.001, "across it")


func test_pitch_burns_on_where_it_lands():
	start(["warden"])
	var w := combat.player
	var garrow := enemy("garrow", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var patches := func() -> Array: return combat.zones.filter(func(z: Zone) -> bool: return z.linger > 0.0)
	assert_true(run_until(func() -> bool: return not patches.call().is_empty(), 8.0))
	var patch: Zone = patches.call()[0]
	assert_eq(patch.pos, w.pos, "at the tank's feet")
	assert_true(run_until(func() -> bool: return patch.went, 3.0))
	assert_true(hits_on(w).has(170.0))
	events.clear()
	run_for(2.2)
	assert_eq(hits_on(w).filter(func(amt: float) -> bool: return amt == 75.0).size(), 2, "it burns whoever stays, every second")
	w.pos = Vector3(-10, 0, 0)
	events.clear()
	run_for(2.2)
	assert_false(hits_on(w).has(75.0), "and nobody who has stepped out")
	assert_true(combat.zones.has(patch), "it is still there")
	combat.damage(w, garrow, 9999999.0)
	run_for(0.1)
	assert_true(patches.call().is_empty(), "it goes out when he falls")


# ---------- the Keeper of the Light

func test_the_beam_turns_and_burns_whoever_it_falls_on_in_his_sight():
	start(["warden", "mender"])
	var w := combat.heroes[0]
	var m := combat.heroes[1]
	m.pos = Vector3(-40, 0, 0)
	var keeper := enemy("keeper", Vector3(3, 0, 0))
	combat.engage(pack, w)
	var beams := func() -> Array: return combat.zones.filter(func(z: Zone) -> bool: return z.turn != 0.0)
	assert_true(run_until(func() -> bool: return not beams.call().is_empty(), 12.0))
	var beam: Zone = beams.call()[0]
	assert_gt(beam.dir.dot(Vector3.RIGHT), 0.99, "it starts pointing away from whoever he is fighting")
	assert_almost_eq(absf(beam.turn), 0.38, 0.001)
	var was := Vector2(beam.dir.x, beam.dir.z)
	run_for(1.0)
	assert_almost_eq(was.angle_to(Vector2(beam.dir.x, beam.dir.z)), beam.turn, 0.02, "turning as fast as it says, the way it says")
	assert_true(run_until(func() -> bool: return beam.went, 3.0))
	events.clear()
	m.pos = keeper.pos + beam.dir * 12.0
	run_for(0.6)
	assert_true(hits_on(m).has(115.0), "it burns")
	# behind a pillar it cannot reach
	combat.los = func(_a: Vector3, _b: Vector3) -> bool: return false
	m.pos = keeper.pos + beam.dir * 12.0
	events.clear()
	run_for(0.6)
	assert_false(hits_on(m).has(115.0), "but not whoever he cannot see")
	assert_eq(beam.pos, keeper.pos)


func test_the_beam_turns_faster_from_level_6():
	start(["warden"], 6)
	enemy("keeper", Vector3(3, 0, 0))
	combat.engage(pack, combat.player)
	assert_true(run_until(func() -> bool: return combat.zones.any(func(z: Zone) -> bool: return z.turn != 0.0), 12.0))
	assert_almost_eq(absf((combat.zones.filter(func(z: Zone) -> bool: return z.turn != 0.0)[0] as Zone).turn), 0.55, 0.001)


func test_lights_out_spares_only_those_in_a_lit_circle():
	start(["warden", "mender"])
	var w := combat.heroes[0]
	var m := combat.heroes[1]
	var keeper := enemy("keeper", Vector3(3, 0, 0))
	combat.engage(pack, w)
	run_for(0.5)
	keeper.hp = keeper.max_hp * 0.59
	assert_true(run_until(func() -> bool: return keeper.cast != null and keeper.cast.name == "Lights Out", 3.0))
	var lit := combat.zones.filter(func(z: Zone) -> bool: return z.safe)
	assert_eq(lit.size(), 3)
	assert_true(of("alert").any(func(e: Dictionary) -> bool: return e.s == "Lights out. Get into a lit circle!"))
	m.pos = (lit[1] as Zone).pos + Vector3(2, 0, 0)
	w.pos = keeper.home
	var m_hp := m.hp
	assert_true(run_until(func() -> bool: return keeper.cast == null, 6.0))
	assert_eq(m.hp, m_hp, "in the light, untouched")
	assert_true(hits_on(w).has(roundf(w.max_hp * 0.9)), "in the dark, all but killed")
	run_for(1.0)
	assert_true(combat.zones.filter(func(z: Zone) -> bool: return z.safe).is_empty(), "the circles go once it is over")
	# and again at three tenths
	w.hp = w.max_hp
	keeper.hp = keeper.max_hp * 0.29
	assert_true(run_until(func() -> bool: return keeper.cast != null and keeper.cast.name == "Lights Out", 3.0))
	keeper.hp = keeper.max_hp * 0.2
	assert_true(run_until(func() -> bool: return keeper.cast == null, 6.0))
	run_for(8.0)
	assert_false(keeper.cast != null and keeper.cast.name == "Lights Out", "twice, and no more")


func test_lights_out_puts_out_the_beam():
	start(["warden"])
	var keeper := enemy("keeper", Vector3(3, 0, 0))
	combat.engage(pack, combat.player)
	assert_true(run_until(func() -> bool: return combat.zones.any(func(z: Zone) -> bool: return z.turn != 0.0), 12.0))
	keeper.hp = keeper.max_hp * 0.5
	assert_true(run_until(func() -> bool: return keeper.cast != null and keeper.cast.name == "Lights Out", 3.0))
	assert_false(combat.zones.any(func(z: Zone) -> bool: return z.turn != 0.0))


# ---------- what the AI makes of them

func test_a_held_hero_does_nothing_and_goes_nowhere():
	var r := harness_at(Vector3(20, 0, 44))
	var c := r.combat
	var healer := c.heroes[1]
	c.engage(c.packs[HASK], c.heroes[0])
	c.add_aura(healer, {"id": "bound", "name": "Bound", "dur": 5.0, "src_id": 0, "debuff": true, "hold": true})
	var at := healer.pos
	var healed: float = healer.stats.heal
	r.run_for(3.0)
	assert_eq(healer.pos, at)
	assert_eq(healer.stats.heal, healed)
	assert_null(healer.cast)


func test_the_party_beats_each_boss_of_tollhaven_at_level_1():
	# each from just inside its door, with the mechanic it brings
	for fight: Array in [[HASK, Vector3(18, 0, 47)], [CORROW, Vector3(99, 0, -23)], [GARROW, Vector3(180, 0, 47)], [KEEPER, Vector3(185, 0, 139)]]:
		var plan := Route.new()
		plan.level = "tollhaven"
		plan.pulls = [Route.pull([fight[0]])]
		var r := harness_at(fight[1], 1, plan)
		var c := r.combat
		for g in r.level.gates.size():
			r.level.open_gate(g)
		var boss: Pack = c.packs[fight[0]]
		assert_true(r.run_until(func() -> bool: return boss.cleared, 240.0), boss.name + " is beaten")
		assert_eq(c.deaths, 0, boss.name + " kills nobody")
		gut.p("%s: %.0f s" % [boss.name, c.elapsed])


func test_chased_off_burning_pitch_the_tank_keeps_to_the_dock():
	var plan := Route.new()
	plan.level = "tollhaven"
	plan.pulls = [Route.pull([GARROW])]
	var r := harness_at(Vector3(180, 0, 47), 1, plan)
	var c := r.combat
	var tank := c.heroes[0]
	var dock: int = r.level.packs[GARROW].room
	var hold: Vector3 = r.level.packs[GARROW].stand
	var furthest := 0.0
	var patches := 0
	var began := false
	for i in 240 * 60:
		r.tick()
		if c.packs[GARROW].cleared:
			break
		began = began or Combat.flat(tank.pos, hold) < 2.0
		if began:
			furthest = maxf(furthest, Combat.flat(tank.pos, hold))
			assert_eq(r.level.room_at(tank.pos), dock, "the tank is still in the dock at %.0f s" % c.time)
			if r.level.room_at(tank.pos) != dock:
				break
		patches = maxi(patches, c.zones.filter(func(z: Zone) -> bool: return z.went and z.linger > 0.0).size())
	assert_true(c.packs[GARROW].cleared)
	assert_gt(patches, 1, "pitch burned under it more than once")
	assert_gt(furthest, 4.0, "and it stepped off")
	assert_lt(furthest, 24.0, "but never far from where it holds him")
	assert_eq(c.deaths, 0)


func test_the_party_cuts_the_net_before_the_haul():
	var plan := Route.new()
	plan.level = "tollhaven"
	plan.pulls = [Route.pull([HASK])]
	var r := harness_at(Vector3(18, 0, 47), 1, plan)
	var c := r.combat
	assert_true(r.run_until(func() -> bool: return c.packs[HASK].cleared, 240.0))
	var nets := c.enemies.filter(func(e: Combatant) -> bool: return e.enemy.id == "net")
	assert_gt(nets.size(), 1, "she threw more than one")
	assert_eq(r.of("yank").size(), 0, "and never got to haul on one")


func test_with_both_damage_dealers_netted_the_tank_cuts_one_free():
	var r := harness_at(Vector3(18, 0, 44))
	var c := r.combat
	var tank := c.heroes[0]
	var hask := c.packs[HASK].units[0]
	c.engage(c.packs[HASK], tank)
	r.run_for(1.0)
	for h: Combatant in [c.heroes[2], c.heroes[3]]:
		var net := c.spawn_enemy("net", h.pos, HASK, true)
		net.flags["holds"] = h.id
		c.add_aura(h, {"id": "netted", "name": "Netted", "dur": 9999.0, "src_id": net.id, "debuff": true, "hold": true})
	hask.cds["haul"] = 60.0
	hask.cds["castnet"] = 60.0
	r.run_for(1.0)
	assert_eq(c.unit(tank.target_id).enemy.id, "net", "nobody else can")
	assert_true(r.run_until(func() -> bool: return not c.held(c.heroes[2]) or not c.held(c.heroes[3]), 25.0), "one is cut free")
	assert_true(r.run_until(func() -> bool: return not c.held(c.heroes[2]) and not c.held(c.heroes[3]), 15.0), "who cuts the other")
	r.run_for(1.0)
	assert_eq(c.unit(tank.target_id), hask, "and the tank goes back to her")


func test_of_two_nets_the_healers_is_cut_first():
	var r := harness_at(Vector3(18, 0, 44))
	var c := r.combat
	var hask := c.packs[HASK].units[0]
	c.engage(c.packs[HASK], c.heroes[0])
	r.run_for(1.0)
	var nets := {}
	for h: Combatant in [c.heroes[3], c.heroes[1]]:
		var net := c.spawn_enemy("net", h.pos, HASK, true)
		net.flags["holds"] = h.id
		nets[h.slot] = net
		c.add_aura(h, {"id": "netted", "name": "Netted", "dur": 9999.0, "src_id": net.id, "debuff": true, "hold": true})
	hask.cds["haul"] = 60.0
	hask.cds["castnet"] = 60.0
	r.run_for(1.0)
	assert_eq(c.heroes[2].target_id, (nets[1] as Combatant).id)
	assert_true(r.run_until(func() -> bool: return not (nets[1] as Combatant).alive, 20.0))
	assert_true((nets[3] as Combatant).alive, "the Harpooner waits her turn")


func test_the_party_gets_into_the_light_and_carries_a_seizure_clear():
	var plan := Route.new()
	plan.level = "tollhaven"
	plan.pulls = [Route.pull([KEEPER])]
	var r := harness_at(Vector3(185, 0, 139), 1, plan)
	r.level.open_gate(0)
	var c := r.combat
	var keeper := c.packs[KEEPER].units[0]
	assert_true(r.run_until(func() -> bool: return keeper.flags.has("d1") and keeper.cast == null, 200.0), "the lights went out once")
	assert_eq(c.deaths, 0, "and everyone had found a circle")
	for h in c.heroes:
		assert_gt(h.hp, h.max_hp * 0.1, h.name + " was in the light")
	# Corrow's circle
	plan.pulls = [Route.pull([CORROW])]
	r = harness_at(Vector3(99, 0, -23), 1, plan)
	c = r.combat
	var carried := func() -> Array: return c.zones.filter(func(z: Zone) -> bool: return z.follow_id > 0 and z.t > z.delay - 0.2)
	assert_true(r.run_until(func() -> bool: return not carried.call().is_empty(), 60.0), "someone was seized")
	var z: Zone = carried.call()[0]
	for h in c.heroes:
		if h.id != z.follow_id:
			assert_gt(Combat.flat(h.pos, z.pos), z.r, h.name + " is clear of it when it goes off")


# ---------- levels for each dungeon

func test_each_dungeon_keeps_its_own_levels_and_bests():
	var s := SaveData.new()
	assert_eq(s.place, "abbey")
	assert_eq(s.record(1, "ranger", 500.0, true), 1)
	assert_eq(s.unlocked, 2)
	s.place = "tollhaven"
	assert_eq(s.unlocked, 1, "nothing earned in the Abbey counts here")
	assert_eq(s.level, 1)
	assert_true(s.bests.is_empty())
	assert_eq(s.record(1, "ranger", 1400.0, true), 1)
	assert_eq(s.record(2, "mender", 1450.0, true), 1)
	s.level = 3
	assert_eq(s.unlocked, 3)
	s.place = "abbey"
	assert_eq(s.unlocked, 2)
	assert_eq(s.bests.keys(), ["ranger"])
	assert_eq(s.record(4, "duelist", 1300.0, true, "tollhaven"), 2, "a run is recorded where it was made")
	assert_eq(s.unlocked, 2)
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.place, "abbey")
	assert_eq(back.unlocked, 2)
	assert_eq(back.progress_in("tollhaven").unlocked, 5)
	assert_eq(back.progress_in("tollhaven").level, 3)
	assert_eq(back.progress_in("tollhaven").bests["mender"], {"level": 2, "time": 1450.0})
	assert_eq(back.to_dict(), s.to_dict())


func test_a_save_from_before_tollhaven_is_the_abbeys():
	var old := SaveData.from_dict({"v": 2, "unlocked": 5, "level": 4, "bests": {"ranger": {"level": 4, "time": 600.0}}})
	assert_eq(old.place, "abbey")
	assert_eq(old.unlocked, 5)
	assert_eq(old.level, 4)
	assert_eq(old.bests["ranger"].time, 600.0)
	assert_eq(old.progress_in("tollhaven"), {"unlocked": 1, "level": 1, "bests": {}, "timed": 0, "records": {}})
	assert_eq(old.progress_in("abbey").timed, 4, "the highest level timed was one below the unlocked")
	var odd := SaveData.from_dict({"v": 3, "place": "nowhere", "progress": {"tollhaven": {"unlocked": "x", "level": 99}, "elsewhere": {"unlocked": 9}}})
	assert_eq(odd.place, "abbey")
	assert_eq(odd.progress_in("tollhaven").level, 1, "a level is never above what is unlocked")
	assert_false(odd.progress.has("elsewhere"))


func test_the_setup_screen_chooses_the_dungeon():
	var save := SaveData.new()
	save.unlocked = 4
	save.level = 4
	var changed := [0]
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(Screens.setup(save, func() -> void: changed[0] += 1, func() -> void: pass))
	assert_eq((holder.find_child("Start", true, false) as Button).text, "Enter the Abbey")
	assert_not_null(holder.find_child("Level4", true, false))
	(holder.find_child("Dungeon_tollhaven", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(save.place, "tollhaven")
	assert_gt(changed[0], 0, "and the save is written")
	assert_eq((holder.find_child("Start", true, false) as Button).text, "Enter Tollhaven")
	assert_null(holder.find_child("Level4", true, false), "its levels are its own")
	assert_not_null(holder.find_child("Level1", true, false))
	assert_true((holder.find_child("RouteName", true, false) as Label).text.begins_with("The safe way: 26 pulls"))


# ---------- the map

func test_the_map_shows_the_gate_and_the_patrols_and_warns_of_what_cannot_be_walked():
	var l := Levels.tollhaven()
	var save := SaveData.new()
	save.place = "tollhaven"
	var party: Array[String] = ["warden", "mender", "duelist", "ranger"]
	var map := RouteMap.new()
	add_child_autofree(map)
	map.open(l, save, party)
	await wait_process_frames(2)
	assert_eq(map.snags(), [] as Array[String])
	assert_eq(map.warnings(), "")
	map.route.remove_pull(map.route.pull_of(NET_ROW))
	var lines := map.snags()
	assert_eq(lines, ["Pull 3 cannot be reached without waking Net Row."] as Array[String])
	assert_true(map.warnings().ends_with(lines[0]), "after what the route leaves undone")
	map.route.move_pull(map.route.pull_of(KEEPER), 0)
	assert_true(map.snags()[0].begins_with("Pull 1 is behind the Mole gate, which opens only when Mother Hask, Exciseman Corrow and Old Garrow are at rest"))
	map._reset()
	map.route.remove_pull(map.route.pull_of(24))
	assert_eq(map.snags().size(), 1)
	assert_true(map.snags()[0].begins_with("Pull 25 is reached the long way round, "))
	assert_true(map.snags()[0].ends_with(" m, to keep clear of Keel Street."))
	# a patrol is where the level starts it, and says what it is
	assert_eq(map.view.middle(WATCH), l.packs[WATCH].center)
	assert_eq(map.view.posts(WATCH), LevelDef.posts(l.packs[WATCH]))
	map._on_pack_hover(WATCH)
	var title: Label = map._details.get_child(0).get_child(0)
	assert_true(title.text.ends_with("a patrol"))
	map.view.hover = WATCH
	map.view.queue_redraw()
	await wait_process_frames(2)
	assert_true(map.view.pull_outline(0).size() > 4)


# ---------- the scene

func test_tollhaven_is_built_with_its_gate_and_the_gate_opens():
	Run.place = "tollhaven"
	Run.party.assign(PARTY)
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.autoplay = false
	Run.rng_seed = 5
	var main: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(main)
	main.combat.ai_plays = false
	await wait_physics_frames(3)
	var c := main.combat
	var level := main.level
	assert_eq(c.packs.size(), 26)
	assert_eq(c.time_limit, 25 * 60.0)
	assert_gt(level.nav_polygons(), 100, "there is a floor to walk on")
	assert_eq(main.all_units().size(), 4 + c.enemies.size())
	var door: Vector3 = level.def.doors[level.def.gates[0].door].pos
	assert_true(level.gate_shut(0))
	assert_false(level.sees(door + Vector3(0, 0, -2.5), door + Vector3(0, 0, 2.5)), "the gate blocks the view")
	assert_gt(level.path(level.def.start, level.def.packs[HASK].center).size(), 2, "the wings can be walked to")
	# a patrol's figures walk
	var keeper_of_the_watch := main.unit_of(c.packs[WATCH].units[0].id)
	var was := keeper_of_the_watch.global_position
	await wait_physics_frames(90)
	assert_gt(Combat.flat(was, keeper_of_the_watch.global_position), 2.0)
	assert_lt(Combat.flat(keeper_of_the_watch.global_position, c.packs[WATCH].units[0].home), 1.0, "in step with the round")
	for id: int in [HASK, CORROW, GARROW]:
		fell(c, id)
	await wait_physics_frames(3)
	assert_false(level.gate_shut(0))
	assert_true(level.sees(door + Vector3(0, 0, -2.5), door + Vector3(0, 0, 2.5)))
	assert_gt(level.path(level.def.start, level.def.packs[KEEPER].center).size(), 2, "and the Mole can be walked")
	# dragged by the rules, a figure is put where they say
	var ranger := main.player
	c.yank(ranger.c, Vector3(100, 0, 120))
	assert_almost_eq(ranger.global_position.x, 100.0, 0.01)
	assert_almost_eq(ranger.global_position.z, 120.0, 0.01)
