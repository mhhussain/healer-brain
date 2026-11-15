extends GutTest

# Milestone 5: the Drowned Abbey as a level, and the AI running it on the rules alone.

func test_the_abbey_has_nine_rooms_in_three_parts():
	var l := Levels.abbey()
	assert_eq(l.packs.size(), 9)
	assert_eq(l.packs.filter(func(p: Dictionary) -> bool: return p.boss).map(func(p: Dictionary) -> String: return p.name),
		["Brother Krogg", "Sister Velisse", "Abbot Sulmar"])
	assert_eq(l.rooms.size(), 10, "the landing, then a room for each pack and boss")
	assert_eq(l.rooms.map(func(r: Dictionary) -> int: return r.zone), [0, 0, 0, 0, 1, 1, 1, 2, 2, 2])
	assert_eq(l.packs.map(func(p: Dictionary) -> int: return p.room), [1, 2, 3, 4, 5, 6, 7, 8, 9])
	for p in l.packs:
		assert_eq(l.room_at(p.center), p.room, p.name + " stands in its room")
	assert_eq(l.pillars.size(), 10)
	assert_true(l.can_stand(l.start))
	assert_eq(l.room_at(l.start), 0)


func test_each_room_of_the_abbey_is_joined_to_the_next_by_a_doorway():
	var l := Levels.abbey()
	assert_eq(l.doors.size(), 9)
	for i in l.doors.size():
		var d: Dictionary = l.doors[i]
		assert_eq([d.a, d.b], [i, i + 1])
		assert_true(l.can_stand(d.pos), "doorway %d can be walked through" % i)
		assert_eq(l.room_at(d.pos), -1, "a doorway is in neither room")
		assert_eq(l.door_at(d.pos), i)
		assert_eq(l.zone_at(d.pos), -1)
	assert_eq(l.doors_between(l.start, l.packs[2].center), [0, 1, 2] as Array[int], "three doorways to Brother Krogg")
	assert_eq(l.doors_between(l.packs[2].center, l.start), [2, 1, 0] as Array[int], "and three back")
	assert_eq(l.doors_between(l.start, l.packs[0].pull_from), [0] as Array[int], "a doorway is reached by going into it")
	assert_eq(l.doors_between(l.doors[0].pos, l.packs[1].center), [1] as Array[int], "from a doorway, the one after")
	assert_eq(l.doors_between(l.start, l.start + Vector3(1, 0, 1)), [] as Array[int])
	assert_eq(l.doors_between(l.start, Vector3(-500, 0, 0)), [] as Array[int], "nowhere has no way to it")


func test_a_spot_is_in_the_tanks_room_only_once_it_is_through_the_doorway():
	var l := Levels.abbey()
	var room: Rect2 = l.rooms[2].rect
	var tank: Vector3 = l.packs[1].stand
	var way_in: Rect2 = l.doors[1].rect
	var inside := Vector3(way_in.end.x, 0, way_in.get_center().y)
	assert_true(l.same_room(tank, l.packs[1].center, 1.5))
	assert_false(l.same_room(tank, l.packs[0].center, 1.5), "the room before")
	assert_false(l.same_room(tank, l.doors[1].pos, 1.5), "the doorway in")
	assert_false(l.same_room(tank, inside + Vector3(1.0, 0, 0), 1.5), "one step through is still the threshold")
	assert_true(l.same_room(tank, inside + Vector3(1.0, 0, 0)), "unless nobody minds")
	assert_true(l.same_room(tank, inside + Vector3(1.6, 0, 0), 1.5))
	assert_true(l.same_room(tank, Vector3(room.position.x + 0.6, 0, room.position.y + 1.0), 1.5), "a far corner is nobody's threshold")
	# a tank in the doorway is pulling: both rooms it joins will do
	assert_true(l.same_room(l.doors[1].pos, l.packs[0].center, 1.5))
	assert_true(l.same_room(l.doors[1].pos, l.packs[1].center, 1.5))
	assert_true(l.same_room(l.doors[1].pos, l.doors[1].pos + Vector3(0.5, 0, 0), 1.5))
	assert_false(l.same_room(l.doors[1].pos, l.packs[2].center, 1.5))
	assert_true(LevelDef.new().same_room(Vector3.ZERO, Vector3(99, 0, 0), 1.5), "a place with no rooms is one room")


