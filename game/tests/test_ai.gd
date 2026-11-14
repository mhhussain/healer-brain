extends GutTest

# Milestone 4: what the AI decides, tested on the rules alone with a stand-in for walking.

const PARTY := ["warden", "mender", "duelist", "ranger"]


func run(party: Array = PARTY, level := 1, rng_seed := 1) -> AIHarness:
	return AIHarness.new(Levels.sandbox(), party, level, rng_seed)


func test_the_party_clears_the_hall_at_level_1():
	for healer in Heroes.HEALERS:
		for dps: Array in [["duelist", "ranger"], ["duelist", "pyromancer"], ["ranger", "pyromancer"]]:
			var r := run(["warden", healer] + dps)
			var who := "%s + %s" % [healer, " + ".join(dps)]
			assert_true(r.run_until(func() -> bool: return r.combat.finished, 240.0), who + " finishes")
			assert_eq(r.combat.deaths, 0, who + " loses nobody")
			assert_lt(r.combat.total_time(), 150.0, who + " is quick about it")
			for h in r.combat.heroes:
				if h.hero.role != "healer":
					assert_gt(h.stats.dmg, 500.0, h.name + " did damage")
			assert_gt(r.combat.heroes[1].stats.heal, 200.0, who + ": the healer healed")
			gut.p("%s: %.0f s, %s" % [who, r.combat.total_time(), ", ".join(r.combat.heroes.map(func(h: Combatant) -> String: return "%s %.0f dmg %.0f heal %d deaths" % [h.hero.id, h.stats.dmg, h.stats.heal, h.stats.deaths]))])


func test_interrupts_and_dispels_are_used_at_level_3():
	var r := run(PARTY, 3)
	assert_true(r.run_until(func() -> bool: return r.combat.finished, 300.0))
	var kicks := 0
	for h in r.combat.heroes:
		kicks += h.stats.interrupts
	assert_gt(kicks, 2, "casts are silenced")
	assert_gt(r.of("interrupt").size(), 2)


func test_a_curse_is_lifted_by_the_healer():
	var r := run(PARTY, 3)
	var healer := r.combat.heroes[1]
	var tank := r.combat.heroes[0]
	r.run_until(func() -> bool: return r.combat.in_combat, 30.0)
	r.combat.add_aura(tank, {"id": "wither", "name": "Withering Verse", "dur": 10.0, "src_id": 0, "debuff": true,
		"dispellable": true, "tick_every": 1.0, "tick_dmg": 38.0})
	assert_true(r.run_until(func() -> bool: return not r.combat.has_aura(tank, "wither"), 3.0))
	assert_eq(healer.stats.dispels, 1)


func test_the_tank_pulls_with_a_hail_once_everyone_is_ready():
	var r := run()
	var tank := r.combat.heroes[0]
	r.combat.heroes[2].hp = 100.0
	r.run_for(3.0)
	assert_false(r.combat.in_combat, "not while someone is hurt")
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 20.0))
	assert_eq(r.of("ability")[0].s, "challenge", "the fight starts with Pilot's Hail")
	assert_gt(Combat.dist(tank, r.combat.enemies[0]), 8.0, "from a distance")


func test_the_party_fights_inside_the_second_room_not_on_its_threshold():
	var r := run()
	var second := r.combat.packs[1]
	assert_true(r.run_until(func() -> bool: return second.engaged, 200.0))
	r.run_for(6.0)
	var ticks := 0
	var outside := {}
	while second.engaged and not second.cleared and ticks < 60 * 120:
		r.tick()
		ticks += 1
		for h in r.combat.heroes:
			if h.alive and h.pos.x < second.room_left:
				outside[h.name] = outside.get(h.name, 0) + 1
	assert_true(second.cleared)
	for name: String in outside:
		assert_lt(outside[name] / float(ticks), 0.02, name + " hangs back outside the room")


func test_a_hero_steps_out_of_a_telegraph():
	var r := run()
	var ranger := r.combat.heroes[3]
	r.run_until(func() -> bool: return r.combat.in_combat, 30.0)
	r.run_for(3.0)
	var zone := r.combat.add_zone({"kind": "circle", "pos": ranger.pos, "r": 3.5, "delay": 1.6, "dmg": 9999.0, "type": "magic"})
	r.run_for(1.7)
	assert_false(zone.holds(ranger.pos), "out before it lands")
	assert_true(ranger.alive)
	assert_eq(r.of("boom").size(), 1)


