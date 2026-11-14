extends GutTest

# Milestone 5: the Drowned Abbey as a level, and the AI running it on the rules alone.

func test_the_abbey_has_nine_rooms_in_three_parts():
	var l := Levels.abbey()
	assert_eq(l.packs.size(), 9)
	assert_eq(l.packs.filter(func(p: Dictionary) -> bool: return p.boss).map(func(p: Dictionary) -> String: return p.name),
		["Brother Krogg", "Sister Velisse", "Abbot Sulmar"])
	assert_eq(l.packs.map(func(p: Dictionary) -> int: return p.zone), [0, 0, 0, 1, 1, 1, 2, 2, 2])
	assert_eq(l.pillars.size(), 10)
	assert_eq(l.doors.size(), 9)
	assert_true(l.can_stand(l.start))


func test_every_post_stand_and_way_in_is_on_the_floor():
	var l := Levels.abbey()
	for p in l.packs:
		for post in LevelDef.posts(p):
			assert_true(l.can_stand(post), p.name + ": an enemy's post")
		assert_true(l.can_stand(p.stand), p.name + ": where the tank stands")
		assert_gt(p.stand.x, p.room_left + 5.0, p.name + ": well inside the room")
		assert_true(l.can_stand(p.entry), p.name + ": the way in")
		assert_true(l.can_stand(p.pull_from), p.name + ": the doorway")


func test_walls_split_the_rooms_and_pillars_block_sight():
	var l := Levels.abbey()
	var first: Dictionary = l.packs[0]
	var second: Dictionary = l.packs[1]
	assert_false(l.clear_line(first.center, second.center, 1.3), "no view through the wall between rooms")
	assert_true(l.clear_line(first.pull_from, first.center, 1.3), "but the doorway sees into its room")
	assert_false(l.can_stand(Vector3(first.room_left - 1.5, 0, 0)), "the wall is solid")
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
	for h in r.combat.heroes:
		assert_true(r.level.can_stand(h.pos, 0.3), h.name + " is still on the floor")