func test_the_abbey_asks_for_all_the_count_it_holds():
	var l := Levels.abbey()
	assert_eq(l.count_needed, 0, "which is how a level asks for everything")
	var r := AIHarness.new(l, ["warden", "mender", "duelist", "ranger"])
	assert_eq(r.combat.count_goal(), 92)
	assert_eq(r.combat.count(), 0)
	var worth := {}
	for e in r.combat.enemies:
		worth[e.enemy.id] = e.enemy.count
	assert_eq(worth, {"brute": 4, "hexer": 3, "archer": 3, "shaman": 3, "berserker": 4, "overseer": 8, "krogg": 0, "velisse": 0, "sulmar": 0})


func test_the_abbey_has_a_lamp_at_the_landing_and_one_by_the_way_on_from_each_boss():
	var l := Levels.abbey()
	assert_eq(l.lamps.map(func(lamp: Dictionary) -> String: return lamp.name), ["the landing", "the Gate Lamp", "the Ward Lamp", "the Bell Lamp"])
	assert_eq(l.lamps.map(func(lamp: Dictionary) -> int: return lamp.pack), [-1, 2, 5, 8])
	assert_eq(l.lamps.map(func(lamp: Dictionary) -> int: return l.room_at(lamp.pos)), [0, 3, 6, 9])
	for lamp in l.lamps:
		for x: float in [-0.75, 0.75]:
			for z: float in [-0.75, 0.75]:
				assert_true(l.can_stand(lamp.pos + Vector3(x, 0, z)), lamp.name + ": room for four round it")


func test_every_post_stand_and_way_in_is_on_the_floor():
	var l := Levels.abbey()
	for p in l.packs:
		for post in LevelDef.posts(p):
			assert_true(l.can_stand(post), p.name + ": an enemy's post")
		assert_true(l.can_stand(p.stand), p.name + ": where the tank stands")
		assert_true(l.same_room(p.center, p.stand, 5.0), p.name + ": well inside the room")
		assert_true(l.can_stand(p.pull_from), p.name + ": the doorway")
		assert_eq(l.door_at(p.pull_from), p.room - 1, p.name + ": pulled from the doorway into its room")


func test_walls_split_the_rooms_and_pillars_block_sight():
	var l := Levels.abbey()
	var first: Dictionary = l.packs[0]
	var second: Dictionary = l.packs[1]
	assert_false(l.clear_line(first.center, second.center, 1.3), "no view through the wall between rooms")
	assert_true(l.clear_line(first.pull_from, first.center, 1.3), "but the doorway sees into its room")
	assert_false(l.can_stand(Vector3(l.doors[0].pos.x, 0, 0)), "the wall is solid")
	var undercroft: Dictionary = l.packs[3]
	var pillar: Vector3 = l.pillars[0].pos
	var behind: Vector3 = pillar + (pillar - undercroft.center).normalized() * 2.5
	assert_false(l.clear_line(undercroft.center, behind, 1.3))
	assert_eq(l.pillar_between(undercroft.center, behind), 0)
	assert_true(l.clear_line(undercroft.center, behind, 1.3, 0.0, [false]), "until it falls")


func test_every_party_times_the_abbey_at_level_1():
	for healer in Heroes.HEALERS:
		for dps: Array in [["duelist", "ranger"], ["duelist", "pyromancer"], ["ranger", "pyromancer"]]:
			var r := AIHarness.new(Levels.abbey(), ["warden", healer] + dps, 1, 1)
			var who := "%s + %s" % [healer, " + ".join(dps)]
			assert_true(r.run_until(func() -> bool: return r.combat.finished, 30 * 60.0), who + " finishes")
			assert_true(r.combat.timed(), who + " is inside 14 minutes")
			assert_lt(r.combat.deaths, 3, who)
			gut.p("%s: %d:%02d, %d deaths" % [who, int(r.combat.total_time()) / 60, int(r.combat.total_time()) % 60, r.combat.deaths])


func test_a_hopeless_level_wipes_and_resets_without_breaking():
	var r := AIHarness.new(Levels.abbey(), ["warden", "mender", "duelist", "ranger"], 30, 1)
	r.run_for(240.0)
	assert_gt(r.of("wipe").size(), 1)
	assert_false(r.combat.finished)
	assert_false(r.combat.packs[0].cleared)
	assert_eq(r.combat.count(), 0, "a pack that wins keeps its count")
	for h in r.combat.heroes:
		assert_true(r.level.can_stand(h.pos, 0.3), h.name + " is still on the floor")