func test_damage_dealers_stay_out_of_the_priors_sweep():
	var r := run(PARTY, 3)
	assert_true(r.run_until(func() -> bool: return r.combat.finished, 300.0))
	var swept := {}
	for e in r.of("hit"):
		if e.amt >= 300.0:
			swept[r.combat.unit(e.id).name] = true
	assert_false(swept.has("Corvin Ashby"), "the Wrecker stands behind")
	assert_false(swept.has("Isolde Fenn"))


func test_the_healer_keeps_the_tank_up_through_a_hard_level():
	var r := run(PARTY, 5)
	assert_true(r.run_until(func() -> bool: return r.combat.finished, 400.0))
	assert_lt(r.combat.heroes[0].stats.deaths, 2)
	assert_gt(r.combat.heroes[1].stats.heal, 1500.0)


func test_the_ai_tank_waits_for_a_player_who_falls_behind():
	# a long corridor with one pack far down it
	var def := LevelDef.new()
	def.floors = [Rect2(-60, -5, 120, 10)]
	def.start = Vector3(-50, 0, 0)
	def.packs = [{"name": "Far away", "boss": false, "lamp": "", "enemies": ["brute"], "center": Vector3(40, 0, 0),
		"entry": Vector3(-50, 0, 0), "pull_from": Vector3(20, 0, 0), "stand": Vector3(30, 0, 0), "room_left": -60.0}]
	var r := AIHarness.new(def, PARTY, 1, 1, false, 3)
	var tank := r.combat.heroes[0]
	var me := r.combat.player
	assert_eq(me.hero.id, "ranger")
	var from := me.pos
	r.run_for(15.0)
	assert_eq(me.pos, from, "the AI leaves the player's hero alone")
	assert_almost_eq(Combat.dist(tank, me), 28.0, 1.0, "the tank goes ahead, but only so far")
	for h in r.combat.heroes.slice(1, 3):
		assert_lt(Combat.dist(h, tank), 8.0, h.name + " goes with the tank")
	me.pos = Vector3(0, 0, 0)
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 15.0), "and it pulls once you catch up")


func test_the_ai_follows_a_player_tank():
	var r := AIHarness.new(Levels.sandbox(), PARTY, 1, 1, false, 0)
	var me := r.combat.player
	me.pos = Vector3(4, 0, 3)
	r.run_for(4.0)
	for h in r.combat.heroes:
		assert_lt(Combat.dist(h, me), 9.0, h.name + " keeps up")
	assert_false(r.combat.in_combat, "and nobody pulls for you")


func test_the_party_hides_from_the_last_toll():
	var def := LevelDef.new()
	def.floors = [Rect2(-20, -20, 60, 40)]
	def.add_pillar(8, 6, 1.5)
	def.start = Vector3(0, 0, 0)
	def.packs = [{"name": "Abbot Sulmar", "boss": true, "lamp": "", "enemies": ["sulmar"], "center": Vector3(18, 0, 0),
		"entry": Vector3(0, 0, 0), "pull_from": Vector3(2, 0, 0), "stand": Vector3(10, 0, 0), "room_left": -20.0}]
	var r := AIHarness.new(def, PARTY, 1, 3)
	var boss := r.combat.enemies[0]
	assert_true(r.run_until(func() -> bool: return r.combat.in_combat, 30.0))
	r.run_for(4.0)
	boss.hp = boss.max_hp * 0.6
	assert_true(r.run_until(func() -> bool: return boss.cast != null and boss.cast.ab.hide, 20.0), "the Abbot rings the Last Toll")
	r.run_until(func() -> bool: return boss.cast == null, 6.0)
	var tolled := r.of("hit").filter(func(e: Dictionary) -> bool: return e.s == "magic" and e.amt >= 900.0)
	assert_eq(tolled.size(), 0, "everyone got behind the pillar")
	for h in r.combat.heroes:
		assert_true(h.alive, h.name)
